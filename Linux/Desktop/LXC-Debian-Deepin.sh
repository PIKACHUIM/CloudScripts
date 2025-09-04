#!/bin/bash
# Check -----------------------------------------------------------
file="/etc/lxc-ssh-flag"
if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e
	apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e
else
    read -r content < "$file"      # 去掉前后空白，只读第一行
    case "$content" in
        0) apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e ;;
        9) echo "检查通过，开始安装桌面....." ;;
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
apt install -y  gxde-desktop --install-recommends
apt install -y  gxde-desktop-extra 
apt install -y  firefox-esr spark-store    

# X11RDP ------------------------------------------------------ 
update-alternatives --set x-session-manager /usr/bin/startdde

# Startup Desktop ---------------------------------------------
echo 'echo Starting Desktop Runtime ----------'  >> /run.sh
echo 'export DISPLAY=:9 &&export $(dbus-launch)' >> /run.sh
echo 'nohup Xvfb :9 -ac -screen 0 1600x900x24 &' >> /run.sh
echo 'nohup startdde &                         ' >> /run.sh
