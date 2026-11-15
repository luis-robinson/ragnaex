"""Logo da tela de título (design/ux/start-flow.md, "Título").

Letras 3D (texto do Blender, chanfro reto) vistas de frente por uma câmera ortográfica, fundo transparente:
  assets/ui/logo_ragnaex.png        "RagnaEx" + emblema (espada e cajado cruzados atrás da estrela de 8 pontas de Aldara)
  assets/ui/logo_subtitle_ato2.png  "Ato II — A Horda" (PNG à parte: o jogo liga/desliga)
  production/qa/evidence/start-flow/logo_preview.png   os dois sobre a foto do cenário do menu

Fonte: "Bfont" embutida no Blender (derivada da Bitstream Vera/DejaVu, licença livre), engrossada com `offset`.
Cor: materiais só de emissão, em faixas (toon): a face muda por altura, o chanfro pela direção da normal.
Não depende de luz nem de motor de render e não toca na cena aberta (monta numa cena própria e a apaga no fim).

Sem janela:
  blender -b --factory-startup --python tools/blender/menu_logo.py
No Blender aberto:
  import menu_logo; menu_logo.run()
"""
import math
import os

import bpy
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI_DIR = os.path.join(ROOT, "assets", "ui")
EVID_DIR = os.path.join(ROOT, "production", "qa", "evidence", "start-flow")
BG_NAME = "menu_set_v4_CAM_title.png"
BG_DIRS = [EVID_DIR, os.path.join(ROOT, ".claude", "worktrees", "k-int", "production", "qa", "evidence", "start-flow")]

# ---- paleta (sRGB hex) -------------------------------------------------------------------------------------------
OUTLINE = "24142b"   # contorno: ameixa quase preta (a mesma família do céu do cenário)
DEPTH = "8a3d2a"     # "espessura" das letras, puxada para baixo
# face = 3 faixas de baixo para cima; bevel = [claro (de cima), meio, escuro (de baixo)]
PAL = {
	"gold": {"face": ["f0a23a", "f9c658", "ffe7a3"], "bevel": ["fff7da", "f3b64c", "c4702b"]},
	"cream": {"face": ["f6d9a0", "fdeecb", "fff8e6"], "bevel": ["ffffff", "f3d9a6", "c99a5e"]},
	"steel": {"face": ["b9c4dc", "dfe6f2", "f4f7fc"], "bevel": ["ffffff", "cfd8ea", "8f9cbd"]},
	"wood": {"face": ["94572f", "b06f3f", "c48a55"], "bevel": ["d9a56e", "a8683c", "70401f"]},
	"blue": {"face": ["3f4f92", "4d5fa8", "5d70b8"], "bevel": ["7f92d6", "4d5fa8", "303c74"]},
	"gem": {"face": ["5fc3d6", "8fe0ea", "d2f7f8"], "bevel": ["ffffff", "8fe0ea", "3f9cb4"]},
}
LIGHT = (-0.45, 0.89)   # de onde vem a "luz" do chanfro (cima-esquerda), no plano da imagem

# ---- o que desenhar ----------------------------------------------------------------------------------------------
TITLE = {"text": "RagnaEx", "size": 1.0, "bold": 0.034, "spacing": 1.06, "pal": "gold",
	"outline": 0.062, "drop": 0.085, "extrude": 0.05, "bevel": 0.03, "bands": (0.2, 0.47)}
SUB = {"left": "Ato II", "right": "A Horda", "size": 1.0, "bold": 0.018, "spacing": 1.08, "pal": "cream",
	"outline": 0.075, "drop": 0.06, "extrude": 0.04, "bevel": 0.022, "bands": (0.16, 0.5), "gap": 0.42}
EMBLEM = {"at": (-0.2, 0.9), "scale": 0.8, "cross": 55.0}

_made = []   # datablocks criados (apagados no fim)


def _keep(block):
	_made.append(block)
	return block


