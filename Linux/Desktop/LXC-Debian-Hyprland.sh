#!/bin/bash
# Hyprland Wayland Compositor
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/hyland.sh

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
        9) echo "检查通过，开始安装 Hyprland 桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

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
echo 8 > /etc/lxc-de-flag
