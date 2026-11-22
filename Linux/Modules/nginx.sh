#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Nginx Module
#  One-click install, reverse proxy and SSL certificate management.
#
#  Layout:
#    /etc/nginx/conf.d/pika.conf        generated server blocks (managed)
#    /etc/pika-sh/nginx/meta/*.meta     site metadata (key=value)
#    /etc/pika-sh/nginx/certs/<id>/     uploaded / issued certificates
#    /etc/pika-sh/nginx/backups/        config snapshots
#    /var/www/pika-acme/                ACME HTTP-01 webroot
#
#  Requires: core libs (00-core, 10-net, 20-pkg, 30-svc, 40-ui, 50-i18n)
# ============================================================
set -e

# ---- Paths / constants ----
NGINX_BIN=""
NGINX_MAIN_CONF="/etc/nginx/nginx.conf"
NGINX_DATA_DIR="/etc/pika-sh/nginx"
NGINX_META_DIR="${NGINX_DATA_DIR}/meta"
NGINX_CERT_DIR="${NGINX_DATA_DIR}/certs"
NGINX_BACKUP_DIR="${NGINX_DATA_DIR}/backups"
NGINX_RELOAD_SCRIPT="${NGINX_DATA_DIR}/reload.sh"
NGINX_WRAPPER="/usr/local/bin/pika-nginx-daemon.sh"
NGINX_ACME_WEBROOT="/var/www/pika-acme"
NGINX_SITE_IDS=()
NGINX_CERT_IDS=()

# Alpine keeps server snippets in http.d instead of conf.d
if [ "${PIKA_PKG_MGR:-}" = "apk" ]; then
    NGINX_CONF_DIR="/etc/nginx/http.d"
else
    NGINX_CONF_DIR="/etc/nginx/conf.d"
fi
NGINX_SITE_CONF="${NGINX_CONF_DIR}/pika.conf"

# ============================================================
#  Menu data
# ============================================================
NginxMENU=(
    "install|nginx.install|nginx.install.desc|do_nginx_install"
    "sites|nginx.sites|nginx.sites.desc|do_nginx_sites"
    "certs|nginx.certs|nginx.certs.desc|do_nginx_certs"
    "service|nginx.service|nginx.service.desc|do_nginx_service"
    "validate|nginx.validate|nginx.validate.desc|do_nginx_validate_menu"
    "uninstall|nginx.uninstall|nginx.uninstall.desc|do_nginx_uninstall"
)

NginxSitesMENU=(
    "list|nginx.site.list|nginx.site.list.desc|do_nginx_site_list"
    "add|nginx.site.add|nginx.site.add.desc|do_nginx_site_add"
    "del|nginx.site.del|nginx.site.del.desc|do_nginx_site_del"
)

NginxCertsMENU=(
    "list|nginx.cert.list|nginx.cert.list.desc|do_nginx_cert_list"
    "upload|nginx.cert.upload|nginx.cert.upload.desc|do_nginx_cert_upload"
    "acme|nginx.cert.acme|nginx.cert.acme.desc|do_nginx_cert_acme"
    "del|nginx.cert.del|nginx.cert.del.desc|do_nginx_cert_delete"
)

NginxServiceMENU=(
    "status|nginx.svc.status|nginx.svc.status.desc|do_nginx_status"
    "start|nginx.svc.start|nginx.svc.start.desc|do_nginx_start"
    "stop|nginx.svc.stop|nginx.svc.stop.desc|do_nginx_stop"
    "restart|nginx.svc.restart|nginx.svc.restart.desc|do_nginx_restart"
    "reload|nginx.svc.reload|nginx.svc.reload.desc|do_nginx_reload_action"
    "logs|nginx.svc.logs|nginx.svc.logs.desc|do_nginx_logs"
)

# ============================================================
#  Small helpers
# ============================================================
_nginx_bin() {
    if command -v nginx >/dev/null 2>&1; then
        command -v nginx
        return 0
    fi
    if [ -x /usr/sbin/nginx ]; then
        printf '%s' "/usr/sbin/nginx"
        return 0
    fi
    return 1
}

_nginx_require() {
    NGINX_BIN=$(_nginx_bin 2>/dev/null || true)
    if [ -z "$NGINX_BIN" ]; then
        pika_err "$(t 'nginx.not_installed')"
        return 1
    fi
    return 0
}

_nginx_ensure_dirs() {
    mkdir -p "/etc/nginx" "$NGINX_CONF_DIR" "$NGINX_META_DIR" "$NGINX_CERT_DIR" \
        "$NGINX_BACKUP_DIR" "$NGINX_ACME_WEBROOT/.well-known/acme-challenge" 2>/dev/null || true
}

_nginx_slug() {
    local s
    s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9.-]/-/g; s/^[.-]*//; s/[.-]*$//; s/--*/-/g')
    if [ -z "$s" ]; then
        s="site-$(date +%s)"
    fi
    printf '%s' "$s"
}

_nginx_upstream_name() {
    local s
    s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g; s/__*/_/g')
    printf 'pika_%s' "$s"
}

_nginx_has_unit() {
    command -v systemctl >/dev/null 2>&1 && systemctl cat nginx.service >/dev/null 2>&1
}

_nginx_running() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet nginx 2>/dev/null; then
            return 0
        fi
    fi
    pgrep -f 'nginx: master' >/dev/null 2>&1 && return 0
    return 1
}

_nginx_version() {
    local bin
    bin=$(_nginx_bin 2>/dev/null || true)
    [ -n "$bin" ] || return 1
    "$bin" -v 2>&1 | head -1
}

# ---- Meta files (key=value) ----
_nginx_meta_file_get() {
    local f="$1" k="$2"
    [ -f "$f" ] || return 1
    sed -n "s/^${k}=//p" "$f" 2>/dev/null | head -1
}

