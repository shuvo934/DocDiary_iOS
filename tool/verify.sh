#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK is required. No Flutter checks have run.' >&2
  exit 1
fi
flutter --version
# Formatting also asks the actual Dart parser to parse every source and test.
dart format lib test
flutter analyze --fatal-infos
flutter test
if [[ "${1:-}" == "--ios-simulator" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo 'The iOS simulator build must run on macOS.' >&2
    exit 1
  fi
  flutter build ios --simulator --debug --no-codesign
fi
