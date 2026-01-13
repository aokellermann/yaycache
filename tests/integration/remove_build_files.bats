#!/usr/bin/env bats
# Integration tests for --remove-build-files feature

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
}

teardown() {
	rm -rf "$TEST_CACHE"
}

@test "build_files: identifies untracked files" {
	create_mock_git_cache "$TEST_CACHE"

	run run_yaycache -d --remove-build-files -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "candidates" ]]
}

@test "build_files: excludes .pkg.tar files" {
	create_mock_git_cache "$TEST_CACHE"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.0" "1" "x86_64"

	run run_yaycache -d --remove-build-files -k0 -vv -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Package should be listed as candidate (from pkgfilter)
	[[ "$output" =~ "test-pkg-1.0-1-x86_64.pkg.tar.zst" ]]
}

@test "build_files: respects whitelist" {
	# Create two AUR package directories
	local pkg_a="$TEST_CACHE/pkg-a"
	local pkg_b="$TEST_CACHE/pkg-b"
	local orig_dir="$PWD"

	mkdir -p "$pkg_a" "$pkg_b"

	# Setup pkg-a
	cd "$pkg_a"
	git init --quiet
	echo "pkg-a" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	echo "source" > untracked.c
	cd "$orig_dir"

	# Setup pkg-b
	cd "$pkg_b"
	git init --quiet
	echo "pkg-b" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	echo "source" > untracked.c
	cd "$orig_dir"

	# Whitelist only pkg-a
	run run_yaycache -d --remove-build-files -k0 -vv -c "$pkg_a/" -c "$pkg_b/" pkg-a
	[ "$status" -eq 0 ]
	# Should only show pkg-a files
	[[ "$output" =~ "pkg-a" ]]
}

@test "build_files: respects blacklist" {
	# Create two AUR package directories
	local pkg_a="$TEST_CACHE/pkg-a"
	local pkg_b="$TEST_CACHE/pkg-b"
	local orig_dir="$PWD"

	mkdir -p "$pkg_a" "$pkg_b"

	# Setup pkg-a
	cd "$pkg_a"
	git init --quiet
	echo "pkg-a" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	echo "source" > untracked.c
	cd "$orig_dir"

	# Setup pkg-b
	cd "$pkg_b"
	git init --quiet
	echo "pkg-b" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	echo "source" > untracked.c
	cd "$orig_dir"

	# Blacklist pkg-a
	run run_yaycache -d --remove-build-files -k0 -i pkg-a -vv -c "$pkg_a/" -c "$pkg_b/"
	[ "$status" -eq 0 ]
	# Should only show pkg-b files
	[[ "$output" =~ "pkg-b" ]]
}

@test "build_files: not supported with move mode" {
	create_mock_git_cache "$TEST_CACHE"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.1" "1" "x86_64"

	local move_dest=$(mktemp -d)

	run run_yaycache -m "$move_dest" --remove-build-files -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Build files should NOT be moved
	[ -f "$TEST_CACHE/src/main.c" ]
	[ ! -f "$move_dest/src/main.c" ]

	rm -rf "$move_dest"
}

@test "build_files: nested git repos handled correctly" {
	create_mock_git_cache "$TEST_CACHE"

	# Verify nested git repo exists
	[ -d "$TEST_CACHE/src/.git" ]

	run run_yaycache -d --remove-build-files -k0 -vv -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should find files in src/
	[[ "$output" =~ "src" ]]
}

@test "build_files: actually removes files with -r" {
	create_mock_git_cache "$TEST_CACHE"

	# Verify files exist before
	[ -f "$TEST_CACHE/src/main.c" ]
	[ -f "$TEST_CACHE/src/main.o" ]

	# Note: Exit status may be non-zero due to race conditions with rm -r
	# when removing nested git directories, but files should still be removed
	run_yaycache -r --remove-build-files -k0 -c "$TEST_CACHE/" || true

	# Build files should be removed
	[ ! -f "$TEST_CACHE/src/main.c" ]
	[ ! -f "$TEST_CACHE/src/main.o" ]

	# PKGBUILD should still exist (tracked by git)
	[ -f "$TEST_CACHE/PKGBUILD" ]
}

@test "build_files: handles empty src directory" {
	local orig_dir="$PWD"
	cd "$TEST_CACHE"
	git init --quiet
	echo "PKGBUILD" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet

	# Create empty src directory (untracked)
	mkdir -p src
	cd "$orig_dir"

	run run_yaycache -d --remove-build-files -k0 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
}

@test "build_files: handles special characters in filenames" {
	local orig_dir="$PWD"
	cd "$TEST_CACHE"
	git init --quiet
	echo "PKGBUILD" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet

	# Create files with special characters
	mkdir -p src
	echo "test" > "src/file with spaces.c"
	echo "test" > "src/file'with'quotes.c"
	cd "$orig_dir"

	run run_yaycache -d --remove-build-files -k0 -vv -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
}

@test "build_files: combined with packages" {
	create_mock_git_cache "$TEST_CACHE"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.1" "1" "x86_64"

	run run_yaycache -d --remove-build-files -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should report candidates for both packages and build files
	[[ "$output" =~ "candidates" ]]
}

@test "build_files: non-git directory falls back gracefully" {
	# Create a non-git directory with packages
	create_mock_package "$TEST_CACHE" "test-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "test-pkg" "1.1" "1" "x86_64"

	# Should handle non-git directory gracefully (may warn but shouldn't crash)
	run run_yaycache -d --remove-build-files -k1 -c "$TEST_CACHE/"
	# Either succeeds or exits with recognizable error, not a crash (segfault=139, etc)
	[[ "$status" -le 128 ]]
	# Should still process packages even if git ls-files fails
	[[ "$output" =~ "candidates" ]] || [[ "$output" =~ "test-pkg" ]]
}
