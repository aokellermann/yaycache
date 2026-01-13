SUBDIRS = src lib completions
if WANT_DOC
SUBDIRS += doc
endif
if WANT_TESTS
SUBDIRS += tests
endif

DIST_SUBDIRS = $(SUBDIRS) tests

DISTCHECK_CONFIGURE_FLAGS = --prefix=/usr --enable-doc --disable-git-version

EXTRA_DIST = README.md

LOG_DRIVER = env AM_TAP_AWK='$(AWK)' $(SHELL) \
	$(top_srcdir)/build-aux/tap-driver.sh
