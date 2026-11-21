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
                # NodeSource first (bounded download), then npmmirror tarball
                if ! pika_run_remote "https://deb.nodesource.com/setup_lts.x"; then
                    pika_debug "NodeSource 脚本不可用，继续尝试其他方式"
                fi
                pkg_install nodejs || {
                    # Fallback: direct download from the npmmirror CDN
                    pika_warn "NodeSource 安装失败，尝试直接下载..."
                    local node_ver="20.11.0" arch="$PIKA_ARCH_SHORT" node_url
                    node_url="${NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node}/v${node_ver}/node-v${node_ver}-linux-${arch}.tar.xz"
                    if pika_fetch "$node_url" -o /tmp/node.tar.xz --max-time 180; then
                        tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1
                        rm -f /tmp/node.tar.xz
                    fi
                }
                ;;
            dnf|yum)
                if ! pika_run_remote "https://rpm.nodesource.com/setup_lts.x"; then
                    pika_debug "NodeSource 脚本不可用，继续尝试发行版仓库"
                fi
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
        local npm_registry; npm_registry=$(pika_npm_registry)
        npm install -g pm2 --registry="$npm_registry" 2>/dev/null || \
        npm install -g pm2 || \
        { pika_err "PM2 安装失败"; return 1; }
    fi
}

# ---- npm / pip registries (China-friendly by default) ----
pika_npm_registry() { printf '%s' "${NPM_CONFIG_REGISTRY:-https://registry.npmmirror.com}"; }
pika_pip_index() { printf '%s' "${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"; }

# Persist npm/pip mirrors for the current user (no-op when the tool is absent).
pika_npm_pip_mirror_set() {
    local npm_reg pip_index rc=1
    npm_reg="$(pika_npm_registry)"
    pip_index="$(pika_pip_index)"

    if command -v npm >/dev/null 2>&1; then
        if npm config set registry "$npm_reg" 2>/dev/null; then
            pika_info "npm registry: $npm_reg"
            rc=0
        fi
    fi

    local pip_cmd=""
    if command -v pip3 >/dev/null 2>&1; then
        pip_cmd="pip3"
    elif command -v pip >/dev/null 2>&1; then
        pip_cmd="pip"
    fi
    if [ -n "$pip_cmd" ]; then
        if "$pip_cmd" config set global.index-url "$pip_index" 2>/dev/null; then
            pika_info "pip index-url: $pip_index"
            rc=0
        fi
    fi

    [ "$rc" -eq 0 ] || pika_warn "未找到 npm/pip，已跳过"
    return 0
}

# ---- Docker registry mirrors (Docker Hub pulls) ----
PIKA_DOCKER_REGISTRY_MIRRORS=(
    "https://docker.1ms.run"
    "https://docker.xuanyuan.me"
    "https://docker.m.daocloud.io"
)

# Merge registry-mirrors into /etc/docker/daemon.json (backup + JSON-safe merge).
pika_docker_mirror_setup() {
    command -v docker >/dev/null 2>&1 || return 0
    local f="/etc/docker/daemon.json" url body sep="" bak
    mkdir -p /etc/docker 2>/dev/null || true

    if [ -f "$f" ] && grep -q 'registry-mirrors' "$f" 2>/dev/null; then
        pika_debug "Docker 镜像加速已配置，跳过"
        return 0
    fi

    if [ -f "$f" ]; then
        bak="${f}.pika.bak.$(date +%s)"
        cp -f "$f" "$bak" 2>/dev/null || true
        if command -v python3 >/dev/null 2>&1; then
            if ! python3 - "$f" "${PIKA_DOCKER_REGISTRY_MIRRORS[@]}" <<'PY' 2>/dev/null
import json, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
mirrors = data.get("registry-mirrors") or []
for url in sys.argv[2:]:
    if url not in mirrors:
        mirrors.append(url)
data["registry-mirrors"] = mirrors
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY
            then
                pika_warn "无法自动合并 $f（已备份到 $bak），请手动添加 registry-mirrors"
                return 1
            fi
            pika_info "已合并 Docker 镜像加速: $f"
        else
            pika_warn "$f 已存在（已备份到 $bak），请手动添加 registry-mirrors"
            return 1
        fi
    else
        for url in "${PIKA_DOCKER_REGISTRY_MIRRORS[@]}"; do
            body="${body}${sep}    \"${url}\""
            sep=$',\n'
        done
        printf '{\n  "registry-mirrors": [\n%s\n  ]\n}\n' "$body" > "$f"
        pika_info "已写入 Docker 镜像加速: $f"
    fi

    systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
    return 0
}

