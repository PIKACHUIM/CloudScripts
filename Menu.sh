#!/usr/bin/env bash
# ============================================================
#  PIKA SH - 服务器脚本工具箱
#  两级菜单：主菜单(5大类) → 子菜单(具体脚本)
#
#  使用方式:
#    bash <(curl -s https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)
#    bash <(curl -s https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)
# ============================================================
set -e

# ---- 颜色 ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

# ---- CDN ----
CDN_RAW="https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
CDN_MIRROR="https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
_choose_cdn() {
    if curl -s --connect-timeout 3 --max-time 5 "${CDN_RAW}/Menu.sh" >/dev/null 2>&1; then echo "$CDN_RAW"
    elif curl -s --connect-timeout 3 --max-time 5 "${CDN_MIRROR}/Menu.sh" >/dev/null 2>&1; then echo "$CDN_MIRROR"
    else echo "$CDN_RAW"; fi
}
CDN_BASE=$(_choose_cdn)

# ---- 系统检测 ----
detect_os() {
    case "$(uname -s)" in
        Linux)  echo "linux|$(. /etc/os-release 2>/dev/null && echo "${NAME:-Linux}" || echo 'Linux')" ;;
        Darwin) echo "macos|macOS $(sw_vers -productVersion 2>/dev/null)" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows|Windows (Git Bash)" ;;
        *)      echo "unknown|$(uname -s)" ;;
    esac
}
OS_INFO=$(detect_os); OS_TYPE="${OS_INFO%%|*}"; OS_DETAIL="${OS_INFO##*|}"
detect_distro_id() { . /etc/os-release 2>/dev/null && echo "${ID:-unknown}" || echo "unknown"; }
DISTRO_ID=$(detect_distro_id)

# ---- 打印 ----
clear_screen() { clear; }
print_header() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║                                                      ║"
    echo "  ║  ██████╗ ██╗██╗  ██╗ █████╗   ███████╗ ██╗  ██╗    ║"
    echo "  ║  ██╔══██╗██║██║ ██╔╝██╔══██╗  ██╔════╝ ██║  ██║    ║"
    echo "  ║  ██████╔╝██║█████╔╝ ███████║  ███████╗ ███████║    ║"
    echo "  ║  ██╔═══╝ ██║██╔═██╗ ██╔══██║  ╚════██║ ██╔══██║    ║"
    echo "  ║  ██║     ██║██║  ██╗██║  ██║  ███████║ ██║  ██║    ║"
    echo "  ║  ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚══════╝ ╚═╝  ╚═╝    ║"
    echo "  ║                                                      ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}PIKA SH${NC}  |  ${GREEN}${OS_DETAIL}${NC}"
}
print_line() { echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"; }
print_section() { echo -e "\n  ${YELLOW}${BOLD}  $1${NC}"; }

# ---- CJK感知宽度计算 ----
# 返回字符串在终端中的显示列宽（ASCII=1, CJK=2, emoji=2）
# 优先 Python（通过 argv 传参避免引号问题），回退 Perl，回退 awk
_str_w() {
    if command -v python3 &>/dev/null; then
        python3 - "$1" << 'PYEOF'
import sys, unicodedata
s = sys.argv[1]
print(sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s))
PYEOF
    elif command -v python &>/dev/null; then
        python - "$1" << 'PYEOF'
import sys, unicodedata
s = sys.argv[1]
print(sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s))
PYEOF
    elif command -v perl &>/dev/null; then
        perl -CSDA -e 'use utf8; binmode STDIN, ":utf8"; my $s = $ARGV[0]; my $w = 0; for my $c (split //, $s) { $w += 2 if $c =~ /[\x{3000}-\x{9fff}\x{ff00}-\x{ffef}\x{1f300}-\x{1f9ff}\x{2600}-\x{26ff}]/; $w += 1 if $c !~ /[\x{3000}-\x{9fff}\x{ff00}-\x{ffef}\x{1f300}-\x{1f9ff}\x{2600}-\x{26ff}]/ } print $w' -- "$1"
    else
        # 最后回退：sed 替换 UTF-8 多字节序列为两个字符
        echo -n "$1" | LC_ALL=C sed 's/[\x80-\xff][\x80-\xff]\{0,3\}/__/g; s/[\x80-\xff]/__/g' | wc -c | awk '{print $1-1}'
    fi
}

# 打印对齐：自动按显示列宽填充
# 参数: 编号  名称  描述
print_item() {
    local NUM="$1" NAME="$2" DESC="$3"
    local WIDTH=32  # 名称列目标显示宽度
    local name_w=$(_str_w "$NAME")
    local pad=$((WIDTH - name_w))
    [ $pad -lt 2 ] && pad=2
    local spaces=$(printf '%*s' $pad '')
    printf "  ${GREEN}%4s${NC}  ${BOLD}%s${NC}${spaces}${BLUE}%s${NC}\n" "[$NUM]" "$NAME" "$DESC"
}
print_tip() { echo -e "  ${MAGENTA}  💡 $1${NC}"; }
print_done() { echo -e "\n  ${GREEN}✅ $1 完成！${NC}"; }
print_warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }

# ---- 脚本执行器 ----
run_setup() { bash <(curl -s "${CDN_BASE}/Linux/VPSSets/Setup.sh") "$@"; }
run_script_pipe() { curl -s "${CDN_BASE}/$1" | bash -e; }
run_bench() { bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/$1"); }
run_clean() { apt -y install curl 2>/dev/null; curl -s "${CDN_BASE}/Linux/Cleaner/LinuxClean.sh" | bash; }

# ---- 获取 GitHub 最新版本号 ----
get_gh_ver() {
    local REPO="$1" TAG
    TAG=$(curl -s --connect-timeout 8 --max-time 12 "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
    [ -z "$TAG" ] || [ "$TAG" = "null" ] && echo "未知(网络获取失败)" || echo "$TAG"
}

# ---- 安装前二次确认 ----
# 参数: 名称  简介  版本信息  [官网/仓库]
# 返回: 0=确认安装  1=取消
confirm_install() {
    local NAME="$1" DESC="$2" VER="$3" URL="${4:-}"
    echo ""
    echo -e "  ${CYAN}┌────────────────────────────────────────────────┐${NC}"
    printf  "  ${CYAN}│${NC} ${BOLD}%-46s${NC} ${CYAN}│${NC}\n" "即将安装: ${NAME}"
    echo -e "  ${CYAN}├────────────────────────────────────────────────┤${NC}"
    echo -e "  ${CYAN}│${NC} 简介: ${DESC}"
    echo -e "  ${CYAN}│${NC} 版本: ${GREEN}${VER}${NC}"
    [ -n "$URL" ] && echo -e "  ${CYAN}│${NC} 项目: ${BLUE}${URL}${NC}"
    echo -e "  ${CYAN}└────────────────────────────────────────────────┘${NC}"
    echo -ne "  ${BOLD}确认安装? (y/N)${NC} > "
    read CONFIRM
    if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
        return 0
    else
        echo -e "  ${YELLOW}已取消安装。${NC}"
        return 1
    fi
}

# ============================================================
# 安装函数库
# ============================================================

# ---- 换大陆镜像源 ----
switch_apt_mirror() {
    echo -e "\n  ${BOLD}正在更换 APT 镜像源...${NC}"
    case "$DISTRO_ID" in
        debian)
            sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g' /etc/apt/sources.list.d/debian.sources 2>/dev/null || true
            sed -i 's|deb.debian.org|mirrors.ustc.edu.cn|g' /etc/apt/sources.list 2>/dev/null || true
            ;;
        ubuntu)
            sed -i 's|archive.ubuntu.com|mirrors.ustc.edu.cn|g' /etc/apt/sources.list 2>/dev/null || true
            sed -i 's|security.ubuntu.com|mirrors.ustc.edu.cn|g' /etc/apt/sources.list 2>/dev/null || true
            ;;
        centos|rhel|rocky|almalinux|fedora)
            echo -e "  ${YELLOW}请手动更换 YUM/DNF 源${NC}"
            ;;
        *) print_warn "未知发行版，跳过换源" ;;
    esac
    apt update -y 2>/dev/null || true
    print_done "镜像源更换"
}

# ---- 1Panel ----
install_1panel() {
    confirm_install "1Panel" "现代化开源 Linux 服务器运维管理面板，支持应用商店、容器、数据库、网站一体化管理" "$(get_gh_ver 1Panel-dev/1Panel)" "https://github.com/1Panel-dev/1Panel" || return
    echo -e "\n  ${BOLD}正在安装 1Panel...${NC}"
    curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o /tmp/1panel.sh
    bash /tmp/1panel.sh
    rm -f /tmp/1panel.sh
    print_done "1Panel 安装"
}

# ---- NetPanel ----
install_netpanel() {
    confirm_install "NetPanel" "皮卡出品的轻量级服务器管理面板" "latest" "https://github.com/PIKACHUIM/NetPanel" || return
    echo -e "\n  ${BOLD}正在安装 NetPanel...${NC}"
    bash <(curl -s https://raw.githubusercontent.com/PIKACHUIM/NetPanel/main/install.sh) 2>/dev/null || {
        print_warn "NetPanel 安装脚本获取失败，请检查仓库"
    }
    print_done "NetPanel 安装"
}

# ---- Docker + 1ms 镜像源 ----
install_docker() {
    local CUR_VER="未安装"
    command -v docker &>/dev/null && CUR_VER="已安装: $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
    confirm_install "Docker CE" "最流行的容器引擎，自动配置 1ms.run 国内镜像加速" "官方最新 (当前${CUR_VER})" "https://get.docker.com" || return
    echo -e "\n  ${BOLD}正在安装 Docker...${NC}"
    if command -v docker &>/dev/null; then
        echo -e "  ${GREEN}Docker 已安装: $(docker --version)${NC}"
    else
        curl -fsSL https://get.docker.com | bash
    fi
    # 配置 1ms 镜像加速
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'DOCKEREOF'
{
  "registry-mirrors": ["https://docker.1ms.run"],
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
DOCKEREOF
    systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
    print_done "Docker 安装 (镜像加速: 1ms.run)"
}

# ---- Podman + 镜像源 ----
install_podman() {
    confirm_install "Podman" "无守护进程的容器引擎，Docker 的安全替代方案，自动配置 1ms.run 镜像加速" "系统仓库版本" "https://podman.io" || return
    echo -e "\n  ${BOLD}正在安装 Podman...${NC}"
    apt install -y podman 2>/dev/null || yum install -y podman 2>/dev/null || true
    mkdir -p /etc/containers
    cat > /etc/containers/registries.conf << 'PODMANEOF'
unqualified-search-registries = ["docker.io"]
[[registry]]
prefix = "docker.io"
location = "docker.1ms.run"
PODMANEOF
    print_done "Podman 安装 (镜像加速: 1ms.run)"
}

# ---- 屏蔽地区 (BlockAreaBot) ----
block_area_bot() {
    confirm_install "BlockAreaBot" "皮卡出品，一键屏蔽指定国家/地区的入站 IP 访问" "latest" "https://github.com/PIKACHUIM/BlockAreaBot" || return
    echo -e "\n  ${BOLD}正在下载 BlockAreaBot...${NC}"
    curl -sSL "https://raw.githubusercontent.com/PIKACHUIM/BlockAreaBot/main/block.sh" -o /tmp/block_area.sh 2>/dev/null || {
        print_warn "BlockAreaBot 下载失败"; return 1
    }
    bash /tmp/block_area.sh
    rm -f /tmp/block_area.sh
}

# ---- 升级/替换内核 ----
upgrade_kernel() {
    echo -e "\n  ${BOLD}内核管理${NC}"
    echo -e "  请选择内核方案:"
    echo -e "  ${GREEN}  [1]${NC} 安装 XanMod 内核 (高性能)"
    echo -e "  ${GREEN}  [2]${NC} 安装 Liquorix 内核 (低延迟)"
    echo -e "  ${GREEN}  [3]${NC} 升级到 Debian Backports 内核"
    echo -e "  ${GREEN}  [4]${NC} 升级到 Ubuntu HWE 内核"
    echo -ne "  ${BOLD}请选择${NC} > "; read KK
    case "$KK" in
        1) echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod.list
           wget -qO - https://dl.xanmod.org/gpg.key | apt-key add - 2>/dev/null || true
           apt update && apt install -y linux-xanmod-x64v3 ;;
        2) curl -s 'https://liquorix.net/add-liquorix-repo.sh' | bash
           apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64 ;;
        3) apt install -y -t bookworm-backports linux-image-amd64 linux-headers-amd64 2>/dev/null || true ;;
        4) apt install -y linux-generic-hwe-22.04 2>/dev/null || true ;;
        *) echo -e "  ${RED}无效选项${NC}"; return 1 ;;
    esac
    print_done "内核安装"
    echo -e "  ${YELLOW}请重启系统以使用新内核: reboot${NC}"
}

# ---- Clash for Linux ----
install_clash_linux() {
    local CLASH_TAG
    CLASH_TAG=$(get_gh_ver nelvko/clash-for-linux-install)
    confirm_install "Clash for Linux" "基于 Mihomo(Clash) 内核的 Linux 代理客户端，支持订阅/Web面板" "$CLASH_TAG" "https://github.com/nelvko/clash-for-linux-install" || return
    echo -e "\n  ${BOLD}正在安装 Clash for Linux...${NC}"
    [ "$CLASH_TAG" = "未知(网络获取失败)" ] && { print_warn "无法获取版本"; return 1; }
    wget -O /tmp/clash-linux-install.tar.gz "https://github.com/nelvko/clash-for-linux-install/releases/download/${CLASH_TAG}/clash-for-linux-install-${CLASH_TAG}.tar.gz" 2>/dev/null
    if [ -f /tmp/clash-linux-install.tar.gz ]; then
        tar -xzf /tmp/clash-linux-install.tar.gz -C /tmp/
        bash /tmp/clash-for-linux-install-*/install.sh 2>/dev/null || bash /tmp/install.sh 2>/dev/null || print_warn "安装失败，请检查压缩包结构"
        rm -rf /tmp/clash-linux-install* /tmp/clash-for-linux-install*
    else
        print_warn "下载失败"
    fi
    print_done "Clash for Linux"
}

