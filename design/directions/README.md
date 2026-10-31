# Migraine Log — visual directions

Files in this folder:

| File | What |
|---|---|
| `direction-a.html` / `.png` | Direction A "Dusk": Home, Log sheet, Calendar, Insights, light + dark |
| `direction-b.html` / `.png` | Direction B "Tide": same screens |
| `icon-a.svg` / `.png`, `icon-b.svg` / `.png` | App icon concepts, 1024×1024 |
| `generate.py` | Builds both HTML files from one token table (`python3 generate.py .`) |

In the mocks, light mode shows Home in its calm state (streak) and dark mode shows Home during an attack (ongoing card + End attack).

## Competitive scan (brief)

- **Migraine Buddy**: dark navy/indigo with purple and teal accents, illustrated mascots, long step-by-step questionnaires.
- **Bearable**: purple/pink, playful and dense, general symptom tracker.
- **Cranium / MiG / most indie "headache tracker" apps**: purple or blue, white cards, stock SF Symbols. Several pitch "dark mode, gentle on sensitive eyes".
- Purple is the category default (it's also the migraine-awareness color), so a purple app blends in. Nobody in the top set owns cool teal → indigo.

## What both directions avoid from Simply BP

BP uses warm paper `#F6F3EC`, ink navy `#1B2333`, blue `#2F5FD0`, white cards with hairline borders, heavy SF Rounded numbers and a green→red scale. Neither direction uses a warm background, hairline borders, white cards, heavy rounded numerals or a traffic-light scale. Surfaces are tonal fills with no strokes, numerals are light or serif, and both ramps are single-family and colorblind-safe (they climb in luminance, and every cell also shows its number).

---

## Direction A — "Dusk"

**Rationale.** An evening journal: soft plum/lavender, New York serif for titles and numbers, pill shapes everywhere, borderless tonal surfaces. Very gentle. The weak point is that it lives in the category's purple.

### Tokens

| Token | Light | Dark |
|---|---|---|
| bg | `#EDE9F1` | `#151118` |
| surface (card/sheet) | `#F7F5F9` | `#211B26` |
| input fill / chip | `#E2DCE8` | `#2C2433` |
| text primary | `#241B2B` | `#EFE8F3` |
| text secondary | `#6A5E73` | `#A99DB1` |
| separator | `#D6CEDD` | `#342B3B` |
| accent (text/icons/tint) | `#70469A` | `#C7A6E3` |
| accentFill (white text on it) | `#6A3F8E` | `#7A4FA2` |
| accent tint | `#E3D7EE` | `#35283F` |
| migraine color | `#6A3F8E` | `#C7A6E3` |
| headache color | `#B0697A` | `#E09AAA` |

Intensity ramp (1–2, 3–4, 5–6, 7–8, 9–10). The label color is what goes on top of each step.

| Step | Light fill / label | Dark fill / label |
|---|---|---|
| 1–2 | `#E6DCF1` / `#3B2A4A` | `#3A2F45` / `#E8DDF0` |
| 3–4 | `#C9B2E2` / `#3B2A4A` | `#5B4575` / `#F3ECF8` |
| 5–6 | `#845DB1` / `#FFFFFF` | `#8661AB` / `#FFFFFF` |
| 7–8 | `#6A3F8E` / `#FFFFFF` | `#B48BD9` / `#1E1426` |
| 9–10 | `#46245F` / `#FFFFFF` | `#E4CBF7` / `#1E1426` |

The light ramp gets darker with intensity. The dark ramp gets brighter, so worse attacks always stand out more against the background.

**Radii.** Everything interactive is a full capsule (999): chips, buttons, segmented controls, intensity pills. Content blocks (time, medication, notes, panels) use 24. Home blocks use 28–32, the sheet top 34. Calendar days are circles.

**Typography.** Titles and big numbers use `ui-serif` / New York: large title 36 semibold, streak numeral 128 light, stats 44 regular, durations 52 regular. UI and body text use SF Pro Text at 15–17, with section labels at 13 semibold uppercase. SwiftUI: `.font(.system(size:, design: .serif))`.

**Icons.** Custom 24-grid line icons with a 1.8 stroke, round caps and joins, in a symptom/trigger set (eye, drop, bolt, ear, fog, moon, wave, cup, screen, cycle, pill). No emoji, no fills.

**App icon (icon-a).** A lavender half-disc setting on a horizon with three receding plum bars, on flat deep plum `#3A1F51`.

### Contrast (WCAG 2.x)

| Pair | Light | Dark |
|---|---|---|
| text / bg | 13.8 | 15.6 |
| text / surface | 15.3 | 14.0 |
| text / fill | 12.3 | 12.4 |
| text2 / bg | 5.1 | 7.2 |
| text2 / surface | 5.6 | 6.5 |
| text2 / fill | 4.5 | 5.8 |
| **white / accentFill** | **7.74** | **6.06** |
| accent / bg | 5.78 | 8.88 |
| accent / tint (PRO badge) | 5.02 | 6.55 |
| ramp labels (1–2 … 9–10) | 9.8 / 6.8 / 5.0 / 7.7 / 12.5 | 9.6 / 7.1 / 4.9 / 6.5 / 12.0 |

---

## Direction B — "Tide"  (recommended)

**Rationale.** Cool sea-glass calm with a data-forward layout. Cool grey-mint backgrounds (not white), teal for actions, and an intensity ramp that runs from pale aqua through teal into deep indigo. Ultralight SF Pro numerals, squarer 16-pt tiles, a full-bleed tinted hero band and a floating capsule tab bar. During an attack Home turns into one big card with the duration, a mini intensity meter and a 60-pt End attack button.

### Tokens

| Token | Light | Dark |
|---|---|---|
| bg | `#E6EDEC` | `#0B1315` |
| surface (card/sheet) | `#F2F6F5` | `#132023` |
| input fill / chip | `#D9E3E2` | `#1B2B2E` |
| text primary | `#0F2627` | `#E1EDEB` |
| text secondary | `#486364` | `#8DA6A7` |
| separator | `#C9D6D5` | `#213236` |
| accent (text/icons/tint) | `#146B66` | `#5FCBBF` |
| accentFill (white text on it) | `#146B66` | `#13756F` |
| accent tint | `#CDE6E2` | `#16393A` |
| migraine color | `#3A4AA3` (indigo) | `#8E98F2` |
| headache color | `#1B8F86` (teal) | `#5FCBBF` |

Intensity ramp (1–2, 3–4, 5–6, 7–8, 9–10):

| Step | Light fill / label | Dark fill / label |
|---|---|---|
| 1–2 | `#C4E7E1` / `#0F2627` | `#1D4644` / `#D7ECE9` |
| 3–4 | `#80CCC3` / `#0F2627` | `#2A7471` / `#FFFFFF` |
| 5–6 | `#2C7F9A` / `#FFFFFF` | `#3C97B6` / `#0B1430` |
| 7–8 | `#4351A6` / `#FFFFFF` | `#8098F0` / `#0B1430` |
| 9–10 | `#2B2C77` / `#FFFFFF` | `#B9B6FF` / `#0B1430` |

Hue moves teal → blue → indigo, and luminance moves in one direction (darker in light mode, brighter in dark mode). Someone with red-green or blue-yellow color blindness still reads it as a lightness scale, and every day and intensity cell also prints its number.

**Radii.** Tiles, panels, inputs, segmented controls and the hero band use 16. Primary buttons use 18. Chips use 12. Inner segments and the Helped? options use 10–13. Calendar cells use 12. The sheet top is 28. The tab bar is a 32 capsule.

**Typography.** Everything is SF Pro (system default). Large title 30 bold with tight tracking. Hero numerals are SF Pro Display weight 200: streak 92, attack duration 62. Stats are 40 light. The date eyebrow is 13 semibold uppercase in accent. Body is 15–17 and tabular numbers use `.monospacedDigit()`. No SF Rounded anywhere, which keeps it clear of BP's heavy rounded numerals.

**Icons.** Same custom 24-grid line set as A (1.8 stroke, round caps). The intensity picker is a 10-bar meter whose bars grow in height, so intensity is encoded by height, color and number. Tab icons are line icons with a 1.9 stroke when active.

**App icon (icon-b).** Three thick wave strokes in the ramp colors (`#80CCC3` → `#3C98AE` → `#6F86E4`) on flat deep teal `#0D2B2E`. It reads as calm, "waves of pain settling", and pressure/weather. No logbook, no heart, no blue field.

### Contrast (WCAG 2.x)

| Pair | Light | Dark |
|---|---|---|
| text / bg | 13.3 | 15.7 |
| text / surface | 14.5 | 13.9 |
| text / fill | 12.1 | 12.2 |
| text2 / bg | 5.5 | 7.3 |
| text2 / surface | 5.9 | 6.5 |
| text2 / fill | 4.9 | 5.7 |
| **white / accentFill** | **6.32** | **5.52** |
| accent / bg | 5.32 | 9.64 |
| accent / surface | 5.80 | 8.57 |
| accent / tint (PRO badge) | 4.82 | 6.42 |
| ramp labels (1–2 … 9–10) | 12.0 / 8.5 / 4.6 / 7.1 / 12.1 | 8.5 / 5.5 / 5.4 / 6.6 / 9.7 |

Every text pair clears 4.5:1. Non-text chart colors only need 3:1 (headache teal on surface is 3.6 light / 8.6 dark), and every chart value also has a printed number.

---

## Recommendation: B "Tide"

1. **It differentiates in both directions.** It's far from Simply BP (cool, not warm; teal, not blue; tonal tiles, not white hairline cards; ultralight sans, not heavy rounded), and it's also outside the migraine category's purple, which A sits squarely in next to Migraine Buddy, Bearable and Cranium. On a store page full of purple, Tide is the one you notice.
2. **It fits the use case better.** Cool, desaturated teal on grey-mint has lower glare than lavender-white, and the dark theme is near-black teal, not purple, which is softer for photophobia. The meter picker gives the biggest, most forgiving targets of either direction for one-handed logging.
3. **It's cheaper to build and keep consistent.** It's all system SF Pro with no serif pairing to tune, and the ramp's hue shift plus monotonic luminance holds up in charts, the calendar and the meter alike.

What A does better: the serif and pills feel warmer and more personal. If the brand ever leans "self-care journal" over "health tool", Dusk is the fallback. One caveat for B: keep the indigo end of the ramp (`#4351A6`, `#2B2C77`) as data color only, and never use it for buttons or tint. That way no surface reads as BP blue `#2F5FD0`.

Not mocked here: Paywall. It should reuse the B tokens (tint band hero, accentFill CTA, ramp-colored feature bullets).
