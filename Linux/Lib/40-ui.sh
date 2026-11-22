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

# 粘贴证书链时会多读一行，留给下一次 ui_read_pem 用，避免吞掉私钥首行
UI_PEM_PUSHBACK=""
# 允许测试或特殊环境指定编辑器，例如 UI_PEM_EDITOR_CMD=/tmp/fake-editor.sh
UI_PEM_EDITOR_CMD="${UI_PEM_EDITOR_CMD:-}"

# 找一个能用的编辑器：UI_PEM_EDITOR_CMD > $EDITOR > $VISUAL > nano > vim > vi
_ui_pem_editor_pick() {
    local e
    for e in "${UI_PEM_EDITOR_CMD:-}" "${EDITOR:-}" "${VISUAL:-}" nano vim vi; do
        [ -n "$e" ] || continue
        command -v "${e%% *}" >/dev/null 2>&1 || continue
        printf '%s\n' "$e"
        return 0
    done
    return 1
}

# 去掉 CR、行尾空白与首尾空行：编辑器保存出来的文件直接可用
_ui_pem_normalize() {
    local f="$1" tmp="${f}.pika.$$"
    sed -e 's/\r$//' -e 's/[[:space:]]*$//' "$f" 2>/dev/null \
        | awk 'BEGIN{seen=0} /^[[:space:]]*$/{ if(seen) buf[++n]=$0; next }
               { for(i=1;i<=n;i++) print buf[i]; n=0; print; seen=1 }' > "$tmp" \
        && mv -f "$tmp" "$f"
    rm -f "$tmp" 2>/dev/null || true
    return 0
}

# 终端开启 bracketed paste 时，粘贴内容首尾会带 ESC[200~ / ESC[201~，
# 不剥掉的话首行就不是 -----BEGIN 开头，会被当成文件路径。
_ui_pem_clean() {
    local s="$1"
    s="${s//$'\033[200~'/}"
    s="${s//$'\033[201~'/}"
    s="${s//$'\033[200'/}"
    s="${s//$'\033[201'/}"
    printf '%s' "$s"
}

# 内容里要有完整的 BEGIN...END 块（私钥/证书都适用）
_ui_pem_block_ok() {
    local f="$1" endmark="$2"
    [ -s "$f" ] || return 1
    grep -q -- '-----BEGIN ' "$f" 2>/dev/null || return 1
    grep -q -- "$endmark" "$f" 2>/dev/null || return 1
    return 0
}

# 打开编辑器粘贴。失败时自己打印原因，返回 1 让主循环重新提问。
# 每次只开一次编辑器：内容不合格就交回主循环，由用户决定重按回车还是改粘贴。
_ui_pem_edit_flow() {
    local out="$1" endmark="$2" cmd base
    local -a ec
    # 没有终端就没法全屏编辑；显式给了 UI_PEM_EDITOR_CMD 时放行（测试用）
    if [ ! -t 0 ] && [ -z "${UI_PEM_EDITOR_CMD:-}" ]; then
        printf '  %s\n' "$(t 'ui.pem.no_tty')"
        return 1
    fi
    cmd=$(_ui_pem_editor_pick) || { printf '  %s\n' "$(t 'ui.pem.no_editor')"; return 1; }
    IFS=' ' read -r -a ec <<< "$cmd"
    base=$(basename "${ec[0]}")

    printf '\n  %s\n' "$(t 'ui.pem.editor_open')"
    case "$base" in
        nano|pico) printf '  %s\n' "$(t 'ui.pem.editor_keys_nano')" ;;
        vi|vim|nvim) printf '  %s\n' "$(t 'ui.pem.editor_keys_vi')" ;;
    esac

    : > "$out" 2>/dev/null || return 1
    case "$base" in
        nano|pico) "${ec[@]}" -w "$out" ;;
        *) "${ec[@]}" "$out" ;;
    esac
    printf '\n'
    _ui_pem_normalize "$out"

    _ui_pem_block_ok "$out" "$endmark" && return 0
    if [ -s "$out" ]; then
        printf '  %s\n' "$(t 'ui.pem.editor_bad')"
    else
        printf '  %s\n' "$(t 'ui.pem.editor_empty')"
    fi
    return 1
}

