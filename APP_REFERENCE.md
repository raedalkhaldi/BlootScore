# BlootScore — App Reference

> Auto-maintained reference for the BlootScore iOS app codebase.
> Last updated: 2026-04-17

---

## Overview

**BlootScore** is an Arabic-language (RTL) iOS scoring app for the Khaleeji card game **Baloot** (البلوت).
It features AI-powered voice input via Claude Haiku, admin-configurable voice feedback per game state,
and Firestore-backed settings — all without any Firebase SDK dependency (pure REST).

| Field               | Value                              |
|---------------------|------------------------------------|
| Bundle ID           | `com.bloot.BlootScore`             |
| Platform            | iOS (SwiftUI, UIKit bridging)      |
| Min Deployment      | iOS 16+                            |
| Language             | Swift 5.9+                         |
| External SDKs       | **None** (zero SPM / CocoaPods)    |
| Firebase Project    | `invlog-6088f` (shared w/ FlickMatch) |
| CI/CD               | GitHub Actions → TestFlight        |
| Winning Score       | 152 points                         |

---

## Architecture at a Glance

```
┌──────────────────────────────────────────────────┐
│                    BlootApp                       │
│  @main entry, injects GameViewModel + VoiceStore  │
└──────────┬───────────────┬───────────────────────┘
           │               │
    ┌──────▼──────┐  ┌─────▼──────────┐
    │  MainView   │  │  WinnerView    │
    │ (scoreboard)│  │ (game-over)    │
    └──────┬──────┘  └────────────────┘
           │
    ┌──────▼──────────────────────────────────────┐
    │  GameViewModel (scoring engine)              │
    │  SpeechManager (mic → text)                  │
    │  GameParser / LocalVoiceParser (text → round)│
    └─────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────┐
    │  VoiceStore   (audio playback + 2-layer mgmt)│
    │  VoiceRecorder (AVAudioRecorder wrapper)     │
    │  FirebaseREST  (auth + Firestore REST)       │
    └─────────────────────────────────────────────┘
```

---

## File Inventory

### App Entry

| File | Purpose |
|------|---------|
| `BlootApp.swift` | `@main` App struct. Creates `GameViewModel`, `FirebaseREST`, `VoiceStore`. Bootstraps Firebase + voices on `.task`. Injects environment objects. Presents `WinnerView` sheet when `vm.isGameOver`. |

### Screens / Views

| File | Purpose |
|------|---------|
| `MainView.swift` | Primary scoreboard. Two modes: **simple** (2 scores + mic) and **detailed** (game type, buyer, raw points, declarations, kaboot, dobble). Contains `ScoreCard`, `ProgressBar`, `RoundHistory`, `DecStepper`, `RoundedCorner`. Voice detection triggers `VoiceStore.play()` on each new round. "New game" button with confirmation dialog. |
| `WinnerView.swift` | Game-over screen. Shows trophy, winner name, final scores, round count. Plays `.barber` (if one team = 0) or `.finalWin` voice on appear. Restart options: same teams / change teams. |
| `AdminSettingsView.swift` | Voice settings screen (all users, not just admin). Admin toggle at top (visible only if `isAdmin`). Per-state rows: record, upload file, play, restore default. `DocPicker` UIViewControllerRepresentable for audio file import. Admin claim button when no admin exists. |
| `APIKeyView.swift` | Anthropic API key input. SecureField, saved to UserDefaults (`anthropic_api_key`). Link to Anthropic console. |

### Core Logic

