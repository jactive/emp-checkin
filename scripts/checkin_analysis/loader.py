"""
Load and parse check-in JSON export files.
"""

import json
from collections import defaultdict
from pathlib import Path


def load_checkin_files(input_dir: str) -> dict:
    """Load all dao check-in JSON files and return organized data.
    
    Returns dict with:
    - files: list of file info dicts
    - all_events: merged list of all events
    - duplicate_exports: list of detected duplicate exports
    """
    files = sorted(Path(input_dir).glob("dao_*.json"), key=lambda x: x.name)
    
    result = {
        "files": [],
        "all_events": [],
        "duplicate_exports": [],
    }
    
    device_events: dict[str, list] = defaultdict(list)
    
    for f in files:
        with open(f) as fp:
            events = json.load(fp)
        
        device_id = f.stem.split("_")[-1]
        export_time = "_".join(f.stem.split("_")[2:4])
        
        file_info = {
            "filename": f.name,
            "device_id": device_id,
            "export_time": export_time,
            "event_count": len(events),
            "events": events,
        }
        result["files"].append(file_info)
        
        # Check for duplicate export (same device, same events)
        event_ids = frozenset(e["id"] for e in events)
        if device_id in device_events:
            for prev in device_events[device_id]:
                if prev["event_ids"] == event_ids:
                    result["duplicate_exports"].append({
                        "device": device_id,
                        "export1": prev["filename"],
                        "export2": f.name,
                        "event_count": len(events),
                    })
        
        device_events[device_id].append({
            "filename": f.name,
            "event_ids": event_ids,
        })
        
        result["all_events"].extend(events)
    
    return result
