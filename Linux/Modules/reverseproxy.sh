#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Reverse Proxy Module (Caddy / Nginx, pick one)
#  Both backends bind ports 80/443, so only one may run at a
#  time.  Switching backends stops and disables the other one.
#  Requires: core libs (00-core, 10-net, 20-pkg, 30-svc, 40-ui, 50-i18n)
# ============================================================
set -e

RP_STATE_FILE="/etc/pika-sh/reverseproxy.backend"
RP_CADDY_DATA="/etc/caddy/pika"
RP_NGINX_DATA="/etc/pika-sh/nginx"

ReverseProxyMENU=(
    "caddy|rp.entry.caddy|rp.entry.caddy.desc|do_rp_caddy"
    "nginx|rp.entry.nginx|rp.entry.nginx.desc|do_rp_nginx"
    "status|rp.status|rp.status.desc|do_rp_status"
)

# ============================================================
#  Backend state
# ============================================================
_rp_label() {
    case "$1" in
        caddy) printf '%s' "Caddy" ;;
        nginx) printf '%s' "Nginx" ;;
        *)     printf '%s' "$1" ;;
    esac
}

_rp_backend_get() {
    local b
    if [ -f "$RP_STATE_FILE" ]; then
        b=$(head -1 "$RP_STATE_FILE" 2>/dev/null || true)
        if [ -n "$b" ]; then
            printf '%s' "$b"
            return 0
        fi
    fi
    if _rp_caddy_running; then
        printf '%s' "caddy"
        return 0
    fi
    if _rp_nginx_running; then
        printf '%s' "nginx"
        return 0
    fi
    printf '%s' "none"
}

_rp_backend_set() {
    mkdir -p "${RP_STATE_FILE%/*}" 2>/dev/null || true
    printf '%s\n' "$1" > "$RP_STATE_FILE"
}

# ============================================================
#  Runtime detection
# ============================================================
_rp_caddy_svc_name() {
    if [ -s "${RP_CADDY_DATA}/service.name" ]; then
        head -1 "${RP_CADDY_DATA}/service.name" 2>/dev/null || printf '%s' "caddy"
        return 0
    fi
    printf '%s' "caddy"
}

_rp_caddy_running() {
    local name
    name=$(_rp_caddy_svc_name)
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet "$name" 2>/dev/null; then
            return 0
        fi
    fi
    if command -v pm2 >/dev/null 2>&1; then
        if pm2 describe "$name" 2>/dev/null | grep -q 'online'; then
            return 0
        fi
    fi
    pgrep -f 'caddy run --config' >/dev/null 2>&1 && return 0
    return 1
}

_rp_nginx_running() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet nginx 2>/dev/null; then
            return 0
        fi
    fi
    pgrep -f 'nginx: master' >/dev/null 2>&1 && return 0
    return 1
}

_rp_is_running() {
    case "$1" in
        caddy) _rp_caddy_running ;;
        nginx) _rp_nginx_running ;;
        *)     return 1 ;;
    esac
}

# ============================================================
#  Start / stop a backend
# ============================================================
_rp_stop_backend() {
    local name bin
    case "$1" in
        caddy)
            name=$(_rp_caddy_svc_name)
            if declare -F svc_stop >/dev/null 2>&1; then
                svc_stop "$name" || true
            fi
            if command -v systemctl >/dev/null 2>&1; then
                systemctl disable "$name" >/dev/null 2>&1 || true
            fi
            if command -v pm2 >/dev/null 2>&1; then
                pm2 save >/dev/null 2>&1 || true
            fi
            ;;
        nginx)
            if command -v systemctl >/dev/null 2>&1 && systemctl cat nginx.service >/dev/null 2>&1; then
                systemctl stop nginx >/dev/null 2>&1 || true
                systemctl disable nginx >/dev/null 2>&1 || true
            else
                bin=$(command -v nginx 2>/dev/null || true)
                if [ -n "$bin" ]; then
                    "$bin" -s stop >/dev/null 2>&1 || true
                fi
                if declare -F svc_stop >/dev/null 2>&1; then
                    svc_stop nginx || true
                fi
            fi
            ;;
    esac
    return 0
}

