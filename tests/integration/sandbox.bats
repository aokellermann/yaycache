#!/usr/bin/env bats
# Self-checks for the test sandbox (tests/sandbox.sh). If any of these fail,
# the rest of the suite must not be trusted to leave the host alone.

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox
}

bwrap_only() {
	[[ ${YAYCACHE_SANDBOX_BWRAP:-0} == 1 ]] || skip "needs bubblewrap mount isolation"
}

@test "sandbox: HOME is a throwaway directory" {
	[[ $HOME != "$YAYCACHE_REAL_HOME" ]]
	[[ -d $HOME && -w $HOME ]]
	[[ ! -e $HOME/.cache/yay ]]
	touch "$HOME/.probe"
	[[ -f $HOME/.probe ]]
}

@test "sandbox: real home directory contents are not visible" {
	bwrap_only
	# The real home may exist as an empty mount-point skeleton when the source
	# tree lives beneath it, but nothing except that path may be inside it.
	[[ ! -e $YAYCACHE_REAL_HOME/.cache ]]
	[[ ! -e $YAYCACHE_REAL_HOME/.config ]]
	if [[ -d $YAYCACHE_REAL_HOME ]]; then
		local entry ok
		while IFS= read -r entry; do
			ok=0
			for tree in "$SRCDIR" "$BUILDDIR" "$PWD"; do
				[[ $tree == "$YAYCACHE_REAL_HOME/$entry" || $tree == "$YAYCACHE_REAL_HOME/$entry/"* ]] && ok=1
			done
			(( ok )) || { echo "unexpected entry in real home: $entry"; return 1; }
		done < <(ls -A "$YAYCACHE_REAL_HOME")
	fi
}

@test "sandbox: TMPDIR is private and empty at start" {
	[[ -n $TMPDIR && -d $TMPDIR && -w $TMPDIR ]]
	bwrap_only
	[[ $(stat -f -c %T "$TMPDIR") == tmpfs ]]
}

@test "sandbox: sudo is the shim and refuses by default" {
	[[ $(command -v sudo) == "$SRCDIR/tests/shims/sudo" ]]
	run sudo -v
	[ "$status" -ne 0 ]
	run sudo true
	[ "$status" -ne 0 ]
	grep -q '^sudo	-v$' "$SUDO_SHIM_LOG"
}

@test "sandbox: pacman is the shim" {
	[[ $(command -v pacman) == "$SRCDIR/tests/shims/pacman" ]]
	PACMAN_SHIM_INSTALLED=$'foo\nbar' run pacman -Qq
	[ "$status" -eq 0 ]
	[ "$output" == $'foo\nbar' ]
}

@test "sandbox: yaycache under test is the built script" {
	[[ $(command -v yaycache) == "$YAYCACHE" ]]
	run yaycache --version
	[ "$status" -eq 0 ]
}

@test "sandbox: source and build trees are read-only" {
	bwrap_only
	run touch "$SRCDIR/.sandbox-write-probe"
	[ "$status" -ne 0 ]
	run touch "$BUILDDIR/src/.sandbox-write-probe"
	[ "$status" -ne 0 ]
}

@test "sandbox: no network" {
	bwrap_only
	run timeout 5 bash -c ': </dev/tcp/1.1.1.1/53'
	[ "$status" -ne 0 ]
}

@test "sandbox: environment is scrubbed" {
	[[ -z ${SSH_AUTH_SOCK:-} ]]
	[[ -z ${XDG_CACHE_HOME:-} ]]
	[[ -z ${XDG_CONFIG_HOME:-} ]]
	[[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]]
}
