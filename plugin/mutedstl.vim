vim9script
# =============================================================================
# plugin/mutedstl.vim  — the only auto-sourced file of this plugin
# plugin/mutedstl.vim  — 本插件唯一自动加载的文件
#
# Maintainer:  <your name> <you@example.com>
# Last Change: 2026-09-23
#
#   LLM POWERED!  This plugin was designed and written with the help of a
#   large language model.  LLM POWERED!
#   LLM POWERED！本插件由大语言模型协助设计与编写。
#
# This file does NOT enable the statusline by default: the statusline is an
# opinionated choice and the user must opt in.  To have it installed
# automatically, set this BEFORE the plugin loads (e.g. in vimrc):
#
#   本文件默认不启用状态栏：状态栏是一种偏好选择，须由用户显式启用。若想自动
#   安装，请在插件加载前（如 vimrc 中）设置：
#
#     g:mutedstl_auto_setup = 1
#
# Otherwise enable it manually whenever you like / 否则可随时手动启用:
#
#     import autoload 'mutedstl.vim'
#     mutedstl.Setup()
#
# (The legacy `mutedstl#Setup()` name still works too.)
# （旧的 `mutedstl#Setup()` 写法也仍然可用。）
#
# Only runs on Vim 9+ with +vim9script; on anything else it is not sourced,
# because this file starts with :vim9script.
# 仅在 Vim 9+ 且含 +vim9script 时运行；否则本文件（以 :vim9script 开头）不会被加载。
# =============================================================================

import autoload '../autoload/mutedstl.vim'

if get(g:, 'mutedstl_auto_setup', 0)
  # Install right away.  Setup() also registers a ColorScheme autocommand, so
  # the colours are refreshed correctly even if the colourscheme is loaded
  # after this plugin.
  # 立即安装。Setup() 同时注册 ColorScheme 自动命令，因此即便配色在本插件之后
  # 才加载，颜色也会被正确刷新。
  mutedstl.Setup()
endif

# --- <Plug> entry points / <Plug> 入口 --------------------------------------
# Map these yourself, e.g.:
#   nmap <Leader>mr <Plug>(mutedstl-refresh)
# 自行映射，例如：nmap <Leader>mr <Plug>(mutedstl-refresh)
#
# <ScriptCmd> is required so the command runs in this script's context, where
# the import alias (mutedstl) is visible.
# 必须用 <ScriptCmd>，命令才会在本脚本上下文运行，从而能看到 import 别名。
nnoremap <silent> <Plug>(mutedstl-refresh) <ScriptCmd>mutedstl.Refresh()<CR>
nnoremap <silent> <Plug>(mutedstl-redraw)  <ScriptCmd>mutedstl.Redraw()<CR>
# Drop the theme cache, then re-apply and redraw (after changing colourschemes).
# 清空主题缓存后重算并重绘（更改配色方案后使用）。
nnoremap <silent> <Plug>(mutedstl-reload)  <ScriptCmd>mutedstl.ReloadCache()<Bar>mutedstl.Refresh()<Bar>mutedstl.Redraw()<CR>
# vim:tw=78:ts=8:sts=2:sw=2:et:norl:
