#!/usr/bin/env bash
# ============================================================
#  PIKA SH - UI / Display Library
#  Menu rendering, CJK-aware alignment, color output
#  Requires: 00-core.sh, 50-i18n.sh loaded first
# ============================================================
set -e

# ---- Color shortcuts (already defined in 00-core, re-export for convenience) ----
: "${PIKA_RED:=$(printf '\033[0;31m')}"; : "${PIKA_GREEN:=$(printf '\033[0;32m')}"
: "${PIKA_YELLOW:=$(printf '\033[1;33m')}"; : "${PIKA_BLUE:=$(printf '\033[0;34m')}"
: "${PIKA_CYAN:=$(printf '\033[0;36m')}"; : "${PIKA_MAGENTA:=$(printf '\033[0;35m')}"
: "${PIKA_BOLD:=$(printf '\033[1m')}"; : "${PIKA_NC:=$(printf '\033[0m')}"

# ============================================================
#  CJK-aware display width (pure bash, no external deps)
#  Uses python3 if available (accurate east-asian-width),
#  otherwise a fast UTF-8 byte heuristic (3/4-byte lead -> 2-wide).
# ============================================================
_ui_str_width() {
    local s="$1"
    # Prefer python3 for accuracy
    if command -v python3 >/dev/null 2>&1 && python3 -c "" 2>/dev/null; then
        local w
        w=$(python3 -c "import sys,unicodedata; s=sys.argv[1]; print(sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s))" -- "$s" 2>/dev/null)
        if [ -n "$w" ] && [ "$w" -ge 0 ] 2>/dev/null; then
            echo "$w"
            return
        fi
    fi

    # Fallback: count chars and 3/4-byte lead bytes under LC_ALL=C
    local _lc_saved="${LC_ALL-__PIKA_UNSET__}"
    LC_ALL=C

    local leads="${s//[$'\x80'-$'\xbf']/}"
    local chars=${#leads}
    local wides="${leads//[!$'\xe0'-$'\xf7']/}"
    local wide=${#wides}

    if [ "$_lc_saved" = "__PIKA_UNSET__" ]; then unset LC_ALL; else LC_ALL="$_lc_saved"; fi

    echo $((chars + wide))
}

# ---- Repeat a single character N times (no external deps) ----
_ui_repeat_char() {
    local char="$1" count="${2:-0}"
    case "$count" in ''|*[!0-9]*) return ;; esac
    local s="" i=0
    while [ "$i" -lt "$count" ]; do
        s="${s}${char}"
        i=$((i + 1))
    done
    printf '%s' "$s"
}

# ---- Terminal width ----
_pika_term_width() {
    local w="${COLUMNS:-}"
    [ -z "$w" ] && w=$(tput cols 2>/dev/null || echo 80)
    case "$w" in ''|*[!0-9]*) w=80 ;; esac
    echo "$w"
}

# ---- Clear screen ----
ui_clear() { clear 2>/dev/null || printf '\033[2J\033[H'; }

# ============================================================
#  Header banner — ASCII-art PIKA logo (fixed width, no CJK calc needed)
#    ╔══════════════════════════════════════════════════╗
#    ║      ██████╗ ██╗██╗  ██╗ █████╗                  ║
#    ║      ██╔══██╗██║██║ ██╔╝██╔══██╗                 ║
#    ║      ██████╔╝██║█████╔╝ ███████║                 ║
#    ║      ██╔═══╝ ██║██╔═██╗ ██╔══██║                 ║
#    ║      ██║     ██║██║  ██╗██║  ██║                 ║
#    ║      ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝                 ║
#    ║                                                  ║
#    ║      皮卡在线脚本托管平台 — 总菜单            v1.0  ║
#    ╚══════════════════════════════════════════════════╝
# ============================================================
ui_header() {
    local ver="v${PIKA_VERSION_FULL:-${PIKA_VERSION:-0.0}}"
    local c="${PIKA_CYAN}" n="${PIKA_NC}" b="${PIKA_BOLD}"

    clear 2>/dev/null || printf '\033[2J\033[H'
    printf '%s\n' "$c"
    printf '  ╔══════════════════════════════════════════════════╗\n'
    printf '  ║      %s██████╗%s ██╗██╗  ██╗ %s█████╗%s                  ║\n' "$b" "$c" "$b" "$c"
    printf '  ║      %s██╔══██╗%s██║██║ ██╔╝%s██╔══██╗%s                 ║\n' "$b" "$c" "$b" "$c"
    printf '  ║      %s██████╔╝%s██║█████╔╝ %s███████║%s                 ║\n' "$b" "$c" "$b" "$c"
    printf '  ║      %s██╔═══╝%s ██║██╔═██╗ %s██╔══██║%s                 ║\n' "$b" "$c" "$b" "$c"
    printf '  ║      %s██║%s     ██║██║  ██╗%s██║  ██║%s                 ║\n' "$b" "$c" "$b" "$c"
    printf '  ║      %s╚═╝%s     ╚═╝╚═╝  ╚═╝%s╚═╝  ╚═╝%s                 ║\n' "$b" "$c" "$b" "$c"
    printf '  ║                                                  ║\n'
    printf '  ║      %s%s%s         %s%s%s  ║\n' \
        "$b" "$(t 'app.name')" "$c" "$PIKA_GREEN" "$ver" "$c"
    printf '  ╚══════════════════════════════════════════════════╝\n'
    printf '%s' "$n"
}

