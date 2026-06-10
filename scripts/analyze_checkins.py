#!/usr/bin/env python3
"""
EmP Check-In Data Analyzer

Reads exported check-in JSON files, preprocesses them (filter by time,
resolve checkIn/undo pairs), analyzes, and generates HTML report.

Usage:
    source .venv/bin/activate
    python scripts/analyze_checkins.py --input-dir data/2026-06-07/dao/exports
"""

import argparse
import os
from pathlib import Path

from checkin_analysis import (
    load_checkin_files,
    preprocess_events,
    analyze_events,
    generate_html_report,
    parse_athletes_roster,
)


def main():
    parser = argparse.ArgumentParser(description="EmP Check-In Data Analyzer")
    parser.add_argument("--input-dir", required=True, help="Directory with exported JSON")
    parser.add_argument("--data-dir", default="data", help="Directory with athletes.xlsx")
    parser.add_argument("--output", default=None, help="Output HTML file path")
    args = parser.parse_args()
    
    # Load athlete roster
    print("📋 Loading athlete roster...")
    athletes_file = Path(args.data_dir) / "athletes.xlsx"
    if not athletes_file.exists():
        print(f"ERROR: {athletes_file} not found")
        return
    
    athletes = parse_athletes_roster(str(athletes_file))
    athletes_by_id = {a["id"]: a for a in athletes}
    print(f"   Loaded {len(athletes)} athletes")
    
    # Load check-in files
    print("📂 Loading check-in exports...")
    data = load_checkin_files(args.input_dir)
    print(f"   Loaded {len(data['files'])} files with {len(data['all_events'])} raw events")
    
    if data["duplicate_exports"]:
        print("   ⚠️  Duplicate exports detected (will be deduplicated):")
        for dup in data["duplicate_exports"]:
            print(f"      - Device {dup['device']}: exported twice")
    
    # Preprocess: filter by time, resolve checkIn/undo pairs
    print("🔧 Preprocessing events...")
    preprocess_info = preprocess_events(data["all_events"])
    print(f"   Event start: {preprocess_info['event_start_pst']}")
    print(f"   Filtered out: {preprocess_info['filtered_count']} pre-event testing events")
    print(f"   Valid check-ins: {len(preprocess_info['valid_checkins'])}")
    
    # Analyze
    print("🔍 Analyzing...")
    analysis = analyze_events(preprocess_info["valid_checkins"], athletes_by_id)
    
    print(f"\n📊 Summary:")
    print(f"   Checked in: {analysis['unique_checked_in']} / {analysis['total_athletes']}")
    print(f"   Not checked in: {analysis['not_checked_in_count']}")
    print(f"   Multi-device: {len(analysis['multi_device'])}")
    
    if analysis["multi_device"]:
        print(f"\n   Multi-device check-ins:")
        for md in analysis["multi_device"]:
            print(f"      - #{md['bibNumber']} {md['name']}: {len(md['devices'])} devices")
    
    # Generate HTML report
    output_path = args.output or str(Path(args.input_dir).parent / "report.html")
    print(f"\n📝 Generating HTML report...")
    generate_html_report(data, analysis, athletes_by_id, output_path, preprocess_info)
    
    print(f"\n✅ Done! Open: file://{os.path.abspath(output_path)}")


if __name__ == "__main__":
    main()
