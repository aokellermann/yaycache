SUBDIRS = src lib
if WANT_DOC
SUBDIRS += doc
endif

DIST_SUBDIRS = $(SUBDIRS)

DISTCHECK_CONFIGURE_FLAGS = --enable-doc --disable-git-version
