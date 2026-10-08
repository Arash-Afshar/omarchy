#!/bin/bash
#
# A refresh that is still running when the caller exits must finish before the
# EXIT trap's sudo -k. Otherwise that refresh can write the timestamp record
# back after it was revoked.

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

script="$ROOT/bin/omarchy-sudo-keepalive"
test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
calls="$test_tmp/calls"
mkdir -p "$mock_bin"

# The refresh takes 0.3 s, like a slow sudo -n true.
cat >"$mock_bin/sudo" <<'SH'
#!/bin/bash

case ${1:-} in
-v | -k)
  printf '%s\n' "$1" >>"$TEST_CALLS"
  ;;
-n)
  printf 'refresh-start\n' >>"$TEST_CALLS"
  /bin/sleep 0.3
  printf 'refresh-done\n' >>"$TEST_CALLS"
  ;;
*)
  echo "unexpected sudo command: $*" >&2
  exit 90
  ;;
esac
SH
chmod +x "$mock_bin/sudo"

# The first refresh starts after one 0.1 s interval; the caller exits at 0.2 s,
# while that refresh is still running.
PATH="$mock_bin:$PATH" \
  TEST_CALLS="$calls" \
  OMARCHY_SUDO_KEEPALIVE_INTERVAL=0.1 \
  OMARCHY_SUDO_KEEPALIVE_MAX_REFRESHES=5 \
  bash -c '
    source "$1"
    /bin/sleep 0.2
  ' bash "$script"

# Let an orphaned refresh finish before reading the log.
/bin/sleep 0.5

[[ $(tail -n 1 "$calls") == "-k" ]] ||
  fail "sudo -k runs after any in-flight refresh" "$(cat "$calls")"
pass "sudo -k runs after any in-flight refresh"
