#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.local/state/omarchy/current/theme" "$TMP/bin"
echo '{"name":"omarchy-system","colors":{}}' >"$TMP/.local/state/omarchy/current/theme/omp.json"

# A stand-in omp that records what it is asked to set.
cat >"$TMP/bin/omp" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$OMP_CALLS"
STUB
chmod +x "$TMP/bin/omp"
export OMP_CALLS="$TMP/omp-calls"

run() {
  env -u PI_CODING_AGENT_DIR -u OMP_PROFILE -u PI_PROFILE HOME="$TMP" PATH="$TMP/bin:$ROOT/bin:$PATH" "$@"
}

run "$ROOT/bin/omarchy-theme-set-omp"
[[ ! -e $TMP/.omp ]] || fail "a plain sync skips a machine without omp"
pass "a plain sync skips a machine without omp"

run "$ROOT/bin/omarchy-theme-set-omp" --activate
[[ -f $TMP/.omp/agent/themes/omarchy-system.json ]] || fail "the theme is synced into ~/.omp/agent"
grep -qx 'config set theme.dark omarchy-system' "$OMP_CALLS" || fail "the dark slot is activated through omp's CLI" "$(cat "$OMP_CALLS")"
grep -qx 'config set theme.light omarchy-system' "$OMP_CALLS" || fail "the light slot is activated through omp's CLI"
pass "activation syncs the theme and selects it through omp's own CLI"

: >"$OMP_CALLS"
run "$ROOT/bin/omarchy-theme-set-omp"
[[ ! -s $OMP_CALLS ]] || fail "a plain sync leaves omp's settings alone"
pass "a theme switch only rewrites the theme file"

mkdir -p "$TMP/moved"
run PI_CODING_AGENT_DIR="$TMP/moved" "$ROOT/bin/omarchy-theme-set-omp"
[[ -f $TMP/moved/themes/omarchy-system.json ]] || fail "PI_CODING_AGENT_DIR moves omp's themes"
run PI_CODING_AGENT_DIR="~/tilde" "$ROOT/bin/omarchy-theme-set-omp" --activate
[[ -f $TMP/tilde/themes/omarchy-system.json ]] || fail "a leading ~ in PI_CODING_AGENT_DIR is expanded"
pass "theme sync follows PI_CODING_AGENT_DIR"

run OMP_PROFILE=work PI_CODING_AGENT_DIR="$TMP/ignored" "$ROOT/bin/omarchy-theme-set-omp" --activate
[[ -f $TMP/.omp/profiles/work/agent/themes/omarchy-system.json ]] || fail "a named profile gets its own theme"
[[ ! -e $TMP/ignored ]] || fail "a named profile ignores PI_CODING_AGENT_DIR, as omp does"
run OMP_PROFILE= PI_PROFILE=other "$ROOT/bin/omarchy-theme-set-omp" --activate
[[ ! -e $TMP/.omp/profiles/other ]] || fail "an empty OMP_PROFILE selects the default profile over PI_PROFILE"
pass "theme sync follows omp's profile selection"

rm "$TMP/bin/omp"
: >"$OMP_CALLS"
run PATH="$ROOT/bin:/usr/bin:/bin" "$ROOT/bin/omarchy-theme-set-omp" --activate 2>/dev/null || fail "activation without omp still syncs"
[[ ! -s $OMP_CALLS ]] || fail "no omp is run when it is not installed"
pass "activation without omp installed syncs the file and stops there"