# ---- Hysteria2 ----
install_hy2() {
    confirm_install "Hysteria2 (HY2)" "基于 QUIC 的高速代理协议，抗封锁、低延迟，适合弱网环境" "$(get_gh_ver apernet/hysteria)" "https://github.com/apernet/hysteria" || return
    echo -e "\n  ${BOLD}正在安装 Hysteria2...${NC}"
    bash <(curl -fsSL https://get.hy2.sh/) 2>/dev/null || {
        bash <(curl -fsSL https://raw.githubusercontent.com/apernet/hysteria/master/install_server.sh)
    }
    print_done "Hysteria2 安装"
}

# ---- Shadowsocks-rust ----
install_shadowsocks() {
    local SS_VER
    SS_VER=$(get_gh_ver shadowsocks/shadowsocks-rust)
    confirm_install "Shadowsocks-rust" "经典 Shadowsocks 代理的 Rust 高性能实现" "$SS_VER" "https://github.com/shadowsocks/shadowsocks-rust" || return
    echo -e "\n  ${BOLD}正在安装 Shadowsocks-rust...${NC}"
    if command -v ssserver &>/dev/null; then
        echo -e "  ${GREEN}Shadowsocks 已安装${NC}"; return 0
    fi
    [ "$SS_VER" = "未知(网络获取失败)" ] && SS_VER="v1.20.4"
    local ARCH; ARCH=$(uname -m)
    case "$ARCH" in x86_64) ARCH="x86_64-unknown-linux-gnu" ;; aarch64) ARCH="aarch64-unknown-linux-gnu" ;; esac
    local SS_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${SS_VER}/shadowsocks-${SS_VER}.${ARCH}.tar.xz"
    wget -O /tmp/ss-rust.tar.xz "$SS_URL" 2>/dev/null
    tar -xf /tmp/ss-rust.tar.xz -C /usr/local/bin/ 2>/dev/null
    chmod +x /usr/local/bin/ss* 2>/dev/null
    rm -f /tmp/ss-rust.tar.xz
    print_done "Shadowsocks-rust 安装"
    echo -e "  使用方法: ${CYAN}ssserver -s 0.0.0.0 -p 8388 -k PASSWORD -m aes-256-gcm${NC}"
}

# ---- Trojan-Go ----
install_trojan() {
    local TROJ_VER
    TROJ_VER=$(get_gh_ver p4gefau1t/trojan-go)
    confirm_install "Trojan-Go" "Trojan 协议的 Go 语言实现，伪装成 HTTPS 流量，抗封锁" "$TROJ_VER" "https://github.com/p4gefau1t/trojan-go" || return
    echo -e "\n  ${BOLD}正在安装 Trojan-Go...${NC}"
    [ "$TROJ_VER" = "未知(网络获取失败)" ] && TROJ_VER="v0.10.6"
    local ARCH; ARCH=$(uname -m)
    case "$ARCH" in x86_64) ARCH="amd64" ;; aarch64) ARCH="arm64" ;; esac
    local TROJ_URL="https://github.com/p4gefau1t/trojan-go/releases/download/${TROJ_VER}/trojan-go-linux-${ARCH}.zip"
    wget -O /tmp/trojan-go.zip "$TROJ_URL" 2>/dev/null
    unzip -o /tmp/trojan-go.zip -d /usr/local/bin/ 2>/dev/null
    chmod +x /usr/local/bin/trojan-go 2>/dev/null
    rm -f /tmp/trojan-go.zip
    print_done "Trojan-Go 安装"
}

# ---- Cloudflare WARP ----
install_warp() {
    confirm_install "Cloudflare WARP" "Cloudflare 免费网络加速/解锁工具，可添加 IPv4/IPv6 出口，解锁 ChatGPT/Netflix 等" "官方最新" "https://pkg.cloudflareclient.com" || return
    echo -e "\n  ${BOLD}Cloudflare WARP${NC}"
    echo -e "  ${GREEN}  [1]${NC} 安装 WARP CLI"
    echo -e "  ${GREEN}  [2]${NC} 管理 WARP (warp-cli)"
    echo -e "  ${GREEN}  [3]${NC} 安装 WGCF (WireGuard 配置生成)"
    echo -ne "  ${BOLD}请选择${NC} > "; read WW
    case "$WW" in
        1)
            curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg 2>/dev/null
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs 2>/dev/null || echo 'bookworm') main" > /etc/apt/sources.list.d/cloudflare-client.list
            apt update && apt install -y cloudflare-warp
            print_done "WARP CLI 安装"
            echo -e "  注册: ${CYAN}warp-cli register${NC}"
            echo -e "  连接: ${CYAN}warp-cli connect${NC}"
            ;;
        2)
            echo -e "  ${CYAN}warp-cli status${NC}"; warp-cli status 2>/dev/null || print_warn "WARP 未安装"
            echo -ne "  [c]连接 [d]断开 [q]退出 > "; read WCMD
            case "$WCMD" in c) warp-cli connect 2>/dev/null ;; d) warp-cli disconnect 2>/dev/null ;; esac
            ;;
        3)
            apt install -y wireguard-tools resolvconf 2>/dev/null || true
            wget -O /usr/local/bin/wgcf "https://github.com/ViRb3/wgcf/releases/latest/download/wgcf_linux_amd64" 2>/dev/null
            chmod +x /usr/local/bin/wgcf 2>/dev/null
            print_done "WGCF 安装"
            echo -e "  使用: ${CYAN}wgcf register && wgcf generate && wg-quick up wgcf-profile.conf${NC}"
            ;;
        *) echo -e "  ${RED}无效选项${NC}" ;;
    esac
}

# ---- WireGuard ----
install_wireguard() {
    confirm_install "WireGuard" "现代化高性能 VPN 组网工具，安装后自动生成服务端密钥对" "系统仓库版本" "https://www.wireguard.com" || return
    echo -e "\n  ${BOLD}正在安装 WireGuard...${NC}"
    apt install -y wireguard wireguard-tools resolvconf 2>/dev/null || true
    mkdir -p /etc/wireguard
    # 生成密钥
    if [ ! -f /etc/wireguard/server_private.key ]; then
        wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
        echo -e "  ${GREEN}已生成密钥${NC}"
    fi
    print_done "WireGuard 安装"
    echo -e "  私钥: ${CYAN}/etc/wireguard/server_private.key${NC}"
    echo -e "  公钥: ${CYAN}$(cat /etc/wireguard/server_public.key 2>/dev/null)${NC}"
}

