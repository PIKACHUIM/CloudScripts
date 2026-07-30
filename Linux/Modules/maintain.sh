#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Maintain Module
#  Menu + handlers for system maintenance.
#  Requires: core libs
# ============================================================
set -e

MaintainMENU=(
    "clean|maintain.clean|maintain.clean.desc|do_clean"
    "swap|maintain.swap|maintain.swap.desc|do_swap"
    "bbr|maintain.bbr|maintain.bbr.desc|do_bbr"
    "bbrplus|maintain.bbrplus|maintain.bbrplus.desc|do_bbrplus"
    "kernel|maintain.kernel|maintain.kernel.desc|do_kernel"
    "ufw|maintain.ufw|maintain.ufw.desc|do_ufw"
    "fail2ban|maintain.fail2ban|maintain.fail2ban.desc|do_fail2ban"
    "blockarea|maintain.blockarea|maintain.blockarea.desc|do_blockarea"
    "limitport|maintain.limitport|maintain.limitport.desc|do_limitport"
    "dd|maintain.dd|maintain.dd.desc|do_dd"
)

# ---- Handlers ----
do_clean() {
    pika_info "$(t 'state.installing') $(t 'maintain.clean')"
    case "$PIKA_PKG_MGR" in
        apt) apt-get autoremove --purge -y; apt-get autoclean -y; apt-get clean ;;
        dnf|yum) dnf autoremove -y 2>/dev/null || yum autoremove -y 2>/dev/null || true; dnf clean all 2>/dev/null || yum clean all 2>/dev/null || true ;;
        apk) apk cache clean ;;
        pacman) pacman -Scc --noconfirm ;;
        zypper) zypper clean -a ;;
    esac
    journalctl --vacuum-time=7d 2>/dev/null || true
    rm -rf /var/log/*.gz /var/log/*.1 /tmp/* 2>/dev/null || true
    pika_info "$(t 'common.done')"
}

do_swap() {
    local size; read -r -p "Swap size (MB, default 1024): " size
    size="${size:-1024}"
    if [ "$size" -lt 64 ] 2>/dev/null; then pika_warn "Swap too small, using 1024MB"; size=1024; fi
    swapoff /swapfile 2>/dev/null || true
    dd if=/dev/zero of=/swapfile bs=1M count="$size" status=progress 2>/dev/null
    chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
    pika_fstab_add "/swapfile none swap sw 0 0"
    pika_info "$(t 'common.done') - Swap ${size}MB"
}

do_bbr() {
    pika_info "$(t 'state.configuring') BBR..."
    pika_sysctl_dropin "99-pika-bbr" \
        "net.core.default_qdisc=fq" \
        "net.ipv4.tcp_congestion_control=bbr"
    pika_info "$(t 'common.done') - BBR $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'enabled')"
}

do_bbrplus() {
    ui_confirm_install "BBRPlus" "$(t 'maintain.bbrplus.desc')" || return
    local url=$(gh_url "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh")
    curl -fsSL "$url" -o /tmp/tcp.sh && chmod +x /tmp/tcp.sh && bash /tmp/tcp.sh
    rm -f /tmp/tcp.sh
}

do_kernel() {
    echo -e "\n  $(t 'kernel.select'):"
    echo "  1) $(t 'kernel.xanmod')"
    echo "  2) $(t 'kernel.liquorix')"
    echo "  3) $(t 'kernel.backports') (Debian)"
    echo "  4) $(t 'kernel.hwe') (Ubuntu)"
    echo ""
    local sel; read -r -p "  $(t 'menu.prompt')" sel

    case "$sel" in
        1)
            # Detect CPU ISA level
            local cpu_level="v1"
            if grep -q 'avx2' /proc/cpuinfo 2>/dev/null; then cpu_level="v3"
            elif grep -q 'sse4_2' /proc/cpuinfo 2>/dev/null; then cpu_level="v2"
            fi
            pika_info "CPU ISA: x86-64-$cpu_level"

            local xanmod_url="https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/VPSTest/xanmod-install.sh"
            case "$cpu_level" in
                v1) pika_warn "$(t 'kernel.xanmod.unsupported'): v4/v3"; xanmod_url=$(gh_url "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh") ;;
            esac

            if command -v curl >/dev/null 2>&1; then
                curl -fsSL "$xanmod_url" | bash -e || {
                    pika_warn "XanMod install via script failed. Trying manual..."
                    # Manual install for Debian/Ubuntu
                    echo "deb http://deb.xanmod.org releases main" > /etc/apt/sources.list.d/xanmod.list
                    local xanmod_gpg_url=$(gh_url "https://dl.xanmod.org/gpg.key")
                    curl -fsSL "$xanmod_gpg_url" | gpg --dearmor -o /etc/apt/trusted.gpg.d/xanmod.gpg
                    pkg_update_once
                    local xanmod_pkg="linux-xanmod-x64v${cpu_level#v}"
                    pkg_install "$xanmod_pkg" || pika_err "XanMod install failed"
                }
            fi
            ;;
        2)
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/VPSTest/liquorix-install.sh" | bash -e || true
            fi
            pkg_install linux-image-liquorix-amd64 linux-headers-liquorix-amd64 2>/dev/null || true
            ;;
        3) pkg_install -t bookworm-backports linux-image-amd64 linux-headers-amd64 2>/dev/null || true ;;
        4) pkg_install linux-generic-hwe-22.04 2>/dev/null || pkg_install linux-image-generic-hwe-22.04 2>/dev/null || true ;;
        *) pika_warn "$(t 'ui.invalid')" ;;
    esac
    pika_info "$(t 'kernel.reboot')"; pika_info "$(t 'common.done')"
}

do_ufw() {
    ensure_cmd ufw
    ufw --force enable 2>/dev/null || true
    ufw allow 22/tcp 2>/dev/null || true
    ufw default deny incoming 2>/dev/null || true
    ufw default allow outgoing 2>/dev/null || true
    ufw status verbose
    pika_info "$(t 'common.done') - UFW"
}

do_fail2ban() {
    pkg_install fail2ban
    systemctl enable --now fail2ban 2>/dev/null || service fail2ban start 2>/dev/null || true
    pika_info "$(t 'common.done') - Fail2Ban"
}

do_blockarea() {
    ensure_cmd curl
    local url=$(gh_url "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/VPSSets/Setup.sh")
    curl -fsSL "$url" | bash -e -s blockarea
}

do_limitport() {
    local port rate; read -r -p "Port number: " port; read -r -p "Rate limit (e.g., 100mbit): " rate
    [ -z "$port" ] || [ -z "$rate" ] && { pika_warn "Port and rate required"; return; }
    tc qdisc add dev "$(ip route show default | awk '/default/ {print $5}' | head -1)" root handle 1: htb default 30 2>/dev/null || true
    tc class add dev "$(ip route show default | awk '/default/ {print $5}' | head -1)" parent 1: classid 1:"$port" htb rate "$rate" 2>/dev/null || true
    pika_info "$(t 'common.done')"
}

do_dd() {
    if pika_is_container; then
        pika_warn "$(t 'app.container') - DD reinstall is not supported in containers!"
        return
    fi
    pika_confirm "$(t 'ui.confirm') DD reinstall - ALL DATA WILL BE LOST!" || { pika_info "$(t 'ui.cancelled')"; return; }
    local url=$(gh_url "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/VPSSets/Setup.sh")
    curl -fsSL "$url" | bash -e -s dd
}
