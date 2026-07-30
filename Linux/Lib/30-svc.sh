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
    [ -n "$PIKA_SVC_BACKEND" ] && { echo "$PIKA_SVC_BACKEND"; return; }
    PIKA_SVC_BACKEND=$(svc_detect_backend)
    export PIKA_SVC_BACKEND
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
    local name="$1" exec_cmd="$2" workdir="${3:-/}" user="${4:-root}" env_vars="${5:-}" desc="${6:-PIKA Service: $name}"
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
#  Unified service management
# ============================================================

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
            # Kill existing instance
            pkill -f "$exec_cmd" 2>/dev/null || true
            cd "$workdir"
            nohup $exec_cmd >> "/var/log/${name}.log" 2>&1 &
            # Add to /run.sh for container auto-start
            pika_file_append_unique "nohup $exec_cmd >> /var/log/${name}.log 2>&1 &" "/run.sh"
            ;;
    esac
}

# ---- Start a service ----
svc_start() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)     pm2 start "$name" 2>/dev/null || pika_warn "无法启动 PM2 服务: $name" ;;
        systemd) systemctl start "$name" 2>/dev/null || pika_warn "无法启动 systemd 服务: $name" ;;
        nohup)   pika_warn "nohup 服务请手动启动" ;;
    esac
}

# ---- Stop a service ----
svc_stop() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)     pm2 stop "$name" 2>/dev/null || true ;;
        systemd) systemctl stop "$name" 2>/dev/null || true ;;
        nohup)   pkill -f "$name" 2>/dev/null || true ;;
    esac
}

# ---- Restart a service ----
svc_restart() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)     pm2 restart "$name" 2>/dev/null || pika_warn "无法重启 PM2 服务: $name" ;;
        systemd) systemctl restart "$name" 2>/dev/null || pika_warn "无法重启 systemd 服务: $name" ;;
        nohup)   pkill -f "$name" 2>/dev/null || true; pika_warn "nohup 服务请手动重启" ;;
    esac
}

# ---- Get service status ----
svc_status() {
    local name="$1"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)     pm2 describe "$name" 2>/dev/null || { echo "NOT FOUND"; return 1; } ;;
        systemd) systemctl status "$name" --no-pager -l 2>/dev/null || { echo "NOT FOUND"; return 1; } ;;
        nohup)   pgrep -f "$name" >/dev/null 2>&1 && echo "RUNNING" || echo "STOPPED" ;;
    esac
}

# ---- View service logs ----
svc_logs() {
    local name="$1" lines="${2:-50}"; [ -z "$name" ] && return 1
    local backend; backend=$(svc_backend)

    case "$backend" in
        pm2)     pm2 logs "$name" --lines "$lines" --nostream 2>/dev/null || pika_warn "无 PM2 日志" ;;
        systemd) journalctl -u "$name" -n "$lines" --no-pager 2>/dev/null || pika_warn "无 systemd 日志" ;;
        nohup)   tail -n "$lines" "/var/log/${name}.log" 2>/dev/null || pika_warn "无 nohup 日志" ;;
    esac
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
            pkill -f "$name" 2>/dev/null || true
            rm -f "/var/log/${name}.log"
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
