#!/bin/bash
# KDE Plasma Desktop Environment (flag=2)
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/plasma.sh

set -e
# Dual-mode commons.sh loading: local file > remote CDN
if [ -f "$(dirname "$0")/commons.sh" ] && [ "$(dirname "$0")" != "." ]; then
    . "$(cd "$(dirname "$0")" && pwd)/commons.sh"
else
    _tmp_commons=$(mktemp)
    _commons_ok=0
    # Dual line: mainland edge -> overseas mirror -> raw GitHub, all time-bounded
    for _base in "https://pikash.pika.net.cn" "https://pikash.opkg.cn" "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"; do
        if curl -fsSL --connect-timeout 3 --max-time 20 "${_base}/Linux/Desktop/commons.sh" -o "$_tmp_commons" 2>/dev/null; then
            _commons_ok=1
            break
        fi
        if wget -q -T 20 -t 1 -O "$_tmp_commons" "${_base}/Linux/Desktop/commons.sh" 2>/dev/null; then
            _commons_ok=1
            break
        fi
    done
    if [ "$_commons_ok" -ne 1 ]; then
        echo "ERROR: Cannot load commons.sh" >&2
        rm -f "$_tmp_commons"
        exit 1
    fi
    . "$_tmp_commons"
    rm -f "$_tmp_commons"
fi

# Check
de_precheck "Plasma" "2"

# Plasma Desktop (来自 RDDocker) -----------------------------------
case "$OS_ID" in
    debian)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL pulseaudio kde-plasma-desktop git cmake nano vim"
        ;;
    ubuntu)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL software-properties-common"
        add-apt-repository -y ppa:kubuntu-ppa/backports 2>/dev/null || true
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL pulseaudio kubuntu-desktop git cmake nano vim" \
            || eval "$PKG_INSTALL pulseaudio kde-plasma-desktop git cmake nano vim"
        ;;
    fedora)
        eval "$PKG_INSTALL plasma-workspace plasma-nm cmake git"
        ;;
    arch|archos)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL pulseaudio plasma kde-applications cmake git"
        ;;
    alpine)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL pulseaudio plasma-desktop kde-applications-base cmake git"
        ;;
esac

# Startup Desktop (来自 RDDocker) ----------------------------------
cat >> /run.sh <<'EOF'
echo "Starting KDE Plasma Desktop..."
export DISPLAY=:9
systemctl disable sddm 2>/dev/null || true
service sddm stop 2>/dev/null; killall startplasma-x11 2>/dev/null || true
killall plasma_session 2>/dev/null; killall kwin_x11 2>/dev/null || true
nohup Xvfb :9 -ac -screen 0 1920x1080x24 &
sleep 1
eval $(dbus-launch --sh-syntax)
bash /x11vnc.sh
DISPLAY=:9 nohup plasma_session &
EOF
de_finish 2
