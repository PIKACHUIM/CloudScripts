#!/bin/bash

# GNOME3 ------------------------------------------------------
DEBIAN_FRONTEND=noninteractive apt install -y gnome curl


# X11RDP ------------------------------------------------------ 
update-alternatives --set x-session-manager /usr/bin/gnome-session

# Startup Desktop ---------------------------------------------
echo 'echo Starting Desktop Runtime -----------' >> /run.sh
echo 'export DISPLAY=:9 &&export $(dbus-launch)' >> /run.sh
echo 'nohup Xvfb :9 -ac -screen 0 1600x900x24 &' >> /run.sh
echo 'nohup /usr/bin/gnome-session &           ' >> /run.sh
