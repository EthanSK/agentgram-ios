# Agentgram Bootstrap

This repository is a public fork of `TelegramMessenger/Telegram-iOS` with a thin project-specific bootstrap layer for Ethan's fork, `Agentgram`.

The goal of this document is to get a local developer machine from "fresh clone" to "Telegram login screen opens in the iOS Simulator" without committing secrets or diverging far from upstream.

## Current machine blockers

Observed in `/Users/ethansk/Projects/agentgram-ios` on 2026-05-02:

- Full Xcode is not installed. `/Applications/Xcode.app` is absent.
- `xcodebuild -version` fails because the active developer directory is `/Library/Developer/CommandLineTools`, not full Xcode.
- The Telegram build system requires Xcode `26.4` according to [`versions.json`](../versions.json).
- App Store installation via `mas install 497799835` was not possible from this session because admin authentication was unavailable.
- Git submodules are initialized and the worktree was clean when this bootstrap layer was added.

Because of those blockers, project generation, Xcode build, simulator launch, and Telegram sign-in could not be verified on this machine yet.

## Telegram constraints

Telegram's upstream README requires the following for forks and third-party clients:

- Do not ship the app as `Telegram` without making it clearly unofficial.
- Do not use the standard Telegram logo.
- Publish your source code to comply with the licenses.
- Protect user privacy and follow Telegram security guidance.
- Obtain your own `api_id` and `api_hash` for this app.

For Agentgram, that means:

- Use `Agentgram` or another clearly unofficial product name in user-facing branding.
- Replace Telegram branding assets before App Store distribution.
- Do not commit Telegram API credentials, Apple credentials, phone numbers, or login codes.

## One-time local setup

### 1. Install full Xcode

Install the full Xcode app, not just Command Line Tools.

Options:

- App Store: install Xcode manually.
- Apple Developer downloads: install the current full release that matches [`versions.json`](../versions.json), currently `26.4`.

After installation:

```bash
open /Applications/Xcode.app
```

Then complete the first-launch prompts so Xcode installs its bundled components.

If Terminal still points at Command Line Tools afterwards, switch the active developer directory:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

If you do not have admin access, use a per-shell override instead:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Verify:

```bash
xcodebuild -version
xcode-select -p
```

Expected outcome:

- `xcodebuild -version` succeeds.
- The selected developer directory resolves inside `/Applications/Xcode.app/...`.
- Xcode version matches `26.4`, or you consciously use `--overrideXcodeVersion`.

### 2. Prepare a local Telegram development config

Create a local-only config file from the upstream template:

```bash
./scripts/agentgram/init-local-config.sh
```

Default output:

```text
build-input/agentgram/development.local.json
```

That path is already ignored by the repository's existing `build-input/*` rule in [`.gitignore`](../.gitignore).

Now edit the generated file and fill in these fields:

- `bundle_id`: a unique bundle identifier for this fork, for example `com.ethansk.agentgram`
- `api_id`: your Telegram application ID from `https://my.telegram.org/apps`
- `api_hash`: your Telegram application hash from `https://my.telegram.org/apps`
- `team_id`: your Apple Developer Team ID

This is the exact place where `api_id` and `api_hash` belong for local development:

```text
build-input/agentgram/development.local.json
```

Do not put real credentials in tracked files under `build-system/`.

### 3. Generate the Xcode project

Recommended path for this repo:

```bash
python3 build-system/Make/Make.py \
  --cacheDir="$HOME/telegram-bazel-cache" \
  generateProject \
  --configurationPath=build-input/agentgram/development.local.json \
  --xcodeManagedCodesigning \
  --disableProvisioningProfiles
```

Notes:

- `Make.py` will fetch the pinned Bazel binary automatically if needed.
- `--disableProvisioningProfiles` keeps the initial run focused on simulator-only work.
- `--xcodeManagedCodesigning` is the least invasive path for local development when you have a valid Apple team configured in Xcode.
- The older [`build-system/generate-xcode-project.sh`](../build-system/generate-xcode-project.sh) script expects `bazel` in `PATH`; prefer `Make.py` for this fork bootstrap.

### 4. Install an iOS simulator runtime if needed

If Xcode opens but no iOS Simulator destination is available:

1. Open Xcode.
2. Go to `Xcode > Settings > Platforms`.
3. Install at least one iOS runtime.
4. Open `Window > Devices and Simulators` and confirm a simulator exists.

### 5. Run in the simulator

After project generation, open the generated Xcode project and select an iPhone simulator destination.

First-run target:

- Build configuration: Debug
- Destination: any iOS Simulator

The app should reach the Telegram login flow once:

- Xcode is installed and selected correctly
- the local config contains your own `api_id` / `api_hash`
- the simulator runtime is installed

### 6. Device builds and App Store readiness

Do not treat the simulator-only setup as App Store-ready.

Before App Store or TestFlight work, you still need:

- final branding that is not Telegram branding
- production signing and provisioning strategy
- privacy review for stored user data and logs
- a release bundle ID and App Store metadata
- review of any upstream license and compliance obligations

## Helper scripts

### Check prerequisites

```bash
./scripts/agentgram/check-prereqs.sh
```

This reports:

- selected developer directory
- whether full Xcode is present
- detected Xcode version
- required Xcode and Bazel versions from `versions.json`
- presence of Python, Swift, and `curl`
- whether submodules look initialized
- whether the local Agentgram config file exists

### Initialize local config

```bash
./scripts/agentgram/init-local-config.sh
```

Optional custom output path:

```bash
./scripts/agentgram/init-local-config.sh /tmp/agentgram-dev.json --force
```

## Safe verification performed in this change

Verified locally without pretending a successful build:

- repository is on `master` and was clean before these changes
- submodules are initialized
- upstream build path is `python3 build-system/Make/Make.py ... generateProject`
- `versions.json` currently pins Xcode `26.4` and Bazel `8.4.2`
- current machine cannot run `xcodebuild` because only Command Line Tools are active

Not verified on this machine:

- Xcode project generation
- simulator build
- simulator install / launch
- Telegram login
- codesigning
