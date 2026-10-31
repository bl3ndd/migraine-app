# Design

Direction **B "Tide"** from `directions/` (chosen 2026-10-31): cool sea-glass teal moving into deep
indigo, light SF Pro numbers, tonal tiles without borders. It is deliberately unlike Simply BP
(warm paper, blue, white cards with hairlines) and outside the purple most migraine apps use.
Tokens live in `MigraineLog/Theme/DesignTokens.swift`; the full rationale and contrast ratios are
in `directions/README.md`.

`AppIcon.svg` (three waves in the ramp colors on deep teal) is the source of
`MigraineLog/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` and the paywall `Logo.png`.
Re-render at 1024×1024 with no alpha:

    chrome --headless=new --force-device-scale-factor=1 --window-size=1024,1024 \
      --screenshot=AppIcon-1024.png page-with-the-svg.html
