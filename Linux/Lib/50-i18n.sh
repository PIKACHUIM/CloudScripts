#!/usr/bin/env bash
# ============================================================
#  PIKA SH - I18n / Localization
#  Auto-detect locale, load language pack, t() translation function
#  Requires: 00-core.sh loaded first
# ============================================================
set -e

# ---- Language detection order ----
# PIKA_LANG env > /etc/pika-sh/config > LC_ALL > LC_MESSAGES > LANG > fallback (zh_CN)
i18n_detect() {
    # 1. Explicit env var
    [ -n "${PIKA_LANG:-}" ] && { echo "$PIKA_LANG"; return; }

    # 2. Persisted config
    local persisted; persisted=$(pika_config_get "lang" 2>/dev/null || true)
    [ -n "$persisted" ] && { echo "$persisted"; return; }

    # 3. System locale
    local sys_lang="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    sys_lang="${sys_lang%%.*}"  # Strip encoding suffix: zh_CN.UTF-8 -> zh_CN

    case "${sys_lang,,}" in
        zh_cn|zh_sg|zh_hk|zh_tw|zh) echo "zh_CN" ;;
        en_us|en_gb|en_au|en_ca|en_nz|en_ie|en) echo "en_US" ;;
        *) echo "zh_CN" ;;  # Default: Chinese
    esac
}

# ---- Translation table ----
declare -A T

# ---- Load language pack ----
# Always load zh_CN first (complete fallback), then overlay target language
i18n_load() {
    local lang="${1:-$(i18n_detect)}"

    # Base: zh_CN (most complete, serves as fallback)
    local base_pack="${PIKA_LIB_DIR:-${PIKA_BASE:-.}/Linux/Lib/..}/I18n/zh_CN.sh"
    if [ -f "$base_pack" ]; then
        source "$base_pack"
    elif [ -f "${PIKA_BASE:-.}/Linux/I18n/zh_CN.sh" ]; then
        source "${PIKA_BASE:-.}/Linux/I18n/zh_CN.sh"
    fi

    # Overlay: target language
    if [ "$lang" != "zh_CN" ]; then
        local pack="${PIKA_LIB_DIR:-${PIKA_BASE:-.}/Linux/Lib/..}/I18n/${lang}.sh"
        if [ -f "$pack" ]; then
            source "$pack"
        elif [ -f "${PIKA_BASE:-.}/Linux/I18n/${lang}.sh" ]; then
            source "${PIKA_BASE:-.}/Linux/I18n/${lang}.sh"
        fi
    fi

    PIKA_LANG="$lang"
    export PIKA_LANG
}

# ---- Translate a key ----
# Usage: t "key" [arg1 arg2 ...]  # printf-style substitution
t() {
    local key="$1"; shift
    local msg="${T[$key]:-$key}"  # Missing key: return key itself (never blank)
    if [ $# -gt 0 ]; then
        # shellcheck disable=SC2059
        printf "$msg" "$@"
    else
        echo -n "$msg"
    fi
}

# ---- Set language and persist ----
i18n_set_lang() {
    local lang="$1"
    case "$lang" in
        zh_CN|en_US) ;;
        zh) lang="zh_CN" ;;
        en) lang="en_US" ;;
        *) pika_warn "不支持的语言: $lang，可用: zh_CN, en_US"; return 1 ;;
    esac
    PIKA_LANG="$lang"
    pika_config_set "lang" "$lang"
    i18n_load "$lang"
    pika_info "语言已切换为: $lang"
}

# ---- Auto-load on source ----
i18n_load

# ---- Mark lib as loaded ----
PIKA_I18N_LOADED=1