# ---- Section title ----
ui_section() {
    printf '\n  %s%s▸ %s%s\n' "${PIKA_YELLOW}" "${PIKA_BOLD}" "$1" "${PIKA_NC}"
}

# ---- Divider ----
ui_divider() {
    printf '  %s%s%s\n' "${PIKA_CYAN}" '──────────────────────────────────────────────────' "${PIKA_NC}"
}

# ============================================================
#  Menu item:  [1]  Name                Description
# ============================================================
ui_item() {
    local num="$1" name="$2" desc="${3:-}"
    local name_col=30
    local name_w; name_w=$(_ui_str_width "$name")
    local pad=$((name_col - name_w))
    [ "$pad" -lt 2 ] && pad=2
    local spacing; spacing=$(printf '%*s' "$pad" '')

    if [ -n "$desc" ]; then
        printf '  %s%4s%s  %s%s%s%s  %s%s%s\n' \
            "${PIKA_GREEN}" "[$num]" "${PIKA_NC}" \
            "${PIKA_BOLD}" "$name" "${PIKA_NC}" "$spacing" \
            "${PIKA_BLUE}" "$desc" "${PIKA_NC}"
    else
        printf '  %s%4s%s  %s%s%s\n' \
            "${PIKA_GREEN}" "[$num]" "${PIKA_NC}" \
            "${PIKA_BOLD}" "$name" "${PIKA_NC}"
    fi
}

# ============================================================
#  Render a data-driven menu
#  Usage: ui_menu "TITLE" "MENU_ARRAY_NAME" ["BACK_LABEL"]
#  Array entries: "key|title_i18n_key|desc_i18n_key|handler"
# ============================================================
ui_menu() {
    local title="$1" array_name="$2" back_label="${3:-}"
    local -n entries="$array_name"

    ui_section "$title"
    local idx=1 entry key title_key desc_key handler
    for entry in "${entries[@]}"; do
        IFS='|' read -r key title_key desc_key handler <<< "$entry"
        ui_item "$idx" "$(t "$title_key")" "$(t "$desc_key")"
        idx=$((idx + 1))
    done

    [ -n "$back_label" ] && ui_item "0" "$back_label" ""

    printf '\n'
    printf '  %s ' "$(t 'menu.prompt')"
}

# ============================================================
#  Dispatch menu selection
#  Returns: 0 = handled, 1 = invalid, 2 = back
# ============================================================
ui_dispatch() {
    local -n ents="$1"
    local sel="${2:-0}"

    [ "$sel" = "0" ] && return 2

    local idx=1 entry key title_key desc_key handler
    for entry in "${ents[@]}"; do
        if [ "$idx" = "$sel" ]; then
            IFS='|' read -r key title_key desc_key handler <<< "$entry"
            if [ -n "$handler" ] && declare -F "$handler" >/dev/null 2>&1; then
                "$handler" "$key"
                return $?
            fi
            pika_err "$(t 'ui.nohandler'): ${handler:-N/A}"
            return 1
        fi
        idx=$((idx + 1))
    done

    return 1
}

# ============================================================
#  Install confirmation dialog
#    ┌──────────────────────────────────────┐
#    │ 即将安装: Docker CE                  │
#    ├──────────────────────────────────────┤
#    │   容器引擎 + 国内镜像加速            │
#    └──────────────────────────────────────┘
# ============================================================
ui_confirm_install() {
    local name="$1" desc="${2:-}" version="${3:-}" url="${4:-}"
    local line='──────────────────────────────────────'

    printf '\n'
    printf '  %s┌%s┐%s\n' "${PIKA_CYAN}" "$line" "${PIKA_NC}"
    printf '  %s│%s %s%s%s %s│%s\n' "${PIKA_CYAN}" "${PIKA_NC}" "${PIKA_BOLD}" "$(t 'ui.install'): ${name}" "${PIKA_NC}" "${PIKA_CYAN}" "${PIKA_NC}"
    printf '  %s├%s┤%s\n' "${PIKA_CYAN}" "$line" "${PIKA_NC}"
    [ -n "$desc" ]    && printf '  %s│%s   %s %s│%s\n' "${PIKA_CYAN}" "${PIKA_NC}" "${desc}" "${PIKA_CYAN}" "${PIKA_NC}"
    [ -n "$version" ] && printf '  %s│%s   %s: %s %s│%s\n' "${PIKA_CYAN}" "${PIKA_NC}" "$(t 'ui.version')" "${version}" "${PIKA_CYAN}" "${PIKA_NC}"
    [ -n "$url" ]     && printf '  %s│%s   %s%s%s %s│%s\n' "${PIKA_CYAN}" "${PIKA_NC}" "${PIKA_BLUE}" "${url}" "${PIKA_NC}" "${PIKA_CYAN}" "${PIKA_NC}"
    printf '  %s└%s┘%s\n' "${PIKA_CYAN}" "$line" "${PIKA_NC}"

    pika_confirm "$(t 'ui.confirm')"
}

# ---- Print tip ----
ui_tip() {
    printf '  %s💡 %s%s\n' "${PIKA_MAGENTA}" "$*" "${PIKA_NC}"
}

# ---- Mark lib as loaded ----
PIKA_UI_LOADED=1