# ---- wg-easy (Docker Web管理WireGuard) ----
install_wgeasy() {
    confirm_install "wg-easy" "带 Web 管理界面的 WireGuard，Docker 部署，可视化管理客户端" "$(get_gh_ver wg-easy/wg-easy)" "https://github.com/wg-easy/wg-easy" || return
    echo -e "\n  ${BOLD}正在部署 wg-easy...${NC}"
    if ! command -v docker &>/dev/null; then
        print_warn "需要 Docker，请先安装 Docker"
        install_docker
    fi
    read -p "  请输入 Web 管理端口 (默认 51821): " WGE_PORT; WGE_PORT=${WGE_PORT:-51821}
    read -p "  请输入 WireGuard 端口 (默认 51820): " WGE_WG; WGE_WG=${WGE_WG:-51820}
    read -rsp "  请输入 Web 管理密码: " WGE_PASS; echo
    [ -z "$WGE_PASS" ] && WGE_PASS="pikash"

    docker rm -f wg-easy 2>/dev/null || true
    docker run -d --name wg-easy \
        --restart=always --cap-add=NET_ADMIN --cap-add=SYS_MODULE \
        --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
        --sysctl="net.ipv4.ip_forward=1" \
        -p "${WGE_PORT}:51821" -p "${WGE_WG}:51820/udp" \
        -e WG_HOST="$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP')" \
        -e PASSWORD="${WGE_PASS}" \
        -v /opt/wg-easy:/etc/wireguard \
        weejewel/wg-easy
    print_done "wg-easy 部署"
    echo -e "  Web 面板: ${CYAN}http://$(curl -s ifconfig.me 2>/dev/null):${WGE_PORT}${NC}"
    echo -e "  密码: ${PASSWORD_HIDE:-$WGE_PASS}"
}

# ---- 3X-UI (独立安装) ----
install_3xui() {
    confirm_install "3X-UI 面板" "Xray-core 多协议 Web 管理面板，支持 VMess/VLESS/Trojan/Shadowsocks" "$(get_gh_ver mhsanaei/3x-ui)" "https://github.com/mhsanaei/3x-ui" || return
    echo -e "\n  ${BOLD}正在安装 3X-UI 面板...${NC}"
    bash <(curl -sL "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh")
}

# ---- EasyTier 配置管理 ----
ET_CONF_FILE="/etc/pikash/easytier.conf"
manage_easytier_config() {
    mkdir -p /etc/pikash
    touch "$ET_CONF_FILE"
    while true; do
        clear_screen; print_header
        echo -e "  ${BOLD}${CYAN}  EasyTier 组网配置管理${NC}"
        print_line
        echo -e "  ${BOLD}当前已配置的 config-server 列表:${NC}"
        echo ""
        if [ -s "$ET_CONF_FILE" ]; then
            local i=1
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                printf "  ${GREEN}%3s)${NC} %s\n" "$i" "$line"
                i=$((i+1))
            done < "$ET_CONF_FILE"
        else
            echo -e "  ${YELLOW}(暂无配置)${NC}"
        fi
        echo ""
        print_line
        print_item "1"  "增加配置"                "添加一个 config-server 地址"
        print_item "2"  "删除配置"                "按序号删除"
        print_item "3"  "应用配置并重启 EasyTier"  "用当前配置重启组网服务"
        print_item "0"  "返回"                    ""
        print_line
        echo -ne "  ${BOLD}请选择${NC} > "; read EC
        case "$EC" in
            1) read -p "  请输入 config-server (如 tcp://public.easytier.top:11010): " NEW_ET
               [ -n "$NEW_ET" ] && echo "$NEW_ET" >> "$ET_CONF_FILE" && echo -e "  ${GREEN}已添加${NC}"
               sleep 1 ;;
            2) read -p "  请输入要删除的序号: " DEL_NUM
               if [[ "$DEL_NUM" =~ ^[0-9]+$ ]]; then
                   sed -i "${DEL_NUM}d" "$ET_CONF_FILE" && echo -e "  ${GREEN}已删除第 ${DEL_NUM} 条${NC}"
               fi
               sleep 1 ;;
            3) apply_easytier_config ;;
            0) break ;;
            *) echo -e "  ${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
}

apply_easytier_config() {
    if [ ! -s "$ET_CONF_FILE" ]; then
        print_warn "没有可用配置，请先添加"; sleep 2; return 1
    fi
    if ! command -v easytier-core &>/dev/null && [ ! -f /bin/easytier-core ]; then
        confirm_install "EasyTier" "去中心化 P2P 组网工具，支持内网穿透与异地组网" "$(get_gh_ver EasyTier/EasyTier)" "https://github.com/EasyTier/EasyTier" || return
        echo -e "  ${BOLD}正在安装 EasyTier...${NC}"
        run_setup 7nocfg
    fi
    # 组装多个 --config-server 参数
    local ARGS=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        ARGS="$ARGS --config-server $line"
    done < "$ET_CONF_FILE"
    echo -e "  应用参数:${ARGS}"
    pm2 delete easytier 2>/dev/null || true
    pm2 start /bin/easytier-core --name easytier -- $ARGS 2>/dev/null && pm2 save
    print_done "EasyTier 配置已应用并重启"
    sleep 2
}

# ---- BBR 加速 ----
install_bbr() {
    echo -e "\n  ${BOLD}BBR 网络加速${NC}"
    echo -e "  ${GREEN}  [1]${NC} 开启原生 BBR (内核>=4.9)"
    echo -e "  ${GREEN}  [2]${NC} 安装 BBR3 + FQ (推荐,高吞吐)"
    echo -e "  ${GREEN}  [3]${NC} 安装 BBR + Cake (低延迟)"
    echo -e "  ${GREEN}  [4]${NC} 查看当前拥塞控制算法"
    echo -ne "  ${BOLD}请选择${NC} > "; read BB
    case "$BB" in
        1)
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p
            print_done "BBR 已开启" ;;
        2)
            modprobe tcp_bbr 2>/dev/null || true
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p
            print_done "BBR + FQ 已配置"
            echo -e "  验证: ${CYAN}sysctl net.ipv4.tcp_congestion_control${NC}" ;;
        3)
            modprobe tcp_bbr 2>/dev/null || true
            echo "net.core.default_qdisc=cake" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p
            print_done "BBR + Cake 已配置" ;;
        4)
            echo -e "  当前算法: ${GREEN}$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')${NC}"
            echo -e "  可用算法: ${GREEN}$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk '{print $3}')${NC}" ;;
        *) echo -e "  ${RED}无效选项${NC}" ;;
    esac
}

# ---- BBR3/BBRPlus 多合一 (ylx2016) ----
install_bbrplus() {
    confirm_install "BBRPlus/BBR2/BBR3 多合一" "ylx2016 出品，一键编译安装多版本 BBR 及锐速内核 (需重启)" "master" "https://github.com/ylx2016/Linux-NetSpeed" || return
    echo -e "\n  ${BOLD}正在安装 BBRPlus/BBR2/BBR3 多合一...${NC}"
    wget -O /tmp/tcpx.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh" 2>/dev/null
    chmod +x /tmp/tcpx.sh
    bash /tmp/tcpx.sh
    rm -f /tmp/tcpx.sh
}

