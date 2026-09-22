# Contributing to mutedstl

Thanks for your interest.  The project is deliberately kept minimal, so the
bar for new features is high: a feature is most likely to be accepted if it
has a chance of being merged into Vim itself as a built-in plugin.

## Getting started

1. Fork and clone the repository.
2. Have **Vim 9.1+** with `+vim9script`.
3. Run `make test` before and after your change.

## Style

- **Vim9 script only** (no legacy `:function`).
- **2-space indent, spaces only, <= 78 columns** — enforced by
  `.editorconfig` and the file modelines.
- Prefer standard functions: `hlget()`/`hlset()`, `v:colornames`,
  `win_getid()`, `get(g:, ...)`.
- Every `export def` needs a matching help tag in `doc/mutedstl.txt`.
- Comment the **why**, not just the what.
- Add a regression test for any behavioural change (`test/mutedstl.vim`).  If
  you rely on a new Vim API, pin its behaviour in `test/upstream.vim`.

## Commits

- Short imperative subject (<= 72 chars); explain the reason in the body.
- One logical change per commit where practical.

## Compatibility

The public API and options are a **contract** (`:help mutedstl-compat`).
Breaking one requires a **major** version bump and the deprecation policy
(`:help mutedstl-deprecation`): mark the item deprecated, keep the old
behaviour, call `Deprecated(what, replacement)` on the old path, and remove it
only in a later major version.  CI freezes the contract
(`test/mutedstl.vim` section 16).

## Docs

Update `doc/mutedstl.txt`, run `make docs` (never hand-edit `doc/tags`), and
add an entry under `## [Unreleased]` in `CHANGELOG.md`.

## Bugs and security

For bugs, include your `vim --version` line, the relevant `g:mutedstl_*`
values, and a minimal reproduction.

For a security issue (e.g. a way to make the plugin execute a command — it
should not be possible, since highlights are set via `hlset()`), email
**yueqrgg@gmail.com** privately.  Only the latest release is supported.

## Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
Be kind and constructive.

## License

Contributions are licensed under the MIT License (see `LICENSE`).
