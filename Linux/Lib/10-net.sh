#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Network / Mirror / Download Library
#  Multi-tier mirror probing, unified download, GitHub URL rewriting
#  Requires: 00-core.sh loaded first
# ============================================================
set -e

# ---- Mirror chain (ordered by preference, fastest first) ----
# User can override via PIKA_MIRROR env var or --mirror CLI arg
# The two PIKA SH sites serve the identical tree:
#   pikash.pika.net.cn = Tencent EdgeOne Pages (mainland reachable)
#   pikash.opkg.cn     = GitHub Pages (overseas)
PIKA_SITE_CN="${PIKA_SITE_CN:-https://pikash.pika.net.cn}"
PIKA_SITE_INTL="${PIKA_SITE_INTL:-https://pikash.opkg.cn}"
PIKA_SITE_RAW="${PIKA_SITE_RAW:-https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main}"

PIKA_MIRRORS_DEFAULT=(
    "$PIKA_SITE_CN"                             # Mainland edge (EdgeOne Pages)
    "$PIKA_SITE_INTL"                           # Overseas mirror (GitHub Pages)
    "https://benchs.pika.net.cn"                # Assets mirror (Pages)
    "https://gh-vps.pika.net.cn"                # VPS scripts mirror (Pages)
    "https://github.524228.xyz/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
    "https://ghfast.top/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
    "https://gh-proxy.com/https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main"
    "$PIKA_SITE_RAW"
)

PIKA_MIRROR_CACHE="${PIKA_CACHE_DIR}/mirror.conf"
PIKA_MIRROR_TTL=86400   # 24 hours

# ---- Verify that a healthz endpoint is really our server ----
# Returns 0 if probe passes, non-zero otherwise
# Uses both HTTP status code AND content feature check to defeat DNS poisoning.
# Two probe paths are tried because some static hosts strip dotfiles.
_probe_mirror() {
    local base="$1" path tmpfile code answered=0
    for path in ".pika-healthz" "pika-healthz.txt"; do
        tmpfile=$(mktemp) || return 1
        # Fast probe: HTTP 200 + PIKA_SH_OK magic string. No -f here so the
        # status code is always available and the txt fallback can be tried.
        code=$(curl -sSL -o "$tmpfile" -w '%{http_code}' \
               --connect-timeout 2 --max-time 4 \
               "${base}/${path}" 2>/dev/null) || code=""
        if [ -n "$code" ]; then
            answered=1
        fi
        if [ "$code" = "200" ] && grep -q 'PIKA_SH_OK' "$tmpfile" 2>/dev/null; then
            rm -f "$tmpfile"
            pika_debug "Mirror probe OK: $base"
            return 0
        fi
        rm -f "$tmpfile"
        [ "$answered" = "0" ] && return 1
    done
    return 1
}

# ---- Probe every mirror concurrently, take the first healthy answer ----
# Hard 5s budget: a blocked or black-holed host costs at most one probe and
# can never stall the menu, even when a whole region is unreachable.
_probe_mirror_fast() {
    local -n _cands=$1
    local tmpd="" result="" i=0 pid
    local pids=()

    tmpd=$(mktemp -d 2>/dev/null) || return 1

    for m in "${_cands[@]}"; do
        ( _probe_mirror "$m" && printf '%s\n' "$m" > "$tmpd/ok.${i}" ) &
        pids+=($!)
        i=$((i + 1))
    done

    local waited=0
    while [ "$waited" -lt 25 ]; do
        for f in "$tmpd"/ok.*; do
            if [ -f "$f" ]; then
                result=$(sed -n '1p' "$f")
                for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
                rm -rf "$tmpd"
                printf '%s' "$result"
                return 0
            fi
        done
        sleep 0.2
        waited=$((waited + 1))
    done

    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    wait "${pids[@]}" 2>/dev/null || true
    rm -rf "$tmpd"
    return 1
}

