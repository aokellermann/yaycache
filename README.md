# yaycache

This repository contains contributed scripts to pacman.

*Note*: These existed in pacman.git, but were moved out to ease maintenance.

## Usage



## Building

```sh
./autogen.sh
./configure --prefix=/usr
make
make check
make install DESTDIR="$pkgdir"
```
