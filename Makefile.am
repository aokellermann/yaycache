SUBDIRS = src lib completions
if WANT_DOC
SUBDIRS += doc
endif
if WANT_TESTS
SUBDIRS += tests
endif

DIST_SUBDIRS = src lib completions doc tests

DISTCHECK_CONFIGURE_FLAGS = --prefix=/usr --enable-doc --disable-git-version

EXTRA_DIST = README.md

# Run the full test suite inside a disposable Arch Linux container (needs
# docker). Exercises the build, `make check`, `make install` and distcheck
# on a clean system independent of the host.
check-docker:
	$(SHELL) $(top_srcdir)/tests/docker/run.sh

.PHONY: check-docker

LOG_DRIVER = env AM_TAP_AWK='$(AWK)' $(SHELL) \
	$(top_srcdir)/build-aux/tap-driver.sh
