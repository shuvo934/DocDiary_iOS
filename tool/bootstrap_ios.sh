#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Run this setup on your Mac with the included iOS Runner.' >&2
  exit 1
fi
if [[ ! -f ios/Runner.xcodeproj/project.pbxproj ||
      ! -f ios/Runner/PrivacyInfo.xcprivacy ]]; then
  echo 'Restore the included DocDiary iOS Runner and privacy manifest.' >&2
  exit 1
fi
flutter pub get
bash tool/verify.sh "$@"
