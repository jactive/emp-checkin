"""
EmP Check-In — Roster Preprocessing Script

Reads athletes.xlsx and volunteers.xlsx, normalizes data into JSON,
encrypts with AES-GCM using a shared password, and outputs .enc files
ready to bundle into the iOS apps.

Also detects and reports potential duplicate registrations.

Usage:
    uv run python scripts/prepare_roster.py --password <shared_password>
"""

import argparse
import hashlib
import json
import os
import sys
from collections import Counter
from pathlib import Path

import openpyxl

# AES-GCM encryption using cryptography library
try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError:
    print("ERROR: 'cryptography' package required. Run: uv add cryptography")
    sys.exit(1)


def derive_key(password: str) -> bytes:
    """Derive a 256-bit AES key from password using SHA-256.
    
    Note: Using SHA-256 for simplicity. The iOS app must use the same
    derivation method. For a local-only community event app with a shared
    password, this is sufficient.
    """
    return hashlib.sha256(password.encode("utf-8")).digest()


def encrypt_data(data: bytes, password: str) -> bytes:
    """Encrypt data with AES-256-GCM. Returns nonce (12 bytes) + ciphertext."""
    key = derive_key(password)
    nonce = os.urandom(12)
    aesgcm = AESGCM(key)
    ciphertext = aesgcm.encrypt(nonce, data, None)
    return nonce + ciphertext


def _clean_phone(value) -> str:
    """Clean phone number from Excel — strip .0 from float representation."""
    if not value:
        return ""
    s = str(value).strip()
    # Excel stores numbers as floats, e.g. 4255984859.0
    if s.endswith(".0"):
        s = s[:-2]
    return s


def parse_athletes(filepath: str) -> list[dict]:
    """Parse athletes from xlsx into normalized dicts."""
    wb = openpyxl.load_workbook(filepath, read_only=True)
    ws = wb["Athletes 2025-05-22"]
    rows = list(ws.iter_rows(values_only=True))
    
    athletes = []
    for row in rows[1:]:
        # Skip empty rows
        if not row[3] or not row[4]:
            continue
        
        # Parse events
        events = []
        if row[5]:  # 4x100m (9+)
            events.append("4×100m Relay")
        if row[6]:  # 100m (15+)
            events.append("100m")
        if row[7]:  # 400m (15+)
            events.append("400m")
        if row[8]:  # 1600m (11+)
            events.append("1600m")
        
        athlete = {
            "id": str(int(row[2])),  # Bib number as string ID
            "firstName": str(row[3]).strip(),
            "lastName": str(row[4]).strip(),
            "age": int(row[0]),
            "gender": str(row[1]).strip(),
            "events": events,
            "bibNumber": int(row[2]),
            # Contact info (only visible in EmP 通)
            "contactName": str(row[10]).strip() if row[10] else "",
            "contactPhone": _clean_phone(row[11]),
            "contactWeChat": str(row[12]).strip() if row[12] else "",
            "contactEmail": str(row[13]).strip() if row[13] else "",
            "shippingPhone": _clean_phone(row[14]),
        }
        athletes.append(athlete)
    
    wb.close()
    return athletes


def parse_volunteers(filepath: str) -> list[dict]:
    """Parse volunteers from xlsx into normalized dicts."""
    wb = openpyxl.load_workbook(filepath, read_only=True)
    ws = wb["Sheet1"]
    rows = list(ws.iter_rows(values_only=True))
    
    volunteers = []
    vol_id = 1
    for row in rows[1:]:
        # Need at least 3 columns and a name
        if len(row) < 3 or not row[2]:
            continue
        
        name = str(row[2]).strip()
        role = str(row[0]).strip() if row[0] else ""
        email = str(row[3]).strip() if len(row) > 3 and row[3] else ""
        phone = _clean_phone(row[4]) if len(row) > 4 else ""
        
        # Skip entries that have no role, no email, and no phone — these are notes, not volunteers
        if not role and not email and not phone:
            continue
        
        volunteer = {
            "id": str(vol_id),
            "name": name,
            "role": role,
            "email": email,
            "phone": phone,
        }
        volunteers.append(volunteer)
        vol_id += 1
    
    wb.close()
    return volunteers


