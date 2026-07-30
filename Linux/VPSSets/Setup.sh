#!/bin/bash
# ============================================================
# 敏感信息已使用 AES-256-CBC + PBKDF2 加密存储（BASE64）
# 运行前需输入正确密码，密码错误将退出
# 如需重新生成加密值，请运行同目录下的 Vault.sh
# ============================================================

# 验证密码
clear
echo "======================================================="
echo "                皮卡丘服务器部署脚本                   "
echo "======================================================="
echo -n "请输入部署密码: "
read _PASS
echo
_dec() {
    local _OUT
    _OUT=$(echo "$1" | openssl enc -aes-256-cbc -pbkdf2 -d -a -pass pass:"${_PASS}" 2>/dev/null)
    [ $? -eq 0 ] && echo "$_OUT" || echo ""
}

# ---- 加密的敏感信息（使用 Vault.sh 生成） ----
ENC_PROXY_AUTH=U2FsdGVkX19nQItQVnIlhqIDn7QBNXcEEVmmzKrw75c=
ENC_PROXY_HOST=U2FsdGVkX18liVs/yQuAVy8jX4CkvyrrezcCIBk+tu56uX5OvFrMpCwSOBo93vaE
ENC_PROXY_PORT=U2FsdGVkX1/wt/E/YrrhMrxpRXJqaGbTJcnTutFoV9Q=
ENC_NZ_SERVER=U2FsdGVkX1++Diwgc0zDxWgmZiXFVce1dJbKPWWk1OlNYMIcijWvBOX20QGNd2y4
ENC_NZ_SECRET=U2FsdGVkX1+DK04DIWFSdtt5eMhdj6sGzxkVYIHpi+Ce6JH66hGsxefEZXd4ZMkQgrRvapMgRBbvIdNE4WbV6g==
ENC_ET_CONFIG=U2FsdGVkX18l+6Zvp8NZnEdwc5PrHNHXCGu+dNozGtoQgfed79x+GrnXS3fVLHMH8dszQsi4goh2lEXVlTMJ+A==
ENC_FRP_API=U2FsdGVkX1/Zs4A6aCNDCZKnJQxAn6uVtRIcDEXQt9rXxJBiZqrAb28SWHoidBux
ENC_FRP_RPC=U2FsdGVkX197mHbNRp8pvPrqhRgtCtHd50+IwctOQFm+Dh8CQHoiQIouYZKYog9y
ENC_BT_PSA=U2FsdGVkX18eTiR3FA15eObj37N1NRvi6XD5Zr6VcCo=
ENC_BT_USER=U2FsdGVkX1+tDXq2/0OGpeOeZxoK9JQRZ9YEpwsy5PI=

# 验证密码（解密ET配置作为校验）
_TEST=$(_dec "$ENC_ET_CONFIG")
if [ -z "$_TEST" ]; then
    echo "密码错误，退出！"
    exit 1
fi

# 解密所有敏感变量
PROXY_AUTH=$(_dec "$ENC_PROXY_AUTH")
PROXY_HOST=$(_dec "$ENC_PROXY_HOST")
PROXY_PORT=$(_dec "$ENC_PROXY_PORT")
NZ_SERVER=$(_dec "$ENC_NZ_SERVER")
NZ_SECRET=$(_dec "$ENC_NZ_SECRET")
ET_CONFIG=$(_dec "$ENC_ET_CONFIG")
FRP_API=$(_dec "$ENC_FRP_API")
FRP_RPC=$(_dec "$ENC_FRP_RPC")
BT_PSA=$(_dec "$ENC_BT_PSA")
BT_USER=$(_dec "$ENC_BT_USER")

GH_URL="https://ghproxy.vip/https://raw.githubusercontent.com"
GH_WEB="https://ghproxy.vip/https://github.com"
GH_API="https://ghproxy.vip/https://api.github.com"
# 直连备用（部分API走proxy可能不工作）
GH_API_DIRECT="https://api.github.com"


# ============================================================
# 工具函数
# ============================================================

