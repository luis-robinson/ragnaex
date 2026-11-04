class_name LooksCatalog
extends RefCounted
## Aparência da criação de personagem: sexo, cabelo, barba e olhos (estilo + cor).
## Os estilos são malhas dentro de cada kit (tools/blender/looks.py: base_hair_<id>, base_beard_<id>, base_eyes_<id>).
## Look = {"sex", "skin", "hair", "hair_color", "beard", "beard_color", "eyes", "eye_color", "brows", "mouth", "marks", "mark_color"};
## cores em hex ("rrggbb"). Rosto: base_brows_<id>, base_mouth_<id>, base_marks_<id>; pele = material m_skin.

const SEXES := {"male": "Masculino", "female": "Feminino"}
const HAIR := {"short": "Curto", "long": "Comprido", "spiky": "Espetado", "ponytail": "Rabo de cavalo", "bob": "Chanel", "buzz": "Raspado",
	"twintails": "Maria-chiquinha", "braid": "Trança", "mohawk": "Moicano", "topknot": "Coque", "messy": "Bagunçado", "curly": "Cacheado"}
const BROWS := {"none": "Discretas", "thin": "Finas", "thick": "Grossas", "angry": "Bravas", "worried": "Preocupadas"}
const MOUTHS := {"none": "Sem boca", "smile": "Sorriso", "neutral": "Séria", "open": "Aberta", "fang": "Caninos"}
const MARKS := {"none": "Nenhuma", "scar": "Cicatriz", "freckles": "Sardas", "warpaint": "Pintura de guerra", "blush": "Rubor", "tattoo": "Tatuagem"}
const SKIN_COLORS := ["fae0cc", "f5d6b8", "e8c09a", "d4a07a", "b07a52", "8a5a3a", "5e3c28", "c8d8b0", "b8c8e8"]
const MARK_COLORS := ["3a66d8", "c03030", "2e8a4a", "e0a020", "8a3ab0", "1c1a20", "f0f0f0"]
const BEARDS := {"none": "Sem barba", "stubble": "Por fazer", "mustache": "Bigode", "goatee": "Cavanhaque", "full": "Cheia"}
const EYES := {"round": "Redondos", "big": "Grandes", "narrow": "Sonolentos", "sharp": "Afiados"}
const HAIR_COLORS := ["1c1a20", "3b2a20", "6b4429", "a0663a", "d8a35a", "f0dc9a", "e8e4dc", "9a9aa6", "b8322e", "e0703a", "3a5aa8", "5c3a8a", "2e7a5a", "e48ab0"]
const EYE_COLORS := ["201828", "4a2e1e", "7a5230", "2e6a3a", "3a6ab0", "6ab0e0", "8a3ab0", "c03030", "d8a020", "9aa0a8"]

## Visual padrão de uma classe (save antigo, NPC): cabelo pela cor da classe.
static func default_look(cls: ClassDef, sex: String = "") -> Dictionary:
	var s := sex if sex != "" else (cls.body_type if cls else "male")
	var hc := cls.hair_color.to_html(false) if cls else "3b2a20"
	return {"sex": s, "skin": SKIN_COLORS[0], "hair": "long" if s == "female" else "short", "hair_color": hc, "beard": "none", "beard_color": hc,
		"eyes": "round", "eye_color": "201828", "brows": "none", "mouth": "none", "marks": "none", "mark_color": MARK_COLORS[0]}

## Visual aleatório (bots): sorteia tudo, barba só no masculino.
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var s: String = SEXES.keys()[rng.randi() % SEXES.size()]
	var hc: String = HAIR_COLORS[rng.randi() % HAIR_COLORS.size()]
	var beard := "none"
	if s == "male" and rng.randf() < 0.5:
		beard = BEARDS.keys()[1 + rng.randi() % (BEARDS.size() - 1)]
	return {"sex": s, "skin": SKIN_COLORS[rng.randi() % 7], "hair": HAIR.keys()[rng.randi() % HAIR.size()], "hair_color": hc, "beard": beard, "beard_color": hc,
		"eyes": EYES.keys()[rng.randi() % EYES.size()], "eye_color": EYE_COLORS[rng.randi() % EYE_COLORS.size()],
		"brows": BROWS.keys()[rng.randi() % BROWS.size()], "mouth": MOUTHS.keys()[rng.randi() % MOUTHS.size()],
		"marks": MARKS.keys()[rng.randi() % MARKS.size()] if rng.randf() < 0.35 else "none", "mark_color": MARK_COLORS[rng.randi() % MARK_COLORS.size()]}

## Completa um look parcial (save antigo ou campo faltando) com o padrão da classe.
static func normalized(look: Dictionary, cls: ClassDef) -> Dictionary:
	var base := default_look(cls, str(look.get("sex", "")))
	for k in base:
		if look.has(k):
			base[k] = look[k]
	if not SEXES.has(base["sex"]):
		base["sex"] = cls.body_type if cls else "male"
	if not HAIR.has(base["hair"]):
		base["hair"] = "short"
	if not BEARDS.has(base["beard"]):
		base["beard"] = "none"
	if not EYES.has(base["eyes"]):
		base["eyes"] = "round"
	for k in [["brows", BROWS], ["mouth", MOUTHS], ["marks", MARKS]]:
		if not k[1].has(base[k[0]]):
			base[k[0]] = "none"
	return base