_nginx_meta_file_set() {
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

_nginx_meta_get() { _nginx_meta_file_get "$(_nginx_meta_path "$1")" "$2"; }
_nginx_meta_set() { _nginx_meta_file_set "$(_nginx_meta_path "$1")" "$2" "$3"; }
_nginx_meta_path() { printf '%s/%s.meta' "$NGINX_META_DIR" "$1"; }

_nginx_global_get() { _nginx_meta_file_get "${NGINX_DATA_DIR}/global.meta" "$1"; }
_nginx_global_set() { _nginx_meta_file_set "${NGINX_DATA_DIR}/global.meta" "$1" "$2"; }

# ---- Backup ----
_nginx_backup() {
    _nginx_ensure_dirs
    local d
    d="${NGINX_BACKUP_DIR}/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$d" 2>/dev/null || true
    if [ -f "$NGINX_SITE_CONF" ]; then
        cp -f "$NGINX_SITE_CONF" "$d/pika.conf" 2>/dev/null || true
    fi
    cp -rf "$NGINX_META_DIR" "$d/meta" 2>/dev/null || true
    printf '%s' "$d"
}

# ---- Wrappers / reload hook ----
_nginx_write_reload_script() {
    mkdir -p "${NGINX_RELOAD_SCRIPT%/*}" 2>/dev/null || true
    local bin
    bin=$(_nginx_bin 2>/dev/null || echo "/usr/sbin/nginx")
    cat > "$NGINX_RELOAD_SCRIPT" <<RELOADEOF
#!/usr/bin/env bash
if "$bin" -t >/dev/null 2>&1; then
    "$bin" -s reload >/dev/null 2>&1 || true
fi
RELOADEOF
    chmod 0755 "$NGINX_RELOAD_SCRIPT"
}

_nginx_write_wrapper() {
    mkdir -p "${NGINX_WRAPPER%/*}" 2>/dev/null || true
    local bin
    bin=$(_nginx_bin 2>/dev/null || echo "/usr/sbin/nginx")
    cat > "$NGINX_WRAPPER" <<WRAPEOF
#!/usr/bin/env bash
exec "$bin" -g 'daemon off;'
WRAPEOF
    chmod 0755 "$NGINX_WRAPPER"
}

# Make sure /etc/nginx/nginx.conf includes our snippet directory
_nginx_ensure_include() {
    [ -f "$NGINX_MAIN_CONF" ] || return 0
    local dir_name
    dir_name="${NGINX_CONF_DIR##*/}"
    if grep -qE "include[[:space:]]+.*${dir_name}/\*\.conf" "$NGINX_MAIN_CONF" 2>/dev/null; then
        return 0
    fi

    local tmp="${NGINX_MAIN_CONF}.pika.tmp"
    awk -v inc="    include ${NGINX_CONF_DIR}/*.conf;" '
        {
            print
            if (!done && $0 ~ /^[[:space:]]*http[[:space:]]*\{/) {
                print "    # PIKA SH managed include"
                print inc
                done = 1
            }
        }
    ' "$NGINX_MAIN_CONF" > "$tmp" 2>/dev/null || true

    if grep -q 'PIKA SH managed include' "$tmp" 2>/dev/null; then
        _nginx_ensure_dirs
        cp -f "$NGINX_MAIN_CONF" "${NGINX_BACKUP_DIR}/nginx.conf.before-pika.$(date +%s)" 2>/dev/null || true
        mv -f "$tmp" "$NGINX_MAIN_CONF"
        pika_info "$(t 'nginx.install.include')"
        return 0
    fi
    rm -f "$tmp" 2>/dev/null || true
    pika_warn "$(t 'nginx.install.include_failed')"
    return 1
}

# ============================================================
#  Rendering / validation
# ============================================================
_nginx_proxy_location() {
    local upname="$1" extra="$2"
    printf '    location / {\n'
    printf '        proxy_pass http://%s;\n' "$upname"
    printf '        proxy_http_version 1.1;\n'
    printf '        proxy_set_header Host $host;\n'
    printf '        proxy_set_header X-Real-IP $remote_addr;\n'
    printf '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n'
    printf '        proxy_set_header X-Forwarded-Proto $scheme;\n'
    printf '        proxy_set_header Upgrade $http_upgrade;\n'
    printf '        proxy_set_header Connection $pika_connection_upgrade;\n'
    if [ -n "$extra" ]; then
        case "$extra" in
            *';'|*'{'|*'}') printf '        %s\n' "$extra" ;;
            *)               printf '        %s;\n' "$extra" ;;
        esac
    fi
    printf '    }\n'
}

