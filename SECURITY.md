# Security Policy

## Supported versions

Only the latest release on the `master` branch is supported.

| Version | Supported |
| ------- | --------- |
| 1.x     | ✅        |

## Reporting a vulnerability

This is a small, dependency-free Vim plugin and does not process untrusted
input over a network.  The realistic risk surface is limited to colour values
and colourscheme names passed into the plugin.

If you believe you have found a security issue (for example, a way to make the
plugin execute an arbitrary command, or read/write files it should not), please
report it **privately** to the maintainer:

- Email: **yueqrgg@gmail.com**

Please include a description, a minimal reproduction, and the affected Vim
version.  We aim to acknowledge reports within a few days and to publish a fix
in a patch release.

## Design notes relevant to security

- Highlight groups are written through `hlset()`, a **structured** API, so
  colour values can never be interpolated into a command line.  Command
  injection via colour strings is therefore not possible.
- The plugin does not shell out, open files, or run user-supplied Ex commands.
