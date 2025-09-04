#!/bin/bash
# Check -----------------------------------------------------------
file="/etc/lxc-de-flag"
set -e
if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Server.sh | bash -e
	apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e
else
    read -r content < "$file"      # 去掉前后空白，只读第一行
    case "$content" in
        0) apt -y install curl && curl https://gh-bat.pika.net.cn/Linux/Desktop/LXC-Debian-Graphy.sh | bash -e ;;
        9) echo "检查通过，开始安装桌面....." ;;
        *) echo "已经安装过桌面，禁止重复安装" && exit ;;
    esac
fi

# Lingmo ------------------------------------------------------
UR="deb https://download.opensuse.org/repositories/home:"
DE="${UR}/elysia:/LingmoOS/Debian_12/ ./"
KR="https://build.opensuse.org/projects/home:"
KF="${KR}elysia:LingmoOS/signing_keys/download?kind=gpg"
echo ${DE} >> /etc/apt/sources.list                  ||echo 1
apt -y install wget gnupg2 nano vim openssl curl git ||echo 3
wget ${KF} -O /etc/apt/trusted.gpg.d/lingmo.asc      ||echo 4
apt update &&DEBIAN_FRONTEND=noninteractive apt install -y \
    lingmo-workspace-base psmisc
cat > /lingmo.sh <<'EOF'
#!/usr/bin/env bash
#------------------
set_session_env() {
    SESSION_2="lingmo-session"

    # Adding dbus-launch may cause problems with vscode.
    #
    DBUS_CMD="dbus-launch"

    [[ ! -s /etc/environment ]] || source /etc/environment
    # /run/user/$UID
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

EOF
chmod 755 /lingmo.sh


# X11RDP ------------------------------------------------------ 
update-alternatives --set x-session-manager /lingmo.sh

# Startup Desktop ---------------------------------------------
echo 'echo Starting Desktop Runtime -----------' >> /run.sh
echo 'export DISPLAY=:9 &&export $(dbus-launch)' >> /run.sh
echo 'nohup Xvfb :9 -ac -screen 0 1600x900x24 &' >> /run.sh
echo 'nohup /lingmo.sh & && killall lingmo-dock' >> /run.sh
echo 3 > /etc/lxc-de-flag