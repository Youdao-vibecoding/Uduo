#!/bin/bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  if [[ $# -eq 1 && "$1" == --help ]]; then
    printf '%s\n' 'Usage: scripts/build.sh' \
      'Builds dist/Uduo.app for Apple silicon and macOS 14 or later.' \
      'Optional: DEVELOPER_DIR, CODE_SIGN_IDENTITY (default: - for ad hoc signing).'
    exit 0
  fi
  printf '%s\n' 'Unsupported argument. Use scripts/build.sh --help.' >&2
  exit 2
fi

uduo_root=$(cd "$(dirname "$0")/.." && pwd)
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
uduo_sdk=$(/usr/bin/xcrun --sdk macosx --show-sdk-path)
uduo_identity=${CODE_SIGN_IDENTITY:--}
uduo_plist="$uduo_root/Info.plist"
/usr/bin/plutil -lint "$uduo_plist"
for uduo_field in CFBundleIdentifier CFBundleExecutable LSMinimumSystemVersion SoftfoldLocalBuild; do
  uduo_value=$(/usr/libexec/PlistBuddy -c "Print :$uduo_field" "$uduo_plist")
  case "$uduo_field:$uduo_value" in
    CFBundleIdentifier:app.uduo.mac|CFBundleExecutable:Uduo|LSMinimumSystemVersion:14.0|SoftfoldLocalBuild:true) ;;
    *) printf 'Unexpected %s in Info.plist: %s\n' "$uduo_field" "$uduo_value" >&2; exit 1 ;;
  esac
done

mkdir -p "$uduo_root/dist"
uduo_stage=$(mktemp -d "$uduo_root/dist/.uduo-build.XXXXXX")
trap 'rm -rf "$uduo_stage"' EXIT
uduo_app="$uduo_stage/Uduo.app"
uduo_resources="$uduo_app/Contents/Resources"
mkdir -p "$uduo_app/Contents/MacOS" "$uduo_resources" "$uduo_stage/AppIcon.iconset"

/usr/bin/xcrun --sdk macosx swiftc -parse-as-library -swift-version 5 -O -sdk "$uduo_sdk" \
  -target arm64-apple-macosx14.0 -module-name Uduo \
  "$uduo_root"/Sources/*.swift -o "$uduo_app/Contents/MacOS/Uduo"
cp "$uduo_plist" "$uduo_app/Contents/Info.plist"
if /usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$uduo_app/Contents/Info.plist" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$uduo_app/Contents/Info.plist"
fi
/usr/bin/xcrun xcstringstool compile "$uduo_root/Resources/Localizable.xcstrings" \
  --output-directory "$uduo_resources"
cp "$uduo_root/Resources/Fold.metal" "$uduo_resources/Fold.metal"
/usr/bin/xcrun --sdk macosx metal -std=macos-metal2.4 -c "$uduo_resources/Fold.metal" \
  -o "$uduo_stage/Fold.air"
cp "$uduo_root/Resources/Assets.xcassets/AppIcon.appiconset/"*.png "$uduo_stage/AppIcon.iconset/"
/usr/bin/iconutil -c icns "$uduo_stage/AppIcon.iconset" -o "$uduo_resources/AppIcon.icns"
for uduo_icon in MenuBarIcon MenuBarIconActive; do
  uduo_images="$uduo_root/Resources/Assets.xcassets/$uduo_icon.imageset"
  cp "$uduo_images/$uduo_icon@1x.png" "$uduo_resources/$uduo_icon.png"
  cp "$uduo_images/$uduo_icon@2x.png" "$uduo_resources/$uduo_icon@2x.png"
done
cp "$uduo_root/LICENSE" "$uduo_resources/LICENSE"

uduo_sign_options=(--force --sign "$uduo_identity" --options runtime)
if [[ "$uduo_identity" == - ]]; then
  uduo_sign_options+=(--timestamp=none)
else
  uduo_sign_options+=(--timestamp)
fi
/usr/bin/codesign "${uduo_sign_options[@]}" "$uduo_app"
/usr/bin/codesign --verify --deep --strict "$uduo_app"
/usr/bin/plutil -lint "$uduo_app/Contents/Info.plist"
/usr/bin/lipo "$uduo_app/Contents/MacOS/Uduo" -verify_arch arm64

uduo_output="$uduo_root/dist/Uduo.app"
if [[ -e "$uduo_output" ]]; then
  mv "$uduo_output" "$uduo_stage/previous.app"
fi
if ! mv "$uduo_app" "$uduo_output"; then
  if [[ -e "$uduo_stage/previous.app" ]]; then
    mv "$uduo_stage/previous.app" "$uduo_output"
  fi
  exit 1
fi
printf 'Built: %s\n' "$uduo_output"
if [[ "$uduo_identity" == - ]]; then
  printf '%s\n' 'Signing: ad hoc, not notarized. This is not a Developer ID release.'
else
  printf '%s\n' 'Signing verified. Notarization has not run; use scripts/release.sh with NOTARY_PROFILE.'
fi
