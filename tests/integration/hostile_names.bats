#!/usr/bin/env bats
# Filenames inside a yay cache directory are chosen by whoever maintains the
# AUR package: `yay -S` clones the repository before anything is built, so even
# the tracked names are untrusted. The candidate pipeline used to be
# newline-delimited, so a name containing a newline split into two records; the
# second was a bare relative name that `rm -r` / `mv` then resolved against the
# directory yaycache was started from ($HOME for yaycache.service).

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox

	YAY_CACHE="$HOME/.cache/yay"
	EVIL="$YAY_CACHE/evil"
	mkdir -p "$EVIL"
	# four "versions" of foo whose names continue, after a newline, with the
	# name of an entry in the directory yaycache runs from
	local v
	for v in 1 2 3 4; do
		: > "$EVIL/foo-$v-1-x86_64.pkg.tar.zst"$'\n'"victim"
	done

	# the directory yaycache is started from, holding the would-be victim
	CWD="$BATS_TEST_TMPDIR/cwd"
	mkdir -p "$CWD/victim"
	: > "$CWD/victim/precious"
	cd "$CWD"
}

@test "hostile names: -r deletes only the oldest hostile package, nothing outside the cache" {
	run yaycache -r
	[ "$status" -eq 0 ]
	[ -f "$CWD/victim/precious" ]
	[ ! -e "$EVIL/foo-1-1-x86_64.pkg.tar.zst"$'\n'"victim" ]
	[ "$(count_packages_nul "$EVIL")" -eq 3 ]
}

@test "hostile names: -m moves only the oldest hostile package, nothing outside the cache" {
	mkdir "$BATS_TEST_TMPDIR/dest"
	run yaycache -m "$BATS_TEST_TMPDIR/dest"
	[ "$status" -eq 0 ]
	[ -f "$CWD/victim/precious" ]
	[ ! -e "$BATS_TEST_TMPDIR/dest/victim" ]
	[ -f "$BATS_TEST_TMPDIR/dest/foo-1-1-x86_64.pkg.tar.zst"$'\n'"victim" ]
	[ "$(count_packages_nul "$EVIL")" -eq 3 ]
}

@test "hostile names: --remove-build-files removes a nested clone's newline file, nothing outside the cache" {
	rm -rf "$EVIL"
	create_aur_pkg_dir "$YAY_CACHE/alpha" alpha 1.0
	# inside the nested upstream clone, which git reports to yaycache as a
	# single directory entry that find then expands
	: > "$YAY_CACHE/alpha/src/alpha-1.0/junk"$'\n'"victim"

	run yaycache -r -k0 --remove-build-files
	[ "$status" -eq 0 ]
	[ -f "$CWD/victim/precious" ]
	[ ! -e "$YAY_CACHE/alpha/src" ]
}

@test "hostile names: --remove-build-files removes an untracked file with a newline in its name" {
	rm -rf "$EVIL"
	create_aur_pkg_dir "$YAY_CACHE/alpha" alpha 1.0
	: > "$YAY_CACHE/alpha/junk"$'\n'"victim"

	run yaycache -r -k0 --remove-build-files
	[ "$status" -eq 0 ]
	[ -f "$CWD/victim/precious" ]
	[ ! -e "$YAY_CACHE/alpha/junk"$'\n'"victim" ]
}

@test "hostile names: -vv -z lists a newline name as a single NUL-terminated path" {
	# the one candidate holds a newline: with -z it must still be one record
	[ "$(yaycache -d -vv -z | count_nuls)" -eq 1 ]
	# NUL -> newline and newline -> | so the record can be compared as a line
	yaycache -d -vv -z | tr '\n\0' '|\n' |
		grep -qx -F -e "==> Candidate files:|$EVIL/foo-1-1-x86_64.pkg.tar.zst|victim"
}
