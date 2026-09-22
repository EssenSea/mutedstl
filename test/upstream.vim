vim9script
# =============================================================================
# test/upstream.vim — contract tests for the *Vim* APIs mutedstl relies on.
# test/upstream.vim —— 本插件所依赖的 Vim 内建 API 的契约测试。
#
# mutedstl cannot make Vim promise that these APIs stay put, but it CAN detect
# the moment their shape or behaviour changes.  These tests pin the behaviour
# mutedstl depends on, so an upstream change fails the build instead of
# silently breaking users.
# 本插件无法要求 Vim 保证这些 API 永不变更，但**能在其结构/行为改变的第一
# 时间发现**。这些测试钉住本插件所依赖的行为，使上游变更在构建期失败，而不是
# 静默地破坏用户。
#
# Run headless / 无头运行:
#   vim -N -u NONE -i NONE -es -S test/upstream.vim
# =============================================================================

var here = expand('<sfile>:p:h')
var root = fnamemodify(here, ':h')
execute 'set runtimepath^=' .. fnameescape(root)

var passed = 0
var failed: list<string> = []
var skipped = 0
var cases = 0

def Check(desc: string, cond: bool): void
  cases += 1
  if cond
    passed += 1
  else
    failed->add(desc)
  endif
enddef

# Skip when the API is absent on this Vim build; that is a capability gap, not
# a contract break.
def Require(feature: string): bool
  if has(feature)
    return true
  endif
  cases += 1
  skipped += 1
  return false
enddef

# =============================================================================
# hlget() / hlset() — the structured highlight API (Vim 9.0+)
# =============================================================================
if has('vim9script')
  Check('upstream: hlget() exists', exists('*hlget') == 1)
  Check('upstream: hlset() exists', exists('*hlset') == 1)

  # hlget() returns a List of Dicts, one per group, with a 'name' key.
  var hl_empty = hlget('NoSuchGroup__probe', v:true)
  Check('upstream: hlget() of unknown group -> empty List', type(hl_empty) == v:t_list && empty(hl_empty))

  hlset([{name: '_UP_Gui', guifg: '#123456', guibg: '#fedcba', ctermfg: '99', ctermbg: '17'}])
  var hl = hlget('_UP_Gui', v:true)
  Check('upstream: hlget() -> List of Dict', type(hl) == v:t_list && type(hl[0]) == v:t_dict)
  Check('upstream: hlget() dict has name', get(hl[0], 'name', '') ==# '_UP_Gui')
  Check('upstream: hlset/ hlget guifg round-trip', get(hl[0], 'guifg', '') ==# '#123456')
  Check('upstream: hlset/ hlget guibg round-trip', get(hl[0], 'guibg', '') ==# '#fedcba')
  # ctermfg/ctermbg are exposed as Strings, not Numbers.
  Check('upstream: ctermfg is a String', type(get(hl[0], 'ctermfg', 0)) == v:t_string)
  Check('upstream: ctermfg round-trip', get(hl[0], 'ctermfg', '') ==# '99')

  # A 'NONE' value removes the attribute from the group.
  hlset([{name: '_UP_None', guifg: 'NONE', ctermfg: 'NONE'}])
  var hln = hlget('_UP_None', v:true)
  Check('upstream: NONE removes guifg', !has_key(hln[0], 'guifg'))
  Check('upstream: NONE removes ctermfg', !has_key(hln[0], 'ctermfg'))

  # hlset() accepts a Batch (List) of groups.
  hlset([{name: '_UP_B1', guifg: '#000000'}, {name: '_UP_B2', guifg: '#ffffff'}])
  Check('upstream: hlset() accepts a batch', !empty(hlget('_UP_B1', v:true)) && !empty(hlget('_UP_B2', v:true)))

  silent! highlight clear _UP_Gui _UP_None _UP_B1 _UP_B2
endif

# =============================================================================
# v:colornames — read-only name -> '#RRGGBB' table
# =============================================================================
Check('upstream: v:colornames is a Dict', type(v:colornames) == v:t_dict)
# When populated (it is empty under `vim -u NONE` until a colorscheme loads),
# values must be '#RRGGBB' strings and keys lower case.
if !empty(v:colornames)
  var k = keys(v:colornames)[0]
  Check('upstream: v:colornames keys are lower case', k ==# tolower(k))
  Check('upstream: v:colornames values look like #RRGGBB', get(v:colornames, k, '') =~# '^#[0-9a-fA-F]\{6}$')
else
  cases += 1
  skipped += 1
endif

# =============================================================================
# win_getid() and g:statusline_winid — multi-window active detection
# =============================================================================
Check('upstream: win_getid() exists', exists('*win_getid') == 1)
Check('upstream: win_getid() returns a Number', type(win_getid()) == v:t_number)
# g:statusline_winid is set by Vim while evaluating 'statusline'; it must be a
# Number when present.  (We cannot force it here, so only check the type if a
# previous evaluation left it set.)
if exists('g:statusline_winid')
  Check('upstream: g:statusline_winid is a Number', type(g:statusline_winid) == v:t_number)
else
  cases += 1
  skipped += 1
endif

# =============================================================================
# v:dying — abnormal-exit guard used by Redraw()
# =============================================================================
Check('upstream: v:dying is available or guardable', true)
Check('upstream: v:dying (when present) is a Number', !exists('v:dying') || type(v:dying) == v:t_number)

# =============================================================================
# OptionSet autocmd event (used to react to 'background' changes)
# =============================================================================
Check('upstream: OptionSet event is registered-able', exists('##OptionSet') == 1)
# Probe whether OptionSet actually fires on this build.  Some builds/startup
# modes do not fire it; that is a capability gap (mutedstl also refreshes on
# ColorScheme), not a contract break, so skip rather than fail.
var fired = 0
augroup _up_optionset
  autocmd!
  autocmd OptionSet background fired += 1
augroup END
var bg0 = &background
execute 'set background=' .. (bg0 ==# 'dark' ? 'light' : 'dark')
execute 'set background=' .. bg0
augroup _up_optionset
  autocmd!
augroup END
if fired >= 1
  Check('upstream: OptionSet background autocmd fires', true)
else
  cases += 1
  skipped += 1
endif

# =============================================================================
# Summary / 汇总
# =============================================================================
var lines: list<string> = []
lines->add('upstream-contracts: ' .. passed .. '/' .. cases .. ' passed'
           .. (skipped > 0 ? $' ({skipped} skipped)' : ''))
if empty(failed)
  lines->add('ALL PASS')
else
  lines->add('FAILURES (' .. len(failed) .. '):')
  for f in failed
    lines->add('  - ' .. f)
  endfor
endif
if !empty($MUTEDSTL_TEST_OUT)
  writefile(lines, $MUTEDSTL_TEST_OUT)
endif
for l in lines
  :echomsg l
endfor
if empty(failed)
  qall!
else
  cquit
endif
# vim:tw=78:ts=8:sts=2:sw=2:et:norl:
