#!/usr/bin/env python3
"""
Migraine Log App Store screenshots (from the appstore-screenshots skill template).
App Store marketing-screenshot generator — HTML/CSS + headless Chrome.

Copy this into the project (e.g. appstore_screenshots/generate.py) and ADAPT:
  1. the mesh-gradient RGBs in TEMPLATE  -> the app's brand colors
  2. the headline color (--head)         -> a dark brand tone
  3. the SCREENS list                    -> your screens + RU/EN copy
  4. sizes (1320x2868 = iPhone 6.9")     -> only change for other device sizes

Layout:
  raw/<lang>/NN_Screen.png    -> source (plain app screenshot, 1320x2868)
  final/<lang>/NN_Screen.png  -> output (background + headline + device frame)

Run:  python3 generate.py      Requires: Google Chrome, Python 3 (no pip deps).
"""
import base64, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
FINAL = os.path.join(HERE, "final")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# (file, head, sub). <br> controls line breaks. Benefit-driven copy, NO medical
# claims and no prices (guidelines 1.4.1, 2.3.7). English only: the app is en-US.
SCREENS = [
    ("01_Home.png", "Your headache diary,<br>calm and simple", "Headache-free days and your month at a glance"),
    ("02_Log.png", "Log a migraine<br>in a few taps", "Pain, triggers and what you took, even mid-attack"),
    ("03_Calendar.png", "Your month<br>at a glance", "Every day shaded by its worst pain"),
    ("04_Insights.png", "See your<br>patterns", "Headache and migraine days, month by month"),
    ("05_InsightsMore.png", "Find what<br>actually helps", "Common triggers and how each medicine worked"),
    ("06_Report.png", "A report your<br>doctor can read", "Headache days, medication days and every attack"),
    # No paywall shot: it shows the price, and 2.3.7 bars prices in screenshots.
    # raw/en-US/07_Paywall.png is the In-App Purchase review screenshot instead.
]

# Brand: Tide, deep teal moving into indigo, like the icon.
TEMPLATE = """<!doctype html><html><head><meta charset="utf-8"><style>
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:1320px; height:2868px; overflow:hidden; }
body {
  font-family:'SF Pro Display',-apple-system,sans-serif;
  background-color:#0E2A2E;
  background-image:
    radial-gradient(at 12% 8%, rgba(31,122,114,0.95) 0px, transparent 50%),
    radial-gradient(at 92% 16%, rgba(44,127,154,0.75) 0px, transparent 44%),
    radial-gradient(at 85% 90%, rgba(67,81,166,0.85) 0px, transparent 52%),
    radial-gradient(at 6% 86%, rgba(20,80,90,0.90) 0px, transparent 48%);
  display:flex; flex-direction:column; align-items:center;
}
.head { margin-top:150px; text-align:center; padding:0 70px; }
.head h1 { font-size:100px; font-weight:700; line-height:1.07; letter-spacing:-2px; color:#FFFFFF; }
.head p  { font-size:46px; font-weight:500; margin-top:34px; color:rgba(255,255,255,0.82); letter-spacing:-0.3px; }
.phone {
  margin-top:90px; width:1000px; border-radius:110px; background:#0E1117; padding:16px;
  box-shadow: 0 70px 120px rgba(2,16,20,0.55), 0 20px 44px rgba(2,16,20,0.35);
}
.phone img { width:100%; display:block; border-radius:94px; }
</style></head><body>
  <div class="head"><h1>__HEAD__</h1><p>__SUB__</p></div>
  <div class="phone"><img src="__IMG__"></div>
</body></html>"""


def b64(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def render(lang, fname, head, sub, outname):
    src = os.path.join(RAW, lang, fname)
    if not os.path.exists(src):
        print("  SKIP (no raw):", src); return
    outdir = os.path.join(FINAL, lang); os.makedirs(outdir, exist_ok=True)
    html = (TEMPLATE.replace("__IMG__", b64(src))
                    .replace("__HEAD__", head).replace("__SUB__", sub))
    hp = os.path.join(outdir, outname.replace(".png", ".html"))
    with open(hp, "w") as f:
        f.write(html)
    out = os.path.join(outdir, outname)
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=1", "--virtual-time-budget=4000",
                    f"--screenshot={out}", "--window-size=1320,2868", f"file://{hp}"],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.remove(hp)
    print("  ok", lang, "->", os.path.relpath(out, HERE))


def main():
    for i, (fname, head, sub) in enumerate(SCREENS, 1):
        render("en-US", fname, head, sub, f"{i:02d}_{fname[3:]}")
    print("done. finals in", os.path.relpath(FINAL, HERE))


if __name__ == "__main__":
    main()
