#!/bin/bash
#
# Merge EmP 签 (volunteer) check-in logs into a CSV report.
#
# Before running:
#   Copy all qian_log_*.json files from devices into ./data/logs-qian/
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

LOGS_DIR="data/logs-qian"
OUTPUT="output/volunteers_report.csv"

if [ ! -d "$LOGS_DIR" ]; then
    echo ""
    echo "📁 Directory not found: $LOGS_DIR"
    echo ""
    echo "   Create it and copy your qian log files there:"
    echo ""
    echo "     mkdir -p $LOGS_DIR"
    echo "     # Then drag qian_log_*.json files into $LOGS_DIR"
    echo ""
    exit 1
fi

JSON_COUNT=$(find "$LOGS_DIR" -name "*.json" | wc -l | tr -d ' ')
if [ "$JSON_COUNT" = "0" ]; then
    echo ""
    echo "⚠️  No .json files found in $LOGS_DIR"
    echo ""
    echo "   Copy qian_log_*.json files from devices into:"
    echo "     $LOGS_DIR"
    echo ""
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  EmP 签 — Merge Volunteer Check-In Logs"
echo "═══════════════════════════════════════════"
echo ""

uv run python scripts/merge_checkins.py \
    --logs-dir "$LOGS_DIR" \
    --roster data/volunteers.xlsx \
    --type volunteers \
    --output "$OUTPUT"

echo ""
echo "📄 Report: $OUTPUT"
echo ""
