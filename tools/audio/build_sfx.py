"""Monta o banco de efeitos sonoros do RagnaEx em assets/audio/sfx/.

Misto (decisão de 2026-11-09):
- CC0 (OpenGameArt, domínio público): golpes, impactos, bloqueio, monstros, itens, poção, interface.
- Sintetizado aqui (só biblioteca padrão, semente fixa = sempre o mesmo som): magias por tema,
  preparação de magia, esquiva, crítico, nível, quest, volta à cidade, arco/tiro, abrir/fechar janela.

Nome no banco: <evento>_<n>.<ogg|wav> — game/audio/sfx.gd acha as variações pelo prefixo.
WAVs saem mono 16 bits (os dos pacotes vinham estéreo 24 bits); OGGs são copiados como vieram.

Uso: python tools/audio/build_sfx.py [--cache <pasta dos pacotes>] [--only=<nome>,<nome>]
(--only refaz só esses nomes e não mexe no resto do banco nem no CREDITS.md)
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
	# Ato II (A Horda): vozes gravadas dos mesmos pacotes
	"orc": [("rpgpack", "RPG Sound Pack/NPC/ogre/ogre%d.wav" % i) for i in (1, 2, 5)],
	"wolf_snarl": [("rpgpack", "RPG Sound Pack/NPC/misc/wolfman.wav"), ("oga80", "creature_roar_01.ogg")],
	# trolls das Estepes: rugido ao ver você, grunhido na skill, queda pesada
	"troll_growl": [("oga80", "creature_roar_02.ogg"), ("oga80", "creature_roar_03.ogg"), ("rpgpack", "RPG Sound Pack/NPC/gutteral beast/mnstr6.wav")],
	"troll_grunt": [("rpgpack", "RPG Sound Pack/NPC/ogre/ogre3.wav"), ("rpgpack", "RPG Sound Pack/NPC/ogre/ogre4.wav"), ("oga80", "creature_monster_02.ogg")],
	"troll_die": [("rpgpack", "RPG Sound Pack/NPC/giant/giant4.wav"), ("oga80", "creature_monster_04.ogg")],
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
	"""Soltura do arco, quase só ruído (playtest 2026-11-16: o Karplus-Strong antigo soava como nota de teclado).
	Estalo da corda + baque grave + vibração que morre em ~50 ms (áspera, sem nota) + sopro da flecha saindo."""
	out = zeros(0.34)
	snap = bandpass(noise(0.03, rng, decay=140, attack=0.0005), 1800, 7000)          # dedos soltam a corda
	thump = lowpass(lowpass(noise(0.1, rng, decay=50, attack=0.001), 420), 420)       # o arco devolve a energia
	f = rng.uniform(70, 95)
	grit = lowpass(noise(0.08, rng, decay=0.0), 600)
	m = max(1e-9, max(abs(x) for x in grit))
	thr = [a * (0.35 + 0.65 * abs(g) / m) for a, g in zip(tone(0.08, f * 1.7, f, decay=55, attack=0.001), grit)]
	whoosh = swell(bandpass(lowpass(noise(0.26, rng, decay=5), 4500, 900), 350, 9000), 0.22)
	add(out, thump, 0.002, 7.0)
	add(out, snap, 0, 0.6)
	add(out, thr, 0.001, 0.5)
	add(out, whoosh, 0.012, 0.5)
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


def s_ult_ready(rng):
	# Carga Suprema cheia (tecla R): acorde que sobe e brilho fino por cima, mais curto que o de subir de nível
	out = zeros(1.1)
	for k, st in enumerate([0, 7, 12]):
	    add(out, bell(0.45, NOTE(st + 2), decay=7), k * 0.07, 0.38)
	for st in [2, 9, 14, 19]:
	    add(out, bell(0.8, NOTE(st), decay=3.2), 0.24, 0.16)
	add(out, highpass(noise(0.6, rng, decay=5), 7000), 0.22, 0.05)
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


def s_firework(rng):
	"""Assobio de subida (0,55 s, o tempo do foguete no FestivalFx) + estouro + estalos caindo."""
	out = zeros(1.9)
	add(out, tone(0.55, rng.uniform(900, 1100), rng.uniform(2200, 2600), decay=0.6, attack=0.05), 0, 0.18)
	add(out, tone(0.6, 80, 35, decay=7), 0.55, 1.0)
	add(out, lowpass(noise(0.5, rng, decay=9), 2500), 0.55, 0.8)
	for _ in range(26):
		add(out, highpass(noise(0.015, rng, decay=200), 2500), 0.62 + rng.random() * 1.0, rng.uniform(0.15, 0.4))
	return out


# ---- Ato II (A Horda)
def _drum_hit(out, rng, f, at, gain, ring=0.5):
	"""Uma batida de tambor de pele: grave que cai de tom + estalo abafado da baqueta."""
	add(out, tone(ring, f * 1.7, f, decay=7.0 / ring * 0.5, harm=[(1.59, 0.3), (2.14, 0.15)]), at, gain)
	add(out, lowpass(noise(0.1, rng, decay=38), 1100), at, gain * 0.55)


def s_war_drum(rng):
	"""Tambor de guerra grande (skill do Agitador): dum, dum, DUM."""
	out = zeros(1.5)
	f = rng.uniform(58, 70)
	for at, g in ((0.0, 0.65), (0.26, 0.8), (0.52, 1.0)):
		_drum_hit(out, rng, f, at, g, ring=0.9)
	return out


def s_drum_beat(rng):
	"""Pulso da aura do Agitador (o jogo repete enquanto ele vive): uma a três batidas curtas."""
	out = zeros(0.55)
	f = rng.uniform(82, 96)
	for at, g in rng.choice([[(0.0, 1.0)], [(0.0, 1.0), (0.2, 0.6)], [(0.0, 0.8), (0.14, 0.5), (0.28, 1.0)]]):
		_drum_hit(out, rng, f, at, g, ring=0.26)
	return out


def s_net(rng):
	"""Rede arremessada: giro no ar (vupe-vupe) e as cordas esticando ao abrir."""
	out = zeros(0.65)
	nz = swell(bandpass(noise(0.45, rng, decay=0.8), 300, 2600), 0.6)
	rate = rng.uniform(15, 20)
	add(out, [x * (0.55 + 0.45 * math.sin(i / SR * 2 * math.pi * rate)) for i, x in enumerate(nz)], 0, 0.9)
	for _ in range(5):
		add(out, lowpass(pluck(0.12, rng.uniform(140, 260), rng, damp=0.98), 1800), 0.36 + rng.uniform(0, 0.14), 0.35)
	return out


def s_wolf_howl(rng):
	"""Uivo: sobe, sustenta com tremor e cai."""
	dur = rng.uniform(1.4, 1.7)
	n = n_of(dur)
	lo = rng.uniform(300, 345)
	hi = lo * rng.uniform(1.55, 1.75)
	out, ph = [], 0.0
	for i in range(n):
		u = i / n
		if u < 0.22:
			f = lo * (hi / lo) ** (u / 0.22)
		elif u < 0.7:
			f = hi * (1 + 0.012 * math.sin(2 * math.pi * 5.5 * i / SR))
		else:
			f = hi * 0.72 ** ((u - 0.7) / 0.3)
		ph += 2 * math.pi * f / SR
		v = math.sin(ph) + 0.45 * math.sin(2 * ph) + 0.2 * math.sin(3 * ph) + 0.08 * math.sin(4 * ph)
		out.append(v * min(1.0, u / 0.12) * min(1.0, (1 - u) / 0.3))
	breath = bandpass(noise(dur, rng, decay=0.3), 500, 2500)
	return lowpass([a + 0.15 * b * abs(a) for a, b in zip(out, breath)], 2600)


def s_goblin(rng):
	"""Tagarelar de goblin: quatro a seis guinchos curtos, cada um num tom."""
	out = zeros(0.8)
	at = 0.0
	for _ in range(rng.randint(4, 6)):
		d = rng.uniform(0.05, 0.1)
		f = rng.uniform(380, 640)
		y = tone(d, f, f * rng.choice([0.7, 1.35, 1.5]), kind="saw", decay=6, attack=0.008)
		add(out, bandpass(y, 700, 2600), at, rng.uniform(0.6, 1.0))
		at += d + rng.uniform(0.01, 0.05)
	return out


def s_goblin_shriek(rng):
	"""Guincho de goblin caindo: sobe rápido e desce tremendo."""
	dur = rng.uniform(0.4, 0.5)
	n = n_of(dur)
	f0 = rng.uniform(620, 760)
	out, ph = [], 0.0
	for i in range(n):
		u = i / n
		f = f0 * (2.1 ** (u / 0.3) if u < 0.3 else 2.1 * 0.5 ** ((u - 0.3) / 0.7))
		ph += 2 * math.pi * f / SR
		v = sum(math.sin(ph * k) / k for k in range(1, 6)) * 0.6
		trem = 1.0 if u < 0.3 else 0.65 + 0.35 * math.sin(i / SR * 2 * math.pi * 28)
		out.append(v * trem * min(1.0, u / 0.03) * min(1.0, (1 - u) / 0.25))
	out = bandpass(out, 800, 4500)
	add(out, highpass(noise(dur * 0.7, rng, decay=8), 3000), 0.08, 0.1)
	return out


def s_naga(rng):
	"""Silvo de naga: chiado agudo que treme, com o estalo da língua no começo."""
	dur = rng.uniform(0.65, 0.85)
	nz = highpass(noise(dur, rng, decay=0.4, attack=0.05), 3500)
	rate = rng.uniform(26, 38)
	out = swell([x * (0.75 + 0.25 * math.sin(i / SR * 2 * math.pi * rate)) for i, x in enumerate(nz)], 0.3)
	add(out, tone(0.1, 900, 500, decay=25), 0, 0.12)
	return out


def s_tide(rng):
	"""Maré/respingo: o corpo d'água bate, estoura, recua e pinga."""
	out = zeros(1.1)
	add(out, tone(0.35, 110, 48, decay=10), 0, 0.8)
	add(out, bandpass(noise(0.5, rng, decay=7, attack=0.004), 500, 6000), 0, 0.9)
	add(out, swell(lowpass(noise(1.0, rng, decay=1.6), 2200, 500), 0.25), 0.05, 0.5)
	for _ in range(10):
		f = rng.uniform(900, 2600)
		add(out, tone(0.05, f, f * 1.5, decay=45), rng.uniform(0.15, 0.8), rng.uniform(0.08, 0.2))
	return out


