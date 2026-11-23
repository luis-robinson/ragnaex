"""Portais do Ato III para mapas que ainda não estão no MapsCatalog (GDD ato3-excesso-45-50 §2.1, WP6).

Os builds gravam em data["future_portals"] a passagem para um mapa que ainda não existe na sim (portal para mapa que não
existe quebra `_check_portal_arrivals` e a viagem dos bots). Quando o mapa entra no catálogo, o id dele vai em `READY`
e a passagem vira portal de verdade, de dois jeitos que dão o MESMO JSON:

  * no build: os build_<zona>.py do Ato III chamam `promote(z.data)` antes do `z.finish`;
  * sem refazer a zona (o GLB não muda: o portal é só dado): `python tools/blender/zones/act3_ready.py [--apply]`
    reescreve data/zones/<zona>.json com o mesmo `json.dump` do zone_lib (sem `--apply` só mostra o que mudaria).

Sem bpy: roda com qualquer Python. O portão (nível, missões) de cada portal fica no MapsCatalog.PORTAL_GATES; o que o
build sabe vai em data["portal_gate_hint"][<id>] (`level`, `if`).
"""
import json
import os
import sys

# mapa de destino -> ponto de chegada nele (o `target_pos` do portal). Masmorras: places.DUNGEON_ARRIVE.
ARRIVE = {
    "dg_cellars": (0.0, 44.0),
    "dg_mirrors": (0.0, 44.0),
    "dg_conservatory": (0.0, 44.0),
    "rift_heart": (0.0, 44.0),
    "rift_garden": (0.0, -4.0),          # build_rift.ARRIVE
}
# mapas já registrados no MapsCatalog (WP13 liga aqui e roda este arquivo com --apply)
READY = ("dg_cellars", "dg_mirrors", "dg_conservatory", "rift_garden", "rift_heart")      # WP6 (2026-11-23)
ZONES = ("field_perfume", "city_lumeria", "field_parade", "rift_garden")
ROOT = os.environ.get("RAGNAEX_ROOT", os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))).replace("\\", "/")


def promote(data, ready=None):
    """Passa para data["portals"] cada future_portal cujo mapa está em `ready` (padrão READY). Devolve os ids movidos."""
    ready = READY if ready is None else ready
    moved, keep = [], []
    for p in data.get("future_portals", []):
        if p["target_map"] not in ready:
            keep.append(p)
            continue
        data["portals"].append({"id": p["id"], "pos": list(p["pos"]), "radius": 2.0, "target_map": p["target_map"],
                                "target_pos": list(ARRIVE[p["target_map"]]), "label": p["label"]})
        hint = {k: p[k] for k in ("level", "if", "quest") if k in p}
        if hint:
            data.setdefault("portal_gate_hint", {})[p["id"]] = hint
        moved.append(p["id"])
    if "future_portals" in data:
        data["future_portals"] = keep
    return moved


def main(argv):
    apply = "--apply" in argv
    for zone in ZONES:
        path = "%s/data/zones/%s.json" % (ROOT, zone)
        if not os.path.exists(path):
            print("sem arquivo:", path)
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        moved = promote(data)
        print("%s: %s" % (zone, moved or "nada a mover"))
        if moved and apply:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=1)
            print("  gravado:", path)


if __name__ == "__main__":
    main(sys.argv[1:])
