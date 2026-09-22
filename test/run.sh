#!/usr/bin/env bash
# Run the mutedstl test suites headless and report the result.
# 无头运行 mutedstl 测试套件并汇报结果。
#
# Suites / 套件:
#   test/mutedstl.vim   plugin behaviour + public API contract
#   test/upstream.vim   contract tests for the Vim APIs the plugin relies on
#
# Usage / 用法:
#   test/run.sh                       # run all suites / 运行全部套件
#   MUTEDSTL_TEST_OUT=x test/run.sh   # also write reports to x.*
#
# Exit status is 0 only if every suite passes. / 仅当所有套件通过才退出 0。
set -u
here="$(cd "$(dirname "$0")" && pwd)"
vim_bin="${VIM:-vim}"
out="${MUTEDSTL_TEST_OUT:-}"
suites=("mutedstl" "upstream")
status=0

run_suite() {
  local name="$1" report="$2"
  MUTEDSTL_TEST_OUT="$report" "$vim_bin" -N -u NONE -i NONE -es -S "$here/$name.vim" </dev/null >/dev/null 2>&1
  local rc=$?
  [ -f "$report" ] && cat "$report"
  if [ "$rc" -ne 0 ]; then
    echo "suite '$name' FAILED (exit $rc)"
    status=1
  fi
}

if [ -n "$out" ]; then
  for name in "${suites[@]}"; do
    run_suite "$name" "$out.$name"
  done
else
  tmpdir="$(mktemp -d)"
  for name in "${suites[@]}"; do
    run_suite "$name" "$tmpdir/$name"
  done
  rm -rf "$tmpdir"
fi

exit $status
