#!/usr/bin/env python3
"""Generates direction-a.html / direction-b.html mockups for Migraine Log."""
import calendar, sys, os

OUT = sys.argv[1]

# ---------------------------------------------------------------- tokens
TOKENS = {
  "a": {
    "name": "Dusk",
    "light": dict(bg="#EDE9F1", surface="#F7F5F9", fill="#E2DCE8", text="#241B2B", text2="#6A5E73",
                  sep="#D6CEDD", accent="#70469A", accentFill="#6A3F8E", tint="#E3D7EE",
                  r=["#E6DCF1", "#C9B2E2", "#845DB1", "#6A3F8E", "#46245F"],
                  rtext=["#3B2A4A", "#3B2A4A", "#FFFFFF", "#FFFFFF", "#FFFFFF"],
                  mig="#6A3F8E", ha="#B0697A", dim="rgba(36,27,43,.38)"),
    "dark": dict(bg="#151118", surface="#211B26", fill="#2C2433", text="#EFE8F3", text2="#A99DB1",
                 sep="#342B3B", accent="#C7A6E3", accentFill="#7A4FA2", tint="#35283F",
                 r=["#3A2F45", "#5B4575", "#8661AB", "#B48BD9", "#E4CBF7"],
                 rtext=["#E8DDF0", "#F3ECF8", "#FFFFFF", "#1E1426", "#1E1426"],
                 mig="#C7A6E3", ha="#E09AAA", dim="rgba(0,0,0,.55)"),
  },
  "b": {
    "name": "Tide",
    "light": dict(bg="#E6EDEC", surface="#F2F6F5", fill="#D9E3E2", text="#0F2627", text2="#486364",
                  sep="#C9D6D5", accent="#146B66", accentFill="#146B66", tint="#CDE6E2",
                  r=["#C4E7E1", "#80CCC3", "#2C7F9A", "#4351A6", "#2B2C77"],
                  rtext=["#0F2627", "#0F2627", "#FFFFFF", "#FFFFFF", "#FFFFFF"],
                  mig="#3A4AA3", ha="#1B8F86", dim="rgba(15,38,39,.38)"),
    "dark": dict(bg="#0B1315", surface="#132023", fill="#1B2B2E", text="#E1EDEB", text2="#8DA6A7",
                 sep="#213236", accent="#5FCBBF", accentFill="#13756F", tint="#16393A",
                 r=["#1D4644", "#2A7471", "#3C97B6", "#8098F0", "#B9B6FF"],
                 rtext=["#D7ECE9", "#FFFFFF", "#0B1430", "#0B1430", "#0B1430"],
                 mig="#8E98F2", ha="#5FCBBF", dim="rgba(0,0,0,.6)"),
  },
}

def step(v):  # intensity 1-10 -> ramp index 0-4
    return min(4, (v - 1) // 2)

# ---------------------------------------------------------------- icons
ICONS = {
 "home": '<path d="M4 10.5 12 4l8 6.5V19a1 1 0 0 1-1 1h-4.5v-5.5h-5V20H5a1 1 0 0 1-1-1z"/>',
 "cal": '<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
 "chart": '<path d="M5 20v-7M12 20V5M19 20v-10"/>',
 "sliders": '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
 "plus": '<path d="M12 5v14M5 12h14"/>',
 "pill": '<rect x="2.6" y="8.2" width="18.8" height="7.6" rx="3.8" transform="rotate(-45 12 12)"/><path d="m9.3 9.3 5.4 5.4"/>',
 "moon": '<path d="M19.5 14.6A7.8 7.8 0 1 1 9.4 4.5a6.3 6.3 0 0 0 10.1 10.1z"/>',
 "sun": '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
 "bolt": '<path d="M13 3 5.5 13H11l-1 8 7.5-10H12z"/>',
 "drop": '<path d="M12 3.5s5.8 6.2 5.8 10.4a5.8 5.8 0 0 1-11.6 0C6.2 9.7 12 3.5 12 3.5z"/>',
 "clock": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
 "eye": '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.8"/>',
 "wave": '<path d="M3 9.5c2-2 4-2 6 0s4 2 6 0 4-2 6 0M3 15.5c2-2 4-2 6 0s4 2 6 0 4-2 6 0"/>',
 "cup": '<path d="M5 8.5h11V14a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5zM16 10.5h1.5a2.5 2.5 0 0 1 0 5H16M8.5 3.5v2M12 3.5v2"/>',
 "screen": '<rect x="3" y="4.5" width="18" height="12" rx="2"/><path d="M8.5 20h7M12 16.5V20"/>',
 "ear": '<path d="M7 9.5a5 5 0 0 1 10 0c0 3-3 3.6-3 6.5a3 3 0 0 1-5.6 1.4"/><path d="M10 10a2 2 0 0 1 4 0"/>',
 "fog": '<path d="M4 9h12M7 13h13M4 17h10"/>',
 "check": '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
 "x": '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
 "chev": '<path d="m9.5 6 6 6-6 6"/>',
 "chevl": '<path d="m14.5 6-6 6 6 6"/>',
 "note": '<path d="M6 3.5h8.5L19 8v12.5H6z"/><path d="M14 3.5V8.5h5M9 13h7M9 16.5h5"/>',
 "lock": '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>',
 "stop": '<rect x="7" y="7" width="10" height="10" rx="2"/>',
 "edit": '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
 "stress": '<circle cx="12" cy="12" r="8.5"/><path d="M8.5 15.5h7M9 9.5l1.5 1M15 9.5l-1.5 1"/>',
 "cycle": '<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5a8.5 8.5 0 0 1 0 17z" fill="currentColor" stroke="none" opacity=".35"/>',
}
def ic(name, size=20, sw=1.8, extra=""):
    return (f'<svg class="ic" width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" {extra}>{ICONS[name]}</svg>')

def statusbar():
    return ('<div class="sb"><span class="sb-time">9:41</span><span class="sb-r">'
            '<svg width="18" height="11" viewBox="0 0 18 11" fill="currentColor"><rect x="0" y="7" width="3" height="4" rx="1"/><rect x="5" y="5" width="3" height="6" rx="1"/><rect x="10" y="2.5" width="3" height="8.5" rx="1"/><rect x="15" y="0" width="3" height="11" rx="1"/></svg>'
            '<svg width="16" height="11" viewBox="0 0 16 11" fill="currentColor"><path d="M8 2.2c2.3 0 4.4.9 6 2.4l1.2-1.2A10.2 10.2 0 0 0 8 .5C5.2.5 2.7 1.6.8 3.4L2 4.6a8.5 8.5 0 0 1 6-2.4zm0 3.4c1.4 0 2.6.5 3.6 1.4l1.2-1.2A6.8 6.8 0 0 0 8 3.9c-1.8 0-3.5.7-4.8 1.9L4.4 7c1-.9 2.2-1.4 3.6-1.4zM8 9l2.4-1.1A3.4 3.4 0 0 0 8 7.3c-.9 0-1.8.3-2.4.6z"/></svg>'
            '<svg width="27" height="12" viewBox="0 0 27 12"><rect x=".5" y=".5" width="23" height="11" rx="3.5" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="17" height="8" rx="2" fill="currentColor"/><path d="M25 4v4c.8-.3 1.3-1 1.3-2s-.5-1.7-1.3-2z" fill="currentColor" opacity=".45"/></svg>'
            '</span></div>')

def homebar():
    return '<div class="hb"></div>'

def tabbar(d, active):
    items = [("home", "Today"), ("cal", "Calendar"), ("chart", "Insights"), ("sliders", "Settings")]
    s = "".join(f'<div class="tab{" on" if i == active else ""}">{ic(n, 24, 1.9 if i == active else 1.7)}<span>{l}</span></div>'
                for i, (n, l) in enumerate(items))
    return f'<div class="tabbar">{s}</div>'

# sample data ------------------------------------------------------------
OCT = {3: (4, "h"), 4: (7, "m"), 9: (3, "h"), 14: (6, "m"), 15: (8, "m"), 16: (5, "m"),
       21: (2, "h"), 26: (9, "m"), 27: (6, "h")}
LAST14 = [(18, 0), (19, 0), (20, 0), (21, 2), (22, 0), (23, 0), (24, 0), (25, 0), (26, 9), (27, 6), (28, 0), (29, 0), (30, 0), (31, 0)]

# ================================================================ HOME
def home(d, mode):
    t = TOKENS[d][mode]
    attack = (mode == "dark")
    strip = "".join(
        f'<div class="dd{" on" if v else ""}" style="{f"background:{t["r"][step(v)]};color:{t["rtext"][step(v)]}" if v else ""}"><i>{day}</i></div>'
        for day, v in LAST14)
    month = ('<div class="mstats">'
             '<div class="ms"><b>9</b><span>headache<br>days</span></div>'
             '<div class="ms"><b>5</b><span>migraine<br>days</span></div>'
             '<div class="ms"><b>6</b><span>medication<br>days</span></div></div>')
    if d == "a":
        if attack:
            hero = (f'<div class="attack">'
                    f'<div class="att-top"><span class="live"></span><span class="att-k">Migraine in progress</span></div>'
                    f'<div class="att-mid"><div><div class="att-dur">3h 12m</div><div class="att-sub">Started 6:40 AM</div></div>'
                    f'<div class="ibadge big" style="background:{t["r"][step(6)]};color:{t["rtext"][step(6)]}"><b>6</b><span>of 10</span></div></div>'
                    f'<div class="att-row"><div class="ghost">{ic("pill",18)} Took medication</div><div class="ghost">{ic("edit",18)} Update</div></div>'
                    f'<div class="btn-end">{ic("stop",20,2)} End attack</div></div>'
                    f'<div class="streak-mini">Before this attack: <b>3 headache-free days</b></div>')
        else:
            hero = (f'<div class="streak"><div class="s-num">4</div><div class="s-lab">headache-free<br>days in a row</div></div>'
                    f'<div class="s-note">Longest run this month: 5 days</div>'
                    f'<div class="strip">{strip}</div>')
        body = (f'<div class="pad"><div class="date">Saturday, October 31</div><h1 class="lt">Today</h1></div>'
                f'<div class="pad">{hero}</div>'
                f'<div class="pad sect"><div class="sh">October so far</div>{month}</div>'
                + ("" if attack else f'<div class="pad"><div class="last"><span class="ibadge sm" style="background:{t["r"][step(6)]};color:{t["rtext"][step(6)]}"><b>6</b></span><div><b>Last: Headache</b><span>Tue, Oct 27 · 4h 10m</span></div>{ic("chev",18,2)}</div></div>')
                + f'<div class="cta-wrap"><div class="btn-log{" quiet" if attack else ""}">{ic("plus",24,2.2)} Log headache</div></div>')
    else:
        if attack:
            hero = (f'<div class="band attackband">'
                    f'<div class="att-top"><span class="live"></span><span class="att-k">Migraine · ongoing</span><span class="att-time">since 6:40 AM</span></div>'
                    f'<div class="att-mid"><div class="att-dur">3<small>h</small> 12<small>m</small></div>'
                    f'<div class="meter-mini">' + "".join(
                        f'<i style="height:{10+i*3}px;background:{t["r"][step(i+1)] if i < 6 else t["fill"]}"></i>' for i in range(10)) +
                    f'</div><div class="att-int"><b>6</b><span>/10</span></div></div>'
                    f'<div class="att-row"><div class="ghost">{ic("pill",18)} Medication</div><div class="ghost">{ic("edit",18)} Update</div></div>'
                    f'<div class="btn-end">{ic("stop",20,2)} End attack</div></div>')
            streak = '<div class="pad"><div class="kv"><span>Last clear streak</span><b>3 days</b></div></div>'
        else:
            hero = (f'<div class="band"><div class="b-lab">Headache-free</div>'
                    f'<div class="b-num">4<span>days</span></div>'
                    f'<div class="bars14">' + "".join(
                        f'<div class="b14"><i style="height:{8+v*6}px;background:{t["r"][step(v)] if v else "var(--clear)"}"></i><span>{day if day in (18,25,31) else ""}</span></div>'
                        for day, v in LAST14) + '</div></div>')
            streak = '<div class="pad"><div class="kv"><span>Longest this month</span><b>5 days</b></div></div>'
        body = (f'<div class="topbar pad"><div><div class="date">Sat, Oct 31</div><div class="lt">Migraine Log</div></div></div>'
                f'{hero}{streak}'
                f'<div class="pad sect"><div class="sh">This month</div>{month}</div>'
                + ("" if attack else f'<div class="pad"><div class="last"><span class="ibadge sm" style="background:{t["r"][step(6)]};color:{t["rtext"][step(6)]}"><b>6</b></span><div><b>Last: Headache</b><span>Tue, Oct 27 · 4h 10m</span></div>{ic("chev",18,2)}</div></div>')
                + f'<div class="cta-wrap"><div class="btn-log{" quiet" if attack else ""}">{ic("plus",24,2.2)} Log headache</div></div>')
    return body + tabbar(d, 0)

# ================================================================ LOG
def chip(label, on=False, icon=None):
    i = ic(icon, 17) if icon else ""
    return f'<span class="chip{" on" if on else ""}">{i}{label}</span>'

def log(d, mode):
    t = TOKENS[d][mode]
    sel = 6
    if d == "a":
        pick = '<div class="ipick">' + "".join(
            f'<div class="ip{" sel" if v == sel else ""}" style="background:{t["r"][step(v)]};color:{t["rtext"][step(v)]}">{v}</div>'
            for v in range(1, 11)) + '</div><div class="iscale"><span>Mild</span><span>Moderate</span><span>Severe</span><span>Worst</span></div>'
    else:
        pick = '<div class="meter">' + "".join(
            f'<div class="mb{" sel" if v == sel else ""}"><i style="height:{22+v*4.6:.0f}px;background:{t["r"][step(v)] if v <= sel else t["fill"]};{"" if v<=sel else ""}"></i><span>{v}</span></div>'
            for v in range(1, 11)) + '</div>'
    seg_type = ('<div class="seg"><span class="on">' + ic("bolt", 17) + 'Migraine</span><span>Headache</span></div>')
    times = ('<div class="times"><div class="tbox"><span>Started</span><b>Today, 6:40 AM</b></div>'
             '<div class="tbox"><span>Ended</span><b class="muted">Still going</b></div></div>')
    loc = "".join([chip("Left side"), chip("Right side", True), chip("Behind eyes", True), chip("Forehead"), chip("Temples"), chip("Neck")])
    sym = "".join([chip("Light", True, "eye"), chip("Nausea", True, "drop"), chip("Aura", False, "bolt"), chip("Sound", False, "ear"), chip("Brain fog", True, "fog")])
    trg = "".join([chip("Poor sleep", True, "moon"), chip("Weather", True, "wave"), chip("Caffeine", False, "cup"), chip("Screens", False, "screen"), chip("Stress", False, "stress"), chip("Period", False, "cycle")])
    med = (f'<div class="med"><div class="med-h"><span class="med-ic">{ic("pill",18)}</span><div><b>Sumatriptan 50 mg</b><span>7:05 AM</span></div></div>'
           f'<div class="helped"><span class="hl">Helped?</span><div class="seg3"><span>Yes</span><span class="on">Partly</span><span>No</span></div></div></div>'
           f'<div class="addmed">{ic("plus",18,2)} Add medication</div>')
    header = ('<div class="sheet-h"><span class="sh-l">Cancel</span><b>New entry</b><span class="sh-r">Save</span></div>')
    intensity_head = f'<div class="lh"><span>Intensity</span><em style="color:{t["accent"]}">6 · Severe</em></div>'
    inner = (header + '<div class="sheet-body">'
             + f'<div class="lsec">{seg_type}</div>'
             + f'<div class="lsec">{times}</div>'
             + f'<div class="lsec">{intensity_head}{pick}</div>'
             + f'<div class="lsec"><div class="lh"><span>Where does it hurt?</span></div><div class="chips">{loc}</div></div>'
             + f'<div class="lsec"><div class="lh"><span>Symptoms</span></div><div class="chips scroll">{sym}</div></div>'
             + f'<div class="lsec"><div class="lh"><span>Possible triggers</span></div><div class="chips scroll">{trg}</div></div>'
             + f'<div class="lsec"><div class="lh"><span>Medication</span></div>{med}</div>'
             + f'<div class="lsec"><div class="lh"><span>Notes</span></div><div class="notes">Woke up with it. Dark room helped a bit…</div></div>'
             + '</div>')
    behind = '<div class="behind"></div>'
    return f'{behind}<div class="scrim"></div><div class="sheet"><div class="grab"></div>{inner}</div>'

# ================================================================ CALENDAR
def cal(d, mode):
    t = TOKENS[d][mode]
    c = calendar.Calendar(firstweekday=6)
    weeks = c.monthdayscalendar(2026, 10)
    cells = ""
    for w in weeks:
        for day in w:
            if day == 0:
                cells += '<div class="cd empty"></div>'
                continue
            cls = "cd"
            style = ""
            sub = ""
            if day in OCT:
                v, k = OCT[day]
                style = f'background:{t["r"][step(v)]};color:{t["rtext"][step(v)]}'
                sub = f'<i>{v}</i>'
                cls += " hit" + (" mig" if k == "m" else "")
            if day == 31: cls += " today"
            if day == 26: cls += " picked"
            cells += f'<div class="{cls}" style="{style}"><b>{day}</b>{sub}</div>'
    legend = '<div class="legend">' + "".join(
        f'<span><i style="background:{t["r"][k]};color:{t["rtext"][k]}"></i>{lab}</span>'
        for k, lab in enumerate(["1–2", "3–4", "5–6", "7–8", "9–10"])) + '</div>'
    detail = (f'<div class="detail"><div class="dt-h"><div><div class="dt-k">Monday, Oct 26</div>'
              f'<div class="dt-t">Migraine · 7h 40m</div></div>'
              f'<div class="ibadge" style="background:{t["r"][step(9)]};color:{t["rtext"][step(9)]}"><b>9</b></div></div>'
              f'<div class="dt-rows"><div>{ic("clock",17)}<span>5:20 AM – 1:00 PM</span></div>'
              f'<div>{ic("pill",17)}<span>Sumatriptan 50 mg · helped partly</span></div>'
              f'<div>{ic("wave",17)}<span>Weather, poor sleep</span></div></div></div>')
    wk = "".join(f"<span>{x}</span>" for x in "SMTWTFS")
    head = (f'<div class="calhead pad"><h1 class="lt">October</h1><div class="cal-nav">'
            f'<span>{ic("chevl",20,2)}</span><span>{ic("chev",20,2)}</span></div></div>')
    summary = '<div class="pad calsum"><span><b>9</b> headache days</span><span><b>5</b> migraine</span><span><b>22</b> clear</span></div>'
    return (head + summary + f'<div class="pad"><div class="wk">{wk}</div><div class="grid">{cells}</div>{legend}'
            f'<div class="legend2"><span class="mdot"></span> migraine day &nbsp;·&nbsp; number = peak intensity</div></div>'
            f'<div class="pad">{detail}</div>' + tabbar(d, 1))

# ================================================================ STATS
def stats(d, mode):
    t = TOKENS[d][mode]
    months = [("May", 11, 6), ("Jun", 9, 4), ("Jul", 12, 7), ("Aug", 8, 4), ("Sep", 10, 5), ("Oct", 9, 5)]
    mx = 14
    bars = "".join(
        f'<div class="mbar"><div class="mstack"><em>{h}</em>'
        f'<i class="ha" style="height:{(h-m)/mx*86:.0f}px"></i><i class="mg" style="height:{m/mx*86:.0f}px"></i></div><span>{n}</span></div>'
        for n, h, m in months)
    trig = [("Poor sleep", 62, "moon"), ("Weather change", 48, "wave"), ("Period", 35, "cycle"), ("Caffeine", 21, "cup")]
    trows = "".join(
        f'<div class="trow"><span class="tl">{ic(i,16)}{n}</span><div class="ttrack"><i style="width:{p}%"></i></div><b>{p}%</b></div>'
        for n, p, i in trig)
    meds = [("Sumatriptan", 64, 27, 9, 22), ("Ibuprofen", 31, 38, 31, 13)]
    mrows = "".join(
        f'<div class="mrow"><div class="mr-h"><b>{n}</b><span>{c} doses</span></div>'
        f'<div class="eff"><i class="e1" style="width:{y}%">{y}%</i><i class="e2" style="width:{p}%">{p}%</i><i class="e3" style="width:{no}%">{no if no>12 else ""}{"%" if no>12 else ""}</i></div></div>'
        for n, y, p, no, c in meds)
    tod = [("Night", 2), ("Morning", 9), ("Afternoon", 5), ("Evening", 3)]
    tods = "".join(
        f'<div class="tod-c" style="background:{t["r"][min(4, v//2)]};color:{t["rtext"][min(4, v//2)]}"><b>{v}</b><span>{n}</span></div>'
        for n, v in tod)
    return (f'<div class="pad stathead"><h1 class="lt">Insights</h1><span class="pro">{ic("lock",13,2.2)}PRO</span></div>'
            '<div class="stgap"></div>'
            f'<div class="pad"><div class="panel"><div class="ph"><span>Headache days per month</span></div>'
            f'<div class="mbars">{bars}</div><div class="key"><span><i class="mg"></i>Migraine</span><span><i class="ha"></i>Headache</span></div></div>'
            f'<div class="panel"><div class="ph"><span>Top triggers</span><em>% of attacks</em></div>{trows}</div>'
            f'<div class="panel"><div class="ph"><span>Medication helped</span></div>{mrows}'
            f'<div class="key"><span><i class="e1"></i>Yes</span><span><i class="e2"></i>Partly</span><span><i class="e3"></i>No</span></div></div>'
            f'<div class="panel"><div class="ph"><span>When attacks start</span><em>last 6 months</em></div><div class="tods">{tods}</div></div>'
            f'</div>' + tabbar(d, 2))

# ================================================================ CSS
BASE_CSS = """
*{box-sizing:border-box;margin:0;padding:0}
body{background:#1a1a1c;font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","SF Pro",system-ui,sans-serif;-webkit-font-smoothing:antialiased;color:#eee}
.page{padding:56px 64px 72px}
.ph1{font-size:40px;font-weight:700;letter-spacing:-.02em;color:#fff}
.psub{font-size:17px;color:#9a9aa2;margin-top:8px;max-width:1100px;line-height:1.45}
.rowlab{font-size:13px;font-weight:600;letter-spacing:.12em;text-transform:uppercase;color:#8a8a92;margin:48px 0 18px}
.row{display:flex;gap:44px}
.frame{display:flex;flex-direction:column;gap:14px}
.flab{font-size:14px;color:#a0a0a8;font-weight:500;padding-left:6px}
.phone{width:390px;height:844px;border-radius:55px;overflow:hidden;position:relative;background:var(--bg);color:var(--text);
  box-shadow:0 0 0 10px #050506,0 0 0 11px #3a3a3e,0 30px 60px rgba(0,0,0,.5)}
.sb{height:54px;display:flex;align-items:center;justify-content:space-between;padding:6px 34px 0 50px;font-weight:600;font-size:17px;position:relative;z-index:5}
.sb-r{display:flex;gap:7px;align-items:center}
.hb{position:absolute;bottom:8px;left:50%;transform:translateX(-50%);width:139px;height:5px;border-radius:3px;background:var(--text);opacity:.85;z-index:20}
.ic{display:block;flex:none}
.pad{padding-left:20px;padding-right:20px}
.chips{display:flex;flex-wrap:wrap;gap:8px}
.chip{display:inline-flex;align-items:center;gap:7px;height:40px;padding:0 15px;font-size:16px;font-weight:500;background:var(--fill);color:var(--text)}
.chip.on{background:var(--accentFill);color:#fff}
.seg{display:flex;background:var(--fill);padding:3px}
.seg span{flex:1;display:flex;align-items:center;justify-content:center;gap:7px;height:44px;font-size:16px;font-weight:600;color:var(--text2)}
.seg span.on{background:var(--surface);color:var(--text);box-shadow:0 1px 3px rgba(0,0,0,.12)}
.seg.sm span{height:34px;font-size:14px}
.behind{position:absolute;inset:0;background:var(--bg)}
.scrim{position:absolute;inset:0;background:var(--dim)}
.sheet{position:absolute;left:0;right:0;top:62px;bottom:0;background:var(--surface);overflow:hidden}
.grab{width:38px;height:5px;border-radius:3px;background:var(--text2);opacity:.45;margin:8px auto 0}
.sheet-h{display:flex;justify-content:space-between;align-items:center;padding:12px 20px 10px;font-size:17px}
.sheet-h b{font-weight:600}
.sh-l{color:var(--text2)} .sh-r{color:var(--accent);font-weight:600}
.sheet-body{padding:0 20px}
.lsec{margin-top:16px}
.lh{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:10px;font-size:15px;font-weight:600;color:var(--text2)}
.lh em{font-style:normal;font-weight:700;font-size:16px}
.times{display:flex;gap:10px}
.tbox{flex:1;background:var(--fill);padding:10px 14px}
.tbox span{display:block;font-size:13px;color:var(--text2);font-weight:500}
.tbox b{display:block;font-size:17px;font-weight:600;margin-top:2px}
.tbox b.muted{color:var(--accent)}
.med{background:var(--fill);padding:12px 14px}
.med-h{display:flex;gap:12px;align-items:center}
.med-h b{display:block;font-size:16px;font-weight:600}
.med-h span{font-size:13px;color:var(--text2)}
.med-ic{width:34px;height:34px;display:flex;align-items:center;justify-content:center;background:var(--tint);color:var(--accent)}
.helped{display:flex;align-items:center;gap:12px;margin-top:12px}
.hl{font-size:14px;color:var(--text2);font-weight:500}
.seg3{flex:1;display:flex;gap:6px}
.seg3 span{flex:1;height:40px;display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:600;background:var(--surface);color:var(--text)}
.seg3 span.on{background:var(--accentFill);color:#fff}
.addmed{display:flex;align-items:center;gap:8px;color:var(--accent);font-weight:600;font-size:16px;padding:12px 2px 0}
.notes{background:var(--fill);padding:12px 14px;font-size:16px;color:var(--text2);height:70px}
.tabbar{position:absolute;left:0;right:0;bottom:0;height:84px;display:flex;justify-content:space-around;padding:8px 10px 0;background:var(--bg)}
.tab{display:flex;flex-direction:column;align-items:center;gap:3px;font-size:10.5px;font-weight:500;color:var(--text2);width:80px}
.tab.on{color:var(--accent)}
.cta-wrap{position:absolute;left:20px;right:20px;bottom:100px}
.btn-log{height:64px;display:flex;align-items:center;justify-content:center;gap:10px;background:var(--accentFill);color:#fff;font-size:19px;font-weight:600}
.btn-log.quiet{background:var(--fill);color:var(--text)}
.mstats{display:flex}
.ms{flex:1}
.ms b{display:block;font-variant-numeric:tabular-nums}
.ms span{display:block;font-size:13px;color:var(--text2);line-height:1.25;margin-top:4px}
.sect{margin-top:28px}
.sh{font-size:13px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:var(--text2);margin-bottom:12px}
.ibadge{display:flex;flex-direction:column;align-items:center;justify-content:center;width:46px;height:46px}
.ibadge b{font-size:20px;font-weight:700;line-height:1}
.ibadge.big{width:64px;height:64px}
.ibadge.big b{font-size:28px}
.ibadge.big span{font-size:11px;font-weight:600;opacity:.8;margin-top:2px}
.live{width:9px;height:9px;border-radius:50%;background:var(--accent);box-shadow:0 0 0 4px var(--tint)}
.att-top{display:flex;align-items:center;gap:10px}
.att-k{font-size:15px;font-weight:600;color:var(--accent)}
.att-row{display:flex;gap:10px;margin-top:16px}
.ghost{flex:1;height:48px;display:flex;align-items:center;justify-content:center;gap:8px;font-size:15px;font-weight:600;background:var(--fill);color:var(--text)}
.btn-end{margin-top:10px;height:60px;display:flex;align-items:center;justify-content:center;gap:10px;background:var(--accentFill);color:#fff;font-size:18px;font-weight:600}
/* calendar */
.calhead{display:flex;justify-content:space-between;align-items:flex-end}
.cal-nav{display:flex;gap:8px;padding-bottom:6px}
.cal-nav span{width:40px;height:40px;display:flex;align-items:center;justify-content:center;background:var(--fill);color:var(--text)}
.calsum{display:flex;gap:16px;font-size:14px;color:var(--text2);margin:6px 0 16px}
.calsum b{color:var(--text);font-weight:600}
.wk{display:grid;grid-template-columns:repeat(7,1fr);font-size:12px;font-weight:600;color:var(--text2);text-align:center;margin-bottom:6px}
.grid{display:grid;grid-template-columns:repeat(7,1fr);gap:5px}
.cd{height:46px;display:flex;flex-direction:column;align-items:center;justify-content:center;position:relative;font-size:16px;color:var(--text)}
.cd b{font-weight:500;line-height:1}
.cd i{font-style:normal;font-size:10px;font-weight:700;opacity:.85;margin-top:3px;line-height:1}
.cd.hit b{font-weight:600}
.cd.mig::after{content:"";position:absolute;top:5px;right:5px;width:6px;height:6px;border-radius:50%;background:currentColor;opacity:.9}
.cd.today{box-shadow:inset 0 0 0 2px var(--accent)}
.cd.picked{box-shadow:0 0 0 2px var(--bg),0 0 0 4px var(--text)}
.legend{display:flex;gap:6px;margin-top:16px}
.legend span{flex:1;display:flex;flex-direction:column;gap:5px;font-size:11px;color:var(--text2);font-weight:500;text-align:center}
.legend i{height:8px}
.legend2{font-size:12px;color:var(--text2);margin-top:10px;display:flex;align-items:center;gap:6px}
.mdot{width:6px;height:6px;border-radius:50%;background:var(--text2);display:inline-block}
.detail{margin-top:16px;background:var(--surface);padding:16px}
.dt-h{display:flex;justify-content:space-between;align-items:center}
.dt-k{font-size:13px;color:var(--text2);font-weight:500}
.dt-t{font-size:18px;font-weight:600;margin-top:2px}
.dt-rows{margin-top:12px;display:flex;flex-direction:column;gap:8px}
.dt-rows div{display:flex;gap:10px;align-items:center;font-size:15px;color:var(--text)}
.dt-rows .ic{color:var(--text2)}
/* stats */
.stathead{display:flex;align-items:center;gap:12px}
.pro{display:inline-flex;align-items:center;gap:4px;font-size:11px;font-weight:700;letter-spacing:.08em;padding:5px 9px;background:var(--tint);color:var(--accent);margin-top:6px}
.seg-range{margin:12px 0 14px}
.panel{background:var(--surface);padding:12px 16px;margin-bottom:8px}
.ph{display:flex;justify-content:space-between;align-items:baseline;font-size:15px;font-weight:600;margin-bottom:10px}
.ph em{font-style:normal;font-size:12px;font-weight:500;color:var(--text2)}
.mbars{display:flex;justify-content:space-between;align-items:flex-end;height:114px;padding:0 4px}
.mbar{display:flex;flex-direction:column;align-items:center;gap:6px;width:40px}
.mstack{display:flex;flex-direction:column;align-items:center;width:30px}
.mstack em{font-style:normal;font-size:12px;font-weight:600;color:var(--text2);margin-bottom:4px}
.mstack i{display:block;width:100%}
.mbar span{font-size:12px;color:var(--text2)}
.mbar:last-child span{color:var(--text);font-weight:600}
i.mg{background:var(--mig)} i.ha{background:var(--ha)}
.key{display:flex;gap:14px;margin-top:10px;font-size:12px;color:var(--text2)}
.key span{display:flex;align-items:center;gap:6px}
.key i{width:10px;height:10px;display:inline-block}
.trow{display:flex;align-items:center;gap:10px;margin-top:8px;font-size:14px}
.tl{width:132px;display:flex;align-items:center;gap:7px;color:var(--text)}
.tl .ic{color:var(--text2)}
.ttrack{flex:1;height:8px;background:var(--fill)}
.ttrack i{display:block;height:100%;background:var(--accent)}
.trow b{width:36px;text-align:right;font-weight:600;font-variant-numeric:tabular-nums}
.mrow{margin-top:8px}
.mr-h{display:flex;justify-content:space-between;font-size:14px;margin-bottom:6px}
.mr-h b{font-weight:600} .mr-h span{color:var(--text2);font-size:12px}
.eff{display:flex;height:24px;gap:2px}
.eff i{display:flex;align-items:center;padding-left:7px;font-style:normal;font-size:11px;font-weight:700}
i.e1{background:var(--effYes);color:var(--onYes)} i.e2{background:var(--accentMid);color:var(--onMid)} i.e3{background:var(--fill);color:var(--text2)}
.tods{display:flex;gap:8px}
.tod{flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;font-size:12px;color:var(--text2)}
.chips.scroll{flex-wrap:nowrap;margin-right:-20px;overflow:hidden;-webkit-mask-image:linear-gradient(90deg,#000 85%,transparent)}
.chips.scroll .chip{flex:none}
.stgap{height:12px}
.last{margin-top:10px;display:flex;align-items:center;gap:12px;background:var(--surface);padding:10px 14px 10px 10px;color:var(--text2)}
.last div{flex:1}
.last b{display:block;font-size:16px;font-weight:600;color:var(--text)}
.last span:not(.ibadge){font-size:13px}
.ibadge.sm{width:40px;height:40px}
.ibadge.sm b{font-size:17px;color:inherit}
.tod-c{flex:1;height:46px;display:flex;flex-direction:column;align-items:center;justify-content:center;line-height:1.05}
.tod-c b{font-size:17px;font-weight:700}
.tod-c span{font-size:10.5px;font-weight:600;opacity:.85}
"""

def mode_vars(t, extra):
    v = {k: t[k] for k in ("bg","surface","fill","text","text2","sep","accent","accentFill","tint","mig","ha","dim")}
    v.update(extra)
    return ";".join(f"--{k}:{val}" for k, val in v.items())

DIR_CSS = {
"a": """
.serif,.lt,.s-num,.att-dur,.ms b,.dt-t{font-family:ui-serif,"New York","Iowan Old Style",Georgia,serif}
.lt{font-size:36px;font-weight:600;letter-spacing:-.01em;margin-top:2px}
.date{font-size:14px;font-weight:500;color:var(--text2);margin-top:8px}
.chip,.seg,.seg span,.tbox,.med,.seg3 span,.notes,.ghost,.btn-end,.btn-log,.ibadge,.cal-nav span,.detail,.panel,.pro,.med-ic,.tod-c,.ttrack,.ttrack i,.eff i,.legend i{border-radius:999px}
.tbox,.med,.notes,.detail,.panel{border-radius:24px}
.last{border-radius:999px}
.ibadge{border-radius:50%}
.med-ic{border-radius:50%}
.tod-c{border-radius:16px}
.sheet{border-radius:34px 34px 0 0}
.chip{padding:0 16px}
.streak{display:flex;align-items:center;gap:16px;margin-top:22px}
.s-num{font-size:128px;font-weight:300;line-height:.9;letter-spacing:-.04em;color:var(--accent)}
.s-lab{font-size:22px;line-height:1.2;font-weight:500}
.s-note{font-size:15px;color:var(--text2);margin-top:12px}
.strip{display:flex;gap:5px;margin-top:22px}
.dd{flex:1;height:44px;border-radius:999px;background:var(--fill);display:flex;align-items:flex-end;justify-content:center;padding-bottom:6px}
.dd i{font-style:normal;font-size:10px;font-weight:600;color:var(--text2)}
.dd.on i{color:inherit}
.ms b{font-size:44px;font-weight:400;line-height:1}
.mstats{background:var(--surface);border-radius:28px;padding:20px 22px}
.attack{margin-top:18px;background:var(--surface);border-radius:32px;padding:20px}
.att-mid{display:flex;justify-content:space-between;align-items:center;margin-top:14px}
.att-dur{font-size:52px;font-weight:400;line-height:1;letter-spacing:-.02em}
.att-sub{font-size:15px;color:var(--text2);margin-top:6px}
.streak-mini{font-size:15px;color:var(--text2);margin-top:16px;padding-left:4px}
.streak-mini b{color:var(--text);font-weight:600}
.ipick{display:flex;gap:4px}
.ip{flex:1;height:50px;border-radius:999px;display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:700}
.ip.sel{transform:scale(1.12);box-shadow:0 0 0 2.5px var(--surface),0 0 0 5px var(--text)}
.iscale{display:flex;justify-content:space-between;font-size:12px;color:var(--text2);margin-top:8px;padding:0 2px}
.cd{border-radius:50%;height:44px;width:44px;margin:auto}
.grid{row-gap:6px}
.lt + .cal-nav{}
.calhead .lt{font-size:36px}
.dt-t{font-size:21px;font-weight:600}
.ibadge:not(.big) b{font-size:19px}
.stathead .lt{font-size:36px}
.tabbar{background:var(--surface)}
""",
"b": """
.lt{font-size:30px;font-weight:700;letter-spacing:-.025em}
.date{font-size:13px;font-weight:600;color:var(--accent);text-transform:uppercase;letter-spacing:.08em;margin-top:6px}
.topbar{margin-bottom:14px}
.chip,.seg,.tbox,.med,.notes,.ghost,.btn-end,.btn-log,.cal-nav span,.detail,.panel,.tod-c,.band{border-radius:16px}
.seg span{border-radius:13px}
.chip{border-radius:12px}
.seg3 span{border-radius:10px}
.ibadge{border-radius:12px}
.med-ic{border-radius:10px}
.pro{border-radius:6px}
.btn-log,.btn-end{border-radius:18px}
.sheet{border-radius:28px 28px 0 0}
.band{margin:0 12px;padding:20px 20px 16px;background:var(--tint)}
.b-lab{font-size:15px;font-weight:600;color:var(--accent)}
.b-num{font-size:92px;font-weight:200;line-height:1;letter-spacing:-.05em;margin-top:2px;font-variant-numeric:tabular-nums}
.b-num span{font-size:22px;font-weight:500;letter-spacing:0;margin-left:10px;color:var(--text2)}
.bars14{display:flex;gap:4px;align-items:flex-end;height:84px;margin-top:10px}
.b14{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:5px;height:100%}
.b14 i{display:block;width:100%;border-radius:5px}
.b14 i[style*="--clear"]{height:6px!important;opacity:.9}
.b14 span{font-size:10px;color:var(--text2);height:11px;font-weight:600}
.kv{display:flex;justify-content:space-between;align-items:center;font-size:16px;padding:16px 4px 0;color:var(--text2)}
.kv b{color:var(--text);font-weight:600}
.mstats{gap:8px}
.last{border-radius:16px}
.ms{background:var(--surface);border-radius:16px;padding:14px 14px 14px}
.ms b{font-size:40px;font-weight:300;letter-spacing:-.03em;line-height:1}
.attackband{background:var(--surface);box-shadow:inset 0 0 0 1.5px var(--tint)}
.att-time{margin-left:auto;font-size:14px;color:var(--text2)}
.att-mid{display:flex;align-items:flex-end;gap:16px;margin-top:12px}
.att-dur{font-size:62px;font-weight:200;line-height:.95;letter-spacing:-.04em}
.att-dur small{font-size:22px;font-weight:500;letter-spacing:0;color:var(--text2);margin:0 4px 0 2px}
.meter-mini{display:flex;gap:3px;align-items:flex-end;margin-left:auto;padding-bottom:6px}
.meter-mini i{width:6px;border-radius:3px;display:block}
.att-int{padding-bottom:2px}
.att-int b{font-size:34px;font-weight:600}
.att-int span{font-size:15px;color:var(--text2)}
.meter{display:flex;gap:5px;align-items:flex-end;height:90px}
.mb{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:6px;height:100%}
.mb i{display:block;width:100%;border-radius:8px}
.mb span{font-size:14px;font-weight:600;color:var(--text2);width:26px;height:26px;display:flex;align-items:center;justify-content:center;border-radius:8px}
.mb.sel span{background:var(--text);color:var(--bg)}
.mb.sel i{box-shadow:0 0 0 2.5px var(--surface),0 0 0 4.5px var(--text)}
.cd{border-radius:12px}
.calhead .lt{font-size:30px}
.tabbar{left:16px;right:16px;bottom:24px;height:64px;border-radius:32px;padding:0 6px;align-items:center;background:var(--surface);box-shadow:0 8px 24px rgba(0,0,0,.14)}
.tab{font-size:10px}
.cta-wrap{bottom:102px}
.phone .sheet .grab{}
.detail{margin-top:14px}
""",
}

def phone(d, mode, fn):
    t = TOKENS[d][mode]
    mid = t["r"][2]
    extra = {"accentMid": t["r"][1], "onMid": t["rtext"][1] if mode == "light" else "#fff",
             "effYes": t["accentFill"] if mode == "light" else t["accent"], "onYes": "#fff" if mode == "light" else t["bg"],
             "clear": t["surface"]}
    return f'<div class="phone {mode}" style="{mode_vars(t, extra)}">{statusbar()}{fn(d, mode)}{homebar()}</div>'

def page(d):
    tk = TOKENS[d]
    title = {"a": "Direction A — Dusk", "b": "Direction B — Tide"}[d]
    sub = {"a": "Soft plum evening palette, New York serif for numbers and titles, pill shapes and borderless tonal surfaces. Feels like a quiet journal you open in a dark room.",
           "b": "Cool sea-glass teal moving into deep indigo, ultralight SF Pro numerals, squarer tiles, a full-bleed hero band and a floating tab bar. Clinical-calm, data-forward."}[d]
    screens = [("Home", home), ("Log sheet", log), ("Calendar", cal), ("Insights (Pro)", stats)]
    rows = ""
    for mode in ("light", "dark"):
        rows += f'<div class="rowlab">{mode} mode{" — home shown in calm state" if mode=="light" else " — home shown during an attack"}</div><div class="row">'
        for lab, fn in screens:
            rows += f'<div class="frame"><div class="flab">{lab}</div>{phone(d, mode, fn)}</div>'
        rows += '</div>'
    return (f'<!doctype html><html><head><meta charset="utf-8"><title>Migraine Log — {tk["name"]}</title>'
            f'<style>{BASE_CSS}{DIR_CSS[d]}</style></head><body><div class="page">'
            f'<div class="ph1">{title}</div><div class="psub">{sub}</div>{rows}</div></body></html>')

for d in ("a", "b"):
    with open(os.path.join(OUT, f"direction-{d}.html"), "w") as f:
        f.write(page(d))
print("ok")
