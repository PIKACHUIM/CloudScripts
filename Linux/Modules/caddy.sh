#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Caddy Module
#  One-click install, reverse proxy and SSL certificate management.
#
#  Layout:
#    /etc/caddy/Caddyfile               master config (managed)
#    /etc/caddy/pika/sites/*.caddy      one fragment per reverse-proxy site
#    /etc/caddy/pika/meta/*.meta        site metadata (key=value)
#    /etc/caddy/pika/certs/<id>/        uploaded / ACME-issued certificates
#    /etc/caddy/pika/backups/           config snapshots (for rollback)
#
#  Requires: core libs (00-core, 10-net, 20-pkg, 30-svc, 40-ui, 50-i18n)
# ============================================================
set -e

# ---- Paths / constants ----
CADDY_BIN="/usr/local/bin/caddy"
CADDY_WRAPPER="/usr/local/bin/pika-caddy-daemon.sh"
CADDY_DATA_DIR="/etc/caddy/pika"
CADDY_MAIN_CONF="/etc/caddy/Caddyfile"
CADDY_SITE_DIR="${CADDY_DATA_DIR}/sites"
CADDY_META_DIR="${CADDY_DATA_DIR}/meta"
CADDY_CERT_DIR="${CADDY_DATA_DIR}/certs"
CADDY_BACKUP_DIR="${CADDY_DATA_DIR}/backups"
CADDY_SVC_NAME_FILE="${CADDY_DATA_DIR}/service.name"
CADDY_RELOAD_SCRIPT="${CADDY_DATA_DIR}/reload.sh"
CADDY_DEFAULT_VERSION="${CADDY_VERSION:-2.10.0}"
CADDY_SITE_IDS=()
CADDY_CERT_IDS=()

# ============================================================
#  Menu data
# ============================================================
CaddyMENU=(
    "install|caddy.install|caddy.install.desc|do_caddy_install"
    "sites|caddy.sites|caddy.sites.desc|do_caddy_sites"
    "certs|caddy.certs|caddy.certs.desc|do_caddy_certs"
    "service|caddy.service|caddy.service.desc|do_caddy_service"
    "validate|caddy.validate|caddy.validate.desc|do_caddy_validate_menu"
    "uninstall|caddy.uninstall|caddy.uninstall.desc|do_caddy_uninstall"
)

CaddySitesMENU=(
    "list|caddy.site.list|caddy.site.list.desc|do_caddy_site_list"
    "add|caddy.site.add|caddy.site.add.desc|do_caddy_site_add"
    "edit|caddy.site.edit|caddy.site.edit.desc|do_caddy_site_edit"
    "del|caddy.site.del|caddy.site.del.desc|do_caddy_site_del"
)

CaddyCertsMENU=(
    "list|caddy.cert.list|caddy.cert.list.desc|do_caddy_cert_list"
    "upload|caddy.cert.upload|caddy.cert.upload.desc|do_caddy_cert_upload"
    "acme|caddy.cert.acme|caddy.cert.acme.desc|do_caddy_cert_acme"
    "del|caddy.cert.del|caddy.cert.del.desc|do_caddy_cert_delete"
)

CaddyServiceMENU=(
    "status|caddy.service.status|caddy.service.status.desc|do_caddy_status"
    "start|caddy.service.start|caddy.service.start.desc|do_caddy_start"
    "stop|caddy.service.stop|caddy.service.stop.desc|do_caddy_stop"
    "restart|caddy.service.restart|caddy.service.restart.desc|do_caddy_restart"
    "reload|caddy.service.reload|caddy.service.reload.desc|do_caddy_reload_action"
    "logs|caddy.service.logs|caddy.service.logs.desc|do_caddy_logs"
)

# ============================================================
#  Small helpers
# ============================================================
_caddy_require() {
    if [ ! -x "$CADDY_BIN" ]; then
        pika_err "$(t 'caddy.not_installed')"
        return 1
    fi
    return 0
}

_caddy_ensure_dirs() {
    mkdir -p "/etc/caddy" "$CADDY_SITE_DIR" "$CADDY_META_DIR" "$CADDY_CERT_DIR" "$CADDY_BACKUP_DIR" /var/log/caddy 2>/dev/null || true
    if [ ! -f "${CADDY_SITE_DIR}/00-placeholder.caddy" ]; then
        printf '# Managed by PIKA SH - site fragments are generated automatically.\n' \
            > "${CADDY_SITE_DIR}/00-placeholder.caddy"
    fi
}

_caddy_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   echo "amd64" ;;
        aarch64|arm64)  echo "arm64" ;;
        armv7l|armv6l)  echo "armv7" ;;
        i386|i686)      echo "386" ;;
        ppc64le)        echo "ppc64le" ;;
        s390x)          echo "s390x" ;;
        *)              echo "" ;;
    esac
}

_caddy_slug() {
    local s
    s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9.-]/-/g; s/^[.-]*//; s/[.-]*$//; s/--*/-/g')
    if [ -z "$s" ]; then
        s="site-$(date +%s)"
    fi
    printf '%s' "$s"
}

# ---- Service name: never clobber a distro-provided caddy.service ----
_caddy_svc_name() {
    if [ -f "$CADDY_SVC_NAME_FILE" ]; then
        cat "$CADDY_SVC_NAME_FILE"
        return 0
    fi
    if [ -f /etc/systemd/system/caddy.service ] \
        || [ -f /lib/systemd/system/caddy.service ] \
        || [ -f /usr/lib/systemd/system/caddy.service ]; then
        echo "caddy-pika"
    else
        echo "caddy"
    fi
}

_caddy_set_svc_name() {
    mkdir -p "$CADDY_DATA_DIR" 2>/dev/null || true
    printf '%s\n' "$1" > "$CADDY_SVC_NAME_FILE"
}

_caddy_running() {
    local name
    name=$(_caddy_svc_name)
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
    pgrep -f "caddy run --config" >/dev/null 2>&1 && return 0
    return 1
}

# ---- Meta files (key=value) ----
_caddy_meta_file_get() {
    local f="$1" k="$2"
    [ -f "$f" ] || return 1
    sed -n "s/^${k}=//p" "$f" 2>/dev/null | head -1
}

_caddy_meta_file_set() {
    local f="$1" k="$2" v="$3" tmp line
    tmp="${f}.tmp"
    : > "$tmp"
    if [ -f "$f" ]; then
        while IFS= read -r line; do
            case "$line" in
                "${k}="*) ;;
                *) printf '%s\n' "$line" >> "$tmp" ;;
            esac
        done < "$f"
    fi
    printf '%s=%s\n' "$k" "$v" >> "$tmp"
    mv -f "$tmp" "$f"
}

_caddy_meta_get() { _caddy_meta_file_get "$(_caddy_meta_path "$1")" "$2"; }
_caddy_meta_set() { _caddy_meta_file_set "$(_caddy_meta_path "$1")" "$2" "$3"; }

_caddy_site_path() { printf '%s/%s.caddy' "$CADDY_SITE_DIR" "$1"; }
_caddy_meta_path() { printf '%s/%s.meta' "$CADDY_META_DIR" "$1"; }

_caddy_global_get() { _caddy_meta_file_get "${CADDY_DATA_DIR}/global.meta" "$1"; }
_caddy_global_set() { _caddy_meta_file_set "${CADDY_DATA_DIR}/global.meta" "$1" "$2"; }

