#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

require_command jq

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

theme_source="$TMP/.local/state/omarchy/current/theme"
mkdir -p "$theme_source"
echo '{"name":"omarchy-system","vars":{},"colors":{}}' >"$theme_source/pi.json"

run() {
  env -u PI_CODING_AGENT_DIR HOME="$TMP" "$@"
}

# PI_CODING_AGENT_DIR moves Pi's whole agent tree.
moved="$TMP/elsewhere/pi"
mkdir -p "$moved"
run PI_CODING_AGENT_DIR="$moved" "$ROOT/bin/omarchy-theme-set-pi"
[[ -f $moved/themes/omarchy-system.json ]] || fail "theme sync follows PI_CODING_AGENT_DIR"
[[ ! -e $TMP/.pi ]] || fail "theme sync leaves the default directory alone when Pi moved" "$(find "$TMP/.pi")"
[[ ! -e $moved/settings.json ]] || fail "a plain sync does not touch Pi's settings"
pass "theme sync follows PI_CODING_AGENT_DIR"

run PI_CODING_AGENT_DIR="$moved" "$ROOT/bin/omarchy-theme-set-pi" --activate
jq -e '.theme == "omarchy-system"' "$moved/settings.json" >/dev/null || fail "activation writes the moved settings"
pass "activation writes settings under PI_CODING_AGENT_DIR"

run PI_CODING_AGENT_DIR="~/tilde/pi" "$ROOT/bin/omarchy-theme-set-pi" --activate
[[ -f $TMP/tilde/pi/themes/omarchy-system.json ]] || fail "a leading ~ in PI_CODING_AGENT_DIR is expanded"
[[ ! -e "~" ]] || fail "no literal ~ directory is created"
pass "a leading ~ in PI_CODING_AGENT_DIR is expanded as Pi does"

# The default location still works, and a missing Pi is left alone.
run "$ROOT/bin/omarchy-theme-set-pi"
[[ ! -e $TMP/.pi ]] || fail "a plain sync skips a machine without Pi"
run "$ROOT/bin/omarchy-theme-set-pi" --activate
jq -e '.theme == "omarchy-system"' "$TMP/.pi/agent/settings.json" >/dev/null || fail "default activation"
pass "default directory is used without PI_CODING_AGENT_DIR"

# A theme the user picked in Pi survives re-provisioning.
settings="$TMP/.pi/agent/settings.json"
echo '{"theme":"dark","model":"keep-me"}' >"$settings"
run "$ROOT/bin/omarchy-theme-set-pi" --activate
jq -e '.theme == "dark" and .model == "keep-me"' "$settings" >/dev/null || fail "a user-chosen theme is kept" "$(cat "$settings")"
pass "activation keeps a theme the user chose"

echo '{"model":"keep-me"}' >"$settings"
chmod 640 "$settings"
run "$ROOT/bin/omarchy-theme-set-pi" --activate
jq -e '.theme == "omarchy-system" and .model == "keep-me"' "$settings" >/dev/null || fail "an unset theme is filled in"
[[ $(stat -c %a "$settings") == 640 ]] || fail "settings keep their mode" "$(stat -c %a "$settings")"
pass "activation fills an unset theme, keeping other settings and the file mode"

# A settings file kept in a dotfiles checkout stays a symlink.
mkdir -p "$TMP/dotfiles"
echo '{"model":"linked"}' >"$TMP/dotfiles/pi-settings.json"
ln -sfn "$TMP/dotfiles/pi-settings.json" "$settings"
run "$ROOT/bin/omarchy-theme-set-pi" --activate
[[ -L $settings ]] || fail "a symlinked settings file stays a symlink"
jq -e '.theme == "omarchy-system" and .model == "linked"' "$TMP/dotfiles/pi-settings.json" >/dev/null || fail "the link target is updated"
pass "activation writes through a symlinked settings file"

# Settings that are not JSON are left as they were, with no stray temp file.
rm "$settings"
printf '{ // a comment\n  "model": "x",\n}\n' >"$settings"
before=$(cat "$settings")
if run "$ROOT/bin/omarchy-theme-set-pi" --activate 2>/dev/null; then
  fail "activation reports settings it cannot parse"
fi
[[ $(cat "$settings") == "$before" ]] || fail "unparseable settings are left unchanged"
compgen -G "$settings.*" >/dev/null && fail "no temp file is left beside the settings" "$(ls "$TMP/.pi/agent")"
pass "unparseable settings are reported and left unchanged"
