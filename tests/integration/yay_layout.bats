#!/usr/bin/env bats
# End-to-end runs against a realistic ~/.cache/yay layout: several AUR
# package clones, each with tracked PKGBUILD/.SRCINFO, built packages, and
# untracked build leftovers including nested git clones and symlinks.

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox

	YAY_CACHE="$HOME/.cache/yay"
	create_realistic_yay_cache "$YAY_CACHE"
}

@test "layout: -r --remove-build-files leaves only the AUR clone and newest packages" {
	run yaycache -r -k1 --remove-build-files
	[ "$status" -eq 0 ]

	# Only the *files* git reported as untracked are removed; the now-empty
	# directory skeletons (src/, pkg/...) that contained them are left behind.
	assert_tree "$YAY_CACHE" <<-EOT
	d alpha
	d alpha/.git
	f alpha/.SRCINFO
	f alpha/PKGBUILD
	f alpha/alpha-2.0-1-x86_64.pkg.tar.zst
	d alpha/pkg
	d alpha/pkg/alpha
	d alpha/pkg/alpha/usr
	d alpha/pkg/alpha/usr/bin
	d alpha/src
	d beta-git
	d beta-git/.git
	f beta-git/.SRCINFO
	f beta-git/PKGBUILD
	f beta-git/beta-git-0.3-1-x86_64.pkg.tar.zst
	d beta-git/pkg
	d beta-git/pkg/beta-git
	d beta-git/pkg/beta-git/usr
	d beta-git/pkg/beta-git/usr/bin
	d beta-git/src
	d gamma
	d gamma/.git
	f gamma/.SRCINFO
	f gamma/PKGBUILD
	f gamma/gamma-5.0-1-x86_64.pkg.tar.zst
	d gamma/pkg
	d gamma/pkg/gamma
	d gamma/pkg/gamma/usr
	d gamma/pkg/gamma/usr/bin
	d gamma/src
	EOT

	# the AUR clones are still valid git repositories afterwards
	for d in alpha beta-git gamma; do
		git -C "$YAY_CACHE/$d" status --porcelain >/dev/null
		[[ "$(git -C "$YAY_CACHE/$d" status --porcelain)" == "?? $d-"*".pkg.tar.zst" ]]
	done
}

@test "layout: removal exits successfully" {
	# Regression: a nested git clone is listed by `git ls-files --others` as
	# a directory and `find -files0-from` then emitted both it and every file
	# beneath it, so `rm -r` failed with ENOENT on the children, xargs exited
	# 123 and yaycache aborted before its summary.
	run yaycache -r -k1 --remove-build-files
	[ "$status" -eq 0 ]
	! [[ "$output" =~ "cannot remove" ]]
	[[ "$output" =~ "files removed" ]]
}

@test "layout: -r --remove-build-files needs no -f to succeed on nested clones" {
	run yaycache -r -v -k0 --remove-build-files -c "$YAY_CACHE/beta-git/"
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/beta-git/src/beta-git-0.3" ]
	[ -f "$YAY_CACHE/beta-git/PKGBUILD" ]
}

@test "layout: dry run lists build files and packages but changes nothing" {
	local before after
	before=$(snapshot_tree "$YAY_CACHE")
	run yaycache -d -vv -k1 --remove-build-files
	[ "$status" -eq 0 ]
	[[ "$output" =~ "$YAY_CACHE/alpha/src/alpha-2.0/main.c" ]]
	[[ "$output" =~ "$YAY_CACHE/alpha/pkg/alpha/usr/bin/alpha" ]]
	[[ "$output" =~ "$YAY_CACHE/alpha/alpha-2.0.tar.gz" ]]
	[[ "$output" =~ "$YAY_CACHE/alpha/alpha-1.0-1-x86_64.pkg.tar.zst" ]]
	! [[ "$output" =~ PKGBUILD ]]
	! [[ "$output" =~ SRCINFO ]]
	after=$(snapshot_tree "$YAY_CACHE")
	[ "$before" == "$after" ]
}

@test "layout: a second run finds nothing" {
	run yaycache -r -k1 --remove-build-files
	[ "$status" -eq 0 ]
	run yaycache -r -k1 --remove-build-files
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate packages" ]]
}

@test "layout: untracked symlink to a directory outside the cache is not followed" {
	local outside="$HOME/outside"
	mkdir -p "$outside/keep"
	echo precious > "$outside/keep/file"
	ln -s "$outside" "$YAY_CACHE/alpha/src/escape"
	ln -s "$outside/keep/file" "$YAY_CACHE/alpha/escape-file"

	run yaycache -r -k1 --remove-build-files
	[ "$status" -eq 0 ]

	[ ! -L "$YAY_CACHE/alpha/src/escape" ]
	[ ! -L "$YAY_CACHE/alpha/escape-file" ]
	[ -f "$outside/keep/file" ]
	[ "$(cat "$outside/keep/file")" == precious ]
}

@test "layout: symlinked package file outside the cache: only the link is removed" {
	local outside="$HOME/outside"
	mkdir -p "$outside"
	create_mock_package "$outside" alpha 0.9 1
	ln -s "$outside/alpha-0.9-1-x86_64.pkg.tar.zst" "$YAY_CACHE/alpha/"
	run yaycache -r -k1 -c "$YAY_CACHE/alpha/"
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/alpha/alpha-0.9-1-x86_64.pkg.tar.zst" ]
	[ -f "$outside/alpha-0.9-1-x86_64.pkg.tar.zst" ]
}

