#!/bin/bash
# GNOME 3 Desktop Environment (flag=6)
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/gnome3.sh

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
de_precheck "GNOME" "6"

_ubver="${VERSION_ID%%.*}"
_is_ubuntu26=false
[ "$OS_ID" = "ubuntu" ] && [ "$_ubver" -ge 26 ] 2>/dev/null && _is_ubuntu26=true

# GNOME Desktop (来自 RDDocker) ------------------------------------
case "$OS_ID" in
debian|ubuntu)
    eval "$PKG_UPDATE"
    if [ "$_is_ubuntu26" = true ]; then
        eval "$PKG_INSTALL gnome-shell gnome-remote-desktop gnome-keyring \
        pipewire pipewire-pulse openssl sudo"
    else
        eval "$PKG_INSTALL gnome-core cmake git sudo pulseaudio-"
    fi
    ;;
fedora)
    eval "$PKG_INSTALL @gnome-desktop cmake git"
    ;;
arch|archos)
    eval "$PKG_INSTALL pulseaudio gnome gnome-extra cmake git"
    ;;
alpine)
    eval "$PKG_INSTALL pulseaudio gnome gnome-apps-core cmake git"
    ;;
esac

# Startup Desktop (来自 RDDocker) ----------------------------------
if [ "$_is_ubuntu26" = true ]; then
cat >> /run.sh <<'EOF'
# GNOME Wayland (Ubuntu 26+) -----------------------------------
echo "Starting GNOME Wayland Desktop..."
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
mkdir -p /run/user/0 && chmod 700 /run/user/0
export XDG_RUNTIME_DIR=/run/user/0
loginctl enable-linger root
systemctl start user@0.service || true
sleep 2
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus

gnome-keyring-daemon --daemonize --components=secrets 2>/dev/null || true
sleep 2

nohup env MUTTER_DEBUG_DUMMY_MODE_SPECS="1920x1080" \
    gnome-shell --headless --wayland &
sleep 3

mkdir -p /root/.local/share/gnome-remote-desktop
[ ! -f /root/.local/share/gnome-remote-desktop/rdp.crt ] && \
    openssl req -new -x509 -days 3650 -nodes \
    -out /root/.local/share/gnome-remote-desktop/rdp.crt \
    -keyout /root/.local/share/gnome-remote-desktop/rdp.key \
    -subj "/CN=gnome-rdp" 2>/dev/null

gsettings set org.gnome.desktop.remote-desktop.rdp tls-cert "/root/.local/share/gnome-remote-desktop/rdp.crt"
gsettings set org.gnome.desktop.remote-desktop.rdp tls-key "/root/.local/share/gnome-remote-desktop/rdp.key"
gsettings set org.gnome.desktop.remote-desktop.rdp enable true
grdctl rdp set-credentials root "${RDP_PASSWORD:-12345678}"
grdctl rdp enable 2>/dev/null || true

grdctl vnc set-password "${RDP_PASSWORD:-12345678}" 2>/dev/null || true
grdctl vnc enable 2>/dev/null || true
gsettings set org.gnome.desktop.remote-desktop.vnc auth-method password 2>/dev/null || true
gsettings set org.gnome.desktop.remote-desktop.vnc enable true 2>/dev/null || true

systemctl --user start gnome-remote-desktop 2>/dev/null || \
    nohup gnome-remote-desktop-daemon &
EOF
else
cat >> /run.sh <<'EOF'
# GNOME X11 ---------------------------------------------------
echo "Starting GNOME Desktop..."
loginctl enable-linger root
systemctl start user@0.service
export XDG_RUNTIME_DIR=/run/user/0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/0/bus
export DISPLAY=:9
export XDG_SESSION_TYPE=x11
nohup Xvfb :9 -ac -screen 0 1920x1080x24 &
sleep 1
eval $(dbus-launch --sh-syntax)
bash /x11vnc.sh DISPLAY=:9
nohup gnome-session &
EOF
fi
de_finish 6
