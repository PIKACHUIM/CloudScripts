#!/usr/bin/env bash
. /g/Codes/PikaProjects/CloudScripts/Linux/Lib/00-core.sh
. /g/Codes/PikaProjects/CloudScripts/Linux/Lib/40-ui.sh

# Trace what _ui_str_width does
_ui_str_width() {
    local s="$1"
    echo "DEBUG: input='$s' (len=${#s})"
    if command -v python3 >/dev/null 2>&1 && python3 -c "" 2>/dev/null; then
        local w
        w=$(python3 -c "import sys,unicodedata; s=sys.argv[1]; print(sum(2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s))" -- "$s" 2>/dev/null)
        echo "DEBUG: python path returned '$w'"
        if [ -n "$w" ] && [ "$w" -ge 0 ] 2>/dev/null; then
            echo "$w"
            return
        fi
    fi
    echo "DEBUG: using fallback"
    local _lc_saved="${LC_ALL-__PIKA_UNSET__}"
    LC_ALL=C
    local leads="${s//[$'\x80'-$'\xbf']/}"
    local chars=${#leads}
    echo "DEBUG: leads='$leads' (len=${#leads})"
    local wides="${leads//[!$'\xe0'-$'\xf7']/}"
    local wide=${#wides}
    echo "DEBUG: wides='$wides' (len=${#wides})"
    [ "$_lc_saved" = "__PIKA_UNSET__" ] && unset LC_ALL || LC_ALL="$_lc_saved"
    echo "DEBUG: result = $((chars + wide))"
    echo $((chars + wide))
}

echo "== Test =="
_ui_str_width '部署安装'
