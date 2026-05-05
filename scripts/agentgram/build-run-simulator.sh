#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

CONFIG_PATH="${CONFIG_PATH:-build-input/agentgram/development.local.json}"
CACHE_DIR="${CACHE_DIR:-$HOME/telegram-bazel-cache}"
BUILD_NUMBER="${BUILD_NUMBER:-10000}"
OUT_DIR="${OUT_DIR:-build-output}"
SIMULATOR_UDID="${SIMULATOR_UDID:-}"

if [ ! -f "$CONFIG_PATH" ]; then
  printf 'Missing local config: %s\n' "$CONFIG_PATH" >&2
  printf 'Create it with: scripts/agentgram/init-local-config.sh\n' >&2
  exit 1
fi

BAZEL_VERSION="$(python3 - <<'PY'
import json
with open('versions.json') as f:
    value = json.load(f)['bazel']
print(value.split(':', 1)[0])
PY
)"
BAZEL="build-input/bazel-${BAZEL_VERSION}-darwin-arm64"

if [ ! -x "$BAZEL" ]; then
  printf 'Bazel %s missing; generating project once to fetch toolchain...\n' "$BAZEL_VERSION"
  python3 build-system/Make/Make.py \
    --overrideXcodeVersion \
    --cacheDir="$CACHE_DIR" \
    generateProject \
    --configurationPath="$CONFIG_PATH" \
    --xcodeManagedCodesigning \
    --disableProvisioningProfiles
fi

mkdir -p "$OUT_DIR"

printf 'Building simulator IPA with Bazel...\n'
"$BAZEL" build Telegram/Telegram \
  --announce_rc \
  --features=swift.use_global_module_cache \
  --verbose_failures \
  --remote_cache_async \
  --define=buildNumber="$BUILD_NUMBER" \
  --disk_cache="$CACHE_DIR" \
  --//Telegram:disableExtensions \
  --//Telegram:disableProvisioningProfiles \
  -c dbg \
  --ios_multi_cpus=sim_arm64 \
  --watchos_cpus=arm64_32 \
  --@build_bazel_rules_swift//swift:copt='-j' \
  --@build_bazel_rules_swift//swift:copt='8'

INSTALL_DIR="$OUT_DIR/sim-install"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
ditto -x -k bazel-bin/Telegram/Telegram.ipa "$INSTALL_DIR"
APP_PATH="$INSTALL_DIR/Payload/Telegram.app"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"

if [ -z "$SIMULATOR_UDID" ]; then
  SIMULATOR_UDID="$(python3 - <<'PY'
import json, subprocess
raw = subprocess.check_output(['xcrun', 'simctl', 'list', '-j', 'devices', 'available'])
devices = []
for runtime_devices in json.loads(raw)['devices'].values():
    devices.extend(runtime_devices)
for preferred in ('iPhone 17', 'iPhone 17 Pro', 'iPhone 17 Pro Max'):
    for device in devices:
        if device.get('name') == preferred:
            print(device['udid'])
            raise SystemExit
for device in devices:
    if device.get('name', '').startswith('iPhone'):
        print(device['udid'])
        raise SystemExit
raise SystemExit('No available iPhone simulator found')
PY
)"
fi

printf 'Booting simulator: %s\n' "$SIMULATOR_UDID"
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_UDID" || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

printf 'Installing %s...\n' "$BUNDLE_ID"
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

printf 'Launching %s...\n' "$BUNDLE_ID"
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID"