| File | Types | Purpose |
|------|-------|---------|
| `GameViewModel.swift` | `GameType`, `Declarations`, `RoundResult`, `Round`, `GameViewModel` | Scoring engine. Converts raw card points → "bant" (بنط) for sun/hokm. Handles kaboot, dobble, declarations. Add/update/delete/undo rounds. Winner detection at 152 pts. |
| `GameParser.swift` | `ParsedRound`, `GameParser`, `ParserError` | AI parsing via Claude Haiku API. `parse()` for detailed mode (extracts all fields). `parseSimple()` for simple mode (2 numbers). Built-in API key (XOR-obfuscated). |
| `LocalVoiceParser.swift` | `SimpleRoundResult`, `LocalVoiceParser` | Offline fallback parser. Regex-based digit extraction. Arabic numeral normalization (٠-٩ → 0-9). |
| `SpeechManager.swift` | `SpeechManager` | iOS Speech Recognition (`SFSpeechRecognizer`, locale `ar-SA`). Auto-stop on 2 seconds silence. Streams transcript via `@Published`. |

### Voice System

| File | Types | Purpose |
|------|-------|---------|
| `VoiceStore.swift` | `VoiceState` (12 cases), `VoiceSource`, `DefaultClip`, `VoiceStore` | Central voice manager. Two-layer: local overrides (Documents/) on top of admin defaults (Firestore base64). `effectiveEnabled()` prefers local toggle → admin default → true. `play()` chain: local file → cached default → fetch from Firestore → play. `detect()` maps game state to voice state. |
| `VoiceRecorder.swift` | `VoiceRecorder` | AVAudioRecorder wrapper. M4A, 22050Hz, mono, 32kbps. Explicit mic permission before recording. `stop()` validates file size > 0. `base64(url:maxBytes:)` for Firestore upload (max 700KB). |

### Firebase / Backend

| File | Types | Purpose |
|------|-------|---------|
| `FirebaseREST.swift` | `FirebaseConst`, `FBError`, `FSValue`, `FSDocument`, `FirebaseREST` | Pure REST client — no Firebase SDK. Anonymous auth via Identity Toolkit. Token refresh via `securetoken.googleapis.com`. Firestore CRUD via REST. Refresh token persisted in iCloud-synced Keychain (`kSecAttrSynchronizable`). |

### Config & Resources

| File | Purpose |
|------|---------|
| `GoogleService-Info.plist` | Firebase config (API key, project ID, GCM sender, app ID). |
| `PrivacyInfo.xcprivacy` | Apple Privacy Manifest. Declares: UserDefaults (CA92.1), FileTimestamp (C617.1), DiskSpace (E174.1). No tracking, no data collection. |
| `Assets.xcassets/` | App icon (multiple sizes), AccentColor. |
| `firestore.rules` | Firestore security rules. `bloot_config/admin`: first-claim pattern. `bloot_voices/*`: read all authed, write admin only. Everything else denied. |
| `firebase.json` | Firebase CLI config, references `firestore.rules`. |
| `.github/workflows/testflight.yml` | CI/CD: macOS 14 runner, Xcode 16, certificate + profile install, archive → TestFlight upload. |

---

## Game States (VoiceState)

12 detectable states, each with an optional admin-set default voice and user-overridable local clip:

| Enum Case      | Key              | Arabic Title                | Trigger Condition |
|----------------|------------------|-----------------------------|-------------------|
| `.kaboot`      | `kaboot`         | كبوت                        | Round is kaboot (clean sweep) |
| `.doubleWin`   | `double_win`     | دبل — فوز                   | Dobble round, buyer won |
| `.doubleLoss`  | `double_loss`    | دبل — خسارة                 | Dobble round, buyer lost |
| `.buyerLost`   | `buyer_lost`     | المشتري خسر                 | Normal round, buyer lost |
| `.buyerWon`    | `buyer_won`      | المشتري كسب                 | Normal round, buyer won |
| `.tieBuyerLost`| `tie_buyer_lost` | تعادل في الدبل              | Tie in dobble (buyer loses) |
| `.nearWin`     | `near_win`       | اقتراب من الفوز (140+)       | Either team ≥ 140 points |
| `.finalWin`    | `final_win`      | فوز نهائي                    | Game over (normal) |
| `.bigGap`      | `big_gap`        | فرق كبير (50+)               | Score difference ≥ 50 |
| `.declaration` | `declaration`    | إعلان (بلوت/سرا/مية)        | Declaration made |
| `.gameStart`   | `game_start`     | بداية لعبة جديدة             | New game / reset |
| `.barber`      | `barber`         | الحلاق (0 مقابل 152)         | Game over, one team = 0 |