def s_troll_slam(rng):
	"""Pancada de troll: o punho de pedra bate no chão (grave fundo), a terra estala e o cascalho chove."""
	out = zeros(1.0)
	add(out, tone(0.6, 58, 26, decay=6, harm=[(1.5, 0.25)]), 0, 1.0)
	add(out, lowpass(noise(0.25, rng, decay=18, attack=0.001), 900), 0, 1.0)
	add(out, lowpass(noise(0.8, rng, decay=3.5), 380), 0.03, 0.7)
	for _ in range(14):
		add(out, bandpass(noise(0.03, rng, decay=90), 700, 3500), 0.12 + rng.random() * 0.6, rng.uniform(0.12, 0.35))
	return out


def s_troll_regen(rng):
	"""Carne de troll se fechando (pulso da regeneração): borbulho úmido grave e um zumbido verde que sobe."""
	out = zeros(0.75)
	for _ in range(rng.randint(4, 6)):
		f = rng.uniform(90, 180)
		add(out, tone(0.08, f, f * 1.8, decay=30, attack=0.006), rng.uniform(0.0, 0.4), rng.uniform(0.35, 0.6))
	add(out, swell(lowpass(noise(0.6, rng, decay=1.5), 600), 0.35), 0.0, 0.45)
	add(out, swell(tone(0.55, 220, 330, kind="tri", decay=1.2, harm=[(1.5, 0.3)]), 0.6), 0.12, 0.22)
	return out


# ---------------------------------------------------------------- Monte Kharzun (40-45)
def s_lava_bubble(rng):
	"""Lava borbulhando (laço perto da lava): bolhas grossas e lentas que estouram, com chiado de calor por baixo."""
	out = zeros(1.4)
	add(out, swell(lowpass(noise(1.3, rng, decay=0.9), 420), 0.5), 0.0, 0.5)
	for _ in range(rng.randint(3, 5)):
		f = rng.uniform(55, 110)
		at = rng.uniform(0.0, 1.0)
		add(out, tone(0.22, f, f * 2.4, decay=12, attack=0.02, harm=[(2.0, 0.25)]), at, rng.uniform(0.5, 0.8))
		add(out, lowpass(noise(0.05, rng, decay=60), 1500), at + 0.18, 0.35)
	add(out, highpass(noise(1.2, rng, decay=1.2, attack=0.2), 4500), 0.1, 0.05)
	return out


def s_forge_hammer(rng):
	"""Martelo na bigorna: clangue metálico agudo com o zumbido da bigorna; às vezes dois golpes."""
	out = zeros(1.2)
	hits = [(0.0, 1.0)] if rng.random() < 0.5 else [(0.0, 0.8), (0.42, 1.0)]
	for at, g in hits:
		f = rng.uniform(820, 980)
		add(out, bell(0.9, f, decay=5.0), at, g * 0.6)
		add(out, tone(0.6, f * 2.76, decay=7, harm=[(1.47, 0.4)]), at, g * 0.25)
		add(out, highpass(noise(0.04, rng, decay=80, attack=0.0005), 2500), at, g * 0.8)
	return out


def s_chain_break(rng):
	"""Corrente partindo: elo estala, os pedaços tilintam e caem no chão de pedra."""
	out = zeros(1.0)
	add(out, highpass(noise(0.05, rng, decay=70, attack=0.0005), 1800), 0.0, 1.0)
	add(out, bell(0.4, rng.uniform(1300, 1600), decay=9), 0.0, 0.5)
	for _ in range(9):
		f = rng.uniform(1800, 4200)
		add(out, tone(0.08, f, f * 0.97, decay=45), rng.uniform(0.08, 0.7), rng.uniform(0.15, 0.35))
	add(out, lowpass(noise(0.15, rng, decay=25), 900), 0.55, 0.4)
	return out


def s_smoke_vanish(rng):
	"""Bomba de fumaça (Assassino/Matador some ou salta): estalo seco, sopro que se espalha e um assobio que some."""
	out = zeros(0.8)
	add(out, lowpass(noise(0.04, rng, decay=90, attack=0.0005), 2500), 0.0, 0.9)
	add(out, swell(bandpass(noise(0.6, rng, decay=2.5), 300, 2200), 0.15), 0.01, 0.8)
	f = rng.uniform(1600, 2000)
	add(out, tone(0.35, f, f * 0.5, kind="sine", decay=6), 0.05, 0.12)
	return out


