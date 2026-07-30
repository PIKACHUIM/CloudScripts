#!/bin/bash
# MATE Desktop Environment (保留原有脚本，RDDocker 未提供 MATE 版本)

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
        9) echo "检查通过，开始安装 MATE 桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

# MATE Desktop -----------------------------------------------------
case "$OS_ID" in
    debian|ubuntu)
        eval "$PKG_INSTALL task-mate-desktop mate-desktop-environment-extras"
        ;;
    fedora)
        eval "$PKG_INSTALL @mate-desktop mate-applications"
        ;;
    arch|archos)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL mate mate-extra"
        ;;
    alpine)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL mate-desktop mate-desktop-environment"
        ;;
esac

# Startup Desktop --------------------------------------------------
cat >> /run.sh <<'EOF'
echo "Starting MATE Desktop..."
export DISPLAY=:9
nohup Xvfb :9 -ac -screen 0 1920x1080x24 &
sleep 1
eval $(dbus-launch --sh-syntax)
bash /x11vnc.sh
DISPLAY=:9 nohup mate-session &
EOF
echo 7 > /etc/lxc-de-flag
