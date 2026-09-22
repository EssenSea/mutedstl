# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The inactive-window chunk now defaults to `'comment'`:
  `g:mutedstl_inactive` is `'comment'` by default, using the colourscheme's
  Comment foreground on the Normal background so non-current windows read
  like dimmed comments.  `'ordinary'` and `'emphasis'` remain selectable, and
  a theme without a Comment foreground falls back to the ordinary chunk.
  This changes the default appearance of `MutedstlInactive` and the value of
  `Colors().inactive`.

### Added

- test/term_render.py: render the statusline in a real PTY (python3 + pyte)
  and assert the visible text and that the emphasis/ordinary segments use
  distinct colours.  Wired into test/run.sh and CI (skipped when pyte is
  absent).  This closes the biggest verification gap: until now the plugin
  was only exercised headless, never through a terminal.

### Fixed

- Mode(): map the Virtual-Replace completion modes (Rvc/Rvx) to V-REPLACE and
  the Ex overstrike mode (cvr) to EX, which the leading-character fallback
  mislabelled.

### Changed

- Reshaped the public options to upstream convention: `g:mutedstl#*` became
  `g:mutedstl_*` (e.g. `g:mutedstl_theme`, `g:mutedstl_invert`).  This is a
  breaking rename of the option names; it is done before the plugin is
  proposed upstream.  The help file is now English-only.
- Declared the minimum supported version as **Vim 9.1** (not 9.0): 9.1 is the
  stable line in major distributions (e.g. Gentoo 9.1.1652).  The CI matrix
  now tests the minimum line (9.1) and the latest release instead of an
  Ubuntu 22.04 / Vim 8.2 point, which was never actually supported.
- Corrected the dependency notes: hlget()/hlset() were added in Vim 8.2.3578
  (not 9.0); the plugin's 9.1 floor comes from the vim9script syntax it uses.

- Slimmed the documentation: shorter README focused on usage, a more compact
  `:help` (Requirements/Compatibility chapters condensed), and a single
  CONTRIBUTING.md that also covers security reporting and conduct (the
  separate CODE_OF_CONDUCT.md and SECURITY.md were removed as out of
  proportion for a plugin of this size).

### Added

- Upstream-API contract tests (`test/upstream.vim`) that pin the behaviour of
  the Vim APIs mutedstl relies on (hlget()/hlset() structure, v:colornames
  shape, win_getid()/v:dying types, the OptionSet event); a change upstream
  fails the build instead of breaking users silently.
- Capability probe `mutedstl#HasCapabilities()` and guards so the plugin stays
  dormant (never errors) on a Vim without hlget()/hlset().
- CI matrix over three Vim versions: oldest supported (ubuntu-22.04), the
  distribution Vim (ubuntu-24.04), and the newest official release.
- `:help mutedstl-requirements` and `:help mutedstl-support` now list each
  Vim API dependency with its version and the fallback when it is absent.
- Backward-compatibility policy and enforcement (`:help mutedstl-compat`):
  explicit STABLE API and option sets, a documented deprecation process, and
  a support matrix.
- `Deprecated()` helper for warning about deprecated items under
  `g:mutedstl_debug`.
- Contract tests (section 16 of `test/mutedstl.vim`) that freeze the public
  return types and the `Colors()` structure, so any breaking change fails CI.

## [1.0.0] - 2026-09-23

First stable release.  A muted, self-contained statusline for Vim 9 that
derives a two-colour pair from any colourscheme without per-theme colourfiles.

### Added

- Colour API: `Colors()`, `Hi()`, `Apply()`, `ApplyDefault()`.
- Statusline front end: `String()`, `Chunk()`, `GroupMark()`, `GroupName()`,
  `Mode()`, `Paste()`, `IsActive()`.
- Lifecycle: `Setup()`, `Refresh()`, `Redraw()`, `Reassert()`, `ReloadCache()`.
- Colour utilities: `NrToHex()`, `HexToCterm()`, `NameToHex()`, `FromTheme()`.
- `<Plug>(mutedstl-refresh|redraw|reload)` entry points.
- Options (all under `g:mutedstl_`): `theme`, `invert`, `fg`, `bg`, `prefix`,
  `inactive`.
- Named-theme colour cache and a headless regression test suite.

### Notes

- Requires Vim 9 (`hlget()`, `hlset()`); uses `v:colornames` (8.2.4774+).
- Designed and written with the help of a large language model (LLM POWERED).

[Unreleased]: https://github.com/EssenSea/mutedstl/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/EssenSea/mutedstl/releases/tag/v1.0.0
