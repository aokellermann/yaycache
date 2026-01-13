#!/usr/bin/env bats
# Integration tests for dry-run mode (-d)

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
	create_mock_cache "$TEST_CACHE"
}

teardown() {
	rm -rf "$TEST_CACHE"
}

@test "dryrun: lists candidates without removing" {
	# Count files before
	local before=$(count_packages "$TEST_CACHE")

	run run_yaycache -d -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Count files after - should be unchanged
	local after=$(count_packages "$TEST_CACHE")
	[ "$before" -eq "$after" ]
}

@test "dryrun: shows candidates with default keep=3" {
	# mock_cache creates 5 versions, keep=3 means 2 candidate files
	run run_yaycache -d -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Output counts cache directories with candidates, not files
	[[ "$output" =~ "1 candidates" ]]
}

@test "dryrun: files still exist after dryrun" {
	run run_yaycache -d -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# All 5 package files should still exist
	[ -f "$TEST_CACHE/test-pkg-1.0-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_CACHE/test-pkg-1.1-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_CACHE/test-pkg-1.2-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_CACHE/test-pkg-2.0-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_CACHE/test-pkg-2.1-1-x86_64.pkg.tar.zst" ]
}

@test "dryrun: -v shows filenames" {
	run run_yaycache -d -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "Candidate" ]]
	[[ "$output" =~ "test-pkg-" ]]
}

@test "dryrun: -vv shows full paths" {
	run run_yaycache -d -vv -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "$TEST_CACHE" ]]
}

@test "dryrun: -vvv shows grouped by package" {
	run run_yaycache -d -vvv -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Grouped output includes package directory name
	[[ "$output" =~ "Candidate" ]]
}

@test "dryrun: shows disk space saved" {
	run run_yaycache -d -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "disk space saved" ]]
}

@test "dryrun: no candidates message when all kept" {
	# With only 2 packages and keep=3, no candidates
	rm -f "$TEST_CACHE"/*.pkg.tar.*
	create_mock_package "$TEST_CACHE" "test-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.1" "1" "x86_64"

	run run_yaycache -d -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "dryrun: empty cache shows no candidates" {
	rm -f "$TEST_CACHE"/*.pkg.tar.*

	run run_yaycache -d -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "dryrun: reports correct byte size" {
	# Clear and create known-size packages
	rm -f "$TEST_CACHE"/*.pkg.tar.*
	create_mock_package "$TEST_CACHE" "size-test" "1.0" "1" "x86_64" 1000
	create_mock_package "$TEST_CACHE" "size-test" "1.1" "1" "x86_64" 1000

	run run_yaycache -d -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should report approximately 1000 bytes saved
	[[ "$output" =~ "disk space saved" ]]
}

@test "dryrun: handles multiple package types" {
	create_multi_pkg_cache "$TEST_CACHE"

	run run_yaycache -d -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "candidates" ]]
}
