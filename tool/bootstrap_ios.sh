#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'Run this setup on your Mac. It creates the iOS runner using your Flutter SDK.' >&2
  exit 1
fi
for required_tool in flutter dart python3 xcodebuild; do
  if ! command -v "$required_tool" >/dev/null 2>&1; then
    echo "Missing: $required_tool. Install/configure it, then run this setup again." >&2
    exit 1
  fi
done

if [[ ! -f ios/Runner.xcodeproj/project.pbxproj ]]; then
  if [[ -e ios ]]; then
    echo 'An incomplete ios directory already exists. Move it aside before running setup.' >&2
    exit 1
  fi
  bootstrap_temp="$(mktemp -d "${TMPDIR:-/tmp}/docdiary-ios.XXXXXX")"
  trap 'rm -rf "$bootstrap_temp"' EXIT
  flutter create --platforms=ios --ios-language=swift --org=com.techterrain \
    --project-name=docdiary_ios --no-pub "$bootstrap_temp/generated"
  cp -R "$bootstrap_temp/generated/ios" ./ios
  cp "$bootstrap_temp/generated/.metadata" ./.metadata
fi

python3 tool/configure_ios.py "$project_root"
python3 tool/install_fonts.py
flutter pub get
bash tool/verify.sh
echo 'Setup and available checks finished. Run flutter devices, then flutter run -d DEVICE_ID.'
echo 'Select your Apple development team in Xcode before running on a physical iPhone.'

