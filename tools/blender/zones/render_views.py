"""Loop de layout sem janela: depois do build, fotografa CAM_top / CAM_game / CAM_poi (Workbench, cor do material).

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- <zona> <pasta_png> [--export]
"""
import bpy


def _vcol_to_materials():
    """Só para a foto: os lotes do dress.py levam a cor no vértice (um material branco `det_vcol`), e o Workbench pinta por
    material. Troca, na cena já exportada, a cor de cada face por um material da mesma cor (sRGB -> linear)."""
    lin = lambda v: v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    cache = {}
    for o in bpy.context.scene.objects:
        me = o.data if o.type == "MESH" else None
        if me is None or not me.materials or me.materials[0] is None or not me.materials[0].name.startswith("det_vcol"):
            continue
        att = me.color_attributes.get("Col")
        if att is None:
            continue
        me.materials.clear()
        slots = {}
        for poly in me.polygons:
            c = att.data[poly.loop_start].color
            key = (round(c[0], 3), round(c[1], 3), round(c[2], 3))
            if key not in slots:
                if key not in cache:
                    m = bpy.data.materials.new("pv_det_%d" % len(cache))
                    m.diffuse_color = (lin(key[0]), lin(key[1]), lin(key[2]), 1.0)
                    cache[key] = m
                slots[key] = len(me.materials)
                me.materials.append(cache[key])
            poly.material_index = slots[key]


def render(out_dir, tag, cams=("CAM_top", "CAM_game", "CAM_poi"), size=900):
    sc = bpy.context.scene
    _vcol_to_materials()
    try:
        sc.render.engine = "BLENDER_WORKBENCH"
    except TypeError as e:
        print("engine:", e)
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.show_cavity = False
    try:
        sc.view_settings.view_transform = "Standard"      # cor do material como no jogo (AgX/Filmic lavam e escurecem)
    except TypeError as e:
        print("view:", e)
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.image_settings.file_format = "PNG"
    for name in cams:
        cam = bpy.data.objects.get(name)
        if cam is None:
            continue
        if name == "CAM_top":
            cam.data.clip_end = 1000.0
        sc.camera = cam
        sc.render.filepath = "%s/%s_%s.png" % (out_dir, tag, name)
        bpy.ops.render.render(write_still=True)
        print("render:", sc.render.filepath)
