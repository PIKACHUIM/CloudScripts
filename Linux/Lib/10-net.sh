#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Network / Mirror / Download Library
#  Multi-tier mirror probing, unified download, GitHub URL rewriting
#  Requires: 00-core.sh loaded first
# ============================================================
set -e

# ---- Mirror chain (ordered by preference, fastest first) ----
# User can override via PIKA_MIRROR env var or --mirror CLI arg
PIKA_MIRRORS_DEFAULT=(
    "https://benchs.pika.net.cn"                # Assets mirror (Pages)
    "https://gh-vps.pika.net.cn"                # VPS scripts mirror (Pages)
    "https://pikash.opkg.cn"                # Main scripts mirror (Pages)
    "https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
    "https://ghfast.top/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
    "https://gh-proxy.com/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
    "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
)

PIKA_MIRROR_CACHE="${PIKA_CACHE_DIR}/mirror.conf"
PIKA_MIRROR_TTL=86400   # 24 hours

# ---- Verify that a healthz endpoint is really our server ----
# Returns 0 if probe passes, non-zero otherwise
# Uses both HTTP status code AND content feature check to defeat DNS poisoning
_probe_mirror() {
    local base="$1" probe_url="${base}/.pika-healthz"
    local code tmpfile
    tmpfile=$(mktemp) || return 1

    # Fast probe: HTTP 200 + PIKA_SH_OK magic string
    code=$(curl -fsSL -o "$tmpfile" -w '%{http_code}' \
           --connect-timeout 3 --max-time 8 \
           "$probe_url" 2>/dev/null) || { rm -f "$tmpfile"; return 1; }

    if [ "$code" = "200" ] && grep -q 'PIKA_SH_OK' "$tmpfile" 2>/dev/null; then
        rm -f "$tmpfile"
        pika_debug "Mirror probe OK: $base"
        return 0
    fi
    rm -f "$tmpfile"
    return 1
}

# ---- Probe first N mirrors concurrently, take first success ----
_probe_mirror_fast() {
    local -n candidates=$1
    local max_parallel="${2:-3}"
    local tmpd result

    tmpd=$(mktemp -d) || { echo "${candidates[-1]}"; return; }
    local pids=() count=0

    for m in "${candidates[@]}"; do
        (_probe_mirror "$m" && echo "$m" > "$tmpd/ok.$count") &
        pids+=($!)
        count=$((count + 1))
        [ $count -ge "$max_parallel" ] && break
    done

    # Wait for first success or all done (timeout 10s total)
    local waited=0
    while [ $waited -lt 10 ]; do
        for f in "$tmpd"/ok.*; do
            [ -f "$f" ] && { read -r result < "$f"; rm -rf "$tmpd"; echo "$result"; return 0; }
        done
        sleep 0.5
        waited=$((waited + 1))
    done

    # Kill remaining probes
    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    rm -rf "$tmpd"

    # None succeeded from first batch; try the rest
    return 1
}

# ---- Full probe: try all mirrors in order ----
_probe_mirror_sequential() {
    local -n cands=$1
    for m in "${cands[@]}"; do
        if _probe_mirror "$m"; then
            echo "$m"
            return 0
        fi
    done
    return 1
}

# ---- Select best mirror (with caching) ----
_pika_select_mirror() {
    local cached cached_ts now best

    # If user forced a mirror, use it directly (no probing needed)
    if [ -n "${PIKA_MIRROR:-}" ]; then
        pika_debug "Using user-specified mirror: $PIKA_MIRROR"
        echo "$PIKA_MIRROR"
        return 0
    fi

    # Check cache
    if [ -f "$PIKA_MIRROR_CACHE" ]; then
        cached=$(head -1 "$PIKA_MIRROR_CACHE" 2>/dev/null || true)
        cached_ts=$(sed -n '2p' "$PIKA_MIRROR_CACHE" 2>/dev/null || echo 0)
        now=$(date +%s)
        if [ -n "$cached" ] && [ $((now - cached_ts)) -lt "$PIKA_MIRROR_TTL" ]; then
            # Verify cached mirror is still alive (quick check)
            if _probe_mirror "$cached"; then
                echo "$cached"
                return 0
            fi
            pika_warn "Cached mirror $cached no longer reachable, re-probing..."
        fi
    fi

    # Probe: fast concurrent first, then sequential
    pika_info "正在探测最优下载通道..."
    best=$(_probe_mirror_fast PIKA_MIRRORS_DEFAULT 3 2>/dev/null || true)
    if [ -z "$best" ]; then
        best=$(_probe_mirror_sequential PIKA_MIRRORS_DEFAULT 2>/dev/null || true)
    fi

    if [ -n "$best" ]; then
        # Cache result
        printf '%s\n%s\n' "$best" "$(date +%s)" > "$PIKA_MIRROR_CACHE"
        echo "$best"
        return 0
    fi

    # Ultimate fallback: raw GitHub
    pika_warn "所有代理通道不可用，回退到直连 (可能较慢)"
    echo "${PIKA_MIRRORS_DEFAULT[-1]}"
}

# Export selected mirror base URL (lazy init)
PIKA_MIRROR_BASE=""

pika_init_mirror() {
    [ -n "$PIKA_MIRROR_BASE" ] && return
    PIKA_MIRROR_BASE=$(_pika_select_mirror)
    export PIKA_MIRROR_BASE
}

# ============================================================
#  Unified download: pika_fetch
#  Usage:
#    pika_fetch <url_or_relpath> [-o outfile] [--sha256 HASH] [--no-cache]
#  If given a relative path (no ://), prepend PIKA_MIRROR_BASE.
#  If given an absolute URL, download directly with retries.
# ============================================================
pika_fetch() {
    local url="" outfile="-" use_cache=1 expect_hash=""
    local retries=3 retry_delay=2

    # Parse args
    while [ $# -gt 0 ]; do
        case "$1" in
            -o) outfile="$2"; shift 2 ;;
            --sha256) expect_hash="$2"; shift 2 ;;
            --no-cache) use_cache=0; shift ;;
            -*) shift ;;
            *) url="$1"; shift ;;
        esac
    done

    [ -z "$url" ] && { pika_err "pika_fetch: no URL specified"; return 1; }

    # Resolve URL: relative paths use mirror, absolute URLs are direct
    case "$url" in
        *://*) ;;  # Absolute URL, use as-is
        *) pika_init_mirror; url="${PIKA_MIRROR_BASE}/${url#/}" ;;
    esac

    # Check local cache (by URL hash)
    local cache_key cache_file
    if [ "$use_cache" = "1" ]; then
        cache_key=$(echo -n "$url" | sha256sum 2>/dev/null | cut -d' ' -f1 || echo -n "$url" | md5sum 2>/dev/null | cut -d' ' -f1 || true)
        cache_file="${PIKA_CACHE_DIR}/fetch_${cache_key}"
        if [ -f "$cache_file" ]; then
            # Verify hash if requested
            if [ -n "$expect_hash" ]; then
                local actual; actual=$(sha256sum "$cache_file" 2>/dev/null | cut -d' ' -f1)
                if [ "$actual" = "$expect_hash" ]; then
                    if [ "$outfile" != "-" ]; then cp "$cache_file" "$outfile"; else cat "$cache_file"; fi
                    return 0
                fi
            else
                if [ "$outfile" != "-" ]; then cp "$cache_file" "$outfile"; else cat "$cache_file"; fi
                return 0
            fi
        fi
    fi

    # Download with retries
    local attempt=0 success=0 tmpf
    tmpf=$(mktemp) || return 1

    while [ $attempt -lt $retries ]; do
        attempt=$((attempt + 1))
        pika_debug "Fetch ($attempt/$retries): $url"

        if curl -fSL --connect-timeout 10 --max-time 120 -o "$tmpf" "$url" 2>/dev/null; then
            success=1
            break
        fi

        # Try wget as fallback
        if command -v wget >/dev/null 2>&1; then
            if wget -q --timeout=10 --tries=1 -O "$tmpf" "$url" 2>/dev/null; then
                success=1
                break
            fi
        fi

        [ $attempt -lt $retries ] && sleep "$retry_delay"
    done

    if [ "$success" != "1" ]; then
        rm -f "$tmpf"
        pika_err "下载失败 (after $retries attempts): $url"
        return 1
    fi

    # Verify hash if requested
    if [ -n "$expect_hash" ]; then
        local actual; actual=$(sha256sum "$tmpf" 2>/dev/null | cut -d' ' -f1)
        if [ "$actual" != "$expect_hash" ]; then
            rm -f "$tmpf"
            pika_err "校验和不匹配: expected=$expect_hash actual=${actual:-N/A}"
            return 1
        fi
    fi

    # Cache if enabled
    if [ "$use_cache" = "1" ] && [ -n "$cache_file" ]; then
        cp "$tmpf" "$cache_file"
    fi

    # Output
    if [ "$outfile" != "-" ]; then
        mv "$tmpf" "$outfile"
    else
        cat "$tmpf"
        rm -f "$tmpf"
    fi
    return 0
}