def _lin(hexcol):
	"""sRGB hex -> RGBA linear."""
	out = []
	for i in (0, 2, 4):
		c = int(hexcol[i:i + 2], 16) / 255.0
		out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
	return (out[0], out[1], out[2], 1.0)


def _ramp(nt, cols, stops):
	"""ColorRamp em degraus: cols[i] vale a partir de stops[i]."""
	n = nt.nodes.new("ShaderNodeValToRGB")
	r = n.color_ramp
	r.interpolation = 'CONSTANT'
	while len(r.elements) < len(cols):
		r.elements.new(1.0)
	for el, col, pos in zip(r.elements, cols, stops):
		el.position = pos
		el.color = _lin(col)
	return n


def flat_mat(name, hexcol):
	m = _keep(bpy.data.materials.new(name))
	try:
		m.use_nodes = True
	except Exception:
		pass
	nt = m.node_tree
	nt.nodes.clear()
	em = nt.nodes.new("ShaderNodeEmission")
	em.inputs["Color"].default_value = _lin(hexcol)
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	nt.links.new(em.outputs[0], out.inputs["Surface"])
	return m


def toon_mat(name, pal, y0, y1, bands=(0.33, 0.66)):
	"""Face (normal para a câmera): 3 faixas pela altura local y0..y1. Chanfro: 3 tons pela direção da normal."""
	m = _keep(bpy.data.materials.new(name))
	try:
		m.use_nodes = True
	except Exception:
		pass
	nt = m.node_tree
	nt.nodes.clear()
	L = nt.links
	# face
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	L.new(tc.outputs["Object"], sep.inputs[0])
	mr = nt.nodes.new("ShaderNodeMapRange")
	mr.inputs["From Min"].default_value = y0
	mr.inputs["From Max"].default_value = y1
	L.new(sep.outputs["Y"], mr.inputs["Value"])
	face = _ramp(nt, pal["face"], [0.0, bands[0], bands[1]])
	L.new(mr.outputs["Result"], face.inputs["Fac"])
	# chanfro
	geo = nt.nodes.new("ShaderNodeNewGeometry")
	dot = nt.nodes.new("ShaderNodeVectorMath")
	dot.operation = 'DOT_PRODUCT'
	dot.inputs[1].default_value = (LIGHT[0], LIGHT[1], 0.0)
	L.new(geo.outputs["Normal"], dot.inputs[0])
	mr2 = nt.nodes.new("ShaderNodeMapRange")
	mr2.inputs["From Min"].default_value = -0.72
	mr2.inputs["From Max"].default_value = 0.72
	L.new(dot.outputs["Value"], mr2.inputs["Value"])
	bev = _ramp(nt, [pal["bevel"][2], pal["bevel"][1], pal["bevel"][0]], [0.0, 0.36, 0.7])
	L.new(mr2.outputs["Result"], bev.inputs["Fac"])
	# escolhe: normal.z > 0.9 = face
	sepn = nt.nodes.new("ShaderNodeSeparateXYZ")
	L.new(geo.outputs["Normal"], sepn.inputs[0])
	gt = nt.nodes.new("ShaderNodeMath")
	gt.operation = 'GREATER_THAN'
	gt.inputs[1].default_value = 0.9
	L.new(sepn.outputs["Z"], gt.inputs[0])
	mix = nt.nodes.new("ShaderNodeMix")
	mix.data_type = 'RGBA'
	L.new(gt.outputs[0], mix.inputs[0])
	L.new(bev.outputs["Color"], mix.inputs[6])
	L.new(face.outputs["Color"], mix.inputs[7])
	em = nt.nodes.new("ShaderNodeEmission")
	L.new(mix.outputs[2], em.inputs["Color"])
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	L.new(em.outputs[0], out.inputs["Surface"])
	return m


# ---- curvas ------------------------------------------------------------------------------------------------------
def text_curve(name, body, size, spacing):
	cu = _keep(bpy.data.curves.new(name, 'FONT'))
	cu.body = body
	cu.size = size
	cu.space_character = spacing
	cu.align_x = 'LEFT'
	cu.resolution_u = 6
	return cu


