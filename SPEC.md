# Migraine Log — product spec (v1)

A headache and migraine diary for US adults with frequent migraines: log an attack in a few taps (even mid-attack), see headache days on a calendar, learn triggers and which medicine works, share a doctor report. Niche research and rationale: `ASO.md` and `~/Documents/projects/aso-keywords` (`results_keywords_round4_us.csv`).

## Free vs Pro

| Free | Pro ($14.99 one-time, `white.tea.MigraineLog.pro`) |
|---|---|
| Unlimited logging, edit, delete, ongoing attacks | Doctor PDF report |
| Calendar shaded by peak pain, month numbers | Insights tab: triggers, medicine results, timing, peak pain, monthly chart, period comparison |
| Today: headache-free streak, this month's headache/migraine/medication days | |
| Apple Health sync, JSON backup / restore | |
| Daily check-in reminder, widgets | |

Gating goes through `ProFeature.isLocked(_:isPro:)`. The paywall shows when a locked feature is tapped, plus once after the first saved attack. No subscription, no ads, no account.

## Attack

`Attack` (SwiftData): start, end (nil = still going), peak pain 1–10, kind (migraine / headache), locations, symptoms, possible triggers, medication doses (name, time, "did it help": yes / a little / no / not sure), note, source (manual / Apple Health), Health sample id. Limits (`AttackLimits`): pain 1–10, no future start or end, end after start, at most 7 days.

Pain bands (`IntensityLevel`): 1–3 mild, 4–6 moderate, 7–10 severe — the same three grades as Apple Health's headache severity.

## Numbers (`StatsEngine`)

- **Headache days**: calendar days touched by any attack; a day counts once; an attack past midnight counts on each day it touched; an ongoing attack counts up to now. **Migraine days**: the same for migraine entries. **Medication days**: days with at least one dose.
- **Headache-free days**: whole days since the last attack ended; 0 while one is going or one ended today.
- Monthly counts, day peaks for the calendar, trigger/symptom shares (of attacks), medicine results (grouped by name, case-insensitive), attack starts by part of day and weekday, average pain and duration (ended attacks only), change in headache days vs the previous period.
- Medication notice: 10 or more medication days in the last 30 (the ICHD-3 medication-overuse threshold) shows a "worth mentioning to your doctor" note on Today and a line in the report. No dosing advice.
- Pain 9–10 shows an emergency note with red-flag symptoms and 911.

## Data

- SwiftData in the app's own container (`groupContainer: .none`), local only. No iCloud/CloudKit (5.1.3(ii)).
- Apple Health (opt-in): finished attacks are written as `HKCategoryType(.headache)` samples with severity and metadata (attack id, pain, kind, details, doses JSON, note, `WasUserEntered`); ongoing attacks are written once they end. Reads every source; other apps' samples import as headaches with the band's middle pain. Dedup by sample id and attack id; deletions are remembered (`AppSettings.deletedIDs`).
- Widget: days headache-free (counted by the widget itself at each midnight) or the attack in progress, and this month's headache days; any tap opens the log form via `simplymigraine://log`. Snapshot in App Group `group.white.tea.MigraineLog`.
- Analytics: TelemetryDeck, feature-usage events only, never health data; off in Settings › Privacy.
- JSON backup (free): user-initiated export; restore is additive (matched on attack id).

## Out of scope for v1

Weather/barometric pressure data, cycle tracking, medication reminders, Watch app, iCloud sync, localization beyond English, anything diagnostic.
