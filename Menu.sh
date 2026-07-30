#!/usr/bin/env bash
# ============================================================
#  皮卡在线脚本托管平台 - 总菜单
#  两级菜单：主菜单(4大类) → 子菜单(具体脚本)
#
#  使用方式:
#    远程一键:  bash <(curl -s https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)
#    国内加速:  bash <(curl -s https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)
# ============================================================

set -e

# ---- 颜色定义 ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

# ---- CDN 地址 ----
CDN_RAW="https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
CDN_MIRROR="https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
_choose_cdn() {
    if curl -s --connect-timeout 3 --max-time 5 "${CDN_RAW}/Menu.sh" > /dev/null 2>&1; then
        echo "$CDN_RAW"
    elif curl -s --connect-timeout 3 --max-time 5 "${CDN_MIRROR}/Menu.sh" > /dev/null 2>&1; then
        echo "$CDN_MIRROR"
    else
        echo "$CDN_RAW"
    fi
}
CDN_BASE=$(_choose_cdn)

# ---- 系统检测 ----
detect_os() {
    case "$(uname -s)" in
        Linux)  echo "linux|$(. /etc/os-release 2>/dev/null && echo "${NAME:-Linux}" || echo 'Linux')" ;;
        Darwin) echo "macos|macOS $(sw_vers -productVersion 2>/dev/null || echo '')" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows|Windows (Git Bash / MSYS2)" ;;
        *)      echo "unknown|$(uname -s)" ;;
    esac
}
OS_INFO=$(detect_os)
OS_TYPE="${OS_INFO%%|*}"; OS_DETAIL="${OS_INFO##*|}"

# ---- 打印函数 ----
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
print_item() { printf "  ${GREEN}%4s${NC}  ${BOLD}%-28s${NC} ${BLUE}%s${NC}\n" "[$1]" "$2" "$3"; }
print_tip() { echo -e "  ${MAGENTA}  💡 $1${NC}"; }

# ---- 脚本执行器 ----
run_setup() { bash <(curl -s "${CDN_BASE}/Linux/VPSSets/Setup.sh") "$@"; }
run_script() { bash <(curl -s "${CDN_BASE}/$1"); }
run_script_pipe() { curl -s "${CDN_BASE}/$1" | bash -e; }
run_bench() { bash <(wget -qO- "${CDN_BASE}/Linux/VPSTest/$1"); }
run_clean() { apt -y install curl 2>/dev/null; curl -s "${CDN_BASE}/Linux/Cleaner/LinuxClean.sh" | bash; }

# ============================================================
# 子菜单：一键部署
# ============================================================
sub_deploy() {
    clear_screen; print_header
    echo -e "  ${BOLD}${CYAN}  ◀ 主菜单                          [1] 一键部署 ▶${NC}"
    print_line

    print_section "系统环境"
    print_item "1"  "系统更新 + 基础工具"       "apt update/upgrade, curl/wget/git/htop/vim"
    print_item "2"  "配置 ProxyChains4"         "SOCKS5 代理链，加速后续下载"

    print_section "面板与探针"
    print_item "3"  "安装 Node.js LTS + PM2"    "NVM 安装，npmmirror 源"
    print_item "4"  "安装宝塔面板"              "自动配置用户名密码端口"
    print_item "5"  "安装哪吒探针"              "Agent 自动注册到服务端"
    print_item "6"  "安装 3X-UI 面板"           "Xray-core 多协议代理面板"

    print_section "组网与中转"
    print_item "7"  "安装 EasyTier"             "去中心化 P2P 组网 (PM2)"
    print_item "8"  "安装 FRP Panel"            "内网穿透面板 (PM2)"
    print_item "9"  "安装 RustDesk 中转"        "远程桌面中继服务器"
    print_item "10" "安装 ZeroTier"             "虚拟局域网组网"
    print_item "11" "安装 Tailscale"            "WireGuard 组网"

    print_line
    print_item "A"  "全部部署（依次询问）"      ""
    print_item "0"  "返回主菜单"                ""
    print_line
    echo -ne "  ${BOLD}请输入选项${NC} > "
}

exec_deploy() {
    case "$1" in
        1) run_setup 1 ;;       # 系统初始化
        2) run_setup 2 ;;       # ProxyChains4
        3) run_setup 3 ;;       # Node.js
        4) run_setup 4 ;;       # 宝塔
        5) run_setup 5 ;;       # 哪吒
        6) run_setup 6 ;;       # 3X-UI
        7) run_setup 7 ;;       # EasyTier
        8) run_setup 8 ;;       # FRP
        9) run_setup A ;;       # RustDesk
        10) run_setup B ;;      # ZeroTier
        11) run_setup C ;;      # Tailscale
        A|a) run_setup ALL ;;   # 全部
        0) return 1 ;;
        *) echo -e "  ${RED}无效选项: $1${NC}" ;;
    esac
    return 0
}

