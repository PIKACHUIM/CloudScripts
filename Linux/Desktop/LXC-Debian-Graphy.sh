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
        9) echo "已经安装过X11，禁止重复安装" && exit ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

# Install Xserver -------------------------------------------------
echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d
DEBIAN_FRONTEND=noninteractive apt update && /sbin/init & 
DEBIAN_FRONTEND=noninteractive apt install -y pulseaudio 
apt install apt-transport-https ca-certificates curl   -y
apt update && DEBIAN_FRONTEND=noninteractiveapt install -y   \
xserver-xorg-core xauth xorg xserver-xorg-video-dummy xinit xvfb \
dbus-x11 x11-xserver-utils
echo 'allowed_users=anybody' > /etc/X11/Xwrapper.config


# Nomachine -------------------------------------------------------
NX="download/8.14/Linux/nomachine_8.14.2_1_amd64.deb"
wget https://download.nomachine.com/${NX} -O nx.deb
dpkg -i nx.deb || echo "Ignore Nomachine" &&  rm nx.deb
sed -i '$a PhysicalDesktopAuthorization 0' /usr/NX/etc/node.cfg
sed -i '$a WaylandModes "egl,compositor,drm"' /usr/NX/etc/node.cfg     
echo 'VirtualDesktopAccess all'  >> /usr/NX/etc/server.cfg
echo 'VirtualDesktopMode 2'      >> /usr/NX/etc/server.cfg
echo 'PhysicalDesktopAccess all' >> /usr/NX/etc/server.cfg
echo 'PhysicalDesktopMode 2'     >> /usr/NX/etc/server.cfg
echo 'CreateDisplay 1'           >> /usr/NX/etc/server.cfg
echo 'DisplayGeometry 1920x1080' >> /usr/NX/etc/server.cfg
echo 'StartHTTPDaemon Automatic' >> /usr/NX/etc/server.cfg
echo 'EnableWebPlayer 1'         >> /usr/NX/etc/server.cfg
echo 'WebAccessType systemlogin' >> /usr/NX/etc/server.cfg

# X11RDP+VNC ------------------------------------------------------
DEBIAN_FRONTEND=noninteractive apt -y install xrdp
DEBIAN_FRONTEND=noninteractive apt -y install x11vnc
cat > /x11vnc.sh <<'EOF'
nohup x11vnc -forever -noxdamage -repeat -rfbport \
      5900 -shared -create -display :9 &
EOF
chmod +x /x11vnc.sh

# Start Setup -----------------------------------------------------
echo 'echo Starting Graph Runtime -----------'  >> /run.sh
echo 'export DISPLAY=:9'                        >> /run.sh
echo '/etc/init.d/dbus start'                   >> /run.sh
echo 'echo Starting NX ----------------------'  >> /run.sh
echo '/etc/NX/nxserver --startup'               >> /run.sh
echo '/etc/NX/nxserver --restart'               >> /run.sh
echo 'echo Starting VNC ---------------------'  >> /run.sh
echo 'export HOME=/root && bash /x11vnc.sh   '  >> /run.sh
echo 9 > /etc/lxc-de-flag
