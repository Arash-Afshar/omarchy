#!/bin/bash

set -euo pipefail

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

# The developer's own pi tree is not the test home's.
unset PI_CODING_AGENT_DIR

mock_bin="$test_tmp/bin"
mkdir -p "$mock_bin" "$test_tmp/home" "$test_tmp/home/.hermes/profiles/james" \
  "$test_tmp/home/.pi/profiles/alice/agent" "$test_tmp/home/.omp/profiles/bob/agent"

for command in xdg-user-dirs-update xdg-settings xdg-mime; do
  printf '#!/bin/bash\nprintf "%%s %%s\\n" "${0##*/}" "$*" >>"$TEST_COMMAND_LOG"\n' >"$mock_bin/$command"
done
export TEST_COMMAND_LOG=$test_tmp/commands.log
chmod +x "$mock_bin"/*

# Provisioning prepends $OMARCHY_PATH/bin, which shadows a mock for anything
# Omarchy ships, so the install suite is stubbed out at its path instead. The
# real one rethemes the session it runs in: hyprctl reload against the live
# compositor, gsettings against the live desktop, and a global Node install.
mkdir -p "$test_tmp/install/user"
: >"$test_tmp/install/user/all.sh"

HOME="$test_tmp/home" PATH="$mock_bin:$ROOT/bin:$PATH" OMARCHY_PATH="$ROOT" \
  OMARCHY_INSTALL="$test_tmp/install" bash "$ROOT/bin/omarchy-provision-user" >/dev/null ||
  fail "omarchy-provision-user finishes"

for skill in omarchy diagnose-crash; do
  link="$test_tmp/home/.gemini/config/skills/$skill"
  [[ -L $link && $(readlink "$link") == "$ROOT/default/agents/skills/$skill" ]] ||
    fail "omarchy-provision-user provisions the $skill skill for Antigravity"

  link="$test_tmp/home/.hermes/skills/$skill"
  [[ -L $link && $(readlink "$link") == "$ROOT/default/agents/skills/$skill" ]] ||
    fail "omarchy-provision-user provisions the $skill skill for Hermes"

  link="$test_tmp/home/.hermes/profiles/james/skills/$skill"
  [[ -L $link && $(readlink "$link") == "$ROOT/default/agents/skills/$skill" ]] ||
    fail "omarchy-provision-user provisions the $skill skill for a Hermes profile"
done

pass "omarchy-provision-user provisions Antigravity and Hermes skills"

for dir in .pi/agent .omp/agent; do
  for skill in omarchy diagnose-crash; do
    link="$test_tmp/home/$dir/skills/$skill"
    [[ -L $link && $(readlink "$link") == "$ROOT/default/agents/skills/$skill" ]] ||
      fail "omarchy-provision-user provisions the $skill skill into $dir"
  done
  for profile in "$test_tmp/home/${dir%/agent}"/profiles/*/; do
    profile_skill="$profile/agent/skills/omarchy"
    [[ -L $profile_skill && $(readlink "$profile_skill") == "$ROOT/default/agents/skills/omarchy" ]] ||
      fail "omarchy-provision-user provisions skills into a ${dir%/agent} profile"
  done
done

pass "omarchy-provision-user provisions Pi and Oh My Pi skills, profile trees included"

# A pi tree that was moved before provisioning gets its skills there too, and
# a leading ~ expands against the provisioned home.
HOME="$test_tmp/home" PATH="$mock_bin:$ROOT/bin:$PATH" OMARCHY_PATH="$ROOT" \
  OMARCHY_INSTALL="$test_tmp/install" PI_CODING_AGENT_DIR="$test_tmp/home/moved-pi" \
  bash "$ROOT/bin/omarchy-provision-user" --force >/dev/null ||
  fail "omarchy-provision-user finishes with PI_CODING_AGENT_DIR set"
for skill in omarchy diagnose-crash; do
  link="$test_tmp/home/moved-pi/skills/$skill"
  [[ -L $link && $(readlink "$link") == "$ROOT/default/agents/skills/$skill" ]] ||
    fail "omarchy-provision-user provisions skills into PI_CODING_AGENT_DIR"
done
HOME="$test_tmp/home" PATH="$mock_bin:$ROOT/bin:$PATH" OMARCHY_PATH="$ROOT" \
  OMARCHY_INSTALL="$test_tmp/install" PI_CODING_AGENT_DIR="~/tilde-pi" \
  bash "$ROOT/bin/omarchy-provision-user" --force >/dev/null ||
  fail "omarchy-provision-user finishes with a ~ in PI_CODING_AGENT_DIR"
link="$test_tmp/home/tilde-pi/skills/omarchy"
[[ -L $link && $(readlink "$link") == "$ROOT/default/agents/skills/omarchy" ]] ||
  fail "omarchy-provision-user expands a leading ~ in PI_CODING_AGENT_DIR"

pass "omarchy-provision-user provisions skills where PI_CODING_AGENT_DIR moves the pi tree"

for dir in DOWNLOAD:Downloads PICTURES:Pictures VIDEOS:Videos DOCUMENTS:Documents MUSIC:Music; do
  grep -qxF "xdg-user-dirs-update --set ${dir%%:*} $test_tmp/home/${dir#*:}" "$TEST_COMMAND_LOG" ||
    fail "provisioning names the ${dir%%:*} folder in English" "$(cat "$TEST_COMMAND_LOG")"
done
for dir in Downloads Pictures Videos Documents Music; do
  [[ -d $test_tmp/home/$dir ]] || fail "provisioning creates the $dir folder it names"
done
pass "provisioning names the user folders in English before a first login in another language"

: >"$TEST_COMMAND_LOG"
mkdir -p "$test_tmp/home/.config"
printf 'XDG_DOWNLOAD_DIR="$HOME/下载"\n' >"$test_tmp/home/.config/user-dirs.dirs"
HOME="$test_tmp/home" PATH="$mock_bin:$ROOT/bin:$PATH" OMARCHY_PATH="$ROOT" \
  OMARCHY_INSTALL="$test_tmp/install" bash "$ROOT/bin/omarchy-provision-user" --force >/dev/null ||
  fail "omarchy-provision-user finishes again"
! grep -q -- '--set DOWNLOAD ' "$TEST_COMMAND_LOG" || fail "provisioning keeps a folder the user already named"
grep -q -- '--set PICTURES ' "$TEST_COMMAND_LOG" || fail "provisioning still names the folders the user has not"
pass "provisioning keeps a folder the user already named, in any language"
