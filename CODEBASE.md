# CODEBASE.md — Agent Reference

Quick reference for AI coding agents. Optimized for scanning, not reading.

## Data Flow

```
athletes.xlsx / volunteers.xlsx
        ↓
scripts/prepare_roster.py (--password-dao/qian/tong)
        ↓
app_bundle/*.enc (AES-256-GCM encrypted JSON)
        ↓
scripts/setup.sh embeds as base64 strings
        ↓
EmbeddedData.swift (static let athletesDaoBase64, etc.)
        ↓
CryptoService.decryptRoster() at login
        ↓
[Athlete] / [Volunteer] in memory
        ↓
CheckInStore.checkIn()/undoCheckIn() → local JSON log
        ↓
exportLogToFile() → JSON via AirDrop
        ↓
scripts/analyze_checkins.py / analyze_qian.py
        ↓
report.html
```

## Project Structure (project.yml)

Three iOS app targets, all share `Sources/Shared/`:

| Target | Bundle ID | Sources | Purpose |
|--------|-----------|---------|---------|
| EmPDao | org.emeraldparents.emp-dao | Shared + Dao | Athlete check-in (green) |
| EmPQian | org.emeraldparents.emp-qian | Shared + Qian | Volunteer check-in (purple) |
| EmPTong | org.emeraldparents.emp-tong | Shared + Tong | Admin lookup with full PII (slate) |

Minimum iOS 17.0, Swift 5.9.

## Models (Sources/Shared/Models/)

### Athlete.swift
```swift
struct Athlete: Identifiable, Codable, Hashable {
    let id: String           // Same as bibNumber (string)
    let firstName: String
    let lastName: String
    let age: Int
    let gender: String
    let events: [String]     // ["4×100m Relay", "100m", etc.]
    let bibNumber: Int
    let contactName: String
    let contactPhone: String
    let contactWeChat: String
    let contactEmail: String
    let shippingPhone: String  // Used for phoneLast4 disambiguation
    
    var fullName: String     // Computed: "\(firstName) \(lastName)"
    var searchTokens: [String]  // [firstName.lowercased(), lastName.lowercased(), bibNumber]
    var phoneLast4: String   // Last 4 digits of shippingPhone
}
```

### Volunteer.swift
```swift
struct Volunteer: Identifiable, Codable, Hashable {
    let id: String           // Same as volunteerNumber (string)
    let volunteerNumber: Int
    let name: String         // Full name
    let role: String         // Task (Column A in main sheet, pipe-delimited if multiple)
    let otherRoles: String   // Column D
    let groupName: String    // Tab name from group sheets
    let groupInfo: [String]  // ["Header: Value", ...] from group sheet columns
    let email: String
    let phone: String
    let wechat: String
    
    var searchTokens: [String]  // name.split + volunteerNumber
    var phoneLast4: String
}
```

### CheckInEvent.swift
```swift
struct CheckInEvent: Codable, Identifiable {
    let id: UUID
    let personId: String     // Athlete.id or Volunteer.id
    let action: Action       // .checkIn or .undo
    let operatorName: String // Who performed the check-in
    let device: String       // deviceName_shortId
    let timestamp: Date
}

struct CheckInState {
    var isCheckedIn: Bool
    var checkedInAt: Date?
    var checkedInBy: String?
}
```

## Services (Sources/Shared/Services/)

| Service | Purpose |
|---------|---------|
| `CheckInStore.swift` | @Observable store. Manages events array, states dict, persistence to Documents/. Methods: `checkIn()`, `undoCheckIn()`, `isCheckedIn()`, `exportLogToFile()`. |
| `SearchService.swift` | Fuzzy search with Levenshtein distance. `searchAthletes()`, `searchVolunteers()`. Scoring: exact=10, prefix=5-9, fuzzy≤2 edits. |
| `CryptoService.swift` | AES-256-GCM decryption. Key derived from SHA256(password). `decryptRoster<T>()` returns decoded model array. |
| `DisambiguationService.swift` | Handles same-name athletes. `findDuplicateGroups()` returns groups with different phoneLast4. `resolve()` matches 4-digit input. |
| `EmbeddedData.swift` | **GENERATED** — base64 encrypted roster data. `athletesDaoData`, `volunteersQianData`, etc. Also `availableAgesDao: [Int]`. |
| `Secrets.swift` | **GENERATED** — `exportPIN` for AirDrop confirmation. |

## View Structure