_nginx_render_site() {
    local id="$1"
    local domains upstreams tls_mode cert key extra d u upname server_names
    domains=$(_nginx_meta_get "$id" "domains" 2>/dev/null || true)
    upstreams=$(_nginx_meta_get "$id" "upstreams" 2>/dev/null || true)
    tls_mode=$(_nginx_meta_get "$id" "tls_mode" 2>/dev/null || true)
    cert=$(_nginx_meta_get "$id" "cert" 2>/dev/null || true)
    key=$(_nginx_meta_get "$id" "key" 2>/dev/null || true)
    extra=$(_nginx_meta_get "$id" "extra" 2>/dev/null || true)
    upname=$(_nginx_upstream_name "$id")

    server_names=""
    local _ng=0
    case $- in *f*) _ng=1 ;; *) set -f ;; esac
    for d in $(printf '%s' "$domains" | tr ',' ' '); do
        server_names="${server_names} ${d}"
    done
    [ "$_ng" = "1" ] || set +f

    printf '# ---- site: %s ----\n' "$id"
    printf 'upstream %s {\n' "$upname"
    for u in $(printf '%s' "$upstreams" | tr ',' ' '); do
        printf '    server %s;\n' "$u"
    done
    printf '}\n\n'

    local use_tls=0
    if [ -n "$cert" ] && [ -n "$key" ] && [ -f "$cert" ] && [ -f "$key" ]; then
        case "$tls_mode" in
            auto|manual) use_tls=1 ;;
        esac
    fi

    # ---- port 80 ----
    printf 'server {\n'
    printf '    listen 80;\n'
    printf '    server_name%s;\n' "$server_names"
    printf '    location ^~ /.well-known/acme-challenge/ {\n'
    printf '        root %s;\n' "$NGINX_ACME_WEBROOT"
    printf '    }\n'
    if [ "$use_tls" = "1" ]; then
        printf '    location / {\n'
        printf '        return 301 https://$host$request_uri;\n'
        printf '    }\n'
    else
        _nginx_proxy_location "$upname" "$extra"
    fi
    printf '}\n\n'

    # ---- port 443 ----
    if [ "$use_tls" = "1" ]; then
        printf 'server {\n'
        printf '    listen 443 ssl;\n'
        printf '    server_name%s;\n' "$server_names"
        printf '    ssl_certificate %s;\n' "$cert"
        printf '    ssl_certificate_key %s;\n' "$key"
        printf '    ssl_protocols TLSv1.2 TLSv1.3;\n'
        _nginx_proxy_location "$upname" "$extra"
        printf '}\n\n'
    fi
}

_nginx_render_all() {
    _nginx_ensure_dirs
    local tmp="${NGINX_SITE_CONF}.tmp" id
    {
        printf '# Managed by PIKA SH (pikash) - generated file, do not edit manually.\n'
        printf '# Site metadata: %s\n\n' "$NGINX_META_DIR"
        printf 'map $http_upgrade $pika_connection_upgrade {\n'
        printf '    default upgrade;\n'
        printf "    ''      close;\n"
        printf '}\n\n'
    } > "$tmp"

    if _nginx_collect_sites; then
        for id in "${NGINX_SITE_IDS[@]}"; do
            _nginx_render_site "$id" >> "$tmp"
        done
    fi

    mv -f "$tmp" "$NGINX_SITE_CONF"
    return 0
}

_nginx_validate() {
    local out
    if out=$("$NGINX_BIN" -t 2>&1); then
        return 0
    fi
    pika_err "$(t 'nginx.config.invalid')"
    printf '%s\n' "$out" >&2
    return 1
}

_nginx_start_if_needed() {
    if _nginx_has_unit; then
        systemctl enable nginx >/dev/null 2>&1 || true
        systemctl start nginx >/dev/null 2>&1 || true
    else
        svc_start nginx || true
    fi
}

_nginx_apply() {
    _nginx_validate || return 1
    if _nginx_running; then
        if ! "$NGINX_BIN" -s reload 2>&1; then
            pika_warn "$(t 'nginx.reload.failed')"
            if _nginx_has_unit; then
                systemctl reload nginx >/dev/null 2>&1 || true
            else
                svc_restart nginx || true
            fi
        fi
    else
        _nginx_start_if_needed
        sleep 1
        if ! _nginx_running; then
            pika_warn "$(t 'nginx.svc.stopped')"
            pika_info "$(t 'nginx.svc.hint')"
        fi
    fi
    return 0
}

# ============================================================
#  Install / upgrade
# ============================================================
do_nginx_install() {
    ui_confirm_install "Nginx" "$(t 'nginx.install.desc')" || { pika_info "$(t 'ui.cancelled')"; return 0; }

    if ! _nginx_bin >/dev/null 2>&1; then
        pika_info "$(t 'state.installing') Nginx..."
        if ! pkg_install nginx; then
            pika_err "$(t 'nginx.install.failed')"
            return 1
        fi
    fi

    if ! _nginx_require; then
        return 1
    fi

    _nginx_ensure_dirs
    _nginx_ensure_include || true
    _nginx_write_reload_script
    _nginx_render_all || return 1
    if ! _nginx_validate; then
        pika_err "$(t 'nginx.install.failed')"
        return 1
    fi

    if _nginx_has_unit; then
        systemctl enable nginx >/dev/null 2>&1 || true
        systemctl restart nginx >/dev/null 2>&1 || systemctl start nginx >/dev/null 2>&1 || true
    else
        _nginx_write_wrapper
        if ! svc_register --name "nginx" --exec "$NGINX_WRAPPER" --workdir "/etc/nginx" \
            --autostart --desc "Nginx (PIKA SH)"; then
            pika_err "$(t 'nginx.install.failed')"
            return 1
        fi
        svc_restart nginx || true
    fi

    sleep 1
    if _nginx_running; then
        pika_info "$(t 'nginx.install.done'): $(_nginx_version 2>/dev/null || echo '?')"
    else
        pika_warn "$(t 'nginx.svc.stopped')"
        pika_info "$(t 'nginx.install.hint')"
    fi

    if declare -F _rp_backend_set >/dev/null 2>&1; then
        _rp_backend_set nginx
    fi
    printf '  %s: %s\n' "$(t 'nginx.svc.config')" "$NGINX_SITE_CONF"
    printf '  %s: %s\n' "$(t 'nginx.svc.bin')" "$NGINX_BIN"
    return 0
}

