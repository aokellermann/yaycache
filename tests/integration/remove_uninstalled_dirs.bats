#!/usr/bin/env bats
# --remove-uninstalled-dirs: with -u, the whole cache directory of a package
# that is no longer installed is a candidate instead of its individual files.
# pacman is the shim from tests/shims/ (PACMAN_SHIM_INSTALLED).

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox

	YAY_CACHE="$HOME/.cache/yay"
	create_realistic_yay_cache "$YAY_CACHE"
	# a split package: the directory name is not one of its pkgnames
	create_aur_pkg_dir "$YAY_CACHE/delta" delta 1.0
	printf 'pkgbase = delta\n\tpkgver = 1.0\n\npkgname = delta-cli\n\npkgname = delta-docs\n' > "$YAY_CACHE/delta/.SRCINFO"
	git -C "$YAY_CACHE/delta" commit -q -am "split"
}

@test "uninstalled_dirs: requires -u" {
	run yaycache -d -k1 --remove-uninstalled-dirs
	[ "$status" -eq 1 ]
	[[ "$output" =~ "requires -u" ]]
}

@test "uninstalled_dirs: dry run lists the directories of uninstalled packages only" {
	PACMAN_SHIM_INSTALLED=$'alpha\ndelta-docs' run list_candidates -u -k1 --remove-uninstalled-dirs --remove-build-files
	[ "$status" -eq 0 ]
	grep -qx "$YAY_CACHE/beta-git" <<<"$output"
	grep -qx "$YAY_CACHE/gamma" <<<"$output"
	# installed packages are not targeted by -u at all
	! grep -q "$YAY_CACHE/alpha" <<<"$output"
	! grep -qx "$YAY_CACHE/delta" <<<"$output"
	# nothing inside a directory candidate is listed on its own
	! grep -q "$YAY_CACHE/beta-git/" <<<"$output"
	! grep -q "$YAY_CACHE/gamma/" <<<"$output"
	# and nothing was touched
	[ -d "$YAY_CACHE/beta-git/.git" ]
}

@test "uninstalled_dirs: -r removes whole directories and prunes installed ones normally" {
	PACMAN_SHIM_INSTALLED=$'alpha\ndelta-docs' run yaycache -r -u -k1 --remove-uninstalled-dirs
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/beta-git" ]
	[ ! -e "$YAY_CACHE/gamma" ]
	[ -d "$YAY_CACHE/alpha/.git" ]
	[ -d "$YAY_CACHE/delta/.git" ]
	# installed packages are untouched, as always with -u
	[ "$(count_packages "$YAY_CACHE/alpha")" -eq 4 ]
}

@test "uninstalled_dirs: a split package directory is kept while any of its packages is installed" {
	PACMAN_SHIM_INSTALLED='delta-cli' run yaycache -r -u -k0 --remove-uninstalled-dirs
	[ "$status" -eq 0 ]
	[ -d "$YAY_CACHE/delta/.git" ]
	PACMAN_SHIM_INSTALLED='alpha' run yaycache -r -u -k0 --remove-uninstalled-dirs
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/delta" ]
}

@test "uninstalled_dirs: whitelist targets restrict which directories go" {
	PACMAN_SHIM_INSTALLED='alpha' run yaycache -r -u -k0 --remove-uninstalled-dirs gamma
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/gamma" ]
	[ -d "$YAY_CACHE/beta-git/.git" ]
	[ -d "$YAY_CACHE/delta/.git" ]
}

@test "uninstalled_dirs: -i protects a directory" {
	PACMAN_SHIM_INSTALLED='alpha' run yaycache -r -u -k0 --remove-uninstalled-dirs -i beta-git
	[ "$status" -eq 0 ]
	[ -d "$YAY_CACHE/beta-git/.git" ]
	[ ! -e "$YAY_CACHE/gamma" ]
}

@test "uninstalled_dirs: --min-mtime keeps directories with recent activity" {
	find "$YAY_CACHE/beta-git" -exec touch -d '2 years ago' {} +
	find "$YAY_CACHE/gamma" -exec touch -d '2 years ago' {} +
	touch "$YAY_CACHE/gamma/src/gamma-5.0/main.c"
	PACMAN_SHIM_INSTALLED='alpha' run yaycache -r -u -k0 --remove-uninstalled-dirs --min-mtime '1 year ago'
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/beta-git" ]
	[ -d "$YAY_CACHE/gamma/.git" ]
}

@test "uninstalled_dirs: -m moves the directory" {
	local dest="$HOME/moved"
	mkdir -p "$dest"
	PACMAN_SHIM_INSTALLED=$'alpha\nbeta-git\ndelta-cli' run yaycache -m "$dest" -u -k1 --remove-uninstalled-dirs
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/gamma" ]
	[ -f "$dest/gamma/PKGBUILD" ]
	[ -f "$dest/gamma/gamma-5.0-1-x86_64.pkg.tar.zst" ]
}

@test "uninstalled_dirs: reported size covers the directory contents" {
	PACMAN_SHIM_INSTALLED=$'alpha\nbeta-git\ndelta-cli' run yaycache -d -u -k1 --remove-uninstalled-dirs
	[ "$status" -eq 0 ]
	# gamma holds a 5 KiB package plus sources and .git: far more than the
	# 4 KiB a stat of the directory itself would report
	[[ "$output" =~ "disk space saved: "([0-9.]+)" "(KiB|MiB) ]]
	local n=${BASH_REMATCH[1]} unit=${BASH_REMATCH[2]}
	[[ $unit == MiB ]] || awk -v n="$n" 'BEGIN { exit !(n > 8) }'
}

@test "uninstalled_dirs: nothing uninstalled means no candidates" {
	PACMAN_SHIM_INSTALLED=$'alpha\nbeta-git\ngamma\ndelta-cli' run yaycache -r -u -k5 --remove-uninstalled-dirs
	[ "$status" -eq 0 ]
	[[ "$output" =~ "no candidate packages" ]]
	[ -d "$YAY_CACHE/gamma/.git" ]
}
