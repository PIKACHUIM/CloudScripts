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

# 进入后按当前引擎直接给出站点管理；这两个菜单只在“无从判断”时出现。
RPPickMENU=(
    "caddy|rp.use.caddy|rp.use.caddy.desc|do_rp_use_caddy"
    "nginx|rp.use.nginx|rp.use.nginx.desc|do_rp_use_nginx"
)

RPInstallMENU=(
    "caddy|rp.install.caddy|rp.install.caddy.desc|do_rp_install_caddy"
    "nginx|rp.install.nginx|rp.install.nginx.desc|do_rp_install_nginx"
)

# 两种引擎共用一套编号，用户不需要记两套菜单。
RPMAINMENU=(
    "list|rp.menu.list|rp.menu.list.desc|do_rp_site_list"
    "add|rp.menu.add|rp.menu.add.desc|do_rp_site_add"
    "edit|rp.menu.edit|rp.menu.edit.desc|do_rp_site_edit"
    "del|rp.menu.del|rp.menu.del.desc|do_rp_site_del"
    "toggle|rp.menu.toggle|rp.menu.toggle.desc|do_rp_site_toggle"
    "test|rp.menu.test|rp.menu.test.desc|do_rp_site_test"
    "certs|rp.menu.certs|rp.menu.certs.desc|do_rp_certs"
    "service|rp.menu.service|rp.menu.service.desc|do_rp_service"
    "engine|rp.menu.engine|rp.menu.engine.desc|do_rp_engine"
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
    # 进程是事实：先看谁在跑，再看上次记录的选择。
    if _rp_caddy_running; then
        printf '%s' "caddy"
        return 0
    fi
    if _rp_nginx_running; then
        printf '%s' "nginx"
        return 0
    fi
    if [ -f "$RP_STATE_FILE" ]; then
        b=$(head -1 "$RP_STATE_FILE" 2>/dev/null || true)
        case "$b" in
            caddy|nginx)
                printf '%s' "$b"
                return 0
                ;;
        esac
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

# ============================================================
#  Entries
#  进入反向代理时不再先问引擎：状态文件 → 已安装的那个 → 判断不了才问。
#  这里只做“打开菜单”，不安装、不启动、不停另一个引擎。
# ============================================================
RP_BACKEND=""

_rp_caddy_installed() {
    if [ -n "${CADDY_BIN:-}" ] && [ -x "$CADDY_BIN" ]; then
        return 0
    fi
    [ -x /usr/local/bin/caddy ]
}

_rp_nginx_installed() {
    command -v nginx >/dev/null 2>&1 && return 0
    [ -x /usr/sbin/nginx ]
}

_rp_installed() {
    case "$1" in
        caddy) _rp_caddy_installed ;;
        nginx) _rp_nginx_installed ;;
        *)     return 1 ;;
    esac
}

_rp_sites_count() {
    case "$1" in
        caddy) _rp_count_meta "${RP_CADDY_DATA}/meta" ;;
        nginx) _rp_count_meta "${RP_NGINX_DATA}/meta" ;;
        *)     printf '0' ;;
    esac
}

# "反向代理 · Caddy · 运行中 · 3 个站点"
_rp_title() {
    printf '%s · %s · %s · %s' \
        "$(t 'rp.title')" \
        "$(_rp_label "$1")" \
        "$(_rp_state_word "_rp_$1_running")" \
        "$(t 'rp.sites_n' "$(_rp_sites_count "$1")")"
}

_rp_open() {
    case "$1" in
        caddy) _load_module "caddy.sh" || return 1 ;;
        nginx) _load_module "nginx.sh" || return 1 ;;
        *) return 1 ;;
    esac
    RP_BACKEND="$1"
    _menu_loop "rp" "RPMAINMENU" "$(_rp_title "$1")" 1
    return 0
}

# 把当前选中的条目交给对应后端的同名函数
_rp_call() {
    case "$RP_BACKEND" in
        caddy) "$1" ;;
        nginx) "$2" ;;
        *)     pika_err "$(t 'rp.no_backend')"; return 1 ;;
    esac
}

