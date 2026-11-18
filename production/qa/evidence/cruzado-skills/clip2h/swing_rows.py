"""Linhas da tabela de golpes para atk_2h_chain_a/b/c (medidas com tools/lineup/arc_measure.gd)."""
import json, re, subprocess, sys, math
ROOT = r"C:/Users/luisf/Desktop/projects/ragnaex"
G = r"C:/Users/luisf/Desktop/Godot_v4.7.2-stable_win64_console.exe"
TAB = ROOT + "/production/qa/evidence/attack-arcs/swing_table.json"
OFF = {"sword2h": "-0.2169,-0.8317,-0.7654", "mace2h": "-0.2199,-0.8602,-0.7614"}
IMPACT = {"atk_2h_chain_a": 5, "atk_2h_chain_b": 6, "atk_2h_chain_c": 7}
WRITE = "--write" in sys.argv


def measure(clip, off):
    out = subprocess.run([G, "--headless", "--path", ROOT, "-s", "tools/lineup/arc_measure.gd", "--", "--model=kit_paladin_male", "--clip=" + clip,
                          "--bones=hand.R", "--offset=" + off], capture_output=True, text=True, timeout=180, stdin=subprocess.DEVNULL).stdout
    line = next(l for l in out.splitlines() if l.startswith("MEAS"))
    return {int(f): [float(x), float(y), float(z)] for f, x, y, z in re.findall(r"f(\d+)\(([-\d.]+),([-\d.]+),([-\d.]+)\)", line)}


raw = open(TAB, "rb").read()
tab = json.loads(raw.decode("utf-8"))
same = json.dumps(tab, indent=1, ensure_ascii=False).replace("\n", "\r\n").encode("utf-8") == raw
print("round trip igual:", same)
tab["rows"] = [r for r in tab["rows"] if r["clip"] not in IMPACT]
rows = []
for clip, imp in IMPACT.items():
    for fam, off in OFF.items():
        p = measure(clip, off)
        last = max(p)
        fr = lambda f: p[max(2, min(last, f))]            # o quadro 1 do arc_measure sai errado (todos os clipes): começa no 2
        a, b = fr(imp - 2), fr(imp + 1)
        dx = b[0] - a[0]
        steps = [(f, [fr(f + 1)[i] - fr(f)[i] for i in range(3)]) for f in range(max(2, imp - 2), imp + 1)]
        f_fast, sv = max(steps, key=lambda s: sum(c * c for c in s[1]))
        n2 = sum(c * c for c in sv)
        sh = [sv[0] ** 2 / n2, sv[1] ** 2 / n2, sv[2] ** 2 / n2]
        typ = "horizontal" if sh[0] >= 0.5 else "overhead" if sh[1] >= 0.5 else "thrust" if sh[2] >= 0.5 else "diagonal"
        sweep = 0 if abs(dx) < 0.10 else (1 if dx > 0 else -1)
        fast = 0 if abs(sv[0]) < 0.10 else (1 if sv[0] > 0 else -1)
        allsteps = [(f + 1, math.dist(p[f], p[f + 1])) for f in range(2, last)]
        pk = max(allsteps, key=lambda s: s[1])
        win = [fr(f) for f in range(imp - 4, imp + 3)]
        dy = b[1] - a[1]
        row = {"kit": "kit_paladin_male", "clip": clip, "offhand": "", "hand": "main", "piece": "wpn_main_" + fam, "bone": "hand.R", "role": "skill",
               "sweep": sweep, "sweep_dx_m": round(dx, 2), "type": typ, "share_lateral": round(sh[0], 2), "share_vertical": round(sh[1], 2),
               "share_forward": round(sh[2], 2), "strike_vec": [round(c, 2) for c in sv], "strike_peak_speed": round(math.sqrt(n2), 2),
               "speed_into_impact": round(math.dist(fr(imp - 1), fr(imp)), 2), "vertical_dir": "down" if dy < -0.1 else "up" if dy > 0.1 else "level",
               "reach_at_impact": round(math.hypot(p[imp][0], p[imp][2]), 2), "fwd_at_impact": round(p[imp][2], 2),
               "h_min": round(min(w[1] for w in win), 2), "h_max": round(max(w[1] for w in win), 2), "h_at_impact": round(p[imp][1], 2),
               "impact_frame": imp, "peak_speed_frame": pk[0], "peak_speed_m_per_frame": round(pk[1], 2), "clip_frames": last,
               "window": [max(2, imp - 4), min(last, imp + 2)],
               "path": [{"k": f - imp, "p": [round(c, 3) for c in p[f]]} for f in range(max(2, imp - 4), min(last, imp + 2) + 1)],
               "sweep_fast": fast, "sweep_ambiguous": fast != sweep and typ != "overhead" and sweep != 0 and fast != 0, "weapon_family": fam,
               "below_ground": min(w[1] for w in win) < -0.05, "impact_off_peak": abs(pk[0] - imp) > 2,
               "measured_with": "tools/lineup/arc_measure.gd 2026-11-17 (ponta da arma por --offset; quadro 1 fora; sem os campos de ângulo)"}
        rows.append(row)
        print(clip, fam, "sweep %+d dx %+.2f tipo %s shares %s rapido f%d->%d %s pico f%d h %.2f..%.2f imp %.2f" % (
            sweep, dx, typ, [round(x, 2) for x in sh], f_fast, f_fast + 1, [round(c, 2) for c in sv], pk[0], row["h_min"], row["h_max"], row["h_at_impact"]))
tab["rows"] += rows
if WRITE and same:
    open(TAB, "wb").write(json.dumps(tab, indent=1, ensure_ascii=False).replace("\n", "\r\n").encode("utf-8"))
    print("gravado", len(rows), "linhas")
