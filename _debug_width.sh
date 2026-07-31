#!/usr/bin/env bash
# Debug _ui_str_width
test_width() {
    local s="$1" expected="$2"
    LC_ALL=C
    local leads="${s//[$'\x80'-$'\xbf']/}"
    local chars=${#leads}
    local wides="${leads//[!$'\xe0'-$'\xf7']/}"
    local wide=${#wides}
    local result=$((chars + wide))
    printf 'input=%-20s  chars=%d  wide=%d  result=%d  expected=%d\n' \
        "\"$s\"" "$chars" "$wide" "$result" "$expected"
}

test_width "AB" 2
test_width "Hello" 5
test_width "部署" 4
test_width "部署安装" 8
test_width "Deploy & Install" 16
