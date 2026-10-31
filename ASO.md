# App Store metadata (US, en-US)

Built from the niche research in `~/Documents/projects/aso-keywords` (Oct 2026, Apple Ads popularity + iTunes top-10 checks, `results_keywords_round4_us.csv`).

## Why this name

With near-zero ratings our apps rank only for phrases in the title and subtitle (Mezame is #1 for its title phrase). The cluster:

| Keyword | Popularity | Top-5 median ratings | Note |
|---|---|---|---|
| migraine tracker | 46 | 259 | **primary**, Migraine Buddy is #1, the rest is weak |
| headache tracker | 40 | 3k | in the name |
| migraine | 39 | 840 | head term |
| headache diary | 26 | 164 | |
| migraine diary | 25 | 81 | |
| headache | 25 | 164 | |
| headache log / migraine log / migraine app | 5 | — | dead, but "Migraine Log" is the brand |

"Migraine Tracker: Headache Log" and "Migraine Tracker & Diary" are already taken as names, so the exact top phrase goes into the subtitle and the name carries the brand plus "Headache Tracker".

## Metadata

- **Support URL:** `https://migraine-log-site.vercel.app/support.html`
- **Privacy Policy URL:** `https://migraine-log-site.vercel.app/privacy.html`
- **Marketing URL (optional):** `https://migraine-log-site.vercel.app/`
  (The Vercel project name must be `migraine-log-site`, or update these and `AppLinks.swift`.)

- **Name (30/30):** `Migraine Log: Headache Tracker`
- **Subtitle (29/30):** `Migraine Tracker & Pain Diary`
- **Keywords (93/100), no repeats of name/subtitle words:**
  `aura,trigger,journal,calendar,symptom,medication,relief,attack,chronic,tension,weather,period`
  Not yet checked for popularity: run `aso.py keywords_migraine_meta.txt` with a fresh cookie and drop the dead (5) ones before submitting.
- **Primary category:** Health & Fitness. **Secondary:** Medical.
- **Age rating:** answer honestly; medical/treatment information = "infrequent/mild" at most.

Don't use: brand names of medicines (Ubrelvy, Nurtec, Imitrex…) in the name, subtitle or keywords (trademarks, 2.3.7 / 5.2.1), "cure" / "treat" / "relief" claims about the app itself (1.4.1 — "relief" as a search keyword is fine, the description never promises it), prices in name/subtitle/screenshots (2.3.7).

## Promotional text (170)

Log a migraine in a few taps, even mid-attack. See your headache days, triggers and what medicine works — and bring a clear report to your doctor. One-time Pro, no subscription.

## Description

A calm, simple headache diary — built to be used when your head hurts.

Migraine Log records your migraines and headaches in a few taps: how bad it is, when it started and ended, what you took and whether it helped. Over time it shows the numbers your doctor asks for first — headache days, migraine days and medication days each month — and the patterns behind them.

WHAT YOU GET FREE
• Log in seconds: pain 1–10, migraine or headache, start and end, or "still going" and end it later
• Where it hurts, symptoms (aura, nausea, light and sound sensitivity…) and possible triggers
• Medicines you take are one tap away, with "Did it help?" for each dose
• A calendar of your month, each day shaded by its worst pain
• Headache-free streak and this month's headache, migraine and medication days
• Apple Health: finished headaches are saved to Health, and headaches other apps log show up here. Apple Health keeps your diary in sync across your devices.
• A gentle daily check-in reminder
• Home Screen and Lock Screen widgets: days headache-free, and one tap to log
• Backup to a file you keep, and restore any time

MIGRAINE LOG PRO — ONE-TIME PURCHASE
• Doctor-ready PDF report: headache and migraine days, medication days, suspected triggers, how each medicine worked, and every attack, on US Letter paper
• Insights: your most common triggers, how often each medicine helped, when attacks start, peak pain, and how your months compare

No subscription. No ads. No account. Your diary stays on your devices and in Apple Health — we never see it.

Migraine Log is a diary, not a medical device. It doesn't diagnose or treat anything. Always talk to your doctor before making medical decisions.

## Screenshot captions

1. Log a migraine in a few taps
2. Pain, triggers and what you took
3. Your month at a glance
4. See your patterns
5. Find what actually helps
6. A report your doctor can read

## App Privacy answers (App Store Connect)

Declare: **Usage Data › Product Interaction**, *Not linked to the user*, *Not used for tracking*, purpose *Analytics* (TelemetryDeck) — the same as `MigraineLog/PrivacyInfo.xcprivacy` and Simply BP's accepted setup. Health & Fitness data: **not collected** (it never leaves the device).

## Notes for Review (2.3.1(a))

Migraine Log is a headache diary. It does not diagnose, measure or treat anything; users record their own headaches.

A short screen recording of the main flow is attached to this submission.

How to review: complete the 4-step onboarding (medicines, Apple Health and the reminder can be skipped). On Today tap "Log Headache", pick a pain level and Save — the attack shows as in progress; tap "It's Over" › "End Now" to finish it. Log a few more to see the Calendar and Insights populate.

- HealthKit: reads and writes Headache category samples (mild / moderate / severe), only after the user turns on Settings › Apple Health. Only finished attacks are written; samples are marked HKMetadataKeyWasUserEntered. Health data is never sent anywhere. The only network traffic is anonymous feature-usage counts via TelemetryDeck (event names only, no health data; opt-out in Settings › Privacy); no ads.
- Storage: local SwiftData store only. No iCloud/CloudKit (5.1.3(ii)). The JSON backup is created only when the user taps "Back Up Diary" and is saved wherever the user chooses with the system file picker.
- In-App Purchase: one non-consumable, "Migraine Log Pro" (`white.tea.MigraineLog.pro`), $14.99. It unlocks the doctor PDF report (Today or Insights › Doctor Report) and the Insights tab. Restore Purchases is in the paywall and in Settings. Pro features don't require HealthKit access.
- Medical: the app reminds users to consult a doctor in onboarding, in Settings › About and on every report page. At pain 9–10 it shows an emergency note listing red-flag symptoms and pointing to 911. When headache medicine was taken on 10 or more of the last 30 days it suggests mentioning that to a doctor (the medication-overuse threshold from ICHD-3), without dosing advice. Triggers are presented as what the user noted, not causes.
