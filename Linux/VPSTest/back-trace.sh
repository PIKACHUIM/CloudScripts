#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Backtrace Route Tracer Wrapper
#  Downloads backtrace binary from mirror and runs it.
# ============================================================
set -e
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  BIN="backtrace-linux-amd64.tar.gz" ;;
    aarch64) BIN="backtrace-linux-arm64.tar.gz" ;;
    *) echo "ERROR: Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

MIRRORS=(
    "https://benchs.pika.net.cn/back-trace/${BIN}"
    "https://gh-vps.pika.net.cn/back-trace/${BIN}"
)

TMPD=$(mktemp -d) || exit 1
for m in "${MIRRORS[@]}"; do
    if curl -fsSL --connect-timeout 8 --max-time 30 "$m" -o "$TMPD/backtrace.tar.gz" 2>/dev/null; then
        cd "$TMPD"
        tar -xf backtrace.tar.gz
        mv backtrace /usr/bin/ 2>/dev/null || true
        backtrace "$@"
        rm -rf "$TMPD"
        exit 0
    fi
done
echo "ERROR: Cannot download backtrace." >&2; rm -rf "$TMPD"; exit 1