# 多方式获取GitHub最新Release版本号
# 参数: owner/repo
# 返回: tag_name (如 v1.2.3)
get_latest_github_tag() {
    local REPO="$1"
    local TAG=""
    local RAW

    # 方法1: 直连GitHub API（最可靠）
    echo "  [方法1] 直连GitHub API获取版本..."
    RAW=$(curl -s --connect-timeout 10 --max-time 15 \
        "${GH_API_DIRECT}/repos/${REPO}/releases/latest" 2>/dev/null)
    TAG=$(echo "$RAW" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | head -1)
    if [ -n "$TAG" ] && [ "$TAG" != "null" ]; then
        echo "$TAG"
        return 0
    fi

    # 方法2: 通过代理访问GitHub API
    echo "  [方法2] 代理访问GitHub API获取版本..."
    RAW=$(${PC_COMM} curl -s --connect-timeout 10 --max-time 15 \
        "${GH_API}/repos/${REPO}/releases/latest" 2>/dev/null)
    TAG=$(echo "$RAW" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | head -1)
    if [ -n "$TAG" ] && [ "$TAG" != "null" ]; then
        echo "$TAG"
        return 0
    fi

    # 方法3: 从GitHub releases/latest重定向地址解析版本
    echo "  [方法3] 解析重定向地址获取版本..."
    local REDIR_URL
    REDIR_URL=$(curl -sI --connect-timeout 10 --max-time 15 \
        "https://github.com/${REPO}/releases/latest" 2>/dev/null \
        | grep -i "^location:" | sed 's/.*\///' | tr -d '\r' | tr -d '\n')
    if [ -n "$REDIR_URL" ] && [ "$REDIR_URL" != "releases" ]; then
        # location通常是 /owner/repo/releases/tag/v1.2.3
        TAG=$(echo "$REDIR_URL" | grep -oE '[^/]+$')
        echo "$TAG"
        return 0
    fi

    # 方法4: 通过代理页面解析
    echo "  [方法4] 通过代理页面解析版本..."
    REDIR_URL=$(curl -sI --connect-timeout 10 --max-time 15 \
        "${GH_WEB}/${REPO}/releases/latest" 2>/dev/null \
        | grep -i "^location:" | sed 's/.*\///' | tr -d '\r' | tr -d '\n')
    if [ -n "$REDIR_URL" ] && [ "$REDIR_URL" != "releases" ]; then
        TAG=$(echo "$REDIR_URL" | grep -oE '[^/]+$')
        echo "$TAG"
        return 0
    fi

    # 方法5: 使用ghproxy API间接获取
    echo "  [方法5] 备用代理API获取版本..."
    RAW=$(curl -s --connect-timeout 10 --max-time 15 \
        "https://ghproxy.vip/${GH_API_DIRECT}/repos/${REPO}/releases/latest" 2>/dev/null)
    TAG=$(echo "$RAW" | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | head -1)
    if [ -n "$TAG" ] && [ "$TAG" != "null" ]; then
        echo "$TAG"
        return 0
    fi

    # 全部失败
    echo ""
    return 1
}

# 从GitHub下载文件（带重试和备用URL）
# 参数: url_path(GitHub release路径相对部分), save_name, [owner/repo用于备用]
download_github_file() {
    local URL_PATH="$1"
    local SAVE_NAME="$2"
    local REPO="${3:-}"

    # 主下载URL
    local MAIN_URL="${GH_WEB}/${URL_PATH}"
    echo "  尝试下载: ${MAIN_URL}"
    ${PC_COMM} wget -O "${SAVE_NAME}" "${MAIN_URL}" 2>&1
    if [ $? -eq 0 ] && [ -f "${SAVE_NAME}" ] && [ -s "${SAVE_NAME}" ]; then
        return 0
    fi

    # 备用下载: 去掉ghproxy前缀直连
    if [ -n "$REPO" ]; then
        local FALLBACK_URL="https://github.com/${URL_PATH}"
        echo "  主下载失败，尝试备用: ${FALLBACK_URL}"
        ${PC_COMM} curl -L --connect-timeout 30 --max-time 120 -o "${SAVE_NAME}" "${FALLBACK_URL}" 2>/dev/null
        if [ $? -eq 0 ] && [ -f "${SAVE_NAME}" ] && [ -s "${SAVE_NAME}" ]; then
            return 0
        fi
    fi

    return 1
}


# ============================================================
# 安装子函数
# ============================================================

# 设置主机名
setup_hostname() {
    echo -n "请输入新主机名: "
    read HS_DAT
    if [ "$HS_DAT" ]; then
        hostnamectl set-hostname ${HS_DAT}
        echo "127.0.0.1 ${HS_DAT}" >> /etc/hosts
        echo "主机名已设置为: ${HS_DAT}"
    fi
}

# 系统初始安装
setup_system() {
    echo "正在更新系统并安装基础工具..."
    apt update && apt upgrade -y && apt install -y curl wget nano sudo
    apt install -y unzip htop git openssl proxychains vim
    echo "系统基础工具安装完成。"
}

# 安装代理工具
setup_proxychains() {
    echo -n "使用ProxyChains4? (y/N): "
    read PROXYS_USAGES
    if [ "$PROXYS_USAGES" = "y" ]; then
        IP_ADDR=$(getent hosts ${PROXY_HOST} | awk '{print $1}')
        PC_COMM="proxychains"
        cat > /etc/proxychains.conf << EOF
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000
[ProxyList]
socks5 ${IP_ADDR} ${PROXY_PORT} ${PROXY_AUTH}
EOF
        echo "ProxyChains4 已配置。"
    else
        PC_COMM=""
    fi
}

