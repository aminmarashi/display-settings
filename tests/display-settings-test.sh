#!/bin/bash

set -euo pipefail

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

MOCK_BIN="$TEST_ROOT/bin"
MOCK_LOG="$TEST_ROOT/calls.log"
PLUGIN_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BACKEND="$PLUGIN_ROOT/bin/display-settings"

mkdir -p "$MOCK_BIN" "$TEST_ROOT/home/.config/hypr"
printf '%s\n' '# original sunset config' >"$TEST_ROOT/home/.config/hypr/hyprsunset.conf"

cat >"$MOCK_BIN/hyprctl" <<'MOCK'
#!/bin/bash
set -euo pipefail
case "${1:-} ${2:-}" in
"monitors -j")
  cat <<'JSON'
[
  {
    "name":"DP-1","description":"External Display","make":"Example","model":"Panel",
    "width":2560,"height":1440,"x":0,"y":0,"scale":1,"transform":0,
    "physicalWidth":600,"physicalHeight":340,
    "refreshRate":60.0,"focused":true,"disabled":false,
    "availableModes":["2560x1440@60.00Hz","2560x1440@144.00Hz","1920x1080@60.00Hz"]
  },
  {
    "name":"eDP-1","description":"Built-in Display","make":"Example","model":"Laptop",
    "width":1920,"height":1200,"x":2560,"y":0,"scale":1.25,"transform":0,
    "physicalWidth":340,"physicalHeight":220,
    "refreshRate":60.0,"focused":false,"disabled":false,
    "availableModes":["1920x1200@60.00Hz"]
  }
]
JSON
  ;;
"eval "*) printf 'hyprctl %s\n' "$*" >>"$MOCK_LOG" ;;
"reload ") ;;
"configerrors ") ;;
*) exit 1 ;;
esac
MOCK

cat >"$MOCK_BIN/omarchy" <<'MOCK'
#!/bin/bash
set -euo pipefail
printf 'omarchy %s\n' "$*" >>"$MOCK_LOG"
if [[ ${1:-} == "toggle" && ${2:-} == "nightlight" ]]; then
  printf '%s\n' '{"enabled":false,"temperature":6500}'
elif [[ ${1:-} == "brightness" && ${2:-} == "display" && $# == 4 ]]; then
  printf '%s\n' '42'
fi
MOCK

cat >"$MOCK_BIN/omarchy-shell" <<'MOCK'
#!/bin/bash
printf 'omarchy-shell %s\n' "$*" >>"$MOCK_LOG"
MOCK

cat >"$MOCK_BIN/systemctl" <<'MOCK'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$MOCK_LOG"
MOCK

chmod +x "$MOCK_BIN"/*
export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$TEST_ROOT/home/.config"
export MOCK_LOG
export PATH="$MOCK_BIN:$PATH"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

state=$($BACKEND state)
jq -e '.displays | length == 2' <<<"$state" >/dev/null || fail "state did not expose active displays"
jq -e '.displays[0].physicalWidth == 600 and .displays[1].physicalHeight == 220' <<<"$state" >/dev/null || fail "state did not expose physical display sizes"
jq -e '.nightLight.schedule.enabled == false' <<<"$state" >/dev/null || fail "unexpected schedule state"

brightness=$($BACKEND brightness DP-1)
jq -e '.available == true and .value == 42' <<<"$brightness" >/dev/null || fail "brightness was not read"

$BACKEND brightness DP-1 65 >/dev/null
grep -Fq 'brightness display --no-osd --monitor DP-1 65%' "$MOCK_LOG" || fail "brightness was not applied"

cat >"$HOME/.config/hypr/monitors.lua" <<'LUA'
-- user monitor configuration
-- BEGIN amin.display-settings
legacy managed configuration
-- END amin.display-settings
LUA

$BACKEND scale DP-1 1.25
grep -Fq 'scale = 1.25' "$MOCK_LOG" || fail "scale was not applied"
grep -Fq -- '-- BEGIN omarchy-display' "$HOME/.config/hypr/monitors.lua" || fail "monitor config was not persisted"
grep -Fq -- '-- user monitor configuration' "$HOME/.config/hypr/monitors.lua" || fail "user monitor config was not preserved"
if grep -Fq -- '-- BEGIN amin.display-settings' "$HOME/.config/hypr/monitors.lua"; then
  fail "legacy monitor config marker was not migrated"
fi

$BACKEND mode DP-1 2560x1440@144.00Hz
grep -Fq 'mode = "2560x1440@144.00Hz"' "$MOCK_LOG" || fail "mode was not applied"

$BACKEND mode DP-1 1920x1080@60.00Hz
grep -Fq 'mode = "1920x1080@60.00Hz"' "$MOCK_LOG" || fail "resolution was not applied"

if $BACKEND mode DP-1 '2560x1440@999.00Hz' >/dev/null 2>&1; then
  fail "unsupported mode was accepted"
fi

evals_before_arrangement=$(awk '/^hyprctl eval/ { count++ } END { print count + 0 }' "$MOCK_LOG")
$BACKEND arrange '[{"name":"DP-1","x":1536,"y":0},{"name":"eDP-1","x":0,"y":240}]'
evals_after_arrangement=$(awk '/^hyprctl eval/ { count++ } END { print count + 0 }' "$MOCK_LOG")
grep -Fq 'position = "1536x0"' "$HOME/.config/hypr/monitors.lua" || fail "edge-touching display position was not applied"
[[ $evals_before_arrangement == "$evals_after_arrangement" ]] || fail "display arrangement was applied one monitor at a time"

calls_before_overlap=$(wc -l <"$MOCK_LOG")
if $BACKEND arrange '[{"name":"DP-1","x":0,"y":0},{"name":"eDP-1","x":0,"y":0}]' >/dev/null 2>&1; then
  fail "overlapping display arrangement was accepted"
fi
calls_after_overlap=$(wc -l <"$MOCK_LOG")
[[ $calls_before_overlap == "$calls_after_overlap" ]] || fail "overlapping arrangement was partially applied"

$BACKEND schedule on 21:00 07:00
grep -Fq '# Managed by omarchy-display' "$HOME/.config/hypr/hyprsunset.conf" || fail "schedule was not written"
jq -e '.nightLight.schedule.enabled == true' < <($BACKEND state) >/dev/null || fail "schedule state was not detected"

$BACKEND schedule off
grep -Fxq '# original sunset config' "$HOME/.config/hypr/hyprsunset.conf" || fail "sunset config was not restored"

$BACKEND nightlight on
grep -Fq 'omarchy-shell -q nightlight enable' "$MOCK_LOG" || fail "night light was not enabled"

if $BACKEND brightness 'DP-1;touch /tmp/nope' 50 >/dev/null 2>&1; then
  fail "unsafe monitor name was accepted"
fi

echo "Display Settings backend tests passed"
