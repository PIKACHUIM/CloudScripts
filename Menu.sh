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

PIKA_VERSION="1.4"
PIKA_BASE="$(cd "$(dirname "$0")" && pwd)"
PIKA_LIB_DIR="${PIKA_BASE}/Linux/Lib"
PIKA_MOD_DIR="${PIKA_BASE}/Linux/Modules"

# ---- CLI argument parsing (must happen before library loading) ----
PIKA_YES=0
PIKA_LANG=""
PIKA_MIRROR=""
PIKA_SVC_BACKEND_MODE=""
PIKA_NO_ACCEL=0
PIKA_DIRECT_CAT=""
PIKA_DIRECT_ITEM=""

# ---- Short fingerprint for --doctor (works before any library is loaded) ----
_pika_fingerprint() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" 2>/dev/null | cut -c1-12
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" 2>/dev/null | cut -c1-12
    else
        printf '?'
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --lang=*)    PIKA_LANG="${1#*=}"; shift ;;
        --mirror=*)  PIKA_MIRROR="${1#*=}"; shift ;;
        --backend=*) PIKA_SVC_BACKEND_MODE="${1#*=}"; shift ;;
        --no-accel)  PIKA_NO_ACCEL=1; shift ;;
        --accel)     PIKA_NO_ACCEL=0; shift ;;
        --yes|-y)    PIKA_YES=1; shift ;;
        --version|-v)
            echo "PIKA SH v${PIKA_VERSION}"
            exit 0
            ;;
        --doctor)
            # 报告“这台机器上实际会跑哪份代码”，用于排查版本漂移。
            echo "PIKA SH v${PIKA_VERSION}"
            echo "entry: ${PIKA_BASE}/Menu.sh"
            for _f in Menu.sh Linux/Lib/00-core.sh Linux/Lib/40-ui.sh Linux/Lib/50-i18n.sh \
                      Linux/I18n/zh_CN.sh Linux/Modules/reverseproxy.sh \
                      Linux/Modules/caddy.sh Linux/Modules/nginx.sh; do
                if [ -f "${PIKA_BASE}/${_f}" ]; then
                    printf '  %-34s %s\n' "$_f" "$(_pika_fingerprint "${PIKA_BASE}/${_f}")"
                else
                    printf '  %-34s %s\n' "$_f" "(not on disk - fetched on demand)"
                fi
            done
            _cache="${PIKA_CACHE_DIR:-/var/cache/pika-sh}/modules"
            if [ -d "$_cache" ]; then
                echo "cache: $_cache"
                for _f in "$_cache"/*.sh; do
                    [ -f "$_f" ] || continue
                    printf '  %-34s %s\n' "${_f##*/}" "$(_pika_fingerprint "$_f")"
                done
            fi
            exit 0
            ;;
        --help|-h)
            echo "PIKA SH v${PIKA_VERSION}"
            echo "Usage: bash Menu.sh [category] [item] [options]"
            echo ""
            echo "Options:"
            echo "  --lang=zh_CN|en_US     Set language"
            echo "  --mirror=URL           Force mirror channel"
            echo "  --backend=pm2|systemd  Force service backend"
            echo "  --no-accel             Disable GitHub acceleration (direct only)"
            echo "  --yes, -y              Skip all confirmations"
            echo "  --help, -h             Show this help"
            echo ""
            echo "Direct access: bash Menu.sh 1 1    (Deploy > Mirror)"
            echo "              bash Menu.sh 3       (Desktop menu)"
            echo "              bash Menu.sh reverseproxy   (Caddy / Nginx gateway)"
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
        deploy|maintain|desktop|bench|software|proxy|reverseproxy|caddy|system|install_local)
            if [ -z "$PIKA_DIRECT_CAT" ]; then
                PIKA_DIRECT_CAT="$1"
            fi
            shift
            ;;
        *) shift ;;
    esac
done

# Export for sub-shells
export PIKA_YES PIKA_LANG PIKA_MIRROR PIKA_SVC_BACKEND_MODE PIKA_NO_ACCEL

# ---- Site endpoints (mainland edge first, then overseas) ----
# Two independent deployments serve the same tree:
#   pikash.pika.net.cn  -> Tencent EdgeOne Pages (mainland reachable)
#   pikash.opkg.cn      -> GitHub Pages (overseas)
# Every request carries hard timeouts so an unreachable host can never stall
# the menu, and the reachable one is picked automatically.
PIKA_SITE_CN="https://pikash.pika.net.cn"
PIKA_SITE_INTL="https://pikash.opkg.cn"
PIKA_SITE_RAW="https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
PIKA_SITE_BASE=""
: "${PIKA_CACHE_DIR:=/var/cache/pika-sh}"