# ---- Select best mirror (with caching) ----
_pika_select_mirror() {
    local cached cached_ts now best

    # If user forced a mirror, use it directly (no probing needed)
    if [ -n "${PIKA_MIRROR:-}" ]; then
        pika_debug "Using user-specified mirror: $PIKA_MIRROR"
        printf '%s' "${PIKA_MIRROR%/}"
        return 0
    fi

    # The bootstrap already picked (and cached) the closest reachable site
    if [ -n "${PIKA_SITE_BASE:-}" ]; then
        pika_debug "Using bootstrapped site: $PIKA_SITE_BASE"
        printf '%s' "$PIKA_SITE_BASE"
        return 0
    fi

    # Check cache
    if [ -f "$PIKA_MIRROR_CACHE" ]; then
        cached=$(sed -n '1p' "$PIKA_MIRROR_CACHE" 2>/dev/null || true)
        cached_ts=$(sed -n '2p' "$PIKA_MIRROR_CACHE" 2>/dev/null || echo 0)
        case "$cached_ts" in ''|*[!0-9]*) cached_ts=0 ;; esac
        now=$(date +%s)
        if [ -n "$cached" ] && [ $((now - cached_ts)) -lt "$PIKA_MIRROR_TTL" ]; then
            # Verify cached mirror is still alive (quick check)
            if _probe_mirror "$cached"; then
                printf '%s' "$cached"
                return 0
            fi
            pika_warn "Cached mirror $cached no longer reachable, re-probing..."
        fi
    fi

    pika_info "正在探测最优下载通道..."
    best=$(_probe_mirror_fast PIKA_MIRRORS_DEFAULT 2>/dev/null || true)
    if [ -n "$best" ]; then
        printf '%s\n%s\n' "$best" "$(date +%s)" > "$PIKA_MIRROR_CACHE" 2>/dev/null || true
        printf '%s' "$best"
        return 0
    fi

    # Ultimate fallback: raw GitHub (may be blocked, but every attempt is bounded)
    pika_warn "所有代理通道不可用，回退到直连 (可能较慢)"
    printf '%s' "$PIKA_SITE_RAW"
}

# Export selected mirror base URL (lazy init)
# Reuse whatever the launcher/bootstrap already resolved.
PIKA_MIRROR_BASE="${PIKA_SITE_BASE:-}"

pika_init_mirror() {
    [ -n "$PIKA_MIRROR_BASE" ] && return
    PIKA_MIRROR_BASE=$(_pika_select_mirror)
    export PIKA_MIRROR_BASE
}

# ============================================================
#  GitHub acceleration (mainland-friendly)
#  Prefix-style accelerators: the full GitHub URL is appended as-is.
#  Direct access is always attempted first, so hosts with good GitHub
#  connectivity keep full speed and never pay for a probe.
# ============================================================
PIKA_GH_PREFIXES=(
    "https://ghfast.top/"
    "https://gh-proxy.com/"
    "https://ghproxy.net/"
    "https://github.524228.xyz/"
)
PIKA_GH_PROBE_PATH="PIKACHUIM/CloudScripts/main/.pika-healthz"
PIKA_GH_CACHE="${PIKA_CACHE_DIR}/gh-proxy.conf"
PIKA_GH_TTL=86400   # 24 hours
PIKA_GH_PREFIX_RESOLVED=""

# Is acceleration allowed? --no-accel wins, then the persisted config.
pika_accel_enabled() {
    [ "${PIKA_NO_ACCEL:-0}" = "1" ] && return 1
    local mode
    mode=$(pika_config_get "accel" 2>/dev/null || true)
    [ "$mode" = "off" ] && return 1
    return 0
}

# Does this URL point at GitHub (raw, release asset, codeload, ...)?
_pika_is_gh_url() {
    case "$1" in
        https://github.com/*|https://raw.githubusercontent.com/*|\
        https://gist.githubusercontent.com/*|https://codeload.github.com/*|\
        https://objects.githubusercontent.com/*|https://github-releases.githubusercontent.com/*)
            return 0
            ;;
    esac
    return 1
}