do_rp_enter() {
    local b c n first=1
    # 安装/选择子菜单用 rc=2 退出，然后这里重新判断一次，装好就直接进站点菜单。
    while true; do
        c=0
        n=0
        _rp_caddy_installed && c=1
        _rp_nginx_installed && n=1
        b=$(_rp_backend_get)

        case "$b" in
            caddy) if [ "$c" = "1" ]; then _rp_open caddy; return 0; fi ;;
            nginx) if [ "$n" = "1" ]; then _rp_open nginx; return 0; fi ;;
        esac

        if [ "$c" = "1" ] && [ "$n" = "0" ]; then
            _rp_backend_set caddy
            _rp_open caddy
            return 0
        fi
        if [ "$n" = "1" ] && [ "$c" = "0" ]; then
            _rp_backend_set nginx
            _rp_open nginx
            return 0
        fi

        # 已经给过一次选择/安装菜单，还没装成就是用户放弃了
        if [ "$first" = "0" ]; then
            return 0
        fi
        first=0

        if [ "$c" = "1" ] && [ "$n" = "1" ]; then
            _menu_loop "rp" "RPPickMENU" "rp.pick.title"
        else
            _menu_loop "rp" "RPInstallMENU" "rp.install.title"
        fi
    done
}

# 选好之后返回 2，让子菜单关闭、由 do_rp_enter 打开站点菜单
do_rp_use_caddy() { _rp_backend_set caddy; return 2; }
do_rp_use_nginx() { _rp_backend_set nginx; return 2; }

do_rp_install_caddy() {
    _load_module "caddy.sh" || return 1
    _rp_prepare caddy || return 0
    if ! do_caddy_install; then
        return 1
    fi
    _rp_backend_set caddy
    _rp_caddy_running || _rp_start_backend caddy
    return 2
}

do_rp_install_nginx() {
    _load_module "nginx.sh" || return 1
    _rp_prepare nginx || return 0
    if ! do_nginx_install; then
        return 1
    fi
    _rp_backend_set nginx
    _rp_nginx_running || _rp_start_backend nginx
    return 2
}

# ---- 统一菜单的分发 ----
do_rp_site_list()   { _rp_call do_caddy_site_list   do_nginx_site_list; }
do_rp_site_add()    { _rp_call do_caddy_site_add    do_nginx_site_add; }
do_rp_site_edit()   { _rp_call do_caddy_site_edit   do_nginx_site_edit; }
do_rp_site_del()    { _rp_call do_caddy_site_del    do_nginx_site_del; }
do_rp_site_toggle() { _rp_call do_caddy_site_toggle do_nginx_site_toggle; }
do_rp_site_test()   { _rp_call do_caddy_site_test   do_nginx_site_test; }
do_rp_certs()       { _rp_call do_caddy_certs       do_nginx_certs; }
do_rp_service()     { _rp_call do_caddy_service     do_nginx_service; }

# ---- 引擎设置：状态 + （切换、卸载、校验、安装） ----
do_rp_engine() {
    local src
    case "$RP_BACKEND" in
        caddy) src="CaddyMENU" ;;
        nginx) src="NginxMENU" ;;
        *)     pika_err "$(t 'rp.no_backend')"; return 1 ;;
    esac

    do_rp_status
    PIKA_KEEP_SCREEN=1

    local -n _rp_src="$src"
    local e k tk dk h
    RPEngineMENU=()
    for e in "${_rp_src[@]}"; do
        IFS='|' read -r k tk dk h <<< "$e"
        # 已安装时不再显示“安装”项（它在引擎子菜单里）
        if [ "$k" = "install" ] && _rp_installed "$RP_BACKEND"; then
            continue
        fi
        RPEngineMENU+=("$e")
    done
    RPEngineMENU+=("switch|rp.switch|rp.switch.desc|do_rp_switch")

    _menu_loop "rp" "RPEngineMENU" "$(t 'rp.title') · $(_rp_label "$RP_BACKEND") · $(t 'rp.settings')" 1
    return 0
}

do_rp_switch() {
    local other
    case "$RP_BACKEND" in
        caddy) other="nginx" ;;
        nginx) other="caddy" ;;
        *)     return 0 ;;
    esac

    if ! _rp_installed "$other"; then
        pika_info "$(t 'rp.other_missing' "$(_rp_label "$other")")"
        return 0
    fi
    pika_warn "$(t 'rp.switch.confirm' "$(_rp_label "$RP_BACKEND")")"
    pika_confirm "$(t 'rp.switch.ask')" || { pika_info "$(t 'ui.cancelled')"; return 0; }

    _rp_stop_backend "$RP_BACKEND"
    _rp_backend_set "$other"
    _rp_start_backend "$other"
    pika_info "$(t 'rp.switch.done' "$(_rp_label "$other")")"
    _rp_open "$other"
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