# Last-resort GitHub accelerators, used only when both PIKA SH sites and the
# raw GitHub endpoint are unreachable (common on mainland VPS).
PIKA_GH_FALLBACK_PREFIXES=(
    "https://ghfast.top/"
    "https://gh-proxy.com/"
)

# Download one URL with hard timeouts (curl preferred, wget fallback).
_pika_bootstrap_get() {
    local url="$1" out="$2" max_time="${3:-15}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 2 --max-time "$max_time" -o "$out" "$url" 2>/dev/null && return 0
        return 1
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -T "$max_time" -t 1 -O "$out" "$url" 2>/dev/null && return 0
    fi
    return 1
}

# Last resort: our raw GitHub tree through an accelerator prefix.
_pika_bootstrap_get_accel() {
    local path="$1" out="$2" prefix
    [ "${PIKA_NO_ACCEL:-0}" = "1" ] && return 1
    for prefix in "${PIKA_GH_FALLBACK_PREFIXES[@]}"; do
        if _pika_bootstrap_get "${prefix}${PIKA_SITE_RAW}/${path}" "$out"; then
            return 0
        fi
    done
    return 1
}

# Health probe: HTTP 200 + magic string, so a hijacked/parked host is rejected.
# A network-level failure returns immediately; the alternate path is only
# tried when the host answered but the dotfile was not served.
_pika_site_ok() {
    local base="$1" path tmp code answered=0
    for path in ".pika-healthz" "pika-healthz.txt"; do
        tmp=$(mktemp 2>/dev/null) || return 1
        code=$(curl -sSL -o "$tmp" -w '%{http_code}' \
               --connect-timeout 2 --max-time 4 "${base}/${path}" 2>/dev/null) || code=""
        if [ -n "$code" ]; then
            answered=1
        fi
        if [ "$code" = "200" ] && grep -q 'PIKA_SH_OK' "$tmp" 2>/dev/null; then
            rm -f "$tmp"
            return 0
        fi
        rm -f "$tmp"
        [ "$answered" = "0" ] && return 1
    done
    return 1
}

# Probe both sites in parallel; the first healthy answer wins (~1 RTT).
_pika_pick_site() {
    local tmpd w winner="" p1="" p2=""
    tmpd=$(mktemp -d 2>/dev/null) || { printf '%s' ""; return 0; }

    ( _pika_site_ok "$PIKA_SITE_CN" && printf '%s\n' "$PIKA_SITE_CN" > "$tmpd/cn" ) &
    p1=$!
    ( _pika_site_ok "$PIKA_SITE_INTL" && printf '%s\n' "$PIKA_SITE_INTL" > "$tmpd/intl" ) &
    p2=$!

    w=0
    while [ "$w" -lt 20 ]; do
        if [ -s "$tmpd/cn" ]; then
            winner=$(sed -n '1p' "$tmpd/cn")
            break
        fi
        if [ -s "$tmpd/intl" ]; then
            winner=$(sed -n '1p' "$tmpd/intl")
            break
        fi
        sleep 0.2
        w=$((w + 1))
    done

    kill "$p1" "$p2" 2>/dev/null || true
    wait "$p1" "$p2" 2>/dev/null || true
    rm -rf "$tmpd"
    printf '%s' "$winner"
}

# Resolve the base URL once: explicit override > cached choice > live probe.
_pika_resolve_site() {
    local cache="${PIKA_CACHE_DIR}/site.conf" base ts now

    if [ -n "${PIKA_SITE_BASE:-}" ]; then
        printf '%s' "$PIKA_SITE_BASE"
        return 0
    fi
    if [ -n "${PIKA_MIRROR:-}" ]; then
        printf '%s' "${PIKA_MIRROR%/}"
        return 0
    fi

    if [ -f "$cache" ]; then
        base=$(sed -n '1p' "$cache" 2>/dev/null || true)
        ts=$(sed -n '2p' "$cache" 2>/dev/null || echo 0)
        case "$ts" in ''|*[!0-9]*) ts=0 ;; esac
        now=$(date +%s)
        if [ -n "$base" ] && [ $((now - ts)) -lt 86400 ] && _pika_site_ok "$base"; then
            printf '%s' "$base"
            return 0
        fi
    fi

    printf '%s\n' "[*] 探测下载线路 / probing mirrors..." >&2
    base=$(_pika_pick_site)
    if [ -z "$base" ]; then
        base="$PIKA_SITE_RAW"
    else
        mkdir -p "$PIKA_CACHE_DIR" 2>/dev/null || true
        printf '%s\n%s\n' "$base" "$(date +%s)" > "$cache" 2>/dev/null || true
    fi
    printf '%s' "$base"
}

