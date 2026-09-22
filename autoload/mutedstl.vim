vim9script
# =============================================================================
# autoload/mutedstl.vim
#
# Maintainer:  EssenMoon <yueqrgg@gmail.com>
# Last Change: 2026-09-23
#
#   LLM POWERED!   This plugin was designed and written with the help of a
#                  large language model.   LLM POWERED!
#   LLM POWERED！   本插件由大语言模型协助设计与编写。
#
# A deliberately clean "muted" statusline colour package for Vim 9: derives a
# two-colour pair from a colourscheme, exposes groups + reusable chunks.
# 刻意素洁的 Vim 9 "失色"状态栏取色包：从配色推导一对颜色，暴露组与可复用片段。
#
# Usage / 用法:   import autoload 'mutedstl.vim'  |  mutedstl.Setup()
# The mutedstl#Fn() names work too (used internally in the statusline expr and
# autocommands, where an import alias cannot).
# mutedstl#Fn() 同样可用（状态栏表达式与自动命令内部即用，那些位置无法用别名）。
#
# API: Setup/Refresh/Redraw/Reassert, String, Chunk, Colors/Hi/Apply/ApplyDefault,
#   Mode/Paste/IsActive, GroupName/GroupMark, FromTheme, ReloadCache,
#   NrToHex/HexToCterm/NameToHex.   See :help mutedstl
# Options (g:mutedstl#*): theme, invert, fg, bg, prefix, inactive.
# Override values / 覆盖值: '#RRGGBB', a colour name, a 256 index, or 'NONE'.
# =============================================================================

# --- option lookup / 选项查询 (g:mutedstl#* only) -------------------------
const opt_ns = 'mutedstl#'

# Read an option by name (g:mutedstl#<name>), or {default} if unset.
# 按名读取选项（g:mutedstl#<name>），未设时返回 {default}。
def Opt(name: string, default: any): any
  var key = opt_ns .. name
  return exists('g:' .. key) ? get(g:, key) : default
enddef

# Type-safe reads: an option set to an unexpected type falls back to {default}
# instead of raising a type error at the use site.  OptBool also normalises any
# number/string to a real Boolean (Vim9 rejects e.g. `if -5`).
# 类型安全读取：选项被设成意外类型时回退到 {default}，而不是在使用处抛类型
# 错误。OptBool 还会把任意数字/字符串规范化成真正的布尔值（Vim9 拒绝 `if -5`）。
def OptBool(name: string, default: bool): bool
  var v = Opt(name, default)
  if type(v) == v:t_bool
    return v
  elseif type(v) == v:t_number
    return v != 0
  elseif type(v) == v:t_string
    return !empty(v)
  endif
  return default
enddef

def OptStr(name: string, default: string): string
  var v = Opt(name, default)
  return type(v) == v:t_string ? v : default
enddef

# Resolve an override option (#fg / #bg) into a [gui, cterm] pair, or return []
# when it is unset / not a usable value (number or non-empty string).  Callers
# fall back to the theme pair on [].
# 把覆盖选项（#fg / #bg）解析为 [gui, cterm] 对；未设或非可用值（数字或非空
# 字符串）时返回 []，调用方据此回退到主题色对。
def Override(name: string): list<string>
  var key = opt_ns .. name
  if !exists('g:' .. key)
    return []
  endif
  var val = get(g:, key)
  if type(val) == v:t_number || (type(val) == v:t_string && !empty(val))
    return ResolveOne(val)
  endif
  return []
enddef

# --- colour primitives -------------------------------------------------------
# Design: Vim keeps the GUI channel (guifg/guibg) and the cterm channel
# (ctermfg/ctermbg, 0..255 index) INDEPENDENT; it never derives one from the
# other, and a theme author writes BOTH (e.g. Normal ... ctermfg=188).  The
# author's cterm value is authoritative for 256-colour terminals, so the flow
# is: read the theme's cterm first; only convert when a side is missing.
# 设计：Vim 的 GUI 通道与 cterm 通道相互独立、绝不互推，主题作者会同时写两者
# （如 ctermfg=188）。作者的 cterm 值在 256 终端下才是权威，故流程为：先读主题
# 的 cterm；仅在某侧缺失时才换算。

