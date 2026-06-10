# EmP Check-In

Offline iOS check-in system for Emerald Parents (EmP) Association events.

## Overview

Three apps for different check-in needs:

| App | Purpose | Devices | Theme |
|-----|---------|---------|-------|
| **EmP 到** (Dào) | Athlete check-in | ~10 iPads | Emerald green |
| **EmP 签** (Qiān) | Volunteer check-in | ~3 iPhones | Deep purple |
| **EmP 通** (Tōng) | Admin lookup (full PII) | Organizer device only | Slate |

**Key features:**
- Fully offline operation (no WiFi/cellular required during event)
- Embedded roster with AES-256-GCM encryption
- Multi-device support (each device exports independently)
- Check-in logging (every check-in/undo timestamped with operator)
- PII-free HTML analysis reports (for athletes and volunteers)

---

## Glossary

| Term | Definition |
|------|------------|
| **App builder** | The person who compiles the apps and installs them on devices before the event |
| **Operator** | A volunteer who uses Dao or Qian to check people in during the event |
| **Organizer** | Event leadership who may need to look up contact info using Tong |
| **Roster** | The Excel files (athletes.xlsx, volunteers.xlsx) containing participant data |
| **Export** | The JSON file each device creates containing check-in records |
| **Bib number** | The athlete's assigned number, printed on their sticker |
| **Volunteer number** | The volunteer's assigned number |

These terms are defined again when first used in the document, so you don't need to flip back here.

See [CODEBASE.md](CODEBASE.md) for coding agent reference (AI assistant quick-start guide).

---

## Prerequisites

This README is for the **app builder** (see Glossary).

### Required Skills
- Familiarity with **macOS Terminal** (running shell commands)
- Basic understanding of **Xcode** (select target app like EmPQian, connect device, build and install)
- iOS device management (enabling Developer Mode, trusting certificates)

### Required Software

