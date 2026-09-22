# mutedstl

[![CI](https://github.com/EssenSea/mutedstl/actions/workflows/ci.yml/badge.svg)](https://github.com/EssenSea/mutedstl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A self-contained, deliberately **clean** statusline for Vim 9: two colours, no
colour noise, pure Vim9script with **no dependencies**.

一个自包含、刻意素洁的 Vim 9 状态栏：两种颜色，零依赖。

It needs **no per-theme colourfile**: it reads the active colourscheme's own
`Normal` foreground/background, so any built-in or third-party theme works
as-is.

它无需逐主题配色文件：读取配色自带的 `Normal` 前后景，任何主题开箱即用。

> Designed and written with the help of a large language model.  **LLM POWERED!**

## Requirements

- Vim 9.1+ with `+vim9script` (uses `hlget()`/`hlset()`; `v:colornames` is
  optional).  On older Vim or builds without those APIs the plugin stays
  dormant — it never errors.

## Installation

As a Vim package:

```
~/.vim/pack/mutedstl/start/mutedstl/
```

Or with any plugin manager:

```vim
Plug 'EssenSea/mutedstl'
```

## Usage

```vim
set laststatus=2
set noshowmode
let g:mutedstl_invert = 1      " optional: swap foreground/background
call mutedstl#Setup()
```

To install automatically when the plugin loads, set `g:mutedstl_auto_setup = 1`
*before* it loads.

`Setup()` applies three highlight groups — `Emphasis` (active, mode),
`Ordinary` (active), `Inactive` (non-current windows, Comment fg on
Normal bg) — and installs
`String()` as the default `'statusline'` **only if** you have not set one.

## Custom statusline

Build your own from the groups.  `Chunk()` wraps any `'statusline'` content
(items like `%t`, `%l:%c`, or `%{...}` expressions) in one of the groups:

```vim
&statusline = mutedstl#Chunk('%{mutedstl#Mode()}%{mutedstl#Paste()} ', 'emphasis')
      \ .. mutedstl#Chunk('%( %<%t %) %m%r', 'ordinary')
      \ .. mutedstl#Chunk('%= %y | Buf:%n | [%l:%c] %P of %LL ', 'ordinary')
call mutedstl#Setup()
```

`kind` is `'emphasis'` | `'ordinary'` (default) | `'inactive'`, **or any
highlight group name** (e.g. `'Error'`), used verbatim:
`mutedstl#Chunk('...', 'Error')`.

To clear a stale window-local `'statusline'` left by another plugin, use
`mutedstl#Reassert()` (installed on buffer/window entry by `Setup()`).

## Options

All under `g:mutedstl_`; see `:help mutedstl-options`.

| Option | Default | Meaning |
|---|---|---|
| `g:mutedstl_theme`    | `''` | Source theme (`''` = current). |
| `g:mutedstl_invert`   | `0`  | Swap fg/bg. |
| `g:mutedstl_fg`       | —    | Foreground override. |
| `g:mutedstl_bg`       | —    | Background override. |
| `g:mutedstl_prefix`   | `'Mutedstl'` | Highlight-group prefix. |
| `g:mutedstl_inactive` | `'comment'` | Chunk for non-current windows (`comment`/`ordinary`/`emphasis`). |
| `g:mutedstl_debug`    | `0`  | Diagnostics via `:echomsg`. |

Override values: `'#RRGGBB'`, a colour name, a 256-colour index, or `'NONE'`.
Out-of-range indices are clamped.

## `<Plug>` mappings

Map these yourself:

```vim
nmap <Leader>mr <Plug>(mutedstl-refresh)   " re-apply groups + redraw
nmap <Leader>md <Plug>(mutedstl-redraw)    " redraw only
nmap <Leader>mL <Plug>(mutedstl-reload)    " drop cache + re-apply + redraw
```

## Documentation

```vim
:help mutedstl
```

## Development

```sh
make test     # headless regression suites (plugin + upstream contracts)
make lint     # shellcheck + doc/tags freshness
make check    # test + lint (what CI runs)
```

`test/term_render.py` additionally renders the statusline in a real PTY and
checks the colours (needs `python3` + `pyte`; skipped otherwise).

CI runs the suites on the minimum supported Vim (9.1) and the latest
release.  `test/upstream.vim` pins the behaviour of the Vim APIs the
plugin relies on, so an upstream change fails CI rather than breaking users —
mutedstl cannot make Vim freeze its APIs, but it can detect when they change.

Contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md) and
[CHANGELOG.md](CHANGELOG.md).  Licensed under [MIT](LICENSE).
