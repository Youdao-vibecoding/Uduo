#!/bin/bash
set -euo pipefail

brand_root=$(cd "$(dirname "$0")/.." && pwd)
brand_developer=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
brand_compiler="$brand_developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
brand_sdk="$brand_developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
brand_stage=$(mktemp -d "${TMPDIR:-/tmp}/uduo-brand.XXXXXX")
trap 'rm -rf "$brand_stage"' EXIT

"$brand_compiler" -parse-as-library -O -sdk "$brand_sdk" \
  -target arm64-apple-macosx14.0 \
  "$brand_root/Sources/FoldShowcase.swift" \
  "$brand_root/scripts/render-brand-assets.swift" \
  -o "$brand_stage/render-brand-assets"
"$brand_stage/render-brand-assets" "$brand_root"
