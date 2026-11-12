"""Roda o build de uma zona sem janela e fotografa as 3 câmeras do loop de layout.

    set RAGNAEX_ROOT=<worktree>
    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- <modulo> <pasta_png> [--export] [--only=<id,...>]

<modulo> = build_field_coast | build_city_port | build_field_ruins | build_dungeons (com --only=dg_goblin).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
mod_name, out_dir = args[0], args[1]
export = "--export" in args
only = next((a.split("=", 1)[1].split(",") for a in args if a.startswith("--only=")), None)
os.makedirs(out_dir, exist_ok=True)

import importlib
import render_views
mod = importlib.import_module(mod_name)
if only:
    mod.build(export=export, only=only)
else:
    mod.build(export=export)
if "--no_render" not in args:
    render_views.render(out_dir, (only[0] if only else mod_name.replace("build_", "")))
