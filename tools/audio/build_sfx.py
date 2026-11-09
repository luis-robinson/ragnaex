"""Monta o banco de efeitos sonoros do RagnaEx em assets/audio/sfx/.

Misto (decisão de 2026-11-09):
- CC0 (OpenGameArt, domínio público): golpes, impactos, bloqueio, monstros, itens, poção, interface.
- Sintetizado aqui (só biblioteca padrão, semente fixa = sempre o mesmo som): magias por tema,
  preparação de magia, esquiva, crítico, nível, quest, volta à cidade, arco/tiro, abrir/fechar janela.

Nome no banco: <evento>_<n>.<ogg|wav> — game/audio/sfx.gd acha as variações pelo prefixo.
WAVs saem mono 16 bits (os dos pacotes vinham estéreo 24 bits); OGGs são copiados como vieram.

Uso: python tools/audio/build_sfx.py [--cache <pasta dos pacotes>]
Depois: godot --headless --path . --import
"""
import io, math, os, random, shutil, struct, sys, urllib.request, wave, zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
SR = 44100

# Pacotes CC0 (página → arquivo). Todos com licença CC0 conferida na página em 2026-11-09.
PACKS = {
	"oga80": ("https://opengameart.org/content/80-cc0-rpg-sfx", "https://opengameart.org/sites/default/files/80-CC0-RPG-SFX_0.zip", "80 CC0 RPG SFX (rubberduck)"),
	"kenney": ("https://opengameart.org/content/50-rpg-sound-effects", "https://opengameart.org/sites/default/files/RPGsounds_Kenney.zip", "50 RPG sound effects (Kenney)"),
	"rpgpack": ("https://opengameart.org/content/rpg-sound-pack", "https://opengameart.org/sites/default/files/rpg_sound_pack.zip", "RPG Sound Pack (artisticdude)"),
	"ui": ("https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks", "https://opengameart.org/sites/default/files/UI_SFX_Set.zip", "51 UI sound effects (Kenney)"),
}

# evento -> [(pacote, caminho dentro do zip)]
CC0 = {
	"swing": [("rpgpack", "RPG Sound Pack/battle/swing.wav"), ("rpgpack", "RPG Sound Pack/battle/swing2.wav"), ("rpgpack", "RPG Sound Pack/battle/swing3.wav")],
	"hit": [("oga80", "blade_01.ogg"), ("oga80", "blade_02.ogg"), ("oga80", "blade_03.ogg"), ("kenney", "OGG/chop.ogg")],
	"block": [("oga80", "metal_01.ogg"), ("oga80", "metal_02.ogg"), ("oga80", "metal_03.ogg")],
	"parry": [("rpgpack", "RPG Sound Pack/inventory/metal-ringing.wav")],
	"fire": [("oga80", "spell_fire_01.ogg"), ("oga80", "spell_fire_02.ogg"), ("oga80", "spell_fire_06.ogg"), ("oga80", "spell_fire_07.ogg")],
	"arcane": [("oga80", "spell_01.ogg"), ("oga80", "spell_02.ogg"), ("rpgpack", "RPG Sound Pack/battle/magic1.wav")],
	"die_monster": [("oga80", "creature_die_01.ogg")] + [("rpgpack", "RPG Sound Pack/NPC/gutteral beast/mnstr%d.wav" % i) for i in (2, 3, 4, 8, 12)],
	"die_boss": [("rpgpack", "RPG Sound Pack/NPC/giant/giant%d.wav" % i) for i in (1, 2, 3, 5)],
	"pickup": [("oga80", "item_misc_0%d.ogg" % i) for i in (1, 2, 3, 4, 5)],
	"coins": [("oga80", "item_coins_01.ogg"), ("oga80", "item_coins_03.ogg"), ("kenney", "OGG/handleCoins2.ogg")],
	"gem": [("oga80", "item_gem_0%d.ogg" % i) for i in (1, 2, 3, 4)],
	"potion": [("rpgpack", "RPG Sound Pack/inventory/bottle.wav"), ("rpgpack", "RPG Sound Pack/inventory/bubble.wav"), ("rpgpack", "RPG Sound Pack/inventory/bubble2.wav")],
	"equip": [("rpgpack", "RPG Sound Pack/inventory/armor-light.wav"), ("rpgpack", "RPG Sound Pack/inventory/chainmail1.wav"), ("rpgpack", "RPG Sound Pack/inventory/cloth-heavy.wav")],
	"craft": [("kenney", "OGG/metalPot2.ogg"), ("kenney", "OGG/metalPot3.ogg")],
	"gather": [("oga80", "item_wood_02.ogg"), ("oga80", "item_stone_02.ogg"), ("oga80", "item_stone_04.ogg")],
	"door": [("kenney", "OGG/doorOpen_1.ogg")],
	"click": [("ui", "click1.wav"), ("ui", "click3.wav"), ("ui", "mouseclick1.wav")],
	"page": [("kenney", "OGG/bookFlip2.ogg"), ("kenney", "OGG/bookFlip3.ogg")],
}