def s_dire_howl(rng):
	"""Uivo do lobo atroz: mais grave e mais rouco que o do lobo comum, com rosnado embaixo."""
	dur = rng.uniform(1.6, 1.9)
	n = n_of(dur)
	lo = rng.uniform(190, 220)
	hi = lo * rng.uniform(1.6, 1.8)
	out, ph = [], 0.0
	for i in range(n):
		u = i / n
		if u < 0.25:
			f = lo * (hi / lo) ** (u / 0.25)
		elif u < 0.68:
			f = hi * (1 + 0.018 * math.sin(2 * math.pi * 4.5 * i / SR))
		else:
			f = hi * 0.68 ** ((u - 0.68) / 0.32)
		ph += 2 * math.pi * f / SR
		v = math.sin(ph) + 0.55 * math.sin(2 * ph) + 0.3 * math.sin(3 * ph) + 0.12 * math.sin(5 * ph)
		out.append(v * min(1.0, u / 0.1) * min(1.0, (1 - u) / 0.3))
	growl = lowpass(noise(dur, rng, decay=0.4), 300)
	rate = 38.0
	out = [a + 0.5 * g * (0.5 + 0.5 * math.sin(i / SR * 2 * math.pi * rate)) for i, (a, g) in enumerate(zip(out, growl))]
	return lowpass(out, 2200)


def s_salamander_hiss(rng):
	"""Salamandra de lava: chiado de vapor com estalos de brasa e um gorgolejo grave."""
	dur = rng.uniform(0.6, 0.8)
	out = swell(bandpass(noise(dur, rng, decay=1.0, attack=0.03), 2500, 7000), 0.25)
	for _ in range(8):
		add(out, highpass(noise(0.01, rng, decay=200), 3000), rng.uniform(0.0, dur * 0.9), rng.uniform(0.2, 0.45))
	add(out, tone(0.25, 140, 70, decay=10, harm=[(2.0, 0.3)]), 0.0, 0.35)
	return out


def s_salamander_die(rng):
	"""Salamandra apagando: chiado longo de água em brasa que esfria e um último estalo."""
	out = zeros(1.2)
	add(out, lowpass(highpass(noise(1.1, rng, decay=2.2, attack=0.01), 1800), 9000, 2500), 0.0, 0.8)
	add(out, tone(0.4, 120, 45, decay=6), 0.0, 0.4)
	add(out, highpass(noise(0.02, rng, decay=150), 2500), rng.uniform(0.7, 0.95), 0.4)
	return out


def s_golem_rumble(rng):
	"""Golem de basalto: pedra moendo pedra, ronco grave e fundo."""
	dur = rng.uniform(0.9, 1.1)
	out = swell(lowpass(noise(dur, rng, decay=0.8, attack=0.05), 260), 0.4)
	gr = bandpass(noise(dur, rng, decay=1.2), 400, 1600)
	rate = rng.uniform(11, 15)
	add(out, [x * max(0.0, math.sin(i / SR * 2 * math.pi * rate)) for i, x in enumerate(gr)], 0.0, 0.45)
	add(out, tone(dur, 48, 40, decay=2.0, harm=[(1.5, 0.3)]), 0.0, 0.6)
	return out


def s_golem_crumble(rng):
	"""Golem desmoronando: estalo da rocha partindo e uma avalanche de blocos e cascalho."""
	out = zeros(1.6)
	add(out, lowpass(noise(0.12, rng, decay=30, attack=0.0005), 1400), 0.0, 1.0)
	add(out, tone(0.8, 52, 24, decay=4), 0.0, 0.8)
	for _ in range(10):
		at = rng.uniform(0.1, 1.1)
		add(out, tone(0.25, rng.uniform(60, 120), 35, decay=12), at, rng.uniform(0.3, 0.6))
		add(out, lowpass(noise(0.08, rng, decay=40), 1200), at, rng.uniform(0.2, 0.4))
	for _ in range(18):
		add(out, bandpass(noise(0.03, rng, decay=90), 900, 4000), rng.uniform(0.2, 1.4), rng.uniform(0.08, 0.2))
	return out


def s_boulder(rng):
	"""Pedregulho do Lança-Pedras caindo: baque surdo pesado e a pedra rolando até parar."""
	out = zeros(1.2)
	add(out, tone(0.5, 70, 32, decay=7, harm=[(1.7, 0.2)]), 0.0, 1.0)
	add(out, lowpass(noise(0.2, rng, decay=22, attack=0.001), 1100), 0.0, 0.9)
	roll = lowpass(noise(0.8, rng, decay=3.0), 500)
	rate = 9.0
	add(out, [x * (0.5 + 0.5 * math.sin(i / SR * 2 * math.pi * rate)) for i, x in enumerate(roll)], 0.15, 0.4)
	return out


def s_banner_plant(rng):
	"""Estandarte fincado no chão: a haste rasga a terra (baque + rangido) e o pano estala ao vento."""
	out = zeros(1.0)
	add(out, tone(0.35, 95, 50, decay=9), 0.0, 0.9)
	add(out, lowpass(noise(0.18, rng, decay=20, attack=0.001), 1300), 0.0, 0.8)
	add(out, bandpass(tone(0.25, 180, 140, kind="saw", decay=8), 300, 1400), 0.05, 0.25)
	for k in range(3):
		add(out, bandpass(noise(0.07, rng, decay=30), 700, 3000), 0.35 + k * 0.14 + rng.uniform(0, 0.04), 0.4)
	return out


def s_sig_warn(rng):
	"""Aviso de assinatura de chefe (o desenho apareceu no chão): gongo grave batido + trompa curta que sobe."""
	out = zeros(1.2)
	f = rng.uniform(150, 170)
	add(out, tone(1.2, f, f * 0.97, decay=2.6, attack=0.002, harm=[(2.41, 0.4), (3.9, 0.18), (5.2, 0.07)]), 0.0, 0.8)
	add(out, lowpass(noise(0.06, rng, decay=60, attack=0.0005), 2200), 0.0, 0.5)
	horn = lowpass(tone(0.55, f * 1.5, f * 2.0, kind="saw", decay=1.5, attack=0.06), 1400)
	add(out, swell(horn, 0.3), 0.08, 0.45)
	return out


def s_drum_tear(rng):
	"""Tambor rasgado (canal do Rufar quebrado): última batida oca, a pele rasgando e o aro chacoalhando."""
	out = zeros(1.1)
	_drum_hit(out, rng, rng.uniform(62, 72), 0.0, 0.9, ring=0.35)
	rip = bandpass(noise(0.45, rng, decay=4.0, attack=0.004), 500, 3200)
	rate = rng.uniform(55, 75)
	add(out, [x * (0.35 + 0.65 * abs(math.sin(i / SR * math.pi * rate))) for i, x in enumerate(lowpass(rip, 3200, 700))], 0.06, 0.8)
	for k in range(4):
		add(out, bandpass(noise(0.05, rng, decay=50), 1500, 5000), 0.45 + k * 0.09 + rng.uniform(0, 0.03), 0.25)
	return out


def _buzz(dur, f, rng, vib=7.0):
	"""Zumbido de asa: dente-de-serra grave com batida rápida (a asa) e vibrato lento."""
	n = n_of(dur)
	out, ph = [], 0.0
	beat = rng.uniform(170, 210)
	for i in range(n):
		t = i / SR
		u = i / n
		ph += 2 * math.pi * f * (1 + 0.04 * math.sin(2 * math.pi * vib * t)) / SR
		v = sum(math.sin(ph * k) / k for k in range(1, 7)) * 0.6
		v *= 0.55 + 0.45 * abs(math.sin(math.pi * beat * t))
		out.append(v * min(1.0, u / 0.12) * min(1.0, (1 - u) / 0.25))
	return bandpass(out, 160, 3200)


def s_wasp_buzz(rng):
	"""Vespa avistando você (Mata dos Zumbidos): zumbido que chega perto e sobe de tom."""
	dur = rng.uniform(0.6, 0.8)
	f = rng.uniform(210, 250)
	out = _buzz(dur, f, rng)
	up = _buzz(0.25, f * 1.35, rng, vib=12.0)
	add(out, up, dur - 0.3, 0.6)
	return out


def s_wasp_die(rng):
	"""Vespa caindo: o zumbido despenca de tom e para com um estalinho."""
	out = zeros(0.55)
	n = n_of(0.45)
	ph, buzz = 0.0, []
	f0 = rng.uniform(230, 260)
	for i in range(n):
		u = i / n
		f = f0 * 0.35 ** u
		ph += 2 * math.pi * f / SR
		buzz.append(sum(math.sin(ph * k) / k for k in range(1, 6)) * 0.6 * (0.55 + 0.45 * abs(math.sin(math.pi * 190 * i / SR))) * (1 - u))
	add(out, bandpass(buzz, 120, 2800), 0.0, 0.9)
	add(out, highpass(noise(0.015, rng, decay=160), 2500), 0.45, 0.5)
	return out


def s_bear_growl(rng):
	"""Urso (Mata dos Zumbidos): rosnado grave e áspero, com o bafo por cima."""
	dur = rng.uniform(0.8, 1.0)
	f = rng.uniform(85, 100)
	body = tone(dur, f, f * 0.85, kind="saw", decay=1.5, attack=0.06)
	rough = lowpass(noise(dur, rng, decay=1.2, attack=0.05), 420)
	rate = rng.uniform(28, 34)
	out = [a + 0.8 * r * (0.5 + 0.5 * math.sin(i / SR * 2 * math.pi * rate)) for i, (a, r) in enumerate(zip(body, rough))]
	add(out, bandpass(noise(dur, rng, decay=2.0, attack=0.04), 600, 2000), 0.0, 0.15)
	return swell(lowpass(out, 1500), 0.3)