# Map an upstream registry to a mainland pull-through mirror.
pika_docker_image_mirror() {
    case "$1" in
        ghcr.io/*)         printf 'ghcr.m.daocloud.io/%s' "${1#ghcr.io/}" ;;
        quay.io/*)         printf 'quay.m.daocloud.io/%s' "${1#quay.io/}" ;;
        gcr.io/*)          printf 'gcr.m.daocloud.io/%s' "${1#gcr.io/}" ;;
        registry.k8s.io/*) printf 'k8s.m.daocloud.io/%s' "${1#registry.k8s.io/}" ;;
        docker.io/*)       printf 'docker.m.daocloud.io/%s' "${1#docker.io/}" ;;
        *)                 printf '%s' "$1" ;;
    esac
}

# Pull an image, falling back to a pull-through mirror for ghcr/quay/gcr.
pika_docker_pull() {
    local image="$1" mirror
    command -v docker >/dev/null 2>&1 || return 1

    case "$image" in
        ghcr.io/*|quay.io/*|gcr.io/*|registry.k8s.io/*|docker.io/*)
            if pika_accel_enabled; then
                mirror=$(pika_docker_image_mirror "$image")
                if [ "$mirror" != "$image" ] && docker pull "$mirror" >/dev/null 2>&1; then
                    docker tag "$mirror" "$image" >/dev/null 2>&1 || true
                    pika_info "镜像经加速通道拉取: $image"
                    return 0
                fi
            fi
            ;;
    esac

    docker pull "$image"
}

# ---- Install Docker (official script, Aliyun repo fallback, distro packages) ----
pika_install_docker() {
    if command -v docker >/dev/null 2>&1; then
        pika_docker_mirror_setup >/dev/null 2>&1 || true
        return 0
    fi

    pika_info "安装 Docker..."
    local tmpf rc=1
    tmpf=$(mktemp) || return 1
    if _pika_download_to "https://get.docker.com" "$tmpf" 60; then
        if bash "$tmpf"; then
            rc=0
        elif bash "$tmpf" --mirror Aliyun; then
            pika_info "已通过阿里云镜像源安装 Docker"
            rc=0
        fi
    fi
    rm -f "$tmpf"

    if [ "$rc" -ne 0 ]; then
        pika_warn "官方脚本安装失败，改用发行版软件包..."
        case "$PIKA_PKG_MGR" in
            apt)          pkg_install docker.io && rc=0 ;;
            dnf|yum)      { pkg_install docker-ce || pkg_install docker; } && rc=0 ;;
            apk)          pkg_install docker && rc=0 ;;
            pacman)       pkg_install docker && rc=0 ;;
            zypper)       pkg_install docker && rc=0 ;;
        esac
    fi

    if [ "$rc" -ne 0 ]; then
        pika_err "Docker 安装失败，请手动安装后重试"
        return 1
    fi

    systemctl enable --now docker 2>/dev/null || service docker start 2>/dev/null || true
    pika_docker_mirror_setup >/dev/null 2>&1 || true
    return 0
}

# ---- Switch distro package sources to mainland mirrors (with backups) ----
# Rewrite one APT source file to the TUNA mirror (idempotent).
_pika_rewrite_apt_file() {
    local f="$1"
    case "$PIKA_DISTRO" in
        ubuntu|devuan|kali|deepin|uos)
            sed -i \
                -e 's|https\?://[a-z0-9.-]*archive\.ubuntu\.com/ubuntu|https://mirrors.tuna.tsinghua.edu.cn/ubuntu|g' \
                -e 's|https\?://[a-z0-9.-]*security\.ubuntu\.com/ubuntu|https://mirrors.tuna.tsinghua.edu.cn/ubuntu|g' \
                -e 's|https\?://ports\.ubuntu\.com/ubuntu-ports|https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports|g' \
                "$f" 2>/dev/null || true
            ;;
        *)
            sed -i \
                -e 's|https\?://deb\.debian\.org/debian|https://mirrors.tuna.tsinghua.edu.cn/debian|g' \
                -e 's|https\?://security\.debian\.org/debian-security|https://mirrors.tuna.tsinghua.edu.cn/debian-security|g' \
                -e 's|https\?://[a-z0-9.-]*ftp\.[a-z0-9.-]*debian\.org/debian|https://mirrors.tuna.tsinghua.edu.cn/debian|g' \
                -e 's|https\?://[a-z0-9.-]*ftp\.[a-z0-9.-]*debian\.org/debian-security|https://mirrors.tuna.tsinghua.edu.cn/debian-security|g' \
                "$f" 2>/dev/null || true
            ;;
    esac
}

# Rewrite one APK repositories file to the TUNA mirror (idempotent).
_pika_rewrite_apk_file() {
    local f="$1"
    sed -i 's|https\?://[a-z0-9.-]*dl-cdn\.alpinelinux\.org/alpine|https://mirrors.tuna.tsinghua.edu.cn/alpine|g' "$f"
}

# Rewrite one dnf/yum repo file (Rocky/Alma/CentOS/Fedora) to the TUNA mirror.
_pika_rewrite_repo_file() {
    local f="$1" distro="$2"
    sed -i -e 's|^mirrorlist=|#mirrorlist=|g' -e 's|^metalink=|#metalink=|g' "$f"
    case "$distro" in
        rocky)
            sed -i -E 's~^#[[:space:]]*baseurl=https?://(dl|download)\.rockylinux\.org~baseurl=https://mirrors.tuna.tsinghua.edu.cn/rocky~g' "$f"
            ;;
        almalinux)
            sed -i -E 's~^#[[:space:]]*baseurl=https?://repo\.almalinux\.org/almalinux~baseurl=https://mirrors.tuna.tsinghua.edu.cn/almalinux~g' "$f"
            ;;
        centos)
            sed -i -E \
                -e 's~^#[[:space:]]*baseurl=https?://mirror\.centos\.org/centos~baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos~g' \
                -e 's~^#[[:space:]]*baseurl=https?://mirror\.stream\.centos\.org~baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos-stream~g' \
                "$f"
            ;;
        fedora)
            # Fedora ships a download.example placeholder in the commented baseurl
            sed -i -E 's~^#[[:space:]]*baseurl=https?://download\.example/pub/fedora/linux~baseurl=https://mirrors.tuna.tsinghua.edu.cn/fedora~g' "$f"
            ;;
    esac
}

pika_pkg_mirror_cn() {
    local ts f
    ts=$(date +%Y%m%d%H%M%S)

    case "$PIKA_PKG_MGR" in
        apt)
            local files=()
            for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
                [ -f "$f" ] && files+=("$f")
            done
            [ ${#files[@]} -gt 0 ] || { pika_warn "未找到 APT 源文件"; return 1; }

            for f in "${files[@]}"; do
                cp -f "$f" "${f}.pika.bak.${ts}" 2>/dev/null || true
            done

            for f in "${files[@]}"; do
                _pika_rewrite_apt_file "$f"
            done
            rm -f "$PIKA_PKG_UPDATE_DONE" 2>/dev/null || true
            pkg_update_once || pika_warn "包索引更新失败，请稍后手动执行 apt update"
            ;;
        apk)
            f=/etc/apk/repositories
            [ -f "$f" ] || { pika_warn "未找到 $f"; return 1; }
            cp -f "$f" "${f}.pika.bak.${ts}" 2>/dev/null || true
            _pika_rewrite_apk_file "$f"
            apk update --quiet || pika_warn "包索引更新失败，请稍后手动执行 apk update"
            ;;
        dnf|yum)
            # Rocky/Alma/CentOS/Fedora keep the same path layout on TUNA, so
            # uncommenting the stock baseurl and swapping the host is safe.
            # AlmaLinux already embeds "/almalinux" in the stock path.
            case "$PIKA_DISTRO" in
                rocky|almalinux|centos|fedora) ;;
                *)
                    pika_warn "当前发行版暂不支持自动切换（$PIKA_DISTRO），请参考 https://mirrors.tuna.tsinghua.edu.cn"
                    return 1
                    ;;
            esac
            for f in /etc/yum.repos.d/*.repo; do
                [ -f "$f" ] || continue
                cp -f "$f" "${f}.pika.bak.${ts}" 2>/dev/null || true
                _pika_rewrite_repo_file "$f" "$PIKA_DISTRO"
                if ! grep -q '^[[:space:]]*baseurl=' "$f"; then
                    pika_warn "未找到可用 baseurl，已恢复 $(basename "$f")"
                    cp -f "${f}.pika.bak.${ts}" "$f" 2>/dev/null || true
                fi
            done
            rm -f "$PIKA_PKG_UPDATE_DONE" 2>/dev/null || true
            pkg_update_once || pika_warn "包索引更新失败，请稍后手动执行 dnf makecache"
            ;;
        *)
            pika_warn "不支持的包管理器: $PIKA_PKG_MGR"
            return 1
            ;;
    esac

    pika_info "软件源已切换，原文件备份为 *.pika.bak.${ts}"
    return 0
}

# ---- Mark lib as loaded ----
PIKA_PKG_LOADED=1
