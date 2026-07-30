#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Package Manager Abstraction
#  Supports: apt, dnf, yum, apk, pacman, zypper
#  Requires: 00-core.sh loaded first
# ============================================================
set -e

PIKA_PKG_UPDATE_DONE="${PIKA_RUN_DIR}/.pika-pkg-updated"

# ---- Detect primary package manager ----
pkg_detect() {
    case "$PIKA_DISTRO" in
        debian|ubuntu|devuan|kali|deepin|uos) echo "apt" ;;
        fedora|rhel|centos|rocky|almalinux|ol|amzn)
            command -v dnf >/dev/null 2>&1 && echo "dnf" || echo "yum" ;;
        opensuse*|sles) echo "zypper" ;;
        arch|manjaro|endeavouros) echo "pacman" ;;
        alpine) echo "apk" ;;
        *)
            # Try to detect by available commands
            command -v apt-get >/dev/null 2>&1 && { echo "apt"; return; }
            command -v dnf >/dev/null 2>&1 && { echo "dnf"; return; }
            command -v yum >/dev/null 2>&1 && { echo "yum"; return; }
            command -v zypper >/dev/null 2>&1 && { echo "zypper"; return; }
            command -v pacman >/dev/null 2>&1 && { echo "pacman"; return; }
            command -v apk >/dev/null 2>&1 && { echo "apk"; return; }
            echo "unknown"
            ;;
    esac
}
PIKA_PKG_MGR=$(pkg_detect)

# ---- Cross-distro package name mapping ----
# Maps common package names to distro-specific alternatives
declare -A PKG_MAP
PKG_MAP[curl]="curl"
PKG_MAP[wget]="wget"
PKG_MAP[tar]="tar"
PKG_MAP[unzip]="unzip"
PKG_MAP[jq]="jq"
PKG_MAP[git]="git"
PKG_MAP[openssl]="openssl"
PKG_MAP[ca-certificates]="ca-certificates"
PKG_MAP[python3]="python3"
PKG_MAP[pip3]="python3-pip"
PKG_MAP[nodejs]="nodejs"
PKG_MAP[npm]="npm"
PKG_MAP[net-tools]="net-tools"
PKG_MAP[wget]="wget"
PKG_MAP[socat]="socat"
PKG_MAP[sudo]="sudo"
PKG_MAP[vim]="vim"
PKG_MAP[nano]="nano"

# Override for specific distros
_pkg_map_init() {
    case "$PIKA_PKG_MGR" in
        apk)
            PKG_MAP[python3-pip]="py3-pip"
            PKG_MAP[net-tools]="iproute2"
            PKG_MAP[ca-certificates]="ca-certificates"
            PKG_MAP[openssl]="openssl"
            PKG_MAP[curl]="curl"
            ;;
        pacman)
            PKG_MAP[python3-pip]="python-pip"
            PKG_MAP[net-tools]="iproute2"
            ;;
        dnf|yum)
            PKG_MAP[ca-certificates]="ca-certificates"
            ;;
    esac
}
_pkg_map_init

# Resolve generic pkg name to distro-specific
pkg_map() {
    local name="$1"
    echo "${PKG_MAP[$name]:-$name}"
}

# ---- Update once per session ----
pkg_update_once() {
    [ -f "$PIKA_PKG_UPDATE_DONE" ] && return 0

    pika_info "更新包索引..."
    case "$PIKA_PKG_MGR" in
        apt) apt-get update -y -qq ;;
        dnf) dnf makecache -y -q 2>/dev/null || true ;;
        yum) yum makecache -y -q 2>/dev/null || true ;;
        apk) apk update --quiet ;;
        pacman) pacman -Sy --noconfirm --quiet ;;
        zypper) zypper refresh -q 2>/dev/null || true ;;
    esac
    touch "$PIKA_PKG_UPDATE_DONE"
}

# ---- Install packages (explicit failure, no silent swallowing) ----
pkg_install() {
    [ $# -eq 0 ] && return 0
    pkg_update_once

    # Map package names to distro-specific
    local pkgs=() mapped
    for p in "$@"; do
        mapped=$(pkg_map "$p")
        pkgs+=("$mapped")
    done

    pika_info "安装: ${pkgs[*]}"

    case "$PIKA_PKG_MGR" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}" || {
                pika_err "APT 安装失败，请尝试: sudo apt update && sudo apt install ${pkgs[*]}"
                return 1
            }
            ;;
        dnf)
            dnf install -y "${pkgs[@]}" || {
                pika_err "DNF 安装失败，请尝试: sudo dnf install ${pkgs[*]}"
                return 1
            }
            ;;
        yum)
            yum install -y "${pkgs[@]}" || {
                pika_err "YUM 安装失败，请尝试: sudo yum install ${pkgs[*]}"
                return 1
            }
            ;;
        apk)
            apk add --no-cache "${pkgs[@]}" || {
                pika_err "APK 安装失败，请尝试: apk add ${pkgs[*]}"
                return 1
            }
            ;;
        pacman)
            pacman -S --noconfirm "${pkgs[@]}" || {
                pika_err "Pacman 安装失败，请尝试: pacman -S ${pkgs[*]}"
                return 1
            }
            ;;
        zypper)
            zypper install -y "${pkgs[@]}" || {
                pika_err "Zypper 安装失败，请尝试: zypper install ${pkgs[*]}"
                return 1
            }
            ;;
        *)
            pika_err "未知包管理器，无法安装: ${pkgs[*]}"
            return 1
            ;;
    esac

    return 0
}

# ---- Ensure a command is available (install if missing) ----
ensure_cmd() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 && continue
        # Map command to package name
        local pkg="$cmd"
        case "$cmd" in
            curl) pkg="curl" ;;
            wget) pkg="wget" ;;
            jq)   pkg="jq" ;;
            tar)  pkg="tar" ;;
            unzip) pkg="unzip" ;;
            git)  pkg="git" ;;
            python3) pkg="python3" ;;
            pip3|pip) pkg="python3-pip" ;;
            node) pkg="nodejs" ;;
            npm)  pkg="npm" ;;
            openssl) pkg="openssl" ;;
            socat) pkg="socat" ;;
            *) continue ;;  # Can't map, skip
        esac
        missing+=("$pkg")
    done

    if [ ${#missing[@]} -gt 0 ]; then
        pika_info "安装缺失工具: ${missing[*]}"
        pkg_install "${missing[@]}" || {
            pika_err "无法安装必要工具: ${missing[*]}"
            return 1
        }
    fi
    return 0
}

# ---- Bootstrap minimal dependencies on first run ----
bootstrap_deps() {
    # Absolute minimum for any script to work
    case "$PIKA_PKG_MGR" in
        apt)
            command -v curl >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq curl ca-certificates; }
            command -v wget >/dev/null 2>&1 || apt-get install -y -qq wget 2>/dev/null || true
            ;;
        apk)
            command -v curl >/dev/null 2>&1 || apk add --no-cache curl ca-certificates
            command -v wget >/dev/null 2>&1 || apk add --no-cache wget 2>/dev/null || true
            ;;
        *)
            # Minimal: just ensure curl works; other managers usually have curl pre-installed
            command -v curl >/dev/null 2>&1 || pkg_install curl ca-certificates 2>/dev/null || true
            ;;
    esac
}

# ---- Ensure Node.js + PM2 (with npmmirror acceleration) ----
ensure_node_pm2() {
    # Node.js
    if ! command -v node >/dev/null 2>&1; then
        pika_info "安装 Node.js LTS..."
        case "$PIKA_PKG_MGR" in
            apt)
                # Use NodeSource with China mirror awareness
                local node_mirror="${NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node}"
                curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - 2>/dev/null || true
                pkg_install nodejs || {
                    # Fallback: direct download
                    pika_warn "NodeSource 安装失败，尝试直接下载..."
                    local node_ver="20.11.0"; local arch="$PIKA_ARCH_SHORT"
                    curl -fsSL "${node_mirror}/v${node_ver}/node-v${node_ver}-linux-${arch}.tar.xz" \
                        -o /tmp/node.tar.xz && \
                        tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 && \
                        rm -f /tmp/node.tar.xz
                }
                ;;
            dnf|yum)
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash - 2>/dev/null || true
                pkg_install nodejs
                ;;
            apk) pkg_install nodejs npm ;;
            pacman) pkg_install nodejs npm ;;
            *) pkg_install nodejs npm 2>/dev/null || pika_err "请手动安装 Node.js" ;;
        esac
    fi

    # PM2
    if ! command -v pm2 >/dev/null 2>&1; then
        pika_info "安装 PM2..."
        local npm_registry="${NPM_CONFIG_REGISTRY:-https://registry.npmmirror.com}"
        npm install -g pm2 --registry="$npm_registry" 2>/dev/null || \
        npm install -g pm2 || \
        { pika_err "PM2 安装失败"; return 1; }
    fi
}

# ---- Mark lib as loaded ----
PIKA_PKG_LOADED=1
