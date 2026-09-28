# Test suite Makefile
#
# Every .bats file is executed through tests/sandbox.sh, which runs it inside
# a bubblewrap sandbox (throwaway HOME and /tmp, no network, shim sudo and
# pacman, read-only source tree). See tests/README.md.

BATS_TESTS = \
	unit/size_to_human.bats \
	unit/pkgfilter.bats \
	unit/bffilter.bats \
	integration/sandbox.bats \
	integration/cli_args.bats \
	integration/dryrun.bats \
	integration/remove.bats \
	integration/move.bats \
	integration/keep_count.bats \
	integration/whitelist_blacklist.bats \
	integration/remove_build_files.bats \
	integration/min_atime_mtime.bats \
	integration/default_cachedir.bats \
	integration/privilege.bats \
	integration/uninstalled.bats \
	integration/yay_layout.bats

TESTS = $(BATS_TESTS)

TEST_EXTENSIONS = .bats
BATS_LOG_DRIVER = env AM_TAP_AWK='$(AWK)' $(SHELL) \
	$(top_srcdir)/build-aux/tap-driver.sh
# The sandbox wrapper execs bats inside the isolated environment; TAP output
# flows back to automake's driver on stdout.
BATS_LOG_COMPILER = $(SHELL) $(top_srcdir)/tests/sandbox.sh -- $(BATS)
AM_BATS_LOG_FLAGS = --tap

# Everything the sandbox needs to locate the source/build trees and the
# script under test. YAYCACHE may be overridden to test an installed copy.
AM_TESTS_ENVIRONMENT = \
	export SRCDIR="$(abs_top_srcdir)"; \
	export BUILDDIR="$(abs_top_builddir)"; \
	export YAYCACHE="$${YAYCACHE:-$(abs_top_builddir)/src/yaycache}";

EXTRA_DIST = \
	README.md \
	common.bash \
	sandbox.sh \
	shims \
	lib \
	docker \
	$(BATS_TESTS)

# Ship only the runtime parts of the vendored bats libraries: their own test
# fixtures contain symlinks too long for ustar, and gitlink files are useless
# outside the repository.
dist-hook:
	rm -rf $(distdir)/lib/*/.git $(distdir)/lib/*/.git* $(distdir)/lib/*/test \
		$(distdir)/lib/*/docs $(distdir)/lib/*/contrib $(distdir)/lib/*/man

clean-local:
	-rm -rf $(builddir)/.bats-*