### Dao (Athlete Check-In)
```
DaoApp.swift → DaoRootView → [AgeSelectionView] → LoginView → DaoMainView
                                    ↓
                              selectedAges: Set<Int>  (pre-login age filter)
```
- `DaoRootView.swift:12-50`: 3-step flow: age selection → login → main
- `DaoMainView.swift`: Search, filter pills (Pending/Done/All), athlete cards, disambig banner
- Age selection before login restricts which athletes the operator sees

### Qian (Volunteer Check-In)
```
QianApp.swift → QianRootView → LoginView → QianMainView
                                              ↓
                                        QianDashboardView (stats sheet)
```
- `QianRootView.swift:7-18`: Simple login → main
- `QianMainView.swift`: Same pattern as Dao, no age filter, no disambiguation needed
- `QianDashboardView.swift`: Live check-in stats

### Tong (Admin Lookup)
```
TongApp.swift → TongRootView → LoginView → TongMainView
```
- `TongRootView.swift:7-18`: Loads both athletes AND volunteers
- `TongMainView.swift`: Segmented picker (Athletes/Volunteers), full PII display, tappable phone links
- No check-in functionality, read-only lookup

### Shared Views (Sources/Shared/Views/)
- `LoginView.swift`: Operator name + password, calls `CryptoService.decryptRoster()`
- `ExportConfirmView.swift`: PIN entry before export
- `ExportShareSheet.swift`: UIActivityViewController wrapper for AirDrop

## Scripts

### prepare_roster.py — xlsx → encrypted JSON

**Expected athletes.xlsx columns** (0-indexed):
- 0: age (int)
- 1: gender (string)
- 2: bibNumber (int)
- 3: firstName (string)
- 4: lastName (string)
- 5-8: event flags (4×100m, 100m, 400m, 1600m)
- 10: contactName
- 11: contactPhone
- 12: contactWeChat
- 13: contactEmail
- 14: shippingPhone

Sheet names tried: `"All"`, `"Athletes 2025-05-22"`

**Expected volunteers.xlsx structure:**
- Main sheet: `"总表0513"` or `"Sheet1"`
- Columns: A=Task, B=Volunteer No., C=Who, D=Other roles, E=Email, F=Phone, G=WeChat
- Other sheets: Group assignments. Headers must include "First Name", "Last Name". Tab name = groupName.
- "ignored" columns skipped; others become groupInfo entries.

### analyze_checkins.py — Athlete report
- Reads `data/athletes.xlsx` for roster
- Reads JSON exports from `--input-dir`
- Filters events before EVENT_START (pre-event testing)
- Resolves checkIn/undo pairs
- Generates HTML: summary cards, heartbeat chart, by-age breakdown, multi-device alerts

### analyze_qian.py — Volunteer report
- Same pattern, reads `data/volunteers.xlsx`
- Groups roster by sheet name for "Roster by Group" tabs
- Ungrouped volunteers → "其他 Others"

## Generated Files (DO NOT EDIT)

| File | Generator |
|------|-----------|
| `EmPCheckIn/Sources/Shared/Services/EmbeddedData.swift` | `setup.sh` |
| `EmPCheckIn/Sources/Shared/Services/Secrets.swift` | `setup.sh` |
| `EmPCheckIn/EmPCheckIn.xcodeproj/` | `xcodegen generate --spec project.yml` |
| `EmPCheckIn/Sources/*/Assets.xcassets/AppIcon.appiconset/` | `setup.sh` (Pillow icon generation) |
| `app_bundle/*.enc` | `prepare_roster.py` |
| `app_bundle/ages_dao.json` | `prepare_roster.py` |

## Wiggly Parts (Fragile xlsx Dependencies)

`prepare_roster.py` hardcodes column indices and sheet names:
- Athletes: columns 0-14 in specific order, sheet name "All" or "Athletes 2025-05-22"
- Volunteers: main sheet "总表0513", columns A-G, group sheets must have "First Name"/"Last Name" headers

If xlsx format changes, either:
1. Rename columns in Excel to match expected names
2. Modify `parse_athletes()` or `parse_volunteers()` in `prepare_roster.py`

## Conventions

- **Naming**: PascalCase for types, camelCase for properties/methods, SCREAMING_SNAKE for env vars
- **File organization**: One model per file, services are static enums or @Observable classes
- **Colors**: Defined in `AppColors.swift` — `.emeraldGreen`, `.deepPurple`, `.warmSlate` + light/dark variants
- **Encryption**: AES-256-GCM, key = SHA256(password), nonce prepended to ciphertext
- **Check-in log**: Append-only, replayed on load to rebuild states dict
- **Export filename**: `{appPrefix}_checkin_{ISO8601}_{deviceName}_{deviceShortId}.json`
