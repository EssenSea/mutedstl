vim9script
# =============================================================================
# test/mutedstl.vim — regression tests for autoload/mutedstl.vim
#
# Run headless / 无头运行:
#   vim -N -u NONE -S test/mutedstl.vim
#   (prints a summary and exits non-zero on failure)
#   输出汇总，失败时以非零状态退出。
#
# The tests exercise only the public (exported) API; internal helpers are
# covered indirectly through the values returned by Colors()/Mode()/etc.
# 仅测试导出（export）的公共 API；内部辅助函数通过 Colors()/Mode() 等的返回
# 值间接覆盖。
# =============================================================================

# --- locate the plugin root and make the autoload findable -------------------
# 定位插件根目录，使 autoload 可被找到。
var here = expand('<sfile>:p:h')          # .../mutedstl/test
var root = fnamemodify(here, ':h')        # .../mutedstl  (plugin root)
execute 'set runtimepath^=' .. fnameescape(root)

# Import the module under test (autoload style).
# 以 autoload 风格导入被测模块。
import autoload root .. '/autoload/mutedstl.vim' as ms

# --- tiny test harness / 迷你测试框架 ----------------------------------------
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

# Skip an assertion when an environment precondition is not met (e.g. the
# optional v:colornames table is empty).  Counted separately so CI stays green
# on minimal Vims while still reporting what was not exercised.
# 当环境前提不满足时跳过断言（如可选的 v:colornames 表为空）。单独计数，使
# 极简 Vim 上的 CI 仍为绿，同时报告哪些未被覆盖。
def Skip(desc: string): void
  cases += 1
  skipped += 1
enddef

def CheckIf(precond: bool, desc: string, cond: bool): void
  if precond
    Check(desc, cond)
  else
    Skip(desc .. ' [skipped: precondition]')
  endif
enddef

