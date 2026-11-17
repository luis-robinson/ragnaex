# Agrupa os episódios do stuck_probe (json de --out) em causas e pontos quentes.
#   python tools/tests/stuck_cluster.py production/qa/evidence/bot-stuck/stuck_s*.json
import json, sys, glob, re, collections
files = sys.argv[1:]
eps = []
alive = 0.0
for f in files:
    d = json.load(open(f, encoding="utf-8"))
    alive += d["alive_bot_s"]
    for e in d["episodes"]:
        e["seed"] = d["seed"]
        eps.append(e)

def cause(e):
    gl = e.get("goal_line", "") or ""
    fl = e.get("foe_line", "") or ""
    st = e["state"]
    if e["kind"] == "parado":
        return "parado:%s" % st
    aim = e["aim"]; fp = e.get("foe_pos")
    aim_is_foe = fp is not None and abs(aim[0]-fp[0]) < 0.6 and abs(aim[1]-fp[1]) < 0.6
    if aim_is_foe and fl:
        k = re.sub(r"\(.*", "", fl.split(":", 1)[1])
        return "chase_foe_blocked:%s%s" % (k, "+water" if e.get("foe_water") else "")
    td = e.get("town_d")
    if td is not None and abs(td) < 3.0 and st in ("TRAVEL", "HUNT", "RETURN", "TOWN_WALK", "SHOP"):
        return "town_gate_pingpong"
    if gl:
        k = re.sub(r"\(.*", "", gl.split(":", 1)[1])
        return "goal_blocked:%s%s" % (k, "+water" if e.get("goal_water") else "")
    if e.get("party") == "follow":
        return "follow"
    return "open_line"

stuck = [e for e in eps if e["kind"] == "preso"]
tot = sum(e["dur"] for e in stuck)
print("files=%d alive_bot_s=%.0f stuck_bot_s=%.0f rate=%.4f eps=%d frozen=%d" % (len(files), alive, tot, tot / alive, len(stuck), len(eps) - len(stuck)))
c = collections.Counter(); cs = collections.Counter()
for e in eps:
    k = cause(e); c[k] += 1; cs[k] += e["dur"]
print("\nCAUSES (eps, bot_s):")
for k, v in cs.most_common():
    print("  %-40s %4d %7.0f" % (k, c[k], v))
st = collections.Counter(); sts = collections.Counter()
for e in stuck:
    k = e["state"] + ("+combat" if e["combat"] else "") + ("+follow" if e.get("party") == "follow" else ""); st[k] += 1; sts[k] += e["dur"]
print("\nSTATES:"); [print("  %-30s %4d %7.0f" % (k, st[k], v)) for k, v in sts.most_common()]
ends = collections.Counter(e["end"] for e in eps); print("\nENDS:", dict(ends))
durs = sorted(e["dur"] for e in stuck)
if durs:
    print("dur p50=%.0f p90=%.0f max=%.0f  >=60s: %d" % (durs[len(durs)//2], durs[int(len(durs)*.9)], durs[-1], sum(1 for x in durs if x >= 60)))
# hotspots: map + 8 m cell
H = 8.0
hot = {}
for e in eps:
    key = (e["map"], int(e["x"] // H), int(e["z"] // H))
    h = hot.setdefault(key, {"n": 0, "s": 0.0, "bots": set(), "seeds": set(), "x": 0, "z": 0, "causes": collections.Counter(), "ex": e})
    h["n"] += 1; h["s"] += e["dur"]; h["bots"].add((e["seed"], e["id"])); h["seeds"].add(e["seed"]); h["x"] += e["x"]; h["z"] += e["z"]
    h["causes"][cause(e)] += 1
    if e["dur"] > h["ex"]["dur"]:
        h["ex"] = e
print("\nHOTSPOTS (top 25 by bot_s):")
for key, h in sorted(hot.items(), key=lambda kv: -kv[1]["s"])[:25]:
    ex = h["ex"]
    print("%-14s %7.1f,%7.1f eps=%2d bot_s=%5.0f bots=%d seeds=%d causes=%s" % (key[0], h["x"]/h["n"], h["z"]/h["n"], h["n"], h["s"], len(h["bots"]), len(h["seeds"]), dict(h["causes"])))
    print("     ex: st=%s dest=%s aim=%s goal_line=%s foe=%s@%s foe_line=%s near=%s town_d=%s portal=%s" % (ex["state"], ex.get("dest"), ex["aim"], ex.get("goal_line"), ex.get("foe"), ex.get("foe_d"), ex.get("foe_line"), ex.get("near", [])[:3], ex.get("town_d"), ex.get("portal")))
# per map
pm = collections.Counter(); pms = collections.Counter()
for e in stuck:
    pm[e["map"]] += 1; pms[e["map"]] += e["dur"]
print("\nPER MAP:"); [print("  %-16s %4d %7.0f" % (k, pm[k], v)) for k, v in pms.most_common()]
