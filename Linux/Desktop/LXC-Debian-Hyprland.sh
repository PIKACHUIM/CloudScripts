#!/bin/bash
# Hyprland Wayland Compositor (flag=8)
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/hyland.sh

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
de_precheck "Hyprland" "8"

# Hyprland (来自 RDDocker) -----------------------------------------
case "$OS_ID" in
  debian)
    echo "deb http://deb.debian.org/debian unstable main" > /etc/apt/sources.list.d/sid.list
    printf 'Package: openssl openssl-provider-legacy libssl3 libssl-dev\nPin: release a=stable\nPin-Priority: 1001\nPackage: *\nPin: release a=unstable\nPin-Priority: 100\n' \
      > /etc/apt/preferences.d/99sid
    eval "$PKG_UPDATE"
    ln -sf /bin/bash /bin/sh
    apt-get install -y -t unstable --no-install-recommends -o Dpkg::Options::="--force-overwrite" hyprland wayvnc xwayland kitty waybar pulseaudio git
    rm /etc/apt/sources.list.d/sid.list /etc/apt/preferences.d/99sid
    ;;
  ubuntu)
    eval "$PKG_INSTALL software-properties-common"
    add-apt-repository -y universe
    eval "$PKG_UPDATE" || true
    eval "$PKG_INSTALL hyprland wayvnc xwayland kitty waybar pulseaudio git" || \
      echo "Warning: hyprland unavailable for Ubuntu ${VERSION_CODENAME}" >&2
    ;;
  fedora)
    dnf copr enable -y solopasha/hyprland
    dnf install -y --allowerasing hyprland wayvnc xorg-x11-server-Xwayland kitty waybar pulseaudio git || \
      echo "Warning: hyprland unavailable for Fedora ${VERSION_ID}" >&2
    ;;
  alpine)
    apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing \
      hyprland wayvnc xwayland kitty waybar pulseaudio git
    ;;
esac

# Hyprland Config (来自 RDDocker) ----------------------------------
mkdir -p /root/.config/hypr
cat > /root/.config/hypr/hyprland.conf << 'CONF'
monitor=,1920x1080,0x0,1
CONF

# Startup Desktop (来自 RDDocker) ----------------------------------
cat >> /run.sh << 'EOF'
echo "Starting Hyprland..."
export XDG_RUNTIME_DIR=/tmp/xdg-runtime
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
export WLR_BACKENDS=headless
export WLR_RENDERER=pixman
export WLR_LIBINPUT_NO_DEVICES=1
nohup Hyprland &
sleep 3
nohup wayvnc 0.0.0.0 5900 &
EOF
de_finish 8
