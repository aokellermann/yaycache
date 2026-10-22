#!/usr/bin/env bats
# yaycache must never touch anything outside the cache directories it scans,
# whatever they hold: their contents come from AUR clones and builds and are
# not trusted. These tests pin the containment properties the 2026-10-21
# security review verified by reading the code, so a regression in any of
# them fails the suite instead of going unnoticed.

setup() {
	load ../common.bash
	load_bats_helpers
	require_sandbox

	YAY_CACHE="$HOME/.cache/yay"
	mkdir -p "$YAY_CACHE"

	# things outside the cache that every run must leave alone: a directory,
	# a file, an empty directory, and an entry in the directory yaycache is
	# started from
	OUTSIDE="$HOME/precious"
	mkdir -p "$OUTSIDE/dir" "$OUTSIDE/empty"
	: > "$OUTSIDE/dir/file"
	: > "$OUTSIDE/file"
	CWD="$BATS_TEST_TMPDIR/cwd"
	mkdir -p "$CWD/victim"
	: > "$CWD/victim/file"
	cd "$CWD"
}

assert_outside_intact() {
	[ -f "$OUTSIDE/dir/file" ]
	[ -f "$OUTSIDE/file" ]
	[ -d "$OUTSIDE/empty" ]
	[ -f "$CWD/victim/file" ]
}

# type + path of every entry under a directory, NUL-safe, for before/after
# comparisons
tree_listing() {
	find "$1" -mindepth 1 -printf '%y %p\0' | sort -z | tr '\0' '\n'
}

@test "containment: -r removes a package-named symlink as a link, its target untouched" {
	mkdir -p "$YAY_CACHE/foo"
	local v
	for v in 2 3 4; do create_mock_package "$YAY_CACHE/foo" foo "$v" 1; done
	ln -s "$OUTSIDE/dir" "$YAY_CACHE/foo/foo-1-1-x86_64.pkg.tar.zst"

	run run_yaycache -r
	[ "$status" -eq 0 ]
	[ ! -L "$YAY_CACHE/foo/foo-1-1-x86_64.pkg.tar.zst" ]
	[ "$(count_packages_nul "$YAY_CACHE/foo")" -eq 3 ]
	assert_outside_intact
}

@test "containment: -m moves a package-named symlink as a link, its target untouched" {
	mkdir -p "$YAY_CACHE/foo" "$BATS_TEST_TMPDIR/dest"
	local v
	for v in 2 3 4; do create_mock_package "$YAY_CACHE/foo" foo "$v" 1; done
	ln -s "$OUTSIDE/dir" "$YAY_CACHE/foo/foo-1-1-x86_64.pkg.tar.zst"

	run run_yaycache -m "$BATS_TEST_TMPDIR/dest"
	[ "$status" -eq 0 ]
	[ -L "$BATS_TEST_TMPDIR/dest/foo-1-1-x86_64.pkg.tar.zst" ]
	[ ! -e "$YAY_CACHE/foo/foo-1-1-x86_64.pkg.tar.zst" ]
	assert_outside_intact
}

@test "containment: --remove-build-files removes untracked symlinks as links, their targets untouched" {
	create_aur_pkg_dir "$YAY_CACHE/alpha" alpha 1.0
	ln -s "$OUTSIDE/dir" "$YAY_CACHE/alpha/src/dirlink"
	ln -s "$OUTSIDE/file" "$YAY_CACHE/alpha/src/filelink"
	ln -s "$OUTSIDE" "$YAY_CACHE/alpha/toplink"

	run run_yaycache -r -k0 --remove-build-files
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/alpha/src" ]
	[ ! -L "$YAY_CACHE/alpha/toplink" ]
	assert_outside_intact
}

@test "containment: pruning emptied build directories never follows a symlink" {
	create_aur_pkg_dir "$YAY_CACHE/alpha" alpha 1.0
	# tracked symlinks to an empty directory outside, at the top level and
	# inside a tracked subdirectory: neither is a build file, and the prune
	# must not reach through them
	mkdir -p "$YAY_CACHE/alpha/keep"
	ln -s "$OUTSIDE/empty" "$YAY_CACHE/alpha/emptylink"
	ln -s "$OUTSIDE/empty" "$YAY_CACHE/alpha/keep/emptylink"
	git -C "$YAY_CACHE/alpha" add emptylink keep/emptylink
	git -C "$YAY_CACHE/alpha" commit -q -m "links"

	run run_yaycache -r -k0 --remove-build-files
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/alpha/src" ]
	[ -L "$YAY_CACHE/alpha/emptylink" ]
	[ -L "$YAY_CACHE/alpha/keep/emptylink" ]
	assert_outside_intact
}

@test "containment: --remove-uninstalled-dirs removes a directory of symlinks without following them" {
	create_aur_pkg_dir "$YAY_CACHE/alpha" alpha 1.0
	ln -s "$OUTSIDE/dir" "$YAY_CACHE/alpha/dirlink"
	ln -s "$OUTSIDE/file" "$YAY_CACHE/alpha/filelink"
	ln -s "$OUTSIDE" "$YAY_CACHE/alpha/src/outside"

	PACMAN_SHIM_INSTALLED='beta' run run_yaycache -r -u --remove-uninstalled-dirs
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/alpha" ]
	assert_outside_intact
}

@test "containment: a cache directory that is itself a symlink is unlinked, not emptied" {
	ln -s "$OUTSIDE/dir" "$YAY_CACHE/alpha"

	PACMAN_SHIM_INSTALLED='beta' run run_yaycache -r -u --remove-uninstalled-dirs
	[ "$status" -eq 0 ]
	[ ! -L "$YAY_CACHE/alpha" ]
	assert_outside_intact
}

@test "containment: hostile .SRCINFO package names are never executed or used as paths" {
	create_aur_pkg_dir "$YAY_CACHE/alpha" alpha 1.0
	printf 'pkgbase = alpha\n\tpkgver = 1.0\n\npkgname = $(touch %s/pwned)\n\npkgname = `touch %s/pwned2`\n\npkgname = *\n\npkgname = ../../precious\n\npkgname = %s\n\npkgname = -rf\n' \
		"$HOME" "$HOME" "$OUTSIDE" > "$YAY_CACHE/alpha/.SRCINFO"

	# something else is installed, so `*` must not match it either
	PACMAN_SHIM_INSTALLED='beta' run run_yaycache -r -u --remove-uninstalled-dirs
	[ "$status" -eq 0 ]
	[ ! -e "$HOME/pwned" ]
	[ ! -e "$HOME/pwned2" ]
	[ ! -e "$YAY_CACHE/alpha" ]
	assert_outside_intact
}

@test "containment: a dry run modifies nothing, whatever the cache holds" {
	create_realistic_yay_cache "$YAY_CACHE"
	: > "$YAY_CACHE/alpha/foo-1-1-x86_64.pkg.tar.zst"$'\n'"victim"
	ln -s "$OUTSIDE/dir" "$YAY_CACHE/alpha/src/dirlink"
	local before
	before=$(tree_listing "$HOME")

	run run_yaycache -d -k0 -vv --remove-build-files
	[ "$status" -eq 0 ]
	PACMAN_SHIM_INSTALLED='beta' run run_yaycache -d -u --remove-uninstalled-dirs --remove-build-files
	[ "$status" -eq 0 ]
	[ "$before" == "$(tree_listing "$HOME")" ]
	assert_outside_intact
}

@test "containment: the --min-mtime pipeline handles hostile names" {
	mkdir -p "$YAY_CACHE/evil"
	local v
	for v in 1 2 3 4; do
		: > "$YAY_CACHE/evil/foo-$v-1-x86_64.pkg.tar.zst"$'\n'"victim"
	done
	touch -d '30 days ago' "$YAY_CACHE/evil/"*

	run run_yaycache -r -k1 --min-mtime '7 days ago'
	[ "$status" -eq 0 ]
	[ "$(count_packages_nul "$YAY_CACHE/evil")" -eq 1 ]
	assert_outside_intact
}

@test "containment: the --min-atime pipeline handles hostile names" {
	mkdir -p "$YAY_CACHE/evil"
	local v
	for v in 1 2 3 4; do
		: > "$YAY_CACHE/evil/foo-$v-1-x86_64.pkg.tar.zst"$'\n'"victim"
	done
	touch -a -d '30 days ago' "$YAY_CACHE/evil/"*

	run run_yaycache -r -k1 --min-atime '7 days ago'
	[ "$status" -eq 0 ]
	[ "$(count_packages_nul "$YAY_CACHE/evil")" -eq 1 ]
	assert_outside_intact
}

@test "containment: build files with option-like, glob and format-like names are removed, nothing else" {
	create_aur_pkg_dir "$YAY_CACHE/alpha" alpha 1.0
	local -a names=('-rf' '--help' '*' '%s%n' 'a b' '[x]' '~' '.hidden')
	local n
	for n in "${names[@]}"; do : > "$YAY_CACHE/alpha/$n"; done

	run run_yaycache -r -k0 --remove-build-files
	[ "$status" -eq 0 ]
	for n in "${names[@]}"; do [ ! -e "$YAY_CACHE/alpha/$n" ]; done
	[ -f "$YAY_CACHE/alpha/PKGBUILD" ]
	[ -f "$YAY_CACHE/alpha/.SRCINFO" ]
	assert_outside_intact
}

