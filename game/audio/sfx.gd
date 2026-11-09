class_name Sfx
extends Node
## Efeitos sonoros lidos do EventBus (como o FxManager; nunca muda a sim).
## Banco: res://assets/audio/sfx/<nome>_<n>.<ogg|wav>, gerado por tools/audio/build_sfx.py (CC0 + sintetizado);
## cada toque sorteia uma variação e um tom levemente diferente.
## Som do mundo sai de um AudioStreamPlayer3D no ponto do evento (o fone/caixa dá a direção), mas o volume
## é pela distância ao JOGADOR (a câmera fica a ~24 m de tudo): cheio até NEAR, some em FAR.
## Briga dos outros sai mais baixa; cada nome tem intervalo mínimo e teto de vozes (batalha grande não vira chiado).

const DIR := "res://assets/audio/sfx/"
const POOL := 28                 # vozes no mundo
const UI_POOL := 6
const NEAR := 8.0
const FAR := 40.0
const OTHERS_DB := -5.0          # golpes de quem não é você nem do seu grupo
const MIN_GAP := 0.035           # s entre dois toques do mesmo nome
const MAX_VOICES := 3            # do mesmo nome ao mesmo tempo
## Volume base por nome (dB). O que não está aqui toca em 0 dB.
const VOL := {
	"swing": -9.0, "hit": -6.0, "crit": -3.0, "hurt": -4.0, "block": -6.0, "parry": -2.0, "dodge": -8.0,
	"cast": -10.0, "bow": -6.0, "gun": -5.0, "arcane": -6.0, "fire": -5.0, "ice": -6.0, "lightning": -6.0,
	"holy": -6.0, "shadow": -5.0, "poison": -7.0, "nature": -6.0, "wind": -7.0, "earth": -4.0, "blood": -6.0,
	"lunar": -6.0, "summon": -6.0, "heal": -8.0, "bone": -6.0, "die_monster": -7.0, "die_boss": -2.0,
	"pickup": -8.0, "coins": -8.0, "gem": -4.0, "potion": -6.0, "equip": -8.0, "craft": -6.0, "gather": -6.0,
	"door": -8.0, "click": -10.0, "page": -8.0, "ui_open": -14.0, "ui_close": -16.0, "level_up": -3.0,
	"quest_accept": -5.0, "quest_done": -3.0, "recall": -6.0, "recall_done": -5.0, "death": -3.0, "firework": -7.0,
}
## Tema visual (FxManager.theme_of) -> som da skill. Físico não tem: quem soa é o golpe (swing/hit).
const THEME_SOUND := {
	"fire": "fire", "ice": "ice", "lightning": "lightning", "holy": "holy", "lunar": "lunar", "shadow": "shadow",
	"poison": "poison", "bone": "bone", "nature": "nature", "earth": "earth", "blood": "blood", "wind": "wind",
	"heal": "heal", "summon": "summon",
}
const RANGED_SOUND := {"bow": "bow", "rifle": "gun", "pistol": "gun"}

static var _inst: Sfx = null