# ---- Swap 管理 ----
manage_swap() {
    echo -e "\n  ${BOLD}Swap 管理${NC}"
    echo -e "  当前 Swap: ${GREEN}$(free -m | awk '/Swap:/{print $2"MB 已用:"$3"MB"}')${NC}"
    echo ""
    echo -e "  ${GREEN}  [1]${NC} 添加 Swap (交互式输入大小)"
    echo -e "  ${GREEN}  [2]${NC} 一键添加 1G Swap"
    echo -e "  ${GREEN}  [3]${NC} 一键添加 2G Swap"
    echo -e "  ${GREEN}  [4]${NC} 安装 Zram (内存压缩,小内存VPS推荐)"
    echo -e "  ${GREEN}  [5]${NC} 关闭并删除 Swap"
    echo -ne "  ${BOLD}请选择${NC} > "; read SW
    case "$SW" in
        1)
            read -p "  请输入 Swap 大小 (MB): " SW_SIZE
            [ -z "$SW_SIZE" ] && SW_SIZE=1024
            swapoff /swapfile 2>/dev/null; rm -f /swapfile
            dd if=/dev/zero of=/swapfile bs=1M count=$SW_SIZE 2>/dev/null
            chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
            print_done "Swap 添加 (${SW_SIZE}MB)" ;;
        2) swapoff /swapfile 2>/dev/null; rm -f /swapfile
           dd if=/dev/zero of=/swapfile bs=1M count=1024 2>/dev/null
           chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
           echo '/swapfile none swap sw 0 0' >> /etc/fstab
           print_done "1G Swap 已添加" ;;
        3) swapoff /swapfile 2>/dev/null; rm -f /swapfile
           dd if=/dev/zero of=/swapfile bs=1M count=2048 2>/dev/null
           chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
           echo '/swapfile none swap sw 0 0' >> /etc/fstab
           print_done "2G Swap 已添加" ;;
        4)
            apt install -y zram-tools 2>/dev/null || true
            cat > /etc/default/zramswap << 'ZRAMEOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
ZRAMEOF
            systemctl restart zramswap 2>/dev/null || true
            print_done "Zram 已启用 (50%内存)" ;;
        5) swapoff /swapfile 2>/dev/null; rm -f /swapfile
           sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null
           print_done "Swap 已删除" ;;
        *) echo -e "  ${RED}无效选项${NC}" ;;
    esac
}

# ---- Fail2ban 防爆破 ----
install_fail2ban() {
    confirm_install "Fail2ban" "SSH 防暴力破解工具，自动封禁多次登录失败的 IP (默认3次失败封24h)" "系统仓库版本" "https://github.com/fail2ban/fail2ban" || return
    echo -e "\n  ${BOLD}正在安装 Fail2ban...${NC}"
    apt install -y fail2ban 2>/dev/null || yum install -y fail2ban 2>/dev/null || true
    cat > /etc/fail2ban/jail.local << 'F2BEOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 86400
F2BEOF
    systemctl enable fail2ban --now 2>/dev/null || service fail2ban start 2>/dev/null || true
    print_done "Fail2ban 安装完成"
    echo -e "  封禁时间: 24小时 | 最大重试: 3次"
    echo -e "  查看状态: ${CYAN}fail2ban-client status sshd${NC}"
}

# ---- DD 系统重装 ----
install_dd_reinstall() {
    echo -e "\n  ${BOLD}${RED}⚠ DD 重装将清除服务器所有数据！${NC}"
    echo -e "  ${YELLOW}推荐使用 bin456789/reinstall (支持19种系统)${NC}"
    echo ""
    echo -e "  ${GREEN}  [1]${NC} DD 重装 Debian 12"
    echo -e "  ${GREEN}  [2]${NC} DD 重装 Ubuntu 22.04"
    echo -e "  ${GREEN}  [3]${NC} DD 重装 AlmaLinux 9"
    echo -e "  ${GREEN}  [4]${NC} DD 重装 Windows Server 2022"
    echo -e "  ${GREEN}  [5]${NC} 仅查看 bin456789 脚本用法"
    echo -ne "  ${BOLD}请选择${NC} > "; read DD
    case "$DD" in
        1) echo -e "  ${RED}即将重装为 Debian 12，请确认！${NC}"
           read -p "  输入 YES 确认: " YN; [ "$YN" = "YES" ] || return
           bash <(curl -sSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) debian 12 ;;
        2) echo -e "  ${RED}即将重装为 Ubuntu 22.04，请确认！${NC}"
           read -p "  输入 YES 确认: " YN; [ "$YN" = "YES" ] || return
           bash <(curl -sSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) ubuntu 22.04 ;;
        3) echo -e "  ${RED}即将重装为 AlmaLinux 9，请确认！${NC}"
           read -p "  输入 YES 确认: " YN; [ "$YN" = "YES" ] || return
           bash <(curl -sSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) almalinux 9 ;;
        4) echo -e "  ${RED}即将重装为 Windows，请确认！${NC}"
           read -p "  输入 YES 确认: " YN; [ "$YN" = "YES" ] || return
           bash <(curl -sSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) windows ;;
        5) echo -e "  ${CYAN}项目地址: https://github.com/bin456789/reinstall${NC}"
           echo -e "  用法: bash reinstall.sh <系统> <版本>" ;;
        *) echo -e "  ${RED}无效选项${NC}" ;;
    esac
}

# ---- ACME 免费 SSL 证书 ----
install_acme() {
    echo -e "\n  ${BOLD}ACME 免费 SSL 证书管理${NC}"
    if ! command -v acme.sh &>/dev/null; then
        echo -e "  正在安装 acme.sh..."
        curl https://get.acme.sh | sh
        source ~/.bashrc 2>/dev/null || true
    fi
    echo ""
    echo -e "  ${GREEN}  [1]${NC} 签发证书 (HTTP验证, 需要80端口开放)"
    echo -e "  ${GREEN}  [2]${NC} 签发证书 (DNS验证, 需要API Key)"
    echo -e "  ${GREEN}  [3]${NC} 查看已签发证书"
    echo -e "  ${GREEN}  [4]${NC} 续期所有证书"
    echo -ne "  ${BOLD}请选择${NC} > "; read AC
    case "$AC" in
        1) read -p "  请输入域名: " ACME_DOMAIN
           read -p "  请输入邮箱: " ACME_EMAIL
           ~/.acme.sh/acme.sh --issue -d "$ACME_DOMAIN" --nginx 2>/dev/null || \
           ~/.acme.sh/acme.sh --issue -d "$ACME_DOMAIN" --standalone
           print_done "证书签发完成" ;;
        2) read -p "  请输入域名: " ACME_DOMAIN
           echo -e "  支持的DNS API: ${CYAN}cf/ali/dp/gd${NC}"
           read -p "  请输入DNS提供商: " ACME_DNS
           read -p "  请输入API Key/Token: " ACME_KEY
           ~/.acme.sh/acme.sh --issue --dns "dns_${ACME_DNS}" -d "$ACME_DOMAIN"
           print_done "DNS验证证书签发完成" ;;
        3) ~/.acme.sh/acme.sh --list ;;
        4) ~/.acme.sh/acme.sh --cron --home ~/.acme.sh && print_done "续期完成" ;;
        *) echo -e "  ${RED}无效选项${NC}" ;;
    esac
}

