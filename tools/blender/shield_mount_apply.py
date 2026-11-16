"""Grava em chibi_kit.SHIELD_MOUNTS as montagens achadas por shield_mount_study.py (python comum, sem Blender):

  python tools/blender/shield_mount_apply.py <pasta de rascunho>/study.json

Troca só o bloco entre as marcas "# SHIELD_MOUNTS: início" e "# SHIELD_MOUNTS: fim" do chibi_kit.py, e dentro dele só os
estilos que o json traz: as outras entradas ficam como estão (estudo rodado com --only não derruba o resto).
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main(path):
    data = json.load(open(path, encoding="utf-8"))
    p = os.path.join(HERE, "chibi_kit.py")
    src = open(p, encoding="utf-8", newline="").read()
    nl = "\r\n" if "\r\n" in src else "\n"
    a, b = src.index("# SHIELD_MOUNTS: início"), src.index("# SHIELD_MOUNTS: fim")
    b = b + len("# SHIELD_MOUNTS: fim")
    entries = {}                        # estilo -> linha; começa com as que já estão no kit, na ordem delas
    for line in src[a:b].splitlines():
        m = re.match(r'\s+"(\w+)": \(', line)
        if m:
            entries[m.group(1)] = line.rstrip()
    kept = set(entries)
    new = 0
    for st, m in data["mounts"].items():
        if st == "_comum":
            continue                    # o escudo sem estilo (wpn_off_shield) usa a montagem do "juramento"
        s = data["styles"][st]
        gda = (s.get("depois") or {}).get("gda")
        note = ("gap %.3f drop %.2f along %.2f" % tuple(gda)) if gda else "face própria (shield_mount.STYLE_MOUNT)"
        entries[st] = '    "%s": (%.1f, %.1f, %.1f, (%.3f, %.3f, %.3f)),%s# %s' % (st, m[0], m[1], m[2], m[3][0], m[3][1], m[3][2], " " * max(1, 12 - len(st)), note)
        kept.discard(st)
        new += 1
    lines = ["# SHIELD_MOUNTS: início (gerado por shield_mount_apply.py a partir de shield_mount_study.py; não edite à mão)", "SHIELD_MOUNTS = {"]
    lines += list(entries.values()) + ["}", "# SHIELD_MOUNTS: fim"]
    src = src[:a] + nl.join(lines) + src[b:]
    open(p, "w", encoding="utf-8", newline="").write(src)
    print("SHIELD_MOUNTS: %d estilos gravados, %d mantidos como estavam (%d no total) em %s" % (new, len(kept), len(entries), p))


if __name__ == "__main__":
    main(sys.argv[1])