# ---- Bootstrap: load core libraries ----
_bootstrap() {
    : "${PIKA_CACHE_DIR:=/var/cache/pika-sh}"
    export PIKA_CACHE_DIR

    # Ensure basic tools exist (minimal, before full pkg abstraction loads)
    command -v curl >/dev/null 2>&1 || { apt-get update -qq 2>/dev/null && apt-get install -y -qq curl 2>/dev/null; } || true
    command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || { echo "ERROR: curl or wget required." >&2; exit 1; }

    # Pick the closest reachable mirror once, reuse it for every library
    local base; base=$(_pika_resolve_site)
    PIKA_SITE_BASE="$base"
    export PIKA_SITE_BASE

    # Load core library (local first, then fetch from the chosen site)
    local lib_core="${PIKA_LIB_DIR}/00-core.sh"
    if [ ! -f "$lib_core" ]; then
        local tmp_core; tmp_core=$(mktemp)
        local loaded_core=0
        if _pika_bootstrap_get "${PIKA_SITE_BASE}/Linux/Lib/00-core.sh" "$tmp_core"; then
            loaded_core=1
        elif [ "$PIKA_SITE_BASE" != "$PIKA_SITE_RAW" ] && \
             _pika_bootstrap_get "${PIKA_SITE_RAW}/Linux/Lib/00-core.sh" "$tmp_core"; then
            loaded_core=1
        elif _pika_bootstrap_get_accel "Linux/Lib/00-core.sh" "$tmp_core"; then
            loaded_core=1
        fi
        if [ "$loaded_core" -ne 1 ]; then
            echo "ERROR: 无法连接任何下载线路 / no reachable mirror." >&2
            echo "       请检查网络，或用 --mirror=URL 指定可用镜像。" >&2
            rm -f "$tmp_core"
            exit 1
        fi
        if ! bash -n "$tmp_core" 2>/dev/null; then
            echo "ERROR: core library is corrupted." >&2
            rm -f "$tmp_core"
            exit 1
        fi
        . "$tmp_core"
        rm -f "$tmp_core"
    else
        . "$lib_core"
    fi

    # Auto-clean stale module cache (older than 24h)
    local cache_dir="${PIKA_CACHE_DIR}/modules"
    if [ -d "$cache_dir" ]; then
        find "$cache_dir" -name '*.sh' -mtime +0 -delete 2>/dev/null || \
            find "$cache_dir" -name '*.sh' -mmin +1440 -delete 2>/dev/null || true
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
        return 0
    fi

    local tmpf; tmpf=$(mktemp)
    local ok=0
    if _pika_bootstrap_get "${PIKA_SITE_BASE}/Linux/Lib/${f}" "$tmpf" 10; then
        ok=1
    elif [ "$PIKA_SITE_BASE" != "$PIKA_SITE_RAW" ] && \
         _pika_bootstrap_get "${PIKA_SITE_RAW}/Linux/Lib/${f}" "$tmpf" 10; then
        ok=1
    elif _pika_bootstrap_get_accel "Linux/Lib/${f}" "$tmpf"; then
        ok=1
    fi
    if [ "$ok" -ne 1 ]; then
        pika_warn "Cannot load: $f"
        rm -f "$tmpf"
        return 1
    fi
    if ! bash -n "$tmpf" 2>/dev/null; then
        pika_warn "Invalid library: $f"
        rm -f "$tmpf"
        return 1
    fi
    . "$tmpf"
    rm -f "$tmpf"
}

# ---- Module loader (lazy, caches to /var/cache/pika-sh/modules) ----
# A module is only accepted when every i18n key it references resolves against the
# language pack that is already loaded. A mirror that is half-way through a release
# (new pack uploaded, old module still cached) would otherwise render raw keys such
# as "deploy.frps.desc", so such a copy is skipped in favour of the next source.
_pika_module_missing_keys() {
    local f="$1" k v out=""
    local keys
    keys=$(
        { grep -oE '"[a-z0-9_]+\|[A-Za-z0-9_.]+\|[A-Za-z0-9_.]+\|' "$f" 2>/dev/null \
              | tr '|' '\n' | grep -E '^[a-z][A-Za-z0-9_]*\.[A-Za-z0-9_.]+$'
          grep -oE "\bt ['\"][A-Za-z0-9_.]+['\"]" "$f" 2>/dev/null \
              | sed -E "s/^t ['\"]//; s/['\"]\$//"
        } | sort -u
    )
    while IFS= read -r k; do
        [ -n "$k" ] || continue
        v="T_${k//./_}"
        [ -n "${!v:-}" ] || out="${out}${k} "
    done <<< "$keys"
    printf '%s' "$out"
}

