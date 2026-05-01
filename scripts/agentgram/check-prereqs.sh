#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

VERSIONS_JSON="$ROOT_DIR/versions.json"
LOCAL_CONFIG="$ROOT_DIR/build-input/agentgram/development.local.json"

json_value() {
  python3 - "$1" "$VERSIONS_JSON" <<'PY'
import json
import sys

key = sys.argv[1]
path = sys.argv[2]

with open(path) as f:
    data = json.load(f)

value = data[key]
if isinstance(value, str) and ":" in value:
    value = value.split(":", 1)[0]
print(value)
PY
}

REQUIRED_XCODE="$(json_value xcode)"
REQUIRED_BAZEL="$(json_value bazel)"

printf 'Repo: %s\n' "$ROOT_DIR"
printf 'Required Xcode: %s\n' "$REQUIRED_XCODE"
printf 'Required Bazel: %s\n' "$REQUIRED_BAZEL"

if command -v xcode-select >/dev/null 2>&1; then
  ACTIVE_DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
  if [ -n "$ACTIVE_DEVELOPER_DIR" ]; then
    printf 'Active developer dir: %s\n' "$ACTIVE_DEVELOPER_DIR"
  else
    printf 'Active developer dir: unavailable\n'
  fi
else
  printf 'Active developer dir: xcode-select not found\n'
fi

if [ -d /Applications/Xcode.app ]; then
  printf 'Full Xcode app: present\n'
else
  printf 'Full Xcode app: missing (/Applications/Xcode.app not found)\n'
fi

if xcodebuild_output="$(xcodebuild -version 2>&1)"; then
  printf 'xcodebuild: available\n'
  printf '%s\n' "$xcodebuild_output"
else
  printf 'xcodebuild: unavailable\n'
  printf '%s\n' "$xcodebuild_output"
fi

for tool in python3 swift curl; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%s: %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '%s: missing\n' "$tool"
  fi
done

if git submodule status >/dev/null 2>&1; then
  if git submodule status | grep -q '^[+-]'; then
    printf 'Submodules: attention needed\n'
    git submodule status
  else
    printf 'Submodules: initialized\n'
  fi
else
  printf 'Submodules: unable to inspect\n'
fi

if [ -f "$LOCAL_CONFIG" ]; then
  printf 'Local Agentgram config: present (%s)\n' "$LOCAL_CONFIG"
else
  printf 'Local Agentgram config: missing (%s)\n' "$LOCAL_CONFIG"
fi

printf 'Recommended generation command:\n'
printf '%s\n' "python3 build-system/Make/Make.py --cacheDir=\"\$HOME/telegram-bazel-cache\" generateProject --configurationPath=build-input/agentgram/development.local.json --xcodeManagedCodesigning --disableProvisioningProfiles"
