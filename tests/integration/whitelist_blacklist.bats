#!/usr/bin/env bats
# Integration tests for whitelist and blacklist filtering

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
}

teardown() {
	rm -rf "$TEST_CACHE"
}

@test "blacklist: -i ignores specified package" {
	create_mock_package "$TEST_CACHE" "pkg-a" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.1" "1" "x86_64"

	# Ignore pkg-a
	run run_yaycache -d -k1 -i pkg-a -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Only pkg-b should have candidates
	[[ "$output" =~ "pkg-b" ]]
	[[ ! "$output" =~ "pkg-a-1" ]]
}

@test "blacklist: -i accepts comma-separated list" {
	create_mock_package "$TEST_CACHE" "pkg-a" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-c" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-c" "1.1" "1" "x86_64"

	# Ignore pkg-a and pkg-b
	run run_yaycache -d -k1 -i pkg-a,pkg-b -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Only pkg-c should have candidates
	[[ "$output" =~ "pkg-c" ]]
}

@test "blacklist: multiple -i options" {
	create_mock_package "$TEST_CACHE" "pkg-a" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-c" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-c" "1.1" "1" "x86_64"

	# Ignore pkg-a and pkg-b via separate -i
	run run_yaycache -d -k1 -i pkg-a -i pkg-b -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Only pkg-c should have candidates
	[[ "$output" =~ "pkg-c" ]]
}

@test "blacklist: -i - reads from stdin" {
	create_mock_package "$TEST_CACHE" "pkg-a" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.1" "1" "x86_64"

	# Read blacklist from stdin
	run bash -c "echo -e 'pkg-a' | $(get_yaycache) -d -k1 -i - -v -c '$TEST_CACHE/'"
	[ "$status" -eq 0 ]
	# Only pkg-b should have candidates
	[[ "$output" =~ "pkg-b" ]]
}

@test "whitelist: positional args as whitelist" {
	create_mock_package "$TEST_CACHE" "pkg-a" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.1" "1" "x86_64"

	# Whitelist only pkg-a
	run run_yaycache -d -k1 -v -c "$TEST_CACHE/" pkg-a
	[ "$status" -eq 0 ]
	# Only pkg-a should have candidates
	[[ "$output" =~ "pkg-a" ]]
	[[ ! "$output" =~ "pkg-b-1" ]]
}

@test "whitelist: multiple positional args" {
	create_mock_package "$TEST_CACHE" "pkg-a" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-b" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-c" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-c" "1.1" "1" "x86_64"

	# Whitelist pkg-a and pkg-b
	run run_yaycache -d -k1 -v -c "$TEST_CACHE/" pkg-a pkg-b
	[ "$status" -eq 0 ]
	# pkg-a and pkg-b should have candidates
	[[ "$output" =~ "pkg-a" ]]
	[[ "$output" =~ "pkg-b" ]]
}

@test "whitelist: non-existent package" {
	create_mock_package "$TEST_CACHE" "pkg-a" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.1" "1" "x86_64"

	# Whitelist non-existent package
	run run_yaycache -d -k1 -c "$TEST_CACHE/" nonexistent
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "blacklist: ignore all packages" {
	create_mock_package "$TEST_CACHE" "pkg-a" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "pkg-a" "1.1" "1" "x86_64"

	# Ignore the only package
	run run_yaycache -d -k1 -i pkg-a -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "whitelist: with build files" {
	local pkg_dir="$TEST_CACHE/pkg-a"
	local orig_dir="$PWD"
	mkdir -p "$pkg_dir"
	cd "$pkg_dir"
	git init --quiet
	echo "PKGBUILD" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	mkdir -p src
	echo "source" > src/main.c
	create_mock_package "$pkg_dir" "pkg-a" "1.0" "1" "x86_64"
	cd "$orig_dir"

	local pkg_dir2="$TEST_CACHE/pkg-b"
	mkdir -p "$pkg_dir2"
	cd "$pkg_dir2"
	git init --quiet
	echo "PKGBUILD" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	mkdir -p src
	echo "source" > src/main.c
	create_mock_package "$pkg_dir2" "pkg-b" "1.0" "1" "x86_64"
	cd "$orig_dir"

	# Whitelist only pkg-a with build files
	run run_yaycache -d -k0 --remove-build-files -c "$pkg_dir/" -c "$pkg_dir2/" pkg-a
	[ "$status" -eq 0 ]
	# Should only process pkg-a
}

@test "blacklist: with build files" {
	local pkg_dir="$TEST_CACHE/pkg-a"
	local orig_dir="$PWD"
	mkdir -p "$pkg_dir"
	cd "$pkg_dir"
	git init --quiet
	echo "PKGBUILD" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	mkdir -p src
	echo "source" > src/main.c
	create_mock_package "$pkg_dir" "pkg-a" "1.0" "1" "x86_64"
	cd "$orig_dir"

	local pkg_dir2="$TEST_CACHE/pkg-b"
	mkdir -p "$pkg_dir2"
	cd "$pkg_dir2"
	git init --quiet
	echo "PKGBUILD" > PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "init" --quiet
	mkdir -p src
	echo "source" > src/main.c
	create_mock_package "$pkg_dir2" "pkg-b" "1.0" "1" "x86_64"
	cd "$orig_dir"

	# Ignore pkg-a
	run run_yaycache -d -k0 --remove-build-files -i pkg-a -c "$pkg_dir/" -c "$pkg_dir2/"
	[ "$status" -eq 0 ]
	# Should only process pkg-b
}
