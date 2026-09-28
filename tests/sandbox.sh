#!/bin/bash
#
# sandbox.sh - run a command inside an isolated environment for the test suite
#
# Usage: tests/sandbox.sh [--no-bwrap] [--] <command> [args...]
#
# The test suite exercises `rm -r`, `mv` and sudo escalation paths, so it must
# never be able to reach the developer's real ~/.cache/yay, /tmp or privileges.
# This wrapper builds a throwaway environment and runs the given command in it:
#
#   * a fresh, empty HOME on tmpfs (the real home directory is not mounted)
#   * a private tmpfs /tmp, /var/tmp and /run
#   * no network, separate PID/IPC/UTS/user namespaces (bubblewrap)
#   * /usr, /etc essentials and the source/build trees mounted read-only
#   * shim `sudo` and `pacman` binaries first on PATH (tests/shims/)
#   * a scrubbed environment: only the variables the tests need survive
#
# bubblewrap (bwrap) provides the namespace/mount isolation. When it is not
# available, or when YAYCACHE_NO_SANDBOX=1 / --no-bwrap is given (e.g. inside a
# container that is itself the sandbox), the mount isolation is skipped but the
# throwaway HOME, TMPDIR, shims and environment scrubbing are still applied.
#
# Environment consumed:
#   SRCDIR, BUILDDIR   source and build trees (default: derived from this file)
#   YAYCACHE           path to the built yaycache script
#   YAYCACHE_NO_SANDBOX=1   same as --no-bwrap
#   BWRAP              bubblewrap binary (default: bwrap)

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
srcdir=$(cd "${SRCDIR:-$here/..}" && pwd)
builddir=$(cd "${BUILDDIR:-$srcdir}" && pwd)
yaycache=${YAYCACHE:-$builddir/src/yaycache}
use_bwrap=1
[[ ${YAYCACHE_NO_SANDBOX:-0} == 1 ]] && use_bwrap=0

while (( $# )); do
	case $1 in
		--no-bwrap) use_bwrap=0; shift ;;
		--) shift; break ;;
		-*) echo "sandbox.sh: unknown option '$1'" >&2; exit 2 ;;
		*) break ;;
	esac
done
(( $# )) || { echo "sandbox.sh: no command given" >&2; exit 2; }

if [[ ! -x $yaycache ]]; then
	echo "sandbox.sh: yaycache not built at '$yaycache' (run make first)" >&2
	exit 2
fi

bwrap=${BWRAP:-bwrap}
if (( use_bwrap )) && ! command -v "$bwrap" >/dev/null 2>&1; then
	cat >&2 <<-MSG
	sandbox.sh: bubblewrap ('$bwrap') not found.
	  Install it (pacman -S bubblewrap) to run the tests in an isolated
	  filesystem, or set YAYCACHE_NO_SANDBOX=1 to run without mount isolation
	  (only do that inside a container or throwaway VM).
	MSG
	exit 2
fi

# Absolute path of the real home so tests can assert it is unreachable.
real_home=${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}

# The environment handed to the tests. Nothing else from the caller survives.
fake_home=/home/tester
declare -a env_vars=(
	HOME="$fake_home"
	TMPDIR=/tmp
	PATH="$srcdir/tests/shims:$(dirname "$yaycache"):/usr/local/bin:/usr/bin:/bin"
	LC_ALL=C
	TERM="${TERM:-dumb}"
	SRCDIR="$srcdir"
	BUILDDIR="$builddir"
	YAYCACHE="$yaycache"
	TEST_COMMON="$srcdir/tests/common.bash"
	BATS_LIB_PATH="$srcdir/tests/lib"
	YAYCACHE_SANDBOX=1
	YAYCACHE_SANDBOX_BWRAP="$use_bwrap"
	YAYCACHE_REAL_HOME="$real_home"
	GIT_CONFIG_NOSYSTEM=1
	GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester@example.invalid
	GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester@example.invalid
)
# Pass through knobs that steer the shims / bats when the caller set them.
for v in SUDO_SHIM_MODE SUDO_SHIM_LOG PACMAN_SHIM_INSTALLED PACMAN_SHIM_FAIL \
         PACMAN_SHIM_LOG BATS_TMPDIR TAP_VERSION; do
	[[ -n ${!v+x} ]] && env_vars+=("$v=${!v}")
done

if (( ! use_bwrap )); then
	# No mount isolation: fall back to a throwaway HOME and TMPDIR under a
	# private temporary directory, and scrub the environment with env -i.
	work=$(mktemp -d "${TMPDIR:-/tmp}/yaycache-test.XXXXXX")
	trap 'rm -rf "$work"' EXIT
	mkdir -p "$work/home" "$work/tmp"
	for i in "${!env_vars[@]}"; do
		case ${env_vars[$i]} in
			HOME=*) env_vars[i]="HOME=$work/home" ;;
			TMPDIR=*) env_vars[i]="TMPDIR=$work/tmp" ;;
		esac
	done
	env -i "${env_vars[@]}" "$@"
	exit $?
fi

declare -a args=(
	--unshare-all
	--die-with-parent
	--new-session
	--clearenv
	--ro-bind /usr /usr
	--proc /proc
	--dev /dev
	--tmpfs /tmp
	--tmpfs /var/tmp
	--tmpfs /run
	--tmpfs /home
	--dir "$fake_home"
	--chdir "$PWD"
)
# Merged-/usr symlinks (Arch) or real directories (others).
for d in /bin /sbin /lib /lib64; do
	if [[ -L $d ]]; then
		args+=(--symlink "$(readlink "$d")" "$d")
	elif [[ -d $d ]]; then
		args+=(--ro-bind "$d" "$d")
	fi
done
# Only the pieces of /etc the tools need; nothing user-specific.
for f in /etc/passwd /etc/group /etc/nsswitch.conf /etc/ld.so.cache \
         /etc/ld.so.conf /etc/ld.so.conf.d /etc/localtime /etc/alternatives \
         /etc/hosts /etc/resolv.conf; do
	[[ -e $f ]] && args+=(--ro-bind "$f" "$f")
done
# Source and build trees are visible but immutable; when they live under
# the (unmounted) real home this also proves nothing else from it leaks in.
args+=(--ro-bind "$srcdir" "$srcdir")
[[ $builddir != "$srcdir" ]] && args+=(--ro-bind "$builddir" "$builddir")
# Keep the caller's cwd reachable when it is outside those trees (VPATH builds
# run the log compiler from tests/ inside the build dir, which is covered).
case $PWD in
	"$srcdir"|"$srcdir"/*|"$builddir"|"$builddir"/*) ;;
	*) args+=(--ro-bind "$PWD" "$PWD") ;;
esac
for kv in "${env_vars[@]}"; do
	args+=(--setenv "${kv%%=*}" "${kv#*=}")
done

exec "$bwrap" "${args[@]}" -- "$@"
