#!/usr/bin/env bash
# Run the mutedstl test suite headless and report the result.
# 无头运行 mutedstl 测试套件并汇报结果。
#
# Usage / 用法:
#   test/run.sh              # run tests / 运行测试
#   MUTEDSTL_TEST_OUT=x test/run.sh   # also write the report to x
#
# Exit status is 0 on success, non-zero on failure.
# 成功退出码 0，失败非零。
set -u
here="$(cd "$(dirname "$0")" && pwd)"
vim_bin="${VIM:-vim}"
out="${MUTEDSTL_TEST_OUT:-}"

if [ -n "$out" ]; then
  MUTEDSTL_TEST_OUT="$out" "$vim_bin" -N -u NONE -i NONE -es -S "$here/mutedstl.vim" </dev/null >/dev/null 2>&1
  status=$?
  [ -f "$out" ] && cat "$out"
  exit $status
else
  tmp="$(mktemp)"
  MUTEDSTL_TEST_OUT="$tmp" "$vim_bin" -N -u NONE -i NONE -es -S "$here/mutedstl.vim" </dev/null >/dev/null 2>&1
  status=$?
  [ -f "$tmp" ] && cat "$tmp"
  rm -f "$tmp"
  exit $status
fi
