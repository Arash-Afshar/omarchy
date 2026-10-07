#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

leaf="$ROOT/install/hardware/dell-xps13-ptl-speaker-firmware.sh"
migration="$ROOT/migrations/1791265613.sh"

grep -q 'run_logged .*hardware/dell-xps13-ptl-speaker-firmware.sh' "$ROOT/install/hardware/all.sh" ||
  fail "hardware setup installs the Panther Lake XPS 13 firmware"
pass "hardware setup installs the Panther Lake XPS 13 firmware"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
mkdir -p "$test_tmp/bin"

cat >"$test_tmp/bin/omarchy-hw-match" <<'SH'
#!/bin/bash
[[ $TEST_PRODUCT_NAME == *"$1"* ]]
SH
cat >"$test_tmp/bin/omarchy-hw-intel-ptl" <<'SH'
#!/bin/bash
[[ $TEST_INTEL_PTL == "1" ]]
SH
cat >"$test_tmp/bin/sudo" <<'SH'
#!/bin/bash
exec "$@"
SH
cat >"$test_tmp/bin/pacman" <<'SH'
#!/bin/bash
if [[ $1 == "-Q" ]]; then
  if [[ ${@: -1} == "linux-firmware-cirrus-dx13260" ]]; then
    [[ -e $TEST_ALIAS_FILE ]] || exit 1
    printf 'linux-firmware-cirrus-dx13260 20260810-1\n'
  else
    [[ -s $TEST_VERSION_FILE ]] || exit 1
    printf 'linux-firmware-cirrus %s\n' "$(<"$TEST_VERSION_FILE")"
  fi
else
  printf 'pacman %s\n' "$*" >>"$TEST_LOG"
  [[ $* == "-S --noconfirm --needed -- linux-firmware-cirrus-dx13260" ]] || exit 1
  [[ ${TEST_INSTALL_FAILURE:-0} == "0" ]] || exit 1
  touch "$TEST_ALIAS_FILE"
fi
SH
cat >"$test_tmp/bin/omarchy-state" <<'SH'
#!/bin/bash
printf 'state %s\n' "$*" >>"$TEST_LOG"
SH
chmod +x "$test_tmp/bin/"*

test_path="$PATH"
export PATH="$test_tmp/bin:$ROOT/bin:$PATH"
export TEST_LOG="$test_tmp/calls" TEST_VERSION_FILE="$test_tmp/version" TEST_ALIAS_FILE="$test_tmp/alias-installed"
export TEST_PRODUCT_NAME="XPS 13 DX13260" TEST_INTEL_PTL=1
install_call="pacman -S --noconfirm --needed -- linux-firmware-cirrus-dx13260"
firmware_pending="$test_tmp/run/pending"

# Redirect the fixed filesystem path in isolated copies, not through production environment overrides.
export OMARCHY_PATH="$test_tmp/omarchy"
mkdir -p "$OMARCHY_PATH/install/hardware" "$OMARCHY_PATH/migrations"
printf -v marker_literal '%q' "$firmware_pending"
marker_replacement=$(printf '%s' "$marker_literal" | sed 's/[\\&|]/\\&/g')
sed "s|\"/run/omarchy/xps13-ptl-speaker-firmware\"|$marker_replacement|g" "$leaf" >"$OMARCHY_PATH/install/hardware/${leaf##*/}"
sed "s|\"/run/omarchy/xps13-ptl-speaker-firmware\"|$marker_replacement|g" "$migration" >"$OMARCHY_PATH/migrations/${migration##*/}"
leaf="$OMARCHY_PATH/install/hardware/${leaf##*/}"
migration="$OMARCHY_PATH/migrations/${migration##*/}"

reset_fixture() {
  : >"$TEST_LOG"
  printf '%s' "$1" >"$TEST_VERSION_FILE"
  rm -f "$firmware_pending" "$TEST_ALIAS_FILE"
}

run_leaf() {
  bash -eE -c 'source "$1"' bash "$leaf"
}

run_migration() {
  bash -euo pipefail "$migration" >/dev/null
}

for model in "XPS 9350" "XPS 13 DX13261"; do
  reset_fixture "20260810-2"
  TEST_PRODUCT_NAME="$model" run_leaf
  TEST_PRODUCT_NAME="$model" run_migration
  [[ ! -s $TEST_LOG && ! -e $firmware_pending ]] || fail "other models receive no firmware repair"
