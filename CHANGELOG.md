# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Options (all under `g:mutedstl#`): `theme`, `invert`, `fg`, `bg`, `prefix`,
  `inactive`.
- Named-theme colour cache and a headless regression test suite.

### Notes

- Requires Vim 9 (`hlget()`, `hlset()`); uses `v:colornames` (8.2.4774+).
- Designed and written with the help of a large language model (LLM POWERED).

[Unreleased]: https://github.com/EssenSea/mutedstl/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/EssenSea/mutedstl/releases/tag/v1.0.0
