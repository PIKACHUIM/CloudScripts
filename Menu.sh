#!/usr/bin/env bash
# ============================================================
#  皮卡在线脚本托管平台 - 总菜单
#  自动检测系统类型，按类别展示可用脚本
#  支持交互式菜单和命令行参数两种模式
#
#  使用方式:
#    交互式:    bash Menu.sh
#    直接执行:  bash Menu.sh <编号>
#    远程一键:  bash <(curl -s https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)
#    国内加速:  bash <(curl -s https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)
# ============================================================

set -e

# ---- 颜色定义 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ---- CDN 基础地址 ----
# 直连地址 (GitHub Raw)
CDN_RAW="https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
# 加速地址 (国内镜像)
CDN_MIRROR="https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"

# 自动测速选择最快的CDN
_choose_cdn() {
    # 优先直连，超时则切镜像
    if curl -s --connect-timeout 3 --max-time 5 "${CDN_RAW}/Menu.sh" > /dev/null 2>&1; then
        echo "$CDN_RAW"
    elif curl -s --connect-timeout 3 --max-time 5 "${CDN_MIRROR}/Menu.sh" > /dev/null 2>&1; then
        echo "$CDN_MIRROR"
    else
        echo "$CDN_RAW"  # 回退
    fi
}
CDN_BASE=$(_choose_cdn)

# ---- 系统检测 ----
detect_os() {
    local OS_TYPE="unknown"
    local OS_DETAIL=""

    case "$(uname -s)" in
        Linux)
            OS_TYPE="linux"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS_DETAIL="${NAME:-Linux}"
            else
                OS_DETAIL="Linux"
            fi
            ;;
        Darwin)
            OS_TYPE="macos"
            OS_DETAIL="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS_TYPE="windows"
            OS_DETAIL="Windows (Git Bash / MSYS2)"
            ;;
        *)
            OS_TYPE="unknown"
            OS_DETAIL="$(uname -s)"
            ;;
    esac

    echo "$OS_TYPE|$OS_DETAIL"
}

OS_INFO=$(detect_os)
OS_TYPE="${OS_INFO%%|*}"
OS_DETAIL="${OS_INFO##*|}"

# ---- 打印函数 ----
print_header() {
    clear
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║                                                      ║"
    echo "  ║      ██████╗ ██╗██╗  ██╗ █████╗                      ║"
    echo "  ║      ██╔══██╗██║██║ ██╔╝██╔══██╗                     ║"
    echo "  ║      ██████╔╝██║█████╔╝ ███████║                     ║"
    echo "  ║      ██╔═══╝ ██║██╔═██╗ ██╔══██║                     ║"
    echo "  ║      ██║     ██║██║  ██╗██║  ██║                     ║"
    echo "  ║      ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝                     ║"
    echo "  ║                                                      ║"
    echo "  ║         皮卡在线脚本托管平台 - 总菜单                  ║"
    echo "  ║         ${CDN_BASE}                  ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}检测到系统:${NC} ${GREEN}${OS_DETAIL}${NC}"
    echo ""
}

print_section() {
    echo -e "${YELLOW}${BOLD}  ── $1 ──${NC}"
}

print_item() {
    local NUM="$1"
    local NAME="$2"
    local DESC="$3"
    printf "  ${GREEN}%4s${NC}  ${BOLD}%-30s${NC} ${BLUE}%s${NC}\n" "[$NUM]" "$NAME" "$DESC"
}

print_tip() {
    echo -e "  ${MAGENTA}  💡 $1${NC}"
}