# ---- Aria2 下载器 ----
install_aria2() {
    confirm_install "Aria2" "多协议轻量下载器 (HTTP/FTP/BT/磁力)，systemd 服务化 + RPC(端口6800)" "系统仓库版本" "https://aria2.github.io" || return
    echo -e "\n  ${BOLD}正在安装 Aria2...${NC}"
    apt install -y aria2 2>/dev/null || yum install -y aria2 2>/dev/null || true
    mkdir -p /etc/aria2 /opt/aria2/downloads
    cat > /etc/aria2/aria2.conf << 'ARIAEOF'
dir=/opt/aria2/downloads
enable-rpc=true
rpc-listen-port=6800
rpc-secret=pikash_aria2
max-concurrent-downloads=5
max-connection-per-server=16
split=16
continue=true
file-allocation=falloc
ARIAEOF
    cat > /etc/systemd/system/aria2.service << 'ARIA2EOF'
[Unit]
Description=Aria2 Download Manager
After=network.target
[Service]
ExecStart=/usr/bin/aria2c --conf-path=/etc/aria2/aria2.conf
Restart=always
[Install]
WantedBy=multi-user.target
ARIA2EOF
    systemctl daemon-reload; systemctl enable aria2 --now 2>/dev/null
    print_done "Aria2 安装完成"
    echo -e "  RPC 端口: ${CYAN}6800${NC} | 密钥: ${CYAN}pikash_aria2${NC}"
    echo -e "  下载目录: ${CYAN}/opt/aria2/downloads${NC}"
}

# ---- 服务器监控 (Netdata) ----
install_netdata() {
    echo -e "\n  ${BOLD}正在安装 Netdata 监控...${NC}"
    echo -e "  ${GREEN}  [1]${NC} Netdata (实时监控,功能全面)"
    echo -e "  ${GREEN}  [2]${NC} Cockpit (Web 管理面板,轻量)"
    echo -e "  ${GREEN}  [3]${NC} Glances (命令行监控)"
    echo -ne "  ${BOLD}请选择${NC} > "; read MN
    case "$MN" in
        1) bash <(curl -sSL https://my-netdata.io/kickstart.sh) --stable-channel ;;
        2) apt install -y cockpit 2>/dev/null || yum install -y cockpit 2>/dev/null || true
           systemctl enable cockpit --now 2>/dev/null || true
           print_done "Cockpit 已安装"
           echo -e "  访问: ${CYAN}https://$(curl -s ifconfig.me 2>/dev/null):9090${NC}" ;;
        3) apt install -y glances 2>/dev/null || pip install glances 2>/dev/null || true
           print_done "Glances 已安装"
           echo -e "  运行: ${CYAN}glances${NC}" ;;
        *) echo -e "  ${RED}无效选项${NC}" ;;
    esac
}

# ---- UFW 防火墙 ----
setup_ufw() {
    echo -e "\n  ${BOLD}UFW 防火墙配置${NC}"
    apt install -y ufw 2>/dev/null || true
    echo -e "  ${GREEN}  [1]${NC} 默认安全规则 (允许SSH/80/443)"
    echo -e "  ${GREEN}  [2]${NC} 交互式添加端口"
    echo -e "  ${GREEN}  [3]${NC} 查看状态"
    echo -e "  ${GREEN}  [4]${NC} 启用/禁用防火墙"
    echo -ne "  ${BOLD}请选择${NC} > "; read UF
    case "$UF" in
        1) ufw default deny incoming; ufw default allow outgoing
           ufw allow ssh; ufw allow 80/tcp; ufw allow 443/tcp
           ufw --force enable; print_done "UFW 默认规则已应用" ;;
        2) read -p "  请输入端口 (如 8080/tcp): " UFW_PORT
           ufw allow "$UFW_PORT"; print_done "端口 ${UFW_PORT} 已放行" ;;
        3) ufw status numbered ;;
        4) echo -ne "  [e]启用 [d]禁用 > "; read UF2
           case "$UF2" in e) ufw --force enable ;; d) ufw disable ;; esac ;;
        *) echo -e "  ${RED}无效选项${NC}" ;;
    esac
}

# ---- TCP 优化 ----
tcp_optimize() {
    echo -e "\n  ${BOLD}TCP 网络优化${NC}"
    cat >> /etc/sysctl.conf << 'TCPEOF'

# TCP 优化
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 8192
TCPEOF
    sysctl -p
    print_done "TCP 优化已应用"
}

# ============================================================
# 子菜单 1: 一键部署
# ============================================================
sub_deploy() {
    clear_screen; print_header
    echo -e "  ${BOLD}${CYAN}  ◀ 主菜单                          [1] 一键部署 ▶${NC}"
    print_line
    print_section "系统环境"
    print_item "1"  "更换大陆镜像源"           "Debian(Ubuntu)USTC / CentOS(Aliyun)"
    print_item "2"  "系统更新 + 基础工具"       "curl/wget/git/htop/vim/unzip"
    print_item "3"  "配置代理 (ProxyChains4)"   "SOCKS5 代理链，加速GitHub下载"
    print_item "4"  "安装 Docker + 镜像加速"    "1ms.run 国内镜像源"
    print_item "5"  "安装 Podman + 镜像加速"    "1ms.run 国内镜像源"
    print_section "面板安装"
    print_item "6"  "安装宝塔面板"              "经典 Linux 面板"
    print_item "7"  "安装 1Panel"               "现代化开源面板"
    print_item "8"  "安装 FRP Panel"            "内网穿透面板 (PM2)"
    print_item "9"  "安装 NetPanel"             "轻量服务器管理面板"
    print_item "10" "安装哪吒探针"              "Agent 自动注册"
    print_item "11" "安装 Node.js LTS + PM2"    "NVM + npmmirror 源"
    print_section "组网与中转"
    print_item "12" "安装 EasyTier"             "去中心化 P2P 组网"
    print_item "13" "安装 RustDesk 中转"        "远程桌面中继服务器"
    print_item "14" "安装 ZeroTier"             "虚拟局域网组网"
    print_item "15" "安装 Tailscale"            "WireGuard 组网"
    print_line
    print_item "A"  "全部部署（依次询问）"      ""
    print_item "0"  "返回主菜单"                ""
    print_line
    echo -ne "  ${BOLD}请输入选项${NC} > "
}

exec_deploy() {
    case "$1" in
        1)  switch_apt_mirror ;;
        2)  run_setup 1 ;;       # 系统更新
        3)  run_setup P ;;       # 代理配置
        4)  install_docker ;;
        5)  install_podman ;;
        6)  run_setup 4 ;;       # 宝塔
        7)  install_1panel ;;
        8)  run_setup 8 ;;       # FRP Panel
        9)  install_netpanel ;;
        10) run_setup 5 ;;       # 哪吒
        11) run_setup 3 ;;       # Node.js
        12) run_setup 7 ;;       # EasyTier
        13) run_setup A ;;       # RustDesk
        14) run_setup B ;;       # ZeroTier
        15) run_setup C ;;       # Tailscale
        A|a) run_setup ALL ;;
        0)  return 1 ;;
        *)  echo -e "  ${RED}无效: $1${NC}" ;; 
    esac; return 0
}

