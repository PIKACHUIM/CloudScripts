#!/usr/bin/env bash
# ============================================================
#  PIKA SH - System Tools Module
#  SSH hardening, timezone, system info, self-update, uninstall.
# ============================================================
set -e

SystemMENU=(
    "ssh|system.ssh|system.ssh.desc|do_sys_ssh"
    "timezone|system.timezone|system.timezone.desc|do_sys_timezone"
    "hostname|system.hostname|system.hostname.desc|do_sys_hostname"
    "info|system.info|system.info.desc|do_sys_info"
    "update|system.update|system.update.desc|do_sys_update"
    "shortcut|system.shortcut|system.shortcut.desc|do_sys_shortcut"
    "uninstall|system.uninstall|system.uninstall.desc|do_sys_uninstall"
    "reboot|system.reboot|system.reboot.desc|do_sys_reboot"
)

do_sys_ssh() {
    pika_info "$(t 'state.configuring') SSH..."
    local port; read -r -p "New SSH port (default 22, 0=skip): " port
    if [ -n "$port" ] && [ "$port" != "0" ]; then
        sed -i "s/^#*Port .*/Port $port/" /etc/ssh/sshd_config
    fi

    read -r -p "Disable root password login? (y/N): " yn
    case "${yn:-n}" in
        [Yy]*) sed -i 's/^#*PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config ;;
    esac

    read -r -p "Disable password auth entirely? (y/N): " yn
    case "${yn:-n}" in
        [Yy]*) sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config ;;
    esac

    read -r -p "Import SSH pubkey (paste, Enter=skip): " pubkey
    if [ -n "$pubkey" ]; then
        mkdir -p ~/.ssh; chmod 700 ~/.ssh
        echo "$pubkey" >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys
    fi

    systemctl restart sshd 2>/dev/null || service ssh restart 2>/dev/null || true
    pika_info "$(t 'common.done') - SSH"
}

do_sys_timezone() {
    echo -e "\n  Common timezones:"
    echo "  1) Asia/Shanghai (UTC+8)"
    echo "  2) Asia/Tokyo (UTC+9)"
    echo "  3) America/New_York (UTC-5)"
    echo "  4) Europe/London (UTC+0)"
    echo "  5) Asia/Singapore (UTC+8)"
    echo "  6) Custom..."
    echo ""
    local sel; read -r -p "  $(t 'menu.prompt')" sel
    local tz="Asia/Shanghai"

    case "$sel" in
        1) tz="Asia/Shanghai" ;;
        2) tz="Asia/Tokyo" ;;
        3) tz="America/New_York" ;;
        4) tz="Europe/London" ;;
        5) tz="Asia/Singapore" ;;
        6) read -r -p "Enter timezone (e.g., Asia/Shanghai): " tz ;;
    esac

    timedatectl set-timezone "$tz" 2>/dev/null || { ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime; }
    # Sync NTP
    ntpdate -u pool.ntp.org 2>/dev/null || timedatectl set-ntp true 2>/dev/null || true
    pika_info "$(t 'common.done') - $(date)"
}

do_sys_hostname() {
    local current; current=$(hostname)
    echo ""
    echo "  $(t 'system.hostname.current'): $current"
    echo ""

    # Show current hostname entry in /etc/hosts
    echo "  $(t 'system.hostname.hosts_entries'):"
    grep -n -E "(^|[[:space:]])${current}([[:space:]]|$)" /etc/hosts 2>/dev/null | sed 's/^/    /' || echo "    (none)"
    echo ""

    local new_name
    read -r -p "  $(t 'system.hostname.new_prompt'): " new_name
    [ -z "$new_name" ] && { pika_info "$(t 'ui.cancelled')"; return; }

    # Validate: RFC 952/1123 hostname rules
    if ! echo "$new_name" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'; then
        pika_err "$(t 'system.hostname.invalid')"
        return
    fi

    # Set hostname (prefer hostnamectl for systemd, fallback to hostname command)
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl set-hostname "$new_name"
    else
        echo "$new_name" > /etc/hostname
        hostname "$new_name" 2>/dev/null || true
    fi

    # Update /etc/hosts: replace old hostname entries, add 127.0.1.1 entry
    if [ -n "$current" ] && [ "$current" != "$new_name" ]; then
        sed -i "s/^\([[:space:]]*[0-9.]*[[:space:]]*\)${current}\([[:space:]].*\|$\)/\1${new_name}\2/" /etc/hosts 2>/dev/null || true
    fi
    # Ensure 127.0.1.1 entry exists
    if ! grep -qE "^[[:space:]]*127\.0\.1\.1[[:space:]]+${new_name}" /etc/hosts 2>/dev/null; then
        echo "127.0.1.1       ${new_name}" >> /etc/hosts
    fi

    # Update cloud-init preserve_hostname if applicable
    if [ -f /etc/cloud/cloud.cfg ]; then
        if grep -q 'preserve_hostname' /etc/cloud/cloud.cfg 2>/dev/null; then
            sed -i 's/^preserve_hostname:.*/preserve_hostname: true/' /etc/cloud/cloud.cfg
        fi
    fi

    pika_info "$(t 'system.hostname.success') $new_name"
}

