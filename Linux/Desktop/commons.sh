#!/bin/sh
# Common utilities - source this in every install script
# 来自 RDDocker 项目: https://github.com/PIKACHUIM/RDDocker
set -e
. /etc/os-release 2>/dev/null || true
OS_ID="${ID:-unknown}"
case "$OS_ID" in
  debian|ubuntu)
    PKG_UPDATE="apt-get update"
    PKG_INSTALL="DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends"
    # Suppress service management in Docker/LXC (exit 101 = deny action)
    # Only write if not already set to 101 (don't overwrite)
    if [ ! -f /usr/sbin/policy-rc.d ] || ! grep -q 'exit 101' /usr/sbin/policy-rc.d 2>/dev/null; then
        printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
        chmod +x /usr/sbin/policy-rc.d
    fi
    ;;
  fedora)
    PKG_UPDATE="dnf check-update || true"
    PKG_INSTALL="dnf install -y"
    ;;
  arch|archos)
    PKG_UPDATE="pacman -Sy --noconfirm"
    PKG_INSTALL="pacman -S --noconfirm"
    ;;
  alpine)
    PKG_UPDATE="apk update"
    PKG_INSTALL="apk add --no-cache"
    ;;
  opensuse*|sles)
    PKG_UPDATE="zypper refresh -q 2>/dev/null || true"
    PKG_INSTALL="zypper install -y"
    ;;
  *)
    echo "Unsupported OS: $OS_ID" && exit 1
    ;;
esac
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    ARCH_DEB="amd64"
    ARCH_RPM="x86_64"
    ;;
  aarch64)
    ARCH_DEB="aarch64"
    ARCH_RPM="aarch64"
    ;;
  *)
    ARCH_DEB="$ARCH"
    ARCH_RPM="$ARCH"
    ;;
esac

# Default CDN base for fetching remote scripts
: "${PIKA_DESKTOP_CDN:=https://pikash.opkg.cn/Linux/Desktop}"

# Quick helper: fetch and run a desktop script by name
de_run_remote() {
    local script_name="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${PIKA_DESKTOP_CDN}/${script_name}" | bash -e
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "${PIKA_DESKTOP_CDN}/${script_name}" | bash -e
    else
        echo "ERROR: curl or wget required" >&2; exit 1
    fi
}

# Standard Desktop pre-check: ensure Server + Graphy are installed before this DE
# Usage: de_precheck <desktop_name> <my_flag_value>
# Returns only if the system is ready for this DE installation.
de_precheck() {
    local de_name="$1" my_flag="$2"
    local file="/etc/lxc-de-flag"

    if [ ! -f "$file" ] || [ ! -s "$file" ]; then
        echo ">>> Installing Server base environment..."
        de_run_remote "LXC-Debian-Server.sh"
        echo ">>> Installing X11 graphics stack..."
        de_run_remote "LXC-Debian-Graphy.sh"
    else
        read -r content < "$file"
        case "$content" in
            0)
                echo ">>> Installing X11 graphics stack..."
                de_run_remote "LXC-Debian-Graphy.sh"
                ;;
            9)
                echo "Check passed, starting ${de_name} installation..."
                ;;
            "${my_flag}")
                echo "${de_name} is already installed, refusing duplicate." && exit
                ;;
            *)
                echo "Another desktop is already installed (flag=${content}), refusing duplicate." && exit
                ;;
        esac
    fi
}

# Mark installation complete by writing flag file
de_finish() {
    local flag="$1"
    echo "$flag" > /etc/lxc-de-flag
}

# Append a line to /run.sh
run_append() { echo "$*" >> /run.sh; }