# 安装 NodeJS LTS (via nvm)
setup_nodejs() {
    echo -n "是否安装 NodeJS LTS? (y/N): "
    read INSTALL_NODEJS
    if [ "$INSTALL_NODEJS" = "y" ]; then
        git clone https://gitee.com/mirrors/nvm.git ~/.nvm && cd ~/.nvm && git checkout `git describe --abbrev=0 --tags`
        echo ". ~/.nvm/nvm.sh" >> ~/.bashrc
        source ~/.bashrc
        export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
        nvm install --lts
        nvm use --lts
        node -v && npm -v
        npm config set registry https://registry.npmmirror.com
        npm install pm2 -g
        echo "NodeJS LTS 及 PM2 安装完成。"
    fi
}

# 安装宝塔面板
setup_baota() {
    echo -n "是否安装宝塔面板? (y/N): "
    read INSTALL_BAOTA
    if [ "$INSTALL_BAOTA" = "y" ]; then
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
    fi
}

# 安装哪吒面板
setup_nezha() {
    echo -n "是否安装哪吒面板? (y/N): "
    read INSTALL_NEZHA
    if [ "$INSTALL_NEZHA" = "y" ]; then
        NZ_URL="${GH_URL}/nezhahq/scripts/main/agent/install.sh"
        ${PC_COMM} curl -L ${NZ_URL} -o agent.sh && chmod +x agent.sh
        env NZ_SERVER=${NZ_SERVER} \
            NZ_TLS=true \
            NZ_CLIENT_SECRET=${NZ_SECRET} \
            ${PC_COMM} ./agent.sh
        echo "哪吒面板安装完成。"
    fi
}

# 安装 3XUI 面板
setup_3xui() {
    echo -n "是否安装3XUI面板? (y/N): "
    read INSTALL_3XUI
    if [ "$INSTALL_3XUI" = "y" ]; then
        mkdir -p /etc/xui
        # 生成自签名证书
        openssl req -x509 -newkey rsa:2048 \
                    -keyout /etc/xui/key.pem \
                    -out /etc/xui/crt.pem \
                    -days 365 -nodes -subj "/CN=${HS_DAT}"
        # 下载脚本到tmp目录
        TMP_SCRIPT="/tmp/3x-ui-install.sh"
        ${PC_COMM} curl -Ls "${GH_URL}/mhsanaei/3x-ui/master/install.sh" -o "${TMP_SCRIPT}"
        chmod +x "${TMP_SCRIPT}"
        # 用sed修改脚本内的GitHub链接
        sed -i "s|https://raw.githubusercontent.com|${GH_URL}|g" "${TMP_SCRIPT}"
        sed -i "s|https://github.com|${GH_WEB}|g" "${TMP_SCRIPT}"
        # 运行修改后的脚本，自动传入参数
        echo -e "y\n1090\n3\n/etc/xui/crt.pem\n/etc/xui/key.pem\n" | ${PC_COMM} bash "${TMP_SCRIPT}"
        echo "3XUI面板安装完成。"
    fi
}