# ============================================================
#  Site table / selection
# ============================================================
_nginx_collect_sites() {
    NGINX_SITE_IDS=()
    local f b
    for f in "${NGINX_META_DIR}"/*.meta; do
        [ -f "$f" ] || continue
        b="${f##*/}"
        NGINX_SITE_IDS+=("${b%.meta}")
    done
    [ ${#NGINX_SITE_IDS[@]} -gt 0 ]
}

_nginx_print_sites() {
    if ! _nginx_collect_sites; then
        pika_info "$(t 'nginx.site.none')"
        return 1
    fi
    printf '\n  %-4s %s %s %s\n' \
        "#" \
        "$(_ui_str_pad "$(t 'nginx.site.domains')" 30)" \
        "$(_ui_str_pad "$(t 'nginx.site.upstream')" 34)" \
        "$(t 'nginx.site.tls')"
    local i=1 id d u m
    for id in "${NGINX_SITE_IDS[@]}"; do
        d=$(_nginx_meta_get "$id" "domains" 2>/dev/null || true)
        u=$(_nginx_meta_get "$id" "upstreams" 2>/dev/null || true)
        m=$(_nginx_meta_get "$id" "tls_mode" 2>/dev/null || true)
        printf '  %-4s %s %s %s\n' \
            "[$i]" "$(_ui_str_pad "$d" 30)" "$(_ui_str_pad "$u" 34)" "${m:-off}"
        i=$((i + 1))
    done
    return 0
}

_nginx_pick_site() {
    _nginx_print_sites >&2 || return 1
    local n total="${#NGINX_SITE_IDS[@]}"
    read -r -p "  $(t 'nginx.site.select') [1-${total}]: " n || return 1
    case "$n" in
        ''|*[!0-9]*) return 1 ;;
    esac
    if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        return 1
    fi
    printf '%s' "${NGINX_SITE_IDS[$((n - 1))]}"
}

# ============================================================
#  Site add / list / delete
# ============================================================
_nginx_clean_domains() {
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

_nginx_clean_upstreams() {
    local raw out="" u
    raw=$(printf '%s' "$1" | tr ',' ' ')
    for u in $raw; do
        u="${u#http://}"
        u="${u#https://}"
        u="${u%%/*}"
        if [ -z "$u" ]; then
            continue
        fi
        case "$u" in
            *[!A-Za-z0-9._:-]*) return 1 ;;
        esac
        out="${out}${out:+,}${u}"
    done
    [ -n "$out" ] || return 1
    printf '%s' "$out"
}

_nginx_selfsigned() {
    local id="$1" domains="$2" dir first san d
    dir="${NGINX_CERT_DIR}/${id}"
    mkdir -p "$dir"
    first=$(printf '%s' "$domains" | cut -d, -f1)
    san=""
    for d in $(printf '%s' "$domains" | tr ',' ' '); do
        san="${san}${san:+,}DNS:${d}"
    done

    if openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
        -keyout "${dir}/key.pem" -out "${dir}/cert.pem" \
        -subj "/CN=${first}" -addext "subjectAltName=${san}" >/dev/null 2>&1; then
        :
    else
        cat > "${dir}/openssl.cnf" <<CNF
[req]
distinguished_name=dn
x509_extensions=v3
prompt=no
[dn]
CN=${first}
[v3]
subjectAltName=${san}
CNF
        if ! openssl req -x509 -newkey rsa:2048 -nodes -days 825 \
            -keyout "${dir}/key.pem" -out "${dir}/cert.pem" \
            -config "${dir}/openssl.cnf" >/dev/null 2>&1; then
            rm -rf "$dir"
            return 1
        fi
        rm -f "${dir}/openssl.cnf"
    fi

    chmod 600 "${dir}/cert.pem" "${dir}/key.pem" 2>/dev/null || true
    _nginx_meta_file_set "${dir}/meta" "domains" "$domains"
    _nginx_meta_file_set "${dir}/meta" "source" "selfsigned"
    _nginx_meta_file_set "${dir}/meta" "created" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    return 0
}

do_nginx_site_add() {
    _nginx_require || return 1
    _nginx_ensure_dirs
    _nginx_ensure_include || true

    local domains_raw domains upstreams tls_choice tls_mode cert_id extra id email
    read -r -p "  $(t 'nginx.site.domain'): " domains_raw || return 1
    if [ -z "$domains_raw" ]; then
        pika_err "$(t 'nginx.site.empty')"
        return 1
    fi
    if ! domains=$(_nginx_clean_domains "$domains_raw"); then
        pika_err "$(t 'nginx.site.invalid')"
        return 1
    fi

    read -r -p "  $(t 'nginx.site.upstream') [http://127.0.0.1:8080]: " upstreams || return 1
    upstreams="${upstreams:-http://127.0.0.1:8080}"
    if ! upstreams=$(_nginx_clean_upstreams "$upstreams"); then
        pika_err "$(t 'nginx.site.invalid')"
        return 1
    fi

    printf '\n  1) %s\n  2) %s\n  3) %s\n  4) %s\n' \
        "$(t 'nginx.tls.auto')" "$(t 'nginx.tls.manual')" \
        "$(t 'nginx.tls.internal')" "$(t 'nginx.tls.off')"
    read -r -p "  $(t 'nginx.site.tls') [1-4, default 1]: " tls_choice || return 1
    tls_choice="${tls_choice:-1}"

    tls_mode="off"
    cert_id=""
    case "$tls_choice" in
        1)
            case "$domains" in
                *\**)
                    pika_err "$(t 'nginx.tls.auto.wildcard')"
                    return 1
                    ;;
            esac
            tls_mode="auto"
            if ! email=$(_nginx_auto_email); then
                return 1
            fi
            ;;
        2)
            tls_mode="manual"
            if _nginx_collect_certs; then
                if ! cert_id=$(_nginx_pick_cert); then
                    pika_info "$(t 'ui.cancelled')"
                    return 1
                fi
            else
                pika_info "$(t 'nginx.cert.none')"
                if ! cert_id=$(_nginx_cert_import_flow); then
                    pika_info "$(t 'ui.cancelled')"
                    return 1
                fi
            fi
            ;;
        3) tls_mode="internal" ;;
        *) tls_mode="off" ;;
    esac

    read -r -p "  $(t 'nginx.site.extra'): " extra || extra=""

    id=$(_nginx_slug "${domains%%,*}")
    if [ -f "$(_nginx_meta_path "$id")" ]; then
        pika_err "$(t 'nginx.site.exists'): $id"
        return 1
    fi

    if [ "$tls_mode" = "internal" ]; then
        if ! _nginx_selfsigned "$id" "$domains"; then
            pika_err "$(t 'nginx.tls.internal.failed')"
            return 1
        fi
        tls_mode="manual"
        cert_id="$id"
    fi

    _nginx_backup >/dev/null 2>&1 || true
    _nginx_meta_set "$id" "domains" "$domains"
    _nginx_meta_set "$id" "upstreams" "$upstreams"
    _nginx_meta_set "$id" "tls_mode" "$tls_mode"
    _nginx_meta_set "$id" "extra" "$extra"
    _nginx_meta_set "$id" "created" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ -n "$cert_id" ]; then
        _nginx_meta_set "$id" "cert" "${NGINX_CERT_DIR}/${cert_id}/cert.pem"
        _nginx_meta_set "$id" "key" "${NGINX_CERT_DIR}/${cert_id}/key.pem"
    fi

    _nginx_render_all
    if ! _nginx_apply; then
        rm -f "$(_nginx_meta_path "$id")"
        _nginx_render_all
        _nginx_apply >/dev/null 2>&1 || true
        return 1
    fi

    pika_info "$(t 'nginx.site.added'): $domains -> $upstreams"

    # Automatic HTTPS via acme.sh HTTP-01 (needs port 80)
    if [ "$tls_mode" = "auto" ]; then
        if _nginx_acme_auto "$id" "$domains" "$email"; then
            pika_info "$(t 'nginx.auto.success')"
        else
            pika_warn "$(t 'nginx.auto.failed')"
            _nginx_meta_set "$id" "tls_mode" "off"
            _nginx_render_all
            _nginx_apply >/dev/null 2>&1 || true
        fi
    fi
    return 0
}

