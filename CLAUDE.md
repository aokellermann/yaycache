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

# Run tests
make check

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

## Testing --remove-build-files

The `--remove-build-files` feature can be tested without touching real yay cache:

```bash
# Create a mock cache directory structure
mkdir -p /tmp/test-pkg/src
(cd /tmp/test-pkg && git init && echo "PKGBUILD" > PKGBUILD && git add PKGBUILD && git commit -m "init")
(cd /tmp/test-pkg/src && git init && mkdir -p refs/pull/1 && touch refs/pull/1/head)

# Dry run against mock directory
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
