"""Biblioteca de helpers low-poly para o RagnaEx (Blender 3.x/4.x, bpy).

Uso (dentro do Blender, via MCP `execute_blender_code` ou headless):
    import sys; sys.path.append(r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender")
    import lowpoly_lib as lp
Estilo: Tree of Savior (chibi, cores pastel, flat shading). Tudo exporta em GLB com animações nomeadas
(idle/run/attack/cast/hit/die/block) que o Godot lê direto no AnimationPlayer.
"""
import bpy
import math
from mathutils import Vector, Euler

# ---------------------------------------------------------------------------
# cena
# ---------------------------------------------------------------------------
def clear_scene():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll, in ((bpy.data.meshes,), (bpy.data.armatures,), (bpy.data.actions,), (bpy.data.materials,)):
        for block in list(coll):
            if block.users == 0:
                try:
                    coll.remove(block)
                except Exception:
                    pass


def material(name, color, emission=0.0):
    """Material flat (Principled, roughness 1). color = (r,g,b) 0..1."""
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.0
        elif "Specular" in bsdf.inputs:
            bsdf.inputs["Specular"].default_value = 0.0
        if emission > 0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
            else:
                bsdf.inputs["Emission"].default_value = (*color, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emission
        m.diffuse_color = (*color, 1.0)
    return m


def _finish(obj, name, mat, flat=True):
    obj.name = name
    obj.data.name = name + "_mesh"
    if mat:
        obj.data.materials.append(mat)
    if flat:
        for p in obj.data.polygons:
            p.use_smooth = False
    return obj


def box(name, size, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = Vector(size)
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, name, mat)


def sphere(name, radius, loc, mat, segments=10, rings=6, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=segments, ring_count=rings, location=loc)
    o = bpy.context.active_object
    o.scale = Vector(scale)
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, name, mat)


