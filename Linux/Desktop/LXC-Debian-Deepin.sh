#!/bin/bash
# Deepin Desktop Environment (flag=1)
# Uses GXDE (GXDE Desktop Environment) - Deepin-style DE for Debian

set -e
# Dual-mode commons.sh loading: local file > remote CDN
if [ -f "$(dirname "$0")/commons.sh" ] && [ "$(dirname "$0")" != "." ]; then
    . "$(cd "$(dirname "$0")" && pwd)/commons.sh"
else
    _tmp_commons=$(mktemp)
    curl -fsSL "https://gh-bat.pika.net.cn/Linux/Desktop/commons.sh" -o "$_tmp_commons" 2>/dev/null || \
        wget -qO "$_tmp_commons" "https://gh-bat.pika.net.cn/Linux/Desktop/commons.sh" || \
        { echo "ERROR: Cannot load commons.sh" >&2; rm -f "$_tmp_commons"; exit 1; }
    . "$_tmp_commons"
    rm -f "$_tmp_commons"
fi

# Check
file="/etc/lxc-de-flag"
if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    echo "检查通过，开始安装 Server 基础环境....."
    de_run_remote "LXC-Debian-Server.sh"
    echo "检查通过，开始安装 X11 图形栈....."
    de_run_remote "LXC-Debian-Graphy.sh"
else
    read -r content < "$file"
    case "$content" in
        0)
            echo "检查通过，开始安装 X11 图形栈....."
            de_run_remote "LXC-Debian-Graphy.sh"
            ;;
        9) echo "检查通过，开始安装 Deepin 桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

# Desktop ------------------------------------------------------
PR="main contrib non-free non-free-firmwar"
. /etc/os-release

case "${VERSION_ID}" in
    13) VER="lizhi" ;;
    12) VER="bixie" ;;
    *)  echo "Unsupported Debian version: ${VERSION_ID}" >&2; exit 1 ;;
esac
export VER


# Deepin ------------------------------------------------------ 
SRC="repo.gxde.top/gxde-os/${VER}/g/gxde-source/" 
wget https://${SRC}gxde-source_1.1.10_all.deb -O gxde.deb 
dpkg -i gxde.deb && rm -rf gxde.deb && apt update
apt install -y gxde-testing-source && apt update 
# apt install -y  gxde-desktop --install-recommends
apt install -y  gxde-desktop
apt install -y  gxde-desktop-extra 
apt install -y  firefox-esr spark-store    

# X11RDP ------------------------------------------------------ 
update-alternatives --set x-session-manager /usr/bin/startdde

# Startup Desktop ---------------------------------------------
echo 'echo Starting DockerClouds Platform -----'  >> /run.sh
echo 'systemctl start dockerclouds 2>/dev/null || /usr/bin/python3 /opt/dockerclouds/Server.py &' >> /run.sh
echo 'echo Starting Desktop Runtime ----------'  >> /run.sh
echo 'export DISPLAY=:9 &&export $(dbus-launch)' >> /run.sh
echo 'nohup Xvfb :9 -ac -screen 0 1600x900x24 &' >> /run.sh
echo 'nohup startdde &                         ' >> /run.sh
de_finish 1