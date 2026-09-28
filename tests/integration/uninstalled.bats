#!/usr/bin/env bats
# -u / --uninstalled: packages reported by `pacman -Qq` are treated as a
# blacklist. pacman is the shim from tests/shims/, so the host's package
# database is never consulted.

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox

	TEST_CACHE="$TMPDIR/cache"
	create_multi_pkg_cache "$TEST_CACHE"
}

@test "uninstalled: installed packages are excluded from candidates" {
	PACMAN_SHIM_INSTALLED=$'pkg-a\npkg-c' run yaycache -d -u -k0 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ "$(PACMAN_SHIM_INSTALLED=$'pkg-a\npkg-c' list_candidates -u -k0 -c "$TEST_CACHE/" | wc -l)" -eq 4 ]
	[[ "$output" =~ pkg-b-0.1 ]]
	! [[ "$output" =~ pkg-a ]]
	! [[ "$output" =~ pkg-c ]]
}

@test "uninstalled: -r only removes uninstalled packages" {
	PACMAN_SHIM_INSTALLED=$'pkg-a\npkg-c' run yaycache -r -u -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ "$(count_files "$TEST_CACHE" 'pkg-b-*')" -eq 0 ]
	[ "$(count_files "$TEST_CACHE" 'pkg-a-*')" -eq 3 ]
	[ "$(count_files "$TEST_CACHE" 'pkg-c-*')" -eq 2 ]
}

@test "uninstalled: pacman is queried exactly once with -Qq" {
	PACMAN_SHIM_INSTALLED='pkg-a' run yaycache -d -u -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ "$(wc -l < "$PACMAN_SHIM_LOG")" -eq 1 ]
	[ "$(cat "$PACMAN_SHIM_LOG")" == $'pacman\t-Qq' ]
}

@test "uninstalled: pacman failure aborts without removing anything" {
	PACMAN_SHIM_FAIL=1 run yaycache -r -u -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "failed to retrieve the list of installed packages" ]]
	[ "$(count_packages "$TEST_CACHE")" -eq 9 ]
}

@test "uninstalled: empty installed list aborts (pacman -Qq gave nothing)" {
	PACMAN_SHIM_INSTALLED='' run yaycache -r -u -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 1 ]
	[ "$(count_packages "$TEST_CACHE")" -eq 9 ]
}

@test "uninstalled: combines with -i blacklist" {
	PACMAN_SHIM_INSTALLED='pkg-a' run yaycache -d -u -i pkg-b -k0 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ "$(PACMAN_SHIM_INSTALLED='pkg-a' list_candidates -u -i pkg-b -k0 -c "$TEST_CACHE/" | wc -l)" -eq 2 ]
	[[ "$output" =~ pkg-c-5.0 ]]
}

@test "uninstalled: still honours --keep for uninstalled packages" {
	PACMAN_SHIM_INSTALLED='pkg-a' run yaycache -d -u -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# pkg-b has 4 versions -> 3, pkg-c has 2 -> 1
	[ "$(PACMAN_SHIM_INSTALLED='pkg-a' list_candidates -u -k1 -c "$TEST_CACHE/" | wc -l)" -eq 4 ]
}