# ============================================================
#  Read a PEM block: editor paste (default) / file path / paste
#  Usage: ui_read_pem <prompt> <out_file> <end_marker>
#  Returns: 0 = written, 2 = path not found, 3 = pasted block
#           incomplete, 1 = empty / cancelled
#  Enter alone opens $EDITOR (nano/vim) on the target file: this is
#  the only reliable way to take a multi-line private key, because a
#  terminal may deliver a paste as a single buffered line.
#  Pasted input starting with "-----BEGIN" is copied verbatim up to
#  the matching END line; on a terminal a following CERTIFICATE block
#  (fullchain) is appended, and any other lookahead line is pushed
#  back so the next prompt can use it.
#  UI_PEM_INPUT keeps the raw first line so callers can echo it back.
# ============================================================
ui_read_pem() {
    local prompt="$1" out="$2" endmark="$3" line peek ended=0 tries=0 retry=0
    UI_PEM_INPUT=""

    while :; do
        if [ -n "${UI_PEM_PUSHBACK:-}" ]; then
            line="$UI_PEM_PUSHBACK"
            UI_PEM_PUSHBACK=""
        else
            printf '  %s: ' "$prompt"
            IFS= read -r line || return 1
        fi
        line=$(_ui_pem_clean "$line")
        line=${line%$'\r'}
        # 去掉首尾空白，以及从别处粘贴时带上的双引号
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        line="${line%\"}"; line="${line#\"}"

        if [ -z "$line" ]; then
            # 直接回车 = 打开编辑器粘贴，失败时流程内已说明原因
            _ui_pem_edit_flow "$out" "$endmark" && return 0
            tries=$((tries + 1))
            [ "$tries" -ge 3 ] && return 1
            continue
        fi
        UI_PEM_INPUT="$line"

        case "$line" in
            "-----BEGIN"*)
                : > "$out" || return 1
                printf '%s\n' "$line" >> "$out"
                while IFS= read -r line; do
                    line=$(_ui_pem_clean "$line")
                    line=${line%$'\r'}
                    printf '%s\n' "$line" >> "$out"
                    case "$line" in
                        *"$endmark"*) ended=1; break ;;
                    esac
                done
                if [ "$ended" -ne 1 ]; then
                    # 终端里给一次改用编辑器的机会，别让用户卡在粘贴上
                    retry=$((retry + 1))
                    printf '  %s\n' "$(t 'ui.pem.incomplete')"
                    if [ -t 0 ] && [ "$retry" -le 2 ]; then
                        printf '  %s\n' "$(t 'ui.pem.retry_editor')"
                        continue
                    fi
                    return 3
                fi
                # 终端里继续读证书链；管道输入不 peek，避免吞掉后续回答
                while [ -t 0 ]; do
                    IFS= read -r -t 2 peek || break
                    peek=$(_ui_pem_clean "$peek")
                    peek=${peek%$'\r'}
                    case "$peek" in
                        "-----BEGIN CERTIFICATE"*)
                            printf '%s\n' "$peek" >> "$out"
                            while IFS= read -r line; do
                                line=${line%$'\r'}
                                printf '%s\n' "$line" >> "$out"
                                case "$line" in *"$endmark"*) break ;; esac
                            done
                            ;;
                        *)
                            # 不是下一段证书：留给下一个输入框
                            UI_PEM_PUSHBACK="$peek"
                            break
                            ;;
                    esac
                done
                return 0
                ;;
            *)
                [ -f "$line" ] || return 2
                cp -f "$line" "$out" || return 1
                _ui_pem_normalize "$out"
                return 0
                ;;
        esac
    done
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
