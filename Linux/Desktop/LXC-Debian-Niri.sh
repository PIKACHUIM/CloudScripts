#!/bin/bash
# Niri - Scrollable-tiling Wayland Compositor (flag=5)
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/nirios.sh

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

# Check (flag 5 = Niri, previously conflicted with Graphy's flag 9)
de_precheck "Niri" "5"

# Niri (来自 RDDocker) ---------------------------------------------
case "$OS_ID" in
  debian)
    echo "deb http://deb.debian.org/debian unstable main" > /etc/apt/sources.list.d/sid.list
    echo "deb http://deb.debian.org/debian experimental main" >> /etc/apt/sources.list.d/sid.list
    printf 'Package: *\nPin: release a=experimental\nPin-Priority: 1\nPackage: *\nPin: release a=unstable\nPin-Priority: 100\n' > /etc/apt/preferences.d/99sid
    eval "$PKG_UPDATE"
    apt-get install -y -t unstable --no-install-recommends niri 2>/dev/null || \
      apt-get install -y -t experimental --no-install-recommends niri 2>/dev/null || \
        echo "Warning: niri unavailable for Debian ${VERSION_CODENAME}" >&2
    apt-get install -y -t unstable --no-install-recommends -o Dpkg::Options::="--force-overwrite" foot waybar wofi xwayland weston pulseaudio \
      wayland-protocols swaybg fonts-noto fonts-noto-cjk
    rm /etc/apt/sources.list.d/sid.list /etc/apt/preferences.d/99sid
    ;;
  ubuntu)
    eval "$PKG_INSTALL software-properties-common"
    add-apt-repository -y universe
    eval "$PKG_UPDATE"
    eval "$PKG_INSTALL niri foot waybar wofi xwayland weston pulseaudio \
      wayland-protocols swaybg fonts-noto fonts-noto-cjk" 2>/dev/null || \
      eval "$PKG_INSTALL foot waybar wofi xwayland weston pulseaudio \
        wayland-protocols swaybg fonts-noto fonts-noto-cjk"
    ;;
  fedora)
    eval "$PKG_INSTALL niri foot waybar wofi xorg-x11-server-Xwayland weston"
    ;;
  arch|archos)
    eval "$PKG_UPDATE"
    eval "$PKG_INSTALL niri foot waybar wofi xorg-xwayland weston pulseaudio"
    ;;
  alpine)
    echo "Niri is not available on Alpine Linux" >&2; exit 1
    ;;
esac

# Startup Desktop (来自 RDDocker) ----------------------------------
cat >> /run.sh << 'EOF'
echo "Starting Niri Wayland..."
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR" && chmod 0700 "$XDG_RUNTIME_DIR"
export WAYLAND_DISPLAY=wayland-1
export NIRI_DISPLAY=wayland-1
nohup niri &
sleep 3
nohup wayvnc 0.0.0.0 5900 &
EOF
de_finish 5
