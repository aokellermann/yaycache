# yaycache

Flexible yay cache cleaning similar to paccache.

*Note: this is a work in progress, and not all documented features may work!*

## Usage

Usage is essentially the same as with [paccache](https://man.archlinux.org/man/paccache.8).

See `man yaycache` for more information, or view the docs online at
[yaycache.aokellermann.dev](https://yaycache.aokellermann.dev).

## Installing

A `PKGBUILD` is provided:

```console
mkdir build && cd build
curl -o PKGBUILD https://raw.githubusercontent.com/aokellermann/yaycache/master/PKGBUILD
yay -Bi .
```

## Building

```console
./autogen.sh
./configure --prefix=/usr
make
make check
make install DESTDIR="$pkgdir"
```
