# yaycache

Flexible yay cache cleaning similar to paccache.

## Usage

Usage is essentially the same as with [paccache](https://man.archlinux.org/man/paccache.8).

See `man yaycache` for more information, or view the docs [here](https://yaycache.aokellermann.dev).

### Pacman Hook

You can use `yaycache-hook` package (similar to `paccache-hook`) to automatically run `yaycache` with
configurable arguments after your `pacman` transactions.

```sh
yay -S yaycache-hook
```

The configuration is stored in `/etc/yaycache-hook.conf`.

### Systemd service

An optional systemd service is included that will run weekly:

```sh
systemctl --user enable --now yaycache.timer
```

The service runs `yaycache -r $YAYCACHE_ARGS`. Put extra options in
`/etc/yaycache.conf`, or in `~/.config/yaycache.conf` which takes precedence:

```sh
YAYCACHE_ARGS="-k1 --remove-build-files --min-mtime '30 days ago'"
```

## Installing

An AUR package is available:

```sh
yay -S yaycache
```

## Building

You can build the package yourself:

```sh
git submodule update --init   # test dependencies (bats-core), only needed for make check
./autogen.sh
./configure --prefix=/usr
make
make check
make install DESTDIR="$pkgdir"
```

## Testing

`make check` runs the BATS suite with every test file inside a
[bubblewrap](https://github.com/containers/bubblewrap) sandbox: throwaway
`HOME` and `/tmp`, no network, shim `sudo`/`pacman`, read-only source tree.
The script under test therefore cannot reach your real `~/.cache/yay` or
escalate privileges. `make check-docker` runs the same suite, plus
`make install` and `make distcheck`, in a disposable Arch Linux container.
See [tests/README.md](tests/README.md).
