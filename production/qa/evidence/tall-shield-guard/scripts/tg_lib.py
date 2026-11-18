"""Tall-shield guard study (2026-11-15): shared helpers. Reads the shields-mount worktree tooling, writes nothing there."""
import sys, os, json, math, time
sys.dont_write_bytecode = True
W = "C:/Users/luisf/Desktop/projects/ragnaex/.claude/worktrees/shields-mount/"
sys.path.insert(0, W + "tools/blender")
import bpy
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
import chibi_kit as ck
import shield_kit
import shield_mount as sm
import shield_mount_study as st
assert ck.__file__.replace("\\", "/").startswith(W), ck.__file__

FAR = ["presa", "perdao", "serpente", "pal_t20", "bis_s30", "pal_t30", "relicario", "veredito", "asa_negra", "suspiros"]
MID = ["asa", "escama", "coluna", "cruel", "pal_g25", "pal_g30", "bis_b15"]
TALL = FAR + MID
KITS = (("paladin", "male"), ("bishop", "male"), ("paladin", "female"), ("bishop", "female"))
P = st.P


def in_kit(style, cid):
    return ck.style_class(style) in (None, cid)


def make_shield(base, style, name, mount=None, trim=None, strap=False):
    """kit_shield with an explicit mount, an optional model-space trim(co) and an optional strap."""
    mats = ck._kit_mats()
    gold = dict(mats, trim=ck.mat("m_escudo_ouro", (0.95, 0.66, 0.16), 0.32))
    obj = ck._join(shield_kit.FAMILIES[style](ck, name, gold), name)
    keep = ck.SHIELD_MOUNTS.get(style)
    if mount is not None:
        ck.SHIELD_MOUNTS[style] = mount
    try:
        rot = ck._shield_rot(style).to_4x4()
        c = ck._shield_anchor(base, style)[1]
        inner = shield_kit.INNER.get(style, 1.0)
        for vert in obj.data.vertices:
            co = vert.co * ck.SHIELD_SCALE * shield_kit.SIZES.get(style, 1.0)
            co.x *= inner if co.x < 0.0 else 1.0
            if trim is not None:
                co = trim(co)
            vert.co = rot @ co + c
        if strap:
            s = ck.kit_shield_strap(base, style, mats, obj)
            if len(s.data.vertices):
                obj = ck._join([obj, s], name)
            else:
                bpy.data.objects.remove(s, do_unlink=True)
    finally:
        if keep is not None:
            ck.SHIELD_MOUNTS[style] = keep
    shield_kit.hull(obj, ck.SHIELD_OUTLINE, ck.mat("m_contorno", (0.12, 0.1, 0.16), 0.9))
    ck.skin_rigid(obj, base["rig"], "forearm.L")
    return obj


def make_basis(base, rig, act):
    st.set_clip(rig, act, "idle", 1)
    gen = sm.solve(base, rig)
    return {"rot": gen[:3], "n": sm.solve(base, rig, gap=1.0, drop=0.0)[3], "d": sm.solve(base, rig, gap=0.0, drop=1.0)[3],
            "a": sm.solve(base, rig, gap=0.0, drop=0.0, along=1.0)[3], "arm_r": st.measure_arm_r(base)}


def air_of(Lv, plate, mount, joints, arm_r):
    pts = st.arm_points(joints["male"], mount)
    ptree = BVHTree.FromPolygons(Lv.tolist(), plate)
    return st.back_probe(ptree, pts, arm_r)[0]


def sub_frames(bodyf, clips, sexes=("male", "female")):
    return {k: {fk: v for fk, v in fs.items() if fk[0] in clips} for k, fs in bodyf.items() if k[1] in sexes}


def min_z(Lv, mount, arm, frames):
    """Lowest shield vertex per clip (ground is z = 0)."""
    out = {}
    for (anim, fr), bf in frames.items():
        z = float(st.place(Lv, mount, arm, bf[1])[:, 2].min())
        out[anim] = round(min(out.get(anim, 9.0), z), 3)
    return out


def hit_map(Lv, polys, mount, arm, frames):
    """Shield faces touching the common body, per clip: [(x, z) model space], owners."""
    out = {}
    cen = np.array([Lv[list(p)].mean(axis=0) for p in polys])
    for (anim, fr), bf in frames.items():
        tree = BVHTree.FromPolygons(st.place(Lv, mount, arm, bf[1]).tolist(), polys)
        for group, bt, outside, _far, _is_set, owner, _soft in bf[0]:
            if group != "corpo":
                continue
            seen = set()
            for i, j in tree.overlap(bt):
                if outside[j]:
                    d = out.setdefault(anim, {"faces": set(), "onde": {}})
                    d["faces"].add(i)
                    if (i, owner[j]) not in seen:
                        seen.add((i, owner[j]))
                        d["onde"][owner[j]] = d["onde"].get(owner[j], 0) + 1
    res = {}
    for anim, d in out.items():
        pts = cen[sorted(d["faces"])]
        res[anim] = {"n": len(pts), "x": [round(float(pts[:, 0].min()), 2), round(float(pts[:, 0].max()), 2)],
                     "z": [round(float(pts[:, 2].min()), 2), round(float(pts[:, 2].max()), 2)], "onde": d["onde"],
                     "pts": [[round(float(a), 3), round(float(b), 3)] for a, b in pts[:, [0, 2]]]}
    return res