# Convert a 256-colour index to an approximate '#RRGGBB'.  Out-of-range
# values are clamped to 0..255 so callers always get a valid colour.
# 将 256 色号转为近似的 '#RRGGBB'。越界值被钳制到 0..255，保证调用方总能
# 得到合法颜色。
export def NrToHex(n: number): string
  var i = Clamp256(n)          # :def cannot assign to its arguments
  if i < 16
    const basic = [
      '#000000', '#800000', '#008000', '#808000',
      '#000080', '#800080', '#008080', '#c0c0c0',
      '#808080', '#ff0000', '#00ff00', '#ffff00',
      '#0000ff', '#ff00ff', '#00ffff', '#ffffff',
    ]
    return basic[i]
  elseif i < 232
    var m = i - 16
    const levels = [0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff]  # xterm cube levels
    var r = levels[m / 36]
    var g = levels[(m % 36) / 6]
    var b = levels[m % 6]
    return printf('#%02x%02x%02x', r, g, b)
  else
    var k = (i - 232) * 10 + 8
    return printf('#%02x%02x%02x', k, k, k)
  endif
enddef

# Standard xterm 256 palette, built once and cached.
# 标准 xterm 256 调色板，构建一次后缓存。
var palette: list<list<number>>
def Palette(): list<list<number>>
  if !empty(palette)
    return palette
  endif
  var p: list<list<number>> = [
    [0, 0, 0], [128, 0, 0], [0, 128, 0], [128, 128, 0],
    [0, 0, 128], [128, 0, 128], [0, 128, 128], [192, 192, 192],
    [128, 128, 128], [255, 0, 0], [0, 255, 0], [255, 255, 0],
    [0, 0, 255], [255, 0, 255], [0, 255, 255], [255, 255, 255],
  ]
  const levels = [0, 95, 135, 175, 215, 255]
  for r in levels
    for g in levels
      for b in levels
        add(p, [r, g, b])
      endfor
    endfor
  endfor
  for i in range(24)
    var v = 8 + i * 10
    add(p, [v, v, v])
  endfor
  palette = p
  return p
enddef

# Nearest xterm-256 index for '#RRGGBB' (min squared RGB distance).  Fallback
# only, used when a theme provides no cterm colour.
# 为 '#RRGGBB' 求最近的 xterm-256 色号（RGB 平方距离最小）。仅在主题未提供
# cterm 色时作为回退。
export def HexToCterm(hex: string): number
  # Strict: exactly '#RRGGBB' with hex digits only.  Without the character
  # class a value like '#gggggg' would match '..' and silently resolve to 0.
  # 严格匹配：恰好 '#RRGGBB' 且仅含十六进制字符。若不加字符类，'#gggggg'
  # 也会被 '..' 匹配并静默解析成 0。
  var m = matchlist(hex, '#\([0-9a-fA-F]\{2\}\)\([0-9a-fA-F]\{2\}\)\([0-9a-fA-F]\{2\}\)$')
  if empty(m)
    return -1
  endif
  var r = str2nr(m[1], 16)
  var g = str2nr(m[2], 16)
  var b = str2nr(m[3], 16)
  var best = 0
  var bestd = 1 << 30
  var i = 0
  for c in Palette()
    var dr = r - c[0]
    var dg = g - c[1]
    var db = b - c[2]
    var d = dr * dr + dg * dg + db * db
    if d < bestd
      bestd = d
      best = i
    endif
    i += 1
  endfor
  return best
enddef

# Resolve a colour NAME to '#RRGGBB' via the built-in v:colornames dict
# (Vim 8.2.4774+): a pure, side-effect-free table, unlike the old
# "define a highlight and read it back" trick.  Keys are lower case.
# 用内置 v:colornames 字典解析颜色名（Vim 8.2.4774+）：纯只读、无副作用。键为
# 小写。
export def NameToHex(name: string): string
  return get(v:colornames, tolower(name), '')
enddef

# Normalise a gui value to '#RRGGBB' (hlget may return a colour name).
# 把 gui 值归一化为 '#RRGGBB'（hlget 可能返回颜色名）。
def NormGui(gui: string): string
  if empty(gui) || gui ==# 'NONE' || gui =~# '^#'
    return gui
  endif
  return NameToHex(gui)
