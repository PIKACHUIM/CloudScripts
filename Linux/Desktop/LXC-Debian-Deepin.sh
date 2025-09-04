#!/bin/bash

PR="main contrib non-free non-free-firmwar"
. /etc/os-release

case "${VERSION_ID}" in
    13) VER="lizhi" ;;
    12) VER="bixie" ;;
    *)  echo "Unsupported Debian version: ${VERSION_ID}" >&2; exit 1 ;;
esac
export VER

DEBIAN_FRONTEND=noninteractive apt update && /sbin/init & 
apt install apt-transport-https ca-certificates curl   -y
DEBIAN_FRONTEND=noninteractive apt install -y pulseaudio 
SRC="repo.gxde.top/gxde-os/${VER}/g/gxde-source/" 
wget https://${SRC}gxde-source_1.1.10_all.deb -O gxde.deb 
dpkg -i gxde.deb && rm -rf gxde.deb
apt install -y aptss gxde-testing-sourc && apt update 
apt install gxde-desktop --install-recommends -y
apt install gxde-desktop-extra firefox-esr spark-store   -y   

# X11RDP ------------------------------------------------------ 
update-alternatives --set x-session-manager /usr/bin/startdde

# Startup Desktop ---------------------------------------------
echo 'echo Starting Desktop Runtime ----------'  >> /run.sh
echo 'export DISPLAY=:9 &&export $(dbus-launch)' >> /run.sh
echo 'nohup Xvfb :9 -ac -screen 0 1600x900x24 &' >> /run.sh
echo 'nohup startdde &                         ' >> /run.sh