do_nginx_site_list() {
    _nginx_require || return 1
    _nginx_print_sites || return 0
    printf '\n  %s: %s\n' "$(t 'nginx.site.dir')" "$NGINX_SITE_CONF"
    return 0
}

do_nginx_site_del() {
    _nginx_require || return 1
    local id
    if ! id=$(_nginx_pick_site); then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    if ! pika_confirm "$(t 'nginx.site.confirm_delete') [$id]"; then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    _nginx_backup >/dev/null 2>&1 || true
    rm -f "$(_nginx_meta_path "$id")"
    pika_info "$(t 'nginx.site.deleted'): $id"
    _nginx_render_all
    _nginx_apply || true
    return 0
}

# ============================================================
#  Certificate helpers
# ============================================================
_nginx_collect_certs() {
    NGINX_CERT_IDS=()
    local d id
    for d in "${NGINX_CERT_DIR}"/*/; do
        [ -d "$d" ] || continue
        [ -f "${d}cert.pem" ] || continue
        d="${d%/}"
        id="${d##*/}"
        NGINX_CERT_IDS+=("$id")
    done
    [ ${#NGINX_CERT_IDS[@]} -gt 0 ]
}

_nginx_cert_expiry() {
    openssl x509 -in "$1" -noout -enddate 2>/dev/null | sed 's/^notAfter=//' || true
}

_nginx_cert_domains() {
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

_nginx_cert_pair_ok() {
    local c="$1" k="$2" pc pk
    if ! command -v openssl >/dev/null 2>&1; then
        pika_warn "$(t 'nginx.cert.noopenssl')"
        return 0
    fi
    pc=$(openssl x509 -in "$c" -noout -pubkey 2>/dev/null | openssl sha256 2>/dev/null || true)
    pk=$(openssl pkey -in "$k" -pubout 2>/dev/null | openssl sha256 2>/dev/null || true)
    if [ -z "$pc" ] || [ -z "$pk" ]; then
        return 1
    fi
    [ "$pc" = "$pk" ]
}

_nginx_pick_cert() {
    _nginx_print_certs >&2 || return 1
    local n total="${#NGINX_CERT_IDS[@]}"
    read -r -p "  $(t 'nginx.cert.select') [1-${total}]: " n || return 1
    case "$n" in
        ''|*[!0-9]*) return 1 ;;
    esac
    if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
        return 1
    fi
    printf '%s' "${NGINX_CERT_IDS[$((n - 1))]}"
}

_nginx_cert_import_flow() {
    local c k id dir d
    read -r -p "  $(t 'nginx.cert.certpath'): " c || return 1
    read -r -p "  $(t 'nginx.cert.keypath'): " k || return 1
    c="${c%\"}"; c="${c#\"}"
    k="${k%\"}"; k="${k#\"}"

    if [ ! -f "$c" ]; then
        pika_err "$(t 'nginx.cert.missing'): $c"
        return 1
    fi
    if [ ! -f "$k" ]; then
        pika_err "$(t 'nginx.cert.missing'): $k"
        return 1
    fi
    if ! _nginx_cert_pair_ok "$c" "$k"; then
        pika_err "$(t 'nginx.cert.pairinvalid')"
        return 1
    fi

    d=$(_nginx_cert_domains "$c")
    [ -z "$d" ] && d=$(basename "${c%.*}")
    id=$(_nginx_slug "${d%%,*}")
    dir="${NGINX_CERT_DIR}/${id}"
    if [ -d "$dir" ]; then
        id="${id}-$(date +%s)"
        dir="${NGINX_CERT_DIR}/${id}"
    fi

    mkdir -p "$dir"
    cp -f "$c" "${dir}/cert.pem"
    cp -f "$k" "${dir}/key.pem"
    chmod 600 "${dir}/cert.pem" "${dir}/key.pem"
    _nginx_meta_file_set "${dir}/meta" "domains" "$d"
    _nginx_meta_file_set "${dir}/meta" "source" "upload"
    _nginx_meta_file_set "${dir}/meta" "created" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s' "$id"
}

_nginx_print_certs() {
    local i=1 id d e
    if ! _nginx_collect_certs; then
        pika_info "$(t 'nginx.cert.none')"
        return 1
    fi
    printf '\n  %s\n' "$(t 'nginx.cert.list.title')"
    for id in "${NGINX_CERT_IDS[@]}"; do
        d=$(_nginx_meta_file_get "${NGINX_CERT_DIR}/${id}/meta" "domains" 2>/dev/null || true)
        [ -z "$d" ] && d="$id"
        e=$(_nginx_cert_expiry "${NGINX_CERT_DIR}/${id}/cert.pem")
        printf '  %-4s %s %s\n' \
            "[$i]" "$(_ui_str_pad "$d" 34)" "$(t 'nginx.cert.expire'): ${e:-?}"
        i=$((i + 1))
    done
    return 0
}

_nginx_bind_cert_to_site() {
    local cert_id="$1" id
    if ! _nginx_collect_sites; then
        pika_info "$(t 'nginx.site.none')"
        return 1
    fi
    if ! id=$(_nginx_pick_site); then
        return 1
    fi
    _nginx_meta_set "$id" "tls_mode" "manual"
    _nginx_meta_set "$id" "cert" "${NGINX_CERT_DIR}/${cert_id}/cert.pem"
    _nginx_meta_set "$id" "key" "${NGINX_CERT_DIR}/${cert_id}/key.pem"
    _nginx_render_all
    if _nginx_apply; then
        pika_info "$(t 'nginx.cert.bound'): $id"
        return 0
    fi
    _nginx_meta_set "$id" "tls_mode" "off"
    _nginx_meta_set "$id" "cert" ""
    _nginx_meta_set "$id" "key" ""
    _nginx_render_all
    _nginx_apply >/dev/null 2>&1 || true
    return 1
}

do_nginx_cert_list() {
    _nginx_require || return 1
    _nginx_print_certs || true
    printf '\n  %s: %s\n' "$(t 'nginx.cert.dir')" "$NGINX_CERT_DIR"
    return 0
}

do_nginx_cert_upload() {
    _nginx_require || return 1
    _nginx_ensure_dirs
    local id
    if ! id=$(_nginx_cert_import_flow); then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    pika_info "$(t 'nginx.cert.uploaded'): $id"
    if pika_confirm "$(t 'nginx.cert.bind')"; then
        _nginx_bind_cert_to_site "$id" || true
    fi
    return 0
}

do_nginx_cert_delete() {
    _nginx_require || return 1
    if ! _nginx_collect_certs; then
        pika_info "$(t 'nginx.cert.none')"
        return 0
    fi
    local id
    if ! id=$(_nginx_pick_cert); then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    if grep -rq "${NGINX_CERT_DIR}/${id}/" "$NGINX_META_DIR" 2>/dev/null; then
        pika_err "$(t 'nginx.cert.inuse')"
        return 1
    fi
    if ! pika_confirm "$(t 'nginx.cert.confirm_delete') [$id]"; then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    rm -rf "${NGINX_CERT_DIR:?}/${id}"
    pika_info "$(t 'nginx.cert.deleted'): $id"
    return 0
}

# ============================================================
#  ACME (acme.sh)
# ============================================================
_nginx_acme_bin() {
    if [ -x "${HOME}/.acme.sh/acme.sh" ]; then
        printf '%s' "${HOME}/.acme.sh/acme.sh"
        return 0
    fi
    return 1
}

_nginx_acme_ensure() {
    local email="$1"
    if _nginx_acme_bin >/dev/null 2>&1; then
        return 0
    fi
    pika_info "$(t 'nginx.cert.acme.installing')"
    if ! pika_fetch "https://get.acme.sh" -o "/tmp/pika-acme-$$.sh" --no-cache --max-time 90; then
        pika_err "$(t 'nginx.cert.acme.installfailed')"
        return 1
    fi
    if ! sh /tmp/pika-acme-$$.sh email="$email" >/dev/null 2>&1; then
        rm -f /tmp/pika-acme-$$.sh
        pika_err "$(t 'nginx.cert.acme.installfailed')"
        return 1
    fi
    rm -f /tmp/pika-acme-$$.sh
    _nginx_acme_bin >/dev/null 2>&1
}

_nginx_acme_ca_flag() {
    case "$1" in
        2) printf '%s' "zerossl" ;;
        3) printf '%s' "buypass" ;;
        *) printf '%s' "letsencrypt" ;;
    esac
}

_nginx_auto_email() {
    local email
    email=$(_nginx_global_get "email" 2>/dev/null || true)
    if [ -z "$email" ]; then
        read -r -p "  $(t 'nginx.cert.acme.email'): " email || return 1
        if [ -z "$email" ]; then
            pika_err "$(t 'nginx.cert.acme.emailrequired')"
            return 1
        fi
        _nginx_ensure_dirs
        _nginx_global_set "email" "$email"
    fi
    printf '%s' "$email"
}

# Issue + install a certificate for an existing site (HTTP-01 webroot)
_nginx_acme_auto() {
    local id="$1" domains="$2" email="$3" acme first dir d
    if ! _nginx_acme_ensure "$email"; then
        return 1
    fi
    acme=$(_nginx_acme_bin)

    mkdir -p "${NGINX_ACME_WEBROOT}/.well-known/acme-challenge"

    local dargs=()
    for d in $(printf '%s' "$domains" | tr ',' ' '); do
        dargs+=(-d "$d")
    done

    pika_info "$(t 'nginx.auto.issuing')"
    if ! "$acme" --issue --webroot "$NGINX_ACME_WEBROOT" "${dargs[@]}" \
        --server letsencrypt -m "$email"; then
        return 1
    fi

    first=$(printf '%s' "$domains" | cut -d, -f1)
    dir="${NGINX_CERT_DIR}/${id}"
    mkdir -p "$dir"
    if ! "$acme" --install-cert -d "$first" \
        --key-file "${dir}/key.pem" \
        --fullchain-file "${dir}/cert.pem" \
        --reloadcmd "$NGINX_RELOAD_SCRIPT"; then
        return 1
    fi
    chmod 600 "${dir}/cert.pem" "${dir}/key.pem" 2>/dev/null || true
    _nginx_meta_file_set "${dir}/meta" "domains" "$domains"
    _nginx_meta_file_set "${dir}/meta" "source" "acme"
    _nginx_meta_file_set "${dir}/meta" "created" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    _nginx_meta_set "$id" "tls_mode" "auto"
    _nginx_meta_set "$id" "cert" "${dir}/cert.pem"
    _nginx_meta_set "$id" "key" "${dir}/key.pem"
    _nginx_render_all
    _nginx_apply || return 1
    return 0
}

do_nginx_cert_acme() {
    _nginx_require || return 1
    _nginx_ensure_dirs

    local domain email ca method webroot acme
    read -r -p "  $(t 'nginx.cert.acme.domain'): " domain || return 1
    if ! domain=$(_nginx_clean_domains "$domain"); then
        pika_err "$(t 'nginx.site.invalid')"
        return 1
    fi
    case "$domain" in
        *,*) pika_err "$(t 'nginx.cert.acme.single')"; return 1 ;;
    esac

    read -r -p "  $(t 'nginx.cert.acme.email'): " email || email=""
    if [ -z "$email" ]; then
        pika_err "$(t 'nginx.cert.acme.emailrequired')"
        return 1
    fi

    printf "\n  1) Let's Encrypt\n  2) ZeroSSL\n  3) Buypass\n"
    read -r -p "  $(t 'nginx.cert.acme.ca') [1-3, default 1]: " ca || ca="1"
    ca="${ca:-1}"

    printf '\n  1) %s\n  2) %s\n  3) %s\n  4) %s\n' \
        "$(t 'nginx.cert.acme.webroot')" "$(t 'nginx.cert.acme.standalone')" \
        "$(t 'nginx.cert.acme.alpn')" "$(t 'nginx.cert.acme.dns')"
    read -r -p "  $(t 'nginx.cert.acme.method') [1-4, default 1]: " method || method="1"
    method="${method:-1}"

    if ! _nginx_acme_ensure "$email"; then
        return 1
    fi
    acme=$(_nginx_acme_bin)
    chmod +x "$acme" 2>/dev/null || true

    local ca_name
    ca_name=$(_nginx_acme_ca_flag "$ca")

    case "$method" in
        2)
            mkdir -p "${NGINX_ACME_WEBROOT}/.well-known/acme-challenge"
            if ! "$acme" --issue --standalone -d "$domain" --server "$ca_name" -m "$email"; then
                pika_err "$(t 'nginx.cert.acme.failed')"
                pika_info "$(t 'nginx.cert.acme.standalonehint')"
                return 1
            fi
            ;;
        3)
            if ! "$acme" --issue --alpn -d "$domain" --server "$ca_name" -m "$email"; then
                pika_err "$(t 'nginx.cert.acme.failed')"
                return 1
            fi
            ;;
        4)
            "$acme" --issue --dns -d "$domain" --server "$ca_name" -m "$email" \
                --yes-I-know-dns-manual-mode-enough-go-ahead-please || true
            pika_info "$(t 'nginx.cert.acme.dnshint')"
            read -r -p "  $(t 'ui.press_enter')" _ || true
            if ! "$acme" --renew -d "$domain" --yes-I-know-dns-manual-mode-enough-go-ahead-please; then
                pika_err "$(t 'nginx.cert.acme.failed')"
                return 1
            fi
            pika_warn "$(t 'nginx.cert.acme.manualrenew')"
            ;;
        *)
            read -r -p "  $(t 'nginx.cert.acme.webrootpath') [${NGINX_ACME_WEBROOT}]: " webroot || webroot=""
            webroot="${webroot:-$NGINX_ACME_WEBROOT}"
            mkdir -p "${webroot}/.well-known/acme-challenge" 2>/dev/null || true
            if [ ! -d "$webroot" ]; then
                pika_err "$(t 'nginx.cert.missing'): $webroot"
                return 1
            fi
            if ! "$acme" --issue --webroot "$webroot" -d "$domain" --server "$ca_name" -m "$email"; then
                pika_err "$(t 'nginx.cert.acme.failed')"
                return 1
            fi
            ;;
    esac

    local id dir
    id=$(_nginx_slug "$domain")
    dir="${NGINX_CERT_DIR}/${id}"
    mkdir -p "$dir"
    _nginx_write_reload_script
    if ! "$acme" --install-cert -d "$domain" \
        --key-file "${dir}/key.pem" \
        --fullchain-file "${dir}/cert.pem" \
        --reloadcmd "$NGINX_RELOAD_SCRIPT"; then
        pika_err "$(t 'nginx.cert.acme.failed')"
        return 1
    fi
    chmod 600 "${dir}/cert.pem" "${dir}/key.pem" 2>/dev/null || true
    _nginx_meta_file_set "${dir}/meta" "domains" "$domain"
    _nginx_meta_file_set "${dir}/meta" "source" "acme"
    _nginx_meta_file_set "${dir}/meta" "created" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    pika_info "$(t 'nginx.cert.acme.success'): $id"
    if pika_confirm "$(t 'nginx.cert.bind')"; then
        _nginx_bind_cert_to_site "$id" || true
    fi
    return 0
}

# ============================================================
#  Service / config actions
# ============================================================
do_nginx_status() {
    _nginx_require || return 0
    local ver state sites certs
    ver=$(_nginx_version 2>/dev/null || echo "?")
    if _nginx_running; then
        state="$(t 'nginx.svc.running')"
    else
        state="$(t 'nginx.svc.stopped')"
    fi
    sites=0
    if _nginx_collect_sites; then
        sites=${#NGINX_SITE_IDS[@]}
    fi
    certs=0
    if _nginx_collect_certs; then
        certs=${#NGINX_CERT_IDS[@]}
    fi

    printf '\n'
    printf '  %s: %s\n' "$(t 'nginx.svc.version')" "$ver"
    printf '  %s: %s\n' "$(t 'nginx.svc.state')" "$state"
    printf '  %s: %s\n' "$(t 'nginx.svc.name')" "nginx"
    printf '  %s: %s\n' "$(t 'nginx.svc.backend')" "$(svc_backend 2>/dev/null || echo '?')"
    printf '  %s: %s\n' "$(t 'nginx.svc.sites')" "$sites"
    printf '  %s: %s\n' "$(t 'nginx.svc.certs')" "$certs"
    printf '  %s: %s\n' "$(t 'nginx.svc.config')" "$NGINX_SITE_CONF"
    printf '  %s: %s\n' "$(t 'nginx.svc.bin')" "$NGINX_BIN"
    printf '\n'
    return 0
}

do_nginx_start() {
    _nginx_require || return 1
    _nginx_start_if_needed
    sleep 1
    if _nginx_running; then
        pika_info "$(t 'nginx.started')"
        return 0
    fi
    pika_err "$(t 'nginx.svc.stopped')"
    return 1
}

do_nginx_stop() {
    _nginx_require || return 1
    if _nginx_has_unit; then
        systemctl stop nginx 2>/dev/null || true
    else
        "$NGINX_BIN" -s stop 2>/dev/null || svc_stop nginx || true
    fi
    pika_info "$(t 'nginx.stopped')"
    return 0
}

do_nginx_restart() {
    _nginx_require || return 1
    if _nginx_has_unit; then
        systemctl restart nginx 2>/dev/null || true
    else
        svc_restart nginx || true
    fi
    sleep 1
    if _nginx_running; then
        pika_info "$(t 'nginx.restarted')"
        return 0
    fi
    pika_err "$(t 'nginx.svc.stopped')"
    return 1
}

do_nginx_reload_action() {
    _nginx_require || return 1
    _nginx_render_all
    if _nginx_apply; then
        pika_info "$(t 'nginx.reload.ok')"
        return 0
    fi
    return 1
}

do_nginx_logs() {
    _nginx_require || return 1
    PIKA_KEEP_SCREEN=1
    if [ -f /var/log/nginx/error.log ]; then
        tail -n 80 /var/log/nginx/error.log 2>/dev/null || true
    elif _nginx_has_unit; then
        journalctl -u nginx -n 80 --no-pager 2>/dev/null || true
    else
        svc_logs nginx 80 || true
    fi
    return 0
}

do_nginx_validate_menu() {
    _nginx_require || return 1
    _nginx_render_all
    if _nginx_validate; then
        pika_info "$(t 'nginx.config.ok')"
        return 0
    fi
    return 1
}

# ============================================================
#  Uninstall
# ============================================================
do_nginx_uninstall() {
    if ! pika_confirm "$(t 'nginx.uninstall.confirm')"; then
        pika_info "$(t 'ui.cancelled')"
        return 0
    fi
    local keep=0
    if _nginx_has_unit; then
        systemctl stop nginx 2>/dev/null || true
        systemctl disable nginx 2>/dev/null || true
    else
        if _nginx_bin >/dev/null 2>&1; then
            "$(_nginx_bin)" -s stop 2>/dev/null || true
        fi
        svc_remove nginx >/dev/null 2>&1 || true
    fi

    if pika_confirm "$(t 'nginx.uninstall.keepcerts')"; then
        keep=1
    fi
    rm -f "$NGINX_SITE_CONF" "$NGINX_RELOAD_SCRIPT" "$NGINX_WRAPPER"
    rm -rf "$NGINX_META_DIR" "$NGINX_BACKUP_DIR"
    if [ "$keep" != "1" ]; then
        rm -rf "$NGINX_CERT_DIR"
    fi
    rm -f "${NGINX_DATA_DIR}/global.meta"
    rmdir "$NGINX_DATA_DIR" 2>/dev/null || true

    if declare -F _rp_backend_get >/dev/null 2>&1; then
        if [ "$(_rp_backend_get)" = "nginx" ]; then
            _rp_backend_set none
        fi
    fi
    pika_info "$(t 'nginx.uninstall.done')"
    return 0
}

# ============================================================
#  Submenu loops
# ============================================================
_nginx_menu_loop() {
    local arr_name="$1" title_key="$2" sel rc total
    local -n _nginx_entries="$arr_name"
    while true; do
        if [ "${PIKA_KEEP_SCREEN:-0}" = "1" ]; then
            printf '\n'
        else
            ui_clear
            ui_header
        fi
        PIKA_KEEP_SCREEN=0
        ui_divider
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
        total=${#_nginx_entries[@]}
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

do_nginx_sites() {
    _nginx_require || return 1
    _nginx_menu_loop "NginxSitesMENU" "nginx.sites.title"
}

do_nginx_certs() {
    _nginx_require || return 1
    _nginx_menu_loop "NginxCertsMENU" "nginx.certs.title"
}

do_nginx_service() {
    _nginx_require || return 1
    _nginx_menu_loop "NginxServiceMENU" "nginx.service.title"
}
