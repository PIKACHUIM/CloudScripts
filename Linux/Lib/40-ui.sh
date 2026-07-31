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

# ---- Pad/truncate a string to a target display width (CJK-aware) ----
_ui_str_pad() {
    local s="$1" target="$2"
    if command -v python3 >/dev/null 2>&1 && python3 -c "" 2>/dev/null; then
        python3 -c "
import sys, unicodedata
s=sys.argv[1]; target=int(sys.argv[2])
w=0; out=[]
for c in s:
    cw=2 if unicodedata.east_asian_width(c) in ('W','F') else 1
    if w+cw>target:
        break
    out.append(c); w+=cw
sys.stdout.write(''.join(out) + ' '*(target-w))
" -- "$s" "$target" 2>/dev/null && return
    fi
    # Fallback: 3-byte+ lead bytes are wide (CJK)
    local _lc="${LC_ALL-__N__}"; LC_ALL=C
    local leads="${s//[$'\x80'-$'\xbf']/}"
    local chars=${#leads}
    local wides="${leads//[!$'\xe0'-$'\xf7']/}"
    local wide=${#wides}
    [ "$_lc" = "__N__" ] && unset LC_ALL || LC_ALL="$_lc"
    local cur=$((chars + wide))
    if [ "$cur" -ge "$target" ]; then
        # Truncate
        local i=0 out=""
        local _lc2="${LC_ALL-__N__}"; LC_ALL=C
        local w2=0
        for ((i=0; i<chars; i++)); do
            local ch="${leads:$i:1}"
            local cw=1
            case "$ch" in [$'\xe0'-$'\xf7']) cw=2 ;; esac
            [ $((w2 + cw)) -gt "$target" ] && break
            out="${out}${ch}"
            w2=$((w2 + cw))
        done
        [ "$_lc2" = "__N__" ] && unset LC_ALL || LC_ALL="$_lc2"
        printf '%s' "$out"
    else
        # Pad with spaces
        printf '%s%*s' "$s" $((target - cur)) ''
    fi
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
#  Header banner — ASCII-art PIKA SH logo
#    ╔═════════════════════════════════════════════════════════╗
#    ║     ██████╗ ██╗██╗  ██╗ █████╗     ███████╗ ██╗  ██╗    ║
#    ║     ██╔══██╗██║██║ ██╔╝██╔══██╗    ██╔════╝ ██║  ██║    ║
#    ║     ██████╔╝██║█████╔╝ ███████║    ███████╗ ███████║    ║
#    ║     ██╔═══╝ ██║██╔═██╗ ██╔══██║    ╚════██║ ██╔══██║    ║
#    ║     ██║     ██║██║  ██╗██║  ██║    ███████║ ██║  ██║    ║
#    ║     ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝ ╚═╝  ╚═╝    ║
#    ║                                                         ║
#    ║                皮卡Linux在线脚本 v1.0                   ║
#    ╚═════════════════════════════════════════════════════════╝
# ============================================================
ui_header() {
    local ver="v${PIKA_VERSION_FULL:-${PIKA_VERSION:-0.0}}"
    local C="${PIKA_CYAN}" N="${PIKA_NC}" Y="${PIKA_YELLOW}"

    clear 2>/dev/null || printf '\033[2J\033[H'
    printf '%b' \
"${C}
  ╔════════════════════════════════════════════════════════╗
  ║   ██████╗ ██╗██╗  ██╗ █████╗     ███████╗ ██╗  ██╗     ║
  ║   ██╔══██╗██║██║ ██╔╝██╔══██╗    ██╔════╝ ██║  ██║     ║
  ║   ██████╔╝██║█████╔╝ ███████║    ███████╗ ███████║     ║
  ║   ██╔═══╝ ██║██╔═██╗ ██╔══██║    ╚════██║ ██╔══██║     ║
  ║   ██║     ██║██║  ██╗██║  ██║    ███████║ ██║  ██║     ║
  ║   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝ ╚═╝  ╚═╝     ║
  ║                                                        ║
  ║               ${Y}皮卡Linux在线脚本 ${ver}${C}                   ║
  ╚════════════════════════════════════════════════════════╝${N}
"
}

# ---- Section title ----
ui_section() {
    printf '\n  %s%s▸ %s%s\n' "${PIKA_YELLOW}" "${PIKA_BOLD}" "$1" "${PIKA_NC}"
}

# ---- Divider ----
ui_divider() {
    printf '  %s%s%s\n' "${PIKA_CYAN}" '──────────────────────────────────────────────────────────' "${PIKA_NC}"
}

# ---- System info block (compact neofetch-lite) ----
ui_sysinfo() {
    local os="${PIKA_DISTRO:-?} ${PIKA_DISTRO_VER:-}"
    local kern; kern=$(uname -r 2>/dev/null || echo "?")
    local arch; arch=$(uname -m 2>/dev/null || echo "?")
    local upt; upt=$(uptime -p 2>/dev/null | sed 's/^up //' || uptime 2>/dev/null | sed 's/.*up *//;s/,[^,]*$//')

    local cpu; cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//;s/  */ /g')
    local cores; cores=$(nproc 2>/dev/null || echo "?")
    [ -n "$cpu" ] && cpu="${cpu} (${cores}C)" || cpu="?"

    local mem; mem=$(free -h 2>/dev/null | awk '/Mem:/{printf "%s / %s", $3, $2}')
    local disk; disk=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
    local ip; ip=$(ip -4 addr show scope global 2>/dev/null | grep inet | awk '{print $2}' | head -1)

    # GPU info — lspci > /sys > glxinfo fallback
    local gpu=""
    if command -v lspci >/dev/null 2>&1; then
        gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/.*: //;s/ (rev.*//' | head -1)
    fi
    [ -z "$gpu" ] && gpu=$(cat /sys/class/drm/card*/device/vendor_name /sys/class/drm/card*/device/product_name 2>/dev/null | paste -sd ' ' -)
    [ -z "$gpu" ] && gpu=$(glxinfo -B 2>/dev/null | grep -i 'opengl renderer' | sed 's/.*: //')
    [ -n "$gpu" ] && gpu="${gpu:0:45}" || gpu="?"

    # Motherboard / vendor (DMI)
    local board=""
    board=$(cat /sys/devices/virtual/dmi/id/board_vendor /sys/devices/virtual/dmi/id/board_name 2>/dev/null | paste -sd ' ' -)
    [ -z "$board" ] && board=$(cat /sys/devices/virtual/dmi/id/sys_vendor /sys/devices/virtual/dmi/id/product_name 2>/dev/null | paste -sd ' ' -)
    [ -z "$board" ] && board="Virtual Machine"

    # Shell + resolution
    local shell_name; shell_name=$(basename "${SHELL:-sh}" 2>/dev/null)
    local res=""; res=$(xdpyinfo 2>/dev/null | grep 'dimensions' | awk '{print $2}' | head -1)

    local container_info=""
    pika_is_container 2>/dev/null && container_info=" (容器环境)"

    local C="${PIKA_CYAN}" N="${PIKA_NC}" G="${PIKA_GREEN}" B="${PIKA_BOLD}" Y="${PIKA_YELLOW}"

    printf '%b' \
"${C}
  ┌────────────────────────────────────────────────────────┐
  │  ${G}操作系统${C}    ${B}${os}${C}
  │  ${G}内核版本${C}    ${kern} ${arch}
  │  ${G}运行时间${C}    ${upt:-?}
  │  ${G}硬件平台${C}    ${board:0:40}${Y}${container_info}${C}
  │  ${G}网络地址${C}    ${B}${ip:-?}${N}
  ${C}├────────────────────────────────────────────────────────┤
  │  ${G}CPU 型号${C}   ${cpu:0:40}
  │  ${G}GPU 型号${C}   ${gpu}
  │  ${G}内存用量${C}   ${mem:-?}
  │  ${G}磁盘用量${C}   ${disk:-?}${N}
  ${C}└────────────────────────────────────────────────────────┘
${N}"
}

# ============================================================
#  Menu item:  [1]  Name                Description
# ============================================================
ui_item() {
    local num="$1" name="$2" desc="${3:-}"
    # Column layout:  2 (indent) + 4 ([N]) + 2 (gap) + name_col (14) + 2 (gap) + desc_col (32) = 56 cols
    local name_col=14
    local desc_col=32
    local name_padded; name_padded=$(_ui_str_pad "$name" "$name_col")
    local desc_padded; desc_padded=$(_ui_str_pad "$desc" "$desc_col")

    if [ -n "$desc" ]; then
        printf '  %s%4s%s  %s%s%s  %s%s%s\n' \
            "${PIKA_GREEN}" "[$num]" "${PIKA_NC}" \
            "${PIKA_BOLD}" "$name_padded" "${PIKA_NC}" \
            "${PIKA_BLUE}" "$desc_padded" "${PIKA_NC}"
    else
        printf '  %s%4s%s  %s%s%s\n' \
            "${PIKA_GREEN}" "[$num]" "${PIKA_NC}" \
            "${PIKA_BOLD}" "$name_padded" "${PIKA_NC}"
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
    ui_divider
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
    local line='─────────────────────────────────────────'

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