# ---------------------------------------------------------------- pacotes
def fetch(cache):
	os.makedirs(cache, exist_ok=True)
	zips = {}
	for key, (_page, url, _name) in PACKS.items():
		p = os.path.join(cache, key + ".zip")
		if not os.path.exists(p):
			print("baixando", url)
			with urllib.request.urlopen(url) as r, open(p, "wb") as f:
				shutil.copyfileobj(r, f)
		zips[key] = zipfile.ZipFile(p)
	return zips


def zip_member(z, inner):
	for n in z.namelist():
		if n.endswith(inner) and "__MACOSX" not in n:
			return n
	raise KeyError(inner)


def wav_to_mono16(data):
	"""WAV PCM 16/24 bits, 1-2 canais -> amostras float mono (taxa original)."""
	w = wave.open(io.BytesIO(data))
	ch, sw, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
	raw = w.readframes(n)
	out = []
	step = ch * sw
	for i in range(0, len(raw) - step + 1, step):
		acc = 0.0
		for c in range(ch):
			b = raw[i + c * sw:i + (c + 1) * sw]
			if sw == 2:
				v = struct.unpack("<h", b)[0] / 32768.0
			elif sw == 3:
				v = int.from_bytes(b, "little", signed=True) / 8388608.0
			else:
				v = (b[0] - 128) / 128.0
			acc += v
		out.append(acc / ch)
	return out, rate


# ---------------------------------------------------------------- síntese
def write_wav(path, s, rate=SR, peak=0.85):
	m = max(1e-9, max(abs(x) for x in s))
	g = peak / m
	fade = min(len(s), int(rate * 0.004))      # sem estalo no fim
	with wave.open(path, "wb") as w:
		w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
		buf = bytearray()
		for i, x in enumerate(s):
			if i >= len(s) - fade:
				x *= (len(s) - i) / fade
			buf += struct.pack("<h", int(max(-1.0, min(1.0, x * g)) * 32767))
		w.writeframes(bytes(buf))


def n_of(dur):
	return int(SR * dur)


def zeros(dur):
	return [0.0] * n_of(dur)


def add(dst, src, at=0.0, gain=1.0):
	o = n_of(at)
	for i, x in enumerate(src):
		if o + i < len(dst):
			dst[o + i] += x * gain
	return dst


def tone(dur, f0, f1=None, kind="sine", decay=6.0, attack=0.004, harm=None):
	"""Tom com glissando exponencial f0->f1 e envelope de ataque + queda exponencial."""
	f1 = f0 if f1 is None else f1
	n = n_of(dur)
	out, ph = [], 0.0
	for i in range(n):
		t = i / SR
		f = f0 * (f1 / f0) ** (i / max(1, n - 1))
		ph += 2 * math.pi * f / SR
		if kind == "sine":
			v = math.sin(ph)
		elif kind == "tri":
			v = 2 / math.pi * math.asin(math.sin(ph))
		else:                                    # "saw" suave (5 harmônicos)
			v = sum(math.sin(ph * k) / k for k in range(1, 6)) * 0.6
		if harm:
			v += sum(a * math.sin(ph * k) for k, a in harm)
		env = min(1.0, t / attack) * math.exp(-decay * t)
		out.append(v * env)
	return out


def noise(dur, rng, decay=8.0, attack=0.002):
	return [rng.uniform(-1, 1) * min(1.0, (i / SR) / attack) * math.exp(-decay * i / SR) for i in range(n_of(dur))]


def lowpass(s, cut0, cut1=None):
	cut1 = cut0 if cut1 is None else cut1
	out, y, n = [], 0.0, len(s)
	for i, x in enumerate(s):
		c = cut0 * (cut1 / cut0) ** (i / max(1, n - 1))
		a = 1 - math.exp(-2 * math.pi * c / SR)
		y += a * (x - y)
		out.append(y)
	return out


