#!/usr/bin/env bash
# ============================================================
#  PIKA SH - NextTrace / SuperTrace Wrapper
#  Downloads besttrace binary from mirror and runs 3-ISP traceroute.
# ============================================================
set -e
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64) BIN="besttrace" ;;
    aarch64|arm64) BIN="besttracearm" ;;
    *) echo "ERROR: Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

MIRRORS=(
    "https://benchs.pika.net.cn/supertrace/${BIN}"
    "https://gh-vps.pika.net.cn/supertrace/${BIN}"
)

TMPF=$(mktemp) || exit 1
for m in "${MIRRORS[@]}"; do
    if curl -fsSL --connect-timeout 8 --max-time 60 "$m" -o "$TMPF" 2>/dev/null; then
        chmod +x "$TMPF"
        echo "=== China Telecom (CT) ==="
        "$TMPF" -q1 202.103.44.150 || true
        echo ""
        echo "=== China Unicom (CU) ==="
        "$TMPF" -q1 210.22.88.1 || true
        echo ""
        echo "=== China Mobile (CM) ==="
        "$TMPF" -q1 221.183.89.45 || true
        rm -f "$TMPF"
        exit 0
    fi
done
echo "ERROR: Cannot download besttrace." >&2; rm -f "$TMPF"; exit 1
