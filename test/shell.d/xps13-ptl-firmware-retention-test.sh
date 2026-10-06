#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/base-test.sh"
require_command pacman
require_command pacman-conf
require_command vercmp
real_pacman=$(command -v pacman)
real_pacman_conf=$(command -v pacman-conf)
test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
mkdir -p "$test_tmp/bin" "$test_tmp/db/local" "$test_tmp/db/sync" "$test_tmp/package"
printf '9\n' >"$test_tmp/db/local/ALPM_DB_VERSION"

export RETENTION_REAL_PACMAN="$real_pacman" RETENTION_REAL_CONF="$real_pacman_conf"
export RETENTION_ROOT="$test_tmp" RETENTION_PTL=1
cat >"$test_tmp/bin/pacman" <<'STUB'
#!/bin/bash
query=0
for arg in "$@"; do
  [[ $arg != -Q* && $arg != -Sg* ]] || query=1
done
if (( query )); then
  if [[ ${RETENTION_SIMULATE_SUCCESS:-0} == 1 && -e $RETENTION_ROOT/transaction-success && $* == *-Q* ]]; then
    printf 'linux-firmware-cirrus 20260810-3\n'
    exit 0
  fi
  exec "$RETENTION_REAL_PACMAN" --config "$RETENTION_ROOT/pacman.conf" --dbpath "$RETENTION_ROOT/db" "$@"
fi
printf '%s\n' "$@" >"$RETENTION_ROOT/transaction-args"
[[ ${RETENTION_FAILURE:-0} == 0 ]] || exit "$RETENTION_FAILURE"
"$RETENTION_REAL_PACMAN" --config "$RETENTION_ROOT/pacman.conf" --dbpath "$RETENTION_ROOT/db" --print --print-format '%r/%n %v' "$@" || exit $?
touch "$RETENTION_ROOT/transaction-success"
STUB
cat >"$test_tmp/bin/omarchy-state" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$RETENTION_ROOT/state"
STUB
cat >"$test_tmp/bin/pacman-conf" <<'STUB'
#!/bin/bash
exec "$RETENTION_REAL_CONF" --config "$RETENTION_ROOT/pacman.conf" "$@"
STUB
cat >"$test_tmp/bin/omarchy-hw-dell-xps13-dx13260-ptl" <<'STUB'
#!/bin/bash
[[ $RETENTION_PTL == 1 ]]
STUB
cat >"$test_tmp/bin/sudo" <<'STUB'
#!/bin/bash
exec "$@"
STUB
cat >"$test_tmp/bin/systemd-run" <<'STUB'
#!/bin/bash
while [[ $1 == -* ]]; do shift; done
exec "$@"
STUB
chmod +x "$test_tmp/bin/"*

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

%GROUPS%
firmware
DESC
  tar -czf "$test_tmp/db/sync/$repo.db" -C "$test_tmp/package" "$entry/desc"
}
reset_fixture() {
  rm -f "$test_tmp/state" "$test_tmp/transaction-success"
  rm -rf "$test_tmp/db/local/"linux-firmware-cirrus-*
  if [[ -n $1 ]]; then
    mkdir -p "$test_tmp/db/local/linux-firmware-cirrus-$1"
    printf '%%NAME%%\nlinux-firmware-cirrus\n\n%%VERSION%%\n%s\n\n%%GROUPS%%\nfirmware\n' "$1" >"$test_tmp/db/local/linux-firmware-cirrus-$1/desc"
    : >"$test_tmp/db/local/linux-firmware-cirrus-$1/files"
  fi
  cat >"$test_tmp/pacman.conf" <<CONF
[options]
Architecture = x86_64
SigLevel = Never
[core]
Server = https://example.invalid/core
[omarchy]
Server = https://example.invalid/omarchy
CONF
  write_repo core 20260810-2
  write_repo omarchy 20260810-3
}
run_transaction() {
  local status=0
  PATH="$test_tmp/bin:$PATH" "$ROOT/bin/omarchy-update-pacman" "$@" >"$test_tmp/result" 2>"$test_tmp/errors" || status=$?
  (( status == 0 )) || cat "$test_tmp/errors" >&2
  return "$status"
}
expect_package() {
  [[ $(<"$test_tmp/result") == "$1" ]] || fail "$2" "$(<"$test_tmp/result") $(<"$test_tmp/errors")"
  pass "$2"
}

reset_fixture 20260810-3
run_transaction -Suu --noconfirm
expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "refresh selects the shim instead of downgrading to core"
run_transaction -Suu --needed --noconfirm
expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "an installed target is retained even when --needed was supplied"
run_transaction --sync --sysupgrade --sysupgrade --noconfirm
expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "long downgrade options retain the firmware minimum"
RETENTION_PTL=0 run_transaction -Suu --needed --noconfirm
expect_package 'core/linux-firmware-cirrus 20260810-2' "other hardware retains the original downgrade behavior"

for installed in '' 20260810-2; do
  reset_fixture "$installed"
  run_transaction -Su --noconfirm
  expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "normal update repairs missing or downgraded firmware independently of migrations"
  [[ ! -e $test_tmp/state ]] || fail "print-only transactions request no reboot"
