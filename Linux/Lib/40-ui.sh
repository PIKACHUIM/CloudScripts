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

# ---- Set to 1 by ui_menu(), read by the menu loops ----
UI_MENU_RENDERED=0

# ============================================================
#  CJK-aware display width (pure bash, no external deps)
#  Uses python3 if available (accurate east-asian-width),
#  otherwise a fast UTF-8 byte heuristic (3/4-byte lead -> 2-wide).
# ============================================================
# ---- python3 probe (cached once at load: on Windows the store alias is slow/stub) ----
# Must run outside command substitution, otherwise the cache is lost per subshell.
_ui_detect_python() {
    [ -n "${_UI_HAS_PY:-}" ] && return 0
    if command -v python3 >/dev/null 2>&1 \
        && [ "$(python3 -c 'print(1)' 2>/dev/null)" = "1" ]; then
        _UI_HAS_PY=1
    else
        _UI_HAS_PY=0
    fi
}
_ui_detect_python

_ui_py_ok() {
    [ -n "${_UI_HAS_PY:-}" ] || _ui_detect_python
    [ "$_UI_HAS_PY" = "1" ]
}

_ui_str_width() {
    local s="$1"
    # Prefer python3 for accuracy
    if _ui_py_ok; then
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

# ---- Fast display width (pure bash, no subprocess) ----
# Counts UTF-8 lead bytes as one column and 3/4-byte leads (CJK, emoji) as two.
_ui_w_fast() {
    local s="$1" _lc="${LC_ALL-__PIKA_UNSET__}"
    local leads chars wides wide
    LC_ALL=C
    leads="${s//[$'\x80'-$'\xbf']/}"
    chars=${#leads}
    wides="${leads//[!$'\xe0'-$'\xf7']/}"
    wide=${#wides}
    if [ "$_lc" = "__PIKA_UNSET__" ]; then unset LC_ALL; else LC_ALL="$_lc"; fi
    printf '%s' $((chars + wide))
}

# ---- Pad/truncate a string to exactly N display columns (CJK-aware) ----
# The result is always N columns wide, so menu rows line up with the divider.
_ui_str_pad() {
    local s="${1-}" target="${2-0}" out w cut pad
    case "$target" in ''|*[!0-9]*) printf '%s' "$s"; return 0 ;; esac
    [ "$target" -le 0 ] && return 0

    # Prefer python3 for exact east-asian-width; otherwise use the bash heuristic.
    if _ui_py_ok; then
        python3 -c '
import sys, unicodedata
s = sys.argv[1]; target = int(sys.argv[2])
def w(t):
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in t)
if w(s) > target:
    cut = max(0, target - 3)
    out, acc = [], 0
    for c in s:
        cw = 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1
        if acc + cw > cut:
            break
        out.append(c); acc += cw
    s = "".join(out) + "..."
    if w(s) > target:
        s = "".join(out)
sys.stdout.write(s + " " * max(0, target - w(s)))
' -- "$s" "$target" 2>/dev/null && return 0
        _UI_HAS_PY=0
    fi

    out="$s"
    w=$(_ui_w_fast "$out")
    if [ "$w" -gt "$target" ]; then
        cut=$((target - 3))
        [ "$cut" -lt 0 ] && cut=0
        while [ -n "$out" ] && [ "$(_ui_w_fast "$out")" -gt "$cut" ]; do
            out="${out%?}"
        done
        out="${out}..."
        w=$(_ui_w_fast "$out")
        if [ "$w" -gt "$target" ]; then
            out="${out%???}"
            w=$(_ui_w_fast "$out")
        fi
        printf '%s' "$out"
        printf '%*s' "$((target - w))" ''
        return 0
    fi

    pad=$((target - w))
    printf '%s%*s' "$out" "$pad" ''
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

# ---- Divider (width defaults to the banner width) ----
ui_divider() {
    local w="${1:-58}"
    case "$w" in ''|*[!0-9]*) w=58 ;; esac
    printf '  %s%s%s\n' "${PIKA_CYAN}" "$(_ui_repeat_char '─' "$w")" "${PIKA_NC}"
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
#  Menu item:  [1]  Name            Description
#  Total width is fixed so every row matches the 58-char divider:
#    2 (indent) + 4 ([N]) + 2 + 12 (name) + 2 + 38 (desc) = 60
# ============================================================
_UI_NUM_COL=4
_UI_GAP=2
_UI_NAME_COL=12
_UI_DESC_COL=38
_UI_ROW_W=60

ui_item() {
    local num="$1" name="$2" desc="${3:-}"
    local name_padded desc_padded
    name_padded=$(_ui_str_pad "$name" "$_UI_NAME_COL")
    desc_padded=$(_ui_str_pad "$desc" "$_UI_DESC_COL")

    printf '  %s%*s%s  %s%s%s  %s%s%s\n' \
        "${PIKA_GREEN}" "$_UI_NUM_COL" "[$num]" "${PIKA_NC}" \
        "${PIKA_BOLD}" "$name_padded" "${PIKA_NC}" \
        "${PIKA_BLUE}" "$desc_padded" "${PIKA_NC}"
}

# ============================================================
#  Render a data-driven menu
#  Usage: ui_menu "TITLE" "MENU_ARRAY_NAME" ["BACK_LABEL"]
#  Array entries: "key|title_i18n_key|desc_i18n_key|handler"
# ============================================================
# Size the columns from one menu's own content so nothing gets cut off
# ("安装 NetPanel" must stay readable).  Titles always win: if the menu would
# be wider than the terminal, only the description column is shortened.
# Sets: _UI_NAME_COL, _UI_DESC_COL, _UI_ROW_W (total columns incl. 2-space indent).
ui_menu_size() {
    local array_name="$1" back_label="${2:-}"
    local -n _ui_entries="$array_name"

    local entry key title_key desc_key handler nw dw name_col=12 desc_col=38
    for entry in "${_ui_entries[@]}"; do
        IFS='|' read -r key title_key desc_key handler <<< "$entry"
        nw=$(_ui_str_width "$(t "$title_key")")
        dw=$(_ui_str_width "$(t "$desc_key")")
        [ "$nw" -gt "$name_col" ] && name_col=$nw
        [ "$dw" -gt "$desc_col" ] && desc_col=$dw
    done
    if [ -n "$back_label" ]; then
        nw=$(_ui_str_width "$back_label")
        [ "$nw" -gt "$name_col" ] && name_col=$nw
    fi

    local fixed=$((2 + _UI_NUM_COL + _UI_GAP + name_col + _UI_GAP))
    local avail; avail=$(_pika_term_width)
    if [ "$avail" -gt "$fixed" ] && [ $((fixed + desc_col)) -gt "$avail" ]; then
        desc_col=$((avail - fixed))
    fi
    [ "$desc_col" -lt 10 ] && desc_col=10

    _UI_NAME_COL="$name_col"
    _UI_DESC_COL="$desc_col"
    _UI_ROW_W=$((fixed + desc_col))
}

ui_menu() {
    local title="$1" array_name="$2" back_label="${3:-}"
    local -n entries="$array_name"

    # 记录“本次动作里画过菜单”，菜单循环据此决定是否需要暂停等回车：
    # 画过菜单说明已经和用户交互过，没画过说明只是打印结果（列表/状态/日志）。
    UI_MENU_RENDERED=1

    ui_menu_size "$array_name" "$back_label"
    local row_w="$_UI_ROW_W"

    ui_divider "$((row_w - 2))"
    ui_section "$title"
    local idx=1 entry key title_key desc_key handler
    for entry in "${entries[@]}"; do
        IFS='|' read -r key title_key desc_key handler <<< "$entry"
        ui_item "$idx" "$(t "$title_key")" "$(t "$desc_key")"
        idx=$((idx + 1))
    done

    [ -n "$back_label" ] && ui_item "0" "$back_label" ""

    printf '\n'
    ui_divider "$((row_w - 2))"
    printf '  %s ' "$(t 'menu.prompt')"
}

# ============================================================
#  Pause so printed results stay readable
#  Menus clear the screen before redrawing, so an action that only
#  prints (site list, status, logs, probe result) would flash by.
#  ui_dispatch callers pause with this unless the handler drew a menu.
# ============================================================
ui_pause() {
    printf '\n  %s ' "$(t 'ui.press_enter')"
    read -r _ || true
    return 0
}

# ============================================================
#  Back / quit key detection
#  0 = back (as printed in menus), b/back and q/quit/exit also work
# ============================================================
ui_is_back() {
    case "${1:-}" in
        0|b|B|back|BACK|q|Q|quit|QUIT|exit|EXIT) return 0 ;;
    esac
    return 1
}

# ============================================================
#  Dispatch menu selection
#  Returns: 0 = handled, 1 = invalid, 2 = back
#  PIKA_DISPATCH_RC holds the handler's exit code so the caller can
#  decide whether the result needs attention (pause) or not.
# ============================================================
ui_dispatch() {
    local -n ents="$1"
    local sel="${2:-0}"

    PIKA_DISPATCH_RC=0
    [ "$sel" = "0" ] && return 2

    local idx=1 entry key title_key desc_key handler
    for entry in "${ents[@]}"; do
        if [ "$idx" = "$sel" ]; then
            IFS='|' read -r key title_key desc_key handler <<< "$entry"
            if [ -n "$handler" ] && declare -F "$handler" >/dev/null 2>&1; then
                # Run in a tested context so a failing install (set -e inside
                # the module) returns to the menu instead of killing the shell.
                # A handler failure is not an invalid selection: the handler
                # already reported it, so only "back" (2) is propagated.
                local rc=0
                "$handler" "$key" || rc=$?
                PIKA_DISPATCH_RC=$rc
                [ "$rc" -eq 2 ] && return 2
                return 0
            fi
            pika_err "$(t 'ui.nohandler'): ${handler:-N/A}"
            PIKA_DISPATCH_RC=1
            return 1
        fi
        idx=$((idx + 1))
    done

    PIKA_DISPATCH_RC=1
    return 1
}

# ============================================================
#  Keyword search inside a menu array
#  Prints "<index>\t<title>" for every item whose key, title,
#  description or handler contains the query (case-insensitive).
#  Lets the menu loop accept "证书" instead of counting numbers.
# ============================================================
ui_search_items() {
    local -n _ui_search_arr="$1"
    local query="${2:-}" idx=1 entry key tk dk handler hay label
    [ -n "$query" ] || return 1
    query=$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')
    for entry in "${_ui_search_arr[@]}"; do
        IFS='|' read -r key tk dk handler <<< "$entry"
        label=$(t "$tk")
        hay=$(printf '%s %s %s %s' "$key" "$label" "$(t "$dk")" "$handler" \
            | tr '[:upper:]' '[:lower:]')
        case "$hay" in
            *"$query"*) printf '%s\t%s\n' "$idx" "$label" ;;
        esac
        idx=$((idx + 1))
    done
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
