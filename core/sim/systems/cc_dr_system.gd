class_name CcDrSystem
extends RefCounted
## Retorno decrescente de controle nos MONSTROS (C7, production/combat-plan-2026-11-23.md; decisão do usuário 2026-11-23).
## Por categoria (slow / root / stun): a 1ª aplicação vale cheia, a 2ª dentro de Balance.CC_DR_WINDOW s da anterior
## vale Balance.CC_DR_MULTS[1] (50%), a 3ª CC_DR_MULTS[2] (25%), e depois o monstro fica imune àquela categoria por
## CC_DR_WINDOW s (tentar durante a imunidade não estende). Sem aplicar por CC_DR_WINDOW s, zera.
## Personagens (jogador, bots) não têm retorno decrescente. O 40% do chefe (`MonsterDef.resists_cc`) continua e multiplica.
## Só o controle de skill que passa por WorldSim._apply_effects conta; lentidão de gelo e de pulso de canal não (slow_exempt); chão que renova a cada pulso (zonas, miasma,
## tempestade) e a lentidão de golpe de equipamento (hit_slow) ficam de fora: são "enquanto está dentro", não aplicações.
## Estado: `SimEntity.cc_dr` = categoria -> [aplicações, sim.time em que a janela/imunidade acaba] (fora do save).

const CATEGORIES := ["slow", "root", "stun"]
static var enabled := true                   # só sondas (boss_probe --no_cc_dr) desligam, para comparar

## Multiplicador de duração desta aplicação (0 = imune) e conta a aplicação. Personagem/NPC: sempre 1.
static func apply(sim: WorldSim, t: SimEntity, category: String) -> float:
	if t.kind != SimEntity.Kind.MONSTER or not enabled:
		return 1.0
	var now: float = sim.time
	var st: Array = t.cc_dr.get(category, [0, 0.0])
	var n: int = int(st[0])
	if now >= float(st[1]):
		n = 0                                  # janela (ou imunidade) acabou: recomeça cheio
	var mults: Array = Balance.CC_DR_MULTS
	if n >= mults.size():
		return 0.0                             # imune até st[1]
	var mult: float = float(mults[n])
	n += 1
	t.cc_dr[category] = [n, now + Balance.CC_DR_WINDOW]     # a 3ª abre a imunidade de CC_DR_WINDOW s
	return mult

## Lentidão fora do retorno decrescente (decisão do usuário 2026-11-23): a de gelo (`slow.frost`, marcada em
## GameData.load_all pelo elemento/tema) e a dos pulsos de canal (skill com `channel` em fase ativa: Mente Açoitada...).
static func slow_exempt(src: SimEntity, slow: Dictionary) -> bool:
	if bool(slow.get("frost", false)):
		return true
	return src != null and src.current_skill != null and src.skill_phase == "active" and src.current_skill.effects.has("channel")

## Só lê (sem contar): quanto a próxima aplicação valeria agora. Ficha/IA/testes.
static func peek(sim: WorldSim, t: SimEntity, category: String) -> float:
	if t.kind != SimEntity.Kind.MONSTER:
		return 1.0
	var st: Array = t.cc_dr.get(category, [0, 0.0])
	var n: int = 0 if sim.time >= float(st[1]) else int(st[0])
	var mults: Array = Balance.CC_DR_MULTS
	return 0.0 if n >= mults.size() else float(mults[n])
