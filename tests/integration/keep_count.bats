#!/usr/bin/env bats
# Integration tests for keep count logic (-k)

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
}

teardown() {
	rm -rf "$TEST_CACHE"
}

@test "keep: default is 3" {
	# Create 5 versions
	create_mock_cache "$TEST_CACHE"

	run run_yaycache -d -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# 5 versions - keep 3 = 2 candidate files, verify via verbose output
	[[ "$output" =~ "test-pkg-1.0" ]]
	[[ "$output" =~ "test-pkg-1.1" ]]
}

@test "keep: -k0 marks all as candidates" {
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.2" "1" "x86_64"

	run run_yaycache -d -k0 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# All 3 should be candidates
	[[ "$output" =~ "pkg-1.0" ]]
	[[ "$output" =~ "pkg-1.1" ]]
	[[ "$output" =~ "pkg-1.2" ]]
}

@test "keep: -k1 keeps newest only" {
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.2" "1" "x86_64"

	run run_yaycache -d -k1 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Oldest 2 should be candidates
	[[ "$output" =~ "pkg-1.0" ]]
	[[ "$output" =~ "pkg-1.1" ]]
}

@test "keep: -k2 keeps two newest" {
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.2" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.3" "1" "x86_64"

	run run_yaycache -d -k2 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Oldest 2 should be candidates
	[[ "$output" =~ "pkg-1.0" ]]
	[[ "$output" =~ "pkg-1.1" ]]
}

@test "keep: handles fewer packages than keep count" {
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.1" "1" "x86_64"

	# Keep 3 but only 2 exist
	run run_yaycache -d -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "keep: exactly matching keep count" {
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.2" "1" "x86_64"

	# Keep 3, have 3 -> 0 candidates
	run run_yaycache -d -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "keep: one more than keep count" {
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.2" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.3" "1" "x86_64"

	# Keep 3, have 4 -> 1 candidate
	run run_yaycache -d -k3 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "pkg-1.0" ]]
}

@test "keep: handles leading zeros in -k value" {
	create_mock_cache "$TEST_CACHE"

	run run_yaycache -d -k003 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should be treated as 3, so 2 candidate files
	[[ "$output" =~ "test-pkg-1.0" ]]
	[[ "$output" =~ "test-pkg-1.1" ]]
}

@test "keep: large keep value with few packages" {
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "x86_64"

	run run_yaycache -d -k100 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "keep: per-package keep count" {
	# Package A: 4 versions
	create_mock_package "$TEST_CACHE" "pkg-a" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.2" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.3" "1" "x86_64"

	# Package B: 2 versions
	create_mock_package "$TEST_CACHE" "pkg-b" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.1" "1" "x86_64"

	# Keep 2 of each
	run run_yaycache -d -k2 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# pkg-a: 4-2=2 candidates, pkg-b: 2-2=0 candidates
	[[ "$output" =~ "pkg-a-1.0" ]]
	[[ "$output" =~ "pkg-a-1.1" ]]
}

@test "keep: per-architecture keep count" {
	# Same package, different architectures
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.2" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "any"
	create_mock_package "$TEST_CACHE" "pkg" "1.1" "1" "any"
	create_mock_package "$TEST_CACHE" "pkg" "1.2" "1" "any"

	# Keep 2 of each (per arch)
	run run_yaycache -d -k2 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# x86_64: 3-2=1, any: 3-2=1, total: 2 candidate files
	[[ "$output" =~ "pkg-1.0-1-x86_64" ]]
	[[ "$output" =~ "pkg-1.0-1-any" ]]
}

@test "keep: single package no candidates" {
	create_mock_package "$TEST_CACHE" "single" "1.0" "1" "x86_64"

	run run_yaycache -d -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}