def detect_athlete_duplicates(athletes: list[dict]) -> list[str]:
    """Detect potential duplicate athlete registrations."""
    warnings = []
    
    # Group by (firstName, lastName, age, gender)
    groups: dict[tuple, list[dict]] = {}
    for a in athletes:
        key = (
            a["firstName"].lower(),
            a["lastName"].lower(),
            a["age"],
            a["gender"],
        )
        groups.setdefault(key, []).append(a)
    
    for key, group in groups.items():
        if len(group) > 1:
            # Check if same contact (likely duplicate registration)
            contacts = set()
            for a in group:
                contact_key = (
                    a["contactEmail"].lower(),
                    a["shippingPhone"],
                )
                contacts.add(contact_key)
            
            if len(contacts) == 1:
                msg = (
                    f"⚠️  LIKELY DUPLICATE: {group[0]['firstName']} {group[0]['lastName']}, "
                    f"age {group[0]['age']} {group[0]['gender']} — "
                    f"{len(group)} registrations with same contact. "
                    f"Bibs: {[a['bibNumber'] for a in group]}"
                )
            else:
                msg = (
                    f"ℹ️  SAME NAME: {group[0]['firstName']} {group[0]['lastName']}, "
                    f"age {group[0]['age']} {group[0]['gender']} — "
                    f"{len(group)} entries with DIFFERENT contacts (likely siblings/twins). "
                    f"Bibs: {[a['bibNumber'] for a in group]}"
                )
            warnings.append(msg)
    
    return warnings


def main():
    parser = argparse.ArgumentParser(description="EmP Check-In Roster Preprocessor")
    parser.add_argument("--password-dao", required=True, help="Password for EmP 到 (athlete app)")
    parser.add_argument("--password-qian", required=True, help="Password for EmP 签 (volunteer app)")
    parser.add_argument("--password-tong", required=True, help="Password for EmP 通 (admin app)")
    parser.add_argument("--data-dir", default="data", help="Directory containing xlsx files")
    parser.add_argument("--output-dir", default="app_bundle", help="Output directory for encrypted files")
    args = parser.parse_args()
    
    data_dir = Path(args.data_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)
    
    # Parse athletes
    print("📋 Parsing athletes...")
    athletes_file = data_dir / "athletes.xlsx"
    if not athletes_file.exists():
        print(f"ERROR: {athletes_file} not found")
        sys.exit(1)
    athletes = parse_athletes(str(athletes_file))
    print(f"   Found {len(athletes)} athletes")
    
    # Validate bib uniqueness
    bibs = [a["bibNumber"] for a in athletes]
    seen = {}
    for a in athletes:
        bib = a["bibNumber"]
        if bib in seen:
            print(f"   ❌ ERROR: Duplicate bib #{bib}: {seen[bib]} and {a['firstName']} {a['lastName']}")
            sys.exit(1)
        seen[bib] = f"{a['firstName']} {a['lastName']}"
    print(f"   ✓ All {len(bibs)} bibs are unique")
    
    # Parse volunteers
    print("📋 Parsing volunteers...")
    volunteers_file = data_dir / "volunteers.xlsx"
    if not volunteers_file.exists():
        print(f"ERROR: {volunteers_file} not found")
        sys.exit(1)
    volunteers = parse_volunteers(str(volunteers_file))
    print(f"   Found {len(volunteers)} volunteers")
    
    # Detect duplicates
    print("\n🔍 Checking for duplicates...")
    warnings = detect_athlete_duplicates(athletes)
    if warnings:
        print(f"   Found {len(warnings)} potential issues:\n")
        for w in warnings:
            print(f"   {w}")
    else:
        print("   No duplicates detected ✓")
    
    # Encrypt and write athletes (for EmP 到)
    print("\n🔐 Encrypting athletes roster (EmP 到)...")
    athletes_json = json.dumps(athletes, ensure_ascii=False, indent=None).encode("utf-8")
    athletes_enc = encrypt_data(athletes_json, args.password_dao)
    athletes_out = output_dir / "athletes_dao.enc"
    athletes_out.write_bytes(athletes_enc)
    print(f"   Written to {athletes_out} ({len(athletes_enc)} bytes)")
    
    # Encrypt and write volunteers (for EmP 签)
    print("🔐 Encrypting volunteers roster (EmP 签)...")
    volunteers_json = json.dumps(volunteers, ensure_ascii=False, indent=None).encode("utf-8")
    volunteers_enc = encrypt_data(volunteers_json, args.password_qian)
    volunteers_out = output_dir / "volunteers_qian.enc"
    volunteers_out.write_bytes(volunteers_enc)
    print(f"   Written to {volunteers_out} ({len(volunteers_enc)} bytes)")
    
    # Encrypt both for EmP 通 (admin sees everything)
    print("🔐 Encrypting both rosters (EmP 通)...")
    athletes_tong_enc = encrypt_data(athletes_json, args.password_tong)
    volunteers_tong_enc = encrypt_data(volunteers_json, args.password_tong)
    (output_dir / "athletes_tong.enc").write_bytes(athletes_tong_enc)
    (output_dir / "volunteers_tong.enc").write_bytes(volunteers_tong_enc)
    print(f"   Written athletes_tong.enc and volunteers_tong.enc")
    
    # Summary
    print("\n✅ Done!")
    print(f"   Athletes:   {len(athletes)} records")
    print(f"   Volunteers: {len(volunteers)} records")
    print(f"\n   EmP 到 password: {args.password_dao}")
    print(f"   EmP 签 password: {args.password_qian}")
    print(f"   EmP 通 password: {args.password_tong}")


if __name__ == "__main__":
    main()