# Probe one accelerator with our health file (magic string defeats parking pages).
_pika_gh_probe() {
    local prefix="$1" tmp code
    tmp=$(mktemp 2>/dev/null) || return 1
    code=$(curl -sSL -o "$tmp" -w '%{http_code}' \
           --connect-timeout 2 --max-time 5 \
           "${prefix}https://raw.githubusercontent.com/${PIKA_GH_PROBE_PATH}" 2>/dev/null) || code=""
    if [ "$code" = "200" ] && grep -q 'PIKA_SH_OK' "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# Probe every accelerator at once, first healthy answer wins (~1 RTT, 6s cap).
_pika_gh_select() {
    local tmpd result="" i=0 pid w=0 prefix f
    local pids=()
    tmpd=$(mktemp -d 2>/dev/null) || return 1

    for prefix in "${PIKA_GH_PREFIXES[@]}"; do
        ( _pika_gh_probe "$prefix" && printf '%s\n' "$prefix" > "$tmpd/ok.${i}" ) &
        pids+=($!)
        i=$((i + 1))
    done

    while [ "$w" -lt 40 ]; do
        for f in "$tmpd"/ok.*; do
            if [ -f "$f" ]; then
                result=$(sed -n '1p' "$f")
                break 2
            fi
        done
        sleep 0.15
        w=$((w + 1))
    done

    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    wait "${pids[@]}" 2>/dev/null || true
    rm -rf "$tmpd"

    [ -n "$result" ] || return 1
    printf '%s\n%s\n' "$result" "$(date +%s)" > "$PIKA_GH_CACHE" 2>/dev/null || true
    printf '%s' "$result"
}

# Return the best accelerator prefix ("" when none works / acceleration off).
# Resolution order: env/config override > 24h cache (probed) > live probe.
pika_gh_prefix() {
    [ -n "$PIKA_GH_PREFIX_RESOLVED" ] && { printf '%s' "$PIKA_GH_PREFIX_RESOLVED"; return 0; }
    pika_accel_enabled || { printf '%s' ""; return 0; }

    local forced cached ts now
    forced="${PIKA_GH_PROXY:-}"
    if [ -z "$forced" ]; then
        forced=$(pika_config_get "gh_proxy" 2>/dev/null || true)
    fi
    if [ -n "$forced" ]; then
        case "$forced" in
            */) ;;
            *) forced="${forced}/" ;;
        esac
        PIKA_GH_PREFIX_RESOLVED="$forced"
        printf '%s' "$forced"
        return 0
    fi

    if [ -f "$PIKA_GH_CACHE" ]; then
        cached=$(sed -n '1p' "$PIKA_GH_CACHE" 2>/dev/null || true)
        ts=$(sed -n '2p' "$PIKA_GH_CACHE" 2>/dev/null || echo 0)
        case "$ts" in ''|*[!0-9]*) ts=0 ;; esac
        now=$(date +%s)
        if [ -n "$cached" ] && [ $((now - ts)) -lt "$PIKA_GH_TTL" ] && _pika_gh_probe "$cached"; then
            PIKA_GH_PREFIX_RESOLVED="$cached"
            printf '%s' "$cached"
            return 0
        fi
    fi

    pika_info "探测 GitHub 加速通道..."
    local best=""
    best=$(_pika_gh_select 2>/dev/null || true)
    PIKA_GH_PREFIX_RESOLVED="$best"
    printf '%s' "$best"
}

# Drop the cached accelerator and probe again (used by the accel menu).
pika_gh_refresh() {
    rm -f "$PIKA_GH_CACHE" 2>/dev/null || true
    PIKA_GH_PREFIX_RESOLVED=""
    pika_gh_prefix
}

