#!/bin/bash
# Check -----------------------------------------------------------
file="/etc/lxc-de-flag"
set -e
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

# GNOME3 ------------------------------------------------------
DEBIAN_FRONTEND=noninteractive apt install -y gnome curl


# X11RDP ------------------------------------------------------ 
update-alternatives --set x-session-manager /usr/bin/gnome-session

# Startup Desktop ---------------------------------------------
echo 'echo Starting Desktop Runtime -----------' >> /run.sh
echo 'export DISPLAY=:9 &&export $(dbus-launch)' >> /run.sh
echo 'nohup Xvfb :9 -ac -screen 0 1600x900x24 &' >> /run.sh
echo 'nohup /usr/bin/gnome-session &           ' >> /run.sh
echo 6 > /etc/lxc-de-flag