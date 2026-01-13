#!/usr/bin/env bats
# Unit tests for pkgfilter() - package filtering logic
# Tests the package parsing regex and filtering behavior

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
}

teardown() {
	rm -rf "$TEST_CACHE"
}

@test "pkgfilter: parse standard package filename" {
	# Standard package: name-version-release-arch.pkg.tar.zst
	create_mock_package "$TEST_CACHE" "simple-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "simple-pkg" "1.1" "1" "x86_64"

	run run_yaycache -d -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "1 candidates" ]]
}

@test "pkgfilter: parse package with hyphens in name" {
	# Package with hyphens: my-complex-package-name-version-release-arch.pkg.tar.zst
	create_mock_package "$TEST_CACHE" "my-complex-package-name" "2.3.4" "5" "x86_64"
	create_mock_package "$TEST_CACHE" "my-complex-package-name" "2.3.5" "1" "x86_64"

	run run_yaycache -d -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should parse name correctly as "my-complex-package-name"
	[[ "$output" =~ "1 candidates" ]]
}

@test "pkgfilter: handles epoch in version" {
	# Package with epoch: pkg-1:2.0-1-x86_64.pkg.tar.zst
	# Note: yaycache doesn't have special epoch handling, version is treated as string
	create_mock_package "$TEST_CACHE" "epoch-pkg" "1:2.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "epoch-pkg" "1:2.1" "1" "x86_64"

	run run_yaycache -d -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "1 candidates" ]]
}

@test "pkgfilter: different compression formats" {
	# Test various compression suffixes
	local name="format-test"
	dd if=/dev/zero of="$TEST_CACHE/${name}-1.0-1-x86_64.pkg.tar.zst" bs=1 count=100 2>/dev/null
	dd if=/dev/zero of="$TEST_CACHE/${name}-1.1-1-x86_64.pkg.tar.xz" bs=1 count=100 2>/dev/null
	dd if=/dev/zero of="$TEST_CACHE/${name}-1.2-1-x86_64.pkg.tar.gz" bs=1 count=100 2>/dev/null

	run run_yaycache -d -k1 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should find 2 candidate files (keep 1, remove 2) - verify via verbose output
	[[ "$output" =~ "format-test-1.0" ]]
	[[ "$output" =~ "format-test-1.1" ]]
}

@test "pkgfilter: excludes signature files" {
	create_mock_package "$TEST_CACHE" "sig-test" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "sig-test" "1.1" "1" "x86_64"
	# Create signature files
	touch "$TEST_CACHE/sig-test-1.0-1-x86_64.pkg.tar.zst.sig"
	touch "$TEST_CACHE/sig-test-1.1-1-x86_64.pkg.tar.zst.sig"

	run run_yaycache -d -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Only the .pkg.tar.zst files should be considered, not .sig
	[[ "$output" =~ "1 candidates" ]]
}

@test "pkgfilter: multiple packages same name different arch" {
	# Create x86_64 versions
	create_mock_package "$TEST_CACHE" "dual-arch" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "dual-arch" "1.1" "1" "x86_64"
	# Create 'any' versions
	create_mock_package "$TEST_CACHE" "dual-arch" "1.0" "1" "any"
	create_mock_package "$TEST_CACHE" "dual-arch" "1.1" "1" "any"

	run run_yaycache -d -k1 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should keep 1 of each arch, so 2 candidate files total - verify via verbose
	[[ "$output" =~ "dual-arch-1.0-1-x86_64" ]]
	[[ "$output" =~ "dual-arch-1.0-1-any" ]]
}

@test "pkgfilter: arch filter x86_64 only" {
	create_mock_package "$TEST_CACHE" "arch-filter" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "arch-filter" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "arch-filter" "1.0" "1" "any"
	create_mock_package "$TEST_CACHE" "arch-filter" "1.1" "1" "any"

	# Filter to only scan x86_64
	run run_yaycache -d -k1 -a x86_64 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should only find 1 candidate (from x86_64), 'any' arch ignored
	[[ "$output" =~ "1 candidates" ]]
}

@test "pkgfilter: arch filter any only" {
	create_mock_package "$TEST_CACHE" "arch-filter" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "arch-filter" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "arch-filter" "1.0" "1" "any"
	create_mock_package "$TEST_CACHE" "arch-filter" "1.1" "1" "any"

	# Filter to only scan 'any'
	run run_yaycache -d -k1 -a any -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should only find 1 candidate (from any), x86_64 ignored
	[[ "$output" =~ "1 candidates" ]]
}

@test "pkgfilter: sorting is correct (oldest removed first)" {
	create_mock_package "$TEST_CACHE" "sort-test" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "sort-test" "2.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "sort-test" "10.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "sort-test" "10.1" "1" "x86_64"

	run run_yaycache -d -k2 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Oldest versions (1.0 and 2.0) should be candidates
	[[ "$output" =~ "sort-test-1.0" ]]
	[[ "$output" =~ "sort-test-2.0" ]]
}

@test "pkgfilter: numeric version sorting" {
	# Ensure 2.0 < 10.0 (not string sort where "10" < "2")
	create_mock_package "$TEST_CACHE" "numsort" "2.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "numsort" "10.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "numsort" "20.0" "1" "x86_64"

	run run_yaycache -d -k1 -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should keep 20.0, remove 2.0 and 10.0
	[[ "$output" =~ "numsort-2.0" ]]
	[[ "$output" =~ "numsort-10.0" ]]
}
