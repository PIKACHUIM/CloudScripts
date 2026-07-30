#!/bin/bash
# Xfce4 Desktop Environment
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/xfce4l.sh

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
        9) echo "检查通过，开始安装 Xfce4 桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

# Xfce4 Desktop (来自 RDDocker) ------------------------------------
case "$OS_ID" in
  debian|ubuntu)
    eval "$PKG_UPDATE"
    eval "$PKG_INSTALL pulseaudio xfce4 xfce4-terminal xfce4-goodies \
      adwaita-qt papirus-icon-theme moka-icon-theme xfwm4 qt5ct git"
    systemctl disable lightdm 2>/dev/null || true
    ;;
  fedora)
    eval "$PKG_INSTALL @xfce-desktop xfce4-terminal git"
    ;;
  arch|archos)
    eval "$PKG_UPDATE"
    eval "$PKG_INSTALL pulseaudio xfce4 xfce4-goodies git"
    ;;
  alpine)
    eval "$PKG_UPDATE"
    eval "$PKG_INSTALL pulseaudio xfce4 xfce4-terminal \
      xfce4-notifyd xfce4-screenshooter xfce4-power-manager \
      xfce4-pulseaudio-plugin xfce4-clipman-plugin git"
    ;;
esac

mkdir -p /etc/default
echo "LANG=en_US.UTF-8" > /etc/default/locale
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale

# Startup Desktop (来自 RDDocker) ----------------------------------
cat >> /run.sh <<'EOF'
echo "Starting Xfce4 Desktop..."
export DISPLAY=:9
service lightdm stop 2>/dev/null; killall xfce4-session 2>/dev/null || true
nohup Xvfb :9 -ac -screen 0 1600x900x24 &
sleep 1
eval $(dbus-launch --sh-syntax)
bash /x11vnc.sh
DISPLAY=:9 nohup xfce4-session &
EOF
echo 4 > /etc/lxc-de-flag
