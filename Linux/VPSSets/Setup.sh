#!/bin/bash
# ============================================================
#  PIKA SH - 服务器部署脚本
#  交互式菜单，无密码验证，代理由用户自行配置
# ============================================================

clear
echo "======================================================="
echo "               PIKA SH 服务器部署脚本                  "
echo "======================================================="

# ---- CDN 地址 ----
GH_URL="https://ghproxy.vip/https://raw.githubusercontent.com"
GH_WEB="https://ghproxy.vip/https://github.com"
GH_API="https://ghproxy.vip/https://api.github.com"
GH_API_DIRECT="https://api.github.com"

# ---- 代理配置（由用户在主菜单设置） ----
PC_COMM=""
PROXY_CONFIGURED=false

# ============================================================
# 工具函数
# ============================================================

get_latest_github_tag() {
    local REPO="$1"; local TAG=""; local RAW
    echo "  [方法1] 直连GitHub API获取版本..." >&2
    RAW=$(curl -s --connect-timeout 10 --max-time 15 "${GH_API_DIRECT}/repos/${REPO}/releases/latest" 2>/dev/null)
    TAG=$(echo "$RAW" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | head -1)
    [ -n "$TAG" ] && [ "$TAG" != "null" ] && { echo "$TAG"; return 0; }
    echo "  [方法2] 代理访问GitHub API获取版本..." >&2
    RAW=$(${PC_COMM} curl -s --connect-timeout 10 --max-time 15 "${GH_API}/repos/${REPO}/releases/latest" 2>/dev/null)
    TAG=$(echo "$RAW" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | head -1)
    [ -n "$TAG" ] && [ "$TAG" != "null" ] && { echo "$TAG"; return 0; }
    echo "  [方法3] 解析重定向地址获取版本..." >&2
    local REDIR_URL
    REDIR_URL=$(curl -sI --connect-timeout 10 --max-time 15 "https://github.com/${REPO}/releases/latest" 2>/dev/null | grep -i "^location:" | sed 's/.*\///' | tr -d '\r\n')
    [ -n "$REDIR_URL" ] && [ "$REDIR_URL" != "releases" ] && { TAG=$(echo "$REDIR_URL" | grep -oE '[^/]+$'); echo "$TAG"; return 0; }
    echo ""; return 1
}

download_github_file() {
    local URL_PATH="$1" SAVE_NAME="$2" REPO="${3:-}"
    local MAIN_URL="${GH_WEB}/${URL_PATH}"
    echo "  尝试下载: ${MAIN_URL}"
    ${PC_COMM} wget -O "${SAVE_NAME}" "${MAIN_URL}" 2>&1
    if [ $? -eq 0 ] && [ -f "${SAVE_NAME}" ] && [ -s "${SAVE_NAME}" ]; then return 0; fi
    if [ -n "$REPO" ]; then
        local FALLBACK_URL="https://github.com/${URL_PATH}"
        echo "  主下载失败，尝试备用: ${FALLBACK_URL}"
        ${PC_COMM} curl -L --connect-timeout 30 --max-time 120 -o "${SAVE_NAME}" "${FALLBACK_URL}" 2>/dev/null
        [ $? -eq 0 ] && [ -f "${SAVE_NAME}" ] && [ -s "${SAVE_NAME}" ] && return 0
    fi
    return 1
}

# ============================================================
# 安装子函数
# ============================================================

setup_hostname() {
    echo -n "请输入新主机名: "; read HS_DAT
    if [ "$HS_DAT" ]; then
        hostnamectl set-hostname ${HS_DAT}
        echo "127.0.0.1 ${HS_DAT}" >> /etc/hosts
        echo "主机名已设置为: ${HS_DAT}"
    fi
}

setup_system() {
    echo "正在更新系统并安装基础工具..."
    apt update && apt upgrade -y && apt install -y curl wget nano sudo
    apt install -y unzip htop git openssl vim
    echo "系统基础工具安装完成。"
}