@test "layout: cachedir given through a symlink" {
	ln -s "$YAY_CACHE" "$HOME/cache-link"
	run yaycache -r -k1 -c "$HOME/cache-link/alpha/"
	[ "$status" -eq 0 ]
	[ "$(count_packages "$YAY_CACHE/alpha")" -eq 1 ]
	package_exists "$YAY_CACHE/alpha" alpha 2.0 1
}

@test "layout: whitelist by AUR directory name selects that dir's build files" {
	run yaycache -d -vv -k0 --remove-build-files beta-git
	[ "$status" -eq 0 ]
	[[ "$output" =~ "$YAY_CACHE/beta-git/src/beta-git-0.3/main.c" ]]
	[[ "$output" =~ "$YAY_CACHE/beta-git/beta-git-0.1-1-x86_64.pkg.tar.zst" ]]
	! [[ "$output" =~ /alpha/ ]]
	! [[ "$output" =~ /gamma/ ]]
}

@test "layout: split package: whitelist matches dir name for build files but pkgname for packages" {
	# AUR dir "foo" building a package named "foo-bin"
	create_aur_pkg_dir "$YAY_CACHE/foo" foo-bin 1.0 2.0
	run yaycache -d -vv -k0 --remove-build-files foo
	[ "$status" -eq 0 ]
	[[ "$output" =~ "$YAY_CACHE/foo/src/foo-bin-2.0/main.c" ]]
	! [[ "$output" =~ foo-bin-1.0-1-x86_64 ]]

	run yaycache -d -vv -k0 --remove-build-files foo-bin
	[ "$status" -eq 0 ]
	[[ "$output" =~ foo-bin-1.0-1-x86_64 ]]
	! [[ "$output" =~ "$YAY_CACHE/foo/src/" ]]
}

@test "layout: -a restricts packages but not build files" {
	create_mock_package "$YAY_CACHE/alpha" alpha 1.0 1 any
	create_mock_package "$YAY_CACHE/alpha" alpha 1.1 1 any
	run yaycache -d -vv -k0 -a any --remove-build-files -c "$YAY_CACHE/alpha/"
	[ "$status" -eq 0 ]
	[[ "$output" =~ alpha-1.0-1-any ]]
	! [[ "$output" =~ alpha-1.0-1-x86_64 ]]
	[[ "$output" =~ "alpha/src/alpha-2.0/main.c" ]]
}

@test "layout: build files with spaces and quotes are removed" {
	local d="$YAY_CACHE/alpha/src"
	echo x > "$d/file with spaces.o"
	echo x > "$d/it's.o"
	run yaycache -r -k0 --remove-build-files -c "$YAY_CACHE/alpha/"
	[ "$status" -eq 0 ]
	[ ! -e "$d/file with spaces.o" ]
	[ ! -e "$d/it's.o" ]
	[ ! -e "$d/alpha-2.0" ]
}

@test "layout: -z emits NUL-delimited candidate paths" {
	local nuls
	nuls=$(yaycache -d -vv -z -k1 -c "$YAY_CACHE/alpha/" | count_nuls)
	[ "$nuls" -eq 3 ]
	nuls=$(yaycache -d -v -z -k1 -c "$YAY_CACHE/alpha/" | count_nuls)
	[ "$nuls" -eq 3 ]
}

@test "layout: move mode across several dirs keeps package contents intact" {
	local dest="$HOME/moved"
	mkdir -p "$dest"
	run yaycache -m "$dest" -k1
	[ "$status" -eq 0 ]
	[[ "$output" =~ "packages moved" ]]
	[ "$(count_packages "$dest")" -eq 5 ]
	# sizes encode the version string length in the fixture; check one
	[ "$(stat -c %s "$dest/alpha-1.0-1-x86_64.pkg.tar.zst")" -eq 3072 ]
	[ -d "$YAY_CACHE/alpha/src" ]
}

@test "layout: large cache (40 packages x 6 versions) keeps exactly the 2 newest of each" {
	local big="$TMPDIR/big"
	mkdir -p "$big"
	local i v
	for i in $(seq -w 1 40); do
		for v in 0 1 2 3 4 5; do
			create_mock_package "$big" "pkg$i" "1.$v" 1 x86_64 16
		done
	done
	[ "$(count_packages "$big")" -eq 240 ]
	run yaycache -r -k2 -c "$big/"
	[ "$status" -eq 0 ]
	[ "$(count_packages "$big")" -eq 80 ]
	[ "$(count_files "$big" '*-1.4-1-*')" -eq 40 ]
	[ "$(count_files "$big" '*-1.5-1-*')" -eq 40 ]
}

@test "layout: generated systemd units point at the installed script" {
	grep -qx 'ExecStart=.*/yaycache -r' "$BUILDDIR/src/yaycache.service"
	grep -qx 'OnCalendar=weekly' "$SRCDIR/src/yaycache.timer"
	grep -qx 'Persistent=true' "$SRCDIR/src/yaycache.timer"
}

@test "layout: prune_nested keeps siblings that merely share a name prefix" {
	# src/foo is a nested clone (listed as a directory); src/foo-bar/x.c is
	# a plain untracked file whose path starts with "src/foo" but is not
	# inside it. Only true descendants may be pruned.
	local d="$YAY_CACHE/gamma/src"
	mkdir -p "$d/foo" "$d/foo-bar"
	(cd "$d/foo" && git init --quiet && echo x > y.c && git add y.c && git commit --quiet -m x)
	echo x > "$d/foo-bar/x.c"
	run yaycache -r -k0 --remove-build-files -c "$YAY_CACHE/gamma/"
	[ "$status" -eq 0 ]
	[ ! -e "$d/foo" ]
	[ ! -e "$d/foo-bar/x.c" ]
	[ ! -e "$d/gamma-5.0" ]
}
