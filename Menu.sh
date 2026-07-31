#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Server Script Toolbox
#  Lightweight bootstrap (~200 lines). Loads core libs,
#  renders data-driven menus, dispatches to modules.
#
#  Usage:
#    bash <(curl -sL https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh)
#    bash Menu.sh [category] [item] [--lang=en_US] [--mirror=URL] [--backend=pm2|systemd] [--yes] [--help]
# ============================================================
set -e

# ---- Require bash 4.3+ (nameref via local -n is essential for menu system) ----
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash 4.3+. Please run: bash Menu.sh" >&2
    exit 1
fi
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ] || { [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -lt 3 ]; }; then
    echo "ERROR: Bash 4.3+ required (current: $BASH_VERSION). Please upgrade bash." >&2
    exit 1
fi

PIKA_VERSION="1.0"
PIKA_BASE="$(cd "$(dirname "$0")" && pwd)"
PIKA_LIB_DIR="${PIKA_BASE}/Linux/Lib"
PIKA_MOD_DIR="${PIKA_BASE}/Linux/Modules"

# ---- CLI argument parsing (must happen before library loading) ----
PIKA_YES=0
PIKA_LANG=""
PIKA_MIRROR=""
PIKA_SVC_BACKEND_MODE=""
PIKA_DIRECT_CAT=""
PIKA_DIRECT_ITEM=""

while [ $# -gt 0 ]; do
    case "$1" in
        --lang=*)    PIKA_LANG="${1#*=}"; shift ;;
        --mirror=*)  PIKA_MIRROR="${1#*=}"; shift ;;
        --backend=*) PIKA_SVC_BACKEND_MODE="${1#*=}"; shift ;;
        --yes|-y)    PIKA_YES=1; shift ;;
        --help|-h)
            echo "PIKA SH v${PIKA_VERSION}"
            echo "Usage: bash Menu.sh [category] [item] [options]"
            echo ""
            echo "Options:"
            echo "  --lang=zh_CN|en_US     Set language"
            echo "  --mirror=URL           Force mirror channel"
            echo "  --backend=pm2|systemd  Force service backend"
            echo "  --yes, -y              Skip all confirmations"
            echo "  --help, -h             Show this help"
            echo ""
            echo "Direct access: bash Menu.sh 1 1    (Deploy > Mirror)"
            echo "              bash Menu.sh 3       (Desktop menu)"
            exit 0
            ;;
        [1-9]|[1-9][0-9])
            if [ -z "$PIKA_DIRECT_CAT" ]; then
                PIKA_DIRECT_CAT="$1"
            elif [ -z "$PIKA_DIRECT_ITEM" ]; then
                PIKA_DIRECT_ITEM="$1"
            fi
            shift
            ;;
        *) shift ;;
    esac
done

# Export for sub-shells
export PIKA_YES PIKA_LANG PIKA_MIRROR PIKA_SVC_BACKEND_MODE

# ---- Bootstrap: load core libraries ----
_bootstrap() {
    # Ensure basic tools exist (minimal, before full pkg abstraction loads)
    command -v curl >/dev/null 2>&1 || { apt-get update -qq 2>/dev/null && apt-get install -y -qq curl 2>/dev/null; } || true
    command -v mktemp >/dev/null 2>&1 || command -v curl >/dev/null 2>&1 || { echo "ERROR: curl or wget required." >&2; exit 1; }

    # Load core library (local first, then fetch from CDN)
    local lib_core="${PIKA_LIB_DIR}/00-core.sh"
    if [ ! -f "$lib_core" ]; then
        _tmp_core=$(mktemp)
        curl -fsSL "https://pikash.opkg.cn/Linux/Lib/00-core.sh" -o "$_tmp_core" 2>/dev/null || \
            curl -fsSL "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Lib/00-core.sh" -o "$_tmp_core" || \
            { echo "ERROR: Cannot load core library." >&2; rm -f "$_tmp_core"; exit 1; }
        . "$_tmp_core"
        rm -f "$_tmp_core"
    else
        . "$lib_core"
    fi

    # Load remaining libraries
    _load_lib "50-i18n.sh"
    _load_lib "10-net.sh"
    _load_lib "20-pkg.sh"
    _load_lib "30-svc.sh"
    _load_lib "40-ui.sh"
}

