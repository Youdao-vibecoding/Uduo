#!/bin/bash
set -euo pipefail

test_root=$(cd "$(dirname "$0")/.." && pwd)
test_build=$(mktemp -d "${TMPDIR:-/tmp}/softfold-motion-tests.XXXXXX")
trap 'rm -rf "$test_build"' EXIT

if [[ -n "${SWIFTC:-}" ]]; then
  test_compiler="$SWIFTC"
else
  test_compiler=$(xcrun --find swiftc)
fi

test_arguments=(-parse-as-library)
if [[ -n "${SDKROOT:-}" ]]; then
  test_arguments+=(-sdk "$SDKROOT")
fi

"$test_compiler" "${test_arguments[@]}" \
  "$test_root/Sources/LidMotion.swift" \
  "$test_root/Tests/LidMotionBehaviorTests.swift" \
  -o "$test_build/LidMotionBehaviorTests"
"$test_build/LidMotionBehaviorTests"
