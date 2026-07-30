#!/usr/bin/env bash
# ============================================================
#  PIKA SH - UI / Display Library
#  Menu rendering, CJK-aware alignment, color output
#  Requires: 00-core.sh, 50-i18n.sh loaded first
# ============================================================
set -e

# ---- Color shortcuts (already defined in 00-core, re-export for convenience) ----
: "${PIKA_RED:=\\033[0;31m}"; : "${PIKA_GREEN:=\\033[0;32m}"
: "${PIKA_YELLOW:=\\033[1;33m}"; : "${PIKA_BLUE:=\\033[0;34m}"
: "${PIKA_CYAN:=\\033[0;36m}"; : "${PIKA_MAGENTA:=\\033[0;35m}"
: "${PIKA_BOLD:=\\033[1m}"; : "${PIKA_NC:=\\033[0m}"

# ---- Terminal width ----
_pika_term_width() {
    tput cols 2>/dev/null || echo 80
}

# ---- Clear screen ----
ui_clear() { clear 2>/dev/null || printf '\033[2J\033[H'; }

# ---- Print header banner ----
ui_header() {
    local w; w=$(_pika_term_width)
    local _line; _line=$(_ui_repeat_char '═' $((w-4)))
    local ver_full="${PIKA_VERSION_FULL:-${PIKA_VERSION:-0.0}}"
    local ver_pad; ver_pad=$(( w - 9 - ${#ver_full} - 1 ))
    [ "$ver_pad" -lt 1 ] && ver_pad=1
    echo -e "${PIKA_CYAN}"
    echo "  ╔${_line}╗"
    echo "  ║  ${PIKA_BOLD}$(t 'app.name')${PIKA_NC}${PIKA_CYAN}$(printf '%*s' "$ver_pad" '')v${ver_full}  ║"
    echo "  ╚${_line}╝"
    echo -e "${PIKA_NC}"
}

# ---- Print section title ----
ui_section() {
    echo -e "\n  ${PIKA_YELLOW}${PIKA_BOLD}▸ $1${PIKA_NC}"
}

# ---- Print divider ----
ui_divider() {
    local _line; _line=$(_ui_repeat_char '─' $(($(_pika_term_width)-4)))
    echo -e "  ${PIKA_CYAN}${_line}${PIKA_NC}"
}

# ---- Repeat a single character N times (no external deps) ----
_ui_repeat_char() {
    local char="$1" count="$2"
    [ "$count" -le 0 ] 2>/dev/null && return
    local s=""
    local i=0
    while [ $i -lt "$count" ]; do
        s="${s}${char}"
        i=$((i+1))
    done
    echo "$s"
}

# ---- Print a menu item: [number] name ........ description ----
# Handles CJK character width for proper alignment
ui_item() {
    local num="$1" name="$2" desc="${3:-}"
    local target_width=32  # Name column target display width

    local name_w; name_w=$(_ui_str_width "$name")
    local pad=$((target_width - name_w))
    [ $pad -lt 2 ] && pad=2
    local spacing; spacing=$(printf '%*s' $pad '')

    printf "  ${PIKA_GREEN}%4s${PIKA_NC}  ${PIKA_BOLD}%s${PIKA_NC}%s${PIKA_BLUE}%s${PIKA_NC}\n" \
        "[$num]" "$name" "$spacing" "$desc"
}

# ---- CJK-aware string display width ----
# Prefers python3 > python > pure bash fallback
_ui_str_width() {
    local s="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import sys,unicodedata; s=sys.argv[1]; print(sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s))" -- "$s" 2>/dev/null && return
    elif command -v python >/dev/null 2>&1; then
        python -c "import sys,unicodedata; s=sys.argv[1]; print(sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s))" -- "$s" 2>/dev/null && return
    fi

    # Pure bash fallback: count bytes in multi-byte ranges as 2-wide
    local w=0 c i=0 len=${#s}
    while [ $i -lt $len ]; do
        c="${s:$i:1}"
        local byte
        byte=$(printf '%d' "'$c" 2>/dev/null || echo "0")
        # Ensure byte is numeric before arithmetic comparison
        case "$byte" in
            ''|*[!0-9]*) byte=0 ;;
        esac
        if [ "$byte" -ge 19968 ] 2>/dev/null; then w=$((w+2))  # U+4E00+
        elif [ "$byte" -ge 12288 ] 2>/dev/null && [ "$byte" -le 12543 ] 2>/dev/null; then w=$((w+2))
        elif [ "$byte" -ge 65072 ] 2>/dev/null && [ "$byte" -le 65119 ] 2>/dev/null; then w=$((w+2))
        elif [ "$byte" -ge 63744 ] 2>/dev/null && [ "$byte" -le 64045 ] 2>/dev/null; then w=$((w+2))
        else w=$((w+1))
        fi
        i=$((i+1))
    done
    echo $w
}

# ---- Render a data-driven menu ----
# Usage: ui_menu "MENU_TITLE" "MENU_ARRAY_NAME" ["BACK_LABEL"]
# The array should contain entries like: "key|title_i18n_key|desc_i18n_key|handler"
ui_menu() {
    local title="$1" array_name="$2" back_label="${3:-}"
    local -n entries="$array_name"

    ui_section "$title"
    local idx=1
    for entry in "${entries[@]}"; do
        local key title_key desc_key handler
        IFS='|' read -r key title_key desc_key handler <<< "$entry"
        ui_item "$idx" "$(t "$title_key")" "$(t "$desc_key")"
        idx=$((idx + 1))
    done

    if [ -n "$back_label" ]; then
        ui_item "0" "$back_label" ""
    fi

    echo ""
    printf "  $(t 'menu.prompt') "
}

# ---- Dispatch menu selection ----
# Usage: ui_dispatch MENU_ARRAY_NAME selection
# Returns 0 on success, non-zero on invalid selection or back (selection=0)
ui_dispatch() {
    local -n ents="$1"
    local sel="${2:-0}"

    # 0 = back
    [ "$sel" = "0" ] && return 2

    local idx=1 found=0
    for entry in "${ents[@]}"; do
        if [ "$idx" = "$sel" ]; then
            local key title_key desc_key handler
            IFS='|' read -r key title_key desc_key handler <<< "$entry"
            if [ -n "$handler" ] && declare -F "$handler" >/dev/null 2>&1; then
                "$handler" "$key"
                return $?
            else
                pika_err "未实现的处理函数: ${handler:-N/A}"
                return 1
            fi
            found=1
            break
        fi
        idx=$((idx + 1))
    done

    [ "$found" = "0" ] && { pika_warn "无效选择: $sel"; return 1; }
}

# ---- Install confirmation dialog ----
ui_confirm_install() {
    local name="$1" desc="$2" version="${3:-}" url="${4:-}"

    local _hdr; _hdr=$(_ui_repeat_char '─' $(($(_pika_term_width)-6)))
    echo ""
    echo -e "  ${PIKA_CYAN}┌${_hdr}┐${PIKA_NC}"
    printf "  ${PIKA_CYAN}│${PIKA_NC} ${PIKA_BOLD}$(t 'ui.install')${PIKA_NC}: %-$(($(_pika_term_width)-17))s ${PIKA_CYAN}│${PIKA_NC}\n" "$name"
    echo -e "  ${PIKA_CYAN}├${_hdr}┤${PIKA_NC}"
    printf "  ${PIKA_CYAN}│${PIKA_NC} %-$(($(_pika_term_width)-8))s ${PIKA_CYAN}│${PIKA_NC}\n" "  $desc"
    [ -n "$version" ] && printf "  ${PIKA_CYAN}│${PIKA_NC} $(t 'ui.version'): %-$(($(_pika_term_width)-18))s ${PIKA_CYAN}│${PIKA_NC}\n" "$version"
    [ -n "$url" ] && printf "  ${PIKA_CYAN}│${PIKA_NC} %-$(($(_pika_term_width)-8))s ${PIKA_CYAN}│${PIKA_NC}\n" "  $url"
    echo -e "  ${PIKA_CYAN}└${_hdr}┘${PIKA_NC}"

    pika_confirm "$(t 'ui.confirm')"
}

# ---- Print tip ----
ui_tip() {
    echo -e "  ${PIKA_MAGENTA}💡 $*${PIKA_NC}"
}

# ---- Mark lib as loaded ----
PIKA_UI_LOADED=1
