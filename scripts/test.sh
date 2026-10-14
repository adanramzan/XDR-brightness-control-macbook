#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -module-cache-path "$PWD/build/SwiftModuleCache" XDRBrightness/BoostPolicy.swift XDRBrightness/tests/main.swift -o build/xdr-policy-tests
build/xdr-policy-tests