# ---- Config backup ----
_caddy_backup() {
    _caddy_ensure_dirs
    local d
    d="${CADDY_BACKUP_DIR}/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$d" 2>/dev/null || true
    if [ -f "$CADDY_MAIN_CONF" ]; then
        cp -f "$CADDY_MAIN_CONF" "$d/Caddyfile" 2>/dev/null || true
    fi
    cp -rf "$CADDY_SITE_DIR" "$d/sites" 2>/dev/null || true
    printf '%s' "$d"
}

# ---- Master Caddyfile ----
_caddy_write_master() {
    _caddy_ensure_dirs
    local email tmp="${CADDY_MAIN_CONF}.pika.tmp"
    email=$(_caddy_global_get "email" 2>/dev/null || true)
    {
        printf '# Managed by PIKA SH (pikash) - manual edits may be overwritten.\n'
        printf '# Site fragments: %s/*.caddy\n' "$CADDY_SITE_DIR"
        printf '{\n'
        if [ -n "$email" ]; then
            printf '\temail %s\n' "$email"
        fi
        printf '\tadmin localhost:2019\n'
        printf '}\n\n'
        printf 'import %s/*.caddy\n' "$CADDY_SITE_DIR"
    } > "$tmp"
    mv -f "$tmp" "$CADDY_MAIN_CONF"
}

# ---- Daemon wrapper (works with systemd / pm2 / nohup backends) ----
_caddy_write_wrapper() {
    mkdir -p "${CADDY_WRAPPER%/*}" 2>/dev/null || true
    cat > "$CADDY_WRAPPER" <<WRAPEOF
#!/usr/bin/env bash
exec "$CADDY_BIN" run --config "$CADDY_MAIN_CONF" --adapter caddyfile
WRAPEOF
    chmod 0755 "$CADDY_WRAPPER"
}

_caddy_write_reload_script() {
    mkdir -p "${CADDY_RELOAD_SCRIPT%/*}" 2>/dev/null || true
    cat > "$CADDY_RELOAD_SCRIPT" <<RELOADEOF
#!/usr/bin/env bash
"$CADDY_BIN" reload --config "$CADDY_MAIN_CONF" --adapter caddyfile >/dev/null 2>&1 || true
RELOADEOF
    chmod 0755 "$CADDY_RELOAD_SCRIPT"
}

# ---- Validate + apply ----
_caddy_validate() {
    local out
    if out=$("$CADDY_BIN" validate --config "$CADDY_MAIN_CONF" --adapter caddyfile 2>&1); then
        return 0
    fi
    pika_err "$(t 'caddy.config.invalid')"
    printf '%s\n' "$out" >&2
    return 1
}

# ---- Self-heal: the recorded service name may have no unit/process at all ----
# Older builds never registered a unit, so the name file can point at a
# service that does not exist ("Unit caddy.service not found").
_caddy_ensure_service() {
    _caddy_require || return 1
    local name
    name=$(_caddy_svc_name)
    if svc_registered "$name"; then
        return 0
    fi
    pika_warn "$(t 'caddy.service.missing'): $name"
    _caddy_ensure_dirs
    _caddy_write_wrapper
    [ -f "$CADDY_MAIN_CONF" ] || _caddy_write_master
    [ -f "$CADDY_SVC_NAME_FILE" ] || _caddy_set_svc_name "$name"
    if ! svc_register --name "$name" --exec "$CADDY_WRAPPER" --workdir "/etc/caddy" \
        --autostart --desc "Caddy Web Server (PIKA SH)"; then
        pika_err "$(t 'caddy.install.failed')"
        return 1
    fi
    pika_info "$(t 'caddy.service.registered'): $name"
    return 0
}

# ---- Why is it not running? Show config/log/port evidence ----
_caddy_fail_hint() {
    local name vout busy
    name=$(_caddy_svc_name)
    pika_warn "$(t 'caddy.service.stopped')"
    pika_info "$(t 'caddy.service.hint')"

    if [ -x "$CADDY_BIN" ] && [ -f "$CADDY_MAIN_CONF" ]; then
        if ! vout=$("$CADDY_BIN" validate --config "$CADDY_MAIN_CONF" --adapter caddyfile 2>&1); then
            pika_err "$(t 'caddy.config.invalid')"
            printf '%s\n' "$vout" >&2
        fi
    fi

    busy=""
    if command -v ss >/dev/null 2>&1; then
        busy=$(ss -lntp 2>/dev/null | grep -E ':(80|443|2019)[[:space:]]' || true)
    elif command -v netstat >/dev/null 2>&1; then
        busy=$(netstat -lntp 2>/dev/null | grep -E ':(80|443|2019)[[:space:]]' || true)
    fi
    if [ -n "$busy" ]; then
        pika_warn "$(t 'caddy.port.busy')"
        printf '%s\n' "$busy" >&2
    fi

    svc_logs "$name" 15 2>/dev/null || true
    return 0
}

_caddy_apply() {
    _caddy_validate || return 1
    _caddy_ensure_service || return 1
    if _caddy_running; then
        if ! "$CADDY_BIN" reload --config "$CADDY_MAIN_CONF" --adapter caddyfile 2>&1; then
            pika_warn "$(t 'caddy.reload.failed')"
            svc_restart "$(_caddy_svc_name)" || true
        fi
    else
        svc_start "$(_caddy_svc_name)" || true
        sleep 1
        if ! _caddy_running; then
            _caddy_fail_hint
        fi
    fi
    return 0
}

# ============================================================
#  Install / upgrade
# ============================================================
_caddy_latest_version() {
    local v
    v=$(pika_gh_api "repos/caddyserver/caddy/releases/latest" 2>/dev/null \
        | grep -m1 '"tag_name"' 2>/dev/null \
        | sed -E 's/.*"v?([0-9]+\.[0-9]+\.[0-9]+)".*/\1/' || true)
    printf '%s' "$v"
}

_caddy_download_binary() {
    local ver="$1" arch="$2" dest="$3"
    local base="https://github.com/caddyserver/caddy/releases/download/v${ver}/caddy_${ver}_linux_${arch}.tar.gz"
    local tmpd archive
    tmpd=$(mktemp -d 2>/dev/null || echo "/tmp/pika-caddy-$$")
    mkdir -p "$tmpd"
    archive="${tmpd}/caddy.tar.gz"

    pika_info "$(t 'caddy.install.fetching') v${ver} (linux/${arch})..."
    # pika_fetch tries GitHub directly and then every accelerator prefix.
    if ! pika_fetch "$base" -o "$archive" --no-cache --max-time 300; then
        pika_err "$(t 'caddy.install.failed')"
        rm -rf "$tmpd"
        return 1
    fi

    mkdir -p "${tmpd}/x"
    if ! tar -xzf "$archive" -C "${tmpd}/x" 2>/dev/null; then
        pika_err "$(t 'caddy.install.failed')"
        rm -rf "$tmpd"
        return 1
    fi
    if [ ! -f "${tmpd}/x/caddy" ]; then
        pika_err "$(t 'caddy.install.failed')"
        rm -rf "$tmpd"
        return 1
    fi

    cp -f "${tmpd}/x/caddy" "$dest"
    chmod 0755 "$dest"
    rm -rf "$tmpd"
    return 0
}