def poly_curve(name, polys):
	"""Polígonos 2D preenchidos (anti-horário)."""
	cu = _keep(bpy.data.curves.new(name, 'CURVE'))
	cu.dimensions = '2D'
	cu.fill_mode = 'BOTH'
	for pts in polys:
		sp = cu.splines.new('POLY')
		sp.points.add(len(pts) - 1)
		for p, (x, y) in zip(sp.points, pts):
			p.co = (x, y, 0.0, 1.0)
		sp.use_cyclic_u = True
	return cu


def ngon(n, r, cx=0.0, cy=0.0, rot=0.0, r2=None):
	"""Polígono regular; com r2 alterna os raios (estrela)."""
	pts = []
	for i in range(n):
		a = rot + math.tau * i / n
		rr = r2 if (r2 is not None and i % 2) else r
		pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
	return pts


def rect(x0, y0, x1, y1):
	return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


class Board:
	"""Cena própria com as camadas (contorno atrás, espessura, face na frente)."""

	def __init__(self, name):
		self.scene = _keep(bpy.data.scenes.new(name))
		self.objs = []
		self.mats = {}
		self.z = 0.0

	def mat(self, key, maker):
		if key not in self.mats:
			self.mats[key] = maker()
		return self.mats[key]

	def _obj(self, name, data, loc, rot, z, mat):
		ob = _keep(bpy.data.objects.new(name, data))
		ob.location = (loc[0], loc[1], z)
		ob.rotation_euler = (0.0, 0.0, math.radians(rot))
		data.materials.clear()
		data.materials.append(mat)
		self.scene.collection.objects.link(ob)
		self.objs.append(ob)
		return ob

	def piece(self, name, cu, pal, loc=(0.0, 0.0), rot=0.0, outline=0.05, drop=0.05, extrude=0.03, bevel=0.02,
			yspan=(0.0, 1.0), bands=(0.33, 0.66), depth=False, steps=6, layer=0.0):
		"""Uma peça = contorno escuro arrastado para baixo (+ espessura colorida, se `depth`) + face com chanfro.
		`layer` empilha: peça com layer maior fica na frente."""
		base_off = cu.offset
		z = layer
		out_cu = _keep(cu.copy())
		out_cu.offset = base_off + outline
		om = self.mat("outline", lambda: flat_mat("logo_outline", OUTLINE))
		for i in range(steps + 1 if steps > 0 else 0):
			self._obj(name + "_out%d" % i, out_cu, (loc[0], loc[1] - drop * i / steps), rot, z, om)
		if depth:
			dep_cu = _keep(cu.copy())
			dm = self.mat("depth", lambda: flat_mat("logo_depth", DEPTH))
			for i in range(1, steps + 1):
				self._obj(name + "_dep%d" % i, dep_cu, (loc[0], loc[1] - drop * i / steps), rot, z + 0.1, dm)
		cu.extrude = extrude
		cu.bevel_depth = bevel
		cu.bevel_resolution = 0
		key = "%s_%.2f_%.2f_%.2f_%.2f" % (pal, yspan[0], yspan[1], bands[0], bands[1])
		fm = self.mat(key, lambda: toon_mat("logo_" + key, PAL[pal], yspan[0], yspan[1], bands))
		return self._obj(name, cu, loc, rot, z + 0.3, fm)

	def bake(self):
		"""Curvas -> malhas facetadas; devolve a caixa (x0, y0, x1, y1) do conjunto."""
		vl = self.scene.view_layers[0]
		vl.update()
		dg = vl.depsgraph
		lo = np.array([1e9, 1e9])
		hi = -lo
		baked = []
		for ob in self.objs:
			me = _keep(bpy.data.meshes.new_from_object(ob.evaluated_get(dg)))
			me.polygons.foreach_set("use_smooth", [False] * len(me.polygons))
			nb = _keep(bpy.data.objects.new(ob.name + "_m", me))
			nb.matrix_world = ob.matrix_world.copy()
			baked.append(nb)
			co = np.empty(len(me.vertices) * 3, dtype=np.float32)
			me.vertices.foreach_get("co", co)
			co = co.reshape(-1, 3)
			if len(co):
				w = (np.array(ob.matrix_world) @ np.c_[co, np.ones(len(co))].T).T[:, :2]
				lo = np.minimum(lo, w.min(axis=0))
				hi = np.maximum(hi, w.max(axis=0))
		for ob in self.objs:
			self.scene.collection.objects.unlink(ob)
		for nb in baked:
			self.scene.collection.objects.link(nb)
		self.objs = baked
		return (lo[0], lo[1], hi[0], hi[1])

	def render(self, path, res, margin=0.03):
		x0, y0, x1, y1 = self.bake()
		sc = self.scene
		cam_d = _keep(bpy.data.cameras.new(sc.name + "_cam"))
		cam_d.type = 'ORTHO'
		w, h = (x1 - x0), (y1 - y0)
		aspect = res[0] / res[1]
		cam_d.ortho_scale = max(w, h * aspect) * (1.0 + 2.0 * margin)
		cam_d.clip_start, cam_d.clip_end = 0.1, 100.0
		cam = _keep(bpy.data.objects.new(sc.name + "_cam", cam_d))
		cam.location = ((x0 + x1) * 0.5, (y0 + y1) * 0.5, 20.0)
		sc.collection.objects.link(cam)
		sc.camera = cam
		r = sc.render
		for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
			try:
				r.engine = eng
				break
			except TypeError:
				continue
		try:
			sc.eevee.taa_render_samples = 64
		except Exception:
			pass
		r.resolution_x, r.resolution_y = res
		r.resolution_percentage = 100
		r.film_transparent = True
		r.image_settings.file_format = 'PNG'
		r.image_settings.color_mode = 'RGBA'
		try:
			sc.view_settings.view_transform = 'Standard'
			sc.view_settings.look = 'None'
		except Exception:
			pass
		r.filepath = os.path.abspath(path)
		os.makedirs(os.path.dirname(r.filepath), exist_ok=True)
		bpy.ops.render.render(write_still=True, scene=sc.name)
		print("LOGO render", r.filepath, "caixa %.2f x %.2f" % (w, h))
		return (x0, y0, x1, y1)


