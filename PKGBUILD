# Maintainer: Antony Kellermann <antony@aokellermann.dev>

pkgname=yaycache-git
pkgver=0.1.0
pkgrel=1
pkgdesc='Flexible yay cache cleaning'
arch=('any')
url=https://github.com/aokellermann/yaycache
license=('GPL')
depends=('pacman-contrib')
makedepends=('asciidoc' 'git')
optdepends=('sudo: privilege elevation')
source=("git+$url.git")
b2sums=('SKIP')

prepare() {
  cd yaycache
  ./autogen.sh
}

build() {
  cd yaycache
  ./configure \
    --prefix=/usr
  make
}

check() {
  cd yaycache
  make check
}

package() {
  cd yaycache
  make DESTDIR="$pkgdir" install
}

# vim:set ts=2 sw=2 et:
