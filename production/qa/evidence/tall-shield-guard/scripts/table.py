import json, sys
S = "C:/Users/luisf/AppData/Local/Temp/claude/63157312b71971d4/e41ef7db-fe62-4976-a5ec-aa8286f05a5c/scratchpad/tallguard/out/"
d3 = json.load(open(S + "run3.json"))
d1 = json.load(open(S + "run1.json"))["styles"]
FAR = ["presa", "perdao", "serpente", "pal_t20", "bis_s30", "pal_t30", "relicario", "veredito", "asa_negra", "suspiros"]


def cls(a):
    return "close" if a <= 0.06 else "mid" if a <= 0.12 else "far"


def mx(d, part=None):
    return max([v for k, v in d.items() if part is None or k.startswith(part)] or [0])


def bind(s):
    r = d1[s]
    f = {"guard": r["guard"]["air"], "run": r["run"]["air"], "idle": r["idle"]["air"]}
    top = max(f.values())
    return "/".join(k for k, v in f.items() if v >= top - 0.021 and v > 0.06) or "none", f


out = []
out.append("| Shield | Was | Height | Floor by clip alone (guard / run / idle) | Binds | Now | Control | A | A+ | B | B trim | B area lost | B height |")
out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
cnt = {k: {"close": 0, "mid": 0, "far": 0} for k in ("antes", "controle", "A", "A+", "B")}
for s, r in d3["styles"].items():
    b, f = bind(s)
    for k in cnt:
        cnt[k][cls(r[k]["ar"])] += 1
    cell = lambda k: "%.3f %s" % (r[k]["ar"], cls(r[k]["ar"]))
    out.append("| `%s` | %s | %.2f | %.2f / %.2f / %.2f | %s | %.3f | %.3f | %s | %s | %s | %s %.2f | %.0f%% | %.2f |" % (
        s, "far" if s in FAR else "mid", r["alt"], f["guard"], f["run"], f["idle"], b, r["antes"]["ar"], r["controle"]["ar"], cell("A"), cell("A+"), cell("B"),
        r["B"]["mode"], r["B"]["k"], 100 * r["B"]["perda"], r["B"]["alt"]))
out.append("")
out.append("Counts (close / mid / far): " + "; ".join("%s %d / %d / %d" % (k, c["close"], c["mid"], c["far"]) for k, c in cnt.items()))
out.append("")
out.append("| Shield | Body contacts m+f (now / A / A+ / B) | Set helmets, worst clip (now / A / A+ / B) | Set chest and skirt, worst clip (now / A / A+ / B) | Lowest point in guard, m (now / A / B) | Lowest point in run, m (now / A+) |")
out.append("|---|---|---|---|---|---|")
for s, r in d3["styles"].items():
    V = ("antes", "A", "A+", "B")
    g = lambda k: r[k]["minz"].get("block_shield", r[k]["minz"].get("block_shield_tall"))
    rn = lambda k: r[k]["minz"].get("run", r[k]["minz"].get("run_shield_tall"))
    out.append("| `%s` | %s | %s | %s | %.2f / %.2f / %.2f | %.2f / %.2f |" % (
        s, " / ".join(str(mx(r[k]["toques"])) for k in V), " / ".join(str(mx(r[k]["elmo"])) for k in V), " / ".join(str(mx(r[k]["conj"])) for k in V),
        g("antes"), g("A"), g("B"), rn("antes"), rn("A+")))
out.append("")
out.append("| Shield | Trim ladder: air (area lost) for canto 0.70 / 0.40 / 0.15 and topo 0.70 / 0.40 / 0.15 |")
out.append("|---|---|")
for s, r in d3["styles"].items():
    out.append("| `%s` | %s |" % (s, " ; ".join("%.3f (%.0f%%)" % (e["ar"], 100 * e["perda"]) for e in r["trims"])))
open(S + "table.md", "w").write("\n".join(out))
print("\n".join(out))
print(d3["kits"])