enddef

# Clamp a numeric colour index into the valid 0..255 range.  An out-of-range
# value (e.g. g:mutedstl#fg = 300) would otherwise reach hlset() as an invalid
# ctermfg and raise E254, so we normalise it here instead.
# 把数字色号钳制到合法的 0..255 范围。否则越界值（如 g:mutedstl#fg = 300）
# 会以非法 ctermfg 传给 hlset() 触发 E254，故在此归一化。
def Clamp256(n: number): number
  return n < 0 ? 0 : (n > 255 ? 255 : n)
enddef

# --- resolve one colour into a [gui, cterm] pair -----------------------------
# Resolve a user option value (g:mutedstl#fg / #bg) into [gui, cterm].  The
# value may be a 256-index number/'string', '#RRGGBB', a colour name or 'NONE'.
# 将用户选项值（g:mutedstl#fg / #bg）解析为 [gui, cterm]，可为 256 色号数字
# 或字符串、'#RRGGBB'、颜色名或 'NONE'。
def ResolveOne(val: any): list<string>
  if type(val) == v:t_number
    var n = Clamp256(val)                                # accept 0..255 only
    return [NrToHex(n), string(n)]
  endif
  # Take the string verbatim: string(val) would add quotes in Vim9.
  # 原样取字符串：Vim9 中 string(val) 会给字符串加引号。
  var s = type(val) == v:t_string ? val : ''
  if s ==# 'NONE'
    return ['NONE', 'NONE']
  elseif s =~# '^\d\+$'
    var n = Clamp256(str2nr(s))                          # accept 0..255 only
    return [NrToHex(n), string(n)]
  elseif s =~# '^#'
    var c = HexToCterm(s)                              # hex: approximate cterm
    return [s, c < 0 ? 'NONE' : string(c)]
  else
    var hex = NameToHex(s)                             # name: to hex, then cterm
    if empty(hex)
      return ['NONE', 'NONE']
    endif
    var c = HexToCterm(hex)
    return [hex, c < 0 ? 'NONE' : string(c)]
  endif
enddef

# Build [gui, cterm] from a theme's raw hlget values: theme cterm is
# authoritative, convert only the missing side.
# 用主题 hlget 的原始值构造 [gui, cterm]：主题 cterm 权威，仅换算缺失的一侧。
def ThemePairFrom(gui: string, cterm: string): list<string>
  var g = NormGui(gui)
  var c = cterm
  if g ==# 'NONE' || (empty(g) && empty(c))
    return ['NONE', 'NONE']
  endif
  if empty(c)                                          # cterm missing: approximate
    var n = HexToCterm(g)
    c = n < 0 ? 'NONE' : string(n)
  endif
  if empty(g)                                          # gui missing: reverse-map
    g = c ==# 'NONE' ? 'NONE' : NrToHex(str2nr(c))
  endif
  return [g, c]
enddef

# --- read a theme's opaque Normal channels -----------------------------------
# Known transparent-background switches, forced off while reading so a
# transparent theme still yields its real (opaque) background colour.
# 已知的透明背景开关；读取时强制关闭，使透明主题仍能给出真实的（非透明）背景色。
const transparent_opts = [
  'everforest_transparent_background',
  'catppuccin_transparent_background',
  'iceberg_transparent_background',
  'tokyonight_transparent_background',
]

# Current Normal's four channels via hlget() ('' when absent).
# 用 hlget() 读取当前 Normal 的四个通道（缺失时为空串）。
def ReadNormal(): dict<string>
  var g = hlget('Normal', v:true)
  if empty(g)
    return {}
  endif
  return {
    'guifg':   get(g[0], 'guifg', ''),
    'guibg':   get(g[0], 'guibg', ''),
    'ctermfg': get(g[0], 'ctermfg', ''),
    'ctermbg': get(g[0], 'ctermbg', ''),
  }
enddef

# Cache of a named theme's opaque Normal channels, keyed by
# '{theme}|{background}'.  Reading a theme means a real `:colorscheme` round
# trip (~2 ms), so caching it makes repeated Colours()/Refresh() calls cheap.
# The current theme (theme == '') is never cached: it changes with
# :colorscheme and is just read directly.  ReloadCache() drops everything.
# 指定主题非透明 Normal 通道的缓存，键为 '{主题}|{background}'。读取一个主题
# 需要真实地 `:colorscheme` 往返一次（约 2ms），缓存后重复调用即廉价。当前主题
# （theme == ''）不缓存：它随 :colorscheme 变化，直接读取即可。ReloadCache()
# 清空全部缓存。
var theme_cache: dict<dict<string>>

def ReadThemeNormal(theme: string): dict<string>
  # Current theme: read directly, no switching, no caching.
  # 当前主题：直接读取，不切换、不缓存。
  if empty(theme)
    return ReadNormal()
  endif

  var key = theme .. '|' .. &background
  if has_key(theme_cache, key)
    return theme_cache[key]
  endif

  var had_name = exists('g:colors_name')
  var orig = get(g:, 'colors_name', '')
  var switched = false
  var orig_bg_opt = &background
  var saved: dict<number> = {}
  for var in transparent_opts
    if exists('g:' .. var)
      saved[var] = get(g:, var, 0)
      g:[var] = 0            # set global by name (Vim9 has no :let)
    endif
  endfor
  try
    noautocmd execute $'colorscheme {theme}'
    switched = true
  catch
    switched = false
  endtry
  # A failed switch leaves the PREVIOUS theme's Normal in place; reading it
  # here would silently return the wrong colours (and cache them).  Report an
  # empty result instead and do not cache, so callers fall back to NONE.
  # 切换失败会残留上一个主题的 Normal；此时读取会静默返回错误颜色（并被缓存）。
  # 故改为返回空结果且不缓存，让调用方回退到 NONE。
  var normal = switched ? ReadNormal() : {}
  if switched
    if had_name && !empty(orig)
      silent! noautocmd execute $'colorscheme {orig}'
    endif
    # Restore g:colors_name itself too: ':colorscheme {theme}' set it.  When
    # the user had no colours_name at all, remove it again so the switch leaves
    # no trace in the user's state.
    # 同样要恢复 g:colors_name 本身：':colorscheme {theme}' 设置了它。若用户
    # 原本就没有 colors_name，则再次删除，使切换不在用户状态里留痕。
    if !had_name
      unlet! g:colors_name
    endif
  endif
  &background = orig_bg_opt
  for [var, val] in items(saved)
    g:[var] = val
  endfor
  if switched
    theme_cache[key] = normal
  endif
  return normal
enddef

# Drop the theme colour cache (call after changing/installing colourschemes).
# 清空主题颜色缓存（切换/新装配色方案后调用）。
export def ReloadCache(): void
  theme_cache = {}
enddef

# Resolve the source theme's fg/bg into [gui, cterm] pairs.
# 解析来源主题的前景/背景为 [gui, cterm] 对。
def ThemePair(attr: string): list<string>
  var theme = OptStr('theme', '')
  var n = ReadThemeNormal(theme)
  if attr ==# 'fg'
    return ThemePairFrom(get(n, 'guifg', ''), get(n, 'ctermfg', ''))
  else
    return ThemePairFrom(get(n, 'guibg', ''), get(n, 'ctermbg', ''))
  endif
enddef

# --- public colour API / 公共取色接口 ----------------------------------------
# Derive [ordinary, emphasis] from the source fg/bg and invert.  ordinary keeps
# fg-on-bg, emphasis swaps them; a 'NONE' side makes one chunk the derived
# concrete pair (so invert still works) and the other fully transparent.
# 由源 fg/bg 与 invert 派生 [ordinary, emphasis]：ordinary 为 fg-on-bg，
# emphasis 交换；某侧为 'NONE' 时一个区块用推导实色对（使 invert 仍可用），
# 另一个完全透明。
def DeriveChunks(s_fg: list<string>, s_bg: list<string>, invert: bool): list<list<any>>
  var fg_none = s_fg[0] ==# 'NONE'
  var bg_none = s_bg[0] ==# 'NONE'
  if !fg_none && !bg_none
    return [[copy(s_fg), copy(s_bg)], [copy(s_bg), copy(s_fg)]]
  endif
  var dark = &background !=# 'light'
  var concrete = [
    dark ? ['#ffffff', '15'] : ['#000000', '0'],
    dark ? ['#000000', '0'] : ['#ffffff', '15'],
  ]
  if !fg_none
    concrete[0] = copy(s_fg)
  endif
  if !bg_none
    concrete[1] = copy(s_bg)
  endif
  var blank = [['NONE', 'NONE'], ['NONE', 'NONE']]
  return invert ? [concrete, blank] : [blank, concrete]