done
reset_fixture 20260810-2
run_transaction -Su --needed --noconfirm
expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "normal update with --needed still repairs old firmware"
for installed in 20260810-3 20260910-2 1:20260810-2; do
  reset_fixture "$installed"
  run_transaction -Su --noconfirm
  expect_package '' "normal update preserves sufficient or newer local firmware without reinstalling"
  [[ ! -e $test_tmp/state ]] || fail "unchanged firmware requests no reboot"
done
reset_fixture 20260810-3
# --print omits IgnorePkg questions, so these cases verify the forwarded mask.
run_transaction -Suu --noconfirm --ignore 'linux-firmware-*'
expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "print resolution retains the minimum target with command-line exclusions"
[[ $(sed -n '/^--ask$/{n;p;}' "$test_tmp/transaction-args") == 1 ]] || fail "package exclusions use pacman's native question policy"
run_transaction -Suu --noconfirm --ignoregroup=firmware,other
expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "print resolution retains the minimum target with command-line group exclusions"
[[ $(sed -n '/^--ask$/{n;p;}' "$test_tmp/transaction-args") == 1 ]] || fail "group exclusions use pacman's native question policy"
reset_fixture 20260810-3
write_repo core 20260910-2
run_transaction -Suu --noconfirm
expect_package 'core/linux-firmware-cirrus 20260910-2' "refresh selects newer core firmware when available"

for ignored in 'IgnorePkg = linux-firmware-*' 'IgnoreGroup = firm*'; do
  for installed in 20260810-2 20260810-3; do
    reset_fixture "$installed"
    sed -i "/Architecture/a $ignored" "$test_tmp/pacman.conf"
    run_transaction -Suu --noconfirm
    expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "print resolution delegates configured exclusions to the native policy"
    [[ $(sed -n '/^--ask$/{n;p;}' "$test_tmp/transaction-args") == 1 ]] || fail "configured exclusions use pacman's native question policy"
    [[ ! -e $test_tmp/state ]] || fail "excluded firmware requests no reboot"
  done
done
reset_fixture 20260810-3
rm "$test_tmp/db/sync/omarchy.db"
sed -i '/\[omarchy\]/,$d' "$test_tmp/pacman.conf"
if run_transaction -Suu --noconfirm; then
  fail "unavailable firmware minimum fails the transaction"
fi
[[ ! -s $test_tmp/result ]] || fail "failed resolution schedules no downgrade"
pass "unavailable firmware minimum fails without scheduling a downgrade"
reset_fixture 20260810-2
status=0
RETENTION_FAILURE=23 run_transaction -Su --noconfirm || status=$?
[[ $status == 23 && ! -e $test_tmp/state ]] || fail "a failed firmware repair preserves its status and requests no reboot"
pass "a failed firmware repair preserves its status and requests no reboot"

reset_fixture 20260810-2
RETENTION_SIMULATE_SUCCESS=1 run_transaction -Su --noconfirm
[[ $(<"$test_tmp/state") == 'set reboot-required' ]] || fail "verified installed repair requests reboot without migrations"
pass "verified installed repair requests reboot without migrations"
for installed in 20260810-2 20260810-3; do
  reset_fixture "$installed"
  run_transaction -Su --needed --noconfirm linux-firmware-cirrus
  expected='omarchy/linux-firmware-cirrus 20260810-3'
  [[ $installed != 20260810-3 ]] || expected=''
  expect_package "$expected" "explicit bare targets cannot bypass the firmware minimum or create duplicates"
done
reset_fixture 20260810-3
run_transaction -Suu --noconfirm core/linux-firmware-cirrus
expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "repo-qualified bare targets cannot bypass refresh retention"
reset_fixture ''
sed -i '/Architecture/a IgnoreGroup = firm*' "$test_tmp/pacman.conf"
run_transaction -Suu --noconfirm
expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "missing firmware delegates sync-only group exclusions to the native policy"

reset_fixture 20260810-3
run_transaction -Suu --noconfirm --ask 4
[[ $(sed -n '/^--ask$/{n;p;}' "$test_tmp/transaction-args" | tail -1) == 5 ]] || fail "existing question bits are preserved"
pass "existing question bits are preserved"

reset_fixture 20260810-3
run_transaction -Suu --noconfirm -- linux-firmware-cirrus
expect_package 'omarchy/linux-firmware-cirrus 20260810-3' "the option separator remains valid with an explicit target"
reset_fixture 20260810-2
run_transaction -Su --noconfirm --confirm
[[ $(<"$test_tmp/transaction-args") != *'--ask'* ]] || fail "a final --confirm keeps the interactive question policy"
pass "a final --confirm keeps the interactive question policy"
run_transaction -Su --confirm --noconfirm
[[ $(sed -n '/^--ask$/{n;p;}' "$test_tmp/transaction-args") == 1 ]] || fail "a final --noconfirm keeps noninteractive exclusions"
pass "a final --noconfirm keeps noninteractive exclusions"
