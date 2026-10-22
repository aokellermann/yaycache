#!/usr/bin/env bats
# A failure inside a candidate pipeline (pacsort crashing on a malformed name,
# git refusing to list a clone) used to be silent: the directory was treated as
# holding nothing to remove, so a hostile name could exempt its directory from
# cleaning for good. A failed scan is now reported, its results are discarded,
# the other directories are still cleaned, and the run exits 1.

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox

	YAY_CACHE="$HOME/.cache/yay"
	create_realistic_yay_cache "$YAY_CACHE"
	# shims put in front of PATH for one yaycache run
	SHIMS="$BATS_TEST_TMPDIR/shims"
	mkdir -p "$SHIMS"
}

# a pacsort that dies with SIGSEGV whenever its input mentions the given
# string, and behaves normally otherwise
crashing_pacsort() {
	cat > "$SHIMS/pacsort" <<-EOS
	#!/bin/bash
	input=\$(mktemp)
	cat > "\$input"
	if grep -qzF -e '$1' "\$input"; then
		kill -SEGV \$\$
	fi
	exec /usr/bin/pacsort "\$@" < "\$input"
	EOS
	chmod +x "$SHIMS/pacsort"
}

# a git whose ls-files fails
failing_git_ls_files() {
	cat > "$SHIMS/git" <<-'EOS'
	#!/bin/bash
	if [[ $1 == ls-files ]]; then
		echo 'git shim: simulated failure' >&2
		exit 128
	fi
	exec /usr/bin/git "$@"
	EOS
	chmod +x "$SHIMS/git"
}

@test "scan failures: a crashing pacsort is reported, its directory skipped, the others cleaned, exit 1" {
	crashing_pacsort '/beta-git/'

	PATH="$SHIMS:$PATH" run run_yaycache -r -k1
	[ "$status" -eq 1 ]
	[[ "$output" =~ "failed to scan" ]]
	[[ "$output" =~ "$YAY_CACHE/beta-git" ]]
	[ "$(count_packages "$YAY_CACHE/beta-git")" -eq 3 ]
	[ "$(count_packages "$YAY_CACHE/alpha")" -eq 1 ]
	[ "$(count_packages "$YAY_CACHE/gamma")" -eq 1 ]
}

@test "scan failures: a dry run whose only directory fails to scan exits 1" {
	crashing_pacsort '/alpha/'

	PATH="$SHIMS:$PATH" run run_yaycache -d -k1 -c "$YAY_CACHE/alpha/"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "failed to scan" ]]
	[ "$(count_packages "$YAY_CACHE/alpha")" -eq 4 ]
}

@test "scan failures: git failing to list a clone is reported, its build files kept, its packages still pruned, exit 1" {
	failing_git_ls_files

	PATH="$SHIMS:$PATH" run run_yaycache -r -k1 --remove-build-files -c "$YAY_CACHE/alpha/"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "failed to scan" ]]
	[ -d "$YAY_CACHE/alpha/src" ]
	[ -f "$YAY_CACHE/alpha/alpha-2.0.tar.gz" ]
	[ "$(count_packages "$YAY_CACHE/alpha")" -eq 1 ]
}

@test "scan failures: a clone with nothing untracked is not a failure" {
	create_aur_pkg_dir "$YAY_CACHE/clean" clean 1.0
	rm -rf "$YAY_CACHE/clean/src" "$YAY_CACHE/clean/pkg" "$YAY_CACHE/clean/clean-1.0.tar.gz" "$YAY_CACHE/clean/"*.pkg.tar*
	[ -z "$(git -C "$YAY_CACHE/clean" ls-files --others)" ]

	run run_yaycache -r -k1 --remove-build-files -c "$YAY_CACHE/clean/"
	[ "$status" -eq 0 ]
	[[ ! "$output" =~ "failed to scan" ]]
	[ -f "$YAY_CACHE/clean/PKGBUILD" ]
}