_pika_get() {  # url outfile
    curl -fsSL --connect-timeout 3 --max-time 25 "$1" -o "$2" 2>/dev/null || \
        wget -q -T 25 -t 1 -O "$2" "$1" 2>/dev/null
}

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

    local cached="${cache_dir}/${mod}"
    local tmpf="${cached}.tmp"
    local keep="${cached}.keep"
    rm -f "$tmpf" "$keep" "$cached"

    # Every source that can serve this module, in preference order.
    local -a sources=()
    [ -n "${PIKA_SITE_BASE:-}" ] && sources+=("$PIKA_SITE_BASE")
    [ -n "${PIKA_SITE_CN:-}" ] && [ "$PIKA_SITE_CN" != "${PIKA_SITE_BASE:-}" ] && sources+=("$PIKA_SITE_CN")
    [ -n "${PIKA_SITE_INTL:-}" ] && [ "$PIKA_SITE_INTL" != "${PIKA_SITE_BASE:-}" ] && sources+=("$PIKA_SITE_INTL")
    [ -n "${PIKA_SITE_RAW:-}" ] && sources+=("$PIKA_SITE_RAW")
    if [ "${PIKA_NO_ACCEL:-0}" != "1" ]; then
        local gh_prefix
        for gh_prefix in "${PIKA_GH_FALLBACK_PREFIXES[@]:-}"; do
            [ -n "$gh_prefix" ] && sources+=("${gh_prefix}${PIKA_SITE_RAW}")
        done
    fi

    local src missing best=""
    for src in "${sources[@]}"; do
        if ! _pika_get "${src}/Linux/Modules/${mod}" "$tmpf"; then
            rm -f "$tmpf"
            continue
        fi
        if ! bash -n "$tmpf" 2>/dev/null; then
            pika_debug "module ${mod}: syntax error from ${src}, skipping"
            rm -f "$tmpf"
            continue
        fi
        missing=$(_pika_module_missing_keys "$tmpf")
        if [ -z "$missing" ]; then
            mv -f "$tmpf" "$cached"
            . "$cached"
            return
        fi
        pika_debug "module ${mod}: ${src} is out of sync (missing: ${missing})"
        if [ -z "$best" ]; then
            mv -f "$tmpf" "$keep"
            best="$keep"
        else
            rm -f "$tmpf"
        fi
    done

    # Nothing agreed with the language pack: use the first parsable copy so the
    # menu still works, and say why the labels look odd.
    if [ -n "$best" ]; then
        pika_warn "$(t 'common.mirror_stale')"
        PIKA_KEEP_SCREEN=1
        mv -f "$best" "$cached"
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
    "reverseproxy|menu.reverseproxy|menu.reverseproxy.desc|menu_reverseproxy"
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

menu_reverseproxy() {
    _load_module "reverseproxy.sh" || return
    do_rp_enter
}

menu_system() {
    _load_module "system.sh" || return
    _menu_loop "system" "SystemMENU" "menu.system"
}

