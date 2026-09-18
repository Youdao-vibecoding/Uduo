#!/bin/bash
set -euo pipefail

test_root=$(cd "$(dirname "$0")/.." && pwd)
test_build=$(mktemp -d "${TMPDIR:-/tmp}/softfold-wake-tests.XXXXXX")
trap 'rm -rf "$test_build"' EXIT

if [[ -n "${SWIFTC:-}" ]]; then
  test_compiler="$SWIFTC"
elif [[ -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]]; then
  test_compiler=/Library/Developer/CommandLineTools/usr/bin/swiftc
else
  test_compiler=$(xcrun --find swiftc)
fi

test_arguments=(-parse-as-library -target "$(uname -m)-apple-macosx14.0")
if [[ -n "${SDKROOT:-}" ]]; then
  test_arguments+=(-sdk "$SDKROOT")
elif [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk ]]; then
  test_arguments+=(-sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)
fi

python3 - "$test_root" "$test_build" <<'PY'
from pathlib import Path
import sys

test_root = Path(sys.argv[1])
test_build = Path(sys.argv[2])
source = (test_root / "Sources/LiveDesktop.swift").read_text()
start = source.index("private final class LidSampleGate {")
end = source.index("\n@MainActor\nfinal class LidReading", start)
tests = (test_root / "Tests/LidSampleGateTests.swift").read_text()
(test_build / "LidSampleGateTests.swift").write_text(source[start:end] + "\n" + tests)
PY

"$test_compiler" "${test_arguments[@]}" \
  "$test_root/Sources/LidMotion.swift" \
  "$test_build/LidSampleGateTests.swift" \
  -o "$test_build/LidSampleGateTests"
"$test_build/LidSampleGateTests"
