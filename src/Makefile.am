# enforce that all scripts have a --help and --version option
AUTOMAKE_OPTIONS = std-options
SUBDIRS=

DIST_SUBDIRS = $(SUBDIRS)

# paths set at make time
conffile  = ${sysconfdir}/pacman.conf
dbpath    = ${localstatedir}/lib/pacman/

bin_SCRIPTS = \
  $(OURSCRIPTS)

bin_PROGRAMS = pacsort pactree

vim_ftdetect_dir = $(vim_dir)/ftdetect
vim_syntax_dir = $(vim_dir)/syntax

vim_ftdetect__DATA = \
	vim/ftdetect/PKGBUILD.vim

vim_syntax__DATA = \
	vim/syntax/PKGBUILD.vim

systemd_dir = ${libdir}/systemd/system

systemd__DATA = \
	paccache.service paccache.timer

BASHSCRIPTS = \
	checkupdates \
	paccache \
	pacdiff \
	paclist \
	paclog-pkglist \
	pacscripts \
	rankmirrors \
	updpkgsums

PERLSCRIPTS = \
	pacsearch

OURSCRIPTS = \
	$(BASHSCRIPTS) \
	$(PERLSCRIPTS)

OURFILES = \
	paccache.service

EXTRA_DIST = \
	checkupdates.sh.in \
	paccache.service.in \
	paccache.sh.in \
	paccache.timer \
	pacdiff.sh.in \
	paclist.sh.in \
	paclog-pkglist.sh.in \
	pacscripts.sh.in \
	pacsearch.pl.in \
	pacsort.c \
	pactree.c \
	rankmirrors.sh.in \
	updpkgsums.sh.in \
	vim/syntax/PKGBUILD.vim \
	vim/ftdetect/PKGBUILD.vim

# Files that should be removed, but which Automake does not know.
MOSTLYCLEANFILES = $(OURSCRIPTS) $(OURFILES) *.tmp

if USE_GIT_VERSION
GIT_VERSION := $(shell sh -c 'git describe --long --abbrev=4 --dirty | sed s/^v//')
REAL_PACKAGE_VERSION = $(GIT_VERSION)
else
REAL_PACKAGE_VERSION = $(PACKAGE_VERSION)
endif

AM_CPPFLAGS = \
	-DLOCALEDIR=\"@localedir@\" \
	-DCONFFILE=\"$(conffile)\" \
	-DDBPATH=\"$(dbpath)\"

AM_CFLAGS = \
	-pedantic \
	-D_GNU_SOURCE \
	$(WARNING_CFLAGS) \
	$(LIBARCHIVE_CFLAGS) \
	$(LIBALPM_CFLAGS)

edit = sed \
	-e 's|@bindir[@]|${bindir}|g' \
	-e 's|@sysconfdir[@]|$(sysconfdir)|g' \
	-e 's|@localstatedir[@]|$(localstatedir)|g' \
	-e 's|@PACKAGE_VERSION[@]|$(REAL_PACKAGE_VERSION)|g' \
	-e 's|@SIZECMD[@]|$(SIZECMD)|g' \
	-e 's|@SCRIPTNAME[@]|$@|g' \
	-e '1s|!/bin/bash|!$(BASH_SHELL)|g' \
	-e 's|@configure_input[@]|Generated from $@.sh.in; do not edit by hand.|g'

$(BASHSCRIPTS): Makefile
	$(AM_V_at)$(RM) $@
	$(AM_V_GEN)test -f $(srcdir)/$@.sh.in && m4 -P -I $(srcdir) $(srcdir)/$@.sh.in | $(edit) >$@
	$(AM_V_at)chmod +x,a-w $@
	@$(BASH_SHELL) -O extglob -n $@

$(PERLSCRIPTS): Makefile
	$(AM_V_at)$(RM) $@ $@.tmp
	$(AM_V_GEN)$(edit) $(srcdir)/$@.pl.in >$@.tmp
	$(AM_V_at)chmod +x,a-w $@.tmp
	$(AM_V_at)mv $@.tmp $@

$(OURFILES): Makefile
	$(AM_V_at)$(RM) $@ $@.tmp
	$(AM_V_GEN)$(edit) $(srcdir)/$@.in >$@.tmp
	$(AM_V_at)chmod a-w $@.tmp
	$(AM_V_at)mv $@.tmp $@

all-am: $(OURSCRIPTS) $(OURFILES)

checkupdates: $(srcdir)/checkupdates.sh.in $(top_srcdir)/lib/output_format.sh $(top_srcdir)/lib/term_colors.sh
paccache: $(srcdir)/paccache.sh.in $(top_srcdir)/lib/output_format.sh $(top_srcdir)/lib/parseopts.sh $(top_srcdir)/lib/size_to_human.sh $(top_srcdir)/lib/term_colors.sh
pacdiff: $(srcdir)/pacdiff.sh.in $(top_srcdir)/lib/output_format.sh $(top_srcdir)/lib/term_colors.sh
paclist: $(srcdir)/paclist.sh.in
paclog-pkglist: $(srcdir)/paclog-pkglist.sh.in
pacscripts: $(srcdir)/pacscripts.sh.in
rankmirrors: $(srcdir)/rankmirrors.sh.in
updpkgsums: $(srcdir)/updpkgsums.sh.in

pacsearch: $(srcdir)/pacsearch.pl.in

pacsort_SOURCES = pacsort.c
pacsort_LDADD = $(LIBARCHIVE_LIBS) $(LIBALPM_LIBS)

pactree_SOURCES = pactree.c
pactree_LDADD = $(LIBARCHIVE_LIBS) $(LIBALPM_LIBS)

# vim:set noet:
