AC_INIT([yaycache], [0.3.3], [https://github.com/aokellermann/yaycache])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])
AC_REQUIRE_AUX_FILE([tap-driver.sh])

AM_INIT_AUTOMAKE([-Wall foreign])

# Help line for root directory
AC_ARG_WITH(root-dir,
	AS_HELP_STRING([--with-root-dir=PATH], [set the location of the root operating directory]),
	[ROOTDIR=$withval], [ROOTDIR=/])

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

# Check for libmakepkg
PKG_CHECK_VAR(LIBMAKEPKGDIR, [libmakepkg], [libmakepkgdir], ,
	AC_MSG_ERROR([*** libmakepkg is needed to build yaycache!]))
AC_SUBST(LIBMAKEPKGDIR)

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

SIZECMD="stat -c %s"
AC_SUBST(SIZECMD)

# Check for documentation support and status
AC_CHECK_PROGS([ASCIIDOC], [asciidoc])
AC_MSG_CHECKING([for building documentation])
if test "x$wantdoc" = "xyes" ; then
	if test $ASCIIDOC ; then
		AC_MSG_RESULT([yes, enabled by configure])
	else
		asciidoc="(warning : asciidoc not installed)"
		AC_MSG_RESULT([yes $asciidoc])
	fi
	wantdoc=yes
else
	AC_MSG_RESULT([no, disabled by configure])
	wantdoc=no
fi
AM_CONDITIONAL(WANT_DOC, test "x$wantdoc" = "xyes")

AC_CONFIG_FILES([
	completions/Makefile
	lib/Makefile
	src/Makefile
	doc/Makefile
	Makefile
])
AC_OUTPUT

echo "
${PACKAGE_NAME}:

  Build information:
    prefix                 : ${prefix}
    libmakepkg dir         : $(eval echo ${LIBMAKEPKGDIR})

    Filesize command       : ${SIZECMD}

    using git version      : ${usegitver}

  Directory and file information:
    root working directory : ${ROOTDIR}

  Compilation options:
    Run make in doc/ dir   : ${wantdoc} ${asciidoc}
    use git version        : ${wantgitver}
"
