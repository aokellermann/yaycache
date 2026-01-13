# Test suite Makefile

# BATS test files
BATS_TESTS = \
	unit/size_to_human.bats \
	unit/pkgfilter.bats \
	unit/bffilter.bats \
	integration/cli_args.bats \
	integration/dryrun.bats \
	integration/remove.bats \
	integration/move.bats \
	integration/keep_count.bats \
	integration/whitelist_blacklist.bats \
	integration/remove_build_files.bats \
	integration/min_atime_mtime.bats

# TAP test runner
TESTS = $(BATS_TESTS)

# Test extensions
TEST_EXTENSIONS = .bats
BATS_LOG_DRIVER = env AM_TAP_AWK='$(AWK)' $(SHELL) \
	$(top_srcdir)/build-aux/tap-driver.sh
BATS_LOG_COMPILER = $(BATS)
AM_BATS_FLAGS = --tap

# Make yaycache available to tests
AM_TESTS_ENVIRONMENT = \
	export PATH="$(top_builddir)/src:$$PATH"; \
	export YAYCACHE="$(top_builddir)/src/yaycache"; \
	export SRCDIR="$(top_srcdir)"; \
	export BUILDDIR="$(top_builddir)"; \
	export TEST_COMMON="$(srcdir)/common.bash";

EXTRA_DIST = \
	common.bash \
	$(BATS_TESTS)

# Clean up test artifacts
clean-local:
	-rm -rf $(builddir)/.bats-*
