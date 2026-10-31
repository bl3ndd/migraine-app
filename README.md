# Migraine Log

iOS migraine and headache diary. SwiftUI, SwiftData, Swift Charts, HealthKit (Headache samples), StoreKit 2, WidgetKit, TelemetryDeck (the only package; anonymous usage counts, no health data). iOS 18+, iPhone only. Started on 2026-10-31 from the Simply BP codebase (`~/Documents/projects/bp-log/BPLog`), with its own domain model and the "Tide" design so it isn't a reskin (guideline 4.3).

Docs: `SPEC.md` (what the app does), `PLAN.md` (plan and status), `ASO.md` (App Store metadata and review notes), `PRIVACY.md` (privacy policy text), `design/` (design direction and icon).

## Run

Open `MigraineLog.xcodeproj`, scheme **MigraineLog**, run on a device (the shared scheme already uses `MigraineLog.storekit`, so the Pro purchase works without App Store Connect).

Launch arguments (Debug only):

| Argument | Effect |
|---|---|
| `-UITEST` | In-memory store and throwaway settings |
| `-DEMO` / `-DEMO_LARGE` | Like `-UITEST` plus 90 days / 5 years of sample attacks, no onboarding |
| `-SKIP_ONBOARDING` | Start on Today |
| `-FREE` | Treat as not Pro, even if the sandbox owns the purchase |
| `-SNAPSHOT…` | Treat as Pro and suppress the review prompt (screenshots) |

## Test

All tests run on the connected iPhone 13 over USB (`00008110-001A345E1E62401E`):

```bash
xcodebuild test -project MigraineLog.xcodeproj -scheme MigraineLog \
  -destination 'id=<device UDID>' -allowProvisioningUpdates \
  -only-testing:MigraineLogTests          # 61 unit tests (Swift Testing)
  # -only-testing:MigraineLogUITests/MigraineLogUITests   # 9 UI tests
```

Covered: every `StatsEngine` function (headache/migraine/medication days over midnight and month edges, ongoing attacks, streak, triggers, medicine results, monthly counts), attack limits and model round trips, Health metadata/severity mapping/import/dedup, JSON backup, widget snapshot, PDF content, reminders, review prompt rules, Pro gating, performance on five years.

## Store assets

- `appstore_screenshots/export.sh <UDID>` captures raw shots on the device, `generate.py` frames them, `upload.py` uploads them (and the paywall shot for the IAP review).
- `appstore_screenshots/header/make_header.py` makes the product page header (upload 5244×2950 as Header, tick "Use header asset in search results").
- `scripts/asc_fill.py` fills metadata from `ASO.md` once the app record exists (`~/Documents/projects/kpt-diary/venv/bin/python scripts/asc_fill.py`).