# 安装 ET (EasyTier)
setup_easytier() {
    echo -n "是否安装EasyTier? (y/N): "
    read INSTALL_ET
    if [ "$INSTALL_ET" = "y" ]; then
        # 自动从GitHub读取最新的tag（多方法回退）
        ET_TAG=$(get_latest_github_tag "EasyTier/EasyTier")
        if [ -z "$ET_TAG" ]; then
            echo "错误: 无法获取EasyTier最新版本，请检查网络连接。"
            echo "跳过ET安装。"
            return 1
        fi
        echo "获取到最新的ET版本: ${ET_TAG}"

        # 构建下载URL并下载
        ET_FILE="easytier-linux-x86_64-${ET_TAG}.zip"
        download_github_file "EasyTier/EasyTier/releases/download/${ET_TAG}/${ET_FILE}" "${ET_FILE}" "EasyTier/EasyTier"

        # 解压ZIP文件
        if [ -f "${ET_FILE}" ] && [ -s "${ET_FILE}" ]; then
            unzip -o "${ET_FILE}"
            # 设置执行权限
            chmod -R +x easytier-linux-x86_64
            # 移动到/bin目录下
            mv easytier-linux-x86_64/* /bin/
            # 清理临时文件
            rm -f "${ET_FILE}"
            rm -rf easytier-linux-x86_64
            pm2 start /bin/easytier-core --name easytier -- --config-server ${ET_CONFIG}
            pm2 save
            echo "ET服务安装完成，已安装到/bin/easytier"
        else
            echo "ET安装失败，文件下载不成功。"
        fi
    fi
}

# 安装 FRPS 服务
setup_frps() {
    echo -n "是否设置FRPS服务? (y/N): "
    read INSTALL_FRPS
    if [ "$INSTALL_FRPS" = "y" ]; then
        # 通过GitHub API获取最新frp-panel版本
        FRP_TAG=$(get_latest_github_tag "VaalaCat/frp-panel")
        if [ -z "$FRP_TAG" ]; then
            echo "错误: 无法获取frp-panel最新版本，请检查网络连接。"
            echo "跳过FRPS安装。"
            return 1
        fi
        echo "获取到最新的frp-panel版本: ${FRP_TAG}"

        download_github_file "VaalaCat/frp-panel/releases/download/${FRP_TAG}/frp-panel-linux-amd64" "frp-panel" "VaalaCat/frp-panel"

        if [ -f "frp-panel" ] && [ -s "frp-panel" ]; then
            mv frp-panel /bin/frp-panel
            chmod +x /bin/frp-panel

            echo "请输入服务器名称(NN_FRP):"
            read NN_FRP
            echo "请输入节点UUID(TK_FRP):"
            read TK_FRP
            pm2 start /bin/frp-panel --name frps -- server -s ${TK_FRP} -i ${NN_FRP} \
                      --api-url ${FRP_API} \
                      --rpc-url ${FRP_RPC}
            pm2 save
            echo "FRPS服务安装完成。"
        else
            echo "FRPS安装失败，文件下载不成功。"
        fi
    fi
}

# 端口限速 ==========================================================
# 解析端口输入: 支持 1040 1041-1043 1045 等混合格式
# 输出: 以空格分隔的端口列表
parse_ports() {
    local INPUT="$1"
    local RESULT=()
    # 按空格/逗号/分号/中文逗号拆分
    local IFS_OLD="$IFS"
    IFS=' ,;，；'
    read -ra TOKENS <<< "$INPUT"
    IFS="$IFS_OLD"

    for TOKEN in "${TOKENS[@]}"; do
        TOKEN=$(echo "$TOKEN" | xargs)  # trim
        [ -z "$TOKEN" ] && continue
        if [[ "$TOKEN" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # 端口范围: start-end
            local START=${BASH_REMATCH[1]}
            local END=${BASH_REMATCH[2]}
            if [ "$START" -le "$END" ] && [ "$START" -ge 1 ] && [ "$END" -le 65535 ]; then
                for ((p=START; p<=END; p++)); do
                    RESULT+=($p)
                done
            else
                echo "警告: 无效的端口范围 ${TOKEN}，已跳过。"
            fi
        elif [[ "$TOKEN" =~ ^[0-9]+$ ]]; then
            if [ "$TOKEN" -ge 1 ] && [ "$TOKEN" -le 65535 ]; then
                RESULT+=($TOKEN)
            else
                echo "警告: 无效的端口 ${TOKEN}，已跳过。"
            fi
        else
            echo "警告: 无法识别的端口格式 ${TOKEN}，已跳过。"
        fi
    done

    echo "${RESULT[*]}"
}

# 解析速率: 支持 1mbit, 512kbit, 2mbit, 10mbit 等
# 返回原始速率值，不合法则返回空
parse_rate() {
    local R="$1"
    R=$(echo "$R" | xargs | tr '[:upper:]' '[:lower:]')
    if [[ "$R" =~ ^[0-9]+(kbit|mbit|gbit)$ ]]; then
        echo "$R"
    else
        echo ""
    fi
}

setup_rate_limit() {
    local IFACE PORTS_ARRAY RATE RAW_PORTS RAW_RATE

    IFACE=$(ip route | grep default | awk '{print $5}' | head -1)

    # 交互输入端口
    echo ""
    echo "端口限速配置"
    echo "================================================"
    echo "输入格式示例:"
    echo "  单个端口:   1040"
    echo "  多个端口:   1040 1041 1042"
    echo "  端口范围:   1040-1043"
    echo "  混合格式:   1040 1043-1045 1050"
    echo "  分隔符:     空格 / 逗号 / 分号 均可"
    echo "================================================"
    echo -n "请输入需要限速的端口: "
    read RAW_PORTS
    if [ -z "$RAW_PORTS" ]; then
        echo "未输入端口，使用默认端口 1040 1041 1042。"
        RAW_PORTS="1040 1041 1042"
    fi
    PORTS_ARRAY=($(parse_ports "$RAW_PORTS"))
    if [ ${#PORTS_ARRAY[@]} -eq 0 ]; then
        echo "没有有效的端口，跳过限速配置。"
        return 1
    fi
    echo "解析后的端口列表: ${PORTS_ARRAY[*]}"

    # 交互输入速率
    echo ""
    echo "速率格式示例: 1mbit, 512kbit, 2mbit, 10mbit, 100mbit"
    echo -n "请输入限速值 (默认 1mbit): "
    read RAW_RATE
    RAW_RATE=${RAW_RATE:-1mbit}
    RATE=$(parse_rate "$RAW_RATE")
    if [ -z "$RATE" ]; then
        echo "无效的速率格式，使用默认值 1mbit。"
        RATE="1mbit"
    fi
    echo "限速值: ${RATE}"

    echo ""
    echo "配置确认:"
    echo "  网卡接口: ${IFACE}"
    echo "  端口列表: ${PORTS_ARRAY[*]}"
    echo "  限速值:   ${RATE}"
    echo -n "确认应用以上限速规则? (y/N): "
    read RL_CONFIRM
    if [ "$RL_CONFIRM" != "y" ] && [ "$RL_CONFIRM" != "Y" ]; then
        echo "已取消端口限速配置。"
        return 0
    fi

    # 清理旧规则
    echo "正在清理旧规则..."
    tc qdisc del dev ${IFACE} root 2>/dev/null
    tc qdisc del dev ${IFACE} ingress 2>/dev/null
    ip link set ifb0 down 2>/dev/null
    ip link del ifb0 2>/dev/null

    # 出方向限速
    echo "正在设置出方向限速..."
    tc qdisc add dev ${IFACE} root handle 1: htb default 999
    tc class add dev ${IFACE} parent 1: classid 1:999 htb rate 1000mbit
    tc class add dev ${IFACE} parent 1: classid 1:10 htb rate ${RATE} ceil ${RATE}
    for PORT in "${PORTS_ARRAY[@]}"; do
        tc filter add dev ${IFACE} parent 1: protocol ip u32 match ip dport ${PORT} 0xffff flowid 1:10
        tc filter add dev ${IFACE} parent 1: protocol ip u32 match ip sport ${PORT} 0xffff flowid 1:10
    done

    # 入方向限速（通过 IFB）
    echo "正在设置入方向限速..."
    modprobe ifb 2>/dev/null
    ip link add ifb0 type ifb 2>/dev/null
    ip link set ifb0 up
    tc qdisc add dev ${IFACE} ingress
    tc filter add dev ${IFACE} parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0
    tc qdisc add dev ifb0 root handle 2: htb default 999
    tc class add dev ifb0 parent 2: classid 2:999 htb rate 1000mbit
    tc class add dev ifb0 parent 2: classid 2:10 htb rate ${RATE} ceil ${RATE}
    for PORT in "${PORTS_ARRAY[@]}"; do
        tc filter add dev ifb0 parent 2: protocol ip u32 match ip dport ${PORT} 0xffff flowid 2:10
        tc filter add dev ifb0 parent 2: protocol ip u32 match ip sport ${PORT} 0xffff flowid 2:10
    done

    echo ""
    echo "端口限速已启用!"
    echo "  端口: ${PORTS_ARRAY[*]}"
    echo "  限速: ${RATE} (出入双向)"
    echo "  网卡: ${IFACE}"
}

# 端口限速入口
setup_rate_limit_menu() {
    echo -n "是否配置端口限速? (y/N): "
    read INSTALL_RATELIMIT
    if [ "$INSTALL_RATELIMIT" = "y" ]; then
        setup_rate_limit
    fi
}


# ============================================================
# 新增服务: RustDesk 中转服务
# ============================================================
setup_rustdesk() {
    echo "================================================"
    echo "             RustDesk 中转服务部署               "
    echo "================================================"
    echo -n "是否安装 RustDesk 中转服务? (y/N): "
    read INSTALL_RD
    if [ "$INSTALL_RD" != "y" ]; then
        return 0
    fi

    # 端口配置
    echo ""
    echo "RustDesk 默认端口:"
    echo "  hbbs (ID服务器) : 21116 (TCP/UDP)"
    echo "  hbbr (中继服务器): 21117 (TCP)"
    echo "  自定义备用端口映射(可选):"
    read -p "请输入 hbbs 端口 (默认 21116): " RD_HBBS_PORT
    RD_HBBS_PORT=${RD_HBBS_PORT:-21116}
    read -p "请输入 hbbr 端口 (默认 21117): " RD_HBBR_PORT
    RD_HBBR_PORT=${RD_HBBR_PORT:-21117}
    read -p "请输入 hbbs Web控制台端口 (默认 21118): " RD_WEB_PORT
    RD_WEB_PORT=${RD_WEB_PORT:-21118}

    echo ""
    echo "配置确认:"
    echo "  hbbs 端口: ${RD_HBBS_PORT}"
    echo "  hbbr 端口: ${RD_HBBR_PORT}"
    echo "  Web控制台: ${RD_WEB_PORT}"
    echo -n "确认继续? (y/N): "
    read RD_CONFIRM
    if [ "$RD_CONFIRM" != "y" ]; then
        echo "已取消 RustDesk 安装。"
        return 0
    fi

    # 检测架构
    local ARCH
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  RD_ARCH="x86_64" ;;
        aarch64) RD_ARCH="aarch64" ;;
        *) echo "不支持的架构: $ARCH"; return 1 ;;
    esac

    # 获取最新版本
    RD_TAG=$(get_latest_github_tag "rustdesk/rustdesk-server")
    if [ -z "$RD_TAG" ]; then
        echo "警告: 无法获取RustDesk最新版本，将使用默认版本 nightly"
        RD_TAG="nightly"
    fi
    echo "RustDesk-Server 版本: ${RD_TAG}"

    # 下载
    local RD_DIR="/opt/rustdesk"
    mkdir -p ${RD_DIR}
    cd ${RD_DIR}

    echo "正在下载 RustDesk Server..."
    local HBBS_URL="${GH_WEB}/rustdesk/rustdesk-server/releases/download/${RD_TAG}/rustdesk-server-hbbs_${RD_ARCH}.deb"
    local HBBR_URL="${GH_WEB}/rustdesk/rustdesk-server/releases/download/${RD_TAG}/rustdesk-server-hbbr_${RD_ARCH}.deb"

    ${PC_COMM} wget -O rustdesk-server-hbbs.deb "${HBBS_URL}" 2>&1
    ${PC_COMM} wget -O rustdesk-server-hbbr.deb "${HBBR_URL}" 2>&1

    if [ -f "rustdesk-server-hbbs.deb" ] && [ -s "rustdesk-server-hbbs.deb" ] && \
       [ -f "rustdesk-server-hbbr.deb" ] && [ -s "rustdesk-server-hbbr.deb" ]; then
        dpkg -i rustdesk-server-hbbs.deb rustdesk-server-hbbr.deb 2>/dev/null
        apt install -f -y 2>/dev/null

        # 配置 systemd (hbbs)
        cat > /etc/systemd/system/rustdesk-hbbs.service << EOFRD1
[Unit]
Description=RustDesk HBBS Service
After=network.target

[Service]
Type=simple
LimitNOFILE=1000000
ExecStart=/usr/bin/hbbs -k _ -r ${HS_DAT}:${RD_HBBR_PORT} --port ${RD_HBBS_PORT}
WorkingDirectory=/var/lib/rustdesk-server/
StandardOutput=append:/var/log/rustdesk-hbbs.log
StandardError=append:/var/log/rustdesk-hbbs.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOFRD1

        # 配置 systemd (hbbr)
        cat > /etc/systemd/system/rustdesk-hbbr.service << EOFRD2
[Unit]
Description=RustDesk HBBR Service
After=network.target

[Service]
Type=simple
LimitNOFILE=1000000
ExecStart=/usr/bin/hbbr -k _ --port ${RD_HBBR_PORT}
WorkingDirectory=/var/lib/rustdesk-server/
StandardOutput=append:/var/log/rustdesk-hbbr.log
StandardError=append:/var/log/rustdesk-hbbr.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOFRD2

        systemctl daemon-reload
        systemctl enable rustdesk-hbbs rustdesk-hbbr
        systemctl start rustdesk-hbbs rustdesk-hbbr

        echo ""
        echo "RustDesk 中转服务安装完成!"
        echo "================================================"
        echo "  hbbs (ID): 端口 ${RD_HBBS_PORT} (TCP/UDP)"
        echo "  hbbr (中继): 端口 ${RD_HBBR_PORT} (TCP)"
        echo "  Web控制台: http://${HS_DAT}:${RD_WEB_PORT}"
        echo ""
        echo "  公钥文件: /var/lib/rustdesk-server/id_ed25519.pub"
        echo "  私钥文件: /var/lib/rustdesk-server/id_ed25519"
        echo "================================================"

        # 清理
        rm -f rustdesk-server-hbbs.deb rustdesk-server-hbbr.deb
    else
        echo "RustDesk 下载失败，请检查网络或版本。"
        # 尝试使用二进制方式安装
        echo "尝试使用二进制方式安装..."
        setup_rustdesk_binary "${RD_TAG}" "${RD_HBBS_PORT}" "${RD_HBBR_PORT}"
    fi

    cd - > /dev/null
}

# RustDesk 二进制备用安装方式
setup_rustdesk_binary() {
    local RD_TAG="$1"
    local RD_HBBS_PORT="$2"
    local RD_HBBR_PORT="$3"
    local ARCH
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  RD_ARCH="x86_64"; RD_SUFFIX="" ;;
        aarch64) RD_ARCH="aarch64"; RD_SUFFIX="-arm64v8" ;;
        *) echo "不支持的架构: $ARCH"; return 1 ;;
    esac

    mkdir -p /opt/rustdesk/{bin,data}
    cd /opt/rustdesk/bin

    ${PC_COMM} wget -O hbbs "${GH_WEB}/rustdesk/rustdesk-server/releases/download/${RD_TAG}/hbbs${RD_SUFFIX}" 2>&1
    ${PC_COMM} wget -O hbbr "${GH_WEB}/rustdesk/rustdesk-server/releases/download/${RD_TAG}/hbbr${RD_SUFFIX}" 2>&1

    if [ -f "hbbs" ] && [ -s "hbbs" ] && [ -f "hbbr" ] && [ -s "hbbr" ]; then
        chmod +x hbbs hbbr

        cat > /etc/systemd/system/rustdesk-hbbs.service << EOFRDB1
[Unit]
Description=RustDesk HBBS Service
After=network.target

[Service]
Type=simple
LimitNOFILE=1000000
ExecStart=/opt/rustdesk/bin/hbbs -k _ -r ${HS_DAT}:${RD_HBBR_PORT} --port ${RD_HBBS_PORT}
WorkingDirectory=/opt/rustdesk/data/
StandardOutput=append:/var/log/rustdesk-hbbs.log
StandardError=append:/var/log/rustdesk-hbbs.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOFRDB1

        cat > /etc/systemd/system/rustdesk-hbbr.service << EOFRDB2
[Unit]
Description=RustDesk HBBR Service
After=network.target

[Service]
Type=simple
LimitNOFILE=1000000
ExecStart=/opt/rustdesk/bin/hbbr -k _ --port ${RD_HBBR_PORT}
WorkingDirectory=/opt/rustdesk/data/
StandardOutput=append:/var/log/rustdesk-hbbr.log
StandardError=append:/var/log/rustdesk-hbbr.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOFRDB2

        systemctl daemon-reload
        systemctl enable rustdesk-hbbs rustdesk-hbbr
        systemctl start rustdesk-hbbs rustdesk-hbbr

        echo "RustDesk (二进制)安装完成!"
        echo "  公钥文件: /opt/rustdesk/data/id_ed25519.pub"
    else
        echo "RustDesk 二进制下载也失败了，请手动安装。"
    fi
    cd - > /dev/null
}


# ============================================================
# 新增服务: ZeroTier 中转服务
# ============================================================
setup_zerotier() {
    echo "================================================"
    echo "             ZeroTier 中转服务部署               "
    echo "================================================"
    echo -n "是否安装 ZeroTier? (y/N): "
    read INSTALL_ZT
    if [ "$INSTALL_ZT" != "y" ]; then
        return 0
    fi

    read -p "请输入 ZeroTier 端口 (默认 1048): " ZT_PORT
    ZT_PORT=${ZT_PORT:-1048}

    echo "正在安装 ZeroTier..."
    curl -s https://install.zerotier.com | ${PC_COMM} bash

    # 加入默认网络（可选）
    echo -n "是否加入 ZeroTier 网络? (需要Network ID) (y/N): "
    read ZT_JOIN
    if [ "$ZT_JOIN" = "y" ]; then
        read -p "请输入 ZeroTier Network ID: " ZT_NETID
        zerotier-cli join ${ZT_NETID}
    fi

    echo ""
    echo "ZeroTier 安装完成!"
    echo "================================================"
    echo "  默认端口: ${ZT_PORT} (UDP)"
    echo ""
    echo "  常用命令:"
    echo "    zerotier-cli status         查看状态"
    echo "    zerotier-cli listnetworks   查看网络"
    echo "    zerotier-cli join <ID>      加入网络"
    echo "    zerotier-cli leave <ID>     离开网络"
    echo ""
    echo "  防火墙开放端口:"
    echo "    ufw allow ${ZT_PORT}/udp"
    echo "================================================"
}

# ============================================================
# 新增服务: Tailscale 中转服务
# ============================================================
setup_tailscale() {
    echo "================================================"
    echo "            Tailscale 中转服务部署               "
    echo "================================================"
    echo -n "是否安装 Tailscale? (y/N): "
    read INSTALL_TS
    if [ "$INSTALL_TS" != "y" ]; then
        return 0
    fi

    read -p "请输入 Tailscale 端口 (默认 1049): " TS_PORT
    TS_PORT=${TS_PORT:-1049}

    echo "正在安装 Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | ${PC_COMM} sh

    # 设置为中转/出口模式（可选）
    echo ""
    echo "Tailscale 常见运行模式:"
    echo "  1) 标准模式（普通节点）"
    echo "  2) 出口节点模式(--advertise-exit-node, 也可作为中转)"
    echo "  3) 子网路由模式(--advertise-routes)"
    echo ""
    read -p "请选择运行模式 (1-3, 默认1): " TS_MODE
    TS_MODE=${TS_MODE:-1}

    local TS_EXTRA_ARGS=""
    case "$TS_MODE" in
        2) TS_EXTRA_ARGS="--advertise-exit-node" ;;
        3)
            read -p "请输入要广播的子网 (如 192.168.1.0/24): " TS_SUBNET
            TS_EXTRA_ARGS="--advertise-routes=${TS_SUBNET} --snat-subnet-routes=false"
            ;;
    esac

    tailscale up ${TS_EXTRA_ARGS} 2>/dev/null

    echo ""
    echo "Tailscale 安装完成!"
    echo "================================================"
    echo "  端口: ${TS_PORT}"
    echo ""
    echo "  常用命令:"
    echo "    tailscale status         查看状态"
    echo "    tailscale up             启动"
    echo "    tailscale down           停止"
    echo "    tailscale ip -4          查看IP"
    echo ""
    echo "  管理面板: https://login.tailscale.com/admin/machines"
    echo "================================================"
}


# ============================================================
# 交互式菜单系统
# ============================================================

show_menu() {
    echo ""
    echo "================================================"
    echo "            皮卡丘服务器部署菜单                 "
    echo "================================================"
    echo "  基础设置:"
    echo "    [0]  设置主机名"
    echo "    [1]  系统更新 + 基础工具"
    echo "    [2]  配置 ProxyChains4"
    echo ""
    echo "  开发环境:"
    echo "    [3]  安装 NodeJS LTS + PM2"
    echo ""
    echo "  面板/管理:"
    echo "    [4]  安装宝塔面板"
    echo "    [5]  安装哪吒面板"
    echo "    [6]  安装 3XUI 面板"
    echo "    [7]  安装 EasyTier (ET)"
    echo "    [8]  安装 FRPS 服务"
    echo ""
    echo "  端口限速:"
    echo "    [9]  配置端口限速 (1040/1041/1042)"
    echo ""
    echo "  组网/中转工具:"
    echo "    [A]  安装 RustDesk 中转服务"
    echo "    [B]  安装 ZeroTier"
    echo "    [C]  安装 Tailscale"
    echo ""
    echo "  批量部署:"
    echo "    [ALL]  一键部署全部服务（交互确认每个组件）"
    echo ""
    echo "    [Q]  退出脚本"
    echo "================================================"
    echo -n "请输入选项 (多个选项用空格分隔, 如: 0 1 3 7): "
}

run_all() {
    echo "[全部部署模式] 将依次询问每个组件..."
    echo ""
    setup_hostname
    setup_system
    setup_proxychains
    setup_nodejs
    setup_baota
    setup_nezha
    setup_3xui
    setup_easytier
    setup_frps
    setup_rate_limit_menu
    setup_rustdesk
    setup_zerotier
    setup_tailscale
}

process_choice() {
    local CHOICE="$1"
    case "$CHOICE" in
        0)   setup_hostname ;;
        1)   setup_system ;;
        2)   setup_proxychains ;;
        3)   setup_nodejs ;;
        4)   setup_baota ;;
        5)   setup_nezha ;;
        6)   setup_3xui ;;
        7)   setup_easytier ;;
        8)   setup_frps ;;
        9)   setup_rate_limit_menu ;;
        A|a) setup_rustdesk ;;
        B|b) setup_zerotier ;;
        C|c) setup_tailscale ;;
        ALL|all|All)
            run_all
            ;;
        Q|q) echo "退出脚本。"; exit 0 ;;
        *)
            echo "无效选项: $CHOICE，跳过。"
            ;;
    esac
}


# ============================================================
# 主流程
# ============================================================

# 初始化 PC_COMM（默认不用代理）
PC_COMM=""

# 如果传了命令行参数，直接按参数执行（兼容旧模式）
if [ $# -gt 0 ]; then
    for ARG in "$@"; do
        process_choice "$ARG"
    done
    echo ""
    echo "======================================================="
    echo "  部署完成！"
    echo "======================================================="
    exit 0
fi

# 交互式菜单循环
while true; do
    show_menu
    read -a CHOICES

    if [ ${#CHOICES[@]} -eq 0 ]; then
        echo "未选择任何选项。"
        continue
    fi

    for CH in "${CHOICES[@]}"; do
        process_choice "$CH"
    done

    echo ""
    echo "======================================================="
    echo -n "当前批次执行完毕。是否继续选择其他服务? (y/N): "
    read CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        break
    fi
done

echo ""
echo "======================================================="
echo "  部署完成！感谢使用皮卡丘服务器部署脚本。"
echo "======================================================="
