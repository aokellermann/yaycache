#!/usr/bin/env bats
# Integration tests for --min-atime and --min-mtime age-based filtering

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
}

teardown() {
	rm -rf "$TEST_CACHE"
}

@test "min_atime: filters by access time" {
	# Create packages
	create_mock_package "$TEST_CACHE" "atime-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "atime-pkg" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "atime-pkg" "1.2" "1" "x86_64"

	# Set old access time on older packages (30 days ago)
	touch -a -d "30 days ago" "$TEST_CACHE/atime-pkg-1.0-1-x86_64.pkg.tar.zst"
	touch -a -d "30 days ago" "$TEST_CACHE/atime-pkg-1.1-1-x86_64.pkg.tar.zst"
	# 1.2 keeps current atime

	# With min-atime=7 days ago, packages accessed within 7 days are kept
	# even if -k0 would otherwise remove them
	run run_yaycache -d -k0 --min-atime "7 days ago" -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Old packages (1.0, 1.1) should be candidates
	[[ "$output" =~ "atime-pkg-1.0" ]]
	[[ "$output" =~ "atime-pkg-1.1" ]]
}

@test "min_atime: keeps recently accessed packages" {
	create_mock_package "$TEST_CACHE" "atime-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "atime-pkg" "1.1" "1" "x86_64"

	# Set old atime on 1.0 only
	touch -a -d "30 days ago" "$TEST_CACHE/atime-pkg-1.0-1-x86_64.pkg.tar.zst"
	# 1.1 has current atime

	# With -k0 and min-atime, recently accessed should be kept
	run run_yaycache -d -k0 --min-atime "7 days ago" -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Only 1.0 should be candidate (old atime)
	[[ "$output" =~ "atime-pkg-1.0" ]]
	# 1.1 should NOT be candidate (recent atime)
	[[ ! "$output" =~ "atime-pkg-1.1" ]]
}

@test "min_mtime: filters by modification time" {
	# Create packages
	create_mock_package "$TEST_CACHE" "mtime-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "mtime-pkg" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "mtime-pkg" "1.2" "1" "x86_64"

	# Set old modification time on older packages
	touch -m -d "30 days ago" "$TEST_CACHE/mtime-pkg-1.0-1-x86_64.pkg.tar.zst"
	touch -m -d "30 days ago" "$TEST_CACHE/mtime-pkg-1.1-1-x86_64.pkg.tar.zst"

	# With min-mtime=7 days ago, old packages are candidates
	run run_yaycache -d -k0 --min-mtime "7 days ago" -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Old packages should be candidates
	[[ "$output" =~ "mtime-pkg-1.0" ]]
	[[ "$output" =~ "mtime-pkg-1.1" ]]
}

@test "min_mtime: keeps recently modified packages" {
	create_mock_package "$TEST_CACHE" "mtime-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "mtime-pkg" "1.1" "1" "x86_64"

	# Set old mtime on 1.0 only
	touch -m -d "30 days ago" "$TEST_CACHE/mtime-pkg-1.0-1-x86_64.pkg.tar.zst"

	run run_yaycache -d -k0 --min-mtime "7 days ago" -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Only 1.0 should be candidate
	[[ "$output" =~ "mtime-pkg-1.0" ]]
	# 1.1 should NOT be candidate (recent mtime)
	[[ ! "$output" =~ "mtime-pkg-1.1" ]]
}

@test "min_atime: combined with keep count" {
	create_mock_package "$TEST_CACHE" "combo-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "combo-pkg" "1.1" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "combo-pkg" "1.2" "1" "x86_64"

	# All have old atime
	touch -a -d "30 days ago" "$TEST_CACHE/combo-pkg-1.0-1-x86_64.pkg.tar.zst"
	touch -a -d "30 days ago" "$TEST_CACHE/combo-pkg-1.1-1-x86_64.pkg.tar.zst"
	touch -a -d "30 days ago" "$TEST_CACHE/combo-pkg-1.2-1-x86_64.pkg.tar.zst"

	# With -k1 and old atime, only keep newest
	run run_yaycache -d -k1 --min-atime "7 days ago" -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# 1.0 and 1.1 should be candidates
	[[ "$output" =~ "combo-pkg-1.0" ]]
	[[ "$output" =~ "combo-pkg-1.1" ]]
}

@test "min_atime: all recent means no candidates" {
	create_mock_package "$TEST_CACHE" "recent-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "recent-pkg" "1.1" "1" "x86_64"

	# All packages have recent atime (just created)
	# With -k0 but min-atime protection, nothing should be candidate
	run run_yaycache -d -k0 --min-atime "7 days ago" -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "min_mtime: all recent means no candidates" {
	create_mock_package "$TEST_CACHE" "recent-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "recent-pkg" "1.1" "1" "x86_64"

	# All packages have recent mtime (just created)
	run run_yaycache -d -k0 --min-mtime "7 days ago" -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate" ]]
}

@test "min_atime: accepts various time formats" {
	create_mock_package "$TEST_CACHE" "format-pkg" "1.0" "1" "x86_64"
	touch -a -d "30 days ago" "$TEST_CACHE/format-pkg-1.0-1-x86_64.pkg.tar.zst"

	# Test "N days ago" format
	run run_yaycache -d -k0 --min-atime "7 days ago" -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
}

@test "min_mtime: accepts various time formats" {
	create_mock_package "$TEST_CACHE" "format-pkg" "1.0" "1" "x86_64"
	touch -m -d "30 days ago" "$TEST_CACHE/format-pkg-1.0-1-x86_64.pkg.tar.zst"

	# Test "N days ago" format
	run run_yaycache -d -k0 --min-mtime "7 days ago" -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
}

@test "min_atime: with remove mode" {
	create_mock_package "$TEST_CACHE" "rm-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "rm-pkg" "1.1" "1" "x86_64"

	# Set old atime on 1.0
	touch -a -d "30 days ago" "$TEST_CACHE/rm-pkg-1.0-1-x86_64.pkg.tar.zst"

	run run_yaycache -r -k0 --min-atime "7 days ago" -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Old package should be removed
	[ ! -f "$TEST_CACHE/rm-pkg-1.0-1-x86_64.pkg.tar.zst" ]
	# Recent package should be kept
	[ -f "$TEST_CACHE/rm-pkg-1.1-1-x86_64.pkg.tar.zst" ]
}

@test "min_mtime: with remove mode" {
	create_mock_package "$TEST_CACHE" "rm-pkg" "1.0" "1" "x86_64"
	create_mock_package "$TEST_CACHE" "rm-pkg" "1.1" "1" "x86_64"

	# Set old mtime on 1.0
	touch -m -d "30 days ago" "$TEST_CACHE/rm-pkg-1.0-1-x86_64.pkg.tar.zst"

	run run_yaycache -r -k0 --min-mtime "7 days ago" -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]

	# Old package should be removed
	[ ! -f "$TEST_CACHE/rm-pkg-1.0-1-x86_64.pkg.tar.zst" ]
	# Recent package should be kept
	[ -f "$TEST_CACHE/rm-pkg-1.1-1-x86_64.pkg.tar.zst" ]
}
