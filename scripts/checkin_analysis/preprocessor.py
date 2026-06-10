"""
Preprocess check-in events: filter by time, resolve checkIn/undo pairs per device.
"""

from collections import defaultdict
from datetime import datetime, timezone, timedelta


# PST = UTC-7 (or UTC-8 for PDT, but using -7 for summer)
PST = timezone(timedelta(hours=-7))

# Event cutoff: June 7, 2026 12:00 PM PST
EVENT_START_PST = datetime(2026, 6, 7, 12, 0, 0, tzinfo=PST)
EVENT_START_UTC = EVENT_START_PST.astimezone(timezone.utc)


def preprocess_events(all_events: list) -> dict:
    """
    Preprocess raw events: filter by time, resolve checkIn/undo pairs per device.
    
    Returns dict with:
    - valid_checkins: list of final valid checkIn events (one per person per device)
    - filtered_count: how many events were filtered (before event start)
    - raw_count: total raw events
    """
    # Filter events before event start
    filtered = []
    for e in all_events:
        try:
            ts = datetime.fromisoformat(e["timestamp"].replace("Z", "+00:00"))
            if ts >= EVENT_START_UTC:
                e["_parsed_ts"] = ts
                filtered.append(e)
        except:
            pass
    
    filtered_count = len(all_events) - len(filtered)
    
    # Group by device
    by_device: dict[str, list] = defaultdict(list)
    for e in filtered:
        by_device[e["device"]].append(e)
    
    # Process each device independently
    valid_checkins = []
    
    for device, events in by_device.items():
        device_checkins = _resolve_device_events(events)
        valid_checkins.extend(device_checkins)
    
    return {
        "valid_checkins": valid_checkins,
        "filtered_count": filtered_count,
        "raw_count": len(all_events),
        "event_start_pst": EVENT_START_PST.strftime("%Y-%m-%d %H:%M PST"),
    }


def _resolve_device_events(events: list) -> list:
    """
    Resolve checkIn/undo pairs for one device.
    Returns list of valid checkIn events (last checkIn per person if not undone).
    """
    # Group by person
    by_person: dict[str, list] = defaultdict(list)
    for e in events:
        by_person[e["personId"]].append(e)
    
    valid = []
    
    for person_id, person_events in by_person.items():
        # Sort by timestamp
        person_events.sort(key=lambda x: x["_parsed_ts"])
        
        # Walk through and track state
        last_checkin = None
        is_checked_in = False
        
        for e in person_events:
            if e["action"] == "checkIn":
                last_checkin = e
                is_checked_in = True
            elif e["action"] == "undo":
                is_checked_in = False
                # Don't clear last_checkin - we might need it for debugging
        
        # If final state is checked in, keep the last checkIn event
        if is_checked_in and last_checkin:
            valid.append(last_checkin)
    
    return valid


def format_timestamp_pst(iso_str: str) -> str:
    """Convert ISO timestamp to PST formatted string."""
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        dt_pst = dt.astimezone(PST)
        return dt_pst.strftime("%Y-%m-%d %H:%M:%S PST")
    except:
        return iso_str
