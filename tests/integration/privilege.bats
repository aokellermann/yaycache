#!/usr/bin/env bats
# Privilege escalation path (runcmd -> sudo). Real sudo is replaced by
# tests/shims/sudo, which records every call and refuses unless
# SUDO_SHIM_MODE=passthrough.

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox
	skip_if_root

	TEST_CACHE="$TMPDIR/cache"
	create_mock_cache "$TEST_CACHE"
}

teardown() {
	chmod -R u+w "$TMPDIR" 2>/dev/null || true
}

sudo_calls() {
	[[ -f $SUDO_SHIM_LOG ]] && cat "$SUDO_SHIM_LOG"
	return 0
}

@test "privilege: unwritable cachedir + -r asks sudo, refusal aborts before deleting" {
	chmod 555 "$TEST_CACHE"
	run yaycache -r -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "Escalating privileges using sudo" ]]
	[[ "$output" =~ "Failed to escalate" ]]
	[ "$(sudo_calls | head -1)" == $'sudo\t-v' ]
	! sudo_calls | grep -q 'rm'
	[ "$(count_packages "$TEST_CACHE")" -eq 5 ]
}

@test "privilege: dry run on an unwritable cachedir never touches sudo" {
	chmod 555 "$TEST_CACHE"
	run yaycache -d -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ "$(list_candidates -k1 -c "$TEST_CACHE/" | wc -l)" -eq 4 ]
	[ -z "$(sudo_calls)" ]
}

@test "privilege: writable cachedir never invokes sudo" {
	run yaycache -r -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ -z "$(sudo_calls)" ]
	[ "$(count_packages "$TEST_CACHE")" -eq 1 ]
}

@test "privilege: escalated command line is 'xargs -0 rm -r' with the chosen options" {
	chmod 555 "$TEST_CACHE"
	SUDO_SHIM_MODE=passthrough run yaycache -r -f -v -k1 -c "$TEST_CACHE/"
	# passthrough runs rm as the unprivileged user, so the removal itself fails
	[ "$status" -ne 0 ]
	sudo_calls | grep -qx $'sudo\t-v'
	sudo_calls | grep -qx $'sudo\t-l'
	sudo_calls | grep -qx $'sudo\txargs\t-0\trm\t-r\t-f\t-v'
	[ "$(count_packages "$TEST_CACHE")" -eq 5 ]
}

@test "privilege: escalated move command line is 'xargs -0 mv -t <dir>'" {
	local dest="$TMPDIR/dest"
	mkdir -p "$dest"
	chmod 555 "$dest"
	SUDO_SHIM_MODE=passthrough run yaycache -m "$dest" -k1 -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	sudo_calls | grep -qx $'sudo\txargs\t-0\tmv\t-t\t'"$dest"
	[ "$(count_packages "$TEST_CACHE")" -eq 5 ]
	[ "$(count_packages "$dest")" -eq 0 ]
}

@test "privilege: an unwritable build-file directory makes the whole run need root" {
	create_aur_pkg_dir "$TMPDIR/aur/pkg" pkg 1.0 1.1
	chmod 555 "$TMPDIR/aur/pkg/pkg-1.1/.." 2>/dev/null || true
	chmod 555 "$TMPDIR/aur/pkg/src"
	run yaycache -r -k1 --remove-build-files -c "$TMPDIR/aur/pkg/"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "Failed to escalate" ]]
	# nothing at all was removed, packages included
	[ "$(count_packages "$TMPDIR/aur/pkg")" -eq 2 ]
	[ -f "$TMPDIR/aur/pkg/pkg-1.1.tar.gz" ]
}

@test "privilege: unwritable parent of a candidate with writable cachedir" {
	local nested="$TEST_CACHE/sub"
	mkdir -p "$nested"
	create_mock_package "$nested" deep 1.0 1
	create_mock_package "$nested" deep 1.1 1
	chmod 555 "$nested"
	# cachedir itself is writable, but the deep package's parent is not
	run yaycache -r -k1 -c "$nested/"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "Failed to escalate" ]]
	[ "$(count_packages "$nested")" -eq 2 ]
}