do_caddy_install() {
    local arch
    arch=$(_caddy_arch)
    if [ -z "$arch" ]; then
        pika_err "$(t 'caddy.install.noarch'): $(uname -m)"
        return 1
    fi

    ui_confirm_install "Caddy" "$(t 'caddy.install.desc')" || { pika_info "$(t 'ui.cancelled')"; return 0; }

    # Never silently drop a foreign Caddyfile
    if [ -f "$CADDY_MAIN_CONF" ] && ! grep -q 'Managed by PIKA SH' "$CADDY_MAIN_CONF" 2>/dev/null; then
        pika_warn "$(t 'caddy.install.foreign')"
        if ! pika_confirm "$(t 'caddy.install.adopt')"; then
            pika_info "$(t 'ui.cancelled')"
            return 0
        fi
        mkdir -p "$CADDY_BACKUP_DIR"
        cp -f "$CADDY_MAIN_CONF" "${CADDY_BACKUP_DIR}/Caddyfile.before-pika.$(date +%s)"
    fi

    ensure_cmd tar curl openssl 2>/dev/null || true

    # Optional ACME contact email
    if [ -z "$(_caddy_global_get "email" 2>/dev/null || true)" ]; then
        local email
        read -r -p "  $(t 'caddy.email.prompt'): " email || email=""
        if [ -n "$email" ]; then
            _caddy_ensure_dirs
            _caddy_global_set "email" "$email"
        fi
    fi

    local ver
    ver=$(_caddy_latest_version)
    [ -z "$ver" ] && ver="$CADDY_DEFAULT_VERSION"

    if ! _caddy_download_binary "$ver" "$arch" "${CADDY_BIN}.new"; then
        if [ "$ver" != "$CADDY_DEFAULT_VERSION" ]; then
            pika_warn "v${ver} failed, retrying v${CADDY_DEFAULT_VERSION}"
            if ! _caddy_download_binary "$CADDY_DEFAULT_VERSION" "$arch" "${CADDY_BIN}.new"; then
                return 1
            fi
        else
            return 1
        fi
    fi
    mv -f "${CADDY_BIN}.new" "$CADDY_BIN"
    chmod 0755 "$CADDY_BIN"

    _caddy_ensure_dirs
    _caddy_write_wrapper
    _caddy_write_reload_script
    _caddy_write_master

    # Pick a service name that does not clash with a distro caddy unit
    if [ ! -f "$CADDY_SVC_NAME_FILE" ]; then
        if [ -f /etc/systemd/system/caddy.service ] \
            || [ -f /lib/systemd/system/caddy.service ] \
            || [ -f /usr/lib/systemd/system/caddy.service ]; then
            _caddy_set_svc_name "caddy-pika"
        else
            _caddy_set_svc_name "caddy"
        fi
    fi

    local name
    name=$(_caddy_svc_name)
    if ! svc_register --name "$name" --exec "$CADDY_WRAPPER" --workdir "/etc/caddy" \
        --autostart --desc "Caddy Web Server (PIKA SH)"; then
        pika_err "$(t 'caddy.install.failed')"
        return 1
    fi
    svc_restart "$name" || true

    sleep 1
    if _caddy_running; then
        pika_info "$(t 'caddy.install.success'): $("$CADDY_BIN" version 2>/dev/null | head -1)"
    else
        _caddy_fail_hint
    fi
    printf '  %s: %s\n' "$(t 'caddy.service.config')" "$CADDY_MAIN_CONF"
    printf '  %s: %s\n' "$(t 'caddy.service.name')" "$name"
    return 0
}

# ============================================================
#  Site table / selection
# ============================================================
_caddy_collect_sites() {
    CADDY_SITE_IDS=()
    local f b
    for f in "${CADDY_META_DIR}"/*.meta; do
        [ -f "$f" ] || continue
        b="${f##*/}"
        CADDY_SITE_IDS+=("${b%.meta}")
    done
    [ ${#CADDY_SITE_IDS[@]} -gt 0 ]
}

# ---- 站点是否启用（meta 里没有 enabled 字段 = 启用） ----
_caddy_site_enabled() {
    local v
    v=$(_caddy_meta_get "$1" "enabled" 2>/dev/null || true)
    [ "${v:-1}" != "0" ]
}

_caddy_print_sites() {
    if ! _caddy_collect_sites; then
        pika_info "$(t 'caddy.site.none')"
        return 1
    fi
    printf '\n  %-4s %s %s %s %s %s\n' \
        "#" \
        "$(_ui_str_pad "$(t 'caddy.site.domains')" 26)" \
        "$(_ui_str_pad "$(t 'caddy.site.upstream')" 26)" \
        "$(_ui_str_pad "$(t 'caddy.site.tls')" 10)" \
        "$(_ui_str_pad "$(t 'rp.state')" 6)" \
        "$(t 'site.port')"
    local i=1 id d u m p st
    for id in "${CADDY_SITE_IDS[@]}"; do
        d=$(_caddy_meta_get "$id" "domains" 2>/dev/null || true)
        u=$(_caddy_meta_get "$id" "upstreams" 2>/dev/null || true)
        m=$(_caddy_meta_get "$id" "tls_mode" 2>/dev/null || true)
        p=$(_caddy_meta_get "$id" "port" 2>/dev/null || true)
        if _caddy_site_enabled "$id"; then st=$(t 'rp.state.on'); else st=$(t 'rp.state.off'); fi
        printf '  %-4s %s %s %s %s %s\n' \
            "[$i]" "$(_ui_str_pad "$d" 26)" "$(_ui_str_pad "$u" 26)" \
            "$(_ui_str_pad "${m:-auto}" 10)" "$(_ui_str_pad "$st" 6)" \
            "${p:-$(t 'site.port.default')}"
        i=$((i + 1))
    done
    return 0
}

_caddy_pick_site() {
    _caddy_print_sites >&2 || return 1
    local n total="${#CADDY_SITE_IDS[@]}"
    read -r -p "  $(t 'caddy.site.select') [1-${total}]: " n || return 1
    case "$n" in
        ''|*[!0-9]*) return 1 ;;
    esac
    if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        return 1
    fi
    printf '%s' "${CADDY_SITE_IDS[$((n - 1))]}"
}

