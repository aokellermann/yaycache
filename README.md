# yaycache

Flexible yay cache cleaning similar to paccache.

## Usage

Usage is essentially the same as with [paccache](https://man.archlinux.org/man/paccache.8).

See `man yaycache` for more information, or view the docs [here](https://yaycache.aokellermann.dev).

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