def s_bear_roar(rng):
	"""Rugido da Ursa-Mãe (lentidão em área): abre grave, cresce e rasga, com o peito ressoando."""
	dur = rng.uniform(1.3, 1.5)
	n = n_of(dur)
	lo = rng.uniform(95, 110)
	out, ph = [], 0.0
	for i in range(n):
		u = i / n
		f = lo * (1.5 ** (u / 0.3) if u < 0.3 else 1.5 * 0.7 ** ((u - 0.3) / 0.7))
		ph += 2 * math.pi * f / SR
		v = math.sin(ph) + 0.6 * math.sin(2 * ph) + 0.35 * math.sin(3 * ph) + 0.15 * math.sin(5 * ph)
		out.append(v * min(1.0, u / 0.08) * min(1.0, (1 - u) / 0.35))
	rasp = lowpass(noise(dur, rng, decay=0.5, attack=0.08), 900)
	out = [a + 0.9 * r * abs(a) for a, r in zip(out, rasp)]
	add(out, tone(dur, 48, 40, decay=1.5, harm=[(1.5, 0.3)]), 0.0, 0.5)
	return lowpass(out, 2400)


def s_hive_crack(rng):
	"""Colmeia gigante caindo: papel da colmeia rachando, o miolo de cera desabando e um último zumbido que some."""
	out = zeros(1.4)
	for _ in range(12):
		add(out, bandpass(noise(0.05, rng, decay=60), 900, 4500), rng.uniform(0.0, 0.5), rng.uniform(0.3, 0.6))
	add(out, tone(0.6, 75, 38, decay=5), 0.35, 0.8)
	add(out, lowpass(noise(0.3, rng, decay=10, attack=0.002), 900), 0.35, 0.7)
	add(out, _buzz(0.8, rng.uniform(200, 230), rng), 0.5, 0.35)
	return out


def s_ui_open(rng):
	return tone(0.09, 520, 820, decay=30, attack=0.002)


def s_ui_close(rng):
	return tone(0.09, 820, 520, decay=30, attack=0.002)


# ---------------------------------------------------------------- impactos por alvo (plano de combate 2026-11-23, C3d)
# Curtos (<= 0,3 s) e secos: tocam em cada alvo atingido, por cima do som da skill/golpe.
def s_hit_blunt(rng):
	"""Maça/cetro/cajado/punho: baque grave + estalo de madeira/metal abafado."""
	out = zeros(0.26)
	f = rng.uniform(85, 110)
	add(out, tone(0.22, f, f * 0.55, decay=18), 0, 1.0)
	add(out, lowpass(noise(0.08, rng, decay=40), 1800), 0, 0.7)
	add(out, bandpass(noise(0.03, rng, decay=120), 900, 3000), 0.004, 0.35)
	return out


def s_hit_chop(rng):
	"""Machado: corte pesado (ruído médio rasgado) + baque."""
	out = zeros(0.28)
	add(out, bandpass(noise(0.12, rng, decay=22), 500, 4200), 0, 0.9)
	add(out, tone(0.2, rng.uniform(120, 150), 60, decay=16), 0.006, 0.8)
	add(out, highpass(noise(0.02, rng, decay=160), 3500), 0, 0.4)
	return out


def s_hit_pierce(rng):
	"""Flecha/bala/lança: estalo agudo curto + batida seca."""
	out = zeros(0.2)
	add(out, highpass(noise(0.03, rng, decay=140), 2500), 0, 0.8)
	add(out, tone(0.12, rng.uniform(190, 240), 110, decay=30), 0.003, 0.7)
	add(out, bandpass(noise(0.06, rng, decay=55), 700, 2400), 0.004, 0.4)
	return out


def s_impact_fire(rng):
	out = zeros(0.3)
	add(out, lowpass(noise(0.28, rng, decay=12, attack=0.004), 2600, 700), 0, 1.0)
	add(out, tone(0.18, 140, 70, decay=20), 0, 0.5)
	for _ in range(4):
		add(out, highpass(noise(0.01, rng, decay=300), 3000), rng.uniform(0.02, 0.2), rng.uniform(0.2, 0.4))
	return out


def s_impact_ice(rng):
	out = zeros(0.3)
	add(out, highpass(noise(0.05, rng, decay=70), 3000), 0, 0.7)
	for _ in range(4):
		add(out, tone(0.22, rng.uniform(2600, 4800), decay=rng.uniform(16, 24)), rng.uniform(0, 0.05), rng.uniform(0.2, 0.35))
	add(out, tone(0.1, 180, 120, decay=30), 0, 0.4)
	return out