# Download one URL with hard timeouts (curl first, wget fallback).
_pika_download_to() {
    local url="$1" out="$2" max_time="${3:-120}"
    if command -v curl >/dev/null 2>&1; then
        curl -fSL --connect-timeout 5 --max-time "$max_time" -o "$out" "$url" 2>/dev/null && return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -T "$max_time" -t 1 -O "$out" "$url" 2>/dev/null && return 0
    fi
    return 1
}

# ============================================================
#  Unified download: pika_fetch
#  Usage:
#    pika_fetch <url_or_relpath> [-o outfile] [--sha256 HASH] [--no-cache]
#                [--max-time SECONDS]
#  Relative paths use the selected PIKA SH site. Absolute GitHub URLs are
#  tried directly first and then through every accelerator, so a mainland
#  host with a blocked github.com still downloads successfully.
# ============================================================
pika_fetch() {
    local url="" outfile="-" use_cache=1 expect_hash=""
    local retries=2 retry_delay=1 max_time=120

    # Parse args
    while [ $# -gt 0 ]; do
        case "$1" in
            -o) outfile="$2"; shift 2 ;;
            --sha256) expect_hash="$2"; shift 2 ;;
            --no-cache) use_cache=0; shift ;;
            --max-time) max_time="$2"; shift 2 ;;
            -*) shift ;;
            *) url="$1"; shift ;;
        esac
    done

    [ -z "$url" ] && { pika_err "pika_fetch: no URL specified"; return 1; }

    # Resolve URL: relative paths use mirror, absolute URLs are direct
    local rel=""
    case "$url" in
        *://*) ;;  # Absolute URL, use as-is
        *)
            rel="${url#/}"
            pika_init_mirror
            url="${PIKA_MIRROR_BASE}/${rel}"
            ;;
    esac

    # Check local cache (by URL hash)
    local cache_key cache_file
    # Cache is valid for 24h: installers/assets change, stale copies are worse
    # than a re-download.
    if [ "$use_cache" = "1" ]; then
        cache_key=$(echo -n "$url" | sha256sum 2>/dev/null | cut -d' ' -f1 || echo -n "$url" | md5sum 2>/dev/null | cut -d' ' -f1 || true)
        cache_file="${PIKA_CACHE_DIR}/fetch_${cache_key}"
        if [ -f "$cache_file" ]; then
            local cache_stale
            cache_stale=$(find "$cache_file" -mmin +1440 2>/dev/null || true)
            if [ -n "$cache_stale" ]; then
                rm -f "$cache_file" 2>/dev/null || true
            fi
        fi
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

        if _pika_download_to "$url" "$tmpf" "$max_time"; then
            success=1
            break
        fi

        [ $attempt -lt $retries ] && sleep "$retry_delay"
    done

    # GitHub direct failed (blocked / reset / throttled): use accelerators.
    if [ "$success" != "1" ] && _pika_is_gh_url "$url" && pika_accel_enabled; then
        local gh_prefix gh_cand
        gh_prefix=$(pika_gh_prefix 2>/dev/null || true)
        for gh_cand in "$gh_prefix" "${PIKA_GH_PREFIXES[@]}"; do
            [ -z "$gh_cand" ] && continue
            case "$url" in
                "$gh_cand"*) continue ;;
            esac
            pika_warn "GitHub 直连失败，尝试加速通道: $gh_cand"
            if _pika_download_to "${gh_cand}${url}" "$tmpf" "$max_time"; then
                success=1
                url="${gh_cand}${url}"
                break
            fi
        done
    fi

    # Relative paths: retry once on the sibling deployment, then on raw GitHub.
    # The mainland edge and the overseas mirror are independent, so a single
    # unreachable site must not break every download.
    if [ "$success" != "1" ] && [ -n "$rel" ]; then
        local alt_base alt
        case "$PIKA_MIRROR_BASE" in
            *pikash.pika.net.cn*) alt_base="$PIKA_SITE_INTL" ;;
            *)                    alt_base="$PIKA_SITE_CN" ;;
        esac
        for alt in "$alt_base" "$PIKA_SITE_RAW"; do
            [ "$alt" = "$PIKA_MIRROR_BASE" ] && continue
            pika_warn "主通道不可用，尝试备用通道: $alt"
            if _pika_download_to "${alt}/${rel}" "$tmpf" "$max_time"; then
                success=1
                url="${alt}/${rel}"
                break
            fi
        done
    fi

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
#  Returns the URL routed through the healthiest accelerator.
#  Non-GitHub URLs are returned unchanged, and when no accelerator is
#  reachable the original URL is returned so the caller can still try it.
#  Usage: download_url=$(gh_url "https://github.com/user/repo/releases/download/v1.0/file.tar.gz")
# ============================================================
gh_url() {
    local url="$1"

    _pika_is_gh_url "$url" || { printf '%s' "$url"; return 0; }
    # Already proxied — never double-wrap.
    case "$url" in
        https://ghfast.top/*|https://gh-proxy.com/*|https://ghproxy.net/*|https://github.524228.xyz/*)
            printf '%s' "$url"
            return 0
            ;;
    esac
    pika_accel_enabled || { printf '%s' "$url"; return 0; }

    local prefix
    prefix=$(pika_gh_prefix 2>/dev/null || true)
    if [ -n "$prefix" ]; then
        printf '%s%s' "$prefix" "$url"
    else
        printf '%s' "$url"
    fi
}

