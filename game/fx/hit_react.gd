class_name HitReact
extends Node
## Quem reage no corpo a um golpe (plano de combate 2026-11-23, C3a/C3b). Só apresentação: ouve Events.damage_dealt
## e chama EntityView.react_hit; nada na sim muda.
## - Personagem (jogador, bots, aliados): só golpe forte (>= HEAVY_PCT da vida máxima), nunca dano no tempo nem
##   golpe bloqueado; a reação é aditiva (HitFlinch) e o controle nunca sai.
## - Chefe tem postura: não encolhe a cada golpe (EntityView pula o encolher do clarão); só com golpe >= BOSS_POISE_PCT
##   da vida ou interrompido (o atordoado já toca o clipe "hit" pelo estado).
## - Monstro comum: segue o encolher do clarão de sempre (EntityView).
## Densidade de efeitos dos aliados (AccessSettings "Mínimo"): aliados não reagem; você sempre.

const HEAVY_PCT := 0.08       # personagem: golpe a partir de 8% da vida máxima
const FULL_PCT := 0.25        # força 1 a partir daqui
const MIN_STRENGTH := 0.5     # golpe forte mais fraco ainda se vê
const BOSS_POISE_PCT := 0.05  # chefe: só encolhe com golpe de 5% da vida ou mais
const SKIP_KINDS := {"dot": true, "dot_fire": true, "aura": true, "thorns": true, "echo": true, "splash": true}

var main                      # Main (views, mapa atual)

func _ready() -> void:
	Events.damage_dealt.connect(_on_damage)

func _on_damage(attacker_id: int, target_id: int, amount: int, _crit: bool, blocked: bool, kind: String) -> void:
	if main == null:
		return
	var t: SimEntity = Sim.get_entity(target_id)
	if t == null or t.map_id != main.current_map_id or not t.is_alive():
		return
	var s := strength(t, amount, blocked, kind)
	if s <= 0.0:
		return
	if t != Sim.player and t.kind != SimEntity.Kind.MONSTER and not AccessSettings.ally_pass():
		return
	var v = main.views.get(target_id)
	if v == null:
		return
	var a: SimEntity = Sim.get_entity(attacker_id)
	var dir := Vector3.ZERO
	if a != null and a != t:
		dir = t.position - a.position
	if Vector2(dir.x, dir.z).length() < 0.01:
		dir = -t.forward()
	v.react_hit(dir, s)

## Força da reação 0-1 (0 = nenhuma). Puro (o teste chama sem cena).
static func strength(t: SimEntity, amount: int, blocked: bool, kind: String) -> float:
	if t == null or t.stats == null or amount <= 0 and kind != "interrupt":
		return 0.0
	var max_hp := maxf(1.0, t.stats.max_hp)
	if t.kind == SimEntity.Kind.MONSTER:
		if t.monster_def == null or not t.monster_def.is_boss:
			return 0.0                     # monstro comum: o encolher do clarão (EntityView) já cobre
		if kind == "interrupt":
			return 1.0
		if blocked or SKIP_KINDS.has(kind):
			return 0.0
		return 1.0 if amount >= max_hp * BOSS_POISE_PCT else 0.0
	if not t.is_character() or blocked or SKIP_KINDS.has(kind) or kind == "interrupt":
		return 0.0
	var f := float(amount) / max_hp
	if f < HEAVY_PCT:
		return 0.0
	return clampf(MIN_STRENGTH + (1.0 - MIN_STRENGTH) * (f - HEAVY_PCT) / (FULL_PCT - HEAVY_PCT), MIN_STRENGTH, 1.0)

## Chefe com postura: não encolhe no clarão de cada golpe (EntityView lê).
static func poised(e: SimEntity) -> bool:
	return e != null and e.monster_def != null and e.monster_def.is_boss