def highpass(s, cut):
	lp = lowpass(s, cut)
	return [x - y for x, y in zip(s, lp)]


def bandpass(s, lo, hi):
	return highpass(lowpass(s, hi), lo)


def swell(s, peak_at=0.4):
	n = len(s)
	return [x * (math.sin(math.pi * min(1.0, (i / n) / peak_at) / 2) if i / n < peak_at else math.cos(math.pi / 2 * ((i / n) - peak_at) / (1 - peak_at))) for i, x in enumerate(s)]


def pluck(dur, f, rng, damp=0.996):
	"""Karplus-Strong: corda de arco."""
	p = max(2, int(SR / f))
	buf = [rng.uniform(-1, 1) for _ in range(p)]
	out = []
	for i in range(n_of(dur)):
		a = buf[i % p]
		b = buf[(i + 1) % p]
		buf[i % p] = damp * 0.5 * (a + b)
		out.append(a)
	return out


def bell(dur, f, decay=3.5):
	return tone(dur, f, decay=decay, attack=0.003, harm=[(2.0, 0.35), (2.76, 0.22), (5.4, 0.08)])


NOTE = lambda semis: 523.25 * 2 ** (semis / 12.0)     # 0 = C5


def s_ice(rng):
	out = zeros(0.7)
	add(out, highpass(noise(0.12, rng, decay=30), 3000), 0, 0.5)
	for _ in range(7):
		add(out, tone(0.5, rng.uniform(2200, 5200), decay=rng.uniform(7, 12)), rng.uniform(0, 0.18), rng.uniform(0.25, 0.5))
	return out


def s_lightning(rng):
	out = zeros(0.55)
	nz = noise(0.5, rng, decay=5)
	gate, on, k = [], True, 0
	while len(gate) < len(nz):
		ln = n_of(rng.uniform(0.004, 0.02))
		gate += [1.0 if on else 0.08] * ln
		on = not on if rng.random() < 0.8 else on
	add(out, highpass([a * b for a, b in zip(nz, gate)], 900), 0, 1.0)
	add(out, tone(0.3, 90, 45, decay=10), 0, 0.8)
	return out


def s_holy(rng):
	root = rng.choice([0, 2, 5])
	out = zeros(1.1)
	for k, st in enumerate([0, 4, 7, 12]):
		add(out, bell(1.0, NOTE(root + st), decay=3.0), k * 0.03, 0.35)
	add(out, [x * (0.5 + 0.5 * math.sin(i / SR * 2 * math.pi * 11)) for i, x in enumerate(tone(1.0, NOTE(root + 24), decay=4))], 0.05, 0.12)
	return out


def s_shadow(rng):
	out = zeros(0.8)
	a = rng.uniform(200, 260)
	add(out, lowpass(tone(0.8, a, a * 0.35, kind="saw", decay=3.5, attack=0.03), 900), 0, 0.6)
	add(out, lowpass(tone(0.8, a * 1.02, a * 0.36, kind="saw", decay=3.5, attack=0.03), 900), 0, 0.6)
	add(out, swell(lowpass(noise(0.7, rng, decay=1.5), 1200, 300), 0.3), 0, 0.5)
	return out


def s_poison(rng):
	out = zeros(0.65)
	add(out, lowpass(noise(0.6, rng, decay=5), 2500), 0, 0.15)
	for _ in range(9):
		f = rng.uniform(280, 900)
		add(out, tone(0.06, f, f * 1.8, decay=40), rng.uniform(0, 0.5), rng.uniform(0.4, 0.8))
	return out


def s_nature(rng):
	out = zeros(0.6)
	add(out, tone(0.25, 180, 150, decay=22, harm=[(2.3, 0.4)]), 0, 0.8)
	r = bandpass(noise(0.55, rng, decay=4, attack=0.03), 1500, 6000)
	add(out, [x * (0.6 + 0.4 * math.sin(i / SR * 2 * math.pi * rng.uniform(14, 22))) for i, x in enumerate(r)], 0.02, 0.6)
	return out


def s_wind(rng, dur=0.6):
	nz = noise(dur, rng, decay=0.5)
	return swell(bandpass(lowpass(nz, 400, 3000), 250, 8000), 0.45)


def s_dodge(rng):
	nz = noise(0.24, rng, decay=1.0)
	return swell(lowpass(nz, 600, 5000), 0.35)