# ============================================================
#  Site rendering
# ============================================================
_caddy_render_site() {
    local id="$1"
    local domains upstreams tls_mode cert key extra port addrs upstream_list d u host enabled
    # A disabled site keeps its metadata but renders no Caddyfile fragment.
    enabled=$(_caddy_meta_get "$id" "enabled" 2>/dev/null || true)
    if [ "${enabled:-1}" = "0" ]; then
        rm -f "$(_caddy_site_path "$id")"
        return 0
    fi
    domains=$(_caddy_meta_get "$id" "domains" 2>/dev/null || true)
    upstreams=$(_caddy_meta_get "$id" "upstreams" 2>/dev/null || true)
    tls_mode=$(_caddy_meta_get "$id" "tls_mode" 2>/dev/null || true)
    cert=$(_caddy_meta_get "$id" "cert" 2>/dev/null || true)
    key=$(_caddy_meta_get "$id" "key" 2>/dev/null || true)
    extra=$(_caddy_meta_get "$id" "extra" 2>/dev/null || true)
    port=$(_caddy_meta_get "$id" "port" 2>/dev/null || true)

    addrs=""
    local _ng=0
    case $- in *f*) _ng=1 ;; *) set -f ;; esac
    for d in $(printf '%s' "$domains" | tr ',' ' '); do
        host="$d"
        [ -n "$port" ] && host="${d}:${port}"
        if [ "$tls_mode" = "off" ]; then
            addrs="${addrs}${addrs:+, }http://${host}"
        elif [ -n "$port" ]; then
            addrs="${addrs}${addrs:+, }https://${host}"
        else
            addrs="${addrs}${addrs:+, }${host}"
        fi
    done
    [ "$_ng" = "1" ] || set +f

    upstream_list=""
    for u in $(printf '%s' "$upstreams" | tr ',' ' '); do
        upstream_list="${upstream_list}${upstream_list:+ }${u}"
    done

    {
        printf '# Managed by PIKA SH - site id: %s\n' "$id"
        printf '%s {\n' "$addrs"
        case "$tls_mode" in
            manual)
                printf '\ttls %s %s\n' "$cert" "$key"
                ;;
            internal)
                printf '\ttls internal\n'
                ;;
        esac
        if [ -n "$upstream_list" ]; then
            printf '\treverse_proxy %s\n' "$upstream_list"
        fi
        if [ -n "$extra" ]; then
            printf '\t%s\n' "$extra"
        fi
        printf '}\n'
    } > "$(_caddy_site_path "$id")"
    return 0
}

# ============================================================
#  Site add / list / delete
# ============================================================
_caddy_clean_domains() {
    local raw out="" d _ng=0
    raw=$(printf '%s' "$1" | tr ',' ' ')
    case $- in *f*) _ng=1 ;; *) set -f ;; esac
    for d in $raw; do
        d="${d#http://}"
        d="${d#https://}"
        d="${d%%/*}"
        if [ -z "$d" ]; then
            continue
        fi
        case "$d" in
            *[!A-Za-z0-9._:*-]*)
                [ "$_ng" = "1" ] || set +f
                return 1
                ;;
        esac
        out="${out}${out:+,}${d}"
    done
    [ "$_ng" = "1" ] || set +f
    if [ -z "$out" ]; then
        return 1
    fi
    printf '%s' "$out"
}

# ---- Normalise a listen port: empty/0 => default 80/443 ----
_caddy_clean_port() {
    local p
    p=$(printf '%s' "${1:-}" | tr -d ' \t')
    case "$p" in
        ''|0|:0) return 0 ;;
    esac
    p="${p#:}"
    p="${p#*:}"
    case "$p" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$p" -ge 1 ] && [ "$p" -le 65535 ] || return 1
    printf '%s' "$p"
}

# ---- A TLS site cannot listen on 80 (that is the plain-HTTP port) ----
_caddy_port_tls_conflict() {
    [ "${1:-}" = "80" ] && [ "${2:-off}" != "off" ]
}

do_caddy_site_add() {
    _caddy_require || return 1
    _caddy_ensure_dirs

    local domains_raw domains upstream tls_choice tls_mode cert_id extra id
    read -r -p "  $(t 'caddy.site.domain'): " domains_raw || return 1
    if [ -z "$domains_raw" ]; then
        pika_err "$(t 'caddy.site.empty')"
        return 1
    fi
    if ! domains=$(_caddy_clean_domains "$domains_raw"); then
        pika_err "$(t 'caddy.site.invalid')"
        return 1
    fi

    read -r -p "  $(t 'caddy.site.upstream') [http://127.0.0.1:8080]: " upstream || return 1
    upstream="${upstream:-http://127.0.0.1:8080}"
    upstream=$(printf '%s' "$upstream" | tr ',' ' ' | tr -s ' ' ',')
    upstream="${upstream#,}"
    upstream="${upstream%,}"

    printf '\n  1) %s\n  2) %s\n  3) %s\n  4) %s\n' \
        "$(t 'caddy.tls.auto')" "$(t 'caddy.tls.manual')" \
        "$(t 'caddy.tls.internal')" "$(t 'caddy.tls.off')"
    read -r -p "  $(t 'caddy.site.tls') [1-4, default 1]: " tls_choice || return 1
    tls_choice="${tls_choice:-1}"

    tls_mode="auto"
    cert_id=""
    case "$tls_choice" in
        2)
            tls_mode="manual"
            if _caddy_collect_certs; then
                if ! cert_id=$(_caddy_pick_cert); then
                    pika_info "$(t 'ui.cancelled')"
                    return 1
                fi
            else
                pika_info "$(t 'caddy.cert.none')"
                if ! cert_id=$(_caddy_cert_import_flow); then
                    pika_info "$(t 'ui.cancelled')"
                    return 1
                fi
            fi
            ;;
        3) tls_mode="internal" ;;
        4) tls_mode="off" ;;
        *) tls_mode="auto" ;;
    esac

    read -r -p "  $(t 'caddy.site.extra'): " extra || extra=""

    local port_in port=""
    printf '  %s (%s)\n' "$(t 'site.port')" "$(t 'site.port.hint')"
    read -r -p "  $(t 'site.port') [default]: " port_in || port_in=""
    if ! port=$(_caddy_clean_port "$port_in"); then
        pika_err "$(t 'site.port.invalid')"
        return 1
    fi
    if _caddy_port_tls_conflict "$port" "$tls_mode"; then
        pika_err "$(t 'site.port.tls80')"
        return 1
    fi

    id=$(_caddy_slug "${domains%%,*}")
    if [ -f "$(_caddy_meta_path "$id")" ]; then
        pika_err "$(t 'caddy.site.exists'): $id"
        return 1
    fi

    _caddy_backup >/dev/null 2>&1 || true
    _caddy_meta_set "$id" "domains" "$domains"
    _caddy_meta_set "$id" "upstreams" "$upstream"
    _caddy_meta_set "$id" "tls_mode" "$tls_mode"
    _caddy_meta_set "$id" "extra" "$extra"
    _caddy_meta_set "$id" "port" "$port"
    _caddy_meta_set "$id" "created" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ -n "$cert_id" ]; then
        _caddy_meta_set "$id" "cert" "${CADDY_CERT_DIR}/${cert_id}/cert.pem"
        _caddy_meta_set "$id" "key" "${CADDY_CERT_DIR}/${cert_id}/key.pem"
    fi
    _caddy_render_site "$id"

    if ! _caddy_apply; then
        rm -f "$(_caddy_site_path "$id")" "$(_caddy_meta_path "$id")"
        _caddy_apply >/dev/null 2>&1 || true
        return 1
    fi

    pika_info "$(t 'caddy.site.added'): $domains -> $upstream"
    if [ "$tls_mode" = "auto" ]; then
        pika_info "$(t 'caddy.tls.auto.hint')"
    fi
    return 0
}

do_caddy_site_list() {
    _caddy_require || return 1
    _caddy_print_sites || return 0
    printf '\n  %s: %s\n' "$(t 'caddy.site.dir')" "$CADDY_SITE_DIR"
    return 0
}

# ---- Edit an existing site: domains, upstream, TLS mode, extra, port ----
do_caddy_site_edit() {
    _caddy_require || return 1
    _caddy_collect_sites || { pika_info "$(t 'caddy.site.none')"; return 0; }

    local id cur_d cur_u cur_tls cur_extra cur_cert cur_key cur_port
    id=$(_caddy_pick_site) || { pika_info "$(t 'ui.cancelled')"; return 0; }
    cur_d=$(_caddy_meta_get "$id" "domains" 2>/dev/null || true)
    cur_u=$(_caddy_meta_get "$id" "upstreams" 2>/dev/null || true)
    cur_tls=$(_caddy_meta_get "$id" "tls_mode" 2>/dev/null || true)
    cur_extra=$(_caddy_meta_get "$id" "extra" 2>/dev/null || true)
    cur_cert=$(_caddy_meta_get "$id" "cert" 2>/dev/null || true)
    cur_key=$(_caddy_meta_get "$id" "key" 2>/dev/null || true)
    cur_port=$(_caddy_meta_get "$id" "port" 2>/dev/null || true)

    printf '\n'
    printf '  %s: %s\n' "$(t 'caddy.site.domains')" "$cur_d"
    printf '  %s: %s\n' "$(t 'caddy.site.upstream')" "$cur_u"
    printf '  %s: %s\n' "$(t 'caddy.site.tls')" "${cur_tls:-auto}"
    printf '  %s: %s\n' "$(t 'site.port')" "${cur_port:-$(t 'site.port.default')}"
    printf '  %s\n\n' "$(t 'site.keep')"

    local domains_raw domains upstreams tls_choice tls_mode cert_id cert key extra extra_in port_in port tls_cur

    read -r -p "  $(t 'caddy.site.domain') [${cur_d}]: " domains_raw || return 1
    domains_raw="${domains_raw:-$cur_d}"
    if ! domains=$(_caddy_clean_domains "$domains_raw"); then
        pika_err "$(t 'caddy.site.invalid')"
        return 1
    fi

    read -r -p "  $(t 'caddy.site.upstream') [${cur_u}]: " upstreams || return 1
    upstreams="${upstreams:-$cur_u}"
    upstreams=$(printf '%s' "$upstreams" | tr ',' ' ' | tr -s ' ' ',')
    upstreams="${upstreams#,}"
    upstreams="${upstreams%,}"

    printf '\n  1) %s\n  2) %s\n  3) %s\n  4) %s\n' \
        "$(t 'caddy.tls.auto')" "$(t 'caddy.tls.manual')" \
        "$(t 'caddy.tls.internal')" "$(t 'caddy.tls.off')"
    tls_cur=1
    case "$cur_tls" in
        manual)   tls_cur=2 ;;
        internal) tls_cur=3 ;;
        off)      tls_cur=4 ;;
    esac
    read -r -p "  $(t 'caddy.site.tls') [1-4, ${tls_cur}]: " tls_choice || return 1
    tls_choice="${tls_choice:-$tls_cur}"

    tls_mode="auto"
    cert=""
    key=""
    cert_id=""
    case "$tls_choice" in
        2)
            tls_mode="manual"
            if [ "$cur_tls" = "manual" ] && [ -f "${cur_cert:-/nonexistent}" ] && [ -f "${cur_key:-/nonexistent}" ]; then
                cert="$cur_cert"
                key="$cur_key"
            elif _caddy_collect_certs; then
                if ! cert_id=$(_caddy_pick_cert); then
                    pika_info "$(t 'ui.cancelled')"
                    return 0
                fi
                cert="${CADDY_CERT_DIR}/${cert_id}/cert.pem"
                key="${CADDY_CERT_DIR}/${cert_id}/key.pem"
            else
                pika_info "$(t 'caddy.cert.none')"
                if ! cert_id=$(_caddy_cert_import_flow); then
                    pika_info "$(t 'ui.cancelled')"
                    return 0
                fi
                cert="${CADDY_CERT_DIR}/${cert_id}/cert.pem"
                key="${CADDY_CERT_DIR}/${cert_id}/key.pem"
            fi
            ;;
        3) tls_mode="internal" ;;
        4) tls_mode="off" ;;
        *) tls_mode="auto" ;;
    esac

    read -r -p "  $(t 'caddy.site.extra') [${cur_extra:-none}]: " extra_in || extra_in=""
    case "$extra_in" in
        '')  extra="$cur_extra" ;;
        '-') extra="" ;;
        *)   extra="$extra_in" ;;
    esac

    read -r -p "  $(t 'site.port') [${cur_port:-$(t 'site.port.default')}]: " port_in || port_in=""
    case "$port_in" in
        '') port="$cur_port" ;;
        '-') port="" ;;
        *)
            if ! port=$(_caddy_clean_port "$port_in"); then
                pika_err "$(t 'site.port.invalid')"
                return 1
            fi
            ;;
    esac
    if _caddy_port_tls_conflict "$port" "$tls_mode"; then
        pika_err "$(t 'site.port.tls80')"
        return 1
    fi

    # An invalid config must not destroy the existing site: keep the meta around.
    local meta_file meta_bak
    meta_file=$(_caddy_meta_path "$id")
    meta_bak="${meta_file}.edit.bak"
    cp -f "$meta_file" "$meta_bak" 2>/dev/null || true

    _caddy_meta_set "$id" "domains" "$domains"
    _caddy_meta_set "$id" "upstreams" "$upstreams"
    _caddy_meta_set "$id" "tls_mode" "$tls_mode"
    _caddy_meta_set "$id" "extra" "$extra"
    _caddy_meta_set "$id" "port" "$port"
    if [ -n "$cert" ]; then
        _caddy_meta_set "$id" "cert" "$cert"
        _caddy_meta_set "$id" "key" "$key"
    fi
    _caddy_render_site "$id"

    if ! _caddy_apply; then
        if [ -f "$meta_bak" ]; then
            mv -f "$meta_bak" "$meta_file"
        fi
        _caddy_render_site "$id"
        _caddy_apply >/dev/null 2>&1 || true
        pika_err "$(t 'site.update.failed')"
        return 1
    fi
    rm -f "$meta_bak"
    pika_info "$(t 'site.updated'): $domains"
    return 0
}

do_caddy_site_del() {
    _caddy_require || return 1
    local id
    if ! id=$(_caddy_pick_site); then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    if ! pika_confirm "$(t 'caddy.site.confirm_delete') [$id]"; then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    _caddy_backup >/dev/null 2>&1 || true
    rm -f "$(_caddy_site_path "$id")" "$(_caddy_meta_path "$id")"
    pika_info "$(t 'caddy.site.deleted'): $id"
    _caddy_apply || true
    return 0
}

# ---- 启用 / 停用：保留配置，只是不参与渲染与重载 ----
do_caddy_site_toggle() {
    _caddy_require || return 1
    _caddy_collect_sites || { pika_info "$(t 'caddy.site.none')"; return 0; }

    local id d
    id=$(_caddy_pick_site) || { pika_info "$(t 'ui.cancelled')"; return 0; }
    d=$(_caddy_meta_get "$id" "domains" 2>/dev/null || true)

    if _caddy_site_enabled "$id"; then
        _caddy_meta_set "$id" "enabled" "0"
        rm -f "$(_caddy_site_path "$id")"
        pika_info "$(t 'rp.site.disabled' "$d")"
    else
        _caddy_meta_set "$id" "enabled" "1"
        _caddy_render_site "$id"
        pika_info "$(t 'rp.site.enabled' "$d")"
    fi
    _caddy_apply || return 1
    return 0
}