done
reset_fixture "20260810-2"
TEST_INTEL_PTL=0 run_leaf
TEST_INTEL_PTL=0 run_migration
[[ ! -s $TEST_LOG && ! -e $firmware_pending ]] || fail "the Wildcat Lake variant receives no firmware repair"
pass "other models and the Wildcat Lake variant receive no firmware repair"

for version in "" "20260810-2" "20260810-3" "20260810-4" "20260910-2" "20260916-1" "1:20260810-2"; do
  reset_fixture "$version"
  run_leaf || fail "the alias package is installed during hardware setup"
  [[ $(<"$TEST_LOG") == "$install_call" && $(<"$TEST_VERSION_FILE") == "$version" && -e $TEST_ALIAS_FILE ]] ||
    fail "hardware setup installs the separate aliases without replacing stock firmware"
  [[ ! -e $firmware_pending ]] || fail "hardware setup leaves reboot bookkeeping to the migration"
done
pass "hardware setup installs the package identity without replacing any stock firmware"
pass "hardware setup leaves reboot bookkeeping to the migration"

reset_fixture "20260810-2"
touch "$TEST_ALIAS_FILE"
run_leaf
run_migration
[[ ! -s $TEST_LOG && ! -e $firmware_pending ]] || fail "installed aliases are idempotent on stock firmware"
pass "installed aliases are idempotent on stock firmware"

reset_fixture "20260810-2"
if TEST_INSTALL_FAILURE=1 run_migration; then
  fail "a failed firmware installation fails the migration"
fi
[[ $(<"$TEST_LOG") == "$install_call" && $(<"$TEST_VERSION_FILE") == "20260810-2" ]] ||
  fail "a failed installation leaves the migration retryable without claiming success"
pass "a failed firmware installation fails the migration and remains retryable"

: >"$TEST_LOG"
run_migration
[[ $(<"$TEST_LOG") == "$install_call"$'\nstate set reboot-required' ]] ||
  fail "retrying the migration installs the firmware and requests a reboot"
pass "retrying the migration installs the firmware and requests a reboot"

: >"$TEST_LOG"
run_migration
[[ $(<"$TEST_LOG") == "state set reboot-required" ]] ||
  fail "a second user before reboot is prompted without reinstalling"
pass "a second user before reboot is prompted without reinstalling"

: >"$TEST_LOG"
rm -f "$firmware_pending"
run_migration
[[ ! -s $TEST_LOG ]] || fail "the migration is a no-op after reboot with repaired firmware"
pass "the migration is a no-op after reboot with repaired firmware"

reset_fixture "20260810-2"
rm -rf "$test_tmp/run"
touch "$test_tmp/run"
if run_migration 2>/dev/null; then
  fail "failure to record the pending reboot fails the migration"
fi
[[ ! -s $TEST_LOG && $(<"$TEST_VERSION_FILE") == "20260810-2" ]] ||
  fail "failure to record the reboot marker installs nothing"
pass "failure to record the reboot marker installs nothing"

rm -f "$test_tmp/run"
reset_fixture "20260810-2"
protected_file="$test_tmp/protected"
printf 'preserve me\n' >"$protected_file"
OMARCHY_XPS13_FIRMWARE_PENDING="$protected_file" run_migration
[[ $(<"$protected_file") == "preserve me" && -e $firmware_pending && $(<"$TEST_LOG") == "$install_call"$'\nstate set reboot-required' ]] ||
  fail "the invoking user's environment cannot redirect the privileged marker write"
pass "the invoking user's environment cannot redirect the privileged marker write"

if [[ ${TEST_FIRMWARE_SPECIAL_TMPDIR:-0} != "1" ]]; then
  special_tmpdir="$test_tmp/"'tmp &|"\$fixture'
  mkdir -p "$special_tmpdir"
  PATH="$test_path" TMPDIR="$special_tmpdir" TEST_FIRMWARE_SPECIAL_TMPDIR=1 \
    bash "$ROOT/test/shell.d/xps13-ptl-firmware-test.sh" >"$test_tmp/special-path.log" 2>&1 ||
    fail "firmware fixtures work with shell and sed metacharacters in TMPDIR" "$(<"$test_tmp/special-path.log")"
  pass "firmware fixtures work with shell and sed metacharacters in TMPDIR"
fi
