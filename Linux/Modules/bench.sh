#!/usr/bin/env bash
# ============================================================
#  PIKA SH - Bench Module
#  Menu + handlers for performance benchmarks.
#  Delegates to Linux/VPSTest/*.sh thin wrappers.
# ============================================================
set -e

BenchMENU=(
    "ecss|bench.ecss|bench.ecss.desc|do_bench_ecss"
    "yabs|bench.yabs|bench.yabs.desc|do_bench_yabs"
    "lemon|bench.lemon|bench.lemon.desc|do_bench_lemon"
    "superbench|bench.superbench|bench.superbench.desc|do_bench_superbench"
    "superspeed|bench.superspeed|bench.superspeed.desc|do_bench_superspeed"
    "unixbench|bench.unixbench|bench.unixbench.desc|do_bench_unixbench"
    "ipquality|bench.ipquality|bench.ipquality.desc|do_bench_ipquality"
    "backtrace|bench.backtrace|bench.backtrace.desc|do_bench_backtrace"
    "besttrace|bench.besttrace|bench.besttrace.desc|do_bench_besttrace"
    "supertrace|bench.supertrace|bench.supertrace.desc|do_bench_supertrace"
    "mping|bench.mping|bench.mping.desc|do_bench_mping"
    "prettyping|bench.prettyping|bench.prettyping.desc|do_bench_prettyping"
    "qsyb|bench.qsyb|bench.qsyb.desc|do_bench_qsyb"
)

PIKA_VPSTEST_DIR="${PIKA_BASE:-.}/Linux/VPSTest"

_run_bench() {
    local name="$1" script="$2"; shift 2
    pika_info "$(t 'state.installing') $name..."

    # Try local script first, then download from CDN
    local local_script="${PIKA_VPSTEST_DIR}/${script}"
    if [ -f "$local_script" ] && [ -s "$local_script" ]; then
        bash "$local_script" "$@"
    else
        # Download wrapper from CDN
        local tmpf; tmpf=$(mktemp)
        if pika_fetch "Linux/VPSTest/${script}" -o "$tmpf" 2>/dev/null; then
            chmod +x "$tmpf"
            bash "$tmpf" "$@"
            rm -f "$tmpf"
        else
            rm -f "$tmpf"
            pika_fetch "Linux/VPSTest/${script}" | bash -e "$@"
        fi
    fi
}

do_bench_ecss()      { _run_bench "ecss" "ecss-bench.sh"; }
do_bench_yabs()      { _run_bench "YABS" "yabs-bench.sh"; }
do_bench_lemon()     { _run_bench "LemonBench" "lemonbench.sh"; }
do_bench_superbench(){ _run_bench "SuperBench" "superbench.sh"; }
do_bench_superspeed(){ _run_bench "SuperSpeed" "superspeed.sh"; }
do_bench_unixbench() { _run_bench "UnixBench" "unix-bench.sh"; }
do_bench_ipquality() { _run_bench "IP Quality" "ip-quality.sh"; }
do_bench_backtrace() { _run_bench "BackTrace" "back-trace.sh"; }
do_bench_besttrace() { _run_bench "BestTrace" "best-trace.sh"; }
do_bench_supertrace(){ _run_bench "SuperTrace" "supertrace.sh"; }
do_bench_mping()     { _run_bench "mPing" "mping-test.sh"; }
do_bench_prettyping(){ _run_bench "PrettyPing" "prettyping.sh"; }
do_bench_qsyb()      { _run_bench "qsyb" "qsyb-bench.sh"; }
