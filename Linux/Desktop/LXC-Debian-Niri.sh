#!/bin/bash
# Niri - Scrollable-tiling Wayland Compositor
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/nirios.sh

set -e
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$INSTALL_DIR/commons.sh"

# Check -----------------------------------------------------------
file="/etc/lxc-de-flag"
if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e
else
    read -r content < "$file"
    case "$content" in
        0) apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e ;;
        9) echo "检查通过，开始安装 Niri 桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

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
echo 9 > /etc/lxc-de-flag