| Tool | Install | Purpose |
|------|---------|---------|
| macOS + Xcode | [developer.apple.com/xcode](https://developer.apple.com/xcode/) | Check [version compatibility](https://developer.apple.com/support/xcode/); download from App Store or [developer.apple.com/download](https://developer.apple.com/download/) |
| [Homebrew](https://brew.sh/) | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` | macOS package manager |
| [uv](https://docs.astral.sh/uv/) | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | Python package manager |
| [xcodegen](https://github.com/yonaskolb/XcodeGen) | `brew install xcodegen` | Generates Xcode project from `project.yml` (project file not stored in git) |

### Required Accounts
- **Apple ID** signed into Xcode → Settings → Accounts (free account = 7-day app provisioning, paid = 365 days)

### Required Data Files (June 7, 2026 Event)

**⚠️ This is the wiggly part.** The code expects specific column names and sheet structures. If the xlsx differs, the app builder will either need to rename columns in Excel or vibe code `scripts/prepare_roster.py`. Neither is fun. Ideally we'd standardize the upstream registration forms, but for a once-a-year event, manual adjustment is the pragmatic choice.

- **`athletes.xlsx`**: Athlete roster from registration (e.g., Google Forms export). Must include: bib number, name, age, gender, contact info.
- **`volunteers.xlsx`**: Volunteer roster with main sheet (`总表0513`) listing all volunteers, plus separate tabs for each team (年龄组领队, 径赛组, etc.) maintained by team coordinators.

If column names don't match, `setup.sh` will report errors. Check `scripts/prepare_roster.py` for expected column names.

---

## Quick Start

### 1. Initial Setup

```bash
cd EmP-CheckIn

# Run setup (interactive wizard)
./scripts/setup.sh
```

The setup script will:
1. Load secrets from `~/.emp-checkin/config.env` (or prompt to create it)
2. Check prerequisites (uv, xcodegen)
3. Ask for paths to your xlsx roster files (copies them into `data/`)
4. Clean previous build artifacts
5. Install Python dependencies
6. Encrypt rosters with per-app passwords (reports duplicate registrations)
7. Generate `EmbeddedData.swift` and `Secrets.swift` (gitignored)
8. Generate app icons
9. Generate the Xcode project

### 2. Open Xcode Project

```bash
./scripts/open.sh
```

### 3. Install on Device

1. Enable Developer Mode: **Settings → Privacy & Security → Developer Mode → On** (restart required)
2. Connect device via USB
3. In Xcode: select target (EmPDao / EmPQian / EmPTong) + your device
4. Cmd+R to build and install
5. On device: **Settings → General → VPN & Device Management → trust your developer certificate**

---

## Secrets Management

The setup script will prompt you to create `~/.emp-checkin/config.env` with these values:

```bash
DAO_PASSWORD=<password for athlete app>
QIAN_PASSWORD=<password for volunteer app>
TONG_PASSWORD=<password for admin app>
EXPORT_PIN=<4-digit PIN for data export>
```

**Important:** Back up this file in a secure location. Losing it means rebuilding apps with new passwords.

---

## Event-Day Operation

### Athletes (EmP 到)

1. Operator opens app → enters their name + password
2. Search by name or bib number
3. Tap athlete card → confirmation shows bib number → Confirm Check-In
4. **Same name found (重名了)**: when multiple athletes match, a banner appears asking for last 4 digits of phone to identify the correct one
5. Filter pills: Not checked in / Checked in / All
6. Tap dashboard icon for live stats

### Volunteers (EmP 签)

Same flow as Dao. Searchable by name or volunteer number. Shows role instead of age/events. No "same name" disambiguation needed.

### Admin (EmP 通)

For organizers only. Shows full contact info (phone, email, WeChat). Phone numbers are tappable.

---

## End-of-Event: Data Collection

### Method 1: AirDrop (Recommended)

Designate one device as the "collector" (e.g., the app builder's iPhone).

**On each operator's device:**
1. Tap share icon (↑) in header
2. Enter PIN
3. Tap "Send via AirDrop"
4. Select the collector device

**On the collector:**
- Accept each AirDrop → files land in Files app (Downloads)

**Transfer to Mac:**
1. Connect collector to Mac via USB
2. Finder → device → **Files** tab → Downloads
3. Drag export files to Mac

### Method 2: Direct Cable

1. Connect any device to Mac via USB
2. Finder → device → **Files** tab → expand **EmPDao** or **EmPQian**
3. Drag the `*_log_*.json` files to Mac

---

## Post-Event Analysis

### Folder Structure

Organize collected data by event date:

```
data/
├── athletes.xlsx          # Master roster (required)
├── volunteers.xlsx        # Master roster (required)
└── 2026-06-07/           # Event date folder
    ├── dao/
    │   ├── exports/       # Export files from iPads
    │   │   ├── dao_checkin_2026-06-07_*.json
    │   │   └── ...
    │   └── report.html    # Generated analysis
    └── qian/
        ├── exports/       # Export files from iPhones
        │   ├── qian_checkin_2026-06-07_*.json
        │   └── ...
        └── report.html    # Generated analysis
```

### Generate HTML Reports

```bash
# Athlete check-in report
uv run python scripts/analyze_checkins.py --input-dir data/2026-06-07/dao/exports
# → Generates: data/2026-06-07/dao/report.html

# Volunteer check-in report
uv run python scripts/analyze_qian.py --input-dir data/2026-06-07/qian/exports
# → Generates: data/2026-06-07/qian/report.html
```

### Report Features

**Athletes (Dao):**
- Summary cards: check-in rate, checked in, missing, total
- Heartbeat chart: check-ins per minute
- By Age: stacked bar chart
- By Gender: doughnut chart
- Gender × Age: grouped bar chart
- Roster by Age: clickable tabs with bib numbers
- Multi-device alerts: athletes checked in on multiple devices

**Volunteers (Qian):**
- Summary cards: check-in rate, checked in, missing, total
- Heartbeat chart: check-ins per minute
- Roster by Group: clickable tabs based on Excel sheet names
- "其他 Others" tab for ungrouped volunteers

**Privacy:** Reports use bib/volunteer numbers only, no names, phones, or emails. Safe to share publicly.

---

## Project Structure

```
.
├── EmPCheckIn/
│   ├── project.yml                  # XcodeGen spec (3 targets)
│   ├── Sources/
│   │   ├── Shared/                  # Models, services, login, crypto
│   │   ├── Dao/                     # EmP 到 views
│   │   ├── Qian/                    # EmP 签 views
│   │   └── Tong/                    # EmP 通 views
│   └── EmPCheckIn.xcodeproj/        # Generated (gitignored)
├── scripts/
│   ├── setup.sh                     # Main setup, run this first
│   ├── clean.sh                     # Remove all generated artifacts
│   ├── open.sh                      # Open Xcode project
│   ├── prepare_roster.py            # xlsx → encrypted JSON
│   ├── analyze_checkins.py          # Athlete check-in → HTML report
│   ├── analyze_qian.py              # Volunteer check-in → HTML report
│   └── checkin_analysis/            # Shared analysis modules
├── data/                            # Rosters + event data (gitignored, PII)
├── app_bundle/                      # Encrypted data files (gitignored)
└── ~/.emp-checkin/config.env        # Secrets (outside repo)
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Untrusted developer" on device | Settings → General → VPN & Device Management → trust your cert |
| "dyld_shared_cache_extract_dylibs failed" | Device low on storage. Free space and reinstall |
| "Missing bundle ID" in simulator | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| App icon shows colored square, no character | Delete app, restart device, reinstall |
| Wrong password on login | Check `~/.emp-checkin/config.env`. Rebuild if passwords changed |
| Fresh clone / starting over | Run `./scripts/setup.sh` which handles everything from zero |

---

## Design Decisions

- **Check-in log**: Every check-in/undo is stored with timestamp and operator name. Analysis scripts combine exports from all devices and flag duplicates.
- **Unique filenames per device**: Copying from multiple devices to one folder won't overwrite files.
- **Encrypted roster embedded in app**: No network calls during event. Regenerated on every build.
- **PIN-gated export**: Prevents accidental data sharing.
- **Light mode only**: UI designed for outdoor readability.

---

## Archiving & Restoration

To preserve the entire project (including data) for future use:

```bash
# Archive (from parent directory)
tar -czvf EmP-CheckIn-2026-06-07.tar.gz EmP-CheckIn/

# Restore
tar -xzvf EmP-CheckIn-2026-06-07.tar.gz
cd EmP-CheckIn
./scripts/setup.sh  # Regenerates Xcode project + encrypted data
```

**Note:** The `data/` folder contains PII and is gitignored. Include it in your archive but never commit to git.

---

## FAQ

**Why can't I just download the app from App Store?**

Not every device has cellular, and we cannot rely on reliable internet access at future event venues, so all roster data is embedded in the app at build time, meaning no network dependency during the event. Is offline more secure than an online system? Not necessarily. A well-built cloud system with proper auth would arguably be more secure than devices floating around with local data. But for a once-a-year community event, the simplicity of "no server, no accounts, no sync" wins over building and maintaining cloud infrastructure. If events become monthly, revisit this since rebuilding apps 12x/year would justify the investment in cloud infrastructure.

**What if battery dies mid-event?**

App builder should ask all operators to bring power banks. Data is saved to device storage after each check-in, so even a crash or restart won't lose data. Just reopen the app and continue. However, if the app is **uninstalled**, all check-in data is permanently lost, so export before deleting.

**How do I know if all data was collected?**

Count the JSON files. Each device exports one file. If you had 8 iPads running Dao, you should have 8 JSON files. The analysis report shows device count in the subtitle. In the 2026 event, the app builder collected exports via AirDrop from each device, then texted the JSON files to themselves as a backup before leaving the venue.

**What if two devices checked in the same person?**

The HTML report flags this under "Multi-Device Check-Ins." It's not an error. Could be operator mistake, or athlete visited two stations. The person is still counted as checked in once in the summary.

**Why three separate apps instead of one?**

Role separation. Dao operators only see athletes in their assigned age groups. Qian operators only see volunteers. Tong shows everything including full contact info (PII), restricted to organizers. One app with role switching would risk accidental PII exposure.

**What's the difference between passwords and PIN?**

- **App passwords** (DAO_PASSWORD, QIAN_PASSWORD, TONG_PASSWORD): Required to log in and use the app. Each app has its own password. Share with operators before the event.
- **Export PIN** (EXPORT_PIN): Required to export check-in data via AirDrop. Prevents accidental data sharing. Only the app builder needs this.

The exported JSON files contain bib/volunteer numbers, timestamps, and operator names. No other PII (names, phones, emails) is in the export. Someone with the export can see "bib 123 was checked in at 12:34 by operator Alice" but cannot identify who bib 123 is without access to the roster.

**Why does the operator enter their name at login?**

The name is stored with each check-in event for accountability. Currently not used for validation or reports, but available if needed to trace who checked in whom. It also makes the process feel more formal.

**Why does the app need Developer Mode on iOS?**

Apps installed via Xcode (not App Store) require Developer Mode. This is an Apple security feature, not something we control. It's a one-time setup per device.