def _text_width(board, cu):
	"""Largura do texto (malha avaliada)."""
	ob = bpy.data.objects.new("_w", cu)
	board.scene.collection.objects.link(ob)
	vl = board.scene.view_layers[0]
	vl.update()
	me = ob.evaluated_get(vl.depsgraph).to_mesh()
	xs = [v.co.x for v in me.vertices]
	ob.to_mesh_clear()
	board.scene.collection.objects.unlink(ob)
	bpy.data.objects.remove(ob)
	return (min(xs), max(xs)) if xs else (0.0, 0.0)


# ---- emblema: espada e cajado cruzados atrás da estrela de 8 pontas (a das flâmulas de Aldara) --------------------
def emblem(board, at, scale=1.0, cross=45.0, layer=0.0):
	s = scale
	P = lambda pts: [(x * s, y * s) for x, y in pts]
	# (nome, paleta, polígonos, giro, camada) — tudo com o centro no cruzamento
	sword = [
		("blade", "steel", [[(-0.07, -0.2), (0.07, -0.2), (0.07, 0.68), (0.0, 0.84), (-0.07, 0.68)]]),
		("grip", "wood", [rect(-0.036, -0.5, 0.036, -0.2)]),
		("guard", "gold", [rect(-0.2, -0.275, 0.2, -0.19)]),
		("pommel", "gold", [ngon(4, 0.075, 0.0, -0.54, math.pi / 2)]),
	]
	staff = [
		("pole", "wood", [rect(-0.038, -0.58, 0.038, 0.56)]),
		("collar", "gold", [[(-0.055, 0.5), (0.055, 0.5), (0.11, 0.61), (-0.11, 0.61)]]),
		("orb", "gem", [ngon(8, 0.13, 0.0, 0.72, math.pi / 8)]),
		("foot", "gold", [rect(-0.055, -0.63, 0.055, -0.55)]),
	]
	z = layer
	for group, rot, parts in (("staff", -cross, staff), ("sword", cross, sword)):
		for name, pal, polys in parts:
			cu = poly_curve("emb_%s_%s" % (group, name), [P(p) for p in polys])
			board.piece("emb_%s_%s" % (group, name), cu, pal, loc=at, rot=rot, outline=0.04 * s, drop=0.03 * s,
				extrude=0.03, bevel=0.016 * s, yspan=(-0.63 * s, 0.85 * s), bands=(0.45, 0.8), layer=z)
			z += 0.5
	medal = [
		("rim", "gold", ngon(16, 0.31, rot=math.pi / 16), (0.3, 0.6)),
		("disc", "blue", ngon(16, 0.25, rot=math.pi / 16), (0.35, 0.7)),
		("star", "gold", ngon(16, 0.2, rot=math.pi / 8, r2=0.2 * 0.765), (0.35, 0.65)),
	]
	for name, pal, poly, bands in medal:
		cu = poly_curve("emb_" + name, [P(poly)])
		board.piece("emb_" + name, cu, pal, loc=at, outline=(0.045 * s if name == "rim" else 0.0),
			drop=(0.04 * s if name == "rim" else 0.0), extrude=0.03, bevel=0.02 * s,
			yspan=(-0.33 * s, 0.33 * s), bands=bands, steps=(6 if name == "rim" else 0), layer=z)
		z += 0.5
	return z


def build_title(path, res=(1600, 600)):
	b = Board("LOGO_title")
	t = TITLE
	cu = text_curve("logo_word", t["text"], t["size"], t["spacing"])
	cu.offset = t["bold"]
	x0, x1 = _text_width(b, cu)
	top = emblem(b, (EMBLEM["at"][0], EMBLEM["at"][1]), EMBLEM["scale"], EMBLEM["cross"], layer=0.0)
	b.piece("logo_word", cu, t["pal"], loc=(-(x0 + x1) * 0.5, 0.0), outline=t["outline"], drop=t["drop"],
		extrude=t["extrude"], bevel=t["bevel"], yspan=(0.0, 0.73 * t["size"]), bands=t["bands"], depth=True, layer=top + 1.0)
	return b.render(path, res)


def build_subtitle(path, res=(900, 150)):
	"""Duas palavras e um travessão desenhado (não depende do glifo da fonte), com um losango de cada lado."""
	b = Board("LOGO_sub")
	t = SUB
	cap = 0.73 * t["size"]
	kw = dict(outline=t["outline"], drop=t["drop"], extrude=t["extrude"], bevel=t["bevel"],
		yspan=(0.0, cap), bands=t["bands"])
	x = 0.0
	ends = []
	for i, body in enumerate((t["left"], t["right"])):
		cu = text_curve("sub_%d" % i, body, t["size"], t["spacing"])
		cu.offset = t["bold"]
		x0, x1 = _text_width(b, cu)
		b.piece("sub_%d" % i, cu, t["pal"], loc=(x - x0, 0.0), **kw)
		ends.append((x, x + (x1 - x0)))
		x += (x1 - x0)
		if i == 0:
			dash = poly_curve("sub_dash", [rect(0.0, cap * 0.38, 0.5, cap * 0.38 + 0.1)])
			b.piece("sub_dash", dash, "gold", loc=(x + t["gap"], 0.0), **kw)
			x += 0.5 + 2.0 * t["gap"]
	for i, cx in enumerate((ends[0][0] - 0.55, ends[1][1] + 0.55)):
		gem = poly_curve("sub_gem%d" % i, [ngon(4, 0.2, 0.0, cap * 0.5, 0.0)])
		b.piece("sub_gem%d" % i, gem, "gold", loc=(cx, 0.0), **kw)
	return b.render(path, res)


# ---- prévia sobre a foto do cenário --------------------------------------------------------------------------------
def _load(path, size=None):
	"""PNG -> array (h, w, 4) com alfa pré-multiplicado, de cima para baixo; `size` = (w, h) reduz."""
	src = bpy.data.images.load(os.path.abspath(path), check_existing=False)
	w, h = src.size
	px = np.empty(w * h * 4, dtype=np.float32)
	src.pixels.foreach_get(px)
	bpy.data.images.remove(src)
	px = px.reshape(h, w, 4)
	px[..., :3] *= px[..., 3:4]
	if size and (size[0] != w or size[1] != h):
		tmp = bpy.data.images.new("_logo_tmp", w, h, alpha=True, float_buffer=True)
		tmp.pixels.foreach_set(px.ravel())
		tmp.scale(size[0], size[1])
		px = np.empty(size[0] * size[1] * 4, dtype=np.float32)
		tmp.pixels.foreach_get(px)
		bpy.data.images.remove(tmp)
		px = px.reshape(size[1], size[0], 4)
	return px[::-1].copy()


def preview(logo, sub, out, bg=None, logo_w=0.44, sub_w=0.2, top=0.035):
	"""Logo no terço de cima, centralizado, subtítulo logo abaixo. Larguras em fração da largura da tela."""
	if bg is None:
		bg = next((os.path.join(d, BG_NAME) for d in BG_DIRS if os.path.exists(os.path.join(d, BG_NAME))), None)
	if bg is None:
		print("LOGO prévia: sem a foto do cenário (%s)" % BG_NAME)
		return None
	base = _load(bg)
	H, W = base.shape[:2]
	y = int(H * top)
	for path, frac, lift in ((logo, logo_w, 0.0), (sub, sub_w, 0.02)):
		src = bpy.data.images.load(os.path.abspath(path), check_existing=False)
		sw, sh = src.size
		bpy.data.images.remove(src)
		w = int(W * frac)
		h = int(round(w * sh / sw))
		img = _load(path, (w, h))
		x = (W - w) // 2
		y -= int(h * lift)
		dst = base[y:y + h, x:x + w]
		dst[...] = img + dst * (1.0 - img[..., 3:4])
		y += h
	base[..., 3] = 1.0
	res = bpy.data.images.new("_logo_preview", W, H, alpha=True)
	res.pixels.foreach_set(np.clip(base[::-1], 0.0, 1.0).ravel())
	res.filepath_raw = os.path.abspath(out)
	res.file_format = 'PNG'
	os.makedirs(os.path.dirname(res.filepath_raw), exist_ok=True)
	res.save()
	bpy.data.images.remove(res)
	print("LOGO prévia", out)
	return out


def _cleanup():
	kinds = (("scenes", bpy.types.Scene), ("objects", bpy.types.Object), ("meshes", bpy.types.Mesh),
		("curves", bpy.types.Curve), ("cameras", bpy.types.Camera), ("materials", bpy.types.Material))
	for attr, typ in kinds:
		for blk in [m for m in _made if isinstance(m, typ)]:
			try:
				getattr(bpy.data, attr).remove(blk)
			except Exception:
				pass
	_made.clear()


def run(ui_dir=UI_DIR, evid_dir=EVID_DIR, bg=None):
	logo = os.path.join(ui_dir, "logo_ragnaex.png")
	sub = os.path.join(ui_dir, "logo_subtitle_ato2.png")
	try:
		build_title(logo)
		build_subtitle(sub)
	finally:
		_cleanup()
	return [logo, sub, preview(logo, sub, os.path.join(evid_dir, "logo_preview.png"), bg)]


if __name__ == "__main__":
	run()
