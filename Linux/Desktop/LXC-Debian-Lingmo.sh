#!/bin/bash
# Lingmo Desktop Environment (flag=3)
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/lingmo.sh

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
de_precheck "Lingmo" "3"

# Lingmo Desktop (来自 RDDocker) -----------------------------------
case "$OS_ID" in
    debian|ubuntu)
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL ca-certificates apt-transport-https curl"
        curl -fsSL https://repo.lingmo.org/lingmo-os/key.gpg \
          | gpg --dearmor -o /usr/share/keyrings/lingmo.gpg 2>/dev/null || true
        echo "deb [signed-by=/usr/share/keyrings/lingmo.gpg] https://repo.lingmo.org/lingmo-os ${VERSION_CODENAME:-bookworm} main" \
          > /etc/apt/sources.list.d/lingmo.list 2>/dev/null || true
        eval "$PKG_UPDATE" || true
        eval "$PKG_INSTALL lingmo-desktop pulseaudio 2>/dev/null || \
            $PKG_INSTALL lingmo-core lingmo-workspace-base pulseaudio"
        ;;
esac

# de-lingmo.sh helper (来自 RDDocker configs/de-lingmo.sh) ----------
cat > /usr/local/bin/de-lingmo.sh <<'LINGMO'
#!/usr/bin/env bash
set_session_env() {
  SESSION_2="lingmo-session"
  [[ ! -s /etc/environment ]] || source /etc/environment
  [[ -n ${XDG_RUNTIME_DIR} ]] || export XDG_RUNTIME_DIR=/tmp/runtime-${UID}
  [[ -e ${XDG_RUNTIME_DIR} ]] || mkdir -pv ${XDG_RUNTIME_DIR}
}
start_session() {
  for i in ${SESSION_2}; do
    if [[ -n $(command -v $i) ]]; then
      exec ${DBUS_CMD} ${i} ${@}
      break
    fi
  done
}
set_session_env
start_session ${@}
LINGMO
chmod +x /usr/local/bin/de-lingmo.sh

# Startup Desktop (来自 RDDocker) ----------------------------------
cat >> /run.sh <<'EOF'
echo "Starting Lingmo Desktop..."
export DISPLAY=:9
nohup Xvfb :9 -ac -screen 0 1920x1080x24 &
sleep 1
eval $(dbus-launch --sh-syntax)
bash /x11vnc.sh DISPLAY=:9
nohup /usr/local/bin/de-lingmo.sh &
EOF
de_finish 3
