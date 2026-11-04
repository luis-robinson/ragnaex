"""Props de cenário low-poly (ToS-like): casa, árvore, pedra, pilar, muro, poço, fonte, lampião,
barraca, caixote, tenda, ruína, estátua. Cada um vira assets/models/prop_<kind>.glb e o MapBuilder
do Godot usa o GLB automaticamente no lugar do blockout quando ele existir.
    import build_props; build_props.build_all(r"<pasta>/ragnaex/assets/models")
"""
import bpy
import importlib
import os
import lowpoly_lib as lp

importlib.reload(lp)

STONE = (0.86, 0.80, 0.68)
ROOF = (0.80, 0.42, 0.34)
WOOD = (0.55, 0.40, 0.27)
LEAF = (0.40, 0.66, 0.38)
LEAF2 = (0.48, 0.74, 0.42)
ROCK = (0.62, 0.60, 0.58)
RUIN = (0.70, 0.68, 0.62)


def house():
    st = lp.material("m_stone", STONE)
    o = [lp.box("walls", (1.0, 1.0, 0.72), (0, 0, 0.36), st),
         lp.cylinder("roof", 0.0, 0.78, 0.5, (0, 0, 0.97), lp.material("m_roof", ROOF), 4, (0, 0, 0.785)),
         lp.box("door", (0.22, 0.04, 0.42), (0, -0.52, 0.21), lp.material("m_door", (0.4, 0.28, 0.18))),
         lp.box("window", (0.18, 0.04, 0.16), (0.3, -0.52, 0.5), lp.material("m_glass", (0.55, 0.75, 0.9))),
         lp.box("beam", (1.06, 1.06, 0.06), (0, 0, 0.72), lp.material("m_wood", WOOD))]
    return lp.join(o, "prop_house")


def tree():
    o = [lp.cylinder("trunk", 0.1, 0.16, 1.6, (0, 0, 0.8), lp.material("m_bark", (0.45, 0.32, 0.2)), 6),
         lp.sphere("crown", 0.95, (0, 0, 2.5), lp.material("m_leaf", LEAF), 7, 5, (1, 1, 1.15)),
         lp.sphere("crown2", 0.6, (0.35, 0.2, 3.1), lp.material("m_leaf2", LEAF2), 6, 4),
         lp.sphere("crown3", 0.5, (-0.4, -0.2, 2.2), lp.material("m_leaf2", LEAF2), 6, 4)]
    return lp.join(o, "prop_tree")


def rock():
    return lp.sphere("prop_rock", 0.7, (0, 0, 0.4), lp.material("m_rock", ROCK), 5, 4, (1, 0.85, 0.65))


def pillar():
    o = [lp.cylinder("col", 0.45, 0.55, 3.0, (0, 0, 1.5), lp.material("m_ruin", RUIN), 8),
         lp.box("cap", (1.3, 1.3, 0.3), (0, 0, 3.15), lp.material("m_ruin2", (0.75, 0.73, 0.68))),
         lp.box("base", (1.3, 1.3, 0.25), (0, 0, 0.12), lp.material("m_ruin2", (0.75, 0.73, 0.68)))]
    return lp.join(o, "prop_pillar")


def wall():
    st = lp.material("m_stone", STONE)
    o = [lp.box("wall", (4.0, 1.2, 2.5), (0, 0, 1.25), st)]
    for i in range(4):
        o.append(lp.box("merlon%d" % i, (0.5, 1.2, 0.5), (-1.5 + i * 1.0, 0, 2.75), lp.material("m_stone2", (0.9, 0.85, 0.74))))
    return lp.join(o, "prop_wall")


def well():
    o = [lp.cylinder("base", 0.8, 0.9, 0.85, (0, 0, 0.42), lp.material("m_stone", STONE), 8),
         lp.cylinder("post1", 0.05, 0.05, 1.6, (0.6, 0, 1.3), lp.material("m_wood", WOOD), 4),
         lp.cylinder("post2", 0.05, 0.05, 1.6, (-0.6, 0, 1.3), lp.material("m_wood", WOOD), 4),
         lp.cylinder("roof", 0.0, 1.1, 0.8, (0, 0, 2.4), lp.material("m_roof2", (0.6, 0.35, 0.3)), 4, (0, 0, 0.785))]
    return lp.join(o, "prop_well")


def fountain():
    o = [lp.cylinder("basin", 1.7, 1.85, 0.6, (0, 0, 0.3), lp.material("m_stone", STONE), 10),
         lp.cylinder("water", 1.45, 1.45, 0.1, (0, 0, 0.62), lp.material("m_water", (0.5, 0.75, 0.95), 0.4), 10),
         lp.cylinder("col", 0.25, 0.35, 1.6, (0, 0, 1.2), lp.material("m_stone", STONE), 8),
         lp.sphere("top", 0.45, (0, 0, 2.1), lp.material("m_water", (0.5, 0.75, 0.95), 0.4), 8, 5)]
    return lp.join(o, "prop_fountain")


def lamp():
    o = [lp.cylinder("post", 0.06, 0.09, 3.0, (0, 0, 1.5), lp.material("m_wood", WOOD), 6),
         lp.box("cage", (0.4, 0.4, 0.5), (0, 0, 3.1), lp.material("m_iron", (0.2, 0.2, 0.22))),
         lp.sphere("light", 0.16, (0, 0, 3.1), lp.material("m_light", (1.0, 0.85, 0.5), 3.0), 6, 4)]
    return lp.join(o, "prop_lamp")


def stall():
    o = [lp.box("table", (2.4, 1.4, 1.6), (0, 0, 0.8), lp.material("m_wood", WOOD)),
         lp.box("canopy", (3.1, 2.0, 0.12), (0, 0, 2.7), lp.material("m_cloth", (0.85, 0.3, 0.3))),
         lp.cylinder("pole1", 0.05, 0.05, 2.7, (1.4, 0.85, 1.35), lp.material("m_wood2", (0.4, 0.3, 0.2)), 4),
         lp.cylinder("pole2", 0.05, 0.05, 2.7, (-1.4, 0.85, 1.35), lp.material("m_wood2", (0.4, 0.3, 0.2)), 4)]
    return lp.join(o, "prop_stall")


def crate():
    o = [lp.box("crate", (1, 1, 1), (0, 0, 0.5), lp.material("m_wood", WOOD)),
         lp.box("band1", (1.04, 1.04, 0.12), (0, 0, 0.25), lp.material("m_wood2", (0.4, 0.3, 0.2))),
         lp.box("band2", (1.04, 1.04, 0.12), (0, 0, 0.75), lp.material("m_wood2", (0.4, 0.3, 0.2)))]
    return lp.join(o, "prop_crate")


def tent():
    o = [lp.cylinder("tent", 0.0, 2.2, 2.2, (0, 0, 1.1), lp.material("m_tent", (0.55, 0.3, 0.25)), 4, (0, 0, 0.785)),
         lp.box("flap", (0.6, 0.05, 1.0), (0, -1.1, 0.5), lp.material("m_tent2", (0.35, 0.2, 0.15)))]
    return lp.join(o, "prop_tent")


def ruin():
    o = [lp.box("ruin", (5.0, 1.0, 1.8), (0, 0, 0.9), lp.material("m_ruin", RUIN)),
         lp.box("ruin2", (1.5, 1.0, 1.0), (-1.5, 0, 2.3), lp.material("m_ruin", RUIN))]
    return lp.join(o, "prop_ruin")


def statue():
    o = [lp.box("pedestal", (1.2, 1.2, 0.9), (0, 0, 0.45), lp.material("m_stone", STONE)),
         lp.sphere("figure", 0.42, (0, 0, 1.8), lp.material("m_stone3", (0.92, 0.88, 0.8)), 6, 4, (0.8, 0.8, 1.6))]
    return lp.join(o, "prop_statue")


def fence():
    o = [lp.box("rail", (2.0, 0.08, 0.1), (0, 0, 0.7), lp.material("m_wood", WOOD)),
         lp.box("rail2", (2.0, 0.08, 0.1), (0, 0, 0.35), lp.material("m_wood", WOOD)),
         lp.box("post1", (0.12, 0.12, 1.0), (-0.9, 0, 0.5), lp.material("m_wood2", (0.4, 0.3, 0.2))),
         lp.box("post2", (0.12, 0.12, 1.0), (0.9, 0, 0.5), lp.material("m_wood2", (0.4, 0.3, 0.2)))]
    return lp.join(o, "prop_fence")


BUILDERS = {"house": house, "tree": tree, "rock": rock, "pillar": pillar, "wall": wall, "well": well,
            "fountain": fountain, "lamp": lamp, "stall": stall, "crate": crate, "tent": tent,
            "ruin": ruin, "statue": statue, "fence": fence}


def build_all(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for kind, fn in BUILDERS.items():
        lp.clear_scene()
        obj = fn()
        obj.name = "prop_" + kind
        lp.export_glb(os.path.join(out_dir, "prop_%s.glb" % kind), [obj])
    print("props done")


if __name__ == "__main__":
    import sys
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    build_all(out)
