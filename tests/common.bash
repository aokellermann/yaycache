#!/bin/bash
# Common test utilities for yaycache tests

# Load the BATS helper libraries (bats-support, bats-assert, bats-file).
# They are vendored as git submodules under tests/lib/ and found via
# BATS_LIB_PATH (set by tests/sandbox.sh); fall back to a system install.
load_bats_helpers() {
	local lib
	for lib in bats-support bats-assert bats-file; do
		if [[ -n ${BATS_LIB_PATH:-} && -f $BATS_LIB_PATH/$lib/load.bash ]]; then
			load "$BATS_LIB_PATH/$lib/load.bash"
		elif [[ -f /usr/lib/$lib/load.bash ]]; then
			load "/usr/lib/$lib/load.bash"
		fi
	done
}

# Every test runs through tests/sandbox.sh, which provides a throwaway HOME,
# a private TMPDIR and shim sudo/pacman binaries. Refuse to run outside it:
# a stray `rm -r` against the developer's real ~/.cache/yay is exactly the
# outcome the sandbox exists to prevent.
require_sandbox() {
	if [[ ${YAYCACHE_SANDBOX:-0} != 1 ]]; then
		echo "refusing to run outside tests/sandbox.sh (see tests/README.md)" >&2
		return 1
	fi
	# One fresh HOME per test so fixtures never bleed between tests.
	export HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME"
	unset XDG_CACHE_HOME
	[[ -n $SUDO_SHIM_LOG ]] || SUDO_SHIM_LOG=$BATS_TEST_TMPDIR/sudo.log
	[[ -n $PACMAN_SHIM_LOG ]] || PACMAN_SHIM_LOG=$BATS_TEST_TMPDIR/pacman.log
	export SUDO_SHIM_LOG PACMAN_SHIM_LOG
}

# Skip the current test when running as root: writability checks (and thus
# the sudo escalation path) are meaningless for uid 0.
skip_if_root() {
	(( EUID == 0 )) && skip "requires an unprivileged user"
	return 0
}

# Create a mock package file with specified name and size
# Usage: create_mock_package <dir> <name> <version> <rel> [arch] [size]
create_mock_package() {
	local dir="$1"
	local name="$2"
	local version="$3"
	local rel="$4"
	local arch="${5:-x86_64}"
	local size="${6:-1024}"

	local filename="${name}-${version}-${rel}-${arch}.pkg.tar.zst"
	dd if=/dev/zero of="$dir/$filename" bs=1 count="$size" 2>/dev/null
}

# Create a mock cache directory with standard test packages
# Creates 5 versions of test-pkg
create_mock_cache() {
	local dir="$1"
	mkdir -p "$dir"

	# Create multiple versions of a test package (oldest to newest)
	create_mock_package "$dir" "test-pkg" "1.0" "1" "x86_64" 1024
	create_mock_package "$dir" "test-pkg" "1.1" "1" "x86_64" 2048
	create_mock_package "$dir" "test-pkg" "1.2" "1" "x86_64" 3072
	create_mock_package "$dir" "test-pkg" "2.0" "1" "x86_64" 4096
	create_mock_package "$dir" "test-pkg" "2.1" "1" "x86_64" 5120
}

# Create a mock cache with multiple packages
create_multi_pkg_cache() {
	local dir="$1"
	mkdir -p "$dir"

	# Package A - 3 versions
	create_mock_package "$dir" "pkg-a" "1.0" "1" "x86_64" 1024
	create_mock_package "$dir" "pkg-a" "1.1" "1" "x86_64" 2048
	create_mock_package "$dir" "pkg-a" "1.2" "1" "x86_64" 3072

	# Package B - 4 versions
	create_mock_package "$dir" "pkg-b" "0.1" "1" "x86_64" 512
	create_mock_package "$dir" "pkg-b" "0.2" "1" "x86_64" 1024
	create_mock_package "$dir" "pkg-b" "0.3" "1" "x86_64" 1536
	create_mock_package "$dir" "pkg-b" "0.4" "1" "x86_64" 2048

	# Package C - 2 versions
	create_mock_package "$dir" "pkg-c" "5.0" "1" "x86_64" 4096
	create_mock_package "$dir" "pkg-c" "5.1" "1" "x86_64" 5120
}

# Create a mock cache with packages of different architectures
create_multi_arch_cache() {
	local dir="$1"
	mkdir -p "$dir"

	# x86_64 packages
	create_mock_package "$dir" "multi-arch" "1.0" "1" "x86_64" 1024
	create_mock_package "$dir" "multi-arch" "1.1" "1" "x86_64" 2048
	create_mock_package "$dir" "multi-arch" "1.2" "1" "x86_64" 3072

	# any packages
	create_mock_package "$dir" "multi-arch" "1.0" "1" "any" 512
	create_mock_package "$dir" "multi-arch" "1.1" "1" "any" 1024
	create_mock_package "$dir" "multi-arch" "1.2" "1" "any" 1536
}

# Create a mock cache with git-tracked AUR package for --remove-build-files testing
create_mock_git_cache() {
	local dir="$1"
	local orig_dir="$PWD"
	mkdir -p "$dir"
	cd "$dir" || return 1

	# Initialize as git repo
	git init --quiet
	echo 'pkgname=test-pkg' > PKGBUILD
	echo 'pkgver=1.0' >> PKGBUILD
	git add PKGBUILD
	git config user.email "test@test.com"
	git config user.name "Test"
	git commit -m "Initial commit" --quiet

	# Create untracked build files
	mkdir -p src
	echo "source code" > src/main.c
	echo "object file" > src/main.o

	# Create nested git repo (common for AUR packages that clone source)
	cd src || { cd "$orig_dir" || return 1; return 1; }
	git init --quiet
	mkdir -p .git/refs/pull/1
	touch .git/refs/pull/1/head

	# Return to original directory
	cd "$orig_dir" || return 1
}

