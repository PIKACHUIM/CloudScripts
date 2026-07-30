#!/usr/bin/env bash
# ============================================================
#  PIKA SH - UnixBench Wrapper
#  Downloads UnixBench from mirror and runs it.
#  Original: teddysun/across
# ============================================================
set -e

MIRRORS=(
    "https://benchs.pika.net.cn/unix-bench/unixbench.sh"
    "https://gh-vps.pika.net.cn/unix-bench/unixbench.sh"
    "https://github.524228.xyz/https://raw.githubusercontent.com/teddysun/across/master/unixbench.sh"
    "https://raw.githubusercontent.com/teddysun/across/master/unixbench.sh"
)

TMPF=$(mktemp) || exit 1
for m in "${MIRRORS[@]}"; do
    if curl -fsSL --connect-timeout 8 --max-time 30 "$m" -o "$TMPF" 2>/dev/null; then
        chmod +x "$TMPF"
        bash "$TMPF" "$@"
        rm -f "$TMPF"
        exit 0
    fi
done
echo "ERROR: All mirror sources are unavailable." >&2; rm -f "$TMPF"; exit 1
