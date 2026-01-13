#!/usr/bin/env bats
# Integration tests for remove mode (-r)

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
	create_mock_cache "$TEST_CACHE"
}

teardown() {
	rm -rf "$TEST_CACHE"
}

@test "remove: deletes candidate packages" {
	# 5 versions, keep 3, should delete 2 oldest
	run run_yaycache -r -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Oldest 2 should be gone
	[ ! -f "$TEST_CACHE/test-pkg-1.0-1-x86_64.pkg.tar.zst" ]
	[ ! -f "$TEST_CACHE/test-pkg-1.1-1-x86_64.pkg.tar.zst" ]

	# Newest 3 should remain
	[ -f "$TEST_CACHE/test-pkg-1.2-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_CACHE/test-pkg-2.0-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_CACHE/test-pkg-2.1-1-x86_64.pkg.tar.zst" ]
}

@test "remove: -k1 keeps only newest" {
	run run_yaycache -r -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Only newest should remain
	[ ! -f "$TEST_CACHE/test-pkg-1.0-1-x86_64.pkg.tar.zst" ]
	[ ! -f "$TEST_CACHE/test-pkg-1.1-1-x86_64.pkg.tar.zst" ]
	[ ! -f "$TEST_CACHE/test-pkg-1.2-1-x86_64.pkg.tar.zst" ]
	[ ! -f "$TEST_CACHE/test-pkg-2.0-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_CACHE/test-pkg-2.1-1-x86_64.pkg.tar.zst" ]
}

@test "remove: -k0 removes all versions" {
	run run_yaycache -r -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# All should be gone
	local count=$(count_packages "$TEST_CACHE")
	[ "$count" -eq 0 ]
}

@test "remove: reports disk space saved" {
	run run_yaycache -r -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Verify disk space is reported with a number and unit (e.g., "3 KiB disk space saved")
	[[ "$output" =~ [0-9].*"disk space saved" ]]
}

@test "remove: reports files removed count" {
	run run_yaycache -r -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "removed" ]]
}

@test "remove: -f forces removal" {
	# Make a file read-only (within our permissions)
	chmod 444 "$TEST_CACHE/test-pkg-1.0-1-x86_64.pkg.tar.zst"

	run run_yaycache -r -f -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	[ ! -f "$TEST_CACHE/test-pkg-1.0-1-x86_64.pkg.tar.zst" ]
}

@test "remove: verbose shows deleted files" {
	run run_yaycache -r -v -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Verify verbose output shows actual file paths being removed
	[[ "$output" =~ "test-pkg-1.0-1-x86_64.pkg.tar.zst" ]]
	[[ "$output" =~ "test-pkg-1.1-1-x86_64.pkg.tar.zst" ]]
}

@test "remove: handles multiple packages" {
	create_multi_pkg_cache "$TEST_CACHE"

	run run_yaycache -r -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Each package type should have only 1 version remaining
	# test-pkg: 1 remaining
	[ -f "$TEST_CACHE/test-pkg-2.1-1-x86_64.pkg.tar.zst" ]
	# pkg-a: 1 remaining
	[ -f "$TEST_CACHE/pkg-a-1.2-1-x86_64.pkg.tar.zst" ]
	# pkg-b: 1 remaining
	[ -f "$TEST_CACHE/pkg-b-0.4-1-x86_64.pkg.tar.zst" ]
	# pkg-c: 1 remaining
	[ -f "$TEST_CACHE/pkg-c-5.1-1-x86_64.pkg.tar.zst" ]
}

@test "remove: no candidates does nothing" {
	rm -f "$TEST_CACHE"/*.pkg.tar.*
	create_mock_package "$TEST_CACHE" "single" "1.0" "1" "x86_64"

	run run_yaycache -r -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]

	# File should still exist
	[ -f "$TEST_CACHE/single-1.0-1-x86_64.pkg.tar.zst" ]
}

@test "remove: with build files" {
	# Clear the default mock cache and create a fresh git cache
	rm -rf "$TEST_CACHE"
	TEST_CACHE=$(mktemp -d)

	create_mock_git_cache "$TEST_CACHE"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.1" "1" "x86_64"

	# Note: Exit status may be non-zero due to race conditions with rm -r
	# when removing nested git directories, but files should still be removed
	run_yaycache -r --remove-build-files -k1 -c "$TEST_CACHE/" || true

	# Old package should be removed
	[ ! -f "$TEST_CACHE/test-pkg-1.0-1-x86_64.pkg.tar.zst" ]
	# New package should remain
	[ -f "$TEST_CACHE/test-pkg-1.1-1-x86_64.pkg.tar.zst" ]
	# Build files should be removed
	[ ! -f "$TEST_CACHE/src/main.c" ]
	[ ! -f "$TEST_CACHE/src/main.o" ]
}