# ---- Linux 菜单 ----
linux_menu() {
    print_header

    print_section "服务器部署与管理"
    print_item "1"  "VPS 一键部署"            "系统初始化/面板/组网/限速 一站式部署"
    print_item "2"  "系统清理"                "清理 apt 缓存、日志、Docker 垃圾"
    print_item "3"  "3X-UI 面板管理"          "Xray-core 多协议代理面板安装与管理"
    print_item "4"  "端口限速工具"            "tc+IFB 双向端口流量限速（支持范围/自定义速率）"
    echo ""

    print_section "桌面环境安装 (Debian LXC 容器)"
    print_item "10" "Server 基础环境"         "换源、SSH、基础工具（前置步骤）"
    print_item "11" "X11 图形栈"              "Xserver + NoMachine 远程桌面（前置步骤）"
    print_item "12" "Deepin / GXDE 桌面"      "中文友好、美观的 Deepin 风格桌面"
    print_item "13" "KDE Plasma 桌面"         "高度可定制的现代桌面"
    print_item "14" "KDE Lingmo 桌面"         "KDE 国风变体"
    print_item "15" "Xfce 轻量桌面"           "资源占用低、稳定流畅"
    print_item "16" "GNOME 3 桌面"            "简洁现代的工作流桌面"
    print_item "17" "MATE 经典桌面"           "传统菜单风格、稳定耐用"
    echo ""

    print_section "性能测评"
    print_item "20" "融合怪 综合测评"         "CPU/内存/磁盘/网络/流媒体 全面检测"
    print_item "21" "IP 质量体检"             "多数据库风险评分 + 流媒体 + 邮局连通性"
    print_item "22" "LemonBench"              "CPU/内存/磁盘/网络 基准测试"
    print_item "23" "YABS 基准测试"           "iperf3 + Geekbench + fio 跨平台测试"
    print_item "24" "UnixBench"               "类Unix系统综合性能跑分"
    print_item "25" "Bench.sh (秋水逸冰)"     "系统信息 + IO + 网速基准"
    print_item "26" "SuperBench (老鬼)"       "系统信息 + IO + 全国测速"
    print_item "27" "SuperSpeed"              "全国三网 Speedtest 全面测速"
    echo ""

    print_section "网络诊断"
    print_item "30" "BackTrace 回程路由"      "三网回程路由自动测试"
    print_item "31" "SuperTrace (老鬼)"       "北上广三大运营商路由追踪"
    print_item "32" "BestTrace (IPIP)"        "IPIP.net 交互式路由追踪"
    print_item "33" "mPing 全国延迟"          "全国多地域 Ping 测试"
    print_item "34" "PrettyPing"              "彩色图形化 Ping 输出"
    echo ""

    print_section "其他"
    print_item "99" "显示此菜单"
    print_item "0"  "退出"
    echo ""
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}输入编号执行脚本，多个编号用空格分隔 (如: 1 20 30)${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
}

# ---- Windows 菜单 ----
windows_menu() {
    print_header

    print_section "Docker / 容器引擎"
    print_item "1"  "Docker CE 安装"          "Hyper-V / Native 双运行时"
    print_item "2"  "Mirantis 容器运行时"     "Docker CE 替代方案"
    print_item "3"  "containerd + nerdctl"    "轻量容器方案（无需 Docker daemon）"
    echo ""

    print_section "系统工具"
    print_item "10" "Windows / Office 激活"   "MAS AIO 全功能激活脚本"
    echo ""

    print_tip "Windows 脚本需在 PowerShell (管理员) 中运行"
    print_tip "当前终端为 Git Bash / MSYS2，将显示 PowerShell 命令"
    echo ""
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}输入编号查看执行命令，多个编号用空格分隔${NC}"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────${NC}"
}

# ---- macOS 菜单 ----
macos_menu() {
    print_header
    echo -e "  ${YELLOW}⚠ macOS 当前暂无专用脚本，以下为通用 Linux 脚本（部分兼容）${NC}"
    echo ""
    print_section "通用工具"
    print_item "1"  "系统清理"                "清理缓存和日志"
    print_item "2"  "Speedtest 测速"          "speedtest-cli 网络测速"
    print_item "0"  "退出"
    echo ""
}

# ---- 脚本执行逻辑 ----

# Linux 脚本执行
exec_linux_script() {
    local NUM="$1"
    case "$NUM" in
        # 服务器部署与管理
        1)  bash <(curl -s "${CDN_BASE}/Linux/VPSSets/Setup.sh") ;;
        2)  apt -y install curl 2>/dev/null; curl -s "${CDN_BASE}/Linux/Cleaner/LinuxClean.sh" | bash ;;
        3)  bash <(curl -sL "${CDN_BASE}/Linux/Tunnels/3x-ui/x-ui.sh") ;;
        4)  bash <(curl -s "${CDN_BASE}/Linux/VPSSets/Setup.sh") 9 ;;

        # 桌面环境
        10) curl -s "${CDN_BASE}/Linux/Desktop/LXC-Debian-Server.sh" | bash -e ;;
        11) curl -s "${CDN_BASE}/Linux/Desktop/LXC-Debian-Graphy.sh" | bash -e ;;
        12) curl -s "${CDN_BASE}/Linux/Desktop/LXC-Debian-Deepin.sh" | bash -e ;;
        13) curl -s "${CDN_BASE}/Linux/Desktop/LXC-Debian-Plasma.sh" | bash -e ;;
        14) curl -s "${CDN_BASE}/Linux/Desktop/LXC-Debian-Lingmo.sh" | bash -e ;;
        15) curl -s "${CDN_BASE}/Linux/Desktop/LXC-Debian-Xfce4L.sh" | bash -e ;;
        16) curl -s "${CDN_BASE}/Linux/Desktop/LXC-Debian-Gnome3.sh" | bash -e ;;
        17) curl -s "${CDN_BASE}/Linux/Desktop/LXC-Debian-MateDE.sh" | bash -e ;;

        # 性能测评
        20) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/ecss-bench.sh") ;;
        21) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/ip-quality.sh") ;;
        22) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/lemonbench.sh") ;;
        23) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/yabs-bench.sh") ;;
        24) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/unix-bench.sh") ;;
        25) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/qsyb-bench.sh") ;;
        26) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/superbench.sh") ;;
        27) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/superspeed.sh") ;;

        # 网络诊断
        30) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/back-trace.sh") ;;
        31) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/supertrace.sh") ;;
        32) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/best-trace.sh") ;;
        33) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/mping-test.sh") ;;
        34) bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/prettyping.sh") ;;

        # 其他
        99) linux_menu; return 2 ;;  # 返回信号2表示仅显示菜单
        0)  echo -e "${GREEN}再见！${NC}"; exit 0 ;;

        *)  echo -e "${RED}无效选项: $NUM${NC}" ;;
    esac
}