# 代理配置（交互式输入）
setup_proxychains() {
    echo ""
    echo "================================================"
    echo "            配置 ProxyChains4 代理              "
    echo "================================================"
    echo -n "是否配置 SOCKS5 代理? (y/N): "; read USE_PROXY
    if [ "$USE_PROXY" != "y" ] && [ "$USE_PROXY" != "Y" ]; then
        PC_COMM=""
        PROXY_CONFIGURED=false
        echo "未配置代理。"
        return 0
    fi
    echo ""
    read -p "  代理主机 (IP/域名): " PROXY_HOST
    read -p "  代理端口: " PROXY_PORT
    read -p "  认证用户名: " PROXY_USER
    read -rsp "  认证密码: " PROXY_PASS; echo
    if [ -z "$PROXY_HOST" ] || [ -z "$PROXY_PORT" ]; then
        echo "代理配置不完整，已跳过。"
        return 1
    fi
    local PROXY_AUTH=""
    [ -n "$PROXY_USER" ] && PROXY_AUTH="${PROXY_USER}:${PROXY_PASS}@"
    local IP_ADDR; IP_ADDR=$(getent hosts ${PROXY_HOST} 2>/dev/null | awk '{print $1}')
    [ -z "$IP_ADDR" ] && IP_ADDR="$PROXY_HOST"
    PC_COMM="proxychains"
    PROXY_CONFIGURED=true
    cat > /etc/proxychains.conf << EOF
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000
[ProxyList]
socks5 ${IP_ADDR} ${PROXY_PORT} ${PROXY_USER} ${PROXY_PASS}
EOF
    echo "ProxyChains4 已配置: socks5://${IP_ADDR}:${PROXY_PORT}"
}

setup_nodejs() {
    echo -n "是否安装 NodeJS LTS? (y/N): "; read INSTALL_NODEJS
    [ "$INSTALL_NODEJS" != "y" ] && return 0
    git clone https://gitee.com/mirrors/nvm.git ~/.nvm && cd ~/.nvm && git checkout `git describe --abbrev=0 --tags`
    echo ". ~/.nvm/nvm.sh" >> ~/.bashrc
    source ~/.bashrc
    export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
    nvm install --lts; nvm use --lts
    node -v && npm -v
    npm config set registry https://registry.npmmirror.com
    npm install pm2 -g
    echo "NodeJS LTS 及 PM2 安装完成。"
}

setup_baota() {
    echo -n "是否安装宝塔面板? (y/N): "; read INSTALL_BAOTA
    [ "$INSTALL_BAOTA" != "y" ] && return 0
    read -p "  请输入宝塔用户名 (默认 pikachu): " BT_USER; BT_USER=${BT_USER:-pikachu}
    read -rsp "  请输入宝塔密码: " BT_PSA; echo
    [ -z "$BT_PSA" ] && BT_PSA="pikachu123"
    BT_URL="https://download.bt.cn/install/install_panel.sh"
    wget -O install_panel.sh ${BT_URL}
    echo -e "y\n" | bash install_panel.sh ed8484bec
    echo -e "bt\n26\n" | bash
    echo -e "bt\n6\n${BT_USER}\n" | bash
    echo -e "bt\n8\n1888\n" | bash
    echo "宝塔面板密码: ${BT_PSA}"
    echo -e "bt\n5\n${BT_PSA}\n" | bash
    rm -f /www/server/panel/data/admin_path.pl
    echo -e "bt\n14\n" | bash
    echo "宝塔面板安装完成。"
}

setup_nezha() {
    echo -n "是否安装哪吒面板? (y/N): "; read INSTALL_NEZHA
    [ "$INSTALL_NEZHA" != "y" ] && return 0
    read -p "  请输入哪吒服务端地址 (如 nz.example.com): " NZ_SERVER
    read -rsp "  请输入哪吒客户端密钥: " NZ_SECRET; echo
    if [ -z "$NZ_SERVER" ] || [ -z "$NZ_SECRET" ]; then
        echo "哪吒配置不完整，已跳过。"
        return 1
    fi
    NZ_URL="${GH_URL}/nezhahq/scripts/main/agent/install.sh"
    ${PC_COMM} curl -L ${NZ_URL} -o agent.sh && chmod +x agent.sh
    env NZ_SERVER=${NZ_SERVER} NZ_TLS=true NZ_CLIENT_SECRET=${NZ_SECRET} ${PC_COMM} ./agent.sh
    echo "哪吒面板安装完成。"
}

