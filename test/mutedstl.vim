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
var cases = 0

def Check(desc: string, cond: bool): void
  cases += 1
  if cond
    passed += 1
  else
    failed->add(desc)
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

# Ensure a deterministic colourscheme / 固定一个可预期的配色方案。
silent! execute 'colorscheme novum'
ms.ReloadCache()

# --- 1. Colors(): default comes from the current Normal ----------------------
# 默认取当前 Normal。
var base = ms.Colors()
Check('default: colors has ordinary/emphasis', has_key(base, 'ordinary') && has_key(base, 'emphasis'))
Check('default: fg is a [gui,cterm] pair', len(base.fg) == 2 && len(base.bg) == 2)
Check('default: not none', base.is_none == false)
Eq('default: ordinary=[fg,bg]', [base.fg, base.bg], base.ordinary)
Eq('default: emphasis=[bg,fg]', [base.bg, base.fg], base.emphasis)
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
  Eq('override name fg gui', '#a9a9a9', ms.Colors().fg[0])
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
var cached_theme = 'everforest'
WithOpts('', '', 0, () => {
  g:mutedstl#theme = cached_theme
  var t1 = ms.Colors()
  var t2 = ms.Colors()
  Eq('theme: stable across calls (cache hit)', t1.fg, t2.fg)
  Check('theme: fg is concrete', t1.fg[0] =~# '^#')
})
ClearOpts()
NoThrow('ReloadCache() does not throw', () => ms.ReloadCache())

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
Eq('NameToHex(DarkGrey)', '#a9a9a9', ms.NameToHex('DarkGrey'))
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

# --- 13. Refresh() / Redraw() do not throw -----------------------------------
NoThrow('Refresh() does not throw', () => ms.Refresh())
NoThrow('Redraw() does not throw', () => ms.Redraw())
NoThrow('Reassert() does not throw', () => ms.Reassert())

# =============================================================================
# Summary / 汇总
# =============================================================================
ClearOpts()
var lines: list<string> = []
lines->add('mutedstl tests: ' .. passed .. '/' .. cases .. ' passed')
if empty(failed)
  lines->add('ALL PASS')
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
