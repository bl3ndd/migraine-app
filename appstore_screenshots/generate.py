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

Run:  python3 generate.py      Requires: Google Chrome, Python 3 with Pillow.
"""
import base64, io, os, subprocess

from PIL import Image, ImageDraw

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
  position:relative;
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
.screen { position:relative; }
.screen svg { position:absolute; inset:0; width:100%; height:100%; }
.zoom {
  position:absolute; left:60px; right:60px; top:1050px; border-radius:36px; overflow:hidden;
  box-shadow: 0 50px 100px rgba(8,30,40,0.45), 0 14px 34px rgba(8,30,40,0.28);
}
.zoom img { width:100%; display:block; }
</style></head><body>
  <div class="head"><h1>__HEAD__</h1><p>__SUB__</p></div>
  <div class="phone"><div class="screen"><img src="__IMG__">__STATUS__</div></div>
  __ZOOM__
</body></html>"""

# Real-device captures (iPhone 13, 1170 wide) carry the real clock and battery.
# Paint Apple's 9:41, full signal, full Wi-Fi and a full battery over them.
STATUS = """<svg viewBox="0 0 1170 2532" preserveAspectRatio="none">
  __HEADER__
  <rect x="100" y="35" width="190" height="80" fill="__BG__"/>
  <rect x="841" y="40" width="85" height="70" fill="__BG__"/>
  <rect x="928" y="46" width="64" height="58" fill="__BG__"/>
  <rect x="996" y="40" width="110" height="70" fill="__BG__"/>
  <text x="191" y="97" text-anchor="middle" font-family="SF Pro Text, -apple-system" font-weight="600" font-size="57">9:41</text>
  <g transform="translate(-9.5,-20)">
    <rect x="865" y="104" width="11" height="13" rx="3"/><rect x="880.5" y="96" width="11" height="21" rx="3"/>
    <rect x="896" y="88" width="11" height="29" rx="3"/><rect x="911" y="79" width="11" height="38" rx="3"/>
    <path d="M970,116 L959.4,105.4 A15,15 0 0 1 980.6,105.4 Z"/>
    <path d="M953.7,98.7 A23,23 0 0 1 986.3,98.7" fill="none" stroke="#000" stroke-width="8.5" stroke-linecap="round"/>
    <path d="M945.2,89.2 A35,35 0 0 1 994.8,89.2" fill="none" stroke="#000" stroke-width="8.5" stroke-linecap="round"/>
    <rect x="1019.5" y="80.5" width="71" height="35" rx="11" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="3"/>
    <rect x="1025" y="86" width="60" height="24" rx="6.5"/>
    <rect x="1094" y="91" width="5" height="14" rx="2.5" fill-opacity="0.4"/>
  </g>
</svg>"""

# A scrolled page shows text through the scroll-edge blur under the inline title:
# repaint that band in the app background and put the title and report button back.
CLEAN_HEADER = {"05_InsightsMore.png": ("Insights", "04_Insights.png")}
HEADER = """<defs><linearGradient id="band" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0.85" stop-color="#E6EDEC"/><stop offset="1" stop-color="#E6EDEC" stop-opacity="0"/></linearGradient></defs>
  <rect x="0" y="0" width="1170" height="370" fill="url(#band)"/>
  <image href="__BTN__" x="__BX__" y="__BY__" width="__BW__" height="__BH__"/>
  <text x="585" y="226" text-anchor="middle" font-family="SF Pro Text, -apple-system" font-weight="600" font-size="51" fill="#000">__TITLE__</text>"""
BUTTON = (986, 137, 1125, 276)  # the report button's circle, same spot on every tab

# The report page is unreadable at phone scale: show its top (summary + chart) enlarged.
ZOOM = {"06_Report.png": (60, 360, 1140, 1290)}


def png_uri(im):
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def b64(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def render(lang, fname, head, sub, outname):
    src = os.path.join(RAW, lang, fname)
    if not os.path.exists(src):
        print("  SKIP (no raw):", src); return
    outdir = os.path.join(FINAL, lang); os.makedirs(outdir, exist_ok=True)
    im = Image.open(src).convert("RGB")
    header = ""
    if fname in CLEAN_HEADER:
        title, button_src = CLEAN_HEADER[fname]
        x0, y0, x1, y1 = BUTTON
        btn = Image.open(os.path.join(RAW, lang, button_src)).convert("RGBA").crop(BUTTON)
        mask = Image.new("L", btn.size, 0)
        ImageDraw.Draw(mask).ellipse((4, 4, btn.width - 5, btn.height - 5), fill=255)
        btn.putalpha(mask)
        header = (HEADER.replace("__BTN__", png_uri(btn)).replace("__TITLE__", title)
                  .replace("__BX__", str(x0)).replace("__BY__", str(y0))
                  .replace("__BW__", str(x1 - x0)).replace("__BH__", str(y1 - y0)))
    bg = "#E6EDEC" if header else "#%02x%02x%02x" % im.getpixel((585, 15))
    status = STATUS.replace("__HEADER__", header).replace("__BG__", bg)
    zoom = f'<div class="zoom"><img src="{png_uri(im.crop(ZOOM[fname]))}"></div>' if fname in ZOOM else ""
    html = (TEMPLATE.replace("__IMG__", b64(src)).replace("__STATUS__", status).replace("__ZOOM__", zoom)
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