@test "containment: packages with spaces and glob characters in their names are handled as single files" {
	mkdir -p "$YAY_CACHE/odd"
	local v
	for v in 1 2; do
		create_mock_package "$YAY_CACHE/odd" 'a b' "$v" 1
		create_mock_package "$YAY_CACHE/odd" '[x]' "$v" 1
	done

	run run_yaycache -r -k1
	[ "$status" -eq 0 ]
	[ ! -e "$YAY_CACHE/odd/a b-1-1-x86_64.pkg.tar.zst" ]
	[ -f "$YAY_CACHE/odd/a b-2-1-x86_64.pkg.tar.zst" ]
	[ ! -e "$YAY_CACHE/odd/[x]-1-1-x86_64.pkg.tar.zst" ]
	[ -f "$YAY_CACHE/odd/[x]-2-1-x86_64.pkg.tar.zst" ]
	assert_outside_intact
}

@test "containment: a cache directory whose own name contains a newline is handled as one directory" {
	local dir="$YAY_CACHE/evil"$'\n'"victim"
	create_aur_pkg_dir "$dir" evil 1.0 1.1
	: > "$dir/junk"

	run run_yaycache -r -k1 --remove-build-files
	[ "$status" -eq 0 ]
	[ -f "$dir/evil-1.1-1-x86_64.pkg.tar.zst" ]
	[ ! -e "$dir/evil-1.0-1-x86_64.pkg.tar.zst" ]
	[ ! -e "$dir/junk" ]
	[ ! -e "$dir/src" ]
	[ -f "$dir/PKGBUILD" ]
	assert_outside_intact
}

@test "containment: --remove-build-files skips a directory that is not the top of a git clone" {
	# a cache directory that is not an AUR clone but lies inside a git
	# repository (here \$HOME is one): git ls-files --others would walk up to
	# that repository and report every file in it as untracked, PKGBUILD and
	# sources included
	git init -q "$HOME"
	mkdir -p "$YAY_CACHE/plain/src"
	printf 'pkgname=plain\n' > "$YAY_CACHE/plain/PKGBUILD"
	: > "$YAY_CACHE/plain/src/main.c"
	create_mock_package "$YAY_CACHE/plain" plain 1.0 1
	create_mock_package "$YAY_CACHE/plain" plain 1.1 1

	run run_yaycache -r -k1 --remove-build-files
	[ "$status" -eq 0 ]
	[[ "$output" =~ "not the top of a git clone" ]]
	[ -f "$YAY_CACHE/plain/PKGBUILD" ]
	[ -f "$YAY_CACHE/plain/src/main.c" ]
	[ "$(count_packages_nul "$YAY_CACHE/plain")" -eq 1 ]
	assert_outside_intact
}

@test "containment: a cache directory path holding printf directives and escapes is handled literally" {
	local dir="$YAY_CACHE/100%d-bs\\n"
	create_aur_pkg_dir "$dir" odd 1.0

	run run_yaycache -r -k0 --remove-build-files
	[ "$status" -eq 0 ]
	[ ! -e "$dir/src" ]
	[ ! -e "$dir/odd-1.0.tar.gz" ]
	[ -f "$dir/PKGBUILD" ]
	assert_outside_intact
}

@test "containment: --remove-build-files still works on a real clone inside an enclosing repository" {
	git init -q "$HOME"
	create_aur_pkg_dir "$YAY_CACHE/alpha" alpha 1.0

	run run_yaycache -r -k0 --remove-build-files
	[ "$status" -eq 0 ]
	[[ ! "$output" =~ "skipping" ]]
	[ ! -e "$YAY_CACHE/alpha/src" ]
	[ -f "$YAY_CACHE/alpha/PKGBUILD" ]
	assert_outside_intact
}

@test "containment: --remove-build-files still works on a clone reached through a symlinked path" {
	create_aur_pkg_dir "$YAY_CACHE/alpha" alpha 1.0
	ln -s "$YAY_CACHE" "$HOME/link"

	run run_yaycache -r -k0 --remove-build-files -c "$HOME/link/alpha/"
	[ "$status" -eq 0 ]
	[[ ! "$output" =~ "skipping" ]]
	[ ! -e "$YAY_CACHE/alpha/src" ]
	[ -f "$YAY_CACHE/alpha/PKGBUILD" ]
	assert_outside_intact
}

@test "containment: a directory named like a package is never removed recursively" {
	mkdir -p "$YAY_CACHE/foo"
	local v
	for v in 2 3 4; do create_mock_package "$YAY_CACHE/foo" foo "$v" 1; done
	mkdir -p "$YAY_CACHE/foo/foo-1-1-x86_64.pkg.tar.zst"
	: > "$YAY_CACHE/foo/foo-1-1-x86_64.pkg.tar.zst/file"

	# rm refuses it ("Is a directory") and the run reports the failure
	run run_yaycache -r
	[ "$status" -ne 0 ]
	[[ "$output" =~ "Is a directory" ]]
	[ -f "$YAY_CACHE/foo/foo-1-1-x86_64.pkg.tar.zst/file" ]
	assert_outside_intact
}
