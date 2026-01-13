#!/usr/bin/env bats
# Unit tests for lib/size_to_human.sh
# Note: The function uses "size > 1024" (strict inequality), so boundary values
# like 1024 stay in the lower unit.

setup() {
	load ../common.bash
	load_bats_helpers

	# Source the size_to_human function
	source "$SRCDIR/lib/size_to_human.sh"
}

@test "size_to_human: 0 bytes" {
	run size_to_human 0
	[ "$status" -eq 0 ]
	[ "$output" = "0 B" ]
}

@test "size_to_human: small bytes (< 1024)" {
	run size_to_human 512
	[ "$status" -eq 0 ]
	[ "$output" = "512 B" ]
}

@test "size_to_human: 1 byte" {
	run size_to_human 1
	[ "$status" -eq 0 ]
	[ "$output" = "1 B" ]
}

@test "size_to_human: 1023 bytes (boundary)" {
	run size_to_human 1023
	[ "$status" -eq 0 ]
	[ "$output" = "1023 B" ]
}

@test "size_to_human: 1024 bytes stays in bytes" {
	# Function uses > 1024, not >= 1024, so 1024 stays as B
	run size_to_human 1024
	[ "$status" -eq 0 ]
	[ "$output" = "1024 B" ]
}

@test "size_to_human: 1025 bytes becomes KiB" {
	run size_to_human 1025
	[ "$status" -eq 0 ]
	[ "$output" = "1 KiB" ]
}

@test "size_to_human: 1.5 KiB" {
	run size_to_human 1536
	[ "$status" -eq 0 ]
	[ "$output" = "1.5 KiB" ]
}

@test "size_to_human: 10 KiB" {
	run size_to_human 10240
	[ "$status" -eq 0 ]
	[ "$output" = "10 KiB" ]
}

@test "size_to_human: 1048576 bytes stays in KiB" {
	# 1024^2 = 1048576, but since > 1024, it's "1024 KiB"
	run size_to_human 1048576
	[ "$status" -eq 0 ]
	[ "$output" = "1024 KiB" ]
}

@test "size_to_human: 1048577 bytes becomes MiB" {
	run size_to_human 1048577
	[ "$status" -eq 0 ]
	[ "$output" = "1 MiB" ]
}

@test "size_to_human: 1.5 MiB" {
	run size_to_human 1572864
	[ "$status" -eq 0 ]
	[ "$output" = "1.5 MiB" ]
}

@test "size_to_human: 2 GiB" {
	run size_to_human 2147483648
	[ "$status" -eq 0 ]
	[ "$output" = "2 GiB" ]
}

@test "size_to_human: fractional value ~1.2 MiB" {
	# 1258291 bytes = ~1.2 MiB
	run size_to_human 1258291
	[ "$status" -eq 0 ]
	# Should be approximately 1.2 MiB (1.2001... actually)
	[[ "$output" =~ ^1\.2.*MiB ]]
}

@test "size_to_human: removes trailing zeros (whole number)" {
	# 2 MiB = 2097152 bytes
	run size_to_human 2097152
	[ "$status" -eq 0 ]
	[ "$output" = "2 MiB" ]
}

@test "size_to_human: large value in TiB range" {
	# ~1.5 TiB
	run size_to_human 1649267441664
	[ "$status" -eq 0 ]
	[ "$output" = "1.5 TiB" ]
}

@test "size_to_human: large value in PiB range" {
	# ~2 PiB
	run size_to_human 2251799813685249
	[ "$status" -eq 0 ]
	[ "$output" = "2 PiB" ]
}
