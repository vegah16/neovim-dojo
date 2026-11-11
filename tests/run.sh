#!/bin/sh
# Run the test suite headless with a private state directory.
#   tests/run.sh                  every test with `nvim`
#   NVIM_BIN=/path/nvim tests/run.sh tests/registry.lua
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
home=$(mktemp -d "${TMPDIR:-/tmp}/neovim-dojo-test.XXXXXX")
trap 'rm -rf -- "$home"' EXIT HUP INT TERM

guard=""
if command -v timeout >/dev/null 2>&1; then
  guard="timeout ${DOJO_TEST_TIMEOUT:-120}"
fi

cd "$root"
[ "$#" -gt 0 ] || set -- tests/registry.lua tests/session.lua tests/lifecycle.lua tests/registers.lua \
  tests/macros.lua tests/native.lua tests/projects.lua
for test_file in "$@"; do
  env XDG_CONFIG_HOME="$home/config" XDG_DATA_HOME="$home/data" XDG_STATE_HOME="$home/state" \
    XDG_CACHE_HOME="$home/cache" DOJO_TEST_FILE="$test_file" \
    $guard "${NVIM_BIN:-nvim}" --headless --clean -u tests/init.lua "+luafile tests/entry.lua" +qa!
  printf '\n'
done
printf 'ALL TESTS PASSED: %s\n' "$("${NVIM_BIN:-nvim}" --version | head -n 1)"
