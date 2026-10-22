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
- `configure.ac` - Main configuration, checks for Bash ≥4.4.0 (`mapfile -d`) and libmakepkg
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

- `src/yaycache.service.in` - User-level oneshot service running `yaycache -r $YAYCACHE_ARGS`; the variable comes from `EnvironmentFile=` `/etc/yaycache.conf` (installed from `src/yaycache.conf`, sysconfdir defaults to `/etc` when prefix is `/usr`) or `~/.config/yaycache.conf`
- `src/yaycache.timer` - Weekly persistent timer triggering the service

## Code Patterns

- `--remove-uninstalled-dirs` (requires `-u`): `dir_is_uninstalled()` reads the `pkgname = ` lines of the clone's `.SRCINFO` (falling back to the directory name) and makes the whole cache directory a candidate when none of them is on the blacklist; such directories skip the per-file scan and their size is summed with `du -sb`, not `stat`.

- Heavy use of embedded AWK for package filename parsing and filtering
- `runcmd()` handles privilege escalation via sudo when needed
- Package regex: `(.+)-[^-]+-[0-9]+-([^.]+)\.pkg.*` extracts name and arch
- AWK associative arrays with SUBSEP for grouping packages by name/arch
- **Important**: AWK associative array keys must be unique full paths, not basenames (see `bffilter()`)
- **Every filename inside a cache directory is attacker-controlled**: the AUR maintainer picks the tracked names and `yay -S` clones the repo before anything is built, so names may contain newlines or anything else. Both candidate pipelines are therefore NUL-delimited end to end (`printf '%s\0'` / `find -print0` / `-printf '...\0'`, `pacsort -z`, `git ls-files -z`, `grep -z`, `RS = "\0"; ORS = "\0"` in the AWK filters, `mapfile -d ''`), `check_candidates` aborts the run on any candidate not under `$PWD`, and `rm`/`mv` get `--` before the path list. A newline-delimited stage would reintroduce the 2026-10-21 finding (a bare relative name reaching `rm -r` in the invocation cwd); `tests/integration/hostile_names.bats` is the regression test. `RS = "\0"` is a gawk feature, which is what `awk` is on Arch. The same review drove these rules, all pinned by `tests/integration/containment.bats` / `scan_failures.bats`:
  - Only the whole directories of `--remove-uninstalled-dirs` go through `rm -r`; file candidates go through plain `rm`, so a candidate that turns out to be a directory fails loudly ("Is a directory") instead of taking a tree with it.
  - Build files are scanned only when `$PWD` is the top of a git work tree (`[[ $(git rev-parse --show-toplevel) -ef . ]]`, `-ef` because `$PWD` may go through a symlink); elsewhere `git ls-files --others` walks up to an enclosing repository (a `$HOME` that is a git repo) and reports PKGBUILD and sources as leftovers. Such directories are skipped with a warning.
  - Each candidate pipeline runs under `set -o pipefail` inside its process substitution and is checked with `wait "$!"` (bash ≥ 4.4): a failure (pacsort crashing on a malformed name, git refusing a clone) is reported with `error`, the directory's results are discarded, the other directories are still processed, and the run exits 1 via `scanfailed`. `grep -v` exiting 1 on an empty result is explicitly not a failure.
  - The cache path is never used as a format string (`printf "$PWD/%s\0"` broke on `%` and `\`); paths are prefixed in AWK via `ENVIRON["PWD"]`, which bash exports.
  - `.SRCINFO` package names are validated against makepkg's rules (non-empty, `[[:alnum:]+_.@-]`, no leading `-`/`.`) before being used as array subscripts; invalid ones are ignored with a warning, and with none left the directory name is used.

## Testing

BATS suite in `tests/` (bats-core and helpers vendored as submodules in `tests/lib/`). Every `.bats` file runs through `tests/sandbox.sh`, a bubblewrap wrapper giving a tmpfs `HOME`/`/tmp`, no network, a read-only source tree and shim `sudo`/`pacman` binaries (`tests/shims/`). `require_sandbox` in `tests/common.bash` aborts any test not launched through it, so **never run bats directly**; use `tests/sandbox.sh -- tests/lib/bats-core/bin/bats <file>` for a single file. Full details in `tests/README.md`.

Rules for writing tests:
- Assert on `list_candidates` output or on-disk file counts, not on the `N candidates` / `N files removed` summary: that number is the count of cache *directories* with candidates (`pkgcount`), not files.
- Use `create_realistic_yay_cache` / `create_aur_pkg_dir` + `assert_tree` for end-to-end scenarios; `HOME` is unique per test so running without `-c` is safe.
- Privilege tests use `SUDO_SHIM_MODE=passthrough` to capture the exact command yaycache would hand to sudo; they are skipped for root.
- `--remove-build-files` candidates are files only (`find ! -type d`); the directories left empty are pruned after the `rm` (all of them except the AUR clone's own `.git`). `yay_layout.bats` covers both.
- Fixtures with newlines in filenames (`hostile_names.bats`): count files with `count_packages_nul`, not `count_packages` (`wc -l`), and do not use `snapshot_tree`/`assert_tree`, which are line-based.
- `privilege.bats` asserts the exact argv handed to `sudo` (`xargs -0 rm <opts> --` for files, `xargs -0 rm -r --` for whole cache directories, `xargs -0 mv -t <dir> --`); any change to those command lines must update it.
- To make a tool inside a pipeline fail, drop a shim into a per-test directory and prepend it for one run: `PATH="$SHIMS:$PATH" run run_yaycache ...` (`scan_failures.bats`). The shim must `exec /usr/bin/<tool>` for the cases it does not simulate.

Manual dry run against a mock directory still works without the suite:

```bash
mkdir -p /tmp/test-pkg/src
(cd /tmp/test-pkg && git init && echo "PKGBUILD" > PKGBUILD && git add PKGBUILD && git commit -m "init")
(cd /tmp/test-pkg/src && git init && mkdir -p refs/pull/1 && touch refs/pull/1/head)
./src/yaycache -d -k0 --remove-build-files -vv -c /tmp/test-pkg/
```

### Build File Discovery Pipeline

The `--remove-build-files` pipeline in `src/yaycache.sh.in`, run only when the directory is the top of a git work tree (see Code Patterns):
1. `git ls-files -z --others` - Lists untracked files in the AUR package directory
2. `awk` - Prepends `$PWD/` (from `ENVIRON`) to make absolute paths (null-terminated)
3. `find -files0-from - ! -type d` - Expands directories to list all files within (directories themselves are not candidates; they are pruned after removal if empty)
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
`mapfile -d '' -t arr < <(...)` (or `IFS=$'\n' read -r -d '' -a arr`) on ~240k entries costs ~10 s of pure syscall overhead (measured
2026-09-27: a `--remove-build-files` dry run spent ~35 of 38 s there). `mapfile` from a pipe is just as
slow; the same `mapfile` from a regular file takes 0.25 s. If a large list must land in a bash array, write
it to a temp file first, or better, keep it as a NUL-delimited stream and pipe it straight to `xargs -0`.

## Releasing

1. Bump `AC_INIT` in `configure.ac`, commit (`bump to X.Y.Z`), then `git tag -s vX.Y.Z -m vX.Y.Z` (tags are SSH-signed with the YubiKey, so tagging needs the user present) and push master + tag. **No GitHub Releases are created**, tags only; the AUR package downloads `archive/vX.Y.Z.tar.gz`.
2. AUR `yaycache` lives in `~/repos/aur/yaycache`: bump `pkgver`, `updpkgsums`, `makepkg --printsrcinfo > .SRCINFO`, commit, push. The b2sum cannot be computed before the tag exists on GitHub (its gzip output differs from a local `git archive`).
3. The GitHub tarball has **no submodules**, so `configure` disables the test suite unless a system `bats` is present. The AUR PKGBUILD deliberately has no `check()` and no `checkdepends` (decided 2026-09-27: not worth making every AUR builder install bats + helpers); the suite runs only in the repo and `make check-docker`. If that ever changes, note that bwrap cannot create namespaces in chroot/container builds and every test ERRORs there, so a `check()` would need to fall back to `YAYCACHE_NO_SANDBOX=1 make check`.
4. To rehearse the AUR build before tagging: `git archive --format=tar.gz --prefix=yaycache-X.Y.Z/ HEAD`, point a copy of the PKGBUILD's `source=` at that file, and run `makepkg -f` as an unprivileged user in `docker run --rm --tmpfs /tmp:exec archlinux:base-devel` (the host has no `bats` packages installed).
5. Website (https://yaycache.aok.site, GitHub Pages from `gh-pages:/docs`) is the rendered man page. Refresh it in a worktree: `git worktree add ../yaycache-gh-pages gh-pages`, merge master, `./autogen.sh && ./configure --enable-doc --disable-git-version && make -C doc html`, copy `doc/yaycache.8.html` to `docs/index.html`, commit, push. `docs.sh` (the `website` target) expects asciidoc's css/js under `/etc/asciidoc`, which on this machine live in `/usr/lib/python3.*/site-packages/asciidoc/resources/`; the committed `docs/asciidoc.{css,js}` are identical to those, so only `index.html` needs regenerating.
