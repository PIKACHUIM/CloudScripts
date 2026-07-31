#!/bin/bash
# Xfce4 Desktop Environment (flag=4)
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/xfce4l.sh

set -e
# Dual-mode commons.sh loading: local file > remote CDN
if [ -f "$(dirname "$0")/commons.sh" ] && [ "$(dirname "$0")" != "." ]; then
    . "$(cd "$(dirname "$0")" && pwd)/commons.sh"
else
    _tmp_commons=$(mktemp)
    curl -fsSL "https://pikash.opkg.cn/Linux/Desktop/commons.sh" -o "$_tmp_commons" 2>/dev/null || \
        wget -qO "$_tmp_commons" "https://pikash.opkg.cn/Linux/Desktop/commons.sh" || \
        { echo "ERROR: Cannot load commons.sh" >&2; rm -f "$_tmp_commons"; exit 1; }
    . "$_tmp_commons"
    rm -f "$_tmp_commons"
fi

# Check
de_precheck "Xfce4" "4"

# Xfce4 Desktop (来自 RDDocker) ------------------------------------
case "$OS_ID" in
  debian|ubuntu)
    eval "$PKG_UPDATE"
    eval "$PKG_INSTALL pulseaudio xfce4 xfce4-terminal xfce4-goodies \
      adwaita-qt papirus-icon-theme moka-icon-theme xfwm4 qt5ct git"
    systemctl disable lightdm 2>/dev/null || true
    ;;
  fedora)
    eval "$PKG_INSTALL @xfce-desktop xfce4-terminal git"
    ;;
  arch|archos)
    eval "$PKG_UPDATE"
    eval "$PKG_INSTALL pulseaudio xfce4 xfce4-goodies git"
    ;;
  alpine)
    eval "$PKG_UPDATE"
    eval "$PKG_INSTALL pulseaudio xfce4 xfce4-terminal \
      xfce4-notifyd xfce4-screenshooter xfce4-power-manager \
      xfce4-pulseaudio-plugin xfce4-clipman-plugin git"
    ;;
esac

mkdir -p /etc/default
echo "LANG=en_US.UTF-8" > /etc/default/locale
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale

# Startup Desktop (来自 RDDocker) ----------------------------------
cat >> /run.sh <<'EOF'
echo "Starting Xfce4 Desktop..."
export DISPLAY=:9
service lightdm stop 2>/dev/null; killall xfce4-session 2>/dev/null || true
nohup Xvfb :9 -ac -screen 0 1600x900x24 &
sleep 1
eval $(dbus-launch --sh-syntax)
bash /x11vnc.sh
DISPLAY=:9 nohup xfce4-session &
EOF
de_finish 4
