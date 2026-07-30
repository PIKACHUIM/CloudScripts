#!/bin/bash
# KDE Plasma Desktop Environment
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/plasma.sh

set -e
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$INSTALL_DIR/commons.sh"

# Check -----------------------------------------------------------
file="/etc/lxc-de-flag"
if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e
else
    read -r content < "$file"
    case "$content" in
        0) apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e ;;
        9) echo "检查通过，开始安装 Plasma 桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

# Plasma Desktop (来自 RDDocker) -----------------------------------
case "$OS_ID" in
    debian)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL pulseaudio kde-plasma-desktop git cmake nano vim"
        ;;
    ubuntu)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL software-properties-common"
        add-apt-repository -y ppa:kubuntu-ppa/backports 2>/dev/null || true
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL pulseaudio kubuntu-desktop git cmake nano vim" \
            || eval "$PKG_INSTALL pulseaudio kde-plasma-desktop git cmake nano vim"
        ;;
    fedora)
        eval "$PKG_INSTALL plasma-workspace plasma-nm cmake git"
        ;;
    arch|archos)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL pulseaudio plasma kde-applications cmake git"
        ;;
    alpine)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL pulseaudio plasma-desktop kde-applications-base cmake git"
        ;;
esac

# Startup Desktop (来自 RDDocker) ----------------------------------
cat >> /run.sh <<'EOF'
echo "Starting KDE Plasma Desktop..."
export DISPLAY=:9
systemctl disable sddm 2>/dev/null || true
service sddm stop 2>/dev/null; killall startplasma-x11 2>/dev/null || true
killall plasma_session 2>/dev/null; killall kwin_x11 2>/dev/null || true
nohup Xvfb :9 -ac -screen 0 1920x1080x24 &
sleep 1
eval $(dbus-launch --sh-syntax)
bash /x11vnc.sh
DISPLAY=:9 nohup plasma_session &
EOF
echo 2 > /etc/lxc-de-flag
