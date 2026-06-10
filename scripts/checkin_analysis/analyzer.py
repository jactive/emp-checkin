"""
Analyze check-in events and compute statistics.
"""

from collections import Counter, defaultdict
from datetime import datetime, timezone, timedelta

from .preprocessor import PST


def analyze_events(valid_checkins: list, athletes_by_id: dict) -> dict:
    """
    Analyze preprocessed valid check-in events.
    
    Args:
        valid_checkins: List of valid checkIn events (after preprocessing)
        athletes_by_id: Dict mapping person ID to athlete info
    
    Returns dict with all computed stats.
    """
    # Group by person to find multi-device check-ins
    person_checkins: dict[str, list] = defaultdict(list)
    for c in valid_checkins:
        person_checkins[c["personId"]].append(c)
    
    # Compute device-to-age mapping (primary age group for each device)
    device_age_map = _compute_device_age_map(valid_checkins, athletes_by_id)
    
    # Multi-device check-ins (same person on different devices)
    multi_device = _find_multi_device(person_checkins, athletes_by_id, device_age_map)
    
    # Unique checked-in athletes
    unique_checked_in = set(person_checkins.keys())
    all_athlete_ids = set(athletes_by_id.keys())
    not_checked_in = all_athlete_ids - unique_checked_in
    
    # Time analysis (in PST)
    timestamps = _parse_timestamps(valid_checkins)
    time_min = min(timestamps) if timestamps else None
    time_max = max(timestamps) if timestamps else None
    hourly_counts = _compute_hourly_buckets(timestamps)
    minute_counts = _compute_minute_buckets(timestamps)
    
    # Breakdowns
    age_counts = _breakdown_by_field(unique_checked_in, athletes_by_id, "age")
    age_totals = Counter(a.get("age") for a in athletes_by_id.values() if a.get("age"))
    gender_counts = _breakdown_by_field(unique_checked_in, athletes_by_id, "gender")
    gender_age_counts = _breakdown_by_gender_age(unique_checked_in, athletes_by_id)
    gender_age_totals = _breakdown_by_gender_age_totals(athletes_by_id)
    event_counts = _breakdown_by_events(unique_checked_in, athletes_by_id)
    operator_counts = Counter(c.get("operator", "Unknown") for c in valid_checkins)
    device_counts = Counter(c["device"] for c in valid_checkins)
    
    # Age 8 stats (for filtering)
    age8_count = sum(1 for a in athletes_by_id.values() if a.get("age") == 8)
    age8_checked_in = sum(1 for pid in unique_checked_in if athletes_by_id.get(pid, {}).get("age") == 8)
    
    return {
        "total_valid_checkins": len(valid_checkins),
        "unique_checked_in": len(unique_checked_in),
        "total_athletes": len(athletes_by_id),
        "not_checked_in_count": len(not_checked_in),
        "not_checked_in_ids": sorted(not_checked_in, key=lambda x: int(x)),
        "multi_device": multi_device,
        "device_age_map": device_age_map,
        "time_min": _format_pst(time_min) if time_min else None,
        "time_max": _format_pst(time_max) if time_max else None,
        "hourly_counts": dict(sorted(hourly_counts.items())),
        "minute_counts": dict(sorted(minute_counts.items())),
        "age_counts": dict(sorted(age_counts.items())),
        "age_totals": dict(sorted(age_totals.items())),
        "gender_counts": dict(gender_counts),
        "gender_age_counts": gender_age_counts,
        "gender_age_totals": gender_age_totals,
        "event_counts": dict(event_counts),
        "operator_counts": dict(operator_counts.most_common()),
        "device_counts": dict(device_counts),
        "age8_count": age8_count,
        "age8_checked_in": age8_checked_in,
    }


def _compute_device_age_map(checkins: list, athletes_by_id: dict) -> dict:
    """Compute primary age group for each device based on check-in patterns."""
    device_ages = defaultdict(Counter)
    for c in checkins:
        device = c.get("device", "?")
        athlete = athletes_by_id.get(c["personId"], {})
        age = athlete.get("age")
        if age:
            device_ages[device][age] += 1
    
    # Find primary age for each device
    device_age_map = {}
    for device, ages in device_ages.items():
        if ages:
            # Get the most common age
            primary_age = ages.most_common(1)[0][0]
            # Check if there's a range (like 3-4 or 11-15)
            sorted_ages = sorted(ages.keys())
            total = sum(ages.values())
            # If primary age accounts for >80% of check-ins, use single age
            if ages[primary_age] / total > 0.8:
                device_age_map[device] = f"Age {primary_age}"
            else:
                # Use range
                device_age_map[device] = f"Age {sorted_ages[0]}-{sorted_ages[-1]}"
    
    return device_age_map


