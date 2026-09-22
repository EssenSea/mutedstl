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
  # NOTE: 'vim' reads $VIM as the runtime root; when we use $VIM to pick the
  # *binary*, unset it for the child so a stale value cannot point Vim at the
  # wrong runtime.  (Vim's own --version/$VIMRUNTIME then resolves normally.)
  # 注意：Vim 把 $VIM 当作 runtime 根目录；当我们用 $VIM 选“二进制”时，为子进
  # 程取消它，避免旧值把 Vim 指向错误的 runtime。
  MUTEDSTL_TEST_OUT="$report" env -u VIM "$vim_bin" \
    -N -u NONE -i NONE -es -S "$here/$name.vim" </dev/null >/dev/null 2>&1
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

# Optional: render the statusline in a real PTY and check the colours.  Needs
# python3 + pyte; skipped (exit 0) when either is missing, so it never blocks
# a plain test run.
# 可选：在真实 PTY 中渲染状态栏并检查颜色；缺 python3/pyte 时跳过。
if command -v python3 >/dev/null 2>&1 &&    python3 -c 'import pyte' >/dev/null 2>&1; then
  python3 "$here/term_render.py" || status=1
else
  echo "term-render: SKIP (python3/pyte not available)"
fi

exit $status
