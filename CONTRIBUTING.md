# Contributing to mutedstl

Thanks for your interest.  This project is deliberately kept minimal, so the
bar for new features is high: a feature is most likely to be accepted if it
has a chance of being merged into Vim itself as a built-in plugin.

## Getting started

1. Fork the repository and clone your fork.
2. Make sure you have **Vim 9+** (needs `+vim9script`, `hlget()`, `hlset()`).
3. Run the test suite before and after your change:

   ```sh
   make test          # or: test/run.sh
   ```

## Coding style

- **Vim9 script only.**  The plugin targets Vim 9; do not add legacy `:function`
  code.
- **2-space indentation, spaces only, no tabs** (`.editorconfig` and the file
  modelines enforce this).
- Keep lines within **78 columns**.
- Prefer standard functions over ad-hoc logic: `hlget()`/`hlset()`,
  `v:colornames`, `win_getid()`, `get(g:, ...)`.
- Every exported (`export def`) function needs a matching help tag in
  `doc/mutedstl.txt`.
- Document the **why**, not just the what.  Comments are bilingual
  (English + 中文) on purpose.
- Add a regression test for any behavioural change; see `test/mutedstl.vim`.

## Commit messages

- Use a short imperative subject line (<= 72 chars).
- Explain the **reason** for the change in the body, and note the problem it
  fixes.
- Keep one logical change per commit where practical.

## Compatibility

The public API and options are a **contract** (see `:help mutedstl-compat`).
Breaking one of them requires:

1. Bumping the **major** version.
2. Following the **deprecation policy** (`:help mutedstl-deprecation`): mark
   the item deprecated in the docs and source, keep the old behaviour, and
   call `Deprecated(what, replacement)` on the old path so it warns under
   `g:mutedstl_debug`.
3. Removing it only in a later major version.

CI freezes the contract: `test/mutedstl.vim` section 16 asserts the public
return types and the `Colors()` structure, so an accidental break fails the
build.

## Documentation

- Update `doc/mutedstl.txt` for user-visible changes and regenerate tags:

  ```sh
  vim -es -c 'helptags doc' -c 'qall!'
  ```

  Do not hand-edit `doc/tags`.
- Add an entry under `## [Unreleased]` in `CHANGELOG.md`.

## Reporting bugs

Please include:

- `vim --version` output (at least the first line),
- the output of `:echo g:mutedstl#*` for the options in use,
- a minimal reproduction (ideally a tiny vimrc + steps).

## License

By contributing you agree that your contributions are licensed under the MIT
License (see `LICENSE`).
