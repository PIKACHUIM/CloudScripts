#!/bin/bash
# Lingmo Desktop Environment
# 基于 RDDocker: https://github.com/PIKACHUIM/RDDocker/blob/master/scripts/install/desktop/lingmo.sh

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
        9) echo "检查通过，开始安装 Lingmo 桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

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
echo 3 > /etc/lxc-de-flag