do_sys_info() {
    echo ""
    echo "  ================  System Overview  ================"
    echo "  Hostname   : $(hostname)"
    echo "  OS         : $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-$PIKA_DISTRO $PIKA_DISTRO_VER}")"
    echo "  Kernel     : $(uname -r)"
    echo "  Arch       : $(uname -m)"
    echo "  Uptime     : $(uptime -p 2>/dev/null || uptime | sed 's/.*up //;s/,.*//')"
    echo "  CPU        : $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo 'N/A')"
    echo "  CPU Cores  : $(nproc)"
    echo "  Memory     : $(free -h | awk '/Mem:/ {print $3 "/" $2}') $(free -h | awk '/Swap:/ {print "| Swap: " $3 "/" $2}')"
    echo "  Disk       : $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
    echo "  Network    : $(ip -4 addr show scope global | grep inet | awk '{print $2}' | paste -sd ' ' -)"
    echo "  ---------------------------------------------------"
    echo ""
}

do_sys_update() {
    pika_info "Checking for updates..."
    local update_url=$(gh_url "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh")
    local tmpf; tmpf=$(mktemp)
    if curl -fsSL "$update_url" -o "$tmpf" 2>/dev/null; then
        local new_ver; new_ver=$(grep -m1 'PIKA_VERSION=' "$tmpf" | cut -d'"' -f2)
        local cur_ver="${PIKA_VERSION:-0.0}"
        if [ "$new_ver" != "$cur_ver" ]; then
            pika_info "New version available: v$new_ver (current: v$cur_ver)"
            if pika_confirm "Update now?"; then
                curl -fsSL "$update_url" -o /usr/local/bin/pika-menu && chmod +x /usr/local/bin/pika-menu
                pika_info "Updated to v$new_ver! Run: bash /usr/local/bin/pika-menu"
            fi
        else
            pika_info "Already up to date (v$cur_ver)"
        fi
    fi
    rm -f "$tmpf"
}

do_sys_shortcut() {
    pika_info "Installing 'p' shortcut..."
    local install_path="/usr/local/bin/p"
    cat > "$install_path" << 'SCRIPT'
#!/usr/bin/env bash
# PIKA SH shortcut - run without arguments for interactive menu
exec bash <(curl -sL https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh) "$@"
SCRIPT
    chmod +x "$install_path"
    pika_info "$(t 'common.done') - Run 'p' to start PIKA SH"
}

do_sys_uninstall() {
    pika_confirm "$(t 'ui.confirm') - This will remove PIKA SH and ALL managed services!" || { pika_info "$(t 'ui.cancelled')"; return; }
    pika_warn "Uninstalling PIKA SH..."

    # Stop and remove services
    systemctl stop aria2 2>/dev/null || true
    systemctl disable aria2 2>/dev/null || true
    pm2 kill 2>/dev/null || true

    # Remove config and cache
    rm -rf /etc/pika-sh /var/cache/pika-sh /run/pika-sh 2>/dev/null || true
    rm -f /etc/lxc-de-flag 2>/dev/null || true
    rm -f /usr/local/bin/pika-menu /usr/local/bin/p 2>/dev/null || true

    # Remove sysctl drop-ins
    rm -f /etc/sysctl.d/99-pika-*.conf 2>/dev/null || true
    sysctl --system 2>/dev/null || true

    pika_info "PIKA SH has been uninstalled. Some services (Docker, installed packages) remain for manual removal."
}

do_sys_reboot() {
    pika_confirm "Reboot now?" || return
    reboot
}