enddef

# The source fg/bg pair: an explicit #fg/#bg override wins; otherwise the
# theme's Normal pair (swapped when invert is set).
# 源 fg/bg 对：显式 #fg/#bg 覆盖优先；否则用主题 Normal 色对（invert 时交换）。
def SourcePair(invert: bool): list<list<string>>
  var s_fg = Override('fg')
  var s_bg = Override('bg')
  if empty(s_fg)
    s_fg = invert ? ThemePair('bg') : ThemePair('fg')
  endif
  if empty(s_bg)
    s_bg = invert ? ThemePair('fg') : ThemePair('bg')
  endif
  return [s_fg, s_bg]
enddef

# Resolve the muted colours.  STABLE INTERFACE / 稳定接口.
#
# Returns a Dictionary / 返回字典:
#   ordinary  [fg, bg]  the normal chunk     / 普通区块
#   emphasis  [fg, bg]  the inverted chunk   / 反色区块
#   inactive  [fg, bg]  chunk for non-current windows (see g:mutedstl#inactive)
#   fg        [gui, cterm]  resolved foreground / 解析后的前景
#   bg        [gui, cterm]  resolved background / 解析后的背景
#   invert    0 | 1         whether fg/bg were swapped / 是否已交换
#   is_none   0 | 1         true if a side is transparent / 某侧是否透明
#
# Each [fg, bg] is a pair [[gui, cterm], [gui, cterm]]; 'gui' is '#RRGGBB' (or
# 'NONE') and 'cterm' is a 0..255 index string (or 'NONE').  Field names and
# their meanings are meant to stay stable for other plugins to consume.
# 每个 [fg, bg] 为 [[gui, cterm], [gui, cterm]]；gui 为 '#RRGGBB'（或 'NONE'），
# cterm 为 0..255 的字符串（或 'NONE'）。字段名与含义意在保持稳定，供其它插件
# 消费。
export def Colors(): dict<any>
  var invert = OptBool('invert', false)
  var src = SourcePair(invert)
  var chunks = DeriveChunks(src[0], src[1], invert)
  var kind = InactiveKind()
  return {
    ordinary: chunks[0],
    emphasis: chunks[1],
    inactive: kind ==# 'emphasis' ? chunks[1] : chunks[0],
    fg: copy(src[0]),
    bg: copy(src[1]),
    invert: invert,
    is_none: src[0][0] ==# 'NONE' || src[1][0] ==# 'NONE',
  }
enddef

# Which chunk the inactive (non-current) windows should use.  Default is the
# ordinary chunk; set g:mutedstl#inactive = 'emphasis' to use the inverted pair
# instead (e.g. to make inactive windows stand out differently).
# 非当前窗口使用哪个区块。默认 ordinary；设 g:mutedstl#inactive = 'emphasis'
# 可改用反色对。
def InactiveKind(): string
  return OptStr('inactive', 'ordinary') ==# 'emphasis' ? 'emphasis' : 'ordinary'
enddef

# Apply one [fg, bg] chunk to a highlight group.
# 把一个 [前景, 背景] 区块应用到某高亮组。
export def Hi(group: string, chunk: list<any>): void
  var fg = chunk[0]
  var bg = chunk[1]
  # hlset() is the structured highlight API: no command-string building (so a
  # colour value can never break the command), and it is far faster than
  # :highlight.  A 'NONE' value removes that attribute, same as
  # `:highlight guifg=NONE` would.
  # hlset() 是结构化高亮 API：无需拼命令字符串（颜色值绝不会破坏命令），且远快
  # 于 :highlight。'NONE' 值会移除该属性，与 `:highlight guifg=NONE` 一致。
  hlset([{
    name: group,
    guifg: fg[0],
    guibg: bg[0],
    ctermfg: fg[1],
    ctermbg: bg[1],
  }])
