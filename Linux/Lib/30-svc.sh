#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Service Management Abstraction
#  Backend: PM2 (preferred) > systemd > nohup (fallback)
#  Requires: 00-core.sh, 20-pkg.sh loaded first
# ============================================================
set -e

# ---- Service backend detection ----
PIKA_SVC_CONFIG="${PIKA_CONFIG_DIR}/config"
PIKA_SVC_BACKEND=""

svc_detect_backend() {
    # 1. Explicit user choice via env
    case "${PIKA_SVC_BACKEND_MODE:-auto}" in
        pm2)     echo "pm2"; return ;;
        systemd) echo "systemd"; return ;;
        nohup)   echo "nohup"; return ;;
    esac

    # 2. Persisted config
    local persisted
    persisted=$(pika_config_get "service_backend" 2>/dev/null || true)
    case "$persisted" in
        pm2|systemd|nohup) echo "$persisted"; return ;;
    esac

    # 3. Auto-detect: PM2 first, then systemd, then nohup
    if command -v pm2 >/dev/null 2>&1; then
        echo "pm2"; return
    fi

    if pika_has_systemd; then
        echo "systemd"; return
    fi

    # Containers without systemd: PM2 if node available, else nohup
    if command -v node >/dev/null 2>&1; then
        echo "pm2"; return
    fi

    echo "nohup"
}

svc_backend() {
    # Must always print the backend: callers use $(svc_backend), which runs in
    # a subshell, so caching into the global alone would return an empty string
    # and every case dispatch below silently matched nothing.
    if [ -z "${PIKA_SVC_BACKEND:-}" ]; then
        PIKA_SVC_BACKEND=$(svc_detect_backend)
        export PIKA_SVC_BACKEND
    fi
    printf '%s\n' "$PIKA_SVC_BACKEND"
}

# ---- Interactive backend selection ----
svc_choose_backend() {
    local choice
    echo ""
    echo "  选择服务托管方式:"
    echo "    1) PM2 (推荐 - Node.js 进程管理器，功能最全)"
    echo "    2) systemd (系统原生服务管理器)"
    echo "    3) 自动 (PM2优先 > systemd > nohup)"
    echo ""
    read -r -p "  请选择 (1-3, 默认自动): " choice

    case "${choice:-3}" in
        1) PIKA_SVC_BACKEND_MODE="pm2"; pika_config_set "service_backend" "pm2" ;;
        2) PIKA_SVC_BACKEND_MODE="systemd"; pika_config_set "service_backend" "systemd" ;;
        *) PIKA_SVC_BACKEND_MODE="auto"; pika_config_set "service_backend" "auto" ;;
    esac
    PIKA_SVC_BACKEND=""
    pika_info "服务托管方式: $(svc_backend)"
}

# ============================================================
#  systemd unit writer (strict: one ExecStart per line, no ; delimiter)
# ============================================================
_write_unit_strict() {
    local name="$1" exec_cmd="$2" workdir="${3:-/}" user="${4:-root}" env_vars="${5:-}"
    local desc="${6:-PIKA Service: $name}"
    local unit_file="/etc/systemd/system/${name}.service"

    cat > "$unit_file" << UNITEOF
[Unit]
Description=${desc}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${user}
WorkingDirectory=${workdir}
ExecStart=${exec_cmd}
Restart=on-failure
RestartSec=5s
UNITEOF

    if [ -n "$env_vars" ]; then
        echo "Environment=\"${env_vars}\"" >> "$unit_file"
    fi

    cat >> "$unit_file" << 'UNITEOF'
StandardOutput=journal
StandardError=journal
SyslogIdentifier=%N

[Install]
WantedBy=multi-user.target
UNITEOF

    systemctl daemon-reload
}

# ============================================================
#  nohup backend state (pid + command), so start/stop/restart work
#  in containers without systemd. Previously "restart" killed the
#  process and left nothing running.
# ============================================================
_SVC_STATE_DIR="${PIKA_CONFIG_DIR}/services"
_SVC_LOG_DIR="${PIKA_SVC_LOG_DIR:-/var/log}"
# Container boot hook. Overridable so tests never touch the real /run.sh.
_SVC_BOOT_FILE="${PIKA_SVC_BOOT_FILE:-/run.sh}"

_svc_nohup_dir() {
    mkdir -p "$_SVC_STATE_DIR" 2>/dev/null || true
    printf '%s' "$_SVC_STATE_DIR"
}

_svc_nohup_pid() {
    local name="$1" pf pid
    pf="$(_svc_nohup_dir)/${name}.pid"
    [ -f "$pf" ] || return 1
    pid=$(cat "$pf" 2>/dev/null || true)
    case "$pid" in ''|*[!0-9]*) return 1 ;; esac
    kill -0 "$pid" 2>/dev/null || return 1
    printf '%s' "$pid"
}

_svc_nohup_start() {
    local name="$1" cmd wd cmd_file wd_file
    cmd_file="$(_svc_nohup_dir)/${name}.cmd"
    wd_file="$(_svc_nohup_dir)/${name}.dir"
    [ -f "$cmd_file" ] || { pika_err "找不到服务启动命令: $cmd_file"; return 1; }
    cmd=$(cat "$cmd_file" 2>/dev/null || true)
    [ -n "$cmd" ] || return 1
    if _svc_nohup_pid "$name" >/dev/null 2>&1; then
        return 0
    fi
    wd="/"
    [ -f "$wd_file" ] && wd=$(cat "$wd_file" 2>/dev/null || echo "/")
    [ -d "$wd" ] || wd="/"
    (
        cd "$wd" 2>/dev/null || cd /
        nohup bash -c "$cmd" >> "${_SVC_LOG_DIR}/${name}.log" 2>&1 &
        echo $! > "$(_svc_nohup_dir)/${name}.pid"
    )
    sleep 1
    if _svc_nohup_pid "$name" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

_svc_nohup_stop() {
    local name="$1" pid i=0
    pid=$(_svc_nohup_pid "$name" 2>/dev/null || true)
    if [ -z "$pid" ]; then
        rm -f "$(_svc_nohup_dir)/${name}.pid" 2>/dev/null || true
        return 0
    fi
    kill "$pid" 2>/dev/null || true
    while [ "$i" -lt 10 ]; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
        i=$((i + 1))
    done
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$(_svc_nohup_dir)/${name}.pid" 2>/dev/null || true
    return 0
}

# ============================================================
#  Unified service management
# ============================================================

# ---- Is the service actually registered with the active backend? ----
svc_registered() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)
    case "$backend" in
        systemd)
            [ -f "/etc/systemd/system/${name}.service" ] \
                || [ -f "/lib/systemd/system/${name}.service" ] \
                || [ -f "/usr/lib/systemd/system/${name}.service" ]
            ;;
        pm2)
            pm2 describe "$name" >/dev/null 2>&1
            ;;
        nohup)
            [ -f "$(_svc_nohup_dir)/${name}.cmd" ]
            ;;
        *) return 1 ;;
    esac
}

# ---- Register/install a service ----
# Usage: svc_register --name NAME --exec "cmd args" [--workdir DIR] [--env "K=V"] [--autostart] [--desc "Description"]
svc_register() {
    local name="" exec_cmd="" workdir="/root" env_vars="" autostart=0 desc=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --name)      name="$2"; shift 2 ;;
            --exec)      exec_cmd="$2"; shift 2 ;;
            --workdir)   workdir="$2"; shift 2 ;;
            --env)       env_vars="$2"; shift 2 ;;
            --autostart) autostart=1; shift ;;
            --desc)      desc="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    [ -z "$name" ] && { pika_err "svc_register: --name required"; return 1; }
    [ -z "$exec_cmd" ] && { pika_err "svc_register: --exec required"; return 1; }

    local backend; backend=$(svc_backend)
    pika_info "注册服务 [$backend]: $name"

    case "$backend" in
        pm2)
            ensure_node_pm2
            pm2 delete "$name" 2>/dev/null || true
            local pm2_env=""
            [ -n "$env_vars" ] && pm2_env="--env $(echo "$env_vars" | tr ',' ' ')"
            cd "$workdir" && pm2 start "$exec_cmd" --name "$name" $pm2_env 2>/dev/null || \
                pm2 start "$exec_cmd" --name "$name" $pm2_env
            pm2 save 2>/dev/null || true
            [ "$autostart" = "1" ] && pm2 startup systemd -u root --hp /root 2>/dev/null || true
            ;;

        systemd)
            _write_unit_strict "$name" "$exec_cmd" "$workdir" "root" "$env_vars" "${desc:-PIKA Service: $name}"
            if [ "$autostart" = "1" ]; then
                systemctl enable --now "$name" 2>/dev/null || true
            fi
            ;;

        nohup)
            mkdir -p "$(_svc_nohup_dir)" 2>/dev/null || true
            printf '%s\n' "$exec_cmd" > "$(_svc_nohup_dir)/${name}.cmd"
            printf '%s\n' "$workdir" > "$(_svc_nohup_dir)/${name}.dir"
            _svc_nohup_stop "$name"
            if ! _svc_nohup_start "$name"; then
                pika_warn "无法启动 nohup 服务: $name"
            fi
            # Add to /run.sh for container auto-start
            pika_file_append_unique "$(svc_autostart_line "$name")" "$_SVC_BOOT_FILE"
            ;;
    esac
}

# ---- Start a service ----
svc_start() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)
            local out
            if ! out=$(pm2 start "$name" 2>&1); then
                pika_warn "无法启动 PM2 服务: $name"
                [ -n "$out" ] && printf '%s\n' "$out" >&2
                return 1
            fi
            ;;
        systemd)
            local out
            if ! out=$(systemctl start "$name" 2>&1); then
                pika_warn "无法启动 systemd 服务: $name"
                [ -n "$out" ] && printf '%s\n' "$out" >&2
                return 1
            fi
            ;;
        nohup)
            if ! _svc_nohup_start "$name"; then
                pika_warn "无法启动 nohup 服务: $name"
                return 1
            fi
            ;;
    esac
    return 0
}

# ---- Stop a service ----
svc_stop() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)     pm2 stop "$name" 2>/dev/null || true ;;
        systemd) systemctl stop "$name" 2>/dev/null || true ;;
        nohup)   _svc_nohup_stop "$name" ;;
    esac
}

# ---- Restart a service ----
svc_restart() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)     pm2 restart "$name" 2>/dev/null || pika_warn "无法重启 PM2 服务: $name" ;;
        systemd) systemctl restart "$name" 2>/dev/null || pika_warn "无法重启 systemd 服务: $name" ;;
        nohup)
            _svc_nohup_stop "$name"
            _svc_nohup_start "$name" || pika_warn "无法重启 nohup 服务: $name"
            ;;
    esac
}

# ---- Get service status (informational: always returns 0) ----
svc_status() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)     pm2 describe "$name" 2>/dev/null || echo "NOT FOUND" ;;
        systemd) systemctl status "$name" --no-pager -l 2>/dev/null || echo "NOT FOUND" ;;
        nohup)
            local pid
            if pid=$(_svc_nohup_pid "$name"); then
                echo "RUNNING (pid $pid)"
            else
                echo "STOPPED"
            fi
            ;;
    esac
    return 0
}

# ---- View service logs ----
svc_logs() {
    local name="$1" lines="${2:-50}"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)     pm2 logs "$name" --lines "$lines" --nostream 2>/dev/null || pika_warn "无 PM2 日志" ;;
        systemd) journalctl -u "$name" -n "$lines" --no-pager 2>/dev/null || pika_warn "无 systemd 日志" ;;
        nohup)   tail -n "$lines" "${_SVC_LOG_DIR}/${name}.log" 2>/dev/null || pika_warn "无 nohup 日志" ;;
    esac
}

# ---- Boot autostart line for the nohup backend ----
# One place builds the /run.sh line, so registering and toggling can never
# drift apart (a drifted line means "autostart: off" forever).
svc_autostart_line() {
    local name="$1" cmd_file cmd
    [ -z "$name" ] && return 1
    cmd_file="$(_svc_nohup_dir)/${name}.cmd"
    [ -f "$cmd_file" ] || return 1
    cmd=$(cat "$cmd_file" 2>/dev/null || true)
    [ -n "$cmd" ] || return 1
    printf 'nohup %s >> %s/%s.log 2>&1 &' "$cmd" "$_SVC_LOG_DIR" "$name"
}

# ---- Autostart state: on | off | na | unknown ----
# na = the backend manages boot globally (PM2 resurrects its saved list),
# so there is no honest per-service answer.
svc_autostart_state() {
    local name="$1" st line
    if [ -z "$name" ]; then
        printf 'unknown'
        return 0
    fi
    case "$(svc_backend)" in
        systemd)
            st=$(systemctl is-enabled "$name" 2>/dev/null || true)
            case "$st" in
                enabled|enabled-runtime|static|indirect|generated) printf 'on' ;;
                disabled|masked|masked-runtime|linked|linked-runtime|alias) printf 'off' ;;
                *) printf 'unknown' ;;
            esac
            ;;
        nohup)
            if ! line=$(svc_autostart_line "$name"); then
                printf 'unknown'
                return 0
            fi
            if [ -f "$_SVC_BOOT_FILE" ] && grep -qxF -- "$line" "$_SVC_BOOT_FILE" 2>/dev/null; then
                printf 'on'
            else
                printf 'off'
            fi
            ;;
        pm2)
            printf 'na'
            ;;
        *)
            printf 'unknown'
            ;;
    esac
    return 0
}

# ---- Turn boot autostart on/off ----
svc_autostart_set() {
    local name="$1" want="$2" line f tmp
    [ -z "$name" ] && return 1
    case "$want" in on|off) ;; *) return 1 ;; esac

    case "$(svc_backend)" in
        systemd)
            if [ "$want" = "on" ]; then
                systemctl enable "$name" >/dev/null 2>&1 || return 1
            else
                systemctl disable "$name" >/dev/null 2>&1 || return 1
            fi
            ;;
        nohup)
            line=$(svc_autostart_line "$name") || return 1
            f="$_SVC_BOOT_FILE"
            if [ "$want" = "on" ]; then
                mkdir -p "${f%/*}" 2>/dev/null || true
                pika_file_append_unique "$line" "$f" || return 1
            else
                [ -f "$f" ] || return 0
                tmp="${f}.pika-$$.tmp"
                grep -vxF -- "$line" "$f" > "$tmp" 2>/dev/null || true
                mv -f "$tmp" "$f" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
            fi
            ;;
        *)
            return 1
            ;;
    esac

    # Verify instead of trusting the exit code: systemctl can "succeed" on a
    # masked unit and nohup can fail on a read-only /run.sh.
    [ "$(svc_autostart_state "$name")" = "$want" ]
}

# ---- Interactive autostart toggle shared by Caddy / Nginx service menus ----
svc_autostart_prompt() {
    local name="$1" st want
    if [ -z "$name" ]; then
        pika_err "$(t 'svc.autostart.unknown')"
        return 1
    fi
    st=$(svc_autostart_state "$name")
    case "$st" in
        na)
            pika_info "$(t 'svc.autostart.pm2')"
            return 0
            ;;
        unknown)
            pika_warn "$(t 'svc.autostart.unknown')"
            return 1
            ;;
        on)
            printf '\n  %s: %s\n' "$(t 'svc.autostart.label')" "$(t 'svc.autostart.on')"
            want="off"
            pika_confirm "$(t 'svc.autostart.turn_off')" || { pika_info "$(t 'ui.cancelled')"; return 0; }
            ;;
        *)
            printf '\n  %s: %s\n' "$(t 'svc.autostart.label')" "$(t 'svc.autostart.off')"
            want="on"
            pika_confirm "$(t 'svc.autostart.turn_on')" || { pika_info "$(t 'ui.cancelled')"; return 0; }
            ;;
    esac

    if svc_autostart_set "$name" "$want"; then
        if [ "$want" = "on" ]; then
            pika_info "$(t 'svc.autostart.enabled')"
        else
            pika_info "$(t 'svc.autostart.disabled')"
        fi
        return 0
    fi
    pika_err "$(t 'svc.autostart.failed')"
    return 1
}

# ---- Remove/uninstall a service completely ----
svc_remove() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)
            pm2 delete "$name" 2>/dev/null || true
            pm2 save 2>/dev/null || true
            ;;
        systemd)
            systemctl stop "$name" 2>/dev/null || true
            systemctl disable "$name" 2>/dev/null || true
            rm -f "/etc/systemd/system/${name}.service"
            systemctl daemon-reload
            ;;
        nohup)
            _svc_nohup_stop "$name"
            rm -f "$(_svc_nohup_dir)/${name}.cmd" "$(_svc_nohup_dir)/${name}.dir" 2>/dev/null || true
            rm -f "${_SVC_LOG_DIR}/${name}.log"
            ;;
    esac
    pika_info "服务已卸载: $name"
}

# ---- List all registered PIKA services ----
svc_list() {
    local backend; backend=$(svc_backend)
    echo ""
    echo "  PIKA 托管服务清单 (后端: $backend):"
    echo "  $(printf '%*s' 50 '' | tr ' ' '─')"

    case "$backend" in
        pm2)
            pm2 list 2>/dev/null || echo "  (无运行中的服务)"
            ;;
        systemd)
            local units; units=$(systemctl list-unit-files --type=service 2>/dev/null | grep -E '\.service' | grep -v '@' | head -30 || true)
            if [ -n "$units" ]; then echo "$units"; else echo "  (无 systemd 服务)"; fi
            ;;
        nohup)
            echo "  nohup 托管服务 (PID):"
            ps aux 2>/dev/null | grep 'nohup' | grep -v grep || echo "  (无 nohup 进程)"
            ;;
    esac
    echo ""
}

# ---- Mark lib as loaded ----
PIKA_SVC_LOADED=1