menu_install_local() {
    local dest="/usr/local/bin/pikash"

    pika_info "$(t 'menu.install_local.fetching')"
    # Install a thin self-updating launcher instead of a frozen copy.
    # It always fetches the latest Menu.sh from CDN before running, so the
    # entry script and every cached module stay fresh — no more stale cache.
    cat > "$dest" <<'PIKA_LAUNCHER'
#!/usr/bin/env bash
# pikash launcher — always runs the latest Menu.sh
set -e
PIKA_RAW="https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Menu.sh"
CACHE_DIR="${PIKA_CACHE_DIR:-/var/cache/pika-sh}"
CACHED="$CACHE_DIR/Menu.sh"
TMP="$(mktemp 2>/dev/null || echo "/tmp/pikash-$$.sh")"
fetch_ok=0
# Mainland edge first, then the overseas mirror; both bounded by timeouts.
for base in "https://pikash.pika.net.cn" "https://pikash.opkg.cn"; do
    if curl -fsSL --connect-timeout 3 --max-time 25 "$base/Menu.sh" -o "$TMP" 2>/dev/null || \
       wget -q -T 25 -t 1 -O "$TMP" "$base/Menu.sh" 2>/dev/null; then
        if bash -n "$TMP" 2>/dev/null; then fetch_ok=1; break; fi
    fi
done
if [ "$fetch_ok" -ne 1 ]; then
    if curl -fsSL --connect-timeout 3 --max-time 25 "$PIKA_RAW" -o "$TMP" 2>/dev/null || \
       wget -q -T 25 -t 1 -O "$TMP" "$PIKA_RAW" 2>/dev/null; then
        if bash -n "$TMP" 2>/dev/null; then fetch_ok=1; fi
    fi
fi
# GitHub blocked: try accelerator prefixes
if [ "$fetch_ok" -ne 1 ] && [ "${PIKA_NO_ACCEL:-0}" != "1" ]; then
    for _prefix in "https://ghfast.top/" "https://gh-proxy.com/"; do
        if curl -fsSL --connect-timeout 3 --max-time 25 "${_prefix}${PIKA_RAW}" -o "$TMP" 2>/dev/null; then
            if bash -n "$TMP" 2>/dev/null; then fetch_ok=1; break; fi
        fi
    done
fi
if [ "$fetch_ok" -eq 1 ]; then
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    cp -f "$TMP" "$CACHED" 2>/dev/null || true
    exec bash "$TMP" "$@"
fi
rm -f "$TMP"
if [ -f "$CACHED" ]; then
    exec bash "$CACHED" "$@"
fi
echo "pikash: failed to fetch latest script and no offline cache available." >&2
exit 1
PIKA_LAUNCHER

    chmod +x "$dest"

    if [ -x "$dest" ]; then
        pika_info "$(t 'menu.install_local.success') $dest"
        echo "  $(t 'menu.install_local.usage'): pikash"
    else
        pika_err "$(t 'menu.install_local.failed')"
    fi
}

# ---- Generic menu loop ----
# $3 is an i18n key, unless $4 = 1, in which case it is the title itself.
_menu_loop() {
    local arr_name="$2" title_key="$3" literal="${4:-0}"
    local -n items="$arr_name"
    local title
    if [ "$literal" = "1" ]; then
        title="$title_key"
    else
        title="$(t "$title_key")"
    fi

    while true; do
        # Keep the previous output (logs, errors) on screen when asked to.
        if [ "${PIKA_KEEP_SCREEN:-0}" = "1" ]; then
            printf '\n'
        else
            ui_clear
            ui_header
        fi
        PIKA_KEEP_SCREEN=0
        ui_menu "$title" "$arr_name" "$(t 'menu.back')"
        read -r sel || return 0

        # Back: 0, b/back, q/quit
        if ui_is_back "$sel"; then return 0; fi

        local rc=0
        ui_dispatch "$arr_name" "$sel" || rc=$?
        if [ "$rc" -eq 2 ]; then return 0; fi
        if [ "$rc" -ne 0 ]; then
            pika_warn "$(t 'ui.invalid'): $sel"
            sleep 1
            continue
        fi

        # Only pause when the action failed and needs attention.
        if [ "${PIKA_DISPATCH_RC:-0}" -ne 0 ]; then
            PIKA_KEEP_SCREEN=1
            printf '\n  %s ' "$(t 'ui.press_enter')"
            read -r _ || return 0
        fi
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
            "deploy" "maintain" "desktop" "bench" "software" "proxy" "reverseproxy" "system" "install_local"
        )
        local cat_key=""
        case "$PIKA_DIRECT_CAT" in
            [0-9]|[0-9][0-9]) cat_key="${cat_map[$((PIKA_DIRECT_CAT - 1))]}" ;;
            *)                 cat_key="$PIKA_DIRECT_CAT" ;;
        esac
        # Backwards compatible alias from the previous Caddy-only menu
        if [ "$cat_key" = "caddy" ]; then
            cat_key="reverseproxy"
        fi
        if [ -n "$cat_key" ] && declare -F "menu_${cat_key}" >/dev/null 2>&1; then
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
        # Size the columns from MENU_MAIN so no title or description is cut off.
        ui_menu_size "MENU_MAIN" "$(t 'menu.exit')"
        local row_w="$_UI_ROW_W"

        ui_clear
        ui_header
        ui_divider "$((row_w - 2))"
        ui_section "$(t 'menu.main')"
        ui_sysinfo
        echo ""
        ui_divider "$((row_w - 2))"

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