enddef

# Apply {group: 'ordinary'|'emphasis'} using the muted colours.
# 用 muted 颜色应用 {组名: 'ordinary'|'emphasis'}。
export def Apply(groups: dict<string>): void
  var c = Colors()
  for [group, kind] in items(groups)
    var chunk = get(c, kind, c.ordinary)
    Hi(group, chunk)
  endfor
enddef

# Register the three statusline groups: active emphasis (mode), active ordinary
# (file/right), and inactive (always ordinary; never emphasis).
# 注册三个状态栏组：活动 emphasis（模式）、活动 ordinary（文件/右侧）、inactive
# （始终 ordinary，从不用 emphasis）。
export def ApplyDefault(): void
  Apply({
    [Grp('emphasis')]: 'emphasis',
    [Grp('ordinary')]: 'ordinary',
    [Grp('inactive')]: 'inactive',
  })
enddef

# Highlight-group name prefix; override with g:mutedstl#prefix.
# 高亮组名前缀；可用 g:mutedstl#prefix 覆盖。
def Prefix(): string
  return OptStr('prefix', 'Mutedstl')
enddef

# Internal: the concrete group name for a logical kind.
# 内部：逻辑类别对应的具体组名。
def Grp(kind: string): string
  if kind ==# 'emphasis'
    return Prefix() .. 'Emphasis'
  elseif kind ==# 'ordinary'
    return Prefix() .. 'Ordinary'
  elseif kind ==# 'inactive'
    return Prefix() .. 'Inactive'
  else
    # Any other value is taken as a literal highlight-group name, so callers
    # can use their own groups (e.g. 'Error', 'Warning', 'MyAccent').
    # 其它值视为字面高亮组名，便于调用方使用自定义组（如 Error/Warning）。
    return kind
  endif
enddef

# Public: read a colour pair from a named theme's Normal group.  {attr} is
# 'fg' or 'bg'; returns [gui, cterm] (both channels, cterm authoritative).
# {theme} may be '' for the current colourscheme.  Handy for reusing mutedstl's
# theme-aware colour reading in your own statusline/tabline/etc.
# 公共接口：从指定主题的 Normal 组读取 [gui, cterm] 颜色对。{attr} 为 'fg' 或
# 'bg'；{theme} 为空表示当前配色。便于在他人的状态栏/标签栏中复用本插件的主题
# 取色。
export def FromTheme(theme: string, attr: string): list<string>
  var n = ReadThemeNormal(theme)
  if attr ==# 'fg'
    return ThemePairFrom(get(n, 'guifg', ''), get(n, 'ctermfg', ''))
  else
    return ThemePairFrom(get(n, 'guibg', ''), get(n, 'ctermbg', ''))
  endif
enddef

# Public: map a logical kind to its highlight group name (honours
# g:mutedstl#prefix).  For use in a custom 'statusline'.
# 公共接口：把逻辑类别映射到高亮组名（遵循 g:mutedstl#prefix）。供自定义
# 'statusline' 使用。  kind: 'emphasis' | 'ordinary' | 'inactive'
export def GroupName(kind: string): string
  return Grp(kind)
enddef

# Like GroupName() but returns '%#Group#', i.e. a statusline group marker you
# can concatenate; for 'emphasis'/'ordinary' it picks the inactive variant when
# the rendered window is not the current one.
# 类似 GroupName()，但返回 '%#组名#'（可直接拼接的状态栏组标记）；对
# 'emphasis'/'ordinary' 会在非当前窗口渲染时选用 inactive 变体。
export def GroupMark(kind: string): string
  var g = ResolveGroup(kind)
  return $'%#{g}#'
enddef

# =============================================================================
# Statusline front end / 状态栏前端
# =============================================================================

