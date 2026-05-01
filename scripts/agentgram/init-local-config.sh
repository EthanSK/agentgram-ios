#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_PATH="${1:-build-input/agentgram/development.local.json}"
FORCE="${2:-}"

if [ "$OUTPUT_PATH" = "--force" ]; then
  OUTPUT_PATH="build-input/agentgram/development.local.json"
  FORCE="--force"
fi

if [ -e "$OUTPUT_PATH" ] && [ "$FORCE" != "--force" ]; then
  printf 'Refusing to overwrite existing file: %s\n' "$OUTPUT_PATH" >&2
  printf 'Re-run with: %s %s --force\n' "$0" "$OUTPUT_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
cp build-system/template_minimal_development_configuration.json "$OUTPUT_PATH"

printf 'Created local config: %s\n' "$OUTPUT_PATH"
printf 'Edit these fields before generating the project:\n'
printf '%s\n' '- bundle_id'
printf '%s\n' '- api_id'
printf '%s\n' '- api_hash'
printf '%s\n' '- team_id'
printf 'This path is ignored by git if it stays under build-input/.\n'
