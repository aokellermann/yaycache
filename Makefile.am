SUBDIRS = src lib
if WANT_DOC
SUBDIRS += doc
endif

DIST_SUBDIRS = $(SUBDIRS)

DISTCHECK_CONFIGURE_FLAGS = --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-doc --disable-git-version
