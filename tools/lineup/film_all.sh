#!/usr/bin/env bash
# Filma TODOS os clipes ([filtro] = regex no nome do png) (revisão de animação em laço): personagem (de lado e de frente, classe com a arma do clipe)
# e monstros/formas (um modelo por tipo de rig). Uso: tools/lineup/film_all.sh <pasta> [char|mob|all] [filtro]
#   GODOT=<exe> para outro binário. Saída: <pasta>/<clipe>_<classe>_side.png, _front.png, mob_<modelo>_<clipe>.png
OUT="${1:?pasta}"
WHAT="${2:-all}"
FILTER="${3:-}"
GODOT="${GODOT:-C:/Users/luisf/Desktop/Godot_v4.7.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$OUT"

# clipe:classe[:build]
CHAR_CLIPS="idle:paladin idle:bishop idle_bow:ranger idle_staff:elementalist run:paladin run:ranger block:berserker block_shield:paladin
jump:paladin fall:paladin land:paladin dash:assassin hit:paladin die:paladin die:bishop
atk_1h_a:paladin atk_1h_b:paladin atk_2h:paladin:cruzado atk_dual_a:assassin:laminas atk_dual_b:assassin:laminas atk_dagger:assassin atk_thrust:assassin
atk_bow:ranger atk_shoot_multi:ranger atk_rifle:ranger:atirador atk_staff:elementalist atk_spin:berserker atk_leap:berserker:executor atk_charge:paladin
atk_throw:assassin atk_sweep:berserker:executor atk_finisher:berserker atk_flurry:assassin:laminas atk_claw:druid:fera shout:berserker
cast:elementalist cast_buff:bishop cast_ground:elementalist cast_channel:elementalist cast_target:necromancer summon:necromancer
cast_fire:elementalist cast_ice:elementalist cast_bolt:elementalist cast_holy:bishop cast_shadow:necromancer cast_nature:druid
buff_power:berserker buff_guard:paladin buff_focus:ranger"

MOB_MODELS="mob_bandit mob_elf_bowman mob_lich mob_skeleton mob_wolf mob_boar mob_rot_bear mob_dragon mob_griffin mob_lynx mob_horse mob_slime mob_spider mob_crab mob_ghost mob_ent mob_trent mob_elemental_fire mob_golem mob_golem_ancient mob_larva mob_bat form_wolf form_bear form_demon"
MOB_CLIPS="idle run attack cast hit die"
FORM_CLIPS="maul pounce slam roar brace"

shot() {
	local png="$1"; shift
	if [ -n "$FILTER" ] && ! [[ "$(basename "$png")" =~ $FILTER ]]; then return; fi
	timeout 120 "$GODOT" --path "$ROOT" tools/lineup/lineup.tscn -- --shot="$png" "$@" </dev/null >/dev/null 2>&1
	echo "$(basename "$png")"
}

if [ "$WHAT" = "char" ] || [ "$WHAT" = "all" ]; then
	for spec in $CHAR_CLIPS; do
		IFS=: read -r clip cls build <<< "$spec"
		extra=()
		[ -n "$build" ] && extra=(--set="$build" --level=30)
		tag="${clip}_${cls}"
		shot "$OUT/${tag}_side.png" --strip="$cls" --anim="$clip" --crop=0.32,0.62 "${extra[@]}"
		shot "$OUT/${tag}_front.png" --strip="$cls" --anim="$clip" --front --crop=0.32,0.62 "${extra[@]}"
	done
fi
if [ "$WHAT" = "mob" ] || [ "$WHAT" = "all" ]; then
	for m in $MOB_MODELS; do
		clips="$MOB_CLIPS"
		[[ "$m" == form_wolf || "$m" == form_bear ]] && clips="$MOB_CLIPS $FORM_CLIPS"
		for c in $clips; do
			shot "$OUT/mob_${m}_${c}.png" --mob_strip="$m" --anim="$c" --crop=0.2,0.75
		done
	done
fi
