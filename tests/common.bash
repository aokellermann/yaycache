#!/bin/bash
# Common test utilities for yaycache tests

# Load BATS helpers if available
load_bats_helpers() {
	if [[ -f /usr/lib/bats-support/load.bash ]]; then
		load /usr/lib/bats-support/load.bash
		load /usr/lib/bats-assert/load.bash
		load /usr/lib/bats-file/load.bash
	fi
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
	cd src || { cd "$orig_dir"; return 1; }
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
