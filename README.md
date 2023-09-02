# yaycache

Flexible yay cache cleaning similar to paccache.

## Usage

Usage is essentially the same as with [paccache](https://man.archlinux.org/man/paccache.8).

See `man yaycache` for more information.

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