# Mode labels keyed by the leading char of mode(1) (per :h mode(): compare the
# leading char, not the whole string).  A few multi-char modes whose first char
# would lose meaning (nt, Rv, cv) are kept exact.
# 模式标签以 mode(1) 首字符为键（依 :h mode()：比较首字符而非整串）。少数首字符
# 会丢失含义的多字符模式（nt、Rv、cv）作精确匹配。
const mode_exact: dict<string> = {
  'nt': 'TERM-N',
  'Rv': 'V-REPLACE',
  'cv': 'EX',
}
const mode_first: dict<string> = {
  'n': 'NORMAL',
  'v': 'VISUAL',
  'V': 'V-LINE',
  "\<C-v>": 'V-BLOCK',
  's': 'SELECT',
  'S': 'S-LINE',
  "\<C-s>": 'S-BLOCK',
  'i': 'INSERT',
  'R': 'REPLACE',
  'c': 'COMMAND',
  'r': 'PROMPT',
  '!': 'SHELL',
  't': 'TERMINAL',
}

# Human-readable mode string; the optional argument overrides mode(1) for tests.
# 可读模式字样；可选参数覆盖 mode(1)（用于测试）。
export def Mode(...args: list<any>): string
  # An optional argument overrides mode(1) (mainly for tests); it is only
  # honoured when it is a string, otherwise mode(1) is used.  This keeps a
  # stray non-string argument from raising E1012.
  # 可选参数用于覆盖 mode(1)（主要用于测试）；仅当它是字符串时生效，否则用
  # mode(1)，以免误传非字符串触发 E1012。
  var m: string = (len(args) > 0 && type(args[0]) == v:t_string) ? args[0] : mode(1)
  if empty(m)
    return ''
  endif
  return get(mode_exact, m, get(mode_first, m[0], m))
enddef

export def Paste(): string
  return &paste ? 'PASTE' : ''
enddef

# True when the window being rendered is the current one.  'statusline'/'%!' is
# evaluated per window with g:statusline_winid bound to that window, so this is
# safe to call from String().
# 正在渲染的窗口是否为当前窗口。'statusline'/'%!' 按窗口求值且此时
# g:statusline_winid 指向该窗口，故在 String() 内调用安全。
export def IsActive(): bool
  return !exists('g:statusline_winid') || win_getid() == g:statusline_winid
enddef

# The group to render in: the given active group, or MutedstlInactive for
# non-current windows.
# 渲染所用的组：活动窗口用给定组名，非当前窗口用 MutedstlInactive。
# True for a logical kind (which participates in the active/inactive switch).
# 逻辑类别（参与活动/非活动切换）返回真。
def IsKind(kind: string): bool
  return kind ==# 'emphasis' || kind ==# 'ordinary' || kind ==# 'inactive'
enddef

# Resolve a {kind} to the concrete group name for the window being rendered:
#   - 'emphasis'/'ordinary': the plugin group, or the inactive group when the
#     window is not current;
#   - 'inactive': the inactive group explicitly;
#   - anything else: used verbatim as a literal highlight-group name (never
#     switched to inactive), so callers may plug in their own groups.
# 将 {kind} 解析为当前渲染窗口的具体组名：emphasis/ordinary 为非活动窗口时用
# inactive 组；inactive 显式用 inactive 组；其它值按字面组名原样使用（不切换），
# 便于调用方接入自定义组。
def ResolveGroup(kind: string): string
  if !IsKind(kind)
    return kind
  elseif kind ==# 'inactive'
    return Grp('inactive')
  endif
  return IsActive() ? Grp(kind) : Grp('inactive')
enddef

# Public: wrap ANY statusline content in one of the plugin's groups.  {content}
# is passed through verbatim (parsed by Vim's 'statusline'): a fixed string, any
# item ('%t', '%<%t%m%r'), or a function ('%{mutedstl#Mode()}').  {kind} is
# 'emphasis' | 'ordinary' (default) | 'inactive'; no spaces are added.
#   Chunk('%t') / Chunk('%{mutedstl#Mode()}', 'emphasis') / Chunk(' | ')
# 公共接口：把任意状态栏内容套上本插件的组。{content} 原样传回、交由 Vim 的
# 'statusline' 解析（固定文本、任意项或函数均可）。{kind} 为 emphasis/ordinary
# （默认）/inactive；不添加空格。示例见上。
export def Chunk(content: string, ...args: list<any>): string
  var kind: string = len(args) > 0 ? args[0] : 'ordinary'
  var g = ResolveGroup(kind)
  return $'%#{g}#{content}'