# ============================================================
# 子菜单 2: 日常维护
# ============================================================
sub_maintain() {
    clear_screen; print_header
    echo -e "  ${BOLD}${CYAN}  ◀ 主菜单                          [2] 日常维护 ▶${NC}"
    print_line

    print_section "系统优化"
    print_item "1"  "系统垃圾清理"              "apt缓存/journal/Docker/bash历史"
    print_item "2"  "Swap 管理"                 "添加/删除/Zram 虚拟内存"
    print_item "3"  "BBR 网络加速"              "原生BBR/BBR3+FQ/BBR+Cake"
    print_item "4"  "BBRPlus/BBR2/BBR3 多合一" "ylx2016 多版本BBR一键安装"
    print_item "5"  "TCP 网络优化"              "TCP FastOpen/缓冲/backlog"

    print_section "安全防护"
    print_item "6"  "UFW 防火墙"                "一键配置/端口管理/状态查看"
    print_item "7"  "Fail2ban 防爆破"           "SSH 防暴力破解 24h封禁"
    print_item "8"  "屏蔽地区 (BlockAreaBot)"   "一键屏蔽指定国家/地区 IP"

    print_section "系统管理"
    print_item "9"  "端口限速"                  "tc+IFB 双向限速(自定义端口/速率)"
    print_item "10" "升级/替换内核"             "XanMod/Liquorix/Backports/HWE"
    print_item "11" "DD 系统重装"               "一键重装Debian/Ubuntu/Win(bin456789)"

    print_section "常用工具"
    print_item "12" "ACME 免费SSL证书"          "自动签发/续期 Let's Encrypt"
    print_item "13" "Aria2 下载器"              "离线下载+RPC(端口6800)"
    print_item "14" "服务器监控"                "Netdata/Cockpit/Glances"

    print_line
    print_item "0"  "返回主菜单"                ""
    print_line
    echo -ne "  ${BOLD}请输入选项${NC} > "
}

exec_maintain() {
    case "$1" in
        1) run_clean ;;
        2) manage_swap ;;
        3) install_bbr ;;
        4) install_bbrplus ;;
        5) tcp_optimize ;;
        6) setup_ufw ;;
        7) install_fail2ban ;;
        8) block_area_bot ;;
        9) run_setup 9 ;;
        10) upgrade_kernel ;;
        11) install_dd_reinstall ;;
        12) install_acme ;;
        13) install_aria2 ;;
        14) install_netdata ;;
        0) return 1 ;;
        *) echo -e "  ${RED}无效: $1${NC}" ;;
    esac; return 0
}

# ============================================================
# 子菜单 3: 桌面安装
# ============================================================
sub_desktop() {
    clear_screen; print_header
    echo -e "  ${BOLD}${CYAN}  ◀ 主菜单                          [3] 桌面安装 ▶${NC}"
    print_line
    print_tip "安装顺序: 基础环境 → X11图形栈 → 选择桌面"
    print_line
    print_section "前置层"
    print_item "1"  "Server 基础环境"           "换 USTC 源、SSH、sudo/vim/git"
    print_item "2"  "X11 图形栈"                "Xserver + NoMachine 远程桌面"
    print_section "桌面环境"
    print_item "3"  "Deepin / GXDE"             "中文友好、美观的 Deepin 风格"
    print_item "4"  "KDE Plasma"                "高度可定制的现代桌面"
    print_item "5"  "KDE Lingmo"                "KDE 国风变体"
    print_item "6"  "Xfce 轻量桌面"             "资源占用低、稳定流畅"
    print_item "7"  "GNOME 3"                   "简洁现代的工作流桌面"
    print_item "8"  "MATE 经典"                 "传统菜单风格、稳定耐用"
    print_line
    print_item "A"  "全套安装"                  "基础→图形→自选桌面"
    print_item "0"  "返回主菜单"                ""
    print_line
    echo -ne "  ${BOLD}请输入选项${NC} > "
}

exec_desktop() {
    case "$1" in
        1) run_script_pipe "Linux/Desktop/LXC-Debian-Server.sh" ;;
        2) run_script_pipe "Linux/Desktop/LXC-Debian-Graphy.sh" ;;
        3) run_script_pipe "Linux/Desktop/LXC-Debian-Deepin.sh" ;;
        4) run_script_pipe "Linux/Desktop/LXC-Debian-Plasma.sh" ;;
        5) run_script_pipe "Linux/Desktop/LXC-Debian-Lingmo.sh" ;;
        6) run_script_pipe "Linux/Desktop/LXC-Debian-Xfce4L.sh" ;;
        7) run_script_pipe "Linux/Desktop/LXC-Debian-Gnome3.sh" ;;
        8) run_script_pipe "Linux/Desktop/LXC-Debian-MateDE.sh" ;;
        A|a) run_script_pipe "Linux/Desktop/LXC-Debian-Server.sh"
             run_script_pipe "Linux/Desktop/LXC-Debian-Graphy.sh"
             echo -ne "  ${BOLD}请选择桌面 (3-8)${NC} > "; read DD; exec_desktop "$DD" ;;
        0) return 1 ;;
        *) echo -e "  ${RED}无效: $1${NC}" ;;
    esac; return 0
}

# ============================================================
# 子菜单 4: 性能测评
# ============================================================
sub_bench() {
    clear_screen; print_header
    echo -e "  ${BOLD}${CYAN}  ◀ 主菜单                          [4] 性能测评 ▶${NC}"
    print_line
    print_section "综合测评"
    print_item "1"  "融合怪 综合测评"           "CPU/内存/磁盘/网络/流媒体"
    print_item "2"  "IP 质量体检"               "多数据库风险评分+流媒体+邮局"
    print_item "3"  "LemonBench"                "CPU/内存/磁盘/网络基准"
    print_item "4"  "YABS 基准测试"             "iperf3+Geekbench+fio"
    print_item "5"  "UnixBench"                 "类Unix综合性能跑分"
    print_item "6"  "Bench.sh (秋水逸冰)"       "系统信息+IO+网速"
    print_item "7"  "SuperBench"                "系统信息+IO+全国测速"
    print_item "8"  "SuperSpeed"                "三网Speedtest全面测速"
    print_section "网络诊断"
    print_item "9"  "BackTrace 回程路由"        "三网回程路由"
    print_item "10" "SuperTrace"                "北上广路由追踪"
    print_item "11" "BestTrace (IPIP)"          "IPIP.net交互式路由"
    print_item "12" "mPing 全国延迟"            "全国多地域Ping"
    print_item "13" "PrettyPing"                "彩色图形化Ping"
    print_line
    print_item "A"  "全部跑一遍"                "依次执行（耗时长）"
    print_item "0"  "返回主菜单"                ""
    print_line
    echo -ne "  ${BOLD}请输入选项${NC} > "
}