def s_impact_lightning(rng):
	out = zeros(0.25)
	nz = noise(0.2, rng, decay=16)
	gate = [1.0 if (i // n_of(0.006)) % 2 == 0 or rng.random() < 0.3 else 0.1 for i in range(len(nz))]
	add(out, highpass([a * b for a, b in zip(nz, gate)], 1200), 0, 1.0)
	add(out, tone(0.12, 110, 60, decay=26), 0, 0.5)
	return out


def s_impact_holy(rng):
	out = zeros(0.32)
	r = rng.choice([7, 9, 12])
	add(out, bell(0.3, NOTE(r), decay=11), 0, 0.5)
	add(out, bell(0.3, NOTE(r + 7), decay=13), 0.01, 0.3)
	add(out, tone(0.1, 160, 100, decay=30), 0, 0.5)
	return out


def s_impact_shadow(rng):
	out = zeros(0.3)
	a = rng.uniform(150, 190)
	add(out, lowpass(tone(0.28, a, a * 0.5, kind="saw", decay=10, attack=0.006), 800), 0, 0.8)
	add(out, lowpass(noise(0.2, rng, decay=14), 900), 0, 0.5)
	return out


def s_impact_nature(rng):
	out = zeros(0.28)
	add(out, bandpass(noise(0.16, rng, decay=20), 400, 2600), 0, 0.8)
	for _ in range(3):
		add(out, bandpass(noise(0.03, rng, decay=90), 1200, 4000), rng.uniform(0.0, 0.08), 0.4)
	add(out, tone(0.14, 130, 80, decay=24), 0, 0.5)
	return out


def s_impact_arcane(rng):
	out = zeros(0.28)
	f = rng.uniform(500, 700)
	add(out, tone(0.25, f, f * 0.6, kind="tri", decay=14), 0, 0.6)
	add(out, tone(0.25, f * 1.5, f * 0.9, decay=16), 0.005, 0.3)
	add(out, bandpass(noise(0.08, rng, decay=40), 900, 5000), 0, 0.4)
	return out


def s_whoosh(rng):
	"""Vento da arma ANTES do impacto (pacote V2): cresce e corta seco no fim (o impacto/hit entra em cima)."""
	dur = rng.uniform(0.13, 0.16)
	nz = noise(dur, rng, decay=0.0, attack=0.002)
	body = bandpass(lowpass(nz, 500, 3800), 220, 7000)          # o filtro abre: a lâmina chega perto
	n = len(body)
	env = [(i / n) ** 1.8 * (1.0 if i < n * 0.9 else (n - i) / (n * 0.1)) for i in range(n)]
	out = zeros(dur)
	add(out, [x * a for x, a in zip(body, env)], 0, 1.0)
	add(out, [x * a for x, a in zip(lowpass(noise(dur, rng, decay=0.0), 260), env)], 0, 0.5)     # peso grave
	return out


def s_whoosh_magic(rng):
	"""Magia rápida: sopro aéreo com um brilho que sobe (energia chegando na mão) e corta no impacto."""
	dur = rng.uniform(0.12, 0.15)
	n = n_of(dur)
	nz = bandpass(noise(dur, rng, decay=0.0), 1200, 7000)
	env = [(i / n) ** 1.6 * (1.0 if i < n * 0.88 else (n - i) / (n * 0.12)) for i in range(n)]
	out = zeros(dur)
	add(out, [x * a for x, a in zip(nz, env)], 0, 0.7)
	f = rng.uniform(700, 900)
	sh = tone(dur, f, f * 1.8, kind="sine", decay=0.0, attack=0.02)
	add(out, [x * a for x, a in zip(sh, env)], 0, 0.25)
	return out


SYNTH = {
	"ice": (s_ice, 3), "lightning": (s_lightning, 3), "holy": (s_holy, 3), "shadow": (s_shadow, 2),
	"poison": (s_poison, 3), "nature": (s_nature, 2), "wind": (s_wind, 2), "earth": (s_earth, 2),
	"blood": (s_blood, 3), "lunar": (s_lunar, 2), "summon": (s_summon, 2), "heal": (s_heal, 2),
	"bone": (s_bone, 3), "cast": (s_cast, 3), "dodge": (s_dodge, 3), "crit": (s_crit, 3),
	"hurt": (s_hurt, 2), "bow": (s_bow, 4), "gun": (s_gun, 2), "level_up": (s_level_up, 1), "ult_ready": (s_ult_ready, 1),
	"quest_accept": (s_quest_accept, 1), "quest_done": (s_quest_done, 1), "recall": (s_recall, 1),
	"recall_done": (s_recall_done, 1), "death": (s_death, 1), "firework": (s_firework, 3), "ui_open": (s_ui_open, 1), "ui_close": (s_ui_close, 1),
	# Ato II (A Horda)
	"war_drum": (s_war_drum, 2), "drum_beat": (s_drum_beat, 3), "net": (s_net, 2), "wolf_howl": (s_wolf_howl, 3),
	"goblin": (s_goblin, 3), "goblin_shriek": (s_goblin_shriek, 2), "naga": (s_naga, 3), "tide": (s_tide, 3),
	"troll_slam": (s_troll_slam, 3), "troll_regen": (s_troll_regen, 3),
	# Monte Kharzun (40-45): lava, forja, correntes, fumaça dos Assassinos, nativos da montanha, pedregulho, estandarte
	"lava_bubble": (s_lava_bubble, 3), "forge_hammer": (s_forge_hammer, 3), "chain_break": (s_chain_break, 2),
	"smoke_vanish": (s_smoke_vanish, 3), "dire_howl": (s_dire_howl, 3), "salamander_hiss": (s_salamander_hiss, 3),
	"salamander_die": (s_salamander_die, 2), "golem_rumble": (s_golem_rumble, 2), "golem_crumble": (s_golem_crumble, 2),
	"boulder": (s_boulder, 3), "banner_plant": (s_banner_plant, 2),
	# assinaturas dos chefes (design/gdd/act2-boss-signatures.md): aviso do desenho no chão e o tambor que rasga
	"sig_warn": (s_sig_warn, 2), "drum_tear": (s_drum_tear, 2),
	# Mata dos Zumbidos (4-8): vespas, ursos e a colmeia
	"wasp_buzz": (s_wasp_buzz, 3), "wasp_die": (s_wasp_die, 2), "bear_growl": (s_bear_growl, 3),
	"bear_roar": (s_bear_roar, 2), "hive_crack": (s_hive_crack, 2),
	# impactos por alvo (plano de combate 2026-11-23, C3d): golpe físico por família de arma, magia por tema
	"hit_blunt": (s_hit_blunt, 3), "hit_chop": (s_hit_chop, 3), "hit_pierce": (s_hit_pierce, 3),
	"impact_fire": (s_impact_fire, 3), "impact_ice": (s_impact_ice, 3), "impact_lightning": (s_impact_lightning, 3),
	"impact_holy": (s_impact_holy, 3), "impact_shadow": (s_impact_shadow, 3), "impact_nature": (s_impact_nature, 3),
	"impact_arcane": (s_impact_arcane, 3),
	# vento antes do impacto das skills rápidas (pacote V2, 2026-11-23)
	"whoosh": (s_whoosh, 3), "whoosh_magic": (s_whoosh_magic, 3),
}


def main():
	cache = os.path.join(ROOT, ".godot", "sfx_cache")      # .godot/ é ignorado pelo git e pelo export
	if "--cache" in sys.argv:
		cache = sys.argv[sys.argv.index("--cache") + 1]
	only = set()                                            # --only=bow,gun: refaz só esses nomes, o resto fica intacto
	for a in sys.argv:
		if a.startswith("--only="):
			only = {x for x in a[7:].split(",") if x}
	unknown = only - set(CC0) - set(SYNTH)
	if unknown:
		sys.exit("nomes desconhecidos: %s" % ", ".join(sorted(unknown)))
	os.makedirs(OUT, exist_ok=True)
	for f in os.listdir(OUT):                               # o banco é todo gerado aqui
		if f.endswith((".wav", ".ogg")) and (not only or os.path.splitext(f)[0].rsplit("_", 1)[0] in only):
			os.remove(os.path.join(OUT, f))
	zips = fetch(cache) if not only or only & set(CC0) else {}
	count = 0
	for ev, srcs in CC0.items():
		if only and ev not in only:
			continue
		for i, (pk, inner) in enumerate(srcs, 1):
			data = zips[pk].read(zip_member(zips[pk], inner))
			if inner.endswith(".ogg"):
				open(os.path.join(OUT, "%s_%d.ogg" % (ev, i)), "wb").write(data)
			else:
				s, rate = wav_to_mono16(data)
				write_wav(os.path.join(OUT, "%s_%d.wav" % (ev, i)), s, rate, peak=0.9)
			count += 1
	for ev, (fn, n) in SYNTH.items():
		if only and ev not in only:
			continue
		for i in range(1, n + 1):
			rng = random.Random("%s:%d" % (ev, i))
			write_wav(os.path.join(OUT, "%s_%d.wav" % (ev, i)), fn(rng))
			count += 1
	if only:
		print("banco:", count, "arquivos refeitos em", OUT, "(--only)")
		return
	with open(os.path.join(ROOT, "assets", "audio", "CREDITS.md"), "w", encoding="utf-8") as f:
		f.write("# Créditos de áudio\n\nGerado por `tools/audio/build_sfx.py`. Sons sintetizados pelo script são do projeto.\n\n")
		f.write("Pacotes de domínio público (CC0 1.0, sem atribuição obrigatória; creditados por cortesia):\n\n")
		for key, (page, _url, name) in PACKS.items():
			used = sorted({ev for ev, srcs in CC0.items() for pk, _ in srcs if pk == key})
			f.write("- %s — %s — usado em: %s\n" % (name, page, ", ".join(used)))
	print("banco:", count, "arquivos em", OUT)


if __name__ == "__main__":
	main()
