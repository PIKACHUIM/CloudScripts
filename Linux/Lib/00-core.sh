#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Core Library
#  Logging, config, error handling, system detection
#  Source after setting PIKA_LIB_DIR
# ============================================================
set -e

# ---- Color palette (real ESC chars, no echo -e needed) ----
PIKA_RED=$(printf '\033[0;31m');    PIKA_GREEN=$(printf '\033[0;32m')
PIKA_YELLOW=$(printf '\033[1;33m'); PIKA_BLUE=$(printf '\033[0;34m')
PIKA_CYAN=$(printf '\033[0;36m');   PIKA_MAGENTA=$(printf '\033[0;35m')
PIKA_BOLD=$(printf '\033[1m');      PIKA_NC=$(printf '\033[0m')

# ---- Config paths ----
PIKA_CONFIG_DIR="/etc/pika-sh"
PIKA_CACHE_DIR="/var/cache/pika-sh"
PIKA_RUN_DIR="/run/pika-sh"

# ---- Ensure directories exist ----
mkdir -p "$PIKA_CONFIG_DIR" "$PIKA_CACHE_DIR" "$PIKA_RUN_DIR" 2>/dev/null || true

# ============================================================
#  Logging (prints to stderr so stdout stays clean for pipelines)
# ============================================================
pika_info()  { printf '%b\n' "${PIKA_GREEN}[INFO]${PIKA_NC}  $*" >&2; }
pika_warn()  { printf '%b\n' "${PIKA_YELLOW}[WARN]${PIKA_NC}  $*" >&2; }
pika_err()   { printf '%b\n' "${PIKA_RED}[ERROR]${PIKA_NC} $*" >&2; }
pika_debug() { [ "${PIKA_DEBUG:-0}" = "1" ] && printf '%b\n' "${PIKA_MAGENTA}[DEBUG]${PIKA_NC} $*" >&2 || true; }

# ---- Exit with error message (always visible, prints to stderr) ----
pika_die() {
    pika_err "$@"
    exit 1
}

# ============================================================
#  Config read/write (simple KEY=VALUE, one per line)
# ============================================================
pika_config_get() {
    local key="$1" file="${2:-${PIKA_CONFIG_DIR}/config}"
    [ -f "$file" ] && grep -m1 "^${key}=" "$file" 2>/dev/null | cut -d= -f2- || true
}

pika_config_set() {
    local key="$1" val="$2" file="${3:-${PIKA_CONFIG_DIR}/config}"
    if [ -f "$file" ] && grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$file"
    else
        echo "${key}=${val}" >> "$file"
    fi
}

# ============================================================
#  System detection
# ============================================================
pika_detect_os() {
    case "$(uname -s)" in
        Linux)  echo "linux" ;;
        Darwin) echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)      echo "unknown" ;;
    esac
}

pika_detect_distro() {
    . /etc/os-release 2>/dev/null && echo "${ID:-unknown}" || echo "unknown"
}

pika_detect_distro_ver() {
    . /etc/os-release 2>/dev/null && echo "${VERSION_ID:-unknown}" || echo "unknown"
}

# Is this a container/LXC/WSL environment?
pika_is_container() {
    # systemd-detect-virt is the most reliable
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt; virt=$(systemd-detect-virt 2>/dev/null || true)
        [ -n "$virt" ] && [ "$virt" != "none" ] && return 0
    fi

    # Fallback checks
    [ -f /.dockerenv ] && return 0
    [ -f /run/.containerenv ] && return 0
    grep -qE 'docker|lxc|container' /proc/1/cgroup 2>/dev/null && return 0
    grep -qi microsoft /proc/version 2>/dev/null && return 0  # WSL

    return 1
}

# Is systemd available?
pika_has_systemd() {
    [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1
}

# Export common vars after detection
PIKA_OS_TYPE=$(pika_detect_os)
PIKA_DISTRO=$(pika_detect_distro)
PIKA_DISTRO_VER=$(pika_detect_distro_ver)
PIKA_ARCH=$(uname -m)

# Convert arch to short names
pika_arch_short() {
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "armv7" ;;
        armv8l)  echo "arm64" ;;
        *)       uname -m ;;
    esac
}
PIKA_ARCH_SHORT=$(pika_arch_short)

# ============================================================
#  Idempotent write helpers
# ============================================================

# Append line to file only if not already present
pika_file_append_unique() {
    local line="$1" file="$2"
    [ ! -f "$file" ] && { echo "$line" > "$file"; return; }
    grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Write a sysctl drop-in file (overwrite mode, for idempotent kernel tuning)
# Usage: pika_sysctl_dropin 99-pika-bbr "net.core.default_qdisc=fq" "net.ipv4.tcp_congestion_control=bbr"
pika_sysctl_dropin() {
    local name="$1"; shift
    local f="/etc/sysctl.d/${name}.conf"
    printf '%s\n' "$@" > "$f"
    sysctl -p "$f" >/dev/null 2>&1 || true
}

# Add fstab entry if not already present (match by mountpoint)
# Usage: pika_fstab_add "tmpfs /mnt/ramdisk tmpfs defaults,size=512M 0 0"
pika_fstab_add() {
    local entry="$1"
    local mp; mp=$(echo "$entry" | awk '{print $2}')
    if ! grep -qE "[[:space:]]${mp}[[:space:]]" /etc/fstab 2>/dev/null; then
        echo "$entry" >> /etc/fstab
    fi
}

# ============================================================
#  Danger confirmation
# ============================================================
pika_confirm() {
    local prompt="${1:-确认执行?}"
    local default="${2:-N}"
    local yn

    if [ "${PIKA_YES:-0}" = "1" ]; then
        return 0
    fi

    read -r -p "${prompt} (y/N): " yn
    case "${yn:-$default}" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================
#  Random password generator (no echo, secure)
# ============================================================
pika_rand_pass() {
    local len="${1:-16}"
    LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?' < /dev/urandom 2>/dev/null | head -c "$len" || \
    openssl rand -base64 "$((len * 2))" 2>/dev/null | tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' | head -c "$len" || \
    date +%s | sha256sum | head -c "$len"
}

# ============================================================
#  Self-check on first load
# ============================================================

# Check if running as root
pika_check_root() {
    [ "$(id -u)" -eq 0 ] || pika_die "此脚本必须以 root 权限运行 (use sudo)"
}

# Check OS support
pika_check_os() {
    case "$PIKA_OS_TYPE" in
        linux)   return 0 ;;
        macos)   pika_die "macOS 不在支持范围内，请使用 Linux 服务器" ;;
        windows) pika_warn "当前在 Windows Git Bash 环境，部分功能可能不可用" ;;
        *)       pika_die "不支持的操作系统: $(uname -s)" ;;
    esac
}

# ---- Mark lib as loaded ----
PIKA_CORE_LOADED=1