# ---- 连通性测试：先测上游，再从本机按域名回环测站点 ----
do_caddy_site_test() {
    _caddy_require || return 1
    _caddy_collect_sites || { pika_info "$(t 'caddy.site.none')"; return 0; }

    local id d u port host up scheme lport tls_mode code
    id=$(_caddy_pick_site) || { pika_info "$(t 'ui.cancelled')"; return 0; }
    d=$(_caddy_meta_get "$id" "domains" 2>/dev/null || true)
    u=$(_caddy_meta_get "$id" "upstreams" 2>/dev/null || true)
    port=$(_caddy_meta_get "$id" "port" 2>/dev/null || true)
    tls_mode=$(_caddy_meta_get "$id" "tls_mode" 2>/dev/null || true)
    host=${d%%,*}
    up=${u%%,*}

    printf '\n  %s: %s\n' "$(t 'caddy.site.domains')" "$d"
    printf '  %s: %s\n\n' "$(t 'caddy.site.upstream')" "$u"

    if [ -n "$up" ]; then
        code=$(pika_http_probe "$up" 2>/dev/null || true)
        printf '  %s\n' "$(t 'rp.test.upstream' "$up" "${code:-000}")"
    fi

    if [ -n "$host" ]; then
        if [ "${tls_mode:-auto}" = "off" ]; then scheme="http"; else scheme="https"; fi
        lport="${port:-}"
        if [ -z "$lport" ]; then
            if [ "$scheme" = "https" ]; then lport=443; else lport=80; fi
        fi
        code=$(pika_http_probe "${scheme}://${host}:${lport}/" "$host" "$lport" 2>/dev/null || true)
        printf '  %s\n' "$(t 'rp.test.site' "$host" "${code:-000}")"
    fi
    return 0
}

# ============================================================
#  Certificate helpers
# ============================================================
_caddy_collect_certs() {
    CADDY_CERT_IDS=()
    local d id
    for d in "${CADDY_CERT_DIR}"/*/; do
        [ -d "$d" ] || continue
        [ -f "${d}cert.pem" ] || continue
        d="${d%/}"
        id="${d##*/}"
        CADDY_CERT_IDS+=("$id")
    done
    [ ${#CADDY_CERT_IDS[@]} -gt 0 ]
}

_caddy_cert_expiry() {
    openssl x509 -in "$1" -noout -enddate 2>/dev/null | sed 's/^notAfter=//' || true
}

_caddy_cert_domains() {
    local c="$1" out="" d _ng=0
    case $- in *f*) _ng=1 ;; *) set -f ;; esac
    for d in $(openssl x509 -in "$c" -noout -ext subjectAltName 2>/dev/null | tr ',' ' '); do
        case "$d" in
            DNS:*)
                d="${d#DNS:}"
                out="${out}${out:+,}${d}"
                ;;
        esac
    done
    [ "$_ng" = "1" ] || set +f
    printf '%s' "$out"
}

_caddy_cert_pair_ok() {
    local c="$1" k="$2" pc pk
    if ! command -v openssl >/dev/null 2>&1; then
        pika_warn "$(t 'caddy.cert.noopenssl')"
        return 0
    fi
    pc=$(openssl x509 -in "$c" -noout -pubkey 2>/dev/null | openssl sha256 2>/dev/null || true)
    pk=$(openssl pkey -in "$k" -pubout 2>/dev/null | openssl sha256 2>/dev/null || true)
    if [ -z "$pc" ] || [ -z "$pk" ]; then
        return 1
    fi
    [ "$pc" = "$pk" ]
}

_caddy_pick_cert() {
    _caddy_print_certs >&2 || return 1
    local n total="${#CADDY_CERT_IDS[@]}"
    read -r -p "  $(t 'caddy.cert.select') [1-${total}]: " n || return 1
    case "$n" in
        ''|*[!0-9]*) return 1 ;;
    esac
    if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        return 1
    fi
    printf '%s' "${CADDY_CERT_IDS[$((n - 1))]}"
}

# Import cert/key from arbitrary paths; echoes the cert id on stdout.
_caddy_cert_import_flow() {
    local c k id dir d
    read -r -p "  $(t 'caddy.cert.certpath'): " c || return 1
    read -r -p "  $(t 'caddy.cert.keypath'): " k || return 1
    c="${c%\"}"; c="${c#\"}"
    k="${k%\"}"; k="${k#\"}"

    if [ ! -f "$c" ]; then
        pika_err "$(t 'caddy.cert.missing'): $c"
        return 1
    fi
    if [ ! -f "$k" ]; then
        pika_err "$(t 'caddy.cert.missing'): $k"
        return 1
    fi
    if ! _caddy_cert_pair_ok "$c" "$k"; then
        pika_err "$(t 'caddy.cert.pairinvalid')"
        return 1
    fi

    d=$(_caddy_cert_domains "$c")
    [ -z "$d" ] && d=$(basename "${c%.*}")
    id=$(_caddy_slug "${d%%,*}")
    dir="${CADDY_CERT_DIR}/${id}"
    if [ -d "$dir" ]; then
        id="${id}-$(date +%s)"
        dir="${CADDY_CERT_DIR}/${id}"
    fi

    mkdir -p "$dir"
    cp -f "$c" "${dir}/cert.pem"
    cp -f "$k" "${dir}/key.pem"
    chmod 600 "${dir}/cert.pem" "${dir}/key.pem"
    _caddy_meta_file_set "${dir}/meta" "domains" "$d"
    _caddy_meta_file_set "${dir}/meta" "source" "upload"
    _caddy_meta_file_set "${dir}/meta" "created" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s' "$id"
}