# ============================================================
#  GitHub URL rewriting: gh_url <github_url>
#  Rewrites any GitHub URL through the active mirror proxy
#  Usage: download_url=$(gh_url "https://github.com/user/repo/releases/download/v1.0/file.tar.gz")
# ============================================================
gh_url() {
    local url="$1"
    pika_init_mirror

    # Only rewrite github.com URLs that aren't already going through a proxy
    case "$url" in
        *github.com*)
            # If mirror base is already a proxy prefix, use it
            case "$PIKA_MIRROR_BASE" in
                *github.524228.xyz*|*ghfast.top*|*gh-proxy.com*|*ghproxy.vip*)
                    # Extract proxy prefix from mirror base
                    local proxy_prefix
                    proxy_prefix=$(echo "$PIKA_MIRROR_BASE" | sed 's|/PIKACHUIM/CloudScripts/main.*||')
                    echo "${proxy_prefix}/${url}"
                    return
                    ;;
            esac
            # Otherwise, try to use the fastest known proxy for GitHub
            # Use the first proxy-type mirror from the chain
            for m in "${PIKA_MIRRORS_DEFAULT[@]}"; do
                case "$m" in
                    *524228.xyz*|*ghfast.top*|*gh-proxy.com*)
                        local pp; pp=$(echo "$m" | sed 's|/PIKACHUIM/CloudScripts/main.*||')
                        echo "${pp}/${url}"
                        return
                        ;;
                esac
            done
            # Fallback: just return original
            echo "$url"
            ;;
        *)
            echo "$url"
            ;;
    esac
}

# ============================================================
#  Remote script execution: pika_run_remote <url_or_relpath> [args...]
#  Downloads script to temp file, then executes it.
#  Avoids curl|bash which steals stdin (problematic for interactive scripts)
# ============================================================
pika_run_remote() {
    local url="$1"; shift
    local tmpf
    tmpf=$(mktemp) || pika_die "无法创建临时文件"

    pika_fetch "$url" -o "$tmpf" || { rm -f "$tmpf"; return 1; }

    chmod +x "$tmpf"
    bash "$tmpf" "$@"
    local rc=$?
    rm -f "$tmpf"
    return $rc
}

# ============================================================
#  Benchmark runner: try multiple sources until one succeeds
#  Usage: pika_bench_run bench "ecss-bench/ecs.sh" -- [args...]
# ============================================================
pika_bench_run() {
    local name="$1"; shift
    local urls=()

    # Collect URLs until -- separator
    while [ $# -gt 0 ]; do
        case "$1" in
            --) shift; break ;;
            *) urls+=("$1"); shift ;;
        esac
    done

    for u in "${urls[@]}"; do
        pika_info "执行 $name: 尝试 $u ..."
        if pika_run_remote "$u" "$@"; then
            return 0
        fi
        pika_warn "$name: $u 失败，尝试下一个源..."
    done

    pika_err "$name: 所有镜像源均不可用"
    return 1
}

# ---- Mark lib as loaded ----
PIKA_NET_LOADED=1