def _find_multi_device(person_checkins: dict, athletes_by_id: dict, device_age_map: dict) -> list:
    """Find athletes checked in on multiple devices."""
    multi_device = []
    for person_id, checks in person_checkins.items():
        devices = set(c["device"] for c in checks)
        if len(devices) > 1:
            athlete = athletes_by_id.get(person_id, {})
            # Map device IDs to age group labels
            device_labels = [device_age_map.get(d, d) for d in devices]
            # Format timestamps in PST
            timestamps_pst = []
            for c in checks:
                try:
                    dt = datetime.fromisoformat(c["timestamp"].replace("Z", "+00:00"))
                    dt_pst = dt.astimezone(PST)
                    timestamps_pst.append(dt_pst.strftime("%I:%M %p"))
                except:
                    timestamps_pst.append(c["timestamp"])
            
            multi_device.append({
                "personId": person_id,
                "name": f"{athlete.get('firstName', '?')} {athlete.get('lastName', '')}".strip(),
                "bibNumber": athlete.get("bibNumber", person_id),
                "age": athlete.get("age", "?"),
                "devices": device_labels,
                "checkInCount": len(checks),
                "timestamps": timestamps_pst,
                "operators": [c.get("operator", "?") for c in checks],
            })
    return sorted(multi_device, key=lambda x: -x["checkInCount"])


def _parse_timestamps(checkins: list) -> list:
    """Parse timestamps from check-in events."""
    timestamps = []
    for c in checkins:
        try:
            dt = datetime.fromisoformat(c["timestamp"].replace("Z", "+00:00"))
            timestamps.append(dt)
        except:
            pass
    return sorted(timestamps)


def _compute_hourly_buckets(timestamps: list) -> Counter:
    """Compute hourly check-in counts in PST."""
    hourly = Counter()
    for dt in timestamps:
        dt_pst = dt.astimezone(PST)
        hourly[dt_pst.strftime("%Y-%m-%d %H:00")] += 1
    return hourly


def _compute_minute_buckets(timestamps: list) -> Counter:
    """Compute per-minute check-in counts in PST with full datetime."""
    minute = Counter()
    for dt in timestamps:
        dt_pst = dt.astimezone(PST)
        minute[dt_pst.strftime("%m-%d %H:%M")] += 1
    return minute


def _format_pst(dt: datetime) -> str:
    """Format datetime as PST string."""
    dt_pst = dt.astimezone(PST)
    return dt_pst.strftime("%Y-%m-%d %H:%M:%S PST")


def _breakdown_by_field(person_ids: set, athletes_by_id: dict, field: str) -> Counter:
    """Count athletes by a specific field (age, gender, etc)."""
    counts = Counter()
    for pid in person_ids:
        athlete = athletes_by_id.get(pid, {})
        value = athlete.get(field)
        if value:
            counts[value] += 1
    return counts


def _breakdown_by_events(person_ids: set, athletes_by_id: dict) -> Counter:
    """Count participation by event type."""
    counts = Counter()
    for pid in person_ids:
        athlete = athletes_by_id.get(pid, {})
        for evt in athlete.get("events", []):
            counts[evt] += 1
    return counts


def _breakdown_by_gender_age(person_ids: set, athletes_by_id: dict) -> dict:
    """Count checked-in athletes by gender and age."""
    result = {"Male": {}, "Female": {}}
    for pid in person_ids:
        athlete = athletes_by_id.get(pid, {})
        gender = athlete.get("gender", "")
        age = athlete.get("age")
        if gender in result and age:
            result[gender][age] = result[gender].get(age, 0) + 1
    return result


def _breakdown_by_gender_age_totals(athletes_by_id: dict) -> dict:
    """Count total athletes by gender and age."""
    result = {"Male": {}, "Female": {}}
    for athlete in athletes_by_id.values():
        gender = athlete.get("gender", "")
        age = athlete.get("age")
        if gender in result and age:
            result[gender][age] = result[gender].get(age, 0) + 1
    return result
