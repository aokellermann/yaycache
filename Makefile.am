SUBDIRS = src lib completions
if WANT_DOC
SUBDIRS += doc
endif

DIST_SUBDIRS = $(SUBDIRS)

DISTCHECK_CONFIGURE_FLAGS = --prefix=/usr --enable-doc --disable-git-version

EXTRA_DIST = README.md AUTHORS.md

LOG_DRIVER = env AM_TAP_AWK='$(AWK)' $(SHELL) \
	$(top_srcdir)/build-aux/tap-driver.sh