setup_3xui() {
    echo -n "是否安装3XUI面板? (y/N): "; read INSTALL_3XUI
    [ "$INSTALL_3XUI" != "y" ] && return 0
    mkdir -p /etc/xui
    openssl req -x509 -newkey rsa:2048 -keyout /etc/xui/key.pem -out /etc/xui/crt.pem -days 365 -nodes -subj "/CN=${HS_DAT:-pikash}"
    TMP_SCRIPT="/tmp/3x-ui-install.sh"
    ${PC_COMM} curl -Ls "${GH_URL}/mhsanaei/3x-ui/master/install.sh" -o "${TMP_SCRIPT}"
    chmod +x "${TMP_SCRIPT}"
    sed -i "s|https://raw.githubusercontent.com|${GH_URL}|g" "${TMP_SCRIPT}"
    sed -i "s|https://github.com|${GH_WEB}|g" "${TMP_SCRIPT}"
    echo -e "y\n1090\n3\n/etc/xui/crt.pem\n/etc/xui/key.pem\n" | ${PC_COMM} bash "${TMP_SCRIPT}"
    echo "3XUI面板安装完成。"
}

setup_easytier() {
    # $1 = "nocfg" 时跳过询问直接安装二进制（供 Menu.sh 配置管理调用）
    local NOCFG="$1"
    if [ "$NOCFG" != "nocfg" ]; then
        echo -n "是否安装EasyTier? (y/N): "; read INSTALL_ET
        [ "$INSTALL_ET" != "y" ] && return 0
    fi
    # 若已安装则跳过下载
    if [ -f /bin/easytier-core ]; then
        echo "EasyTier 已安装 (/bin/easytier-core)。"
    else
        ET_TAG=$(get_latest_github_tag "EasyTier/EasyTier")
        [ -z "$ET_TAG" ] && { echo "无法获取EasyTier版本，已跳过。"; return 1; }
        echo "获取到最新的ET版本: ${ET_TAG}"
        ET_FILE="easytier-linux-x86_64-${ET_TAG}.zip"
        download_github_file "EasyTier/EasyTier/releases/download/${ET_TAG}/${ET_FILE}" "${ET_FILE}" "EasyTier/EasyTier"
        if [ -f "${ET_FILE}" ] && [ -s "${ET_FILE}" ]; then
            unzip -o "${ET_FILE}"
            chmod -R +x easytier-linux-x86_64
            mv easytier-linux-x86_64/* /bin/
            rm -f "${ET_FILE}"; rm -rf easytier-linux-x86_64
            echo "ET 二进制安装完成 (/bin/easytier-core)。"
        else
            echo "ET安装失败。"
            return 1
        fi
    fi
    # 组网配置从配置文件读取（在 Menu.sh 的“代理配置 → EasyTier 组网配置”中管理）
    local ET_CONF_FILE="/etc/pikash/easytier.conf"
    if [ "$NOCFG" = "nocfg" ]; then
        echo "二进制已就绪，请在“代理配置 → EasyTier 组网配置”中添加并应用配置。"
        return 0
    fi
    if [ -s "$ET_CONF_FILE" ]; then
        local ARGS=""
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            ARGS="$ARGS --config-server $line"
        done < "$ET_CONF_FILE"
        pm2 delete easytier 2>/dev/null || true
        pm2 start /bin/easytier-core --name easytier -- $ARGS
        pm2 save
        echo "ET 服务已按配置文件启动。"
    else
        echo "未检测到组网配置，请在“代理配置 → EasyTier 组网配置”中添加。"
    fi
}

setup_frps() {
    echo -n "是否设置FRPS服务? (y/N): "; read INSTALL_FRPS
    [ "$INSTALL_FRPS" != "y" ] && return 0
    read -p "  请输入 FRP API 地址: " FRP_API
    read -p "  请输入 FRP RPC 地址: " FRP_RPC
    FRP_TAG=$(get_latest_github_tag "VaalaCat/frp-panel")
    [ -z "$FRP_TAG" ] && { echo "无法获取frp-panel版本，已跳过。"; return 1; }
    echo "获取到最新的frp-panel版本: ${FRP_TAG}"
    download_github_file "VaalaCat/frp-panel/releases/download/${FRP_TAG}/frp-panel-linux-amd64" "frp-panel" "VaalaCat/frp-panel"
    if [ -f "frp-panel" ] && [ -s "frp-panel" ]; then
        mv frp-panel /bin/frp-panel; chmod +x /bin/frp-panel
        echo "请输入服务器名称(NN_FRP):"; read NN_FRP
        echo "请输入节点UUID(TK_FRP):"; read TK_FRP
        pm2 start /bin/frp-panel --name frps -- server -s ${TK_FRP} -i ${NN_FRP} --api-url ${FRP_API} --rpc-url ${FRP_RPC}
        pm2 save
        echo "FRPS服务安装完成。"
    else
        echo "FRPS安装失败。"
    fi
}

# 端口限速
parse_ports() {
    local INPUT="$1"; local RESULT=()
    local IFS_OLD="$IFS"; IFS=' ,;，；'; read -ra TOKENS <<< "$INPUT"; IFS="$IFS_OLD"
    for TOKEN in "${TOKENS[@]}"; do
        TOKEN=$(echo "$TOKEN" | xargs); [ -z "$TOKEN" ] && continue
        if [[ "$TOKEN" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local START=${BASH_REMATCH[1]} END=${BASH_REMATCH[2]}
            [ "$START" -le "$END" ] && [ "$START" -ge 1 ] && [ "$END" -le 65535 ] && for ((p=START; p<=END; p++)); do RESULT+=($p); done
        elif [[ "$TOKEN" =~ ^[0-9]+$ ]]; then
            [ "$TOKEN" -ge 1 ] && [ "$TOKEN" -le 65535 ] && RESULT+=($TOKEN)
        fi
    done
    echo "${RESULT[*]}"
}
parse_rate() { local R="$1"; R=$(echo "$R" | xargs | tr '[:upper:]' '[:lower:]'); [[ "$R" =~ ^[0-9]+(kbit|mbit|gbit)$ ]] && echo "$R" || echo ""; }

setup_rate_limit() {
    local IFACE; IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    echo ""; echo "端口限速配置"
    echo "格式: 1040 1041-1043 1050 (空格/逗号/分号分隔)"
    echo -n "请输入需要限速的端口 (默认 1040 1041 1042): "; read RAW_PORTS
    RAW_PORTS=${RAW_PORTS:-"1040 1041 1042"}
    local PORTS_ARRAY=($(parse_ports "$RAW_PORTS"))
    [ ${#PORTS_ARRAY[@]} -eq 0 ] && { echo "没有有效端口，跳过。"; return 1; }
    echo "端口列表: ${PORTS_ARRAY[*]}"
    echo -n "请输入限速值 (如 1mbit, 512kbit, 默认 1mbit): "; read RAW_RATE
    RAW_RATE=${RAW_RATE:-1mbit}
    local RATE; RATE=$(parse_rate "$RAW_RATE"); [ -z "$RATE" ] && RATE="1mbit"
    echo "确认: 网卡=${IFACE} 端口=${PORTS_ARRAY[*]} 限速=${RATE}"
    echo -n "确认应用? (y/N): "; read RL_CONFIRM
    [ "$RL_CONFIRM" != "y" ] && [ "$RL_CONFIRM" != "Y" ] && { echo "已取消。"; return 0; }
    tc qdisc del dev ${IFACE} root 2>/dev/null; tc qdisc del dev ${IFACE} ingress 2>/dev/null
    ip link set ifb0 down 2>/dev/null; ip link del ifb0 2>/dev/null
    tc qdisc add dev ${IFACE} root handle 1: htb default 999
    tc class add dev ${IFACE} parent 1: classid 1:999 htb rate 1000mbit
    tc class add dev ${IFACE} parent 1: classid 1:10 htb rate ${RATE} ceil ${RATE}
    for PORT in "${PORTS_ARRAY[@]}"; do
        tc filter add dev ${IFACE} parent 1: protocol ip u32 match ip dport ${PORT} 0xffff flowid 1:10
        tc filter add dev ${IFACE} parent 1: protocol ip u32 match ip sport ${PORT} 0xffff flowid 1:10
    done
    modprobe ifb 2>/dev/null; ip link add ifb0 type ifb 2>/dev/null; ip link set ifb0 up
    tc qdisc add dev ${IFACE} ingress
    tc filter add dev ${IFACE} parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0
    tc qdisc add dev ifb0 root handle 2: htb default 999
    tc class add dev ifb0 parent 2: classid 2:999 htb rate 1000mbit
    tc class add dev ifb0 parent 2: classid 2:10 htb rate ${RATE} ceil ${RATE}
    for PORT in "${PORTS_ARRAY[@]}"; do
        tc filter add dev ifb0 parent 2: protocol ip u32 match ip dport ${PORT} 0xffff flowid 2:10
        tc filter add dev ifb0 parent 2: protocol ip u32 match ip sport ${PORT} 0xffff flowid 2:10
    done
    echo "端口限速已启用: ${PORTS_ARRAY[*]} 限速 ${RATE}"
}

setup_rate_limit_menu() {
    echo -n "是否配置端口限速? (y/N): "; read INSTALL_RATELIMIT
    [ "$INSTALL_RATELIMIT" = "y" ] && setup_rate_limit
}

# RustDesk 中转
setup_rustdesk() {
    echo -n "是否安装 RustDesk 中转服务? (y/N): "; read INSTALL_RD
    [ "$INSTALL_RD" != "y" ] && return 0
    read -p "hbbs 端口 (默认 21116): " RD_HBBS_PORT; RD_HBBS_PORT=${RD_HBBS_PORT:-21116}
    read -p "hbbr 端口 (默认 21117): " RD_HBBR_PORT; RD_HBBR_PORT=${RD_HBBR_PORT:-21117}
    read -p "Web控制台端口 (默认 21118): " RD_WEB_PORT; RD_WEB_PORT=${RD_WEB_PORT:-21118}
    echo -n "确认继续? (y/N): "; read RD_CONFIRM
    [ "$RD_CONFIRM" != "y" ] && { echo "已取消。"; return 0; }
    local ARCH; ARCH=$(uname -m)
    case "$ARCH" in x86_64) RD_ARCH="x86_64" ;; aarch64) RD_ARCH="aarch64" ;; *) echo "不支持的架构"; return 1 ;; esac
    RD_TAG=$(get_latest_github_tag "rustdesk/rustdesk-server")
    [ -z "$RD_TAG" ] && RD_TAG="nightly"
    echo "RustDesk-Server 版本: ${RD_TAG}"
    local RD_DIR="/opt/rustdesk"; mkdir -p ${RD_DIR}; cd ${RD_DIR}
    ${PC_COMM} wget -O rustdesk-server-hbbs.deb "${GH_WEB}/rustdesk/rustdesk-server/releases/download/${RD_TAG}/rustdesk-server-hbbs_${RD_ARCH}.deb" 2>&1
    ${PC_COMM} wget -O rustdesk-server-hbbr.deb "${GH_WEB}/rustdesk/rustdesk-server/releases/download/${RD_TAG}/rustdesk-server-hbbr_${RD_ARCH}.deb" 2>&1
    if [ -f "rustdesk-server-hbbs.deb" ] && [ -s "rustdesk-server-hbbs.deb" ]; then
        dpkg -i rustdesk-server-hbbs.deb rustdesk-server-hbbr.deb 2>/dev/null; apt install -f -y 2>/dev/null
        cat > /etc/systemd/system/rustdesk-hbbs.service << EOF
[Unit]
Description=RustDesk HBBS; After=network.target
[Service]; Type=simple; LimitNOFILE=1000000
ExecStart=/usr/bin/hbbs -k _ -r ${HS_DAT}:${RD_HBBR_PORT} --port ${RD_HBBS_PORT}
WorkingDirectory=/var/lib/rustdesk-server/
StandardOutput=append:/var/log/rustdesk-hbbs.log
StandardError=append:/var/log/rustdesk-hbbs.log; Restart=always; RestartSec=10
[Install]; WantedBy=multi-user.target
EOF
        cat > /etc/systemd/system/rustdesk-hbbr.service << EOF
[Unit]
Description=RustDesk HBBR; After=network.target
[Service]; Type=simple; LimitNOFILE=1000000
ExecStart=/usr/bin/hbbr -k _ --port ${RD_HBBR_PORT}
WorkingDirectory=/var/lib/rustdesk-server/
StandardOutput=append:/var/log/rustdesk-hbbr.log
StandardError=append:/var/log/rustdesk-hbbr.log; Restart=always; RestartSec=10
[Install]; WantedBy=multi-user.target
EOF
        systemctl daemon-reload; systemctl enable rustdesk-hbbs rustdesk-hbbr; systemctl start rustdesk-hbbs rustdesk-hbbr
        echo "RustDesk 安装完成! 公钥: /var/lib/rustdesk-server/id_ed25519.pub"
        rm -f rustdesk-server-hbbs.deb rustdesk-server-hbbr.deb
    else
        echo "RustDesk 下载失败。"
    fi
    cd - > /dev/null
}

setup_zerotier() {
    echo -n "是否安装 ZeroTier? (y/N): "; read INSTALL_ZT
    [ "$INSTALL_ZT" != "y" ] && return 0
    curl -s https://install.zerotier.com | bash
    echo -n "是否加入网络? (y/N): "; read ZT_JOIN
    [ "$ZT_JOIN" = "y" ] && { read -p "Network ID: " ZT_NETID; zerotier-cli join ${ZT_NETID}; }
    echo "ZeroTier 安装完成。"
}

setup_tailscale() {
    echo -n "是否安装 Tailscale? (y/N): "; read INSTALL_TS
    [ "$INSTALL_TS" != "y" ] && return 0
    curl -fsSL https://tailscale.com/install.sh | sh
    echo "1)标准 2)出口节点 3)子网路由"; read -p "模式 (1-3, 默认1): " TS_MODE; TS_MODE=${TS_MODE:-1}
    local ARGS=""
    case "$TS_MODE" in 2) ARGS="--advertise-exit-node" ;; 3) read -p "子网: " TS_SUBNET; ARGS="--advertise-routes=${TS_SUBNET}" ;; esac
    tailscale up ${ARGS} 2>/dev/null
    echo "Tailscale 安装完成。"
}

# ============================================================
# 菜单系统
# ============================================================

show_menu() {
    echo ""
    echo "================================================"
    echo "            PIKA SH 服务器部署菜单               "
    echo "================================================"
    if $PROXY_CONFIGURED; then
        echo "  代理状态: 已配置 (socks5://${PROXY_HOST:-?}:${PROXY_PORT:-?})"
    else
        echo "  代理状态: 未配置"
    fi
    echo "================================================"
    echo "  基础设置:"
    echo "    [0]  设置主机名"
    echo "    [1]  系统更新 + 基础工具"
    echo "    [P]  配置/修改代理 (ProxyChains4)"
    echo ""
    echo "  开发环境:"
    echo "    [3]  安装 NodeJS LTS + PM2"
    echo ""
    echo "  面板/管理:"
    echo "    [4]  安装宝塔面板"
    echo "    [5]  安装哪吒面板"
    echo "    [6]  安装 3XUI 面板"
    echo "    [7]  安装 EasyTier (ET, 组网配置在代理配置中管理)"
    echo "    [8]  安装 FRPS 服务"
    echo ""
    echo "  端口限速:"
    echo "    [9]  配置端口限速"
    echo ""
    echo "  组网/中转:"
    echo "    [A]  安装 RustDesk 中转服务"
    echo "    [B]  安装 ZeroTier"
    echo "    [C]  安装 Tailscale"
    echo ""
    echo "  批量部署:"
    echo "    [ALL] 一键部署全部服务（交互确认）"
    echo ""
    echo "    [Q]  退出"
    echo "================================================"
    echo -n "请输入选项 (多个用空格分隔): "
}

run_all() {
    echo "[全部部署模式] 将依次询问每个组件..."
    setup_hostname; setup_system; setup_proxychains
    setup_nodejs; setup_baota; setup_nezha; setup_3xui
    setup_easytier; setup_frps; setup_rate_limit_menu
    setup_rustdesk; setup_zerotier; setup_tailscale
}

process_choice() {
    local CHOICE="$1"
    case "$CHOICE" in
        0)   setup_hostname ;;
        1)   setup_system ;;
        2|P|p) setup_proxychains ;;
        3)   setup_nodejs ;;
        4)   setup_baota ;;
        5)   setup_nezha ;;
        6)   setup_3xui ;;
        7)   setup_easytier ;;
        7nocfg) setup_easytier nocfg ;;
        8)   setup_frps ;;
        9)   setup_rate_limit_menu ;;
        A|a) setup_rustdesk ;;
        B|b) setup_zerotier ;;
        C|c) setup_tailscale ;;
        ALL|all|All) run_all ;;
        Q|q) echo "退出脚本。"; exit 0 ;;
        *)   echo "无效选项: $CHOICE，跳过。" ;;
    esac
}

# ============================================================
# 主流程
# ============================================================

PC_COMM=""
PROXY_CONFIGURED=false

if [ $# -gt 0 ]; then
    for ARG in "$@"; do process_choice "$ARG"; done
    echo ""; echo "部署完成！"; exit 0
fi

while true; do
    show_menu
    read -a CHOICES
    [ ${#CHOICES[@]} -eq 0 ] && continue
    for CH in "${CHOICES[@]}"; do process_choice "$CH"; done
    echo ""; echo -n "当前批次执行完毕。是否继续? (y/N): "; read CONTINUE
    [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ] && break
done
echo ""; echo "部署完成！感谢使用 PIKA SH。"