def cylinder(name, r_top, r_bot, depth, loc, mat, verts=8, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r_bot, radius2=r_top, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    return _finish(o, name, mat)


def capsule(name, radius, height, loc, mat, segments=10):
    """Cápsula aproximada: cilindro + duas meias esferas unidas."""
    parts = []
    parts.append(cylinder(name + "_c", radius, radius, height, loc, mat, verts=segments))
    parts.append(sphere(name + "_t", radius, (loc[0], loc[1], loc[2] + height / 2), mat, segments=segments, rings=5))
    parts.append(sphere(name + "_b", radius, (loc[0], loc[1], loc[2] - height / 2), mat, segments=segments, rings=5))
    return join(parts, name)


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name + "_mesh"
    return o


# ---------------------------------------------------------------------------
# rig simples: cada parte do corpo é parenteada a um bone (sem skinning)
# ---------------------------------------------------------------------------
BONES = {
    # nome: (head, tail, parent)
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "body": ((0, 0, 0.35), (0, 0, 0.95), "root"),
    "head": ((0, 0, 0.95), (0, 0, 1.5), "body"),
    "arm_r": ((0.32, 0, 0.85), (0.32, 0, 0.45), "body"),
    "arm_l": ((-0.32, 0, 0.85), (-0.32, 0, 0.45), "body"),
    "leg_r": ((0.14, 0, 0.35), (0.14, 0, 0.0), "root"),
    "leg_l": ((-0.14, 0, 0.35), (-0.14, 0, 0.0), "root"),
}


def make_armature(name, bones=BONES):
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.active_object
    arm.name = name
    arm.data.name = name + "_arm"
    eb = arm.data.edit_bones
    for b in list(eb):
        eb.remove(b)
    created = {}
    for bname, (h, t, parent) in bones.items():
        b = eb.new(bname)
        b.head = Vector(h)
        b.tail = Vector(t)
        created[bname] = b
    for bname, (h, t, parent) in bones.items():
        if parent:
            created[bname].parent = created[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def attach(obj, arm, bone_name):
    """Parenteia o objeto ao bone (mantém transform)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    arm.data.bones.active = arm.data.bones[bone_name]
    bpy.ops.object.parent_set(type="BONE", keep_transform=True)


# ---------------------------------------------------------------------------
# animações: dicionário {bone: [(frame, rotation_euler_deg, location), ...]}
# ---------------------------------------------------------------------------
def add_action(arm, name, keys, frame_end, loop=True):
    """Cria uma Action com keyframes em pose bones e a empurra para uma NLA track
    (assim o glTF exporta todas as animações nomeadas)."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    action = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = action
    for bone, frames in keys.items():
        pb = arm.pose.bones[bone]
        for frame, rot, loc in frames:
            pb.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
            pb.location = Vector(loc)
            pb.keyframe_insert("rotation_euler", frame=frame)
            pb.keyframe_insert("location", frame=frame)
    if hasattr(action, "use_frame_range"):
        action.use_frame_range = True
    action.frame_range = (1, frame_end)
    # Blender 5 tirou Action.fcurves (actions em camadas); bezier já é o padrão e o loop é ligado no Godot
    for fc in getattr(action, "fcurves", []):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
        if loop:
            fc.modifiers.new("CYCLES")
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.name = name
    arm.animation_data.action = None
    bpy.ops.object.mode_set(mode="OBJECT")
    return action


def humanoid_actions(arm, weapon_hand="arm_r", caster=False):
    """Conjunto padrão de animações chibi: idle, run, attack, cast, hit, die, block."""
    z = (0, 0, 0)
    add_action(arm, "idle", {
        "body": [(1, (0, 0, 0), z), (24, (2, 0, 0), (0, 0, 0.02)), (48, (0, 0, 0), z)],
        "head": [(1, (0, 0, 0), z), (24, (-3, 0, 2), z), (48, (0, 0, 0), z)],
        "arm_r": [(1, (0, 0, 0), z), (24, (4, 0, -3), z), (48, (0, 0, 0), z)],
        "arm_l": [(1, (0, 0, 0), z), (24, (4, 0, 3), z), (48, (0, 0, 0), z)],
    }, 48)
    add_action(arm, "run", {
        "body": [(1, (12, 0, 0), z), (8, (12, 0, 0), (0, 0, 0.05)), (16, (12, 0, 0), z)],
        "leg_r": [(1, (40, 0, 0), z), (8, (-40, 0, 0), z), (16, (40, 0, 0), z)],
        "leg_l": [(1, (-40, 0, 0), z), (8, (40, 0, 0), z), (16, (-40, 0, 0), z)],
        "arm_r": [(1, (-35, 0, 0), z), (8, (35, 0, 0), z), (16, (-35, 0, 0), z)],
        "arm_l": [(1, (35, 0, 0), z), (8, (-35, 0, 0), z), (16, (35, 0, 0), z)],
        "head": [(1, (0, 0, 0), z), (8, (0, 0, 3), z), (16, (0, 0, 0), z)],
    }, 16)
    add_action(arm, "attack", {
        "body": [(1, (-10, 0, 20), z), (5, (25, 0, -25), (0, 0.12, 0)), (14, (0, 0, 0), z)],
        weapon_hand: [(1, (-120, 0, 0), z), (5, (30, 0, 0), z), (14, (0, 0, 0), z)],
        "head": [(1, (-5, 0, 0), z), (5, (10, 0, 0), z), (14, (0, 0, 0), z)],
    }, 14, loop=False)
    add_action(arm, "cast", {
        "body": [(1, (0, 0, 0), z), (8, (-8, 0, 0), (0, 0, 0.05)), (16, (0, 0, 0), z)],
        "arm_r": [(1, (0, 0, 0), z), (8, (-150, 0, -20), z), (16, (-90, 0, 0), z)],
        "arm_l": [(1, (0, 0, 0), z), (8, (-150, 0, 20), z), (16, (-90, 0, 0), z)],
    }, 16, loop=False)
    add_action(arm, "hit", {
        "body": [(1, (-20, 0, 0), (0, -0.08, 0)), (8, (0, 0, 0), z)],
        "head": [(1, (-25, 0, 0), z), (8, (0, 0, 0), z)],
    }, 8, loop=False)
    add_action(arm, "die", {
        "root": [(1, (0, 0, 0), z), (12, (-90, 0, 0), (0, -0.3, 0.1)), (20, (-90, 0, 0), (0, -0.3, 0.05))],
        "arm_r": [(1, (0, 0, 0), z), (12, (-60, 0, -40), z)],
        "arm_l": [(1, (0, 0, 0), z), (12, (-60, 0, 40), z)],
    }, 20, loop=False)
    add_action(arm, "block", {
        "body": [(1, (8, 0, 0), z), (24, (10, 0, 0), z), (48, (8, 0, 0), z)],
        "arm_l": [(1, (-90, 0, 30), z), (48, (-90, 0, 30), z)],
    }, 48)


# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------
def export_glb(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
        for c in o.children_recursive:
            c.select_set(True)
    kwargs = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                  export_animations=True, export_nla_strips=True, export_yup=True, export_materials="EXPORT")
    try:
        bpy.ops.export_scene.gltf(export_animation_mode="NLA_TRACKS", **kwargs)   # Blender 3.6+ / 4.x
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)
    print("exported", path)
