extends Node
## EventBus global. A simulação emite, a apresentação escuta.
## Nenhum sinal carrega nós — só ids e dados simples.

signal entity_spawned(entity)            # SimEntity
signal entity_despawned(entity_id: int)
signal entity_changed_map(entity_id: int, map_id: String)
signal damage_dealt(attacker_id: int, target_id: int, amount: int, crit: bool, blocked: bool, kind: String)
signal healed(source_id: int, target_id: int, amount: int)
signal entity_died(entity_id: int, killer_id: int)
signal entity_respawned(entity_id: int)
signal skill_cast(entity_id: int, skill_id: String, phase: String) # "startup" | "active" | "recovery"
signal skill_effect(skill_id: String, origin: Vector3, aim: Vector3, radius: float)
signal projectile_spawned(projectile)      # SimProjectile
signal projectile_removed(projectile_id: int)
signal hit_stop(frames: int)
signal xp_gained(entity_id: int, amount: int)
signal level_up(entity_id: int, new_level: int)
signal item_gained(entity_id: int, item_id: String, count: int)
signal item_removed(entity_id: int, item_id: String, count: int)
signal loot_dropped(map_id: String, position: Vector3, item_id: String, count: int)
signal equipment_changed(entity_id: int)
signal quest_accepted(entity_id: int, quest_id: String)
signal quest_progress(entity_id: int, quest_id: String, current: int, needed: int)
signal quest_completed(entity_id: int, quest_id: String)
signal quest_abandoned(entity_id: int, quest_id: String)
signal crafted(entity_id: int, item_id: String, count: int)
signal mastery_changed(entity_id: int, skill_id: String, level: int)
signal chat_message(sender_name: String, text: String, channel: String)
signal notification(text: String)          # texto de sistema (ex.: "Nível 5!")
signal dialog_requested(npc_id: String)
signal potion_used(entity_id: int, slot: int)
signal blocked_hit(target_id: int)
signal guard_flanked(target_id: int)        # golpe por fora do arco enquanto segurava a guarda
signal shield_block(target_id: int, attacker_id: int, theme: String, parried: bool, from: Vector3)     # from = origem do golpe
signal buff_applied(entity_id: int, buff_id: String, duration: float)
signal trap_placed(trap_id: int, kind: String, pos: Vector3, radius: float, map_id: String)     # armadilha no chão (Ranger)
signal trap_removed(trap_id: int, triggered: bool)
signal dodged(entity_id: int)
signal monster_emerged(map_id: String, position: Vector3)
signal gathered(map_id: String, node_index: int, entity_id: int)     # ponto de colheita esvaziou (volta depois)   # chefe saiu da água (respingo no lugar)
signal mount_changed(entity_id: int, mounted: bool)   # montou/desmontou (H, golpe ou dano)                # esquivou um golpe (Assassino)
signal party_invited(from_id: int, to_id: int)
signal party_changed(party_id: int)         # entrou/saiu/líder mudou/desfez (id do grupo afetado)
