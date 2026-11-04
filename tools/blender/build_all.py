"""Gera TODOS os modelos (personagens, monstros, props) em assets/models.

Headless (sem MCP):
    blender -b --python tools/blender/build_all.py -- "C:/Users/luisf/Desktop/projects/ragnaex/assets/models"

Via Blender MCP (execute_blender_code):
    import sys; sys.path.append(r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender")
    import build_all; build_all.run(r"C:/Users/luisf/Desktop/projects/ragnaex/assets/models")
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.append(HERE)


def run(out_dir=None):
    import importlib
    import chibi_kit, mob_kit, prop_kit
    for m in (chibi_kit, mob_kit, prop_kit):
        importlib.reload(m)
    out_dir = out_dir or os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
    chibi_kit.build_kits(out_dir)     # personagens/NPCs: kit_male/kit_female com todas as peças de equipamento
    mob_kit.build_all(out_dir)          # monstros esculpidos (mesmo rig de build_monsters)
    prop_kit.build_all(out_dir)         # construções e props esculpidos (1 mesh por prop)
    print("ALL DONE ->", out_dir)


if __name__ == "__main__":
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else None
    run(out)
