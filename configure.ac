AC_INIT([pacman-contrib], [0.0.0], [arch-projects@archlinux.org])

AM_INIT_AUTOMAKE([-Wall foreign])

# Help line for documentation
AC_ARG_ENABLE(doc,
				AS_HELP_STRING([--disable-doc], [prevent make from looking at doc/ dir]),
					[wantdoc=$enableval], [wantdoc=yes])

# Help line for using git version in pacman version string
AC_ARG_ENABLE(git-version,
	AS_HELP_STRING([--enable-git-version],
		[enable use of git version in version string if available]),
	[wantgitver=$enableval], [wantgitver=no])

# Checks for programs.
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


AM_CONDITIONAL(WANT_DOC, test "x$wantdoc" = "xyes")

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

AC_CONFIG_FILES([
	Makefile
	src/Makefile
])
AC_OUTPUT
