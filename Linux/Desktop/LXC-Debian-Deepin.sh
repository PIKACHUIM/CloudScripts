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