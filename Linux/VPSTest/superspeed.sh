#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Multi-Node Speed Test Wrapper
#  Downloads and runs global multi-node speedtest.
# ============================================================
set -e

MIRRORS=(
    "https://benchs.pika.net.cn/qsyb-bench/ookla-speedtest-1.2.0-linux-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/aarch64/').tgz"
    "https://gh-vps.pika.net.cn/qsyb-bench/ookla-speedtest-1.2.0-linux-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/aarch64/').tgz"
)

ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/aarch64/')
TMPD=$(mktemp -d) || exit 1
cd "$TMPD"

for m in "${MIRRORS[@]}"; do
    if curl -fsSL --connect-timeout 8 --max-time 60 "$m" -o speedtest.tgz 2>/dev/null; then
        tar -xzf speedtest.tgz
        chmod +x speedtest 2>/dev/null || true
        ./speedtest --accept-license --accept-gdpr "$@"
        rm -rf "$TMPD"
        exit 0
    fi
done
echo "ERROR: All speedtest sources are unavailable." >&2; rm -rf "$TMPD"; exit 1