### Detection Priority (in `VoiceStore.detect()`):
1. Final win / barber (score ≥ winning score)
2. Kaboot
3. Dobble win/loss
4. Near win (140+)
5. Big gap (50+)
6. Buyer won / buyer lost

---

## Voice System Architecture

```
                    ┌───────────────────┐
                    │   Firestore       │
                    │ bloot_voices/{key}│
                    │  audioBase64      │
                    │  enabled          │
                    └────────┬──────────┘
                             │ fetch on play (cached)
                    ┌────────▼──────────┐
                    │  defaults_cache/  │
                    │  {key}.m4a        │
                    └────────┬──────────┘
                             │ fallback
    ┌────────────────────────┼──────────────────────┐
    │  Local Overrides       │                      │
    │  overrides/{key}.m4a   │  ← user recordings   │
    │  (takes priority)      │                      │
    └────────────────────────┘                      │
                                                    │
    UserDefaults: voiceEnabled_{key}                │
    (local toggle, overrides admin's enabled flag)  │
    ────────────────────────────────────────────────┘
```

**Source priority**: custom (local) > defaultAdmin (Firestore) > none

**Playback chain** (`VoiceStore.playAsync()`):
1. Check `effectiveEnabled()` → skip if disabled
2. Try local override file → play
3. Try cached default → play
4. Fetch from Firestore → decode base64 → cache to disk → play

**File limits**:
- Local override: max 2MB (`saveLocalOverride`)
- Firestore upload: max 700KB base64 (`VoiceRecorder.base64()`)

---

## Firebase Setup

### Project: `invlog-6088f` (shared with FlickMatch)

**Auth**: Anonymous sign-in (no user-facing login).
Refresh token stored in iCloud Keychain → survives reinstalls, preserves admin UID.

**Firestore Collections** (prefixed `bloot_` to isolate from FlickMatch):

| Collection/Doc            | Fields                          | Access |
|---------------------------|---------------------------------|--------|
| `bloot_config/admin`      | `adminUID: string`              | Read: any authed. Create: first user (UID must match). Update: current admin only. |
| `bloot_voices/{state}`    | `enabled: bool`, `audioBase64: string`, `format: string`, `updatedAt: timestamp` | Read: any authed. Write: admin only (verified via `get()` on admin doc). |

### Admin Claim Pattern:
1. On first launch, `bloot_config/admin` doesn't exist
2. User taps "تعيين هذا الجهاز كأدمن" button
3. `claimAdmin()` writes their UID → Firestore `create` rule allows if `adminUID == auth.uid`
4. Subsequent users see admin already claimed → button hidden
5. Admin survives reinstalls via iCloud Keychain refresh token

---

## Scoring Rules

### Game Types

| Type | Arabic | Raw Total | Base Points | Kaboot Base |
|------|--------|-----------|-------------|-------------|
| Sun  | صن     | 130       | 26          | 44          |
| Hokm | حكم    | 162       | 16          | 25          |

### Raw → Points Conversion

**Sun** (doubled):
- `raw / 10 * 2` (integer division)
- Remainder = 5 → add 1 (represents ×2 of 0.5)
- Remainder > 5 → round up

**Hokm** (no doubling):
- `raw / 10` (integer division)
- Remainder > 5 → round up
- Remainder = 5 → stays (no rounding)

### Declarations (Mashare3)

| Name         | Arabic     | Sun Points | Hokm Points |
|--------------|------------|------------|-------------|
| Sara (سرا)   | سرا/سارة  | 4          | 2           |
| Fifty (خمسين)| خمسين      | 10         | 5           |
| Hundred (مية)| مية/مئة    | 20         | 10          |
| 400 (أربع مية)| أربع مية  | 40         | Sun only    |
| Bloot (بلوت) | بلوت       | N/A        | 2 (Hokm only)|