# ============================================================
#  GitHub API query through direct + mirrors: pika_gh_api <path>
#  Example: pika_gh_api "repos/caddyserver/caddy/releases/latest"
# ============================================================
pika_gh_api() {
    local path="${1#/}" body url prefix
    for url in "https://api.github.com/${path}" "https://api.kkgithub.com/${path}"; do
        body=$(curl -fsSL --connect-timeout 3 --max-time 15 \
               -H 'Accept: application/vnd.github+json' "$url" 2>/dev/null || true)
        [ -n "$body" ] && { printf '%s' "$body"; return 0; }
    done
    prefix=$(pika_gh_prefix 2>/dev/null || true)
    if [ -n "$prefix" ]; then
        body=$(curl -fsSL --connect-timeout 3 --max-time 15 \
               -H 'Accept: application/vnd.github+json' \
               "${prefix}https://api.github.com/${path}" 2>/dev/null || true)
        [ -n "$body" ] && { printf '%s' "$body"; return 0; }
    fi
    return 1
}

# ============================================================
#  Remote script execution: pika_run_remote [--errexit] <url_or_relpath> [args...]
#  Downloads script to temp file, then executes it.
#  Avoids curl|bash which steals stdin (problematic for interactive scripts)
#  and gives the download the accelerator + timeout fallback chain.
# ============================================================
pika_run_remote() {
    local strict=0
    if [ "${1:-}" = "--errexit" ]; then
        strict=1
        shift
    fi
    local url="${1:-}"
    [ -n "$url" ] || { pika_err "pika_run_remote: no URL specified"; return 1; }
    shift
    local tmpf
    tmpf=$(mktemp) || pika_die "无法创建临时文件"

    if ! pika_fetch "$url" -o "$tmpf" --no-cache; then
        rm -f "$tmpf"
        pika_err "脚本下载失败: $url"
        return 1
    fi
    if ! bash -n "$tmpf" 2>/dev/null; then
        pika_warn "脚本语法校验失败，仍尝试执行: $url"
    fi

    chmod +x "$tmpf"
    local rc=0
    if [ "$strict" = "1" ]; then
        bash -e "$tmpf" "$@" || rc=$?
    else
        bash "$tmpf" "$@" || rc=$?
    fi
    rm -f "$tmpf"
    return "$rc"
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
