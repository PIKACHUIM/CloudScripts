#!/bin/bash

PR="main contrib non-free non-free-firmwar"
DEBIAN_FRONTEND=noninteractive apt update && /sbin/init & 
apt install apt-transport-https ca-certificates curl   -y
DEBIAN_FRONTEND=noninteractive apt install -y pulseaudio 
if [ $OS_VERSHOW = "13.00" ]; then export VER="lizhi"; fi
if [ $OS_VERSHOW = "12.00" ]; then export VER="bixie"; fi
SRC="repo.gxde.top/gxde-os/${VER}/g/gxde-source/" 
wget https://${SRC}gxde-source_1.1.8_all.deb -O gxde.deb 
dpkg -i gxde.deb && rm -rf gxde.deb && apt install sudo -y
apt update && apt install -y aptss gxde-testing-source   
apt install gxde-desktop spark-store --install-recommends -y
apt update && apt install gxde-desktop-extra firefox-esr  -y    

# Startup Desktop ---------------------------------------------
cat > /x11vnc.sh <<'EOF'
nohup x11vnc -forever -noxdamage -repeat -rfbauth \
/etc/x11vnc.pass -rfbport 5900 -shared -create -display :9 &
EOF

# Startup Desktop ---------------------------------------------
echo 'export DISPLAY=:9 &&export $(dbus-launch)' >> /run.sh
echo 'nohup Xvfb :9 -ac -screen 0 1600x900x24 &' >> /run.sh
echo 'chmod +x /x11vnc.sh && export HOME=/root ' >> /run.sh
echo 'bash /x11vnc.sh && nohup startdde &      ' >> /run.sh

