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
systemctl enable --now yaycache.timer
```

## Installing

An AUR package is available:

```sh
yay -S yaycache
```

## Building

You can build the package yourself:

```sh
./autogen.sh
./configure --prefix=/usr
make
make check
make install DESTDIR="$pkgdir"
```
