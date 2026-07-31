#!/usr/bin/env bash
# ============================================================
#  PIKA SH - I18n / Localization
#  Uses flat variable names (T_key_name=value) — no associative
#  arrays needed.  Keys use dot separators in t() calls, which
#  are mapped to underscores internally.
#  Requires: 00-core.sh loaded first
# ============================================================
set -e

# ---- Require bash ----
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Please run: bash Menu.sh" >&2
    exit 1
fi

# ============================================================
#  Language detection
# ============================================================
i18n_detect() {
    [ -n "${PIKA_LANG:-}" ] && { echo "$PIKA_LANG"; return; }
    local persisted; persisted=$(pika_config_get "lang" 2>/dev/null || true)
    [ -n "$persisted" ] && { echo "$persisted"; return; }
    # Default to Chinese (项目主要面向中文用户); users can override via PIKA_LANG= or --lang=
    echo "zh_CN"
}

# ============================================================
#  Translation function — flat variables, no associative arrays
#  t() converts "app.name" → variable T_app_name
# ============================================================
t() {
    local key="$1"; shift
    local varname="T_${key//./_}"
    local msg="${!varname}"
    if [ $# -gt 0 ]; then
        # shellcheck disable=SC2059
        printf "${msg:-$key}" "$@"
    else
        printf '%s' "${msg:-$key}"
    fi
}

# ============================================================
#  Load language pack — local first, then remote CDN fallback
# ============================================================
_i18n_source_pack() {
    local lang="$1"   # e.g., "zh_CN" or "en_US"
    local pack_file="I18n/${lang}.sh"
    local local_path remote_url loaded=0

    # ----- Try PIKA_BASE/Linux/I18n/xx.sh (correct local path) -----
    local_path="${PIKA_BASE:-.}/Linux/${pack_file}"
    if [ -f "$local_path" ]; then
        . "$local_path"
        loaded=1
    fi

    # ----- Try CDN fallback -----
    if [ "$loaded" = "0" ]; then
        local tmpf; tmpf=$(mktemp 2>/dev/null || echo "/tmp/pika-i18n-$$")
        # Try multiple CDN sources
        for base_url in \
            "https://pikash.opkg.cn/Linux/${pack_file}" \
            "https://raw.githubusercontent.com/PIKACHUIM/CloudScripts/main/Linux/${pack_file}" \
            "https://github.524228.xyz/PIKACHUIM/CloudScripts/main/Linux/${pack_file}"
        do
            if curl -fsSL "$base_url" -o "$tmpf" 2>/dev/null; then
                . "$tmpf"
                loaded=1
                break
            fi
            if wget -qO "$tmpf" "$base_url" 2>/dev/null; then
                . "$tmpf"
                loaded=1
                break
            fi
        done
        rm -f "$tmpf" 2>/dev/null || true
    fi

    return "$loaded"
}

i18n_load() {
    local lang="${1:-$(i18n_detect)}"

    # Always load zh_CN as base (most complete)
    _i18n_source_pack "zh_CN" || true

    # Overlay target language
    if [ "$lang" != "zh_CN" ]; then
        _i18n_source_pack "$lang" || true
    fi

    PIKA_LANG="$lang"
    export PIKA_LANG
}

# ============================================================
#  Set language and persist
# ============================================================
i18n_set_lang() {
    local lang="$1"
    case "$lang" in
        zh_CN|en_US) ;;
        zh) lang="zh_CN" ;;
        en) lang="en_US" ;;
        *) pika_warn "Unsupported language: $lang (available: zh_CN, en_US)"; return 1 ;;
    esac
    PIKA_LANG="$lang"
    pika_config_set "lang" "$lang"
    i18n_load "$lang"
    pika_info "Language: $lang"
}

# ---- Auto-load on source ----
i18n_load

# ---- Mark lib as loaded ----
PIKA_I18N_LOADED=1