enddef


# --- assemble the default statusline ----------------------------------------
# 组装默认状态栏。
export def String(): string
  # The DEFAULT layout: mode in emphasis, the rest in ordinary.  It is only a
  # default -- build your own 'statusline' from Chunk()/GroupMark() instead.
  # 默认布局：模式用 emphasis，其余用 ordinary。它只是默认值——可改用
  # Chunk()/GroupMark() 自建 'statusline'。
  var s = Chunk('%{mutedstl#Mode()}%{mutedstl#Paste()} ', 'emphasis')
  # One ordinary chunk (a single group marker) for everything after the mode.
  # 模式之后的全部内容共用一个 ordinary 区块（单个组标记，避免重复）。
  s ..= Chunk('%( %<%t %) %m%r%= %y | Buf:%n | [%l:%c] %P of %LL ', 'ordinary')
  return s
enddef

# --- color refresh -----------------------------------------------------------
# Highlight groups depend only on the source theme and 'background' (not on the
# mode or focused window), so refresh is only needed on ColorScheme/background.
# 高亮组只依赖来源主题与 'background'（不依赖模式或聚焦窗口），故仅在
# ColorScheme/background 变化时刷新。
export def Refresh(): void
  ApplyDefault()
enddef

# Redraw only when safe: a late redrawstatus during startup/shutdown makes Vim
# emit extra terminal sequences (kitty artifacts), so skip while v:dying.
# 仅在安全时重绘：启动/退出时的 redrawstatus 会输出多余终端序列（kitty 残影），
# 故 v:dying 时跳过。
export def Redraw(): void
  if exists('v:dying') && v:dying
    return
  endif
  redrawstatus
enddef

# Plugins may leave a stale WINDOW-LOCAL 'statusline' (vim-matchup's offscreen
# races on fast tag jumps; goyo hides it) that shadows the global one and can
# show a stray fragment like '/'.  `setlocal statusline<` clears it so the
# window inherits the global statusline again.
# 插件可能残留“窗口局部”的 'statusline'（matchup offscreen 快速跳转时竞态；
# goyo 隐藏它），遮蔽全局值并可能只剩 '/' 之类残片。`setlocal statusline<`
# 清除它，使窗口重新继承全局状态栏。
export def Reassert(): void
  setlocal statusline<
enddef

# Install the statusline and refresh autocmds.
# 安装状态栏与刷新自动命令。
export def Setup(): void
  Refresh()
  # Install String() as the DEFAULT 'statusline', but only when no GLOBAL
  # value is set; an explicit value (your own layout) is never overwritten.
  # Testing the global (not the effective, window-local-overridden) value means
  # a window-local 'statusline' in one window does not stop every OTHER window
  # from inheriting the default.
  # 仅当“全局”未设置时把 String() 作为默认 'statusline'；显式值（自定义布局）
  # 不会被覆盖。判断全局值（而非被窗口局部遮蔽的有效值），这样一个窗口的局部
  # 'statusline' 不会阻止其它窗口继承默认值。
  if empty(&g:statusline)
    set statusline=%!mutedstl#String()
  endif
  augroup mutedstl
    autocmd!
    # Highlights change only with the colourscheme/'background'.
    # 仅在配色或 'background' 变化时刷新高亮。
    autocmd ColorScheme * mutedstl#Refresh() | mutedstl#Redraw()
    autocmd OptionSet background mutedstl#Refresh() | mutedstl#Redraw()
    # Re-assert on buffer/window entry so a stale window-local 'statusline'
    # (left by another plugin) cannot keep shadowing it (see Reassert()).
    # 进入缓冲区/窗口时重新声明，避免其它插件遗留的窗口局部 'statusline' 持续
    # 遮蔽（见 Reassert()）。
    autocmd BufWinEnter,WinEnter,FileType * mutedstl#Reassert()
  augroup END
enddef
# vim:tw=78:ts=8:sts=2:sw=2:et:norl:
