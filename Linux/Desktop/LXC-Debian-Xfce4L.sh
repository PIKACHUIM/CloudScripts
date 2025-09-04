#!/bin/bash

# Xfce4L ------------------------------------------------------
DEBIAN_FRONTEND=noninteractive apt install-y  fonts-noto-cjk xfce4
DEBIAN_FRONTEND=noninteractive apt install -y xfce4-goodies git


# X11RDP ------------------------------------------------------ 
update-alternatives --set x-session-manager /usr/bin/xfce4-session

# Startup Desktop ---------------------------------------------
echo 'echo Starting Desktop Runtime -----------' >> /run.sh
echo 'export DISPLAY=:9 &&export $(dbus-launch)' >> /run.sh
echo 'nohup Xvfb :9 -ac -screen 0 1600x900x24 &' >> /run.sh
echo 'nohup /usr/bin/xfce4-session &           ' >> /run.sh