# Create multiple mock cache directories (simulates yay cache structure)
create_mock_yay_cache() {
	local base_dir="$1"
	local orig_dir="$PWD"
	mkdir -p "$base_dir"

	for pkg in pkg-a pkg-b pkg-c; do
		local pkg_dir="$base_dir/$pkg"
		mkdir -p "$pkg_dir"
		cd "$pkg_dir" || continue

		# Initialize git repo for this AUR package
		git init --quiet
		echo "pkgname=$pkg" > PKGBUILD
		git add PKGBUILD
		git config user.email "test@test.com"
		git config user.name "Test"
		git commit -m "Initial" --quiet

		# Create some built packages
		create_mock_package "$pkg_dir" "$pkg" "1.0" "1" "x86_64"
		create_mock_package "$pkg_dir" "$pkg" "1.1" "1" "x86_64"

		# Create some build artifacts (untracked files)
		mkdir -p src
		echo "source" > src/main.c

		cd "$orig_dir" || return 1
	done
}

# Count files matching pattern in directory
count_files() {
	local dir="$1"
	local pattern="$2"
	find "$dir" -name "$pattern" -type f 2>/dev/null | wc -l
}

# Count .pkg.tar* files in directory
count_packages() {
	local dir="$1"
	find "$dir" -name '*.pkg.tar*' -type f 2>/dev/null | wc -l
}

# Get list of package files in directory (sorted)
list_packages() {
	local dir="$1"
	find "$dir" -name '*.pkg.tar*' -type f 2>/dev/null | sort
}

# Check if a specific package file exists
package_exists() {
	local dir="$1"
	local name="$2"
	local version="$3"
	local rel="$4"
	local arch="${5:-x86_64}"

	local filename="${name}-${version}-${rel}-${arch}.pkg.tar.zst"
	[[ -f "$dir/$filename" ]]
}

# Get the yaycache binary path
get_yaycache() {
	if [[ -n "$YAYCACHE" && -x "$YAYCACHE" ]]; then
		echo "$YAYCACHE"
	elif [[ -n "$BUILDDIR" && -x "$BUILDDIR/src/yaycache" ]]; then
		echo "$BUILDDIR/src/yaycache"
	else
		echo "yaycache"
	fi
}

# Run yaycache with common test options
run_yaycache() {
	local yaycache
	yaycache=$(get_yaycache)
	"$yaycache" "$@"
}

# ---------------------------------------------------------------------------
# Realistic fixtures
# ---------------------------------------------------------------------------

# Create one AUR package directory the way yay leaves it after a build:
# a git clone of the AUR repo (PKGBUILD + .SRCINFO tracked and committed),
# built packages for each given version, and untracked build leftovers
# (a source tarball, src/ containing a nested upstream git clone, and pkg/).
#
# Usage: create_aur_pkg_dir <dir> <pkgname> <version>...
create_aur_pkg_dir() {
	local dir="$1" name="$2"; shift 2
	local ver
	mkdir -p "$dir"
	(
		cd "$dir" || exit 1
		git init --quiet
		printf 'pkgname=%s\npkgver=%s\npkgrel=1\n' "$name" "${!#}" > PKGBUILD
		printf 'pkgbase = %s\n\tpkgver = %s\n' "$name" "${!#}" > .SRCINFO
		git add PKGBUILD .SRCINFO
		git commit --quiet -m "Update to ${!#}"

		# untracked build leftovers
		printf 'tarball' > "$name-${!#}.tar.gz"
		mkdir -p "src/$name-${!#}" "pkg/$name/usr/bin"
		printf 'int main(){}' > "src/$name-${!#}/main.c"
		printf 'binary' > "pkg/$name/usr/bin/$name"
		(
			cd "src/$name-${!#}" || exit 1
			git init --quiet
			git add main.c
			git commit --quiet -m "upstream"
		)
	) || return 1
	for ver in "$@"; do
		create_mock_package "$dir" "$name" "$ver" 1 x86_64 $(( 1024 * ${#ver} ))
	done
}

# Create a full ~/.cache/yay-style tree with three AUR packages holding
# 4, 3 and 1 built versions respectively.
#
# Usage: create_realistic_yay_cache <yay-cache-dir>
create_realistic_yay_cache() {
	local base="$1"
	create_aur_pkg_dir "$base/alpha" alpha 1.0 1.1 1.2 2.0
	create_aur_pkg_dir "$base/beta-git" beta-git 0.1 0.2 0.3
	create_aur_pkg_dir "$base/gamma" gamma 5.0
}

# Print a sorted, stable listing of a directory tree: one "<type> <path>" line
# per entry, with the contents of any .git directory collapsed to the
# directory itself so git internals do not make comparisons noisy.
snapshot_tree() {
	local dir="$1"
	(cd "$dir" && find . -mindepth 1 -name .git -prune -printf 'd %P\n' -o -printf '%y %P\n' | sort)
}

# Assert a snapshot_tree listing equals the expected listing given on stdin.
# Usage: assert_tree <dir> <<EOF ... EOF
assert_tree() {
	local dir="$1" expected actual
	expected=$(sort)
	actual=$(snapshot_tree "$dir")
	if [[ $expected != "$actual" ]]; then
		echo "-- tree mismatch for $dir --"
		diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
		return 1
	fi
}

# Number of NUL bytes on stdin
count_nuls() {
	tr -cd '\0' | wc -c
}

# Print the full path of every candidate a dry run would select, one per
# line. The "N candidates" / "N files removed" figure in yaycache's summary is
# the number of cache *directories* with candidates, so tests count paths.
list_candidates() {
	yaycache -d -vv "$@" | grep '^/'
}