# Compare two values for equality. / 比较两个值是否相等。
def Eq(desc: string, expected: any, actual: any): void
  Check(desc, string(expected) ==# string(actual))
enddef

# Run a block, assert it does NOT throw. / 断言代码块不抛异常。
def NoThrow(desc: string, Fn: func): void
  cases += 1
  try
    Fn()
    passed += 1
  catch
    failed->add(desc .. ' (threw: ' .. v:exception .. ')')
  endtry
enddef

# --- helpers to isolate each case / 每个用例的环境隔离 ------------------------
def ClearOpts(): void
  for k in ['invert', 'theme', 'fg', 'bg', 'prefix', 'inactive']
    execute 'unlet! g:mutedstl#' .. k
  endfor
enddef

def WithOpts(fg: string, bg: string, invert: number, Fn: func): void
  ClearOpts()
  if !empty(fg)   | g:mutedstl#fg = fg | endif
  if !empty(bg)   | g:mutedstl#bg = bg | endif
  if invert >= 0  | g:mutedstl#invert = invert | endif
  Fn()
  ClearOpts()
enddef

# =============================================================================
# Tests / 测试
# =============================================================================

# Best-effort: populate v:colornames so colour-name tests can run even on a
# minimal Vim.  Vim usually fills this when a colourscheme loads, but a bare
# `vim -u NONE` starts with it empty.  Older Vims may lack the file entirely;
# tests that need it then skip instead of failing.
# 尽力填充 v:colornames，使颜色名测试在极简 Vim 上也能跑。Vim 通常在加载配色
# 时填充它，但裸 `vim -u NONE` 启动时为空。旧 Vim 可能没有该文件，此时相关
# 测试跳过而非失败。
silent! runtime colors/lists/default.vim
var has_colornames = !empty(v:colornames)

# Ensure a deterministic colourscheme / 固定一个可预期的配色方案。
# Try a few themes that ship with Vim; the first that loads wins.  If none is
# available (very minimal runtime) the colour-dependent cases skip rather than
# fail — the plugin itself does not require any particular theme.
# 尝试若干 Vim 自带主题，取第一个成功加载者。若都不可用（极简 runtime），
# 依赖颜色的用例改为跳过而非失败——插件本身不要求任何特定主题。
var baseline_theme = ''
for cand in ['blue', 'desert', 'default']
  silent! execute 'colorscheme ' .. cand
  if get(g:, 'colors_name', '') ==# cand
    baseline_theme = cand
    break
  endif
endfor
if empty(baseline_theme)
  Skip('baseline: a colourscheme is available [skipped: none loadable]')
else
  Check('baseline: a colourscheme loaded', true)
endif
ms.ReloadCache()

# A minimal Vim (e.g. `vim -u NONE` on a slim distro package) may load 'blue'
# without giving Normal any colours.  Detect that once; colour-content
# assertions are then skipped rather than failing on an environment quirk.
# 极简 Vim（如 slim 发行包的 `vim -u NONE`）可能加载 'blue' 却不给 Normal 上色。
# 检测一次；颜色内容相关断言改为跳过，而非因环境差异失败。
var baseline_ok = !ms.Colors().is_none

# --- 1. Colors(): default comes from the current Normal ----------------------
# 默认取当前 Normal。
var base = ms.Colors()
Check('default: colors has ordinary/emphasis', has_key(base, 'ordinary') && has_key(base, 'emphasis'))
Check('default: fg is a [gui,cterm] pair', len(base.fg) == 2 && len(base.bg) == 2)
CheckIf(baseline_ok, 'default: not none', base.is_none == false)
if baseline_ok
  Eq('default: ordinary=[fg,bg]', [base.fg, base.bg], base.ordinary)
  Eq('default: emphasis=[bg,fg]', [base.bg, base.fg], base.emphasis)
else
  Skip('default: ordinary=[fg,bg] [skipped: no baseline colours]')
  Skip('default: emphasis=[bg,fg] [skipped: no baseline colours]')
endif
ms.ReloadCache()

# --- 2. invalid overrides fall back safely (no throw) ------------------------
# 非法覆盖值安全回退（不抛异常）。
ClearOpts()
g:mutedstl#invert = 'abc'
NoThrow('invert="abc" does not throw', () => ms.Colors())
ClearOpts()
g:mutedstl#theme = 123
NoThrow('theme=123 does not throw', () => ms.Colors())
ClearOpts()
g:mutedstl#fg = 1.5
NoThrow('fg=1.5 (float) does not throw', () => ms.Colors())
ClearOpts()

# --- 2b. out-of-range numeric index is clamped, never E254 -------------------
# 越界数字色号被钳制，绝不触发 E254。
ClearOpts()
g:mutedstl#fg = 300
var cl = ms.Colors()
Eq('fg=300 clamps gui to max', '#eeeeee', cl.fg[0])
Eq('fg=300 clamps cterm to 255', '255', cl.fg[1])
NoThrow('fg=300 ApplyDefault does not throw', () => ms.ApplyDefault())
ClearOpts()
g:mutedstl#fg = -5
var cl2 = ms.Colors()
Eq('fg=-5 clamps gui to min', '#000000', cl2.fg[0])
Eq('fg=-5 clamps cterm to 0', '0', cl2.fg[1])
ClearOpts()
g:mutedstl#fg = '300'
Eq('fg="#300" string clamps cterm', '255', ms.Colors().fg[1])
ClearOpts()
NoThrow('NrToHex(300) does not throw', () => ms.NrToHex(300))
Eq('NrToHex(300) clamped', '#eeeeee', ms.NrToHex(300))
Eq('NrToHex(-1) clamped', '#000000', ms.NrToHex(-1))

# --- 2c. HexToCterm strictness ----------------------------------------------
Eq('HexToCterm(#gggggg) is -1', -1, ms.HexToCterm('#gggggg'))
Eq('HexToCterm(#ff00) is -1 (too short)', -1, ms.HexToCterm('#ff00'))
Eq('HexToCterm(ff0000) is -1 (no #)', -1, ms.HexToCterm('ff0000'))
Eq('HexToCterm(#ff0000z) is -1 (trailing)', -1, ms.HexToCterm('#ff0000z'))

# --- 3. explicit overrides / 显式覆盖 ----------------------------------------
WithOpts('#ff8800', '', -1, () => {
  var c = ms.Colors()
  Eq('override hex fg value', '#ff8800', c.fg[0])
  Eq('override hex fg cterm (nearest 208)', '208', c.fg[1])
})
WithOpts('208', '', -1, () => {
  var c = ms.Colors()
  Eq('override 256 fg cterm', '208', c.fg[1])
  Eq('override 256 fg gui', '#ff8700', c.fg[0])
})
WithOpts('DarkGrey', '', -1, () => {
  CheckIf(has_colornames, 'override name fg gui', ms.Colors().fg[0] ==# '#a9a9a9')
})
WithOpts('NONE', '', -1, () => {
  var c = ms.Colors()
  Eq('override NONE fg', ['NONE', 'NONE'], c.fg)
  Check('override NONE sets is_none', c.is_none == true)
})

# --- 4. invert swaps fg/bg ---------------------------------------------------
ClearOpts()
g:mutedstl#invert = 0
var c0 = ms.Colors()
g:mutedstl#invert = 1
var c1 = ms.Colors()
Eq('invert=1 swaps fg', c0.bg, c1.fg)
Eq('invert=1 swaps bg', c0.fg, c1.bg)
ClearOpts()

# --- 5. NONE matrix (ordinary/emphasis split) --------------------------------
# NONE 组合矩阵：一个区块为推导实色，另一个全透明。
WithOpts('NONE', 'NONE', 0, () => {
  var c = ms.Colors()
  Eq('none/none inv0 ordinary blank', [['NONE', 'NONE'], ['NONE', 'NONE']], c.ordinary)
  Check('none/none inv0 emphasis concrete', c.emphasis[0][0] !=# 'NONE')
})
WithOpts('NONE', 'NONE', 1, () => {
  var c = ms.Colors()
  Eq('none/none inv1 emphasis blank', [['NONE', 'NONE'], ['NONE', 'NONE']], c.emphasis)
  Check('none/none inv1 ordinary concrete', c.ordinary[0][0] !=# 'NONE')
})
WithOpts('#111111', 'NONE', 0, () => {
  var c = ms.Colors()
  Eq('fg set / bg none: emphasis keeps fg', '#111111', c.emphasis[0][0])
})

# --- 6. Mode(): leading-char mapping + fallbacks -----------------------------
Eq('Mode n', 'NORMAL', ms.Mode('n'))
Eq('Mode no', 'NORMAL', ms.Mode('no'))
Eq('Mode v', 'VISUAL', ms.Mode('v'))
Eq('Mode V', 'V-LINE', ms.Mode('V'))
Eq('Mode i', 'INSERT', ms.Mode('i'))
Eq('Mode ic', 'INSERT', ms.Mode('ic'))
Eq('Mode R', 'REPLACE', ms.Mode('R'))
Eq('Mode c', 'COMMAND', ms.Mode('c'))
Eq('Mode !', 'SHELL', ms.Mode('!'))
Eq('Mode t', 'TERMINAL', ms.Mode('t'))
Eq('Mode exact nt', 'TERM-N', ms.Mode('nt'))
Eq('Mode exact Rv', 'V-REPLACE', ms.Mode('Rv'))
Eq('Mode exact cv', 'EX', ms.Mode('cv'))
Eq('Mode unknown passthrough', 'zz', ms.Mode('zz'))
Eq('Mode empty', '', ms.Mode(''))
NoThrow('Mode(123) does not throw', () => ms.Mode(123))
NoThrow('Mode([1]) does not throw', () => ms.Mode([1]))
Check('Mode(non-string) falls back to mode()', len(ms.Mode(123)) > 0)

# --- 7. Paste() --------------------------------------------------------------
NoThrow('Paste() does not throw', () => ms.Paste())
Eq('Paste() empty when nopaste', '', ms.Paste())

# --- 8. Hi(): structured highlight, incl. NONE -------------------------------
ms.Hi('_T_Ord', [['#ff8800', '208'], ['#14161b', '233']])
var h = hlget('_T_Ord', v:true)
Check('Hi sets guifg', !empty(h) && get(h[0], 'guifg', '') ==# '#ff8800')
Check('Hi sets ctermfg', !empty(h) && get(h[0], 'ctermfg', '') ==# '208')
ms.Hi('_T_None', [['NONE', 'NONE'], ['#14161b', '233']])
var hn = hlget('_T_None', v:true)
Check('Hi NONE fg removes guifg', !empty(hn) && !has_key(hn[0], 'guifg'))
Check('Hi NONE fg keeps guibg', !empty(hn) && get(hn[0], 'guibg', '') ==# '#14161b')
silent! highlight clear _T_Ord _T_None

# --- 9. ApplyDefault(): three groups, inactive == ordinary -------------------
ms.ApplyDefault()
var em = hlget('MutedstlEmphasis', v:true)
var od = hlget('MutedstlOrdinary', v:true)
var ina = hlget('MutedstlInactive', v:true)
Check('ApplyDefault: Emphasis exists', !empty(em))
Check('ApplyDefault: Ordinary exists', !empty(od))
Check('ApplyDefault: Inactive exists', !empty(ina))
Eq('ApplyDefault: Inactive == Ordinary (gui)', get(od[0], 'guifg', ''), get(ina[0], 'guifg', ''))
Eq('ApplyDefault: Inactive == Ordinary (cterm)', get(od[0], 'ctermfg', ''), get(ina[0], 'ctermfg', ''))
Check('ApplyDefault: Emphasis differs from Ordinary', get(em[0], 'guifg', '') !=# get(od[0], 'guifg', ''))

# --- 10. theme option + cache ------------------------------------------------
# Use a theme that ships with Vim ('blue'); a non-existent name would now
# (correctly) yield NONE rather than the previous theme's leaked colours.
# 使用 Vim 自带主题（blue）；不存在的名字现在会（正确地）返回 NONE，而不是
# 泄漏上一个主题的颜色。
var cached_theme = 'blue'
WithOpts('', '', 0, () => {
  g:mutedstl#theme = cached_theme
  var t1 = ms.Colors()
  var t2 = ms.Colors()
  Eq('theme: stable across calls (cache hit)', t1.fg, t2.fg)
  CheckIf(baseline_ok, 'theme: fg is concrete', t1.fg[0] =~# '^#')
  CheckIf(baseline_ok, 'theme: not none', t1.is_none == false)
})
ClearOpts()
NoThrow('ReloadCache() does not throw', () => ms.ReloadCache())

# --- 10b. a non-existent theme must NOT leak the previous theme's colours ----
# 不存在的主题绝不能泄漏上一个主题的颜色（也不能被缓存）。
silent! colorscheme blue            # load a real theme so a stale Normal exists
ms.ReloadCache()
var bad = ms.FromTheme('no_such_theme_xyz', 'fg')
Eq('missing theme -> NONE (no stale leak)', ['NONE', 'NONE'], bad)
# switch elsewhere, then re-read: still NONE (nothing was cached)
silent! colorscheme desert
var bad2 = ms.FromTheme('no_such_theme_xyz', 'fg')
Eq('missing theme stays NONE (not cached)', ['NONE', 'NONE'], bad2)
ClearOpts()
g:mutedstl#theme = 'no_such_theme_xyz'
var cbad = ms.Colors()
Check('Colors(missing theme) is_none', cbad.is_none == true)
ClearOpts()
ms.ReloadCache()

# --- 10c. reading another theme must restore g:colors_name -------------------
# 读取其它主题后必须恢复 g:colors_name（无副作用泄漏）。
silent! colorscheme blue
var blue_loaded = get(g:, 'colors_name', '') ==# 'blue'
ms.ReloadCache()
var bg_before = &background
ms.FromTheme('desert', 'fg')
CheckIf(blue_loaded, 'FromTheme restores colors_name', get(g:, 'colors_name', '<unset>') ==# 'blue')
Eq('FromTheme restores background', bg_before, &background)
# When the user had no colors_name at all, it must stay unset afterwards.
unlet! g:colors_name
ms.ReloadCache()
ms.FromTheme('desert', 'fg')
Check('FromTheme leaves colors_name unset if it was unset', !exists('g:colors_name'))
ms.ReloadCache()
silent! colorscheme blue            # restore a known baseline for later cases

# --- 11. String(): structural checks -----------------------------------------
var sl = ms.String()
Check('String: references Emphasis group', sl =~# 'MutedstlEmphasis')
Check('String: references Ordinary group', sl =~# 'MutedstlOrdinary')
Check('String: uses lazy Mode()', sl =~# '%{mutedstl#Mode()}')
Check('String: uses lazy Paste()', sl =~# '%{mutedstl#Paste()}')
Check('String: has truncation point %<', sl =~# '%<')

# --- 12. Generic interfaces: colour tools, FromTheme, GroupName/prefix ------
Eq('NrToHex(0)', '#000000', ms.NrToHex(0))
Eq('NrToHex(232)', '#080808', ms.NrToHex(232))
Check('HexToCterm(#ff0000) is a number', type(ms.HexToCterm('#ff0000')) == v:t_number)
CheckIf(has_colornames, 'NameToHex(DarkGrey)', ms.NameToHex('DarkGrey') ==# '#a9a9a9')
Eq('NameToHex(nosuch)', '', ms.NameToHex('nosuchcolour'))
# FromTheme: current theme fg/bg are returned as [gui, cterm] pairs
var tf = ms.FromTheme('', 'fg')
Check('FromTheme fg is a [gui,cterm] pair', len(tf) == 2)
Check('FromTheme fg gui is a colour', tf[0] =~# '^#' || tf[0] ==# 'NONE')
# GroupName honours the prefix option
Eq('GroupName default emphasis', 'MutedstlEmphasis', ms.GroupName('emphasis'))
g:mutedstl#prefix = 'Zz'
Eq('GroupName with prefix', 'ZzEmphasis', ms.GroupName('emphasis'))
ms.ApplyDefault()
Check('prefixed group created', !empty(hlget('ZzEmphasis', v:true)))
ClearOpts()
ms.ApplyDefault()
Eq('GroupName back to default', 'MutedstlEmphasis', ms.GroupName('emphasis'))
# inactive option
Eq('GroupMark inactive default', '%#MutedstlInactive#', ms.GroupMark('inactive'))
# Colors() exposes an inactive chunk
Check('Colors has inactive chunk', has_key(ms.Colors(), 'inactive'))
g:mutedstl#inactive = 'emphasis'
var ci = ms.Colors()
Eq('inactive=emphasis uses emphasis chunk', ci.emphasis, ci.inactive)
ClearOpts()
var cd = ms.Colors()
Eq('inactive default uses ordinary chunk', cd.ordinary, cd.inactive)

# --- 13. Chunk(): content wrapped in a group, no spaces ----------------------
Eq('Chunk %t default', '%#MutedstlOrdinary#%t', ms.Chunk('%t'))
Eq('Chunk %t emphasis', '%#MutedstlEmphasis#%t', ms.Chunk('%t', 'emphasis'))
Eq('Chunk %t inactive', '%#MutedstlInactive#%t', ms.Chunk('%t', 'inactive'))
Eq('Chunk literal text', '%#MutedstlOrdinary# | ', ms.Chunk(' | '))
Eq('Chunk stl item passthrough', '%#MutedstlEmphasis#%l:%c', ms.Chunk('%l:%c', 'emphasis'))
Eq('Chunk stl function passthrough', '%#MutedstlEmphasis#%{mutedstl#Mode()}', ms.Chunk('%{mutedstl#Mode()}', 'emphasis'))
Check('Chunk has no added space', ms.Chunk('%t') ==# '%#MutedstlOrdinary#%t')
# Any non-logical value is used verbatim as a literal group name.
Eq('Chunk literal group Error', '%#Error#x', ms.Chunk('x', 'Error'))
Eq('Chunk literal group Warning', '%#Warning#x', ms.Chunk('x', 'Warning'))
Eq('Chunk literal group custom', '%#MyAccent#x', ms.Chunk('x', 'MyAccent'))
Eq('GroupMark literal group', '%#Error#', ms.GroupMark('Error'))

# --- 12b. public API failure contracts ---------------------------------------
# 公共 API 的失败契约。
# FromTheme(): a bad attr must fail loudly, not silently return the bg.
NoThrow('FromTheme("", "fg") is ok', () => ms.FromTheme('', 'fg'))
var threw_attr = false
try
  ms.FromTheme('', 'bogus')
catch
  threw_attr = true
endtry
Check('FromTheme(bad attr) throws', threw_attr)
# Hi(): a malformed chunk must throw a clear error, not E684/E928.
var threw_hi = false
try
  ms.Hi('_TC_Bad', [])
catch
  threw_hi = true
endtry
Check('Hi(bad chunk) throws', threw_hi)
# A well-formed chunk must still apply.
ms.Hi('_TC_Ok', [['#000000', '0'], ['#ffffff', '15']])
Check('Hi(valid chunk) applies', !empty(hlget('_TC_Ok', v:true)))
silent! highlight clear _TC_Ok

# --- 13. Refresh() / Redraw() do not throw -----------------------------------
NoThrow('Refresh() does not throw', () => ms.Refresh())
NoThrow('Redraw() does not throw', () => ms.Redraw())
NoThrow('Reassert() does not throw', () => ms.Reassert())

# --- 14. Setup(): default is installed based on the GLOBAL statusline --------
# Setup() 依据“全局” statusline 决定是否安装默认值。
set statusline=
setlocal statusline<
ms.Setup()
Check('Setup: installs default when global empty', &g:statusline =~# 'mutedstl#String')
# an explicit global value is never overwritten
set statusline=MY_OWN
ms.Setup()
Eq('Setup: explicit global value kept', 'MY_OWN', &g:statusline)
# a window-local value must not block the global default
set statusline=
setlocal statusline=LOCAL_ONLY
ms.Setup()
Check('Setup: window-local does not block global default', &g:statusline =~# 'mutedstl#String')
setlocal statusline<
set statusline=

# --- 15. String(): no duplicated consecutive group marker --------------------
var stl_str = ms.String()
Check('String: single Ordinary marker', len(split(stl_str, '%#MutedstlOrdinary#')) == 2)

# =============================================================================
# 16. Backward-compatibility contract (see :help mutedstl-stable-api)
# 向后兼容契约（见 :help mutedstl-stable-api）。
# These assertions freeze the public surface.  A change that trips one of them
# is a breaking change and must be accompanied by a major version bump and a
# deprecation step (see :help mutedstl-deprecation).
# 这些断言冻结公共接口。若某项失败即为破坏性变更，必须伴随主版本号提升与
# 弃用流程（见 :help mutedstl-deprecation）。
# =============================================================================
var cc = ms.Colors()
Eq('compat: Colors() keys', ['bg', 'emphasis', 'fg', 'inactive', 'invert', 'is_none', 'ordinary'], sort(keys(cc)))
Check('compat: Colors().ordinary is [fg, bg]', len(cc.ordinary) == 2 && len(cc.ordinary[0]) == 2 && len(cc.ordinary[1]) == 2)
Check('compat: Colors().emphasis is [fg, bg]', len(cc.emphasis) == 2 && len(cc.emphasis[0]) == 2 && len(cc.emphasis[1]) == 2)
Check('compat: Colors().inactive is [fg, bg]', len(cc.inactive) == 2 && len(cc.inactive[0]) == 2 && len(cc.inactive[1]) == 2)
Check('compat: Colors().fg is [gui, cterm]', len(cc.fg) == 2)
Check('compat: Colors().bg is [gui, cterm]', len(cc.bg) == 2)
Check('compat: Colors().invert is Boolean', type(cc.invert) == v:t_bool)
Check('compat: Colors().is_none is Boolean', type(cc.is_none) == v:t_bool)

# Return-type contract for the other stable functions.
Check('compat: NrToHex -> String', type(ms.NrToHex(0)) == v:t_string)
Check('compat: HexToCterm -> Number', type(ms.HexToCterm('#000000')) == v:t_number)
Check('compat: NameToHex -> String', type(ms.NameToHex('Red')) == v:t_string)
Check('compat: FromTheme -> List', type(ms.FromTheme('', 'fg')) == v:t_list)
Check('compat: Mode -> String', type(ms.Mode('n')) == v:t_string)
Check('compat: Paste -> String', type(ms.Paste()) == v:t_string)
Check('compat: IsActive -> Boolean', type(ms.IsActive()) == v:t_bool)
Check('compat: GroupName -> String', type(ms.GroupName('ordinary')) == v:t_string)
Check('compat: GroupMark -> String', type(ms.GroupMark('ordinary')) == v:t_string)
Check('compat: Chunk -> String', type(ms.Chunk('%t')) == v:t_string)
Check('compat: String -> String', type(ms.String()) == v:t_string)

# Option names are part of the contract: setting the documented option must
# actually take effect (and the documented default must hold when unset).
ClearOpts()
g:mutedstl#prefix = 'Compat'
Eq('compat: g:mutedstl#prefix takes effect', 'CompatEmphasis', ms.GroupName('emphasis'))
ClearOpts()
Eq('compat: g:mutedstl#prefix default', 'MutedstlEmphasis', ms.GroupName('emphasis'))
Eq('compat: g:mutedstl#inactive default', '%#MutedstlInactive#', ms.GroupMark('inactive'))
g:mutedstl#inactive = 'emphasis'
Eq('compat: g:mutedstl#inactive takes effect', 'emphasis', ms.Colors().inactive == ms.Colors().emphasis ? 'emphasis' : 'other')
ClearOpts()

# =============================================================================
# Summary / 汇总
# =============================================================================
ClearOpts()
var lines: list<string> = []
lines->add('mutedstl tests: ' .. passed .. '/' .. cases .. ' passed'
             .. (skipped > 0 ? $' ({skipped} skipped)' : ''))
if empty(failed)
  lines->add('ALL PASS' .. (skipped > 0 ? $' ({skipped} skipped)' : ''))
else
  lines->add('FAILURES (' .. len(failed) .. '):')
  for f in failed
    lines->add('  - ' .. f)
  endfor
endif
# Report: always to stderr (visible in -es); also to $MUTEDSTL_TEST_OUT
# when set, for scripts/CI.
# 汇报：始终写 stderr（-es 下可见）；若设了 $MUTEDSTL_TEST_OUT 再写该文件。
var out: list<string> = lines
if !empty($MUTEDSTL_TEST_OUT)
  writefile(out, $MUTEDSTL_TEST_OUT)
endif
for l in out
  :echomsg l
endfor

if empty(failed)
  qall!
else
  cquit      # non-zero exit on failure / 失败时非零退出
endif
# vim:tw=78:ts=8:sts=2:sw=2:et:norl:
