#!/usr/bin/env bats
# Default cache directory resolution: $XDG_CACHE_HOME/yay/*/ or
# $HOME/.cache/yay/*/. These tests run yaycache without -c, which is only
# safe because HOME is a throwaway directory inside the sandbox.

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox

	YAY_CACHE="$HOME/.cache/yay"
	create_realistic_yay_cache "$YAY_CACHE"
}

@test "default: uses \$HOME/.cache/yay/*/ when XDG_CACHE_HOME is unset" {
	run yaycache -d -vv -k1
	[ "$status" -eq 0 ]
	[ "$(list_candidates -k1 | wc -l)" -eq 5 ]
	[[ "$output" =~ "$YAY_CACHE/alpha/alpha-1.0-1-x86_64.pkg.tar.zst" ]]
	[[ "$output" =~ "$YAY_CACHE/beta-git/beta-git-0.2-1-x86_64.pkg.tar.zst" ]]
}

@test "default: -r without -c cleans every package dir under the yay cache" {
	run yaycache -r -k1
	[ "$status" -eq 0 ]
	[[ "$output" =~ "files removed" ]]
	[ "$(count_packages "$YAY_CACHE/alpha")" -eq 1 ]
	[ "$(count_packages "$YAY_CACHE/beta-git")" -eq 1 ]
	[ "$(count_packages "$YAY_CACHE/gamma")" -eq 1 ]
	package_exists "$YAY_CACHE/alpha" alpha 2.0 1
	package_exists "$YAY_CACHE/beta-git" beta-git 0.3 1
	package_exists "$YAY_CACHE/gamma" gamma 5.0 1
	# build files untouched without --remove-build-files
	[ -d "$YAY_CACHE/alpha/src" ]
	[ -f "$YAY_CACHE/alpha/alpha-2.0.tar.gz" ]
}

@test "default: systemd unit invocation (-r, keep=3) removes only the oldest" {
	run yaycache -r
	[ "$status" -eq 0 ]
	[[ "$output" =~ "files removed" ]]
	! package_exists "$YAY_CACHE/alpha" alpha 1.0 1
	[ "$(count_packages "$YAY_CACHE/alpha")" -eq 3 ]
	[ "$(count_packages "$YAY_CACHE/beta-git")" -eq 3 ]
	[ "$(count_packages "$YAY_CACHE/gamma")" -eq 1 ]
}

@test "default: XDG_CACHE_HOME takes precedence over HOME" {
	local xdg="$HOME/xdg-cache"
	create_aur_pkg_dir "$xdg/yay/delta" delta 1.0 2.0
	XDG_CACHE_HOME="$xdg" run yaycache -r -k1 -vv
	[ "$status" -eq 0 ]
	[[ "$output" =~ "files removed" ]]
	! package_exists "$xdg/yay/delta" delta 1.0 1
	package_exists "$xdg/yay/delta" delta 2.0 1
	# ~/.cache/yay must be untouched
	[ "$(count_packages "$YAY_CACHE")" -eq 8 ]
}

@test "default: XDG_CACHE_HOME without a yay cache finds nothing" {
	local xdg="$HOME/empty-cache"
	mkdir -p "$xdg"
	XDG_CACHE_HOME="$xdg" run yaycache -r -k0
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate packages" ]]
	[ "$(count_packages "$YAY_CACHE")" -eq 8 ]
}

@test "default: no yay cache at all is not an error" {
	rm -rf "$YAY_CACHE"
	run yaycache -r -k0
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate packages" ]]
}

@test "default: explicit -c overrides the default and leaves HOME cache alone" {
	local other="$TMPDIR/other-cache"
	create_mock_cache "$other"
	run yaycache -r -k0 -c "$other/"
	[ "$status" -eq 0 ]
	[ "$(count_packages "$other")" -eq 0 ]
	[ "$(count_packages "$YAY_CACHE")" -eq 8 ]
}

@test "default: non-package directories under the yay cache are harmless" {
	mkdir -p "$YAY_CACHE/completion.cache"
	echo "not a package" > "$YAY_CACHE/vcs.json"
	run yaycache -r -k1
	[ "$status" -eq 0 ]
	[ -f "$YAY_CACHE/vcs.json" ]
	[ -d "$YAY_CACHE/completion.cache" ]
	[ "$(count_packages "$YAY_CACHE")" -eq 3 ]
}
