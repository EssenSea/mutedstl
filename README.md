# mutedstl

> **LLM POWERED!** — This plugin was designed and written with the help of a
> large language model. **LLM POWERED！**
> 本插件由大语言模型协助设计与编写。

A self-contained, deliberately **clean** statusline for Vim 9 — two colours,
no colour noise — written in pure Vim9script with **no dependencies**.

一个自包含的、刻意**素洁（clean）**的 Vim 9 状态栏 —— 两种颜色，不做色彩堆
砌 —— 纯 Vim9script 编写，**零依赖**。

> **素洁：前后景协调，即几乎适配任何主题；多色状态栏除外。**

It needs **no per-theme colourfile**: mutedstl reads each colourscheme's own
`Normal` foreground/background, so built-in and third-party themes work
as-is.  (Contrast lightline/airline, which ship a colourfile *per theme* and
otherwise fall back to `default`.)

它**无需逐主题配色文件**：mutedstl 读取各配色方案自带的 `Normal` 前后景，
因此内置与三方主题开箱即用。（对比 lightline/airline：它们为**每个主题**单独
附带配色，否则回退到 `default`。）

---

## Features / 特性

- Derives a muted foreground/background pair from the active colourscheme (or
  from any other theme you name).
  从当前配色（或你指定的任意主题）推导淡化的前景/背景色对。
- Reads the **theme's own cterm value first** (authoritative for 256-colour
  terminals); approximates only a missing side.
  优先读取**主题自带的 cterm 值**（256 终端下权威），仅在缺失一侧时近似。
- Uses Vim's own `hlget()` / `hlset()` / `v:colornames` — **zero external
  dependencies**.
  使用 Vim 自带的 `hlget()` / `hlset()` / `v:colornames` —— **零外部依赖**。
- Three highlight groups: active `Emphasis` / `Ordinary`, plus `Inactive`
  (non-current windows, always ordinary).
  三个高亮组：活动 `Emphasis` / `Ordinary`，以及 `Inactive`（非当前窗口，始终
  ordinary）。
- Named-theme colour cache; cheap repeated refresh.
  命名主题颜色缓存；重复刷新廉价。
- Ships with a headless regression test suite.
  附带无头回归测试套件。

## Requirements / 依赖

- **Vim 9** with `+vim9script` (uses `hlget`/`hlset`, `v:colornames`).
  **Vim 9**，需 `+vim9script`。
- Modern Vim on Vim 8 stays dormant (harmless).

## Installation / 安装

**As a Vim package / 作为 Vim 包：**

```
~/.vim/pack/mutedstl/start/mutedstl/
```

**With vim-plug / 用 vim-plug**：

```vim
call plug#begin()
Plug 'EssenSea/mutedstl'
call plug#end()
```

A local path also works (must start with `~` or `%`):
本地路径亦可（须以 `~` 或 `%` 开头）：

```vim
Plug '~/path/to/mutedstl'
```

Any other plugin manager works too — just point it at this directory (it has
the standard `autoload/`, `plugin/`, `doc/` layout).
其它插件管理器亦可 —— 指向本目录即可（具备标准 `autoload/`、`plugin/`、`doc/`
结构）。

## Enabling / 启用

```vim
set laststatus=2
set noshowmode
let g:mutedstl#invert = 1
call mutedstl#Setup()
```

Or auto-setup on VimEnter / 或在 VimEnter 自动启用：

```vim
let g:mutedstl_auto_setup = 1
```

## Options / 选项

All in the `g:mutedstl#` namespace; see `:help mutedstl-options`.

| Option | Default | Meaning / 含义 |
|---|---|---|
| `g:mutedstl#theme`  | `''` | Source theme (`''` = current). / 取色来源主题 |
| `g:mutedstl#invert` | `0`  | Swap fg/bg. / 交换前景背景 |
| `g:mutedstl#fg`     | —    | Foreground override. / 前景覆盖 |
| `g:mutedstl#bg`     | —    | Background override. / 背景覆盖 |
| `g:mutedstl#prefix` | `'Mutedstl'` | Group-name prefix. / 组名前缀 |
| `g:mutedstl#inactive` | `'ordinary'` | Chunk for non-current windows (`ordinary`/`emphasis`). / 非当前窗口区块 |

Override values: `'#RRGGBB'`, a colour name, a 256-colour index, or `'NONE'`.
覆盖值：`'#RRGGBB'`、颜色名、256 色号或 `'NONE'`。

## Custom statusline / 自定义状态栏

`Setup()` installs `String()` as the **default** layout, but only when you have
not set `'statusline'` yourself.  To roll your own, set `'statusline'` first
(an explicit value is never overwritten) and build it from the plugin's groups:

`Setup()` 会在你**尚未设置** `'statusline'` 时把 `String()` 作为**默认**布局装上。
若要自定义，请先设 `'statusline'`（显式值不会被覆盖），用本插件的组拼装：

```vim
&statusline = mutedstl#GroupMark('emphasis')
      \ .. ' %{mutedstl#Mode()}%{mutedstl#Paste()} '
      \ .. mutedstl#GroupMark('ordinary') .. ' %<%f%m%r%=%y | Buf:%n | [%l:%c]'
call mutedstl#Setup()
```

Groups / 组：`%#MutedstlEmphasis#` `%#MutedstlOrdinary#` `%#MutedstlInactive#`

(An `import autoload 'mutedstl.vim'` alias works too; the `mutedstl#Fn()` names
are used here for brevity and because the 'statusline' string needs them
anyway. / 也可用 `import autoload 'mutedstl.vim'` 别名；这里用 `mutedstl#Fn()`
更简洁，且 'statusline' 字符串本就需要它。)

## Reusable chunks / 可复用片段

One function wraps ANY statusline content in one of the three groups.  The
content is passed through verbatim and parsed by Vim's 'statusline' mechanism,
so it may be a fixed string, any item (`%t`, `%<%t%m%r`, `%l:%c`, `%P`, ...),
or a statusline function (`%{mutedstl#Mode()}`):

一个函数把任意状态栏内容套上三种组之一。内容原样传回、交由 Vim 的
'statusline' 机制解析，因此可以是固定文本、任意项（`%t`、`%<%t%m%r`、
`%l:%c`、`%P`…）或状态栏函数（`%{mutedstl#Mode()}`）：

```vim
&statusline = mutedstl#Chunk('%{mutedstl#Mode()}%{mutedstl#Paste()} ', 'emphasis')
      \ .. mutedstl#Chunk('%( %<%t %) %m%r', 'ordinary')
      \ .. mutedstl#Chunk('%= %y | Buf:%n | [%l:%c] %P of %LL ', 'ordinary')
```

`kind` may be a *logical* name (`'emphasis'` | `'ordinary'` def. |
`'inactive'`), resolved via `mutedstl#GroupName()` (so `g:mutedstl#prefix`
applies), **or ANY highlight group name** (e.g. `'Error'`, `'Warning'`,
`'MyAccent'`), which is used verbatim and never switched to inactive.  No
spaces are added.

`kind` 可以是**逻辑名**（`'emphasis'` | `'ordinary'` 默认 | `'inactive'`），经
`mutedstl#GroupName()` 解析（故受 `g:mutedstl#prefix` 影响）；**也可以是任意
高亮组名**（如 `'Error'`、`'Warning'`、`'MyAccent'`），此时原样使用、不切换到
inactive。`Chunk()` 不添加空格。

```vim
&statusline = mutedstl#Chunk('%= %{ale#statusline#Count()}', 'Error')   " your group
```

## `<Plug>` mappings / `<Plug>` 映射

Map these yourself / 自行映射：

```vim
nmap <Leader>mr <Plug>(mutedstl-refresh)   " re-apply groups + redraw / 重算并重绘
nmap <Leader>md <Plug>(mutedstl-redraw)    " redraw only / 仅重绘
nmap <Leader>mL <Plug>(mutedstl-reload)    " drop cache + re-apply + redraw / 清缓存并重算
```


## Documentation / 文档

```vim
:help mutedstl
```

## Tests / 测试

```sh
test/run.sh
# or
vim -N -u NONE -i NONE -es -S test/mutedstl.vim
```

Expected / 预期：`mutedstl tests: NN/NN passed` + `ALL PASS`.

## Contributing / 贡献

- **Pull requests are welcome.** / **欢迎 PR。**
- **Bugs will be maintained.** / **Bug 会维护。**
- **Feature requests are considered very carefully** — kept minimal on purpose.
  A new feature is most likely to be accepted if it has a chance of being
  merged into Vim itself as a built-in plugin; otherwise it is probably better
  left to the user.
  **功能请求会被审慎对待** —— 本插件刻意保持精简。只有当某个功能
  **有机会被合并为 Vim 内置插件**时才最可能被接受；否则更适合交给用户自行实现。

## License / 许可

MIT — see [LICENSE](LICENSE).  With attribution: **LLM POWERED!**

## Credits / 致谢

Designed and written with the help of a large language model. **LLM POWERED!**
由大语言模型协助设计与编写。**LLM POWERED！**
