pacman-contrib
==============

This repository contains contributed scripts to pacman.

*Note*: This used to be part of pacman.git, but was moved out to make pacman maintenance easier.


How to build:
-------------

    ./autogen.sh
    ./configure --prefix=/usr \
                --sysconfdir=/etc
    make
    make install DESTDIR="$pkgdir"


Scripts available in this repository:
-------------------------------------

* checkupdates - print a list of pending updates without touching the system
                 sync databases (for safety on rolling release distributions).

* pacdiff - a simple pacnew/pacsave updater for /etc/.

* paccache - a flexible package cache cleaning utility that allows greater
             control over which packages are removed.

* paclist - list all packages installed from a given repository. Useful for seeing
            which packages you may have installed from the testing repository,
            for instance.

* updpkgsums - performs an in-place update of the checksums in a PKGBUILD.
