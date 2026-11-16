#!/usr/bin/env bash
# Filme do arco de golpe em várias câmeras: um processo do Godot por câmera, um depois do outro (o 2º passe no mesmo
# processo herdava o lince, números e restos de efeito). Mesmos argumentos do tools/lineup/arc_film.tscn; --cams=9,24.
#   tools/lineup/arc_film.sh --class=paladin --build=cruzado --main=sword2h --skill=basic --cams=9,24 --out=<pasta>
#   GODOT=<exe> para outro binário; ARC_ROOT=<projeto> / ARC_SCENE=<tscn> para rodar de fora. Log de cada câmera: <out>/arc_film_cam<C>.log
ROOT="${ARC_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
GODOT="${GODOT:-C:/Users/luisf/Desktop/Godot_v4.7.2-stable_win64_console.exe}"
SCENE="${ARC_SCENE:-tools/lineup/arc_film.tscn}"
CAMS="24"; OUT=""; ARGS=()
for a in "$@"; do
	case "$a" in
		--cams=*) CAMS="${a#--cams=}" ;;
		*) [[ "$a" == --out=* ]] && OUT="${a#--out=}"; ARGS+=("$a") ;;
	esac
done
[ -n "$OUT" ] || { echo "arc_film: --out=<pasta> obrigatório" >&2; exit 2; }
mkdir -p "$OUT"
RC=0
for C in ${CAMS//,/ }; do
	LOG="$OUT/arc_film_cam$C.log"
	timeout 300 "$GODOT" --path "$ROOT" --position -4000,-4000 --audio-driver Dummy --fixed-fps 60 "$SCENE" -- "${ARGS[@]}" --cams="$C" </dev/null >"$LOG" 2>&1 || RC=1
	grep -hE "ARC_FILM|SCRIPT ERROR|SHOWCASE (OK|FAIL)" "$LOG"
done
exit $RC
