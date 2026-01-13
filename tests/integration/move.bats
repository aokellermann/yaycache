#!/usr/bin/env bats
# Integration tests for move mode (-m)

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
	TEST_DEST=$(mktemp -d)
	create_mock_cache "$TEST_CACHE"
}

teardown() {
	rm -rf "$TEST_CACHE" "$TEST_DEST"
}

@test "move: moves candidates to destination" {
	run run_yaycache -m "$TEST_DEST" -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Candidates should be in destination
	[ -f "$TEST_DEST/test-pkg-1.0-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_DEST/test-pkg-1.1-1-x86_64.pkg.tar.zst" ]

	# Candidates should NOT be in source
	[ ! -f "$TEST_CACHE/test-pkg-1.0-1-x86_64.pkg.tar.zst" ]
	[ ! -f "$TEST_CACHE/test-pkg-1.1-1-x86_64.pkg.tar.zst" ]

	# Kept packages should still be in source
	[ -f "$TEST_CACHE/test-pkg-1.2-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_CACHE/test-pkg-2.0-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_CACHE/test-pkg-2.1-1-x86_64.pkg.tar.zst" ]
}

@test "move: fails if destination doesn't exist" {
	run run_yaycache -m /nonexistent/dir -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "does not exist" ]]
}

@test "move: reports packages moved" {
	run run_yaycache -m "$TEST_DEST" -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "moved" ]]
}

@test "move: reports disk space" {
	run run_yaycache -m "$TEST_DEST" -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "disk space" ]]
}

@test "move: -k0 moves all" {
	run run_yaycache -m "$TEST_DEST" -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# All should be moved
	local src_count=$(count_packages "$TEST_CACHE")
	local dest_count=$(count_packages "$TEST_DEST")

	[ "$src_count" -eq 0 ]
	[ "$dest_count" -eq 5 ]
}

@test "move: -f forces move" {
	run run_yaycache -m "$TEST_DEST" -f -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
}

@test "move: verbose shows moved files" {
	run run_yaycache -m "$TEST_DEST" -v -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
}

@test "move: handles multiple packages" {
	create_multi_pkg_cache "$TEST_CACHE"

	run run_yaycache -m "$TEST_DEST" -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Check destination has moved packages
	[ -f "$TEST_DEST/test-pkg-1.0-1-x86_64.pkg.tar.zst" ]
	[ -f "$TEST_DEST/pkg-a-1.0-1-x86_64.pkg.tar.zst" ]
}

@test "move: build files not moved (ignored)" {
	# Clear cache and create git-tracked package
	rm -rf "$TEST_CACHE"
	mkdir -p "$TEST_CACHE"
	create_mock_git_cache "$TEST_CACHE"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.1" "1" "x86_64"

	run run_yaycache -m "$TEST_DEST" --remove-build-files -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Package should be moved
	[ -f "$TEST_DEST/test-pkg-1.0-1-x86_64.pkg.tar.zst" ]

	# Build files should NOT be moved (still in source)
	[ -f "$TEST_CACHE/src/main.c" ]
	[ -f "$TEST_CACHE/src/main.o" ]

	# Build files should NOT be in destination
	[ ! -f "$TEST_DEST/src/main.c" ]
	[ ! -f "$TEST_DEST/src/main.o" ]
}

@test "move: relative path converted to absolute" {
	# Test that relative paths work
	local orig_dir=$(pwd)
	cd "$TEST_CACHE"

	# Create relative destination
	local rel_dest="./moved_packages"
	mkdir -p "$rel_dest"

	run run_yaycache -m "$rel_dest" -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	cd "$orig_dir"
}

@test "move: no candidates shows message" {
	rm -f "$TEST_CACHE"/*.pkg.tar.*
	create_mock_package "$TEST_CACHE" "single" "1.0" "1" "x86_64"

	run run_yaycache -m "$TEST_DEST" -k3 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]

	# File should still be in source
	[ -f "$TEST_CACHE/single-1.0-1-x86_64.pkg.tar.zst" ]
}
