#!/bin/bash
# MATE Desktop Environment (flag=7, 保留原有脚本，RDDocker 未提供 MATE 版本)

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
de_precheck "MATE" "7"

# MATE Desktop -----------------------------------------------------
case "$OS_ID" in
    debian|ubuntu)
        eval "$PKG_INSTALL task-mate-desktop mate-desktop-environment-extras"
        ;;
    fedora)
        eval "$PKG_INSTALL @mate-desktop mate-applications"
        ;;
    arch|archos)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL mate mate-extra"
        ;;
    alpine)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL mate-desktop mate-desktop-environment"
        ;;
esac

# Startup Desktop --------------------------------------------------
cat >> /run.sh <<'EOF'
echo "Starting MATE Desktop..."
export DISPLAY=:9
nohup Xvfb :9 -ac -screen 0 1920x1080x24 &
sleep 1
eval $(dbus-launch --sh-syntax)
bash /x11vnc.sh
DISPLAY=:9 nohup mate-session &
EOF
de_finish 7
