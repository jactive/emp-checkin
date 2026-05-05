#!/bin/bash
#
# EmP Check-In — Clean Script
#
# Removes all generated artifacts. Run setup.sh to rebuild.
#
# Usage:
#   ./scripts/clean.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "🧹 Cleaning generated files..."

rm -rf app_bundle
echo "  ✓ app_bundle/"

rm -rf EmPCheckIn/EmPCheckIn.xcodeproj
echo "  ✓ EmPCheckIn.xcodeproj/"

rm -rf EmPCheckIn/Icons
echo "  ✓ EmPCheckIn/Icons/"

rm -rf EmPCheckIn/Sources/*/Assets.xcassets
echo "  ✓ Asset catalogs"

rm -f EmPCheckIn/Sources/Shared/Services/EmbeddedData.swift
echo "  ✓ EmbeddedData.swift"

rm -rf ~/Library/Developer/Xcode/DerivedData/EmPCheckIn-*
echo "  ✓ Xcode DerivedData"

echo ""
echo "✅ Clean. Run ./scripts/setup.sh to rebuild."
