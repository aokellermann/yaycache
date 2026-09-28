#!/bin/bash
# Build the test image from the current working tree (tracked and untracked
# files, submodules included, minus anything gitignored) and run the whole
# suite in a throwaway container with no network and no capabilities.
#
# Usage: tests/docker/run.sh [--shell]
#   --shell   drop into an interactive shell instead of running the checks
set -euo pipefail

top=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
image=${YAYCACHE_TEST_IMAGE:-yaycache-test}
docker=${DOCKER:-docker}

command -v "$docker" >/dev/null || { echo "run.sh: $docker not found" >&2; exit 2; }

if [[ ! -x $top/tests/lib/bats-core/bin/bats ]]; then
	echo "run.sh: tests/lib submodules are missing; run 'git submodule update --init'" >&2
	exit 2
fi

ctx=$(mktemp -d "${TMPDIR:-/tmp}/yaycache-docker.XXXXXX")
trap 'rm -rf "$ctx"' EXIT
# tracked files (submodules included) plus untracked-but-not-ignored ones, so
# work in progress is tested too; build products stay out via .gitignore
(cd "$top" && { git ls-files --recurse-submodules -z; git ls-files --others --exclude-standard -z; } |
	tar --null --no-recursion -T - -cf -) | tar -C "$ctx" -xf -

"$docker" build -f "$top/tests/docker/Dockerfile" -t "$image" "$ctx"

run_args=(--rm --network none --cap-drop ALL --security-opt no-new-privileges --tmpfs /tmp:exec)
if [[ ${1:-} == --shell ]]; then
	exec "$docker" run "${run_args[@]}" -it "$image" bash
fi
exec "$docker" run "${run_args[@]}" "$image"