# ============================================================
# 子菜单：日常维护
# ============================================================
sub_maintain() {
    clear_screen; print_header
    echo -e "  ${BOLD}${CYAN}  ◀ 主菜单                          [2] 日常维护 ▶${NC}"
    print_line
    print_item "1"  "系统清理"                  "清理 apt 缓存、journal 日志、Docker 垃圾、bash 历史"
    print_item "2"  "端口限速"                  "tc+IFB 双向限速，支持端口范围和自定义速率"
    print_line
    print_item "0"  "返回主菜单"                ""
    print_line
    echo -ne "  ${BOLD}请输入选项${NC} > "
}

exec_maintain() {
    case "$1" in
        1) run_clean ;;
        2) run_setup 9 ;;    # 端口限速
        0) return 1 ;;
        *) echo -e "  ${RED}无效选项: $1${NC}" ;;
    esac
    return 0
}

# ============================================================
# 子菜单：桌面安装
# ============================================================
sub_desktop() {
    clear_screen; print_header
    echo -e "  ${BOLD}${CYAN}  ◀ 主菜单                          [3] 桌面安装 ▶${NC}"
    print_line
    print_tip "安装顺序: 基础环境 → X11图形栈 → 选择桌面"
    print_line

    print_section "前置层"
    print_item "1"  "Server 基础环境"           "换 USTC 源、SSH、sudo/vim/git 等"
    print_item "2"  "X11 图形栈"                "Xserver + NoMachine 远程桌面"

    print_section "桌面环境"
    print_item "3"  "Deepin / GXDE"             "中文友好、美观的 Deepin 风格"
    print_item "4"  "KDE Plasma"                "高度可定制的现代桌面"
    print_item "5"  "KDE Lingmo"                "KDE 国风变体"
    print_item "6"  "Xfce 轻量桌面"             "资源占用低、稳定流畅"
    print_item "7"  "GNOME 3"                   "简洁现代的工作流桌面"
    print_item "8"  "MATE 经典"                 "传统菜单风格、稳定耐用"

    print_line
    print_item "A"  "全套安装"                  "基础→图形→自选桌面（依次引导）"
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
        A|a)
            echo -e "  ${GREEN}开始全套安装...${NC}"
            run_script_pipe "Linux/Desktop/LXC-Debian-Server.sh"
            run_script_pipe "Linux/Desktop/LXC-Debian-Graphy.sh"
            echo -ne "  ${BOLD}请选择桌面 (3-8)${NC} > "; read DD
            exec_desktop "$DD"
            ;;
        0) return 1 ;;
        *) echo -e "  ${RED}无效选项: $1${NC}" ;;
    esac
    return 0
}

# ============================================================
# 子菜单：性能测评
# ============================================================
sub_bench() {
    clear_screen; print_header
    echo -e "  ${BOLD}${CYAN}  ◀ 主菜单                          [4] 性能测评 ▶${NC}"
    print_line

    print_section "综合测评"
    print_item "1"  "融合怪 综合测评"           "CPU/内存/磁盘/网络/流媒体 全面检测"
    print_item "2"  "IP 质量体检"               "多数据库风险评分 + 流媒体 + 邮局"
    print_item "3"  "LemonBench"                "CPU/内存/磁盘/网络 基准测试"
    print_item "4"  "YABS 基准测试"             "iperf3 + Geekbench + fio"
    print_item "5"  "UnixBench"                 "类Unix系统综合性能跑分"
    print_item "6"  "Bench.sh (秋水逸冰)"       "系统信息 + IO + 网速基准"
    print_item "7"  "SuperBench"                "系统信息 + IO + 全国测速"
    print_item "8"  "SuperSpeed"                "全国三网 Speedtest 全面测速"

    print_section "网络诊断"
    print_item "9"  "BackTrace 回程路由"        "三网回程路由自动测试"
    print_item "10" "SuperTrace"                "北上广三大运营商路由追踪"
    print_item "11" "BestTrace (IPIP)"          "IPIP.net 交互式路由追踪"
    print_item "12" "mPing 全国延迟"            "全国多地域 Ping 测试"
    print_item "13" "PrettyPing"                "彩色图形化 Ping 输出"

    print_line
    print_item "A"  "全部跑一遍"                "依次执行全部测评（耗时长）"
    print_item "0"  "返回主菜单"                ""
    print_line
    echo -ne "  ${BOLD}请输入选项${NC} > "
}

exec_bench() {
    case "$1" in
        1)  run_bench "ecss-bench.sh" ;;
        2)  run_bench "ip-quality.sh" ;;
        3)  run_bench "lemonbench.sh" ;;
        4)  run_bench "yabs-bench.sh" ;;
        5)  run_bench "unix-bench.sh" ;;
        6)  run_bench "qsyb-bench.sh" ;;
        7)  run_bench "superbench.sh" ;;
        8)  run_bench "superspeed.sh" ;;
        9)  run_bench "back-trace.sh" ;;
        10) run_bench "supertrace.sh" ;;
        11) run_bench "best-trace.sh" ;;
        12) run_bench "mping-test.sh" ;;
        13) run_bench "prettyping.sh" ;;
        A|a)
            for S in ecss-bench.sh ip-quality.sh superbench.sh superspeed.sh back-trace.sh; do
                echo -e "\n  ${YELLOW}>>> 运行: $S${NC}"
                run_bench "$S"
            done
            ;;
        0) return 1 ;;
        *) echo -e "  ${RED}无效选项: $1${NC}" ;;
    esac
    return 0
}

# ============================================================
# 主菜单
# ============================================================
main_menu() {
    clear_screen; print_header
    print_line
    print_item "1"  "🖥️ 一键部署"             "一键换源/面板/探针/组网/中转"
    print_item "2"  "🔧 日常维护"             "垃圾清理/限速/更新/屏蔽/加速"
    print_item "3"  "🎨 桌面安装"             "桌面安装/配置/更新/维护/卸载"
    print_item "4"  "📊 性能测评"             "测评性能/网络/线路/延迟/回程"
    print_line
    print_item "0"  "退出"                      ""
    print_line
    echo -ne "  ${BOLD}请选择${NC} > "
}

# ---- Windows 菜单 ----
windows_menu() {
    clear_screen; print_header
    print_line
    print_item "1"  "Docker CE 安装"            "Hyper-V / Native 双运行时"
    print_item "2"  "Mirantis 容器运行时"       "Docker CE 替代方案"
    print_item "3"  "containerd + nerdctl"      "轻量容器方案"
    print_item "10" "Windows / Office 激活"     "MAS AIO 全功能激活"
    print_line
    print_tip "Windows 脚本需在 PowerShell (管理员) 中运行"
    print_tip "当前为 Git Bash，将显示 PowerShell 命令"
    print_line
    print_item "0"  "退出"                      ""
    print_line
    echo -ne "  ${BOLD}请选择${NC} > "
}

show_windows_cmd() {
    case "$1" in
        1)  echo -e "  ${GREEN}PowerShell 管理员执行:${NC}"
            echo -e "  ${CYAN}irm ${CDN_BASE}/WinNT/Docker/Winx86-dockerce.ps1 | iex${NC}" ;;
        2)  echo -e "  ${GREEN}PowerShell 管理员执行:${NC}"
            echo -e "  ${CYAN}irm ${CDN_BASE}/WinNT/Docker/Winx86-mirantis.ps1 | iex${NC}" ;;
        3)  echo -e "  ${GREEN}PowerShell 管理员执行:${NC}"
            echo -e "  ${CYAN}irm ${CDN_BASE}/WinNT/Docker/Winx86-nerdctls.ps1 | iex${NC}" ;;
        10) echo -e "  ${GREEN}PowerShell 管理员执行:${NC}"
            echo -e "  ${CYAN}irm ${CDN_BASE}/WinNT/Active/MAS_AIO.cmd | iex${NC}" ;;
        0)  return 1 ;;
        *)  echo -e "  ${RED}无效选项: $1${NC}" ;;
    esac
    return 0
}

# ============================================================
# 主流程
# ============================================================

run_submenu() {
    local CATEGORY="$1"
    local CHOICE
    while true; do
        case "$CATEGORY" in
            1) sub_deploy ;;
            2) sub_maintain ;;
            3) sub_desktop ;;
            4) sub_bench ;;
        esac
        read CHOICE
        [ -z "$CHOICE" ] && continue
        case "$CATEGORY" in
            1) exec_deploy "$CHOICE" || break ;;
            2) exec_maintain "$CHOICE" || break ;;
            3) exec_desktop "$CHOICE" || break ;;
            4) exec_bench "$CHOICE" || break ;;
        esac
        echo ""
        echo -ne "  ${BOLD}按 Enter 继续，输入 0 返回${NC} > "
        read NEXT
        [ "$NEXT" = "0" ] && break
    done
}

main() {
    while true; do
        case "$OS_TYPE" in
            linux)   main_menu ;;
            windows) windows_menu ;;
            *)
                echo -e "${RED}不支持的系统: ${OS_DETAIL}${NC}"
                echo "项目: https://github.com/PIKACHUIM/CloudScripts"
                exit 1
                ;;
        esac

        read CHOICE
        [ -z "$CHOICE" ] && continue

        case "$OS_TYPE" in
            linux)
                case "$CHOICE" in
                    1|2|3|4) run_submenu "$CHOICE" ;;
                    0) echo -e "${GREEN}再见！${NC}"; exit 0 ;;
                    *) echo -e "  ${RED}无效选项${NC}" ;;
                esac
                ;;
            windows)
                show_windows_cmd "$CHOICE" || { echo -e "${GREEN}再见！${NC}"; exit 0; }
                echo ""; echo -ne "  ${BOLD}按 Enter 继续${NC} > "; read _
                ;;
        esac
    done
}

main "$@"
