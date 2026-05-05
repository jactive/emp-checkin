#!/bin/bash
#
# Opens the EmP Check-In Xcode project.
# Run setup.sh first if you haven't already.
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -d "$PROJECT_ROOT/EmPCheckIn/EmPCheckIn.xcodeproj" ]; then
    echo "Xcode project not found. Run ./scripts/setup.sh first."
    exit 1
fi

open "$PROJECT_ROOT/EmPCheckIn/EmPCheckIn.xcodeproj"
echo "Xcode opened. Select target (EmPDao / EmPQian / EmPTong) and Cmd+R."