_rp_start_backend() {
    local name
    case "$1" in
        caddy)
            name=$(_rp_caddy_svc_name)
            if command -v systemctl >/dev/null 2>&1; then
                systemctl enable "$name" >/dev/null 2>&1 || true
            fi
            if declare -F svc_start >/dev/null 2>&1; then
                svc_start "$name" || true
            fi
            ;;
        nginx)
            if command -v systemctl >/dev/null 2>&1 && systemctl cat nginx.service >/dev/null 2>&1; then
                systemctl enable nginx >/dev/null 2>&1 || true
                systemctl start nginx >/dev/null 2>&1 || true
            elif declare -F svc_start >/dev/null 2>&1; then
                svc_start nginx || true
            fi
            ;;
    esac
    return 0
}

# Free ports 80/443 by stopping the other backend, then persist the choice.
_rp_prepare() {
    local target="$1" other
    if [ "$target" = "caddy" ]; then
        other="nginx"
    else
        other="caddy"
    fi

    if _rp_is_running "$other"; then
        pika_warn "$(t 'rp.stop_other' "$(_rp_label "$other")")"
        if ! pika_confirm "$(t 'rp.stop_confirm' "$(_rp_label "$other")")"; then
            pika_info "$(t 'ui.cancelled')"
            return 1
        fi
        _rp_stop_backend "$other"
    fi

    _rp_backend_set "$target"
    return 0
}

_rp_ensure() {
    _rp_prepare "$1" || return 1
    _rp_start_backend "$1"
    return 0
}

# ============================================================
#  Entries
# ============================================================
do_rp_caddy() {
    _load_module "caddy.sh" || return 1
    if [ ! -x "$CADDY_BIN" ]; then
        _rp_prepare caddy || return 0
        pika_info "$(t 'caddy.not_installed')"
        do_caddy_install || return 1
    fi
    _rp_ensure caddy || return 0
    _menu_loop "caddy" "CaddyMENU" "menu.reverseproxy"
    return 0
}

do_rp_nginx() {
    _load_module "nginx.sh" || return 1
    if ! command -v nginx >/dev/null 2>&1 && [ ! -x /usr/sbin/nginx ]; then
        _rp_prepare nginx || return 0
        pika_info "$(t 'nginx.not_installed')"
        do_nginx_install || return 1
    fi
    _rp_ensure nginx || return 0
    _menu_loop "nginx" "NginxMENU" "menu.reverseproxy"
    return 0
}

# ============================================================
#  Status
# ============================================================
_rp_count_meta() {
    local d="$1" n=0 f
    for f in "$d"/*.meta; do
        if [ -f "$f" ]; then
            n=$((n + 1))
        fi
    done
    printf '%s' "$n"
}

_rp_state_word() {
    if "$1"; then
        t 'rp.running'
    else
        t 'rp.stopped'
    fi
}

do_rp_status() {
    local current caddy_installed=0 nginx_installed=0
    current=$(_rp_backend_get)
    if [ -x "/usr/local/bin/caddy" ]; then
        caddy_installed=1
    fi
    if command -v nginx >/dev/null 2>&1 || [ -x /usr/sbin/nginx ]; then
        nginx_installed=1
    fi

    printf '\n'
    if [ "$current" = "none" ]; then
        printf '  %s: %s\n' "$(t 'rp.current')" "$(t 'rp.none')"
    else
        printf '  %s: %s\n' "$(t 'rp.current')" "$(_rp_label "$current")"
    fi
    printf '\n'

    if [ "$caddy_installed" = "1" ]; then
        printf '  Caddy  %s  %s  %s: %s\n' \
            "$(t 'rp.installed')" "$(_rp_state_word _rp_caddy_running)" "$(t 'rp.sites')" \
            "$(_rp_count_meta "${RP_CADDY_DATA}/meta")"
    else
        printf '  Caddy  %s\n' "$(t 'rp.notinstalled')"
    fi

    if [ "$nginx_installed" = "1" ]; then
        printf '  Nginx  %s  %s  %s: %s\n' \
            "$(t 'rp.installed')" "$(_rp_state_word _rp_nginx_running)" "$(t 'rp.sites')" \
            "$(_rp_count_meta "${RP_NGINX_DATA}/meta")"
    else
        printf '  Nginx  %s\n' "$(t 'rp.notinstalled')"
    fi

    printf '\n  %s\n' "$(t 'rp.hint')"
    printf '\n'
    return 0
}
