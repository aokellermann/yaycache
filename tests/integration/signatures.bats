#!/usr/bin/env bats
# Detached signature files (*.pkg.tar*.sig) next to packages. Regression:
# they used to be parsed as package versions, which made the newest real
# package a removal candidate while its .sig survived.

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox

	TEST_CACHE="$TMPDIR/cache"
	mkdir -p "$TEST_CACHE"
	local v
	for v in 1.0 1.1 1.2; do
		create_mock_package "$TEST_CACHE" signed "$v" 1
		printf 'sig' > "$TEST_CACHE/signed-$v-1-x86_64.pkg.tar.zst.sig"
	done
}

@test "signatures: newest package is kept when signatures are present" {
	run yaycache -r -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	package_exists "$TEST_CACHE" signed 1.2 1
	[ -f "$TEST_CACHE/signed-1.2-1-x86_64.pkg.tar.zst.sig" ]
	! package_exists "$TEST_CACHE" signed 1.0 1
	! package_exists "$TEST_CACHE" signed 1.1 1
}

@test "signatures: a candidate's signature is removed with it" {
	run yaycache -r -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ ! -e "$TEST_CACHE/signed-1.0-1-x86_64.pkg.tar.zst.sig" ]
	[ ! -e "$TEST_CACHE/signed-1.1-1-x86_64.pkg.tar.zst.sig" ]
	[ "$(find "$TEST_CACHE" -type f | wc -l)" -eq 2 ]
}

@test "signatures: keep count applies to packages, not to package+sig pairs" {
	run yaycache -d -k2 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "2 candidates" ]]
	[ "$(list_candidates -k2 -c "$TEST_CACHE/" | wc -l)" -eq 2 ]
	list_candidates -k2 -c "$TEST_CACHE/" | grep -qx "$TEST_CACHE/signed-1.0-1-x86_64.pkg.tar.zst"
	list_candidates -k2 -c "$TEST_CACHE/" | grep -qx "$TEST_CACHE/signed-1.0-1-x86_64.pkg.tar.zst.sig"
}

@test "signatures: dry run lists the signature and counts its size" {
	run yaycache -d -v -k2 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ signed-1.0-1-x86_64.pkg.tar.zst.sig ]]
	# 1024-byte package + 3-byte signature = 1027 bytes, shown as "1 KiB";
	# without the signature it would be exactly 1024 bytes, shown as "1024 B"
	[[ "$output" =~ "disk space saved: 1 KiB" ]]
}

@test "signatures: move mode moves the signature along" {
	local dest="$TMPDIR/dest"
	mkdir -p "$dest"
	run yaycache -m "$dest" -k2 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ -f "$dest/signed-1.0-1-x86_64.pkg.tar.zst" ]
	[ -f "$dest/signed-1.0-1-x86_64.pkg.tar.zst.sig" ]
	[ -f "$TEST_CACHE/signed-1.1-1-x86_64.pkg.tar.zst.sig" ]
}

@test "signatures: orphaned signature without a package is left alone" {
	printf 'sig' > "$TEST_CACHE/orphan-9.9-1-x86_64.pkg.tar.zst.sig"
	run yaycache -r -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ -f "$TEST_CACHE/orphan-9.9-1-x86_64.pkg.tar.zst.sig" ]
	package_exists "$TEST_CACHE" signed 1.2 1
}

@test "signatures: --min-mtime path removes signatures of old candidates" {
	touch -d "60 days ago" "$TEST_CACHE"/signed-1.0-1-x86_64.pkg.tar.zst*
	run yaycache -r -k1 --min-mtime "30 days ago" -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	! package_exists "$TEST_CACHE" signed 1.0 1
	[ ! -e "$TEST_CACHE/signed-1.0-1-x86_64.pkg.tar.zst.sig" ]
	# 1.1 is a keep-count candidate but too recent
	package_exists "$TEST_CACHE" signed 1.1 1
	[ -f "$TEST_CACHE/signed-1.1-1-x86_64.pkg.tar.zst.sig" ]
	package_exists "$TEST_CACHE" signed 1.2 1
}

@test "signatures: packages without signatures are unaffected" {
	rm -f "$TEST_CACHE"/*.sig
	run yaycache -r -k1 -c "$TEST_CACHE/"
	[ "$status" -eq 0 ]
	[ "$(count_packages "$TEST_CACHE")" -eq 1 ]
	package_exists "$TEST_CACHE" signed 1.2 1
}