def s_earth(rng):
	out = zeros(0.8)
	add(out, tone(0.7, 70, 32, decay=5), 0, 1.0)
	add(out, lowpass(noise(0.7, rng, decay=5), 500), 0, 0.9)
	for _ in range(6):
		add(out, highpass(noise(0.02, rng, decay=120), 1500), rng.uniform(0.02, 0.35), rng.uniform(0.2, 0.4))
	return out


def s_blood(rng):
	out = zeros(0.45)
	add(out, tone(0.35, 130, 50, decay=12), 0, 0.9)
	add(out, lowpass(noise(0.3, rng, decay=14), 1800), 0.005, 0.8)
	return out


def s_lunar(rng):
	out = zeros(1.0)
	f = rng.choice([NOTE(7), NOTE(9), NOTE(12)])
	b = bell(0.95, f * 2, decay=3)
	add(out, [x * (0.7 + 0.3 * math.sin(i / SR * 2 * math.pi * 6)) for i, x in enumerate(b)], 0, 0.5)
	add(out, bell(0.9, f * 3, decay=4), 0.06, 0.25)
	return out


def s_summon(rng):
	out = zeros(1.0)
	add(out, lowpass(tone(0.95, 120, 520, kind="saw", decay=1.6, attack=0.15), 1600), 0, 0.6)
	add(out, swell(bandpass(noise(0.95, rng, decay=0.5), 300, 2500), 0.7), 0, 0.4)
	add(out, bell(0.4, NOTE(7), decay=7), 0.6, 0.3)
	return out


def s_heal(rng):
	out = zeros(1.0)
	base = rng.choice([0, 2])
	for k, st in enumerate([0, 4, 7, 12, 16]):
		add(out, tone(0.6, NOTE(base + st), decay=5, attack=0.02, harm=[(2, 0.15)]), k * 0.07, 0.35)
	add(out, highpass(noise(0.5, rng, decay=6), 5000), 0.1, 0.08)
	return out


def s_bone(rng):
	out = zeros(0.45)
	add(out, tone(0.15, 320, 260, decay=28, harm=[(2.7, 0.3)]), 0, 0.6)
	for _ in range(12):
		add(out, bandpass(noise(0.012, rng, decay=300), 1500, 6000), rng.uniform(0, 0.3), rng.uniform(0.3, 0.7))
	return out


def s_cast(rng):
	out = zeros(0.5)
	f = rng.uniform(260, 340)
	add(out, tone(0.5, f, f * 2.6, kind="tri", decay=1.0, attack=0.12), 0, 0.35)
	add(out, swell(bandpass(noise(0.5, rng, decay=0.3), 800, 5000), 0.85), 0, 0.3)
	return out


def s_crit(rng):
	out = zeros(0.35)
	add(out, tone(0.3, 110, 40, decay=14), 0, 1.0)
	add(out, highpass(noise(0.03, rng, decay=90), 2000), 0, 0.6)
	return out


def s_hurt(rng):
	out = zeros(0.25)
	add(out, tone(0.22, 160, 70, decay=16), 0, 0.9)
	add(out, bandpass(noise(0.12, rng, decay=30), 300, 2000), 0, 0.5)
	return out


def s_bow(rng):
	out = zeros(0.4)
	add(out, lowpass(pluck(0.4, rng.uniform(95, 120), rng, damp=0.993), 2500), 0, 0.9)
	add(out, s_dodge(rng)[:n_of(0.2)], 0.01, 0.35)
	return out


def s_gun(rng):
	out = zeros(0.6)
	add(out, noise(0.25, rng, decay=22), 0, 1.0)
	add(out, tone(0.4, 120, 45, decay=9), 0, 0.9)
	add(out, lowpass(noise(0.6, rng, decay=4), 600), 0.03, 0.4)     # eco
	return out


def s_level_up(rng):
	out = zeros(1.6)
	for k, st in enumerate([0, 4, 7, 12]):
		add(out, bell(0.5, NOTE(st), decay=6), k * 0.11, 0.45)
	for st in [0, 4, 7, 12, 16]:
		add(out, bell(1.1, NOTE(st), decay=2.5), 0.46, 0.22)
	add(out, highpass(noise(0.8, rng, decay=4), 6000), 0.46, 0.06)
	return out


def s_quest_accept(rng):
	out = zeros(0.5)
	add(out, bell(0.3, NOTE(7), decay=9), 0, 0.5)
	add(out, bell(0.4, NOTE(12), decay=7), 0.1, 0.5)
	return out


def s_quest_done(rng):
	out = zeros(1.2)
	for k, st in enumerate([0, 4, 7]):
		add(out, bell(0.3, NOTE(st), decay=8), k * 0.1, 0.45)
	for st in [0, 7, 12, 16]:
		add(out, bell(0.9, NOTE(st), decay=3), 0.32, 0.25)
	return out


def s_recall(rng):
	out = zeros(1.2)
	add(out, swell(bandpass(noise(1.2, rng, decay=0.2), 1500, 7000), 0.9), 0, 0.35)
	for k in range(8):
		add(out, bell(0.4, NOTE(k * 2), decay=8), k * 0.12, 0.18)
	return out


def s_recall_done(rng):
	out = zeros(0.9)
	add(out, s_wind(rng, 0.5), 0, 0.6)
	add(out, bell(0.8, NOTE(12), decay=4), 0.15, 0.4)
	return out


def s_death(rng):
	out = zeros(1.6)
	for k, st in enumerate([7, 3, 0, -5]):
		add(out, tone(0.6, NOTE(st - 12), decay=3.5, attack=0.02, kind="tri"), k * 0.28, 0.4)
	return out


def s_ui_open(rng):
	return tone(0.09, 520, 820, decay=30, attack=0.002)


def s_ui_close(rng):
	return tone(0.09, 820, 520, decay=30, attack=0.002)


SYNTH = {
	"ice": (s_ice, 3), "lightning": (s_lightning, 3), "holy": (s_holy, 3), "shadow": (s_shadow, 2),
	"poison": (s_poison, 3), "nature": (s_nature, 2), "wind": (s_wind, 2), "earth": (s_earth, 2),
	"blood": (s_blood, 3), "lunar": (s_lunar, 2), "summon": (s_summon, 2), "heal": (s_heal, 2),
	"bone": (s_bone, 3), "cast": (s_cast, 3), "dodge": (s_dodge, 3), "crit": (s_crit, 3),
	"hurt": (s_hurt, 2), "bow": (s_bow, 3), "gun": (s_gun, 2), "level_up": (s_level_up, 1),
	"quest_accept": (s_quest_accept, 1), "quest_done": (s_quest_done, 1), "recall": (s_recall, 1),
	"recall_done": (s_recall_done, 1), "death": (s_death, 1), "ui_open": (s_ui_open, 1), "ui_close": (s_ui_close, 1),
}


def main():
	cache = os.path.join(ROOT, ".godot", "sfx_cache")      # .godot/ é ignorado pelo git e pelo export
	if "--cache" in sys.argv:
		cache = sys.argv[sys.argv.index("--cache") + 1]
	os.makedirs(OUT, exist_ok=True)
	for f in os.listdir(OUT):                               # o banco é todo gerado aqui
		if f.endswith((".wav", ".ogg")):
			os.remove(os.path.join(OUT, f))
	zips = fetch(cache)
	count = 0
	for ev, srcs in CC0.items():
		for i, (pk, inner) in enumerate(srcs, 1):
			data = zips[pk].read(zip_member(zips[pk], inner))
			if inner.endswith(".ogg"):
				open(os.path.join(OUT, "%s_%d.ogg" % (ev, i)), "wb").write(data)
			else:
				s, rate = wav_to_mono16(data)
				write_wav(os.path.join(OUT, "%s_%d.wav" % (ev, i)), s, rate, peak=0.9)
			count += 1
	for ev, (fn, n) in SYNTH.items():
		for i in range(1, n + 1):
			rng = random.Random("%s:%d" % (ev, i))
			write_wav(os.path.join(OUT, "%s_%d.wav" % (ev, i)), fn(rng))
			count += 1
	with open(os.path.join(ROOT, "assets", "audio", "CREDITS.md"), "w", encoding="utf-8") as f:
		f.write("# Créditos de áudio\n\nGerado por `tools/audio/build_sfx.py`. Sons sintetizados pelo script são do projeto.\n\n")
		f.write("Pacotes de domínio público (CC0 1.0, sem atribuição obrigatória; creditados por cortesia):\n\n")
		for key, (page, _url, name) in PACKS.items():
			used = sorted({ev for ev, srcs in CC0.items() for pk, _ in srcs if pk == key})
			f.write("- %s — %s — usado em: %s\n" % (name, page, ", ".join(used)))
	print("banco:", count, "arquivos em", OUT)


if __name__ == "__main__":
	main()