### Special Round Types

- **Kaboot** (كبوت/كنس): Buyer takes all points. Score = kabootBase + buyerDeclarations.
- **Dobble** (دبل): All points ×2. Tie = buyer loses.
- **Normal**: If buyer's total (cards + declarations) < other's → buyer gets 0, other gets basePoints + all declarations.

---

## AI Voice Input

### Detailed Mode (`GameParser.parse()`)
- Model: `claude-haiku-4-5-20251001`
- Extracts: gameType, buyerIsTeam1, buyerRaw, isKaboot, isDobble, team1Declarations, team2Declarations
- Returns JSON parsed into `ParsedRound`

### Simple Mode (`GameParser.parseSimple()`)
- Model: `claude-haiku-4-5-20251001`
- Extracts: t1 (team 1 score), t2 (team 2 score)
- Max tokens: 50

### Fallback (`LocalVoiceParser`)
- No API call — pure regex
- Arabic numeral normalization
- Keyword detection: صن/حكم/كبوت/دبل

### Speech Recognition (`SpeechManager`)
- Locale: `ar-SA` (Saudi Arabic)
- Auto-stop: 2 seconds of silence
- Publishes `autoStoppedText` for automatic processing

---

## Key UserDefaults Keys

| Key                         | Type   | Purpose |
|-----------------------------|--------|---------|
| `anthropic_api_key`         | String | User's Anthropic API key (optional, built-in key exists) |
| `voiceEnabled_{state.key}`  | Bool   | Per-state local voice enabled toggle |

---

## Local File Storage

```
Documents/
├── voices/
│   ├── overrides/          # User's custom recordings
│   │   ├── kaboot.m4a
│   │   ├── double_win.m4a
│   │   └── ...
│   └── defaults_cache/     # Cached admin defaults from Firestore
│       ├── kaboot.m4a
│       └── ...
```

---

## CI/CD Pipeline

**Trigger**: Push to `main` or manual dispatch.
**Runner**: `macos-14` with Xcode 16.
**Steps**:
1. Checkout code
2. Install Apple Distribution certificate (from secrets)
3. Install provisioning profile
4. Setup App Store Connect API key
5. Patch `project.pbxproj`: Automatic → Manual signing, inject team/profile, set build number from date
6. `xcodebuild archive` with manual signing
7. `xcodebuild -exportArchive` → upload to TestFlight

**Required GitHub Secrets**:
`CERTIFICATE_P12`, `P12_PASSWORD`, `PROVISIONING_PROFILE`, `TEAM_ID`, `PROFILE_NAME`,
`APPSTORE_API_KEY_P8`, `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`

---

## App Store Readiness Checklist

| Item | Status |
|------|--------|
| PrivacyInfo.xcprivacy | Done |
| Privacy Policy URL | Pending |
| App Store description/keywords | Pending |
| Screenshots | Pending |
| Age rating | Pending |
| Export compliance | Pending |
| Review notes for Apple | Pending |

---

## Important Notes

1. **No Firebase SDK** — everything is REST. This keeps build times fast and avoids SPM complexity.
2. **Shared Firebase project** — `invlog-6088f` is also used by FlickMatch. All BlootScore data uses `bloot_` prefix. Firestore rules deny everything outside `bloot_*`.
3. **iCloud Keychain** — Firebase refresh token syncs via iCloud, so the same anonymous UID persists across reinstalls and devices. This is critical for admin persistence.
4. **Voice UGC concern** — Admin sets global defaults, users override locally only. No cross-user content sharing → avoids Apple UGC requirements.
5. **Built-in API key** — XOR-obfuscated Anthropic key in `GameParser.swift`. Users can supply their own via `APIKeyView`.
6. **RTL throughout** — `.environment(\.layoutDirection, .rightToLeft)` applied at app root and on every sheet/navigation.
