# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

yaycache is a cache cleaning utility for the `yay` AUR helper on Arch Linux. It removes old cached packages, keeping configurable versions (default: 3). Written in Bash, inspired by `paccache` from pacman-contrib.

## Build Commands

```bash
# First-time setup (generates configure script)
./autogen.sh

# Configure (standard prefix for Arch)
./configure --prefix=/usr

# Build
make

# Run tests (sandboxed with bubblewrap; see tests/README.md)
git submodule update --init   # once: vendored bats-core + helpers in tests/lib/
make check

# Same suite + make install + distcheck in a disposable Arch container
make check-docker

# Install to staging directory
make install DESTDIR=/path/to/staging

# Clean
make clean
make distclean  # Also removes configure
```

For distribution tarballs:
```bash
./configure --prefix=/usr --enable-doc --disable-git-version
make distcheck
```

## Architecture

### Build System

Uses GNU Autotools (Autoconf/Automake). Key files:
- `configure.ac` - Main configuration, checks for Bash ≥4.1.0 and libmakepkg
- `Makefile.am` - Build rules, subdirectory order: src → lib → completions → doc

### Source Structure

- `src/yaycache.sh.in` - Main script template, processed by m4 (for macro includes) and sed (for variable substitution)
- `lib/size_to_human.sh` - AWK function for human-readable sizes, included via m4
- `doc/yaycache.8.adoc` - Manpage source in AsciiDoc format
- `completions/zsh/_yaycache` - Zsh completions

### Template Processing

The `.sh.in` files use:
- m4 macros like `m4_include(../lib/size_to_human.sh)` for library inclusion
- Sed substitution for `@libdir@`, `@bindir@`, `@YAYCACHE_VERSION@`, etc.
- Bash syntax validation (`bash -n`) before installation

### Key Dependencies

- **libmakepkg** - Provides `util/message.sh` and `util/parseopts.sh`
- **pacsort** - For sorting package files by version
- **asciidoc/a2x** - For documentation generation (optional)

### Systemd Integration

- `src/yaycache.service.in` - User-level oneshot service running `yaycache -r`
- `src/yaycache.timer` - Weekly persistent timer triggering the service

## Code Patterns

- Heavy use of embedded AWK for package filename parsing and filtering
- `runcmd()` handles privilege escalation via sudo when needed
- Package regex: `(.+)-[^-]+-[0-9]+-([^.]+)\.pkg.*` extracts name and arch
- AWK associative arrays with SUBSEP for grouping packages by name/arch
- **Important**: AWK associative array keys must be unique full paths, not basenames (see `bffilter()`)

## Testing

BATS suite in `tests/` (bats-core and helpers vendored as submodules in `tests/lib/`). Every `.bats` file runs through `tests/sandbox.sh`, a bubblewrap wrapper giving a tmpfs `HOME`/`/tmp`, no network, a read-only source tree and shim `sudo`/`pacman` binaries (`tests/shims/`). `require_sandbox` in `tests/common.bash` aborts any test not launched through it, so **never run bats directly**; use `tests/sandbox.sh -- tests/lib/bats-core/bin/bats <file>` for a single file. Full details in `tests/README.md`.

Rules for writing tests:
- The `N candidates` / `N files removed` summary counts candidate files (packages and build files, including directory entries expanded by find). `list_candidates` lists them one per line.
- Use `create_realistic_yay_cache` / `create_aur_pkg_dir` + `assert_tree` for end-to-end scenarios; `HOME` is unique per test so running without `-c` is safe.
- Privilege tests use `SUDO_SHIM_MODE=passthrough` to capture the exact command yaycache would hand to sudo; they are skipped for root.
- Known bug (skipped test in `yay_layout.bats`): `--remove-build-files` with a nested git clone passes the directory and its children to `rm -r`, so yaycache exits non-zero after removing everything. Tests assert the resulting tree and tolerate the exit status.

Manual dry run against a mock directory still works without the suite:

```bash
mkdir -p /tmp/test-pkg/src
(cd /tmp/test-pkg && git init && echo "PKGBUILD" > PKGBUILD && git add PKGBUILD && git commit -m "init")
(cd /tmp/test-pkg/src && git init && mkdir -p refs/pull/1 && touch refs/pull/1/head)
./src/yaycache -d -k0 --remove-build-files -vv -c /tmp/test-pkg/
```

### Build File Discovery Pipeline

The `--remove-build-files` pipeline in `src/yaycache.sh.in`:
1. `git ls-files --others` - Lists untracked files in the AUR package directory
2. `xargs printf` - Prepends `$PWD/` to make absolute paths (null-terminated)
3. `find -files0-from -` - Expands directories to list all files within
4. `grep -v .pkg.tar*` - Excludes built packages
5. `bffilter()` - Applies whitelist/blacklist and atime/mtime filters

### Yay Cache Structure

Yay cache directories (`~/.cache/yay/*/`) are git repos containing:
- `PKGBUILD` and other AUR files (tracked by git)
- Source directories with nested git clones (e.g., `src/`, `SourceCode/`)
- Built packages (`*.pkg.tar*`)

The nested git repos mean `git ls-files --others` from the parent only sees the nested repo as a single directory entry, which `find` then expands.

## Performance gotcha: bash `read`/`mapfile` from pipes

Bash reads from a non-seekable fd (pipe, process substitution) one byte per `read(2)` syscall, so
`IFS=$'\n' read -r -d '' -a arr < <(...)` on ~240k lines costs ~10 s of pure syscall overhead (measured
2026-09-27: a `--remove-build-files` dry run spent ~35 of 38 s there). `mapfile` from a pipe is just as
slow; the same `mapfile` from a regular file takes 0.25 s. If a large list must land in a bash array, write
it to a temp file first, or better, keep it as a NUL-delimited stream and pipe it straight to `xargs -0`.
