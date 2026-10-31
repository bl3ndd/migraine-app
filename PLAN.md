# Migraine Log — plan and status

## Status

2026-10-31: built in one session from the Simply BP codebase. Done: domain model, statistics, log form, Today, Calendar, Insights, paywall, settings, onboarding, Apple Health, backup, PDF report, widget, reminders, review prompt, Tide design and icon, 58 unit + 10 UI tests green on the iPhone 13, site, ASO metadata, screenshots and header. An independent code review ran; its findings are fixed (see git log).

## What's left (owner)

1. Deploy `site/` to Vercel as project **migraine-log-site** (or change the URL in `AppLinks.swift`, `ASO.md`, `scripts/asc_fill.py`).
2. App Store Connect: create the app (name `Migraine Log: Headache Tracker`, bundle `white.tea.MigraineLog`, SKU e.g. `migraine-log-ios`), then the IAP `white.tea.MigraineLog.pro`, non-consumable, $14.99, display name "Migraine Log Pro".
3. Run `scripts/asc_fill.py` (metadata, categories, age rating, review notes) and `appstore_screenshots/upload.py` (screenshots + IAP review shot).
4. Optional: check the keyword field popularity with `aso.py keywords_migraine_meta.txt` (fresh cookie) and swap dead words.
5. TelemetryDeck: create a separate app for Migraine Log and put its App ID into `AnalyticsService.swift` (`Analytics.appID` is still Simply BP's, so signals would land in the BP dashboard).
6. Archive and upload the build via the Xcode account; App Privacy (Usage Data › Product Interaction, not linked, analytics); review video; header asset; submit with the IAP.

## Decisions

- Name in the store vs app: `Migraine Log: Headache Tracker` (exact "migraine tracker" phrase goes into the subtitle; the obvious names were taken).
- Design: direction B "Tide" (`design/`), chosen over a plum direction because purple is what every migraine app uses and Simply BP is warm blue.
- Same monetization as Simply BP: data free, insights and report paid, $14.99 once.
- Store in the app's own container, not the App Group (SwiftData's default with a group).
