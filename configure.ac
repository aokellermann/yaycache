AC_INIT([pacman-contrib], [0.0.0], [pacman-contrib@lists.archlinux.org])

AM_INIT_AUTOMAKE([-Wall foreign])

if test "$pkgdatadir" = ""; then
    pkgdatadir="$datadir/$PACKAGE_NAME"
fi

# Help line for root directory
AC_ARG_WITH(root-dir,
	AS_HELP_STRING([--with-root-dir=PATH], [set the location of the root operating directory]),
	[ROOTDIR=$withval], [ROOTDIR=/])

# Help line for vim runtime directory
AC_ARG_WITH(vim-dir,
	[AS_HELP_STRING([--with-vim-dir=PATH], [set the location of the vim runtime file directory])],
	[vim_dir=$withval], [vim_dir=$pkgdatadir/vim])

# Help line for using git version in pacman version string
AC_ARG_ENABLE(git-version,
	AS_HELP_STRING([--enable-git-version],
		[enable use of git version in version string if available]),
	[wantgitver=$enableval], [wantgitver=no])

# Checks for programs.
AC_PROG_CC
AC_PROG_CC_C99
AC_PATH_PROGS([BASH_SHELL], [bash bash4], [false])

AS_IF([test "x$BASH_SHELL" = "xfalse"],
	AC_MSG_WARN([*** bash >= 4.1.0 is required for pacman scripts]),
	[bash_version_major=`$BASH_SHELL -c 'echo "${BASH_VERSINFO[[0]]}"'`
	bash_version_minor=`$BASH_SHELL -c 'echo "${BASH_VERSINFO[[1]]}"'`
	ok=yes
	if test "$bash_version_major" -lt 4; then
		ok=no
	fi
	if test "$bash_version_major" -eq 4 && test "$bash_version_minor" -lt 1; then
		ok=no
	fi
	if test "$ok" = "no"; then
		AC_MSG_ERROR([*** bash >= 4.1.0 is required for pacman scripts])
	fi
	unset bash_version_major bash_version_minor ok])

# Check for libarchive
PKG_CHECK_MODULES(LIBARCHIVE, [libarchive >= 2.8.0], ,
	AC_MSG_ERROR([*** libarchive >= 2.8.0 is needed to build pacman-contrib!]))

# Check for libalpm
PKG_CHECK_MODULES(LIBALPM, [libalpm], ,
	AC_MSG_ERROR([*** libalpm is needed to build pacman-contrib!]))

# Enable or disable use of git version in version string
AC_MSG_CHECKING(whether to use git version if available)
if test "x$wantgitver" = "xyes" ; then
	AC_CHECK_PROGS([GIT], [git])
	AC_CHECK_FILE([.git/], hasgitdir=yes)
	usegitver=$ac_cv_file__git_
	if test $GIT -a "x$hasgitdir" = "xyes"; then
		AC_DEFINE([USE_GIT_VERSION], , [Use GIT version in version string])
	fi
else
	AC_MSG_RESULT([no, disabled by configure])
	usegitver=no
fi
AM_CONDITIONAL(USE_GIT_VERSION, test "x$usegitver" = "xyes")

# Set root directory
AC_SUBST(ROOTDIR)
AC_DEFINE_UNQUOTED([ROOTDIR], "$ROOTDIR", [The location of the root operating directory])
AC_SUBST(vim_dir, [$vim_dir])

SIZECMD="stat -c %s"
AC_SUBST(SIZECMD)

AC_CONFIG_FILES([
	Makefile
	src/Makefile
	lib/Makefile
])
AC_OUTPUT