_load_lib() {
    local f="$1"
    local local_path="${PIKA_LIB_DIR}/${f}"
    if [ -f "$local_path" ]; then
        . "$local_path"
    else
        local tmpf; tmpf=$(mktemp)
        curl -fsSL "https://pikash.opkg.cn/Linux/Lib/${f}" -o "$tmpf" 2>/dev/null || \
            curl -fsSL "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Lib/${f}" -o "$tmpf" || \
            { pika_warn "Cannot load: $f"; rm -f "$tmpf"; return 1; }
        . "$tmpf"
        rm -f "$tmpf"
    fi
}

# ---- Module loader (lazy, caches to /var/cache/pika-sh/modules) ----
_load_module() {
    local mod="$1"
    local cache_dir="${PIKA_CACHE_DIR}/modules"
    mkdir -p "$cache_dir"

    # Try local file first (development mode)
    local local_mod="${PIKA_MOD_DIR}/${mod}"
    if [ -f "$local_mod" ]; then
        . "$local_mod"
        return
    fi

    # Try fetching from CDN
    local cached="${cache_dir}/${mod}"
    if pika_fetch "Linux/Modules/${mod}" -o "$cached.tmp" 2>/dev/null; then
        mv -f "$cached.tmp" "$cached"
        . "$cached"
        return
    fi

    # Fallback: raw.githubusercontent.com (always up-to-date)
    local raw_url="https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/Modules/${mod}"
    if curl -fsSL "$raw_url" -o "$cached.tmp" 2>/dev/null || wget -qO "$cached.tmp" "$raw_url" 2>/dev/null; then
        mv -f "$cached.tmp" "$cached"
        . "$cached"
        return
    fi

    # Last resort: stale local cache
    if [ -f "$cached" ]; then
        . "$cached"
        return
    fi

    pika_err "$(t 'common.error'): module $mod"
    return 1
}

# ---- Menu data tables (key|title_i18n|desc_i18n|handler) ----
MENU_MAIN=(
    "deploy|menu.deploy|menu.deploy.desc|menu_deploy"
    "maintain|menu.maintain|menu.maintain.desc|menu_maintain"
    "desktop|menu.desktop|menu.desktop.desc|menu_desktop"
    "bench|menu.bench|menu.bench.desc|menu_bench"
    "software|menu.software|menu.software.desc|menu_software"
    "proxy|menu.proxy|menu.proxy.desc|menu_proxy"
    "system|menu.system|menu.system.desc|menu_system"
    "install_local|menu.install_local|menu.install_local.desc|menu_install_local"
)

# ---- Submenu handlers (all follow pattern: load module, render, dispatch) ----
menu_deploy() {
    _load_module "deploy.sh" || return
    _menu_loop "deploy" "DeployMENU" "menu.deploy"
}

menu_maintain() {
    _load_module "maintain.sh" || return
    _menu_loop "maintain" "MaintainMENU" "menu.maintain"
}

menu_desktop() {
    _load_module "desktop.sh" || return
    _menu_loop "desktop" "DesktopMENU" "menu.desktop"
}

menu_bench() {
    _load_module "bench.sh" || return
    _menu_loop "bench" "BenchMENU" "menu.bench"
}

menu_software() {
    _load_module "software.sh" || return
    _menu_loop "software" "SoftwareMENU" "menu.software"
}

menu_proxy() {
    _load_module "proxy.sh" || return
    _menu_loop "proxy" "ProxyMENU" "menu.proxy"
}

menu_system() {
    _load_module "system.sh" || return
    _menu_loop "system" "SystemMENU" "menu.system"
}

menu_install_local() {
    local dest="/usr/local/bin/pikash"
    local url="https://pikash.opkg.cn/Menu.sh"
    local tmp; tmp=$(mktemp 2>/dev/null || echo "/tmp/pikash-$$.sh")

    pika_info "$(t 'menu.install_local.fetching') $url"
    curl -fsSL "$url" -o "$tmp" 2>/dev/null || wget -qO "$tmp" "$url" || {
        pika_err "$(t 'menu.install_local.failed')"
        rm -f "$tmp"
        return 1
    }

    cp "$tmp" "$dest" && chmod +x "$dest"
    rm -f "$tmp"

    if [ -x "$dest" ]; then
        pika_info "$(t 'menu.install_local.success') $dest"
        echo "  $(t 'menu.install_local.usage'): pikash"
    else
        pika_err "$(t 'menu.install_local.failed')"
    fi
}

# ---- Generic menu loop ----
_menu_loop() {
    local arr_name="$2" title_key="$3"
    local -n items="$arr_name"

    while true; do
        ui_clear
        ui_header
        ui_divider
        ui_menu "$(t "$title_key")" "$arr_name" "$(t 'menu.back')"
        read -r sel

        # Back
        case "$sel" in
            0|b|B|back|BACK) return ;;
        esac

        ui_dispatch "$arr_name" "$sel"
        local rc=$?

        if [ $rc -eq 2 ]; then return; fi  # Back
        if [ $rc -ne 0 ]; then
            pika_warn "$(t 'ui.invalid'): $sel"
        fi

        echo ""; printf "  $(t 'ui.press_enter') "; read -r
    done
}

# ---- Main entry ----
main() {
    _bootstrap
    bootstrap_deps

    # OS check
    case "$PIKA_OS_TYPE" in
        linux) ;;
        macos) pika_die "macOS is not supported. Please use a Linux server." ;;
        windows) pika_warn "Running in Windows Git Bash. Some features may not work." ;;
    esac

    # Init mirror
    pika_init_mirror
    pika_debug "Mirror base: $PIKA_MIRROR_BASE"

    # Handle direct access (positional args)
    if [ -n "$PIKA_DIRECT_CAT" ]; then
        local cat_map=(
            "deploy" "maintain" "desktop" "bench" "software" "proxy" "system" "install_local"
        )
        local cat_key="${cat_map[$((PIKA_DIRECT_CAT - 1))]}"
        if [ -n "$cat_key" ]; then
            if [ -n "$PIKA_DIRECT_ITEM" ]; then
                # Direct to specific item
                pika_info "Direct: $cat_key/$PIKA_DIRECT_ITEM"
                "menu_${cat_key}" "$PIKA_DIRECT_ITEM"
            else
                "menu_${cat_key}"
            fi
        fi
        return
    fi

    # Interactive main menu loop
    while true; do
        ui_clear
        ui_header
        ui_divider
        ui_section "$(t 'menu.main')"
        ui_sysinfo
        echo ""
        ui_divider

        local idx=1
        for entry in "${MENU_MAIN[@]}"; do
            local key title_key desc_key handler
            IFS='|' read -r key title_key desc_key handler <<< "$entry"
            ui_item "$idx" "$(t "$title_key")" "$(t "$desc_key")"
            idx=$((idx + 1))
        done
        ui_item "0" "$(t 'menu.exit')" ""
        echo ""
        printf "  $(t 'menu.prompt') "
        read -r sel

        case "$sel" in
            0|q|Q|exit|quit) echo ""; pika_info "Goodbye!"; exit 0 ;;
        esac

        local cidx=1 found=0
        for entry in "${MENU_MAIN[@]}"; do
            if [ "$cidx" = "$sel" ]; then
                local key title_key desc_key handler
                IFS='|' read -r key title_key desc_key handler <<< "$entry"
                $handler
                found=1
                break
            fi
            cidx=$((cidx + 1))
        done

        [ "$found" = "0" ] && { pika_warn "$(t 'ui.invalid'): $sel"; sleep 1; }
    done
}

main "$@"
