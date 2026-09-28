#!/bin/bash
# Runs inside the container (see Dockerfile): the suite against the build
# tree, then against an installed copy, then a full distcheck.
set -euo pipefail
cd /src

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

step "make check (build tree)"
make check || { cat tests/test-suite.log; exit 1; }

step "make install DESTDIR=/tmp/stage"
make install DESTDIR=/tmp/stage
test -x /tmp/stage/usr/bin/yaycache
test -f /tmp/stage/usr/lib/systemd/user/yaycache.service
test -f /tmp/stage/usr/lib/systemd/user/yaycache.timer
grep -q '^ExecStart=/usr/bin/yaycache -r$' /tmp/stage/usr/lib/systemd/user/yaycache.service

step "make check (installed copy)"
YAYCACHE=/tmp/stage/usr/bin/yaycache make check || { cat tests/test-suite.log; exit 1; }

step "make distcheck"
make distcheck

step "all container checks passed"
