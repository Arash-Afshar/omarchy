#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

leaf="$ROOT/install/hardware/dell-xps13-ptl-speaker-firmware.sh"
migration="$ROOT/migrations/1790904845.sh"

grep -q 'run_logged .*hardware/dell-xps13-ptl-speaker-firmware.sh' "$ROOT/install/hardware/all.sh" ||
  fail "hardware setup installs the Panther Lake XPS 13 firmware"
pass "hardware setup installs the Panther Lake XPS 13 firmware"

require_command vercmp
require_command pacman
real_pacman=$(command -v pacman)
test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
mkdir -p "$test_tmp/bin"

firmware_target=$(grep -E '^(omarchy/)?linux-firmware-cirrus' "$ROOT/install/omarchy-other.packages")
mkdir -p "$test_tmp/db/local" "$test_tmp/db/sync" "$test_tmp/package"
cat >"$test_tmp/pacman.conf" <<'CONF'
[options]
Architecture = x86_64
SigLevel = Never
[core]
Server = https://example.invalid/core
[omarchy]
Server = https://example.invalid/omarchy
CONF

write_repo() {
  local repo="$1" version="$2"
  local entry="linux-firmware-cirrus-$version"
  mkdir -p "$test_tmp/package/$entry"
  cat >"$test_tmp/package/$entry/desc" <<DESC
%FILENAME%
linux-firmware-cirrus-$version-any.pkg.tar.zst

%NAME%
linux-firmware-cirrus

%VERSION%
$version

%ARCH%
any
DESC
  tar -czf "$test_tmp/db/sync/$repo.db" -C "$test_tmp/package" "$entry/desc"
}

resolve_firmware() {
  "$real_pacman" --config "$test_tmp/pacman.conf" --dbpath "$test_tmp/db" \
    -S --print --print-format '%r/%n %v' "$firmware_target"
}

write_repo omarchy "20260810-3"
write_repo core "20260810-2"
[[ $(resolve_firmware) == "omarchy/linux-firmware-cirrus 20260810-3" ]] ||
  fail "the offline package target selects Omarchy over older core firmware"
pass "the offline package target selects Omarchy over older core firmware"

write_repo core "20260910-2"
[[ $(resolve_firmware) == "core/linux-firmware-cirrus 20260910-2" ]] ||
  fail "the offline package target preserves newer Arch firmware"
pass "the offline package target preserves newer Arch firmware"

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
  [[ -s $TEST_VERSION_FILE ]] || exit 1
  printf 'linux-firmware-cirrus %s\n' "$(<"$TEST_VERSION_FILE")"
else
  printf 'pacman %s\n' "$*" >>"$TEST_LOG"
  [[ $* == "-S --noconfirm --needed omarchy/linux-firmware-cirrus" ]] || exit 1
  [[ ${TEST_INSTALL_FAILURE:-0} == "0" ]] || exit 1
  printf '20260810-3\n' >"$TEST_VERSION_FILE"
fi
SH
cat >"$test_tmp/bin/omarchy-state" <<'SH'
#!/bin/bash
printf 'state %s\n' "$*" >>"$TEST_LOG"
SH
chmod +x "$test_tmp/bin/"*

export PATH="$test_tmp/bin:$ROOT/bin:$PATH"
export OMARCHY_PATH="$ROOT" TEST_LOG="$test_tmp/calls" TEST_VERSION_FILE="$test_tmp/version"
export OMARCHY_XPS13_FIRMWARE_PENDING="$test_tmp/run/pending"
export TEST_PRODUCT_NAME="XPS 13 DX13260" TEST_INTEL_PTL=1
install_call="pacman -S --noconfirm --needed omarchy/linux-firmware-cirrus"

reset_fixture() {
  : >"$TEST_LOG"
  printf '%s' "$1" >"$TEST_VERSION_FILE"
  rm -f "$OMARCHY_XPS13_FIRMWARE_PENDING"
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
  [[ ! -s $TEST_LOG && ! -e $OMARCHY_XPS13_FIRMWARE_PENDING ]] || fail "other models receive no firmware repair"
done
reset_fixture "20260810-2"
TEST_INTEL_PTL=0 run_leaf
TEST_INTEL_PTL=0 run_migration
[[ ! -s $TEST_LOG && ! -e $OMARCHY_XPS13_FIRMWARE_PENDING ]] || fail "the Wildcat Lake variant receives no firmware repair"
pass "other models and the Wildcat Lake variant receive no firmware repair"

for version in "" "20260810-2"; do
  reset_fixture "$version"
  run_leaf || fail "missing or old firmware is installed during hardware setup"
  [[ $(<"$TEST_LOG") == "$install_call" && $(<"$TEST_VERSION_FILE") == "20260810-3" ]] ||
    fail "hardware setup explicitly selects the Omarchy firmware"
  [[ -e $OMARCHY_XPS13_FIRMWARE_PENDING ]] || fail "the firmware repair records its pending reboot"
done
pass "hardware setup explicitly installs the Omarchy firmware when missing or old"

for version in "20260810-3" "20260810-4" "20260910-2" "1:20260810-2"; do
  reset_fixture "$version"
  run_leaf
  run_migration
  [[ ! -s $TEST_LOG && ! -e $OMARCHY_XPS13_FIRMWARE_PENDING && $(<"$TEST_VERSION_FILE") == "$version" ]] ||
    fail "sufficient or newer firmware is preserved without a reboot request"
done
pass "sufficient or newer firmware is preserved without a reboot request"

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
rm -f "$OMARCHY_XPS13_FIRMWARE_PENDING"
run_migration
[[ ! -s $TEST_LOG ]] || fail "the migration is a no-op after reboot with repaired firmware"
pass "the migration is a no-op after reboot with repaired firmware"

reset_fixture "20260810-2"
if OMARCHY_XPS13_FIRMWARE_PENDING="$TEST_VERSION_FILE/not-a-directory" run_migration 2>/dev/null; then
  fail "failure to record the pending reboot fails the migration"
fi
[[ ! -s $TEST_LOG && $(<"$TEST_VERSION_FILE") == "20260810-2" ]] ||
  fail "failure to record the reboot marker installs nothing"
pass "failure to record the reboot marker installs nothing"
