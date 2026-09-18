#!/bin/bash
set -euo pipefail

uduo_skip_build=false
case "${1:-}" in
  '') ;;
  --skip-build) uduo_skip_build=true; shift ;;
  --help)
    printf '%s\n' 'Usage: scripts/package.sh [--skip-build]' \
      'Creates dist/Uduo-<version>-arm64.dmg and its SHA-256 checksum.' \
      'Optional: CODE_SIGN_IDENTITY; NOTARY_PROFILE or NOTARYTOOL_PROFILE.' \
      'Notarization requires an explicitly supplied Developer ID Application identity.' \
      'No publishing, credential creation, or system security changes are performed.'
    exit 0 ;;
  *) printf '%s\n' 'Unsupported argument. Use scripts/package.sh --help.' >&2; exit 2 ;;
esac
if [[ $# -ne 0 ]]; then
  printf '%s\n' 'Too many arguments.' >&2
  exit 2
fi

uduo_root=$(cd "$(dirname "$0")/.." && pwd)
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
uduo_identity=${CODE_SIGN_IDENTITY:--}
uduo_profile=${NOTARY_PROFILE:-${NOTARYTOOL_PROFILE:-}}
if [[ -n "$uduo_profile" && "$uduo_identity" == - ]]; then
  printf '%s\n' 'NOTARY_PROFILE requires CODE_SIGN_IDENTITY for a Developer ID Application certificate.' >&2
  exit 2
fi
if [[ "$uduo_skip_build" == false ]]; then
  /bin/bash "$uduo_root/scripts/build.sh"
fi
uduo_app="$uduo_root/dist/Uduo.app"
if [[ ! -d "$uduo_app" ]]; then
  printf '%s\n' 'dist/Uduo.app is missing. Run scripts/build.sh first.' >&2
  exit 1
fi
/usr/bin/codesign --verify --deep --strict "$uduo_app"
uduo_app_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$uduo_app/Contents/Info.plist")
uduo_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$uduo_app/Contents/Info.plist")
uduo_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$uduo_app/Contents/Info.plist")
uduo_minimum=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$uduo_app/Contents/Info.plist")
if [[ "$uduo_app_id" != app.uduo.mac || "$uduo_executable" != Uduo || "$uduo_minimum" != 14.0 || ! "$uduo_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf '%s\n' 'The app bundle identity or version is not a valid Uduo release.' >&2
  exit 1
fi
/usr/bin/lipo "$uduo_app/Contents/MacOS/Uduo" -verify_arch arm64
uduo_signature=$(/usr/bin/codesign --display --verbose=4 "$uduo_app" 2>&1)
if [[ -n "$uduo_profile" && "$uduo_signature" != *'Authority=Developer ID Application:'* ]]; then
  printf '%s\n' 'Notarization requires the app to be signed with Developer ID Application.' >&2
  exit 1
fi

uduo_stage=$(mktemp -d "$uduo_root/dist/.uduo-package.XXXXXX")
trap 'rm -rf "$uduo_stage"' EXIT
uduo_volume="$uduo_stage/volume"
mkdir -p "$uduo_volume"
/usr/bin/ditto "$uduo_app" "$uduo_volume/Uduo.app"
ln -s /Applications "$uduo_volume/Applications"
cp "$uduo_root/LICENSE" "$uduo_volume/LICENSE.txt"

uduo_notarize() {
  local uduo_submission=$1
  local uduo_record=$2
  if ! /usr/bin/xcrun notarytool submit "$uduo_submission" --keychain-profile "$uduo_profile" \
    --wait --output-format json > "$uduo_record"; then
    cat "$uduo_record" >&2
    return 1
  fi
  local uduo_status
  uduo_status=$(/usr/bin/plutil -extract status raw -o - "$uduo_record")
  if [[ "$uduo_status" != Accepted ]]; then
    printf 'Notarization was not accepted: %s\n' "$uduo_status" >&2
    cat "$uduo_record" >&2
    return 1
  fi
}

if [[ -n "$uduo_profile" ]]; then
  /usr/bin/ditto -c -k --keepParent "$uduo_volume/Uduo.app" "$uduo_stage/Uduo.zip"
  uduo_notarize "$uduo_stage/Uduo.zip" "$uduo_stage/app-notarization.json"
  /usr/bin/xcrun stapler staple "$uduo_volume/Uduo.app"
  /usr/bin/xcrun stapler validate "$uduo_volume/Uduo.app"
  /usr/bin/codesign --verify --deep --strict "$uduo_volume/Uduo.app"
  /usr/sbin/spctl --assess --type execute "$uduo_volume/Uduo.app"
  uduo_signing_note='Developer ID signed and notarized by Apple. / 已使用 Developer ID 签名并通过 Apple 公证。'
elif [[ "$uduo_signature" == *'Signature=adhoc'* ]]; then
  uduo_signing_note='Ad hoc signed, not notarized. Other Macs may refuse to open this build. / 本地临时签名，未经过 Apple 公证；其他 Mac 可能拒绝打开此版本。'
else
  uduo_signing_note='Signed, but notarization was not performed for this package. / 已签名，但此安装包未执行 Apple 公证流程。'
fi

cat > "$uduo_volume/INSTALL.txt" <<EOF
Uduo $uduo_version

1. Drag Uduo.app to the Applications shortcut, then eject this disk image.
2. Open Uduo from Applications and enable its effect.
3. Allow screen recording when macOS requests it, then reopen Uduo if asked.

If macOS blocks this app because its developer cannot be verified, first try opening
it once. Then open System Settings > Privacy & Security, find the Uduo notice,
and choose Open Anyway if you trust this build. Confirm the prompt that follows.
If that option is unavailable or macOS reports malware or damage, do not change
security settings to bypass it; obtain a verified build instead.

Requires macOS 14 or later, Apple silicon (arm64), and a compatible lid-angle sensor.
Uduo stays running when its settings window closes. Click its Dock or menu-bar icon
to return to settings. Use Quit in the app to stop it completely.

1. 将 Uduo.app 拖到 Applications 快捷方式，完成后推出此磁盘映像。
2. 从“应用程序”打开 Uduo，再开启效果。
3. 按 macOS 提示允许屏幕录制；如有要求，退出并重新打开 Uduo。

若 macOS 因无法验证开发者而拦截，请先尝试打开一次，再前往
“系统设置 → 隐私与安全性”，找到 Uduo 的提示；确认信任此版本后，
点击“仍要打开”，并确认后续提示。
若没有此选项，或系统报告恶意软件、文件损坏，请获取经过验证的版本，勿修改系统安全设置来绕过。
Apple 操作说明：https://support.apple.com/guide/mac-help/mh40616/mac

需要 macOS 14 或更新版本、Apple 芯片（arm64），以及兼容的屏幕开合角度传感器。
关闭设置窗口后应用仍会运行。点击 Dock 或菜单栏图标可返回设置；点击应用内“退出”可完全停止。

$uduo_signing_note

This installer does not remove quarantine attributes or change macOS security settings.
For broad distribution without the unidentified-developer prompt, use a Developer ID signed and notarized build.
此安装包不会移除隔离属性或修改 macOS 安全设置。对外分发应使用 Developer ID 签名并公证的版本。

Uduo is derived from Softfold and Hinge. See LICENSE.txt for the MIT license
and the retained copyright notices.
EOF

uduo_name="Uduo-$uduo_version-arm64.dmg"
uduo_dmg="$uduo_stage/$uduo_name"
/usr/bin/hdiutil create -ov -volname Uduo -fs HFS+ -srcfolder "$uduo_volume" -format UDZO "$uduo_dmg"
uduo_sign_options=(--force --sign "$uduo_identity")
if [[ "$uduo_identity" == - ]]; then
  uduo_sign_options+=(--timestamp=none)
else
  uduo_sign_options+=(--timestamp)
fi
/usr/bin/codesign "${uduo_sign_options[@]}" "$uduo_dmg"
/usr/bin/codesign --verify --strict "$uduo_dmg"
if [[ -n "$uduo_profile" ]]; then
  uduo_notarize "$uduo_dmg" "$uduo_stage/dmg-notarization.json"
  /usr/bin/xcrun stapler staple "$uduo_dmg"
  /usr/bin/xcrun stapler validate "$uduo_dmg"
  /usr/bin/codesign --verify --strict "$uduo_dmg"
fi
/usr/bin/hdiutil verify "$uduo_dmg"
(
  cd "$uduo_stage"
  /usr/bin/shasum -a 256 "$uduo_name" > "$uduo_name.sha256"
)
if [[ -n "$uduo_profile" ]]; then
  mv "$uduo_app" "$uduo_stage/previous.app"
  if ! mv "$uduo_volume/Uduo.app" "$uduo_app"; then
    mv "$uduo_stage/previous.app" "$uduo_app"
    exit 1
  fi
  cp "$uduo_stage/app-notarization.json" "$uduo_root/dist/Uduo-$uduo_version-arm64-app.notary.json"
  cp "$uduo_stage/dmg-notarization.json" "$uduo_root/dist/Uduo-$uduo_version-arm64-dmg.notary.json"
fi
mv -f "$uduo_dmg" "$uduo_root/dist/$uduo_name"
mv -f "$uduo_stage/$uduo_name.sha256" "$uduo_root/dist/$uduo_name.sha256"
printf 'Created: %s\n' "$uduo_root/dist/$uduo_name"
printf '%s\n' "$uduo_signing_note"
