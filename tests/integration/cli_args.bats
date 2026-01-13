#!/usr/bin/env bats
# Integration tests for command-line argument parsing

setup() {
	load ../common.bash
	load_bats_helpers

	TEST_CACHE=$(mktemp -d)
	create_mock_cache "$TEST_CACHE"
}

teardown() {
	rm -rf "$TEST_CACHE"
}

@test "cli: --help shows usage" {
	run run_yaycache --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "Flexible yay cache cleaning utility" ]]
}

@test "cli: -h shows usage" {
	run run_yaycache -h
	[ "$status" -eq 0 ]
	[[ "$output" =~ "Flexible yay cache cleaning utility" ]]
}

@test "cli: --version shows version" {
	run run_yaycache --version
	[ "$status" -eq 0 ]
	[[ "$output" =~ "yaycache" ]]
}

@test "cli: -V shows version" {
	run run_yaycache -V
	[ "$status" -eq 0 ]
	[[ "$output" =~ "yaycache" ]]
}

@test "cli: no operation specified fails" {
	run run_yaycache -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "no operation specified" ]]
}

@test "cli: multiple operations fails (dryrun + remove)" {
	run run_yaycache -d -r -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "only one operation" ]]
}

@test "cli: multiple operations fails (dryrun + move)" {
	local move_dest=$(mktemp -d)
	run run_yaycache -d -m "$move_dest" -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "only one operation" ]]
	rm -rf "$move_dest"
}

@test "cli: multiple operations fails (remove + move)" {
	local move_dest=$(mktemp -d)
	run run_yaycache -r -m "$move_dest" -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "only one operation" ]]
	rm -rf "$move_dest"
}

@test "cli: -k with non-numeric fails" {
	run run_yaycache -d -k abc -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "must be a non-negative integer" ]]
}

@test "cli: -k with empty value fails" {
	run run_yaycache -d -k "" -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "must be a non-negative integer" ]]
}

@test "cli: -k with negative fails" {
	run run_yaycache -d -k -1 -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
}

@test "cli: -k with valid number succeeds" {
	run run_yaycache -d -k 2 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
}

@test "cli: -k with leading zeros succeeds" {
	run run_yaycache -d -k 003 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Should work and find candidates (default cache has 5 versions, keep 3)
	[[ "$output" =~ "candidates" ]]
}

@test "cli: invalid cachedir fails" {
	run run_yaycache -d -c /nonexistent/path/
	[ "$status" -ne 0 ]
	[[ "$output" =~ "does not exist" ]]
}

@test "cli: move destination doesn't exist fails" {
	run run_yaycache -m /nonexistent/destination -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "does not exist" ]]
}

@test "cli: --nocolor disables colors" {
	run run_yaycache -d --nocolor -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Output should not contain ANSI escape sequences
	[[ ! "$output" =~ $'\033' ]]
}

@test "cli: -q/--quiet minimizes output" {
	run run_yaycache -d -q -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Quiet mode should have minimal output
	[ -z "$output" ] || [[ ! "$output" =~ "finished" ]]
}

@test "cli: -v increases verbosity" {
	run run_yaycache -d -v -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "Candidate" ]]
}

@test "cli: -vv shows full paths" {
	run run_yaycache -d -vv -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "$TEST_CACHE" ]]
}

@test "cli: multiple -c options accepted" {
	local cache2=$(mktemp -d)
	create_mock_package "$cache2" "other-pkg" "1.0" "1" "x86_64"
	create_mock_package "$cache2" "other-pkg" "1.1" "1" "x86_64"

	run run_yaycache -d -k1 -c "$TEST_CACHE/" -c "$cache2/"
	[ "$status" -eq 0 ]
	# Should process both caches
	[[ "$output" =~ "candidates" ]]

	rm -rf "$cache2"
}

@test "cli: --min-atime with invalid date fails" {
	run run_yaycache -d --min-atime "invalid date format" -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "min-atime" ]]
}

@test "cli: --min-mtime with invalid date fails" {
	run run_yaycache -d --min-mtime "invalid date format" -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
	[[ "$output" =~ "min-mtime" ]]
}

@test "cli: --min-atime with valid date succeeds" {
	run run_yaycache -d --min-atime "30 days ago" -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
}

@test "cli: --min-mtime with valid date succeeds" {
	run run_yaycache -d --min-mtime "1 week ago" -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
}

@test "cli: -z/--null sets null delimiter" {
	run run_yaycache -d -v -z -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	# Note: null delimiter affects verbose output format
}

@test "cli: unknown option fails" {
	run run_yaycache -d --unknown-option -c "$TEST_CACHE/"
	[ "$status" -ne 0 ]
}
