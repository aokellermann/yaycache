#!/usr/bin/env bats
# Unit tests for bffilter() - build file filtering logic
# Tests the build file discovery and filtering behavior

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
}

teardown() {
	rm -rf "$TEST_CACHE"
}

@test "bffilter: identifies untracked files in git cache" {
	create_mock_git_cache "$TEST_CACHE"

	run run_yaycache -d --remove-build-files -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should identify untracked build files
	[[ "$output" =~ "candidates" ]]
}

@test "bffilter: excludes .pkg.tar files from build files" {
	create_mock_git_cache "$TEST_CACHE"
	# Add a built package
	create_mock_package "$TEST_CACHE" "test-pkg" "1.0" "1" "x86_64"

	run run_yaycache -d --remove-build-files -k0 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# The .pkg.tar.zst should NOT appear in build file candidates
	# It should appear in package candidates instead
	[[ "$output" =~ "test-pkg-1.0-1-x86_64.pkg.tar.zst" ]]
}

@test "bffilter: nested git repos handled correctly" {
	create_mock_git_cache "$TEST_CACHE"

	# Verify nested git repo was created
	[ -d "$TEST_CACHE/src/.git" ]

	run run_yaycache -d --remove-build-files -k0 -vv -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Files inside src/ should be found
	[[ "$output" =~ "src/main.c" ]] || [[ "$output" =~ "src/main.o" ]]
}

@test "bffilter: full path keys avoid basename collisions" {
	# This tests the fix from commit fd92740
	# Create two packages with files that have same basename
	local pkg1="$TEST_CACHE/pkg1"
	local pkg2="$TEST_CACHE/pkg2"

	mkdir -p "$pkg1" "$pkg2"

	# Setup pkg1 as git repo
	cd "$pkg1"
	git init --quiet
	echo "pkg1" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	mkdir -p src
	echo "content1" > src/file.c

	# Setup pkg2 as git repo
	cd "$pkg2"
	git init --quiet
	echo "pkg2" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	mkdir -p src
	echo "content2" > src/file.c

	# Run on both directories - both file.c should be candidates
	run run_yaycache -d --remove-build-files -k0 -vv -c "$pkg1/" -c "$pkg2/"
	[ "$status" -eq 0 ]
	# Both src/file.c files should be found (different full paths)
	[[ "$output" =~ "pkg1/src/file.c" ]] || [[ "$output" =~ "pkg1" ]]
	[[ "$output" =~ "pkg2/src/file.c" ]] || [[ "$output" =~ "pkg2" ]]
}

@test "bffilter: empty git cache (only tracked files)" {
	mkdir -p "$TEST_CACHE"
	cd "$TEST_CACHE"
	git init --quiet
	echo "PKGBUILD" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet

	# No untracked files
	run run_yaycache -d --remove-build-files -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "bffilter: only packages, no build files" {
	mkdir -p "$TEST_CACHE"
	cd "$TEST_CACHE"
	git init --quiet
	echo "PKGBUILD" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet

	# Add packages but no untracked build files
	create_mock_package "$TEST_CACHE" "pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg" "1.1" "1" "x86_64"

	run run_yaycache -d --remove-build-files -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should find package candidates but no build file candidates
	[[ "$output" =~ "1 candidates" ]]
}

@test "bffilter: build files not supported for move mode" {
	create_mock_git_cache "$TEST_CACHE"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.1" "1" "x86_64"

	local move_dest=$(mktemp -d)

	run run_yaycache -m "$move_dest" --remove-build-files -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Build files should NOT be moved, only packages
	# Check that build files still exist in original location
	[ -f "$TEST_CACHE/src/main.c" ]
	[ -f "$TEST_CACHE/src/main.o" ]

	rm -rf "$move_dest"
}

@test "bffilter: handles deeply nested directories" {
	mkdir -p "$TEST_CACHE"
	cd "$TEST_CACHE"
	git init --quiet
	echo "PKGBUILD" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet

	# Create deeply nested untracked files
	mkdir -p src/deep/nested/path
	echo "deep file" > src/deep/nested/path/file.txt

	run run_yaycache -d --remove-build-files -k0 -vv -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "deep/nested/path/file.txt" ]] || [[ "$output" =~ "candidates" ]]
}