var main                                   # Main (mapa atual)
var bank: Dictionary = {}                  # nome -> Array[AudioStream]
var _players: Array[AudioStreamPlayer3D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _next := 0
var _ui_next := 0
var _last_at: Dictionary = {}              # nome -> tempo (s) do último toque
var _quiet_until := 0.0                    # equipar/itens do carregamento não soam
var _gold := -1
var played: Dictionary = {}                # nome -> vezes que tocou (o smoke imprime)

## Toca um som de interface (cliques, janelas). Sem Sfx na árvore (testes, ferramentas), não faz nada.
## Contagem do que tocou nesta partida (smoke/revisão).
static func played_summary() -> String:
	if not is_instance_valid(_inst):
		return "sem Sfx"
	var keys: Array = _inst.played.keys()
	keys.sort()
	return ", ".join(keys.map(func(k): return "%s=%d" % [k, _inst.played[k]]))

static func ui(sound: String) -> void:
	if is_instance_valid(_inst):
		_inst.play_ui(sound)

func _ready() -> void:
	_inst = self
	AudioSettings.load_and_apply()
	_load_bank()
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED     # volume vem da distância ao jogador
		p.panning_strength = 0.6
		add_child(p)
		_players.append(p)
	for i in UI_POOL:
		var u := AudioStreamPlayer.new()
		u.bus = &"UI"
		add_child(u)
		_ui_players.append(u)
	_quiet_until = _now() + 2.0
	get_tree().node_added.connect(_on_node_added)
	Events.skill_cast.connect(_on_skill_cast)
	Events.skill_effect.connect(_on_skill_effect)
	Events.projectile_spawned.connect(_on_projectile)
	Events.damage_dealt.connect(_on_damage)
	Events.blocked_hit.connect(_on_block)
	Events.shield_block.connect(_on_shield_block)
	Events.dodged.connect(_on_dodged)
	Events.entity_died.connect(_on_died)
	Events.level_up.connect(_on_level_up)
	Events.item_gained.connect(_on_item_gained)
	Events.potion_used.connect(func(id: int, _s: int): _player_sound(id, "potion"))
	Events.equipment_changed.connect(_on_equipment_changed)
	Events.quest_accepted.connect(func(id: int, _q: String): _player_sound(id, "quest_accept", true))
	Events.quest_completed.connect(func(id: int, _q: String): _player_sound(id, "quest_done", true))
	Events.crafted.connect(func(id: int, _i: String, _c: int): _player_sound(id, "craft"))
	Events.gathered.connect(func(_m: String, _n: int, id: int): _player_sound(id, "gather"))
	Events.recall_cast.connect(_on_recall)
	Events.entity_changed_map.connect(_on_changed_map)

func _exit_tree() -> void:
	if _inst == self:
		_inst = null

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Lê o banco pelo prefixo (funciona no jogo exportado: list_directory vê os recursos importados).
func _load_bank() -> void:
	for f in ResourceLoader.list_directory(DIR):
		var file := String(f)
		if not (file.ends_with(".ogg") or file.ends_with(".wav")):
			continue
		var key := file.get_basename()
		key = key.substr(0, key.rfind("_"))
		var s: AudioStream = load(DIR + file)
		if s:
			if not bank.has(key):
				bank[key] = []
			bank[key].append(s)

# ---------------------------------------------------------------- tocar
## Som no mundo, no ponto `pos`. `mine` = do jogador/grupo (volume cheio; os outros saem mais baixos).
func play_at(sound: String, pos: Vector3, mine: bool = true, extra_db: float = 0.0) -> void:
	if not bank.has(sound) or not _gap_ok(sound):
		return
	var p: SimEntity = Sim.player
	var d := 0.0 if p == null else pos.distance_to(p.position)
	if d >= FAR:
		return
	var g := 1.0 if d <= NEAR else 1.0 - (d - NEAR) / (FAR - NEAR)
	var db: float = float(VOL.get(sound, 0.0)) + linear_to_db(g) + extra_db + (0.0 if mine else OTHERS_DB)
	var pl := _voice(sound)
	if pl == null:
		return
	pl.stream = _pick(sound)
	pl.global_position = pos + Vector3(0, 1.0, 0)
	pl.volume_db = db
	pl.pitch_scale = randf_range(0.93, 1.07)
	pl.set_meta("sound", sound)
	pl.play()
	played[sound] = int(played.get(sound, 0)) + 1

func play_ui(sound: String) -> void:
	if not bank.has(sound) or not _gap_ok(sound):
		return
	var u := _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	u.stream = _pick(sound)
	u.volume_db = float(VOL.get(sound, 0.0))
	u.pitch_scale = randf_range(0.97, 1.03)
	u.play()
	played[sound] = int(played.get(sound, 0)) + 1

func _pick(sound: String) -> AudioStream:
	var arr: Array = bank[sound]
	return arr[randi() % arr.size()]

func _gap_ok(sound: String) -> bool:
	var t := _now()
	if t - float(_last_at.get(sound, -1.0)) < MIN_GAP:
		return false
	_last_at[sound] = t
	return true

## Voz livre; se o nome já tem MAX_VOICES tocando, não toca; senão rouba a mais antiga do rodízio.
func _voice(sound: String) -> AudioStreamPlayer3D:
	var same := 0
	for pl in _players:
		if pl.playing and pl.get_meta("sound", "") == sound:
			same += 1
	if same >= MAX_VOICES:
		return null
	for i in _players.size():
		var pl := _players[(_next + i) % _players.size()]
		if not pl.playing:
			_next = (_next + i + 1) % _players.size()
			return pl
	var steal := _players[_next]
	_next = (_next + 1) % _players.size()
	return steal

# ---------------------------------------------------------------- quem
func _here(e: SimEntity) -> bool:
	return e != null and main != null and e.map_id == main.current_map_id

## Do jogador ou do grupo dele (e invocações): o mesmo critério dos números de dano.
func _mine(e: SimEntity) -> bool:
	var p: SimEntity = Sim.player
	if p == null or e == null:
		return false
	if e == p or e.owner_id == p.id:
		return true
	return p.party_id >= 0 and e.party_id == p.party_id

func _player_sound(id: int, sound: String, as_ui: bool = false) -> void:
	var p: SimEntity = Sim.player
	if p == null or id != p.id:
		return
	if as_ui:
		play_ui(sound)
	else:
		play_at(sound, p.position)

# ---------------------------------------------------------------- eventos
## Golpe físico: o vento da arma no começo da fase ativa. Magia demorada: o zumbido da preparação.
func _on_skill_cast(id: int, skill_id: String, phase: String) -> void:
	var e: SimEntity = Sim.get_entity(id)
	if not _here(e) or skill_id == "jump":
		return
	if skill_id == "dash":
		play_at("dodge", e.position, _mine(e), -2.0)
		return
	var s: SkillDef = GameData.skill_or_basic(skill_id)
	if s == null:
		return
	var ranged := e.stats != null and RANGED_SOUND.has(e.stats.weapon_type)
	if phase == "startup" and s.kind != SkillDef.Kind.PHYSICAL and s.kind != SkillDef.Kind.HEAL and s.startup >= 0.2:
		play_at("cast", e.position, _mine(e))
	elif phase == "active" and s.kind == SkillDef.Kind.PHYSICAL and not ranged:
		play_at("swing", e.position, _mine(e), -3.0 if e.kind == SimEntity.Kind.MONSTER else 0.0)

## Impacto de skill (não do básico, que soa no golpe): som do tema no ponto mirado.
func _on_skill_effect(skill_id: String, origin: Vector3, aim: Vector3, _radius: float) -> void:
	if not GameData.skills.has(skill_id):
		return
	var s: SkillDef = GameData.skills[skill_id]
	var snd: String = THEME_SOUND.get(FxManager.theme_of(s), "")
	if snd == "" and s.kind == SkillDef.Kind.MAGICAL:
		snd = "arcane"
	if snd == "":
		return
	var p: SimEntity = Sim.player
	var at := aim if s.target in [SkillDef.Target.GROUND, SkillDef.Target.TARGET] else origin
	var mine := p != null and origin.distance_to(p.position) < 1.5
	play_at(snd, at, mine or p == null)

func _on_projectile(pr: SimProjectile) -> void:
	var e: SimEntity = Sim.get_entity(pr.owner_id)
	if not _here(e) or e.stats == null:
		return
	var snd: String = RANGED_SOUND.get(e.stats.weapon_type, "")
	if snd != "" and (pr.skill == null or pr.skill.kind == SkillDef.Kind.PHYSICAL):
		play_at(snd, e.position, _mine(e))

func _on_damage(attacker_id: int, target_id: int, amount: int, crit: bool, blocked: bool, kind: String) -> void:
	if blocked or amount <= 0 or kind in ["dot", "dot_fire", "aura", "interrupt"]:
		return
	var t: SimEntity = Sim.get_entity(target_id)
	if not _here(t):
		return
	var a: SimEntity = Sim.get_entity(attacker_id)
	if t == Sim.player:
		play_at("hurt", t.position)
		return
	var mine := _mine(a) or _mine(t)
	if kind != "magical":
		play_at("hit", t.position, mine)
	if crit and mine:
		play_at("crit", t.position, true)

func _on_block(id: int) -> void:
	var t: SimEntity = Sim.get_entity(id)
	if _here(t):
		play_at("block", t.position, _mine(t))

func _on_shield_block(id: int, _attacker: int, _theme: String, parried: bool, _from: Vector3) -> void:
	var t: SimEntity = Sim.get_entity(id)
	if _here(t):
		play_at("parry" if parried else "block", t.position, _mine(t))

func _on_dodged(id: int) -> void:
	var t: SimEntity = Sim.get_entity(id)
	if _here(t):
		play_at("dodge", t.position, _mine(t))

func _on_died(id: int, _killer: int) -> void:
	var e: SimEntity = Sim.get_entity(id)
	if not _here(e):
		return
	if e == Sim.player:
		play_ui("death")
	elif e.kind == SimEntity.Kind.MONSTER:
		var boss := e.monster_def != null and e.monster_def.is_boss
		play_at("die_boss" if boss else "die_monster", e.position, true)

func _on_level_up(id: int, _lv: int) -> void:
	_player_sound(id, "level_up", true)

func _on_item_gained(id: int, item_id: String, _count: int) -> void:
	if Sim.player == null or id != Sim.player.id or _now() < _quiet_until:
		return
	var it: ItemDef = GameData.items.get(item_id)
	play_ui("gem" if it != null and it.rarity >= 3 else "pickup")

func _on_equipment_changed(id: int) -> void:
	if _now() >= _quiet_until:
		_player_sound(id, "equip", true)

func _on_recall(id: int, phase: String) -> void:
	if phase == "start":
		_player_sound(id, "recall")
	elif phase == "done":
		_player_sound(id, "recall_done", true)

## Entrar/sair de casa: porta.
func _on_changed_map(id: int, map_id: String) -> void:
	var p: SimEntity = Sim.player
	if p == null or id != p.id:
		return
	var m: MapDef = GameData.maps.get(map_id)
	var prev: MapDef = GameData.maps.get(main.current_map_id) if main else null
	if (m and m.interior) or (prev and prev.interior):
		play_ui("door")

## Ouro só sobe por venda, quest ou saque: moedas.
func _process(_delta: float) -> void:
	var p: SimEntity = Sim.player
	if p == null:
		return
	if _gold >= 0 and p.gold > _gold and _now() >= _quiet_until:
		play_ui("coins")
	_gold = p.gold

## Todo botão da interface clica (janelas são refeitas em código, então liga na criação).
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(_click):
		(n as BaseButton).pressed.connect(_click)

func _click() -> void:
	play_ui("click")
