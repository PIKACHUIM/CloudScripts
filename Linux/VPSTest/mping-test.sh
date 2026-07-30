#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Multi-Ping Test Wrapper
#  Downloads besttrace from mirror and runs ping test.
# ============================================================
set -e
MIRRORS=(
    "https://benchs.pika.net.cn/mping-test/besttrace"
    "https://gh-vps.pika.net.cn/mping-test/besttrace"
)

TMPF=$(mktemp) || exit 1
for m in "${MIRRORS[@]}"; do
    if curl -fsSL --connect-timeout 8 --max-time 60 "$m" -o "$TMPF" 2>/dev/null; then
        chmod +x "$TMPF"
        echo "=== Multi-location Ping Test ==="
        for ip in 202.103.44.150 114.114.114.114 223.5.5.5 119.29.29.29 180.76.76.76; do
            echo -n "  PING $ip: "
            "$TMPF" -q1 "$ip" 2>/dev/null | head -3 || echo "FAILED"
        done
        rm -f "$TMPF"
        exit 0
    fi
done
echo "ERROR: Cannot download besttrace." >&2; rm -f "$TMPF"; exit 1
