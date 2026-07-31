#!/usr/bin/env bash
set -e
export PIKA_BASE="$(cd "$(dirname "$0")" && pwd)"
export PIKA_VERSION="1.0"
export PIKA_CONFIG_DIR=/tmp/pika-test
export PIKA_CACHE_DIR=/tmp/pika-test
export PIKA_RUN_DIR=/tmp/pika-test
mkdir -p /tmp/pika-test
. "$PIKA_BASE/Linux/Lib/00-core.sh"
. "$PIKA_BASE/Linux/Lib/50-i18n.sh"
. "$PIKA_BASE/Linux/Lib/40-ui.sh"

# Override column width for testing
_pika_term_width() { echo 80; }
export COLUMNS=80

echo "===== Chinese menu (80 cols) ====="
ui_item 1 "部署安装" "面板、容器、工具一键部署"
ui_item 2 "系统维护" "内核、BBR、防火墙、清理"
ui_item 3 "桌面环境" "LXC 容器图形桌面安装"
ui_item 4 "性能测评" "跑分、测速、路由追踪"
ui_item 5 "代理组网" "VPN、代理、内网穿透"
ui_item 6 "系统工具" "SSH加固、时区、自更新、卸载"
ui_item 0 "退出" ""

echo ""
echo "===== English menu (80 cols) ====="
i18n_load en_US
ui_item 1 "Deploy & Install" "Panels, containers, tools - one-click deploy"
ui_item 2 "System Maintenance" "Kernel, BBR, firewall, cleanup"
ui_item 6 "System Tools" "SSH hardening, time sync, updater, uninstall"
ui_item 0 "Exit" ""