_caddy_print_certs() {
    local i=1 id d e root f
    if _caddy_collect_certs; then
        printf '\n  %s\n' "$(t 'caddy.cert.list.title')"
        for id in "${CADDY_CERT_IDS[@]}"; do
            d=$(_caddy_meta_file_get "${CADDY_CERT_DIR}/${id}/meta" "domains" 2>/dev/null || true)
            [ -z "$d" ] && d="$id"
            e=$(_caddy_cert_expiry "${CADDY_CERT_DIR}/${id}/cert.pem")
            printf '  %-4s %s %s\n' \
                "[$i]" "$(_ui_str_pad "$d" 34)" "$(t 'caddy.cert.expire'): ${e:-?}"
            i=$((i + 1))
        done
    else
        pika_info "$(t 'caddy.cert.none')"
    fi

    # Certificates acquired by Caddy's own ACME client (read-only view)
    printf '\n  %s\n' "$(t 'caddy.cert.auto.title')"
    local found=0
    for root in "${XDG_DATA_HOME:-$HOME/.local/share}/caddy" "/root/.local/share/caddy" "/var/lib/caddy/.local/share/caddy"; do
        [ -d "${root}/certificates" ] || continue
        while IFS= read -r f; do
            [ -f "$f" ] || continue
            found=1
            printf '  %s %s\n' "$(_ui_str_pad "${f##*/}" 40)" \
                "$(t 'caddy.cert.expire'): $(_caddy_cert_expiry "$f")"
        done <<EOF
$(find "${root}/certificates" -type f -name '*.crt' 2>/dev/null | sort -u)
EOF
    done
    if [ "$found" = "0" ]; then
        pika_info "$(t 'caddy.cert.auto.none')"
    fi
    return 0
}

_caddy_bind_cert_to_site() {
    local cert_id="$1" id
    if ! _caddy_collect_sites; then
        pika_info "$(t 'caddy.site.none')"
        return 1
    fi
    if ! id=$(_caddy_pick_site); then
        return 1
    fi
    _caddy_meta_set "$id" "tls_mode" "manual"
    _caddy_meta_set "$id" "cert" "${CADDY_CERT_DIR}/${cert_id}/cert.pem"
    _caddy_meta_set "$id" "key" "${CADDY_CERT_DIR}/${cert_id}/key.pem"
    _caddy_render_site "$id"
    if _caddy_apply; then
        pika_info "$(t 'caddy.cert.bound'): $id"
        return 0
    fi
    # Roll back to automatic TLS so a bad cert cannot break the site
    _caddy_meta_set "$id" "tls_mode" "auto"
    _caddy_meta_set "$id" "cert" ""
    _caddy_meta_set "$id" "key" ""
    _caddy_render_site "$id"
    _caddy_apply >/dev/null 2>&1 || true
    return 1
}

do_caddy_cert_list() {
    _caddy_require || return 1
    _caddy_print_certs
    printf '\n  %s: %s\n' "$(t 'caddy.cert.dir')" "$CADDY_CERT_DIR"
    return 0
}

do_caddy_cert_upload() {
    _caddy_require || return 1
    _caddy_ensure_dirs
    local id
    if ! id=$(_caddy_cert_import_flow); then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    pika_info "$(t 'caddy.cert.uploaded'): $id"
    if pika_confirm "$(t 'caddy.cert.bind')"; then
        _caddy_bind_cert_to_site "$id" || true
    fi
    return 0
}

do_caddy_cert_delete() {
    _caddy_require || return 1
    if ! _caddy_collect_certs; then
        pika_info "$(t 'caddy.cert.none')"
        return 0
    fi
    local id
    if ! id=$(_caddy_pick_cert); then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    if grep -rq "${CADDY_CERT_DIR}/${id}/" "$CADDY_META_DIR" 2>/dev/null; then
        pika_err "$(t 'caddy.cert.inuse')"
        return 1
    fi
    if ! pika_confirm "$(t 'caddy.cert.confirm_delete') [$id]"; then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    rm -rf "${CADDY_CERT_DIR:?}/${id}"
    pika_info "$(t 'caddy.cert.deleted'): $id"
    return 0
}

# ============================================================
#  ACME (acme.sh) interactive issuance
# ============================================================
_caddy_acme_bin() {
    if [ -x "${HOME}/.acme.sh/acme.sh" ]; then
        printf '%s' "${HOME}/.acme.sh/acme.sh"
        return 0
    fi
    return 1
}

_caddy_acme_install_tool() {
    local email="$1"
    if _caddy_acme_bin >/dev/null 2>&1; then
        return 0
    fi
    pika_info "$(t 'caddy.cert.acme.installing')"
    if ! pika_fetch "https://get.acme.sh" -o "/tmp/pika-acme-$$.sh" --no-cache --max-time 90; then
        pika_err "$(t 'caddy.cert.acme.installfailed')"
        return 1
    fi
    if ! sh /tmp/pika-acme-$$.sh email="$email" >/dev/null 2>&1; then
        rm -f /tmp/pika-acme-$$.sh
        pika_err "$(t 'caddy.cert.acme.installfailed')"
        return 1
    fi
    rm -f /tmp/pika-acme-$$.sh
    _caddy_acme_bin >/dev/null 2>&1
}

_caddy_acme_ca_flag() {
    case "$1" in
        2) printf '%s' "zerossl" ;;
        3) printf '%s' "buypass" ;;
        *) printf '%s' "letsencrypt" ;;
    esac
}

do_caddy_cert_acme() {
    _caddy_require || return 1
    _caddy_ensure_dirs

    local domain email ca method webroot acme
    read -r -p "  $(t 'caddy.cert.acme.domain'): " domain || return 1
    if ! domain=$(_caddy_clean_domains "$domain"); then
        pika_err "$(t 'caddy.site.invalid')"
        return 1
    fi
    case "$domain" in
        *,*) pika_err "$(t 'caddy.cert.acme.single')"; return 1 ;;
    esac

    read -r -p "  $(t 'caddy.cert.acme.email'): " email || email=""
    if [ -z "$email" ]; then
        pika_err "$(t 'caddy.cert.acme.emailrequired')"
        return 1
    fi

    printf "\n  1) Let's Encrypt\n  2) ZeroSSL\n  3) Buypass\n"
    read -r -p "  $(t 'caddy.cert.acme.ca') [1-3, default 1]: " ca || ca="1"
    ca="${ca:-1}"

    printf '\n  1) %s\n  2) %s\n  3) %s\n  4) %s\n' \
        "$(t 'caddy.cert.acme.standalone')" "$(t 'caddy.cert.acme.webroot')" \
        "$(t 'caddy.cert.acme.alpn')" "$(t 'caddy.cert.acme.dns')"
    read -r -p "  $(t 'caddy.cert.acme.method') [1-4, default 1]: " method || method="1"
    method="${method:-1}"

    if ! _caddy_acme_install_tool "$email"; then
        return 1
    fi
    acme=$(_caddy_acme_bin)
    chmod +x "$acme" 2>/dev/null || true

    local ca_name
    ca_name=$(_caddy_acme_ca_flag "$ca")

    case "$method" in
        2)
            read -r -p "  $(t 'caddy.cert.acme.webrootpath') [/var/www/html]: " webroot || webroot=""
            webroot="${webroot:-/var/www/html}"
            if [ ! -d "$webroot" ]; then
                pika_err "$(t 'caddy.cert.missing'): $webroot"
                return 1
            fi
            if ! "$acme" --issue --webroot "$webroot" -d "$domain" --server "$ca_name" -m "$email"; then
                pika_err "$(t 'caddy.cert.acme.failed')"
                return 1
            fi
            ;;
        3)
            if ! "$acme" --issue --alpn -d "$domain" --server "$ca_name" -m "$email"; then
                pika_err "$(t 'caddy.cert.acme.failed')"
                return 1
            fi
            ;;
        4)
            "$acme" --issue --dns -d "$domain" --server "$ca_name" -m "$email" \
                --yes-I-know-dns-manual-mode-enough-go-ahead-please || true
            pika_info "$(t 'caddy.cert.acme.dnshint')"
            read -r -p "  $(t 'ui.press_enter')" _ || true
            if ! "$acme" --renew -d "$domain" --yes-I-know-dns-manual-mode-enough-go-ahead-please; then
                pika_err "$(t 'caddy.cert.acme.failed')"
                return 1
            fi
            pika_warn "$(t 'caddy.cert.acme.manualrenew')"
            ;;
        *)
            if ! "$acme" --issue --standalone -d "$domain" --server "$ca_name" -m "$email"; then
                pika_err "$(t 'caddy.cert.acme.failed')"
                pika_info "$(t 'caddy.cert.acme.standalonehint')"
                return 1
            fi
            ;;
    esac

    local id dir
    id=$(_caddy_slug "$domain")
    dir="${CADDY_CERT_DIR}/${id}"
    mkdir -p "$dir"
    _caddy_write_reload_script
    if ! "$acme" --install-cert -d "$domain" \
        --key-file "${dir}/key.pem" \
        --fullchain-file "${dir}/cert.pem" \
        --reloadcmd "$CADDY_RELOAD_SCRIPT"; then
        pika_err "$(t 'caddy.cert.acme.failed')"
        return 1
    fi
    chmod 600 "${dir}/cert.pem" "${dir}/key.pem" 2>/dev/null || true
    _caddy_meta_file_set "${dir}/meta" "domains" "$domain"
    _caddy_meta_file_set "${dir}/meta" "source" "acme"
    _caddy_meta_file_set "${dir}/meta" "created" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    pika_info "$(t 'caddy.cert.acme.success'): $id"
    if pika_confirm "$(t 'caddy.cert.bind')"; then
        _caddy_bind_cert_to_site "$id" || true
    fi
    return 0
}

