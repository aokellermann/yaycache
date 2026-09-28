# yaycache test suite

BATS tests (`bats-core`, vendored under `lib/`) that exercise the built
`src/yaycache` script end to end. Because the script's whole job is running
`rm -r`, `mv` and `sudo`, every test file is executed inside an isolated
environment so a bug in the script or a test can never touch the developer's
real `~/.cache/yay`, `/tmp` or privileges.

## Running

```bash
git submodule update --init      # once: fetches bats-core + helper libraries
./autogen.sh && ./configure --prefix=/usr && make
make check                       # sandboxed with bubblewrap (bwrap)
make check-docker                # same suite in a disposable Arch container
```

Run a single file (or pass `--filter` etc. to bats):

```bash
tests/sandbox.sh -- tests/lib/bats-core/bin/bats tests/integration/privilege.bats
```

Test an installed copy instead of the build tree:

```bash
YAYCACHE=/usr/bin/yaycache make check
```

## Isolation layers

| Layer | Provided by | What it guarantees |
|---|---|---|
| bubblewrap sandbox | `sandbox.sh` | Fresh tmpfs `HOME`, `/tmp`, `/var/tmp`, `/run`; no network; own PID/IPC/UTS/user namespaces; `/usr` and the source/build trees read-only; environment cleared |
| Shim binaries | `shims/sudo`, `shims/pacman` | First on `PATH`. `sudo` records every call and refuses (or, with `SUDO_SHIM_MODE=passthrough`, runs the command unprivileged so its arguments can be asserted). `pacman -Qq` answers from `PACMAN_SHIM_INSTALLED` |
| Per-test HOME | `require_sandbox` in `common.bash` | `HOME` (and an unset `XDG_CACHE_HOME`) point at a directory unique to the test, so tests that rely on default cachedir resolution cannot bleed into each other |
| Guard | `require_sandbox` | Every test aborts unless `YAYCACHE_SANDBOX=1`, i.e. it was launched via `sandbox.sh` |
| Container | `docker/` | `make check`, `make install DESTDIR=…` + the suite against the installed copy, and `make distcheck` on a clean `archlinux:base-devel` image, as an unprivileged user, with `--network none --cap-drop ALL` |

`sandbox.sh --no-bwrap` (or `YAYCACHE_NO_SANDBOX=1`) skips only the mount
and namespace layer; the shims, environment scrubbing and throwaway HOME are
kept. This is what the container uses, since docker's default seccomp
profile does not allow the user namespaces bubblewrap needs. Tests marked
`bwrap_only` are skipped in that mode.

`integration/sandbox.bats` self-checks all of the above and should be the
first thing to look at if the suite ever behaves surprisingly.

## Layout

- `common.bash` – shared helpers: mock package/cache builders, the realistic
  `create_realistic_yay_cache` fixture (AUR clones with tracked
  PKGBUILD/.SRCINFO, built packages, nested upstream git clone, `src/`,
  `pkg/`, tarball), `snapshot_tree`/`assert_tree`, `list_candidates`.
- `unit/` – filter functions (`pkgfilter`, `bffilter`, `size_to_human`).
- `integration/` – one file per feature or mode. The ones that only make
  sense inside the sandbox: `default_cachedir` (no `-c`), `privilege`
  (unwritable dirs, sudo command line), `uninstalled` (`-u` via the pacman
  shim), `yay_layout` (realistic tree, symlink escapes, large caches).

## Gotchas

- The `N candidates` / `N files removed` summary counts candidate files,
  packages and build files alike (a nested clone directory expanded by
  `find` contributes every entry). `list_candidates` prints them one per line.
- `--remove-build-files` currently exits non-zero when a nested git clone is
  among the build files (`rm -r` gets the directory and its children; see the
  skipped test in `yay_layout.bats`). Tests assert the resulting tree and
  tolerate the exit status until that is fixed.
- Writability tests are skipped for root (`skip_if_root`); the docker image
  runs as user `tester` for this reason.
