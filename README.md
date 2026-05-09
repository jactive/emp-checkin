# EmP Check-In

Three offline iOS apps for the Emerald Parents Family Track & Field Meet:

| App | Purpose | Devices | Theme |
|-----|---------|---------|-------|
| **EmP 到** (Dào) | Athlete check-in | ~10 iPhones/iPads | Emerald green |
| **EmP 签** (Qiān) | Volunteer check-in | ~3 iPhones | Deep purple |
| **EmP 通** (Tōng) | Admin lookup (full PII) | Your device only | Slate |

All apps are fully offline. Rosters are AES-256-GCM encrypted and embedded in the build. Check-in logs are stored on-device and collected at end-of-event via AirDrop or cable.

---

## Prerequisites

- macOS with **Xcode 15+** installed
- [**uv**](https://docs.astral.sh/uv/getting-started/installation/) for Python package management
- [**xcodegen**](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- Apple ID signed into Xcode (free account works, paid dev account better for 365-day provisioning)
- Two roster files in Excel format:
  - `athletes.xlsx` — with columns: Age, Gender, Number (bib), FIRST Name, Last Name, event columns, Order #, Main contact name/phone/WeChat, Email, Shipping Phone/Email
  - `volunteers.xlsx` — `Sheet1` with columns: Task, Quantity, Who, Email, Phone

---

## Quick Start

```bash
./scripts/setup.sh
```

The script will:

1. Load secrets from `~/.emp-checkin/config.env` (or prompt to create it)
2. Check prerequisites (uv, xcodegen)
3. Ask for the paths to your xlsx roster files (copies them into `data/`)
4. Clean previous build artifacts
5. Install Python dependencies
6. Encrypt the rosters with per-app passwords (reports duplicate registrations)
7. Generate `EmbeddedData.swift` (roster) and `Secrets.swift` (PIN) — both gitignored
8. Generate app icons (Dào / Qiān / Tōng)
9. Generate the Xcode project

Then open the project:

```bash
./scripts/open.sh
```

Pick a target (EmPDao / EmPQian / EmPTong), select your device, Cmd+R.

---

## Secrets

All secrets live in `~/.emp-checkin/config.env` (chmod 600, not in git):

```bash
DAO_PASSWORD=<password for athlete app>
QIAN_PASSWORD=<password for volunteer app>
TONG_PASSWORD=<password for admin app>
EXPORT_PIN=<4-digit PIN for AirDrop export gate>
```

If the file is missing, `setup.sh` prompts you to create it. Back it up somewhere safe (password manager) — losing it means rebuilding with new passwords.

---

## Installing on Devices

### Before the event

1. Enable Developer Mode on each device: **Settings → Privacy & Security → Developer Mode → On** (requires restart)
2. Plug device into Mac via USB
3. In Xcode, select the target (EmPDao / EmPQian / EmPTong) + the device
4. Cmd+R to build and install
5. On the device: **Settings → General → VPN & Device Management → trust your developer certificate**
6. Repeat for each device + each app you want installed

With a free Apple ID, the provisioning profile expires in **7 days** — install within a week of the event. Paid accounts get 365 days.

### Installation time per device

- First device with a new iOS version: ~5–10 min (Xcode syncs debug symbols)
- Subsequent installs on same device: ~10 seconds

---

## Event-Day Operation

### Athletes (EmP 到)

1. Operator opens app → enters their First/Last name + password `<DAO_PASSWORD>`
2. Search by name (works order-independent — "chen qian" and "qian chen" both find Qianyu Chen)
3. Tap athlete card → confirmation sheet shows bib number prominently → Confirm Check-In
4. **Duplicates** (same name + age + gender with different contacts): disambiguation banner appears, operator taps the card and enters last 4 digits of phone number → auto-selects correct athlete
5. Filter pills: Not checked in / Checked in / All
6. Tap dashboard icon for stats

### Volunteers (EmP 签)

Same flow as Dao but simpler — no bib numbers, no disambiguation. Role is shown instead of age/events.

### Admin (EmP 通)

For your eyes only. Shows full contact info (phone, email, WeChat) for any athlete or volunteer. Phone numbers are tappable to call.

---

## End-of-Event: Collecting Data

### Primary method: AirDrop to one "collector" device

Designate one iPhone/iPad as the collector (e.g., your own).

On each operator's device:
1. Tap the share icon (↑) in the header
2. Enter PIN `<EXPORT_PIN>`
3. Tap "Send via AirDrop"
4. Pick the collector device

On the collector:
- Accept each AirDrop → files land in the Files app (Downloads)

Then:
1. Plug the collector into your Mac via cable
2. Finder → select device → **Files** tab → browse to Downloads
3. Drag all `*.json` files to `data/logs-dao/` and `data/logs-qian/` on your Mac

### Backup method: Direct cable copy

If AirDrop fails, plug any device directly into your Mac:
1. Finder → device → **Files** tab
2. Expand **EmPQian** or **EmPDao**
3. Drag the `qian_log_XXXXXXXX.json` (or `dao_log_XXXXXXXX.json`) to your Mac

### Merge into CSV reports

```bash
# Place log files in the correct folders first:
#   data/logs-dao/   ← dao_log_*.json files
#   data/logs-qian/  ← qian_log_*.json files

./bin/merge-dao.sh     # → output/athletes_report.csv
./bin/merge-qian.sh    # → output/volunteers_report.csv
```

CSVs open cleanly in Excel or Numbers (UTF-8 BOM for Chinese characters).

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
│   └── EmPCheckIn.xcodeproj/        # Generated by xcodegen (gitignored)
├── scripts/
│   ├── setup.sh                     # Main setup — run this
│   ├── clean.sh                     # Remove all generated artifacts
│   ├── open.sh                      # Open the Xcode project
│   ├── prepare_roster.py            # xlsx → encrypted JSON
│   └── merge_checkins.py            # device logs → CSV report
├── bin/
│   ├── merge-dao.sh                 # Wrapper — merge athlete logs
│   └── merge-qian.sh                # Wrapper — merge volunteer logs
├── data/                            # xlsx rosters (gitignored, contains PII)
├── output/                          # merged CSV reports (gitignored)
├── app_bundle/                      # encrypted .enc files (gitignored)
└── ~/.emp-checkin/config.env        # secrets (outside repo)
```

---

## Troubleshooting

**"Untrusted developer" on device**
→ Settings → General → VPN & Device Management → trust your cert

**"dyld_shared_cache_extract_dylibs failed"**
→ Device is low on storage. Free up space and reinstall.

**"Missing bundle ID" in simulator**
→ `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (toolchain mismatch)

**App icon shows a colored square but no character**
→ Icon cache. Delete app from home screen, restart device, reinstall.

**Wrong password on login**
→ Check `~/.emp-checkin/config.env`. If you rebuilt with new passwords, reinstall the apps.

**Fresh clone / starting over**
→ Just run `./scripts/setup.sh` — it handles everything from zero.

---

## Design Decisions (for future-me)

- **Event-sourced check-in log** — stores every check-in and undo with timestamp/operator, not just final state. Merge script replays events in timestamp order so the final CSV is always correct even with multi-device edits.
- **Per-device unique log filename** — uses `identifierForVendor` short hash so copying from multiple devices into one folder never overwrites.
- **Embedded encrypted data as base64 in Swift** — avoids iOS 26 bundle resource + codesigning quirks. Data is regenerated on every build from xlsx + passwords.
- **PIN-gated AirDrop export** — prevents accidental shares to strangers, uses numeric-only keyboard (no password autofill prompt).
- **Force light mode** — UI was designed for light backgrounds; dark mode text-on-white issues avoided.