exec_bench() {
    case "$1" in
        1) run_bench "ecss-bench.sh";; 2) run_bench "ip-quality.sh";;
        3) run_bench "lemonbench.sh";; 4) run_bench "yabs-bench.sh";;
        5) run_bench "unix-bench.sh";; 6) run_bench "qsyb-bench.sh";;
        7) run_bench "superbench.sh";; 8) run_bench "superspeed.sh";;
        9) run_bench "back-trace.sh";; 10) run_bench "supertrace.sh";;
        11) run_bench "best-trace.sh";; 12) run_bench "mping-test.sh";;
        13) run_bench "prettyping.sh";;
        A|a) for S in ecss-bench.sh ip-quality.sh superbench.sh superspeed.sh back-trace.sh; do
                echo -e "\n  ${YELLOW}>>> 运行: $S${NC}"; run_bench "$S"; done ;;
        0) return 1 ;;
        *) echo -e "  ${RED}无效: $1${NC}" ;;
    esac; return 0
}

# ============================================================
# 子菜单 5: 代理配置
# ============================================================
sub_proxy() {
    clear_screen; print_header
    echo -e "  ${BOLD}${CYAN}  ◀ 主菜单                          [5] 代理配置 ▶${NC}"
    print_line

    print_section "面板管理"
    print_item "1"  "安装 3X-UI 面板"           "Xray-core 多协议 Web 面板"

    print_section "代理协议一键部署"
    print_item "2"  "Clash for Linux"           "基于 Clash 的代理客户端"
    print_item "3"  "Hysteria2 (HY2)"           "高速 UDP 代理协议"
    print_item "4"  "Shadowsocks-rust"          "经典 Shadowsocks (Rust版)"
    print_item "5"  "Trojan-Go"                 "Trojan 协议的 Go 实现"

    print_section "组网与加速"
    print_item "6"  "Cloudflare WARP"           "WARP CLI / WGCF 一键部署+管理"
    print_item "7"  "WireGuard 部署"            "原生 WireGuard 安装+密钥生成"
    print_item "8"  "wg-easy 部署"              "Docker Web 管理 WireGuard"
    print_item "9"  "EasyTier 组网配置"         "增加/删除/查看 config-server 并应用"

    print_line
    print_item "0"  "返回主菜单"                ""
    print_line
    echo -ne "  ${BOLD}请输入选项${NC} > "
}

exec_proxy() {
    case "$1" in
        1) install_3xui ;;
        2) install_clash_linux ;;
        3) install_hy2 ;;
        4) install_shadowsocks ;;
        5) install_trojan ;;
        6) install_warp ;;
        7) install_wireguard ;;
        8) install_wgeasy ;;
        9) manage_easytier_config ;;
        0) return 1 ;;
        *) echo -e "  ${RED}无效: $1${NC}" ;;
    esac; return 0
}

# ============================================================
# 主菜单
# ============================================================
main_menu() {
    clear_screen; print_header
    print_line
    print_item "1"  "🖥️  一键部署"               "一键换源/面板/探针/组网/中转"
    print_item "2"  "🔧 日常维护"               "垃圾清理/限速/更新/屏蔽/加速"
    print_item "3"  "🎨 桌面安装"               "桌面安装/配置/更新/维护/卸载"
    print_item "4"  "📊 性能测评"               "测评性能/网络/线路/延迟/回程"
    print_item "5"  "🌐 代理配置"               "配置代理/出站/入站/WARP/SOCK"
    print_line
    print_item "0"  "退出"                      ""
    print_line
    echo -ne "  ${BOLD}请选择${NC} > "
}

# ---- Windows ----
windows_menu() {
    clear_screen; print_header
    print_line
    print_item "1"  "Docker CE 安装"            "Hyper-V / Native 双运行时"
    print_item "2"  "Mirantis 容器运行时"       "Docker CE 替代方案"
    print_item "3"  "containerd + nerdctl"      "轻量容器方案"
    print_item "10" "Windows / Office 激活"     "MAS AIO 全功能激活"
    print_line
    print_tip "Windows 脚本需在 PowerShell (管理员) 中运行"
    print_line
    print_item "0"  "退出"                      ""
    print_line
    echo -ne "  ${BOLD}请选择${NC} > "
}

show_windows_cmd() {
    case "$1" in
        1)  echo -e "  ${GREEN}PowerShell:${NC} irm ${CDN_BASE}/WinNT/Docker/Winx86-dockerce.ps1 | iex" ;;
        2)  echo -e "  ${GREEN}PowerShell:${NC} irm ${CDN_BASE}/WinNT/Docker/Winx86-mirantis.ps1 | iex" ;;
        3)  echo -e "  ${GREEN}PowerShell:${NC} irm ${CDN_BASE}/WinNT/Docker/Winx86-nerdctls.ps1 | iex" ;;
        10) echo -e "  ${GREEN}PowerShell:${NC} irm ${CDN_BASE}/WinNT/Active/MAS_AIO.cmd | iex" ;;
        0)  return 1 ;;
        *)  echo -e "  ${RED}无效: $1${NC}" ;;
    esac; return 0
}

# ============================================================
# 主流程
# ============================================================
run_submenu() {
    local CAT="$1"; local CHOICE
    while true; do
        case "$CAT" in
            1) sub_deploy;; 2) sub_maintain;; 3) sub_desktop;; 4) sub_bench;; 5) sub_proxy;;
        esac
        read CHOICE; [ -z "$CHOICE" ] && continue
        case "$CAT" in
            1) exec_deploy "$CHOICE" || break ;;  2) exec_maintain "$CHOICE" || break ;;
            3) exec_desktop "$CHOICE" || break ;;  4) exec_bench "$CHOICE" || break ;;
            5) exec_proxy "$CHOICE" || break ;;
        esac
        echo ""; echo -ne "  ${BOLD}按 Enter 继续，输入 0 返回${NC} > "; read NEXT
        [ "$NEXT" = "0" ] && break
    done
}

main() {
    while true; do
        case "$OS_TYPE" in
            linux)   main_menu ;;
            windows) windows_menu ;;
            *) echo -e "${RED}不支持的系统${NC}"; echo "https://github.com/PIKACHUIM/CloudScripts"; exit 1 ;;
        esac
        read CHOICE; [ -z "$CHOICE" ] && continue
        case "$OS_TYPE" in
            linux)
                case "$CHOICE" in
                    1|2|3|4|5) run_submenu "$CHOICE" ;;
                    0) echo -e "${GREEN}再见！${NC}"; exit 0 ;;
                    *) echo -e "  ${RED}无效选项${NC}" ;;
                esac ;;
            windows)
                show_windows_cmd "$CHOICE" || { echo -e "${GREEN}再见！${NC}"; exit 0; }
                echo ""; echo -ne "  ${BOLD}按 Enter 继续${NC} > "; read _ ;;
        esac
    done
}

main "$@"