# Windows 显示命令
show_windows_cmd() {
    local NUM="$1"
    case "$NUM" in
        1)  echo -e "${GREEN}执行以下命令 (PowerShell 管理员):${NC}"
            echo -e "  ${CYAN}irm ${CDN_BASE}/WinNT/Docker/Winx86-dockerce.ps1 | iex${NC}"
            ;;
        2)  echo -e "${GREEN}执行以下命令 (PowerShell 管理员):${NC}"
            echo -e "  ${CYAN}irm ${CDN_BASE}/WinNT/Docker/Winx86-mirantis.ps1 | iex${NC}"
            ;;
        3)  echo -e "${GREEN}执行以下命令 (PowerShell 管理员):${NC}"
            echo -e "  ${CYAN}irm ${CDN_BASE}/WinNT/Docker/Winx86-nerdctls.ps1 | iex${NC}"
            ;;
        10) echo -e "${GREEN}执行以下命令 (PowerShell 管理员):${NC}"
            echo -e "  ${CYAN}irm ${CDN_BASE}/WinNT/Active/MAS_AIO.cmd | iex${NC}"
            ;;
        0)  echo -e "${GREEN}再见！${NC}"; exit 0 ;;
        *)  echo -e "${RED}无效选项: $NUM${NC}" ;;
    esac
}

# macOS 执行
exec_macos_script() {
    local NUM="$1"
    case "$NUM" in
        1)  echo "暂未实现" ;;
        2)  bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/speed-test.py") ;;
        0)  echo -e "${GREEN}再见！${NC}"; exit 0 ;;
        *)  echo -e "${RED}无效选项: $NUM${NC}" ;;
    esac
}

# ---- 主流程 ----

main() {
    # 如果有命令行参数，直接执行对应编号
    if [ $# -gt 0 ]; then
        for ARG in "$@"; do
            case "$OS_TYPE" in
                linux)    exec_linux_script "$ARG" ;;
                windows)  show_windows_cmd "$ARG" ;;
                macos)    exec_macos_script "$ARG" ;;
                *)
                    echo -e "${RED}不支持的操作系统: ${OS_DETAIL}${NC}"
                    echo "项目地址: ${CDN_BASE}"
                    exit 1
                    ;;
            esac
        done
        exit 0
    fi

    # 交互式菜单循环
    while true; do
        case "$OS_TYPE" in
            linux)    linux_menu ;;
            windows)  windows_menu ;;
            macos)    macos_menu ;;
            *)
                echo -e "${RED}不支持的操作系统: ${OS_DETAIL}${NC}"
                echo "请手动访问: ${CDN_BASE}"
                exit 1
                ;;
        esac

        echo -ne "  ${BOLD}请输入选项${NC} > "
        read -ra CHOICES

        if [ ${#CHOICES[@]} -eq 0 ]; then
            continue
        fi

        for CH in "${CHOICES[@]}"; do
            case "$OS_TYPE" in
                linux)   exec_linux_script "$CH" ;;
                windows) show_windows_cmd "$CH" ;;
                macos)   exec_macos_script "$CH" ;;
            esac
        done

        echo ""
        echo -ne "  ${BOLD}按 Enter 返回菜单，输入 q 退出${NC} > "
        read NEXT
        [ "$NEXT" = "q" ] || [ "$NEXT" = "Q" ] && break
    done

    echo -e "${GREEN}感谢使用皮卡在线脚本平台！${NC}"
}

main "$@"
