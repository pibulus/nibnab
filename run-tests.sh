#!/bin/bash

# ===================================================================
# NibNab Test Runner
# Compiles the storage test harness against the real StorageManager
# and runs it. Exit code 0 = all green.
# ===================================================================

set -euo pipefail

BUILD_DIR="build"
TEST_BIN="$BUILD_DIR/storage-tests"

mkdir -p "$BUILD_DIR"

swiftc -parse-as-library -target arm64-apple-macos13.0 \
    Sources/Models.swift \
    Sources/ColorTheme.swift \
    Sources/StorageManager.swift \
    Tests/StorageTests.swift \
    -o "$TEST_BIN"

"$TEST_BIN"
