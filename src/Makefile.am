# enforce that all scripts have a --help and --version option
AUTOMAKE_OPTIONS = std-options
SUBDIRS=

DIST_SUBDIRS = $(SUBDIRS)

bin_SCRIPTS = \
	$(OURSCRIPTS)

systemd_dir = ${libdir}/systemd/user

systemd__DATA = \
	yaycache.service yaycache.timer

BASHSCRIPTS = \
	yaycache

OURSCRIPTS = \
	$(BASHSCRIPTS)

OURFILES = \
	yaycache.service

EXTRA_DIST = \
	yaycache.service.in \
	yaycache.sh.in \
	yaycache.timer

# Files that should be removed, but which Automake does not know.
MOSTLYCLEANFILES = $(OURSCRIPTS) $(OURFILES) *.tmp

if USE_GIT_VERSION
GIT_VERSION := $(shell sh -c 'git describe --long --abbrev=4 --dirty | sed s/^v//')
REAL_PACKAGE_VERSION = $(GIT_VERSION)
else
REAL_PACKAGE_VERSION = $(PACKAGE_VERSION)
endif

edit = sed \
	-e 's|@bindir[@]|$(bindir)|g' \
	-e 's|@PACKAGE_VERSION[@]|$(REAL_PACKAGE_VERSION)|g' \
	-e 's|@libmakepkgdir[@]|$(LIBMAKEPKGDIR)|g' \
	-e 's|@SIZECMD[@]|$(SIZECMD)|g' \
	-e 's|@SCRIPTNAME[@]|$@|g' \
	-e '1s|!/bin/bash|!$(BASH_SHELL)|g' \
	-e 's|@configure_input[@]|Generated from $@.sh.in; do not edit by hand.|g'

$(BASHSCRIPTS): Makefile
	$(AM_V_at)$(RM) $@
	$(AM_V_GEN)test -f $(srcdir)/$@.sh.in && m4 -P -I $(srcdir) $(srcdir)/$@.sh.in | $(edit) >$@
	$(AM_V_at)chmod +x,a-w $@
	@$(BASH_SHELL) -O extglob -n $@

$(OURFILES): Makefile
	$(AM_V_at)$(RM) $@ $@.tmp
	$(AM_V_GEN)$(edit) $(srcdir)/$@.in >$@.tmp
	$(AM_V_at)chmod a-w $@.tmp
	$(AM_V_at)mv $@.tmp $@

all-am: $(OURSCRIPTS) $(OURFILES)

$(BASHSCRIPTS): %: $(srcdir)/%.sh.in

# dependency links
yaycache: $(top_srcdir)/lib/size_to_human.sh
