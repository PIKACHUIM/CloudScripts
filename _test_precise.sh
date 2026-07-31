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

# Test _ui_str_pad output
test_pad() {
    local s="$1" target="$2"
    local out; out=$(_ui_str_pad "$s" "$target")
    local out_w; out_w=$(_ui_str_width "$out")
    printf 'input=%-30s target=%d  output_w=%d  len=%d\n' \
        "\"$s\"" "$target" "$out_w" "${#out}"
}

test_pad "部署安装" 14
test_pad "系统维护" 14
test_pad "系统工具" 14
test_pad "Deploy & Install" 14

echo "---- desc padding ----"
test_pad "面板、容器、工具一键部署" 32
test_pad "内核、BBR、防火墙、清理" 32
test_pad "LXC 容器图形桌面安装" 32
test_pad "跑分、测速、路由追踪" 32
test_pad "VPN、代理、内网穿透" 32
test_pad "SSH加固、时区、自更新、卸载" 32