# ============================================================
#  Service / config actions
# ============================================================
do_caddy_status() {
    _caddy_require || return 0
    local name ver state sites certs
    name=$(_caddy_svc_name)
    ver=$("$CADDY_BIN" version 2>/dev/null | head -1 || true)
    if _caddy_running; then
        state="$(t 'caddy.service.running')"
    else
        state="$(t 'caddy.service.stopped')"
    fi
    sites=0
    if _caddy_collect_sites; then
        sites=${#CADDY_SITE_IDS[@]}
    fi
    certs=0
    if _caddy_collect_certs; then
        certs=${#CADDY_CERT_IDS[@]}
    fi

    printf '\n'
    printf '  %s: %s\n' "$(t 'caddy.service.version')" "${ver:-?}"
    printf '  %s: %s\n' "$(t 'caddy.service.state')" "$state"
    printf '  %s: %s\n' "$(t 'caddy.service.name')" "$name"
    printf '  %s: %s\n' "$(t 'caddy.service.backend')" "$(svc_backend 2>/dev/null || echo '?')"
    printf '  %s: %s\n' "$(t 'caddy.service.sites')" "$sites"
    printf '  %s: %s\n' "$(t 'caddy.service.certs')" "$certs"
    printf '  %s: %s\n' "$(t 'caddy.service.config')" "$CADDY_MAIN_CONF"
    printf '  %s: %s\n' "$(t 'caddy.service.admin')" "http://localhost:2019/config/"
    if ! svc_registered "$name"; then
        pika_warn "$(t 'caddy.service.missing'): $name"
    fi
    printf '\n'
    return 0
}

do_caddy_start() {
    _caddy_require || return 1
    _caddy_ensure_service || return 1
    svc_start "$(_caddy_svc_name)" || true
    sleep 1
    if _caddy_running; then
        pika_info "$(t 'caddy.started')"
        return 0
    fi
    _caddy_fail_hint
    return 1
}

do_caddy_stop() {
    _caddy_require || return 1
    svc_stop "$(_caddy_svc_name)" || true
    pika_info "$(t 'caddy.stopped')"
    return 0
}

do_caddy_restart() {
    _caddy_require || return 1
    _caddy_ensure_service || return 1
    svc_restart "$(_caddy_svc_name)" || true
    sleep 1
    if _caddy_running; then
        pika_info "$(t 'caddy.restarted')"
        return 0
    fi
    _caddy_fail_hint
    return 1
}

do_caddy_reload_action() {
    _caddy_require || return 1
    if _caddy_apply; then
        pika_info "$(t 'caddy.reload.ok')"
        return 0
    fi
    return 1
}

do_caddy_logs() {
    _caddy_require || return 1
    PIKA_KEEP_SCREEN=1
    svc_logs "$(_caddy_svc_name)" 80 || true
    return 0
}

do_caddy_validate_menu() {
    _caddy_require || return 1
    if [ -f "$CADDY_MAIN_CONF" ]; then
        "$CADDY_BIN" fmt --overwrite "$CADDY_MAIN_CONF" 2>/dev/null || true
    fi
    if _caddy_validate; then
        pika_info "$(t 'caddy.validate.ok')"
        return 0
    fi
    return 1
}

# ============================================================
#  Uninstall
# ============================================================
do_caddy_uninstall() {
    if ! pika_confirm "$(t 'caddy.uninstall.confirm')"; then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    local name keep=0
    name=$(_caddy_svc_name)
    svc_stop "$name" >/dev/null 2>&1 || true
    svc_remove "$name" >/dev/null 2>&1 || true

    if pika_confirm "$(t 'caddy.uninstall.keepcerts')"; then
        keep=1
    fi
    if [ "$keep" = "1" ]; then
        rm -rf "$CADDY_SITE_DIR" "$CADDY_META_DIR" "$CADDY_BACKUP_DIR"
        rm -f "$CADDY_SVC_NAME_FILE" "$CADDY_RELOAD_SCRIPT" "${CADDY_DATA_DIR}/global.meta"
    else
        rm -rf "$CADDY_DATA_DIR"
    fi
    if [ -f "$CADDY_MAIN_CONF" ] && grep -q 'Managed by PIKA SH' "$CADDY_MAIN_CONF" 2>/dev/null; then
        rm -f "$CADDY_MAIN_CONF"
    fi
    rm -f "$CADDY_BIN" "$CADDY_WRAPPER"
    pika_info "$(t 'caddy.uninstall.done')"
    return 0
}

# ============================================================
#  Submenu loops
# ============================================================
_caddy_menu_loop() {
    local arr_name="$1" title_key="$2" sel rc total
    local -n _caddy_entries="$arr_name"
    while true; do
        if [ "${PIKA_KEEP_SCREEN:-0}" = "1" ]; then
            printf '\n'
        else
            ui_clear
            ui_header
        fi
        PIKA_KEEP_SCREEN=0
        ui_menu "$(t "$title_key")" "$arr_name" "$(t 'menu.back')"
        read -r sel || return 0
        if ui_is_back "$sel"; then return 0; fi
        case "$sel" in
            ''|*[!0-9]*)
                pika_warn "$(t 'ui.invalid'): $sel"
                sleep 1
                continue
                ;;
        esac
        total=${#_caddy_entries[@]}
        if [ "$sel" -lt 1 ] || [ "$sel" -gt "$total" ]; then
            pika_warn "$(t 'ui.invalid'): $sel"
            sleep 1
            continue
        fi
        rc=0
        ui_dispatch "$arr_name" "$sel" || rc=$?
        if [ "$rc" -eq 2 ]; then
            return 0
        fi
        # Pause only when the action failed; a successful action returns
        # straight to the menu (logs stay on screen).
        if [ "${PIKA_DISPATCH_RC:-0}" -ne 0 ]; then
            PIKA_KEEP_SCREEN=1
            printf '\n  %s ' "$(t 'ui.press_enter')"
            read -r _ || return 0
        fi
    done
}

do_caddy_sites() {
    _caddy_require || return 1
    _caddy_menu_loop "CaddySitesMENU" "caddy.sites.title"
}

do_caddy_certs() {
    _caddy_require || return 1
    _caddy_menu_loop "CaddyCertsMENU" "caddy.certs.title"
}

do_caddy_service() {
    _caddy_require || return 1
    _caddy_menu_loop "CaddyServiceMENU" "caddy.service.title"
}
