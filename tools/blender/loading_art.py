"""Arte da tela de carregamento: uma foto de apresentação por zona, tirada do modelo real do mapa.

    blender -b --factory-startup --python tools/blender/loading_art.py -- [--only=a,b] [--scale=0.5] [--out=<pasta>]
                                                                          [--top] [--sheet] [--no_render] [--samples=N]

Para cada zona de `ZONES`: cena vazia, importa `assets/models/map_<zona>.glb`, põe o chão e as props do
`data/zones/<zona>.json` (árvores, casas, pedras: no jogo quem faz isso é o `MapBuilder`), troca os materiais por um
toon simples (3 tons + névoa de distância no próprio shader; `glow_*` emite), acende um sol pelo clima da zona, mira a
câmera pelo preset e grava `assets/ui/loading/<zona>.jpg` (1600x900, qualidade 88). Não salva .blend.

    --top     foto ortográfica de cima (conferir layout/coordenadas) em vez da foto final
    --sheet   monta a folha de contato `production/qa/evidence/start-flow/loading_sheet.png` com os .jpg que existem
    --scale   fração da resolução (prévia rápida)

Coordenadas dos presets: as do Blender (x, y) = jogo (x, -z). `az` = de onde a câmera olha (0 = do sul para o norte,
90 = do leste para o oeste), `elev` = altura da câmera vista do alvo, `pitch` = quanto ela inclina para baixo (menor
que `elev`: o alvo desce no quadro e uma faixa de céu aparece em cima), `fov` = vertical em graus.
Cores escritas em sRGB (como no `maps_catalog.gd`); `GROUND` espelha `ground_color` de lá.

Masmorras (clima `dungeon`): foto "de herói", câmera baixa dentro do salão do chefe olhando ao longo dele. O toon passa
a ler as luzes da cena (`lit`): poças quentes nos lampiões/caldeirões/brasas (`hall_lights`: props do JSON e peças
`glow_*` do GLB), um facho de cima na cor do `ambient` da masmorra sobre a arena (`shaft`), contraluz na borda das
peças (`rim`) e névoa volumétrica (`make_haze`). `hall` no preset: `focus` (x, y) = centro da arena, `lamps` = lampiões
a mais (a prop `lamp` do jogo), `lights` = luzes soltas, `shaft`/`haze`/`fill` = ajustes.

Chefe na foto (`boss` no preset, ver `BOSSES` e `place_boss`): o `mob_<modelo>.glb` do chefe da masmorra, num quadro de
um clipe dele, no tamanho do jogo (`MonsterDef.scale` direto no modelo, como o `EntityView`), no ponto do spawner do
JSON (ou `at`), virado para a câmera em 3/4 (`turn`), com o mesmo toon das props (emissão forte = brilho, como
`EntityView.mob_glow`; modelo emprestado puxa para a cor do monstro, como `EntityView.monster_tint`), uma luz de
ribalta baixa na frente e um contraluz por cima.
"""
import bpy
import colorsys
import json
import math
import os
import sys
import zlib

import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MODELS = os.path.join(ROOT, "assets", "models")
ZDATA = os.path.join(ROOT, "data", "zones")
OUT_DIR = os.path.join(ROOT, "assets", "ui", "loading")
SHEET = os.path.join(ROOT, "production", "qa", "evidence", "start-flow", "loading_sheet.png")
W, H, QUALITY = 1600, 900, 88

# ---------------------------------------------------------------------------------------------------------------------
# Clima: sol (direção relativa à câmera), 3 tons do toon, céu e névoa. Cores em sRGB.
MOODS = {
    "day":     {"sun_rel": -55, "sun_el": 44, "light": (1.06, 1.0, 0.9), "shadow": (0.56, 0.56, 0.78), "top": (0.36, 0.56, 0.88),
                "hor": (0.86, 0.9, 0.94), "fog": 0.0026, "fog_start": 70, "fog_max": 1.0, "calm": (0.2, 0.26, 0.34)},
    "forest":  {"sun_rel": -60, "sun_el": 46, "light": (1.02, 1.0, 0.86), "shadow": (0.46, 0.56, 0.7), "top": (0.34, 0.56, 0.74),
                "hor": (0.78, 0.9, 0.86), "fog": 0.0032, "fog_start": 60, "fog_max": 1.0, "calm": (0.14, 0.24, 0.24)},
    "elf":     {"sun_rel": -50, "sun_el": 48, "light": (1.04, 1.04, 0.9), "shadow": (0.5, 0.62, 0.76), "top": (0.38, 0.62, 0.82),
                "hor": (0.84, 0.95, 0.9), "fog": 0.0029, "fog_start": 70, "fog_max": 1.0, "calm": (0.16, 0.28, 0.3)},
    "dawn":    {"sun_rel": -65, "sun_el": 34, "light": (1.08, 0.96, 0.8), "shadow": (0.56, 0.52, 0.76), "top": (0.46, 0.52, 0.8),
                "hor": (0.96, 0.84, 0.74), "fog": 0.0030, "fog_start": 60, "fog_max": 1.0, "calm": (0.26, 0.22, 0.34), "low": 0.36},
    "coast":   {"sun_rel": -50, "sun_el": 52, "light": (1.1, 1.06, 0.96), "shadow": (0.6, 0.66, 0.86), "top": (0.3, 0.6, 0.94),
                "hor": (0.86, 0.95, 1.0), "fog": 0.0021, "fog_start": 90, "fog_max": 1.0, "calm": (0.16, 0.32, 0.44)},
    "steppe":  {"sun_rel": -60, "sun_el": 36, "light": (1.1, 1.0, 0.82), "shadow": (0.6, 0.5, 0.62), "top": (0.5, 0.62, 0.84),
                "hor": (0.98, 0.88, 0.7), "fog": 0.0027, "fog_start": 70, "fog_max": 1.0, "calm": (0.34, 0.24, 0.2), "low": 0.38},
    "ash":     {"sun_rel": -70, "sun_el": 30, "light": (1.14, 0.86, 0.7), "shadow": (0.5, 0.36, 0.48), "top": (0.34, 0.24, 0.32),
                "hor": (0.9, 0.58, 0.44), "fog": 0.0036, "fog_start": 50, "fog_max": 1.0, "calm": (0.16, 0.09, 0.11), "low": 0.34,
                "glow": 3.2},
    "ember":   {"sun_rel": -75, "sun_el": 30, "light": (1.12, 0.84, 0.66), "shadow": (0.46, 0.32, 0.42), "top": (0.14, 0.09, 0.14),
                "hor": (0.36, 0.13, 0.11), "fog": 0.0120, "fog_start": 36, "fog_max": 1.0, "calm": (0.1, 0.05, 0.07), "low": 0.34,
                "glow": 3.4},
    "moody":   {"sun_rel": -70, "sun_el": 34, "light": (0.86, 0.84, 1.0), "shadow": (0.36, 0.34, 0.6), "top": (0.16, 0.14, 0.32),
                "hor": (0.52, 0.48, 0.72), "fog": 0.0041, "fog_start": 46, "fog_max": 1.0, "calm": (0.1, 0.09, 0.2), "low": 0.38,
                "glow": 3.0},
    # Fortaleza dos Ossos: crepúsculo (sol baixo e quente de lado, sombra índigo), o abismo e os olhos das caveiras
    # brilham verde-espectral (`glow_mats` do preset)
    "bone":    {"sun_rel": -95, "sun_el": 17, "light": (1.16, 0.86, 0.68), "shadow": (0.36, 0.36, 0.62), "top": (0.12, 0.11, 0.27),
                "hor": (0.96, 0.6, 0.5), "fog": 0.0036, "fog_start": 46, "fog_max": 1.0, "calm": (0.1, 0.09, 0.19), "low": 0.36,
                "glow": 3.2, "sun_glow": 0.9},
    "bile":    {"sun_rel": -65, "sun_el": 36, "light": (0.98, 0.98, 0.78), "shadow": (0.4, 0.46, 0.44), "top": (0.3, 0.36, 0.34),
                "hor": (0.74, 0.8, 0.66), "fog": 0.0040, "fog_start": 46, "fog_max": 1.0, "calm": (0.13, 0.16, 0.1), "low": 0.38,
                "glow": 2.6},
    "frost":   {"sun_rel": -55, "sun_el": 36, "light": (1.0, 1.04, 1.1), "shadow": (0.56, 0.66, 0.9), "top": (0.36, 0.52, 0.86),
                "hor": (0.86, 0.93, 1.0), "fog": 0.0035, "fog_start": 56, "fog_max": 1.0, "calm": (0.22, 0.32, 0.5), "low": 0.38,
                "glow": 2.6},
    # masmorra: foto de dentro do salão; quem ilumina são as luzes da cena (`lit`), a cor vem do `ambient` (build_zone)
    "dungeon": {"sun_rel": 155, "sun_el": 52, "light": (1.0, 1.0, 1.0), "shadow": (0.3, 0.3, 0.4), "top": (0.02, 0.02, 0.04),
                "hor": (0.1, 0.1, 0.16), "fog": 0.009, "fog_start": 18, "fog_max": 0.9, "calm": (0.03, 0.03, 0.06), "glow": 3.4,
                "lit": True, "sun_glow": 0.0, "sun_w": 0.11, "rim": 0.55, "haze": 0.011},
}

TORCH = (1.0, 0.6, 0.26)            # luz de lampião/braseiro (sRGB)

# conquista/estágio: peças do GLB que só aparecem DEPOIS de uma quest (o "if" dos *_CONQUEST_VIS) ficam fora da foto.
# Exceção de propósito: o farol da Costa e o farolete do Porto saem acesos (a foto é a promessa da zona).
HORDE_FORT_HIDE = ["estandarte_aurora", "tenda_ghar_aurora"]
STEPPE_HIDE = ["estandarte_aurora_", "limpo_", "torre_aurora_", "passo_aberto"]
KHARZUN_HIDE = ["k1_minas_aurora", "k1_jaula_aberta", "k1_torre", "k1_anoes", "k1_libertos", "k1b_canil_aurora",
                "k1c_forja_aurora", "k2_portao_aurora", "k2_portao_aberto", "k2_cerco", "k4_festa"]

def ring_lamps(c, r, w=0.45, n=8, phase=22.5, skip=()):
    """Lampiões (prop `lamp` do jogo, só na foto) ao pé dos pilares do salão: (x, y, força) num anel de raio `r`.
    `skip` = os que ficariam colados na câmera (0 = leste-nordeste, anti-horário; 5 e 6 = os dois do sul)."""
    return [(round(c[0] + math.cos(math.radians(phase + 360.0 / n * i)) * r, 2),
             round(c[1] + math.sin(math.radians(phase + 360.0 / n * i)) * r, 2), w) for i in range(n) if i not in skip]


# Chefes (monsters_catalog.gd): modelo, `scale` do MonsterDef e, quando o modelo é emprestado de outro monstro, a cor
# dele e a do dono do modelo (`tint`: EntityView.monster_tint). Espelho dos dados; mudou lá, mude aqui.
BOSSES = {
    "boss_durgash": {"model": "mob_durgash", "scale": 2.1},
    "slime_king": {"model": "mob_slime", "scale": 2.0, "tint": ((0.3, 0.5, 0.95), (0.45, 0.9, 0.5))},
    "wailing_widow": {"model": "mob_ghost", "scale": 1.6, "tint": ((0.7, 0.8, 1.0), (0.6, 0.9, 1.0))},
    "count_vargo": {"model": "mob_lich", "scale": 1.8},
    "crystal_warden": {"model": "mob_crystal_warden", "scale": 1.5},
    "quarry_heart": {"model": "mob_quarry_heart", "scale": 1.9},
    "spider_queen": {"model": "mob_spider", "scale": 1.9, "tint": ((0.45, 0.2, 0.55), (0.25, 0.2, 0.3))},
    "elf_king": {"model": "mob_elf_king", "scale": 1.6},
    "crypt_lord": {"model": "mob_skeleton", "scale": 1.8, "tint": ((0.6, 0.45, 0.85), (0.9, 0.9, 0.8))},
    "boss_agitator_lord": {"model": "mob_agitator_lord", "scale": 1.7},
    "boss_shazka": {"model": "mob_shazka", "scale": 1.5},
}

# id -> nome (MapDef.name), chão (ground_color), clima, câmera. `boss` (masmorras) = chefe na foto: `id` (BOSSES),
# `clip`/`frame` = pose, `at` = (x, y) do Blender (sem ele: o spawner do JSON), `fwd` = passos até a câmera, `turn` = 3/4 (graus a partir de "de
# frente para a câmera"), `foot`/`back` = força da ribalta e do contraluz, `foot_col`/`back_col` = cor delas (sem: a da masmorra;
# cor diferente da do salão é o que separa o chefe do fundo), `lift` = altura do pé (em cima de um degrau),
# `no_glow` = as luzes das peças `glow_*` do salão não pegam nele (poça que lavava o chefe na cor dela). `at` = (x, y) do Blender, "town" (centro do JSON) ou
# "obj:<trecho do nome>" (centro das peças do GLB); `az` = número ou "spawn" (olha de onde o jogador chega) + `az_off`.
ZONES = {
    "city_aldara": {"name": "Vale de Aldara", "ground": (0.48, 0.68, 0.38), "mood": "day",
                    "cam": {"at": (10, 12), "az": -45, "dist": 128, "elev": 25, "pitch": 17, "fov": 50}},
    "field_forest": {"name": "Floresta Sombria", "ground": (0.36, 0.52, 0.34), "mood": "forest",
                     "cam": {"at": (-5, 8), "az": -8, "dist": 122, "elev": 25, "pitch": 17, "fov": 50}},
    "elf_city": {"name": "Cidade Élfica", "ground": (0.42, 0.6, 0.44), "mood": "elf",
                 "cam": {"at": (0, 0), "az": 18, "dist": 155, "elev": 24, "pitch": 13, "fov": 50}},
    "field_ruins": {"name": "Bastião da Aurora", "ground": (0.55, 0.56, 0.46), "mood": "dawn", "hide": ["limpo_"],
                    "cam": {"at": (0, 0), "az": -35, "dist": 125, "elev": 25, "pitch": 17, "fov": 50}},
    "fort_ghoul": {"name": "Covil do Carniçal", "ground": (0.4, 0.38, 0.24), "mood": "bile",
                   "cam": {"at": "town", "az": "spawn", "dist": 98, "elev": 26, "pitch": 18, "fov": 50}},
    "fort_bones": {"name": "Fortaleza dos Ossos", "ground": (0.56, 0.54, 0.5), "mood": "bone",
                   "glow_mats": {"chasm": ((0.1, 0.44, 0.4), 0.45, 1.0), "socket": ((0.45, 1.0, 0.75), 1.0, 1.0),
                                 "candle": ((0.6, 1.0, 0.8), 1.0, 0.0), "bone": ((0.78, 1.0, 0.86), 0.6, 0.0)},
                   "cam": {"at": (0, 14), "h": 4.0, "az": 10, "dist": 95, "elev": 14, "pitch": 14, "fov": 42}},
    "fort_frost": {"name": "Torre do Mago Gélido", "ground": (0.74, 0.82, 0.9), "mood": "frost",
                   "cam": {"at": "town", "az": "spawn", "dist": 98, "elev": 26, "pitch": 18, "fov": 50}},
    "lich_citadel": {"name": "Cidadela do Lich", "ground": (0.32, 0.28, 0.36), "mood": "moody",
                     "cam": {"at": "town", "az": "spawn", "dist": 98, "elev": 26, "pitch": 18, "fov": 50}},
    "city_port": {"name": "Porto Esperança", "ground": (0.62, 0.62, 0.44), "mood": "coast", "sea": True,
                  "hide": ["_pronta_", "casa_nova", "farolete_apagado"],      # C0 do Cerco Vivo: trechos em obra, casas queimadas
                  "cam": {"at": (0, -22), "az": 160, "dist": 125, "elev": 25, "pitch": 16, "fov": 50}},
    "field_coast": {"name": "Costa Partida", "ground": (0.64, 0.66, 0.46), "mood": "coast", "sea": True,
                    "hide": ["farol_apagado", "passo_estepes_aberto"], "water_tints": {"water_dark": (0.22, 0.38, 0.36)},
                    "cam": {"at": (56, -72), "az": 140, "dist": 112, "elev": 25, "pitch": 16, "fov": 50}},
    "field_steppe": {"name": "Estepes de Cinza", "ground": (0.74, 0.62, 0.34), "mood": "steppe", "hide": STEPPE_HIDE,
                     "cam": {"at": (8, 16), "az": -28, "dist": 128, "elev": 25, "pitch": 16, "fov": 50}},
    "fort_trolls": {"name": "Toca do Rei-da-Rocha", "ground": (0.6, 0.55, 0.46), "mood": "steppe", "hide": HORDE_FORT_HIDE,
                    "cam": {"at": "town", "az": "spawn", "dist": 98, "elev": 26, "pitch": 18, "fov": 50}},
    "fort_fire": {"name": "Paliçada das Flechas de Fogo", "ground": (0.44, 0.39, 0.34), "mood": "ash", "hide": HORDE_FORT_HIDE,
                  "cam": {"at": "town", "az": "spawn", "dist": 98, "elev": 26, "pitch": 18, "fov": 50}},
    "fort_war": {"name": "Arraial de Ghar", "ground": (0.66, 0.52, 0.36), "mood": "steppe", "hide": HORDE_FORT_HIDE,
                 "cam": {"at": "town", "az": "spawn", "dist": 98, "elev": 26, "pitch": 18, "fov": 50}},
    "field_kharzun": {"name": "Monte Kharzun", "ground": (0.38, 0.31, 0.31), "mood": "ash", "hide": KHARZUN_HIDE,
                      "water_tints": {"glow_lava": (1.0, 0.38, 0.1)},
                      "cam": {"at": (0, 62), "az": 0, "dist": 150, "elev": 24, "pitch": 11, "fov": 50}},
    # masmorras: câmera baixa dentro do salão do chefe (ver `hall_lights`); `ambient` = o do MapDef (cor de destaque)
    "kharzun_citadel": {"name": "Cidadela de Kharzun", "ground": (0.3, 0.27, 0.29), "mood": "dungeon", "ambient": (0.98, 0.62, 0.48),
                        "hide": ["trono_aberto", "cla_lobo_caido", "cla_pedra_caido", "cla_forja_caido"],
                        "hall": {"focus": (0, 68), "shaft": {"back": 3, "h": 22, "w": 7000}},
                        # Durgash em pé no alto dos degraus, à frente e à esquerda do trono (fora do eixo dele), câmera mais
                        # perto e um pouco de lado; ribalta e contraluz de fogo claro recortam a silhueta contra o salão
                        "boss": {"id": "boss_durgash", "clip": "shout", "frame": 12, "at": (-1.9, 66.3), "lift": 0.9, "turn": -24,
                                 "foot": 2.0, "foot_col": (1.0, 0.84, 0.58), "back": 2.0, "back_col": (1.0, 0.8, 0.5)},
                        "cam": {"at": (-0.3, 67.5), "h": 2.6, "az": 30, "dist": 17, "elev": 8, "pitch": 5, "fov": 44}},
    "dg_gruta": {"name": "Gruta Gotejante", "ground": (0.3, 0.34, 0.36), "mood": "dungeon", "ambient": (0.6, 0.72, 0.85),
                 "hall": {"focus": (10, 58), "lamps": ring_lamps((10, 50), 13.2, skip=(6, 7)) + [(7, 58, 1.0), (13, 58, 1.0)]},
                 "boss": {"id": "slime_king", "clip": "roar", "frame": 10, "fwd": 2.0, "turn": -26},
                 "cam": {"at": (10, 54), "h": 1.5, "az": 38, "dist": 24, "elev": 10, "pitch": 8, "fov": 40}},
    "dg_catacumbas": {"name": "Catacumbas do Conde", "ground": (0.28, 0.27, 0.3), "mood": "dungeon", "ambient": (0.62, 0.6, 0.78),
                      "hall": {"focus": (30, 56.8), "lamps": ring_lamps((30, 45), 13.2, skip=(4, 5)) + [(27, 56.8, 1.0), (33, 56.8, 1.0)]},
                      "boss": {"id": "wailing_widow", "clip": "roar", "frame": 15, "fwd": 2.0, "turn": 26},
                      "cam": {"at": (30, 49.5), "h": 1.5, "az": -38, "dist": 24, "elev": 10, "pitch": 8, "fov": 40}},
    "dg_catacumbas_trono": {"name": "Trono do Conde", "ground": (0.26, 0.22, 0.3), "mood": "dungeon", "ambient": (0.68, 0.5, 0.8),
                            "hall": {"focus": (0, 41.8), "lamps": ring_lamps((0, 25), 18.2, skip=(5, 6)) + [(-3, 41.8, 1.0), (3, 41.8, 1.0)]},
                            "boss": {"id": "count_vargo", "clip": "buff_focus", "frame": 10, "at": (0, 29), "turn": 24, "foot": 0.6},
                            "cam": {"at": (0, 36), "h": 1.5, "az": 0, "dist": 27, "elev": 10, "pitch": 8, "fov": 44}},
    "dg_pedreira": {"name": "Pedreira dos Golens", "ground": (0.42, 0.36, 0.28), "mood": "dungeon", "ambient": (0.82, 0.78, 0.72),
                    "hall": {"focus": (32.5, 56.8), "lamps": ring_lamps((32.5, 45), 13.2, skip=(6, 7)) + [(29.5, 56.8, 1.0), (35.5, 56.8, 1.0)]},
                    "boss": {"id": "crystal_warden", "clip": "roar", "frame": 10, "fwd": 2.0, "turn": -26},
                    "cam": {"at": (32.5, 49.5), "h": 1.5, "az": 38, "dist": 24, "elev": 10, "pitch": 8, "fov": 40}},
    # Coração da Pedreira: o chefe (o próprio veio, `mob_quarry_heart`) fica no meio da arena; carrinho de mina e entulho
    # na frente (`extras`, só na foto), e a câmera baixa olhando para ele.
    "dg_pedreira_coracao": {"name": "Coração da Pedreira", "ground": (0.4, 0.3, 0.24), "mood": "dungeon", "ambient": (0.9, 0.7, 0.6),
                            "prop_colors": {"p_crystal": (0.96, 0.52, 0.18), "p_crystal_d": (0.78, 0.26, 0.08)},
                            "boss": {"id": "quarry_heart", "clip": "roar", "frame": 10, "at": (0, 31.0), "turn": -22,
                                     "foot": 1.4, "foot_col": (1.0, 0.55, 0.22)},
                            "extras": [
                                {"kind": "rock", "pos": (-1.8, 27.6), "size": [1.6, 0.8, 1.4], "color": [0.5, 0.36, 0.28]},
                                {"kind": "rock", "pos": (3.6, 28.2), "size": [1.3, 0.6, 1.2], "color": [0.5, 0.36, 0.28]},
                                {"kind": "rock", "pos": (-3.8, 32.4), "size": [1.4, 0.9, 1.3], "color": [0.46, 0.34, 0.26]},
                                {"kind": "cart", "pos": (-4.8, 26.0), "size": [1.4, 1.9, 2.4], "rot": 115},
                                {"kind": "rock", "pos": (-2.6, 24.6), "size": [1.6, 0.9, 1.4], "color": [0.46, 0.34, 0.26]},
                                {"kind": "rock", "pos": (3.6, 23.4), "size": [2.2, 1.1, 1.8], "color": [0.4, 0.3, 0.24]},
                                {"kind": "rock", "pos": (0.8, 24.2), "size": [1.0, 0.5, 0.9], "color": [0.5, 0.36, 0.28]},
                            ],
                            "hall": {"focus": (0, 31.0), "fill": 0.3, "glow": 2.5, "shaft": {"back": 2.0, "h": 20, "w": 9000, "angle": 26},
                                     "lamps": ring_lamps((0, 25), 18.2, skip=(5, 6, 7)) + [(-3, 41.8, 1.0), (3, 41.8, 1.0)]},
                            "cam": {"at": (0, 31), "h": 2.4, "az": 24, "dist": 15, "elev": 8, "pitch": 4, "fov": 46}},
    "dg_ninho": {"name": "Ninho Profundo", "ground": (0.26, 0.3, 0.24), "mood": "dungeon", "ambient": (0.6, 0.78, 0.62),
                 "hall": {"focus": (-10, 58), "lamps": ring_lamps((-10, 50), 13.2, skip=(4, 5)) + [(-13, 58, 1.0), (-7, 58, 1.0)]},
                 # luz violeta na rainha: sob o facho verde do salão o roxo dela virava cinza
                 "boss": {"id": "spider_queen", "clip": "roar", "frame": 5, "fwd": 2.0, "turn": 32, "foot": 1.2,
                          "foot_col": (0.82, 0.5, 1.0), "back": 1.0, "back_col": (0.78, 0.45, 1.0)},
                 "cam": {"at": (-10, 54), "h": 1.5, "az": -38, "dist": 24, "elev": 10, "pitch": 8, "fov": 40}},
    "dg_coracao": {"name": "Coração da Árvore", "ground": (0.4, 0.34, 0.26), "mood": "dungeon", "ambient": (0.7, 0.92, 0.7),
                   "hall": {"focus": (7.5, 61), "glow": 2.3, "glow_w": 0.55},
                   # luz fria (azul-clara) no rei: separa do amarelo-esverdeado da poça
                   "boss": {"id": "elf_king", "clip": "buff_focus", "frame": 10, "at": (1.5, 46.5), "turn": 26, "foot": 2.2, "no_glow": True,
                            "foot_col": (0.72, 0.86, 1.0), "back": 2.4, "back_col": (0.6, 0.8, 1.0)},
                   "cam": {"at": (7.5, 52), "h": 1.5, "az": -20, "dist": 30, "elev": 10, "pitch": 8, "fov": 40}},
    "dg_cripta": {"name": "Cripta de Vel'Thar", "ground": (0.3, 0.28, 0.32), "mood": "dungeon", "ambient": (0.66, 0.58, 0.82),
                  "hall": {"focus": (10, 58), "lamps": ring_lamps((10, 50), 13.2, skip=(5, 6)) + [(7, 58, 1.0), (13, 58, 1.0)]},
                  "boss": {"id": "crypt_lord", "clip": "buff_focus", "frame": 10, "fwd": 2.5, "turn": -26, "foot": 0.6},
                  "cam": {"at": (10, 54), "h": 1.5, "az": 0, "dist": 27.5, "elev": 10, "pitch": 8, "fov": 40}},
    "dg_goblin": {"name": "Grutas Goblin", "ground": (0.34, 0.32, 0.24), "mood": "dungeon", "ambient": (0.85, 0.7, 0.6),
                  "hall": {"focus": (0, 62)},
                  "boss": {"id": "boss_agitator_lord", "clip": "shout", "frame": 12, "at": (4.5, 52), "turn": 30, "foot_col": TORCH},
                  "cam": {"at": (0, 56), "h": 1.5, "az": -10, "dist": 20, "elev": 12, "pitch": 9, "fov": 48}},
    "dg_slayers": {"name": "Salão dos Matadores", "ground": (0.26, 0.23, 0.29), "mood": "dungeon", "ambient": (0.74, 0.62, 0.9),
                   "hall": {"focus": (5, 64), "fill": 0.5},
                   "boss": {"id": "boss_shazka", "clip": "idle", "frame": 12, "turn": -26},
                   "cam": {"at": (5, 54), "h": 1.5, "az": 17, "dist": 25, "elev": 12, "pitch": 9, "fov": 42}},
}

# ---------------------------------------------------------------------------------------------------------------------
# cor

def lin1(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def lin(c):
    """sRGB (como o Color() do Godot) -> linear RGBA."""
    return (lin1(c[0]), lin1(c[1]), lin1(c[2]), 1.0)


def srgb1(v):
    v = max(0.0, v)
    return v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def lightened(c, t):
    return mix(c, (1, 1, 1), t)


def darkened(c, t):
    return tuple(v * (1 - t) for v in c[:3])


def accent(c, k=2.4):
    """Cor de destaque da masmorra: o `ambient` do mapa (pálido) com a saturação puxada e o canal mais forte em 1."""
    m = (c[0] + c[1] + c[2]) / 3.0
    v = [max(0.0, m + (x - m) * k) for x in c[:3]]
    top = max(v) or 1.0
    return tuple(x / top for x in v)


def saturation(c):
    mx, mn = max(c[:3]), min(c[:3])
    return 0.0 if mx <= 0 else (mx - mn) / mx


def dirt_color(g):
    """MapBuilder._dirt_color: terra das estradas tirada do chão."""
    if saturation(g) < 0.25:
        return mix(darkened(g, 0.12), (0.6, 0.54, 0.46), 0.45)
    return mix(g, (0.62, 0.5, 0.36), 0.7)


def stable_hash(*vals):
    return zlib.crc32(repr(vals).encode())


# ---------------------------------------------------------------------------------------------------------------------
# shader: grupo LA_Shade (toon de 3 tons + água + brilho + névoa de distância) e os materiais que o usam

def _mixrgb(nt, blend="MIX", fac=1.0):
    n = nt.nodes.new("ShaderNodeMix")
    n.data_type = "RGBA"
    n.blend_type = blend
    n.inputs[0].default_value = fac
    return n            # entradas 0 = fator, 6 = A, 7 = B; saída 2


def _math(nt, op, b=None):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    if b is not None:
        n.inputs[1].default_value = b
    return n


def make_shade_group(mood, dungeon_bg=None):
    g = bpy.data.node_groups.new("LA_Shade", "ShaderNodeTree")
    itf = g.interface
    itf.new_socket("Color", in_out="INPUT", socket_type="NodeSocketColor")
    for name in ("Glow", "Water", "Flat"):
        s = itf.new_socket(name, in_out="INPUT", socket_type="NodeSocketFloat")
        s.default_value = 0.0
    itf.new_socket("Shader", in_out="OUTPUT", socket_type="NodeSocketShader")
    N, L = g.nodes, g.links
    gin = N.new("NodeGroupInput")
    gout = N.new("NodeGroupOutput")
    # luz do sol -> 3 tons
    dif = N.new("ShaderNodeBsdfDiffuse")
    dif.inputs["Color"].default_value = (1, 1, 1, 1)
    s2r = N.new("ShaderNodeShaderToRGB")
    L.new(dif.outputs[0], s2r.inputs[0])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "LINEAR"
    el = ramp.color_ramp.elements
    lo = mood.get("low", 0.46)          # limiar do tom cheio (chão plano com sol baixo ainda fica "aceso")
    el[0].position, el[0].color = 0.07, (0, 0, 0, 1)
    el[1].position, el[1].color = 0.11, (0.5, 0.5, 0.5, 1)
    e = el.new(lo)
    e.color = (0.5, 0.5, 0.5, 1)
    e = el.new(lo + 0.04)
    e.color = (1, 1, 1, 1)
    L.new(s2r.outputs[0], ramp.inputs[0])
    tone_flat = _math(g, "MAXIMUM")     # Flat = 1: sem tons (chão pintado, água)
    L.new(ramp.outputs[0], tone_flat.inputs[0])
    L.new(gin.outputs["Flat"], tone_flat.inputs[1])
    tone = _mixrgb(g)
    tone.inputs[6].default_value = lin(mood["shadow"])
    tone.inputs[7].default_value = lin(mood["light"])
    L.new(tone_flat.outputs[0], tone.inputs[0])
    lit = _mixrgb(g, "MULTIPLY")
    L.new(gin.outputs["Color"], lit.inputs[6])
    L.new(tone.outputs[2], lit.inputs[7])
    band = None
    if mood.get("lit"):
        # masmorra: a luz é a das lâmpadas da cena, em faixas (poças de luz no chão), com a cor de cada uma
        bw = N.new("ShaderNodeRGBToBW")
        L.new(s2r.outputs[0], bw.inputs[0])
        r2 = N.new("ShaderNodeValToRGB")
        r2.color_ramp.interpolation = "LINEAR"
        e2 = r2.color_ramp.elements
        e2[0].position, e2[0].color = 0.0, (0, 0, 0, 1)
        e2[1].position, e2[1].color = 0.92, (1, 1, 1, 1)
        for pos, v in ((0.02, 0.0), (0.032, 0.15), (0.11, 0.15), (0.135, 0.38), (0.34, 0.38), (0.39, 0.7), (0.84, 0.7)):
            e = e2.new(pos)
            e.color = (v, v, v, 1)
        L.new(bw.outputs[0], r2.inputs[0])
        ov0 = _math(g, "SUBTRACT", 1.0)
        L.new(bw.outputs[0], ov0.inputs[0])
        ov1 = _math(g, "MAXIMUM", 0.0)
        L.new(ov0.outputs[0], ov1.inputs[0])
        ov2 = _math(g, "MULTIPLY", 0.4)
        L.new(ov1.outputs[0], ov2.inputs[0])
        band = _math(g, "ADD")
        L.new(r2.outputs[0], band.inputs[0])
        L.new(ov2.outputs[0], band.inputs[1])
        safe = _math(g, "MAXIMUM", 0.001)
        L.new(bw.outputs[0], safe.inputs[0])
        ratio = _math(g, "DIVIDE")
        L.new(band.outputs[0], ratio.inputs[0])
        L.new(safe.outputs[0], ratio.inputs[1])
        hue = N.new("ShaderNodeVectorMath")
        hue.operation = "SCALE"
        L.new(s2r.outputs[0], hue.inputs[0])
        L.new(ratio.outputs[0], hue.inputs["Scale"])
        tone2 = _mixrgb(g, "ADD")
        tone2.inputs[6].default_value = lin(mood["shadow"])
        L.new(hue.outputs[0], tone2.inputs[7])
        L.new(tone2.outputs[2], lit.inputs[7])
    # água: puxa o horizonte no ângulo rasante
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    wfac = _math(g, "MULTIPLY")
    L.new(lw.outputs["Facing"], wfac.inputs[0])
    L.new(gin.outputs["Water"], wfac.inputs[1])
    wfac2 = _math(g, "MULTIPLY", 0.6)
    L.new(wfac.outputs[0], wfac2.inputs[0])
    wat = _mixrgb(g)
    wat.inputs[7].default_value = lin(mix(mood["hor"], mood["top"], 0.25))
    L.new(wfac2.outputs[0], wat.inputs[0])
    L.new(lit.outputs[2], wat.inputs[6])
    # brilho: a própria cor, acima de 1 (o pós faz o halo)
    gk = _math(g, "MULTIPLY", mood.get("glow", 2.4))
    L.new(gin.outputs["Glow"], gk.inputs[0])
    gcol = _mixrgb(g, "MULTIPLY")
    L.new(gin.outputs["Color"], gcol.inputs[6])
    L.new(gk.outputs[0], gcol.inputs[7])
    gsel = _math(g, "MINIMUM", 1.0)
    L.new(gin.outputs["Glow"], gsel.inputs[0])
    glo = _mixrgb(g)
    L.new(gsel.outputs[0], glo.inputs[0])
    L.new(wat.outputs[2], glo.inputs[6])
    L.new(gcol.outputs[2], glo.inputs[7])
    # névoa de distância (o brilho fura metade dela)
    cam = N.new("ShaderNodeCameraData")
    d0 = _math(g, "SUBTRACT", mood["fog_start"])
    L.new(cam.outputs["View Distance"], d0.inputs[0])
    d1 = _math(g, "MAXIMUM", 0.0)
    L.new(d0.outputs[0], d1.inputs[0])
    d2 = _math(g, "MULTIPLY", -mood["fog"])
    L.new(d1.outputs[0], d2.inputs[0])
    ex = _math(g, "EXPONENT")
    L.new(d2.outputs[0], ex.inputs[0])
    f0 = _math(g, "SUBTRACT")
    f0.inputs[0].default_value = 1.0
    L.new(ex.outputs[0], f0.inputs[1])
    f1 = _math(g, "MINIMUM", mood["fog_max"])
    L.new(f0.outputs[0], f1.inputs[0])
    gh = _math(g, "MULTIPLY", -0.5)
    L.new(gsel.outputs[0], gh.inputs[0])
    gh2 = _math(g, "ADD", 1.0)
    L.new(gh.outputs[0], gh2.inputs[0])
    f2 = _math(g, "MULTIPLY")
    L.new(f1.outputs[0], f2.inputs[0])
    L.new(gh2.outputs[0], f2.inputs[1])
    fog = _mixrgb(g)
    fog.inputs[7].default_value = lin(dungeon_bg if dungeon_bg else mood["hor"])
    L.new(f2.outputs[0], fog.inputs[0])
    L.new(glo.outputs[2], fog.inputs[6])
    if band is not None and mood.get("rim", 0.0) > 0.0:
        # contraluz: borda das peças em pé (pilares, estátua, paredão) pega a cor da masmorra onde há luz
        lw2 = N.new("ShaderNodeLayerWeight")
        lw2.inputs["Blend"].default_value = 0.5
        edge = N.new("ShaderNodeMapRange")
        edge.interpolation_type = "SMOOTHSTEP"
        edge.inputs["From Min"].default_value = 0.6
        edge.inputs["From Max"].default_value = 0.9
        L.new(lw2.outputs["Facing"], edge.inputs["Value"])
        geo = N.new("ShaderNodeNewGeometry")
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Normal"], sep.inputs[0])
        az = _math(g, "ABSOLUTE")
        L.new(sep.outputs["Z"], az.inputs[0])
        wall = N.new("ShaderNodeMapRange")
        wall.interpolation_type = "SMOOTHSTEP"
        wall.inputs["From Min"].default_value = 0.45
        wall.inputs["From Max"].default_value = 0.75
        wall.inputs["To Min"].default_value = 1.0
        wall.inputs["To Max"].default_value = 0.0
        L.new(az.outputs[0], wall.inputs["Value"])
        b1 = _math(g, "MINIMUM", 1.0)
        L.new(band.outputs[0], b1.inputs[0])
        b2 = _math(g, "ADD", 0.12)
        L.new(b1.outputs[0], b2.inputs[0])
        r1 = _math(g, "MULTIPLY")
        L.new(edge.outputs["Result"], r1.inputs[0])
        L.new(wall.outputs["Result"], r1.inputs[1])
        r3 = _math(g, "MULTIPLY")
        L.new(r1.outputs[0], r3.inputs[0])
        L.new(b2.outputs[0], r3.inputs[1])
        r4 = _math(g, "MULTIPLY", mood["rim"])
        L.new(r3.outputs[0], r4.inputs[0])
        rim = _mixrgb(g, "ADD")
        L.new(r4.outputs[0], rim.inputs[0])
        L.new(glo.outputs[2], rim.inputs[6])
        rim.inputs[7].default_value = lin(mood.get("rim_col", mood["hor"]))
        L.new(rim.outputs[2], fog.inputs[6])
    em = N.new("ShaderNodeEmission")
    L.new(fog.outputs[2], em.inputs["Color"])
    L.new(em.outputs[0], gout.inputs["Shader"])
    return g


def _orig(mat):
    """Cor base e emissão do Principled que o glTF trouxe."""
    base, emit = (0.8, 0.8, 0.8, 1.0), 0.0
    if mat.node_tree:
        b = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if b:
            base = tuple(b.inputs["Base Color"].default_value)
            es = b.inputs.get("Emission Strength")
            ec = b.inputs.get("Emission Color")
            if es and ec and es.default_value > 0.0 and max(ec.default_value[:3]) > 0.01:
                emit = min(es.default_value, 2.0)
    return base, emit


def _rebuild(mat, group, color=None, glow=0.0, water=0.0, flat=0.0, source=None):
    """Troca a árvore do material por [cor] -> LA_Shade. `source(nt)` devolve a saída de cor (vértice, atributo...)."""
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    gn = nt.nodes.new("ShaderNodeGroup")
    gn.node_tree = group
    gn.inputs["Glow"].default_value = glow
    gn.inputs["Water"].default_value = water
    gn.inputs["Flat"].default_value = flat
    if source is not None:
        nt.links.new(source(nt), gn.inputs["Color"])
    else:
        gn.inputs["Color"].default_value = color
    nt.links.new(gn.outputs[0], out.inputs["Surface"])


def _vcol_source(nt):
    """Lotes do dress.py: a cor vem no vértice, escrita em sRGB (o toon do jogo liga `vcol_srgb`)."""
    a = nt.nodes.new("ShaderNodeVertexColor")
    gm = nt.nodes.new("ShaderNodeGamma")
    gm.inputs[1].default_value = 2.2
    nt.links.new(a.outputs["Color"], gm.inputs[0])
    return gm.outputs[0]


def _attr_source(name, has, orig):
    """Prop: cor do obstáculo (propriedade do objeto) quando ele tem cor; senão a do material."""
    def f(nt):
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_type = "OBJECT"
        a.attribute_name = name
        h = nt.nodes.new("ShaderNodeAttribute")
        h.attribute_type = "OBJECT"
        h.attribute_name = has
        m = _mixrgb(nt)
        m.inputs[6].default_value = orig
        nt.links.new(h.outputs["Fac"], m.inputs[0])
        nt.links.new(a.outputs["Color"], m.inputs[7])
        return m.outputs[2]
    return f


def _ground_source(g):
    def f(nt):
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 0.035
        nz.inputs["Detail"].default_value = 2.0
        nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        el = ramp.color_ramp.elements
        el[0].position, el[0].color = 0.0, lin(darkened(g, 0.1))
        el[1].position, el[1].color = 0.44, lin(g)
        e = el.new(0.6)
        e.color = lin(lightened(g, 0.07))
        nt.links.new(nz.outputs[0], ramp.inputs[0])
        return ramp.outputs[0]
    return f


def pow22(c):
    return (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1.0)


def map_materials(mats, zid, zd, group):
    """Espelho de MapBuilder._zone_materials: regra pelo nome do material do GLB da zona."""
    g = zd["ground"]
    tints = zd.get("water_tints", {})
    glows = zd.get("glow_mats", {})
    open_zone = not (zid.startswith("dg_") or zid.startswith("fort_") or zid.endswith("_citadel"))
    for m in mats:
        name = m.name
        base, emit = _orig(m)
        if name in glows:
            # só na foto: material do GLB que passa a brilhar (cor sRGB, força do brilho, chapado)
            c, gw, fl = glows[name]
            _rebuild(m, group, lin(c), glow=gw, flat=fl)
        elif name.startswith("det_vcol"):
            _rebuild(m, group, source=_vcol_source, flat=1.0 if name == "det_vcol_chao" else 0.0)
        elif name.startswith("patch_") or name.startswith("pave_"):
            _rebuild(m, group, pow22(base))
        elif name in tints:
            _rebuild(m, group, lin(tints[name]), glow=1.0 if name.startswith("glow_") else 0.0,
                     water=0.0 if name.startswith("glow_") else 1.0, flat=1.0)
        elif name.startswith("glow_") or name in ("soul", "fire", "farol_halo", "farol_aceso", "toxic_glow", "rune", "candle"):
            c = lin((1.0, 0.6, 0.2)) if name == "fire" else (pow22(base) if name.startswith("glow_") else base)
            _rebuild(m, group, c, glow=1.0)
        elif name in ("water", "water_dark"):
            c = (base[0] ** (1 / 2.2), base[1] ** (1 / 2.2), base[2] ** (1 / 2.2))
            _rebuild(m, group, lin(mix(c, (0.4, 0.66, 0.86), 0.25)), water=1.0, flat=1.0)
        elif name.startswith("agua_") or name.startswith("espuma_"):
            _rebuild(m, group, base, water=0.0 if name.startswith("espuma_") else 1.0, flat=1.0)
        elif name in ("icewater", "soulwater", "bile", "chasm"):
            _rebuild(m, group, pow22(base), water=0.0 if name == "chasm" else 0.7, flat=1.0,
                     glow=0.35 if name == "soulwater" else 0.0)
        elif name == "road":
            _rebuild(m, group, pow22(base) if open_zone else lin(dirt_color(g)))
        elif name == "street":
            _rebuild(m, group, lin((0.68, 0.64, 0.56)))
        elif name in ("cliff_grass", "hill_grass"):
            c = (base[0] ** (1 / 2.2), base[1] ** (1 / 2.2), base[2] ** (1 / 2.2))
            _rebuild(m, group, lin(mix(g, c, 0.4)))
        else:
            _rebuild(m, group, base, glow=emit)


def prop_materials(mats, kind, zd, group):
    """Espelho de MapBuilder._prop_model: `tint`/`roof` pegam a cor do obstáculo (propriedades do objeto)."""
    moss = mix(zd["ground"], (0.42, 0.6, 0.32), 0.35)
    recolor = zd.get("prop_colors", {})
    for m in mats:
        name = m.name.split(".")[0]
        base, emit = _orig(m)
        m.name = "P_%s_%s" % (kind, name)
        if name in recolor:
            _rebuild(m, group, lin(recolor[name]), glow=emit)        # só na foto (ex.: cristal âmbar na pedreira)
        elif name == "tint":
            _rebuild(m, group, source=_attr_source("la_tint", "la_has", base))
        elif name == "tint_l":
            _rebuild(m, group, source=_attr_source("la_tint_l", "la_has", base))
        elif name == "roof":
            _rebuild(m, group, source=_attr_source("la_roof", "la_has_roof", base))
        elif kind == "tent" and name in ("p_cloth_w", "p_cloth_r"):
            _rebuild(m, group, source=_attr_source("la_cloth_w" if name == "p_cloth_w" else "la_cloth_r", "la_has", base))
        elif name == "p_moss":
            _rebuild(m, group, lin(moss))
        else:
            _rebuild(m, group, base, glow=emit)


# ---------------------------------------------------------------------------------------------------------------------
# cena

def import_glb(path):
    obs, mats = set(bpy.data.objects), set(bpy.data.materials)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in obs], [m for m in bpy.data.materials if m not in mats]


LONG = ("wall", "fence", "ruin", "bench", "stall", "tent", "log")
BY_HEIGHT = ("tree", "pine", "dead_tree", "lamp", "statue")
ROUND = ("rock", "pillar", "well", "fountain", "bush", "stump", "flowers", "reeds")
SPUN = ("rock", "bush", "stump", "flowers", "reeds")


def load_prop(kind, zd, group):
    """Importa prop_<kind>.glb, junta numa malha só na origem e devolve (malha, tamanho xyz no Blender) ou None."""
    path = os.path.join(MODELS, "prop_%s.glb" % kind)
    if not os.path.exists(path):
        return None
    new, mats = import_glb(path)
    bpy.context.view_layer.update()
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        return None
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    if len(meshes) > 1:
        with bpy.context.temp_override(active_object=meshes[0], object=meshes[0], selected_objects=meshes,
                                       selected_editable_objects=meshes):
            bpy.ops.object.join()
    ob = meshes[0]
    bpy.context.view_layer.update()
    me = ob.data
    me.transform(ob.matrix_world)
    me.name = "LA_prop_" + kind
    me.use_fake_user = True
    for o in list(new):
        try:
            if o.name in bpy.data.objects:
                bpy.data.objects.remove(o, do_unlink=True)
        except ReferenceError:
            pass
    co = np.empty(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    size = co.max(axis=0) - co.min(axis=0)
    prop_materials(mats, kind, zd, group)
    return me, (float(size[0]), float(size[1]), float(size[2]))


def place_props(zid, zd, group, coll, extra=()):
    """Obstáculos visíveis do JSON -> instâncias das props, com a regra de escala do MapBuilder._prop_model.
    `extra` = obstáculos a mais só da foto (lampiões do preset `hall.lamps`)."""
    with open(os.path.join(ZDATA, zid + ".json"), encoding="utf-8") as f:
        z = json.load(f)
    z["obstacles"] = list(z.get("obstacles", [])) + list(extra)
    cache, n = {}, 0
    for ob in z.get("obstacles", []):
        if not ob.get("visible", True) or "if" in ob:
            continue
        kind = ob.get("kind", "")
        if kind not in cache:
            cache[kind] = load_prop(kind, zd, group)
        if cache[kind] is None:
            continue
        me, bb = cache[kind]
        if min(bb) < 0.001:
            continue
        sx, sy, sz = ob.get("size", [1, 1, 1])          # jogo: x, altura, fundo
        inner, h = 0.0, stable_hash(zid, ob["pos"])
        if kind in LONG and sz > sx * 1.2:
            inner, sx, sz = math.pi * 0.5, sz, sx
        if kind in BY_HEIGHT:
            u = sy / bb[2] * (0.9 + (h % 21) / 100.0)
            sc, inner = (u, u, u), math.radians(h % 360)
        elif kind.startswith("elf_"):
            u = sy / bb[2]
            sc = (u, u, u)
        elif kind in ROUND:
            u = max(sx, sz) / max(bb[0], bb[1])
            sc = (u, u, sy / bb[2])
            if kind in SPUN:
                inner = math.radians(h % 360)
        else:
            sc = (sx / bb[0], sz / bb[1], sy / bb[2])
        o = bpy.data.objects.new("LA_%s_%d" % (kind, n), me)
        coll.objects.link(o)
        if kind in PROP_LIGHT:
            o.visible_shadow = False        # a luz mora dentro da peça (hall_lights)
        rot = math.radians(float(ob.get("rot", 0.0)))
        o.matrix_world = (Matrix.Translation((ob["pos"][0], -ob["pos"][1], float(ob.get("y", 0.0))))
                          @ Matrix.Rotation(rot + inner, 4, "Z") @ Matrix.Diagonal((sc[0], sc[1], sc[2], 1.0)))
        c = ob.get("color")
        o["la_has"] = 1.0 if c else 0.0
        o["la_has_roof"] = 1.0 if ob.get("roof") else 0.0
        if c:
            o["la_tint"] = lin(c)[:3]
            o["la_tint_l"] = lin(lightened(c, 0.22))[:3]
            o["la_cloth_w"] = lin(lightened(c, 0.25))[:3]
            o["la_cloth_r"] = lin(darkened(c, 0.18))[:3]
        if ob.get("roof"):
            o["la_roof"] = lin(ob["roof"])[:3]
        n += 1
    return z, n


# brilho de peça de monstro como no jogo (EntityView.mob_glow): só emissão de verdade (> 1,05); o m_white e os corpos
# que exportam emissão 1,0 só para clarear ficam de fora
MOB_GLOW_MIN = 1.05
MOB_FIXED = ("m_eye", "m_white", "m_horn", "m_leather", "m_metal", "m_wood", "m_string", "belt", "trim")


def mob_tint(col, name, tint):
    """EntityView.monster_tint: o corpo do modelo emprestado puxa para a cor do monstro (matiz dele, 75% da saturação)."""
    if tint is None or name in MOB_FIXED or name.startswith("m_hair_") or (name.startswith("m_mob_") and not name.endswith("_cloth")):
        return col
    mh, ms, mv = colorsys.rgb_to_hsv(*tint[0])
    bv = colorsys.rgb_to_hsv(*tint[1])[2]
    h, sat, v = colorsys.rgb_to_hsv(*[min(1.0, max(0.0, c)) for c in col[:3]])
    v = min(1.0, max(0.0, v * (mv / max(0.05, bv))))
    r, g, b = colorsys.hsv_to_rgb(mh, sat + (ms - sat) * 0.75, v)
    return (r, g, b, 1.0)


def mob_materials(mats, bd, group):
    """Toon das props nos materiais do chefe; emissão forte (ou nome `glow_*`) emite na cor da emissão."""
    glows = []
    for m in mats:
        name = m.name.split(".")[0]
        base, es, ec = (0.8, 0.8, 0.8, 1.0), 0.0, None
        b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m.node_tree else None
        if b:
            base = tuple(b.inputs["Base Color"].default_value)
            if b.inputs.get("Emission Strength") and b.inputs.get("Emission Color"):
                es, ec = b.inputs["Emission Strength"].default_value, tuple(b.inputs["Emission Color"].default_value)
        m.name = "B_" + name
        glow = 0.0
        if es > MOB_GLOW_MIN and ec and max(ec[:3]) > 0.02:
            glow, base = min(1.0, es * 0.6 / 1.5), ec
        elif name.startswith("glow_"):
            glow = 1.0
        col = mob_tint(base, name, bd.get("tint"))
        if glow > 0.0:
            glows.append((glow, col[:3]))
        _rebuild(m, group, col, glow=glow)
    return glows


def place_boss(zd, z, group, coll, sc, cam_pos, acc):
    """O chefe da masmorra na foto: importa o GLB, posa num quadro do clipe, põe no tamanho do jogo (MonsterDef.scale
    direto no modelo) no spawner dele (ou `at`), virado para a câmera em 3/4, e acende a ribalta e o contraluz."""
    spec = zd.get("boss")
    if not spec:
        return None
    bd = BOSSES[spec["id"]]
    path = os.path.join(MODELS, bd["model"] + ".glb")
    if not os.path.exists(path):
        print("LA sem chefe:", path)
        return None
    acts0 = set(bpy.data.actions)
    new, mats = import_glb(path)
    glows = mob_materials(mats, bd, group)
    at = spec.get("at")
    if at is None:
        sp = next(s for s in z.get("spawners", []) if s["monster_id"] == spec["id"])
        at = (sp["pos"][0], -sp["pos"][1])
    pos = Vector((at[0], at[1], spec.get("lift", 0.0)))
    to_cam = Vector((cam_pos.x - pos.x, cam_pos.y - pos.y, 0.0)).normalized()
    pos += to_cam * spec.get("fwd", 0.0)             # uns passos na direção da câmera (o chefe cresce no quadro)
    turn = spec.get("turn", 26.0)
    yaw = math.atan2(to_cam.x, -to_cam.y) + math.radians(turn)      # a frente do modelo é -Y
    # pose: um quadro do clipe (as outras actions do GLB ficam soltas)
    arm = next((o for o in new if o.type == "ARMATURE"), None)
    acts = {a.name.split(".")[0]: a for a in bpy.data.actions if a not in acts0}
    act = acts.get(spec.get("clip", "idle"))
    if arm is not None and act is not None:
        ad = arm.animation_data or arm.animation_data_create()
        for t in list(ad.nla_tracks):
            ad.nla_tracks.remove(t)
        ad.action = act
        try:
            if ad.action_slot is None and len(act.slots):
                ad.action_slot = act.slots[0]
        except AttributeError:
            pass
    else:
        print("LA chefe sem clipe:", spec["id"], spec.get("clip"), sorted(acts))
    sc.frame_set(int(spec.get("frame", 0)))
    k = bd["scale"]
    mw = Matrix.Translation(pos) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Diagonal((k, k, k, 1.0))
    bpy.context.view_layer.update()
    for o in new:
        if o.parent is None:
            o.matrix_world = mw @ o.matrix_world
    bpy.context.view_layer.update()
    # tamanho de verdade (malha deformada no quadro)
    dg = bpy.context.evaluated_depsgraph_get()
    lo, hi = np.full(3, 1e9), np.full(3, -1e9)
    for o in new:
        if o.type != "MESH" or o.hide_render or not o.visible_get():      # fora: a forma de osso que o importador cria
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3, dtype=np.float32)
        me.vertices.foreach_get("co", co)
        m4 = np.array(ev.matrix_world, dtype=np.float32)
        co = co.reshape(-1, 3) @ m4[:3, :3].T + m4[:3, 3]
        ev.to_mesh_clear()
        if len(co):
            lo, hi = np.minimum(lo, co.min(axis=0)), np.maximum(hi, co.max(axis=0))
    h = float(hi[2] - lo[2])
    wide = float(max(hi[0] - lo[0], hi[1] - lo[1]))
    side = Vector((-to_cam.y, to_cam.x, 0.0))
    sgn = -1.0 if turn > 0 else 1.0           # a ribalta fica do lado para onde o chefe olha
    # ribalta: facho baixo na frente, de baixo para cima (ameaça), na cor da masmorra (ou `foot_col`). A borda de baixo
    # do cone fica na horizontal (não faz poça no chão) e ele não acende a névoa.
    fcol = spec.get("foot_col") or lightened(acc, 0.35)
    d = wide * 0.5 + 2.6
    src = pos + to_cam * d + side * (sgn * d * 0.5) + Vector((0, 0, 0.3))
    aim = pos + Vector((0, 0, h * 0.55))
    el = math.degrees(math.atan2(aim.z - src.z, (aim.xy - src.xy).length))
    foot = add_light(coll, "LA_chefe_ribalta", src, fcol, 38.0 * (aim - src).length_squared * spec.get("foot", 1.0), "SPOT", 0.3,
                     aim, max(20.0, el * 2.0), 0.3)
    try:
        foot.data.volume_factor = 0.0
    except AttributeError:
        pass
    # contraluz por cima e por trás: recorta a silhueta contra o fundo do salão
    if spec.get("back", 1.0) > 0.0:
        src = pos - to_cam * (h * 0.9 + 2.0) - side * (sgn * 1.5) + Vector((0, 0, h + 5.0))
        add_light(coll, "LA_chefe_contraluz", src, spec.get("back_col") or lightened(acc, 0.45), 15.0 * (src - pos).length_squared * spec.get("back", 1.0),
                  "SPOT", 0.5, pos + Vector((0, 0, h * 0.6)), 30.0, 0.4)
    print("LA chefe %s: %s clipe %s quadro %d, escala %.2f, altura %.2f m, largura %.2f m, em (%.1f, %.1f), giro %.0f, brilhos %d"
          % (spec["id"], bd["model"], spec.get("clip", "idle"), int(spec.get("frame", 0)), k, h, wide, pos.x, pos.y,
             math.degrees(yaw), len(glows)))
    return new


def make_ground(zd, group, coll, size=3200.0, south=None):
    """Chão até o horizonte. `south` = onde ele acaba ao sul (zona de mar: dali para baixo é água, ver make_sea)."""
    me = bpy.data.meshes.new("LA_ground")
    s = size * 0.5
    y0 = -s if south is None else south
    me.from_pydata([(-s, y0, 0), (s, y0, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new("LA_ground", me)
    o.location.z = -0.03
    coll.objects.link(o)
    m = bpy.data.materials.new("LA_ground")
    _rebuild(m, group, source=_ground_source(zd["ground"]))
    me.materials.append(m)
    o.visible_shadow = False
    return o


def make_sea(group, coll, objs, size=3200.0):
    """Mar aberto além da malha do GLB, na cor do material `agua_funda_*` dela."""
    src = next((m for m in bpy.data.materials if m.name.startswith("agua_funda")), None)
    col = lin((0.3, 0.6, 0.8))
    if src is not None:
        gn = next((n for n in src.node_tree.nodes if n.type == "GROUP"), None)
        if gn is not None:
            col = tuple(gn.inputs["Color"].default_value)
    me = bpy.data.meshes.new("LA_sea")
    s = size * 0.5
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new("LA_sea", me)
    o.location.z = -0.3
    coll.objects.link(o)
    m = bpy.data.materials.new("LA_sea")
    _rebuild(m, group, col, water=1.0, flat=1.0)
    me.materials.append(m)
    o.visible_shadow = False
    # a baía do GLB é um disco (areia > raso > fundo) pensado para a câmera do jogo; de longe o lado de fora dele
    # aparece. Um leque de mar fundo cobre a metade de fora (do raio do fundo em diante), abrindo em pontas nos lados.
    deep = next((ob for ob in objs if "agua_funda" in ob.name and ob.type == "MESH"), None)
    if deep is None:
        return
    cs = [deep.matrix_world @ Vector(c) for c in deep.bound_box]
    cx = (min(c.x for c in cs) + max(c.x for c in cs)) * 0.5
    cy = (min(c.y for c in cs) + max(c.y for c in cs)) * 0.5
    r0 = (max(c.x for c in cs) - min(c.x for c in cs)) * 0.5 - 1.0
    radii = [r0, r0 + 10, r0 + 24, r0 + 45, r0 + 80, r0 + 160, size]
    seg, verts, faces = 64, [], []
    for r in radii:
        lim = math.radians(84.0 + min(44.0, (r - r0) * 0.7))
        for k in range(seg + 1):
            a = lim * (k / seg * 2.0 - 1.0)             # 0 = para o sul (mar aberto)
            verts.append((cx + math.sin(a) * r, cy - math.cos(a) * r, 0.0))
    for i in range(len(radii) - 1):
        for k in range(seg):
            p0 = i * (seg + 1) + k
            faces.append((p0, p0 + 1, p0 + seg + 2, p0 + seg + 1))
    fan = bpy.data.meshes.new("LA_sea_fan")
    fan.from_pydata(verts, [], faces)
    fo = bpy.data.objects.new("LA_sea_fan", fan)
    fo.location.z = 0.06
    coll.objects.link(fo)
    fan.materials.append(m)
    fo.visible_shadow = False


def make_world(mood, sun_dir, bg=None):
    w = bpy.data.worlds.new("LA_world")
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bgn = nt.nodes.new("ShaderNodeBackground")
    lp = nt.nodes.new("ShaderNodeLightPath")
    nt.links.new(lp.outputs["Is Camera Ray"], bgn.inputs["Strength"])      # o céu aparece, mas não ilumina (o toon manda)
    if bg is not None:
        bgn.inputs["Color"].default_value = lin(bg)
    else:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        nrm = nt.nodes.new("ShaderNodeVectorMath")
        nrm.operation = "NORMALIZE"
        nt.links.new(tc.outputs["Generated"], nrm.inputs[0])
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(nrm.outputs[0], sep.inputs[0])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.interpolation_type = "SMOOTHSTEP"
        mr.inputs["From Min"].default_value = 0.0
        mr.inputs["From Max"].default_value = 0.24
        nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
        sky = _mixrgb(nt)
        sky.inputs[6].default_value = lin(mood["hor"])
        sky.inputs[7].default_value = lin(mood["top"])
        nt.links.new(mr.outputs["Result"], sky.inputs[0])
        # clarão em volta do sol
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        dot.inputs[1].default_value = sun_dir
        nt.links.new(nrm.outputs[0], dot.inputs[0])
        mx = _math(nt, "MAXIMUM", 0.0)
        nt.links.new(dot.outputs["Value"], mx.inputs[0])
        pw = _math(nt, "POWER", 10.0)
        nt.links.new(mx.outputs[0], pw.inputs[0])
        k = _math(nt, "MULTIPLY", mood.get("sun_glow", 0.45))
        nt.links.new(pw.outputs[0], k.inputs[0])
        glow = _mixrgb(nt)
        glow.inputs[7].default_value = lin(lightened(mood["light"], 0.3))
        nt.links.new(k.outputs[0], glow.inputs[0])
        nt.links.new(sky.outputs[2], glow.inputs[6])
        nt.links.new(glow.outputs[2], bgn.inputs["Color"])
    nt.links.new(bgn.outputs[0], out.inputs["Surface"])
    return w


# ---------------------------------------------------------------------------------------------------------------------
# masmorra: luzes do salão e névoa

# prop do JSON que ilumina: cor (None = a do obstáculo ou a da masmorra), watts, altura da luz (fração da prop)
PROP_LIGHT = {"lamp": (TORCH, 520.0, 0.9), "cauldron": (TORCH, 260.0, 1.25), "elf_lantern": ((0.72, 1.0, 0.66), 380.0, 0.9),
              "crystal": (None, 220.0, 0.8)}


def add_light(coll, name, loc, color, watts, kind="POINT", radius=0.3, aim=None, angle=40.0, blend=0.5):
    """Luz da cena (cor em sRGB). ~40 W por m² de distância acendem o tom cheio do toon `lit`."""
    ld = bpy.data.lights.new(name, kind)
    ld.color = lin(color)[:3]
    ld.energy = watts
    ld.shadow_soft_size = radius
    if kind == "SPOT":
        ld.spot_size = math.radians(angle)
        ld.spot_blend = blend
    o = bpy.data.objects.new(name, ld)
    o.location = loc
    if aim is not None:
        o.rotation_euler = (Vector(aim) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    coll.objects.link(o)
    return o


def glow_clusters(objs, cell=5.0):
    """Peças `glow_*` do GLB -> [(centro, área, cor linear)], uma por célula de `cell` m (brasas, lava, poças, cogumelos)."""
    out = []
    for o in objs:
        if o.type != "MESH" or o.hide_render or not o.data.polygons:
            continue
        cols = {}
        for i, m in enumerate(o.data.materials):
            gn = next((n for n in m.node_tree.nodes if n.type == "GROUP"), None) if m and m.node_tree else None
            if gn is not None and gn.inputs["Glow"].default_value >= 0.9 and not gn.inputs["Color"].is_linked:
                cols[i] = tuple(gn.inputs["Color"].default_value)[:3]
        if not cols:
            continue
        me = o.data
        n = len(me.polygons)
        ctr = np.empty(n * 3, dtype=np.float32)
        me.polygons.foreach_get("center", ctr)
        area = np.empty(n, dtype=np.float32)
        me.polygons.foreach_get("area", area)
        mi = np.empty(n, dtype=np.int32)
        me.polygons.foreach_get("material_index", mi)
        mw = np.array(o.matrix_world, dtype=np.float32)
        ctr = ctr.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
        for i, col in cols.items():
            sel = mi == i
            if not sel.any():
                continue
            c, a = ctr[sel], area[sel]
            keys = np.floor(c[:, :2] / cell).astype(np.int64)
            for kx, ky in {(int(k[0]), int(k[1])) for k in keys}:
                s = (keys[:, 0] == kx) & (keys[:, 1] == ky)
                w = a[s] / max(1e-6, float(a[s].sum()))
                p = (c[s] * w[:, None]).sum(axis=0)
                out.append((Vector((float(p[0]), float(p[1]), float(c[s][:, 2].max()))), float(a[s].sum()), col))
    return out


def hall_lights(zd, z, objs, coll, target, az, mood):
    """Acende o salão: props do JSON que iluminam, peças `glow_*` do GLB, luzes do preset e o facho sobre a arena."""
    hall = zd.get("hall", {})
    acc = mood["acc"]
    fx, fy = hall.get("focus", (target.x, target.y))
    focus = Vector((fx, fy, 0.0))
    reach = hall.get("reach", 46.0)
    n = 0
    for ob in z.get("obstacles", []):
        spec = PROP_LIGHT.get(ob.get("kind", ""))
        if spec is None or not ob.get("visible", True) or "if" in ob:
            continue
        p = Vector((ob["pos"][0], -ob["pos"][1], float(ob.get("y", 0.0)) + ob.get("size", [1, 1, 1])[1] * spec[2]))
        if (p.xy - focus.xy).length > reach:
            continue
        col = spec[0] or ob.get("color") or lightened(acc, 0.2)
        add_light(coll, "LA_luz_%s_%d" % (ob["kind"], n), p, col, spec[1] * ob.get("la_w", 1.0) * hall.get("prop_w", 1.0), radius=0.25)
        n += 1
    cl = [c for c in glow_clusters(objs) if (c[0].xy - focus.xy).length <= reach]
    cl.sort(key=lambda c: (c[0].xy - focus.xy).length)
    gw = hall.get("glow_w", 1.0)
    for p, area, col in cl[:hall.get("glow_max", 40)]:
        top = max(col) or 1.0
        ld = add_light(coll, "LA_luz_glow_%d" % n, (p.x, p.y, max(p.z, 0.5) + 0.45), (1, 1, 1),
                       min(900.0, 140.0 + area * 70.0) * gw, radius=0.4)
        ld.data.color = tuple(v / top for v in col)
        n += 1
    for k, d in enumerate(hall.get("lights", [])):
        col = d.get("color", "acc")
        col = lightened(acc, 0.25) if col == "acc" else (TORCH if col == "torch" else col)
        if "to" in d:
            add_light(coll, "LA_luz_%d" % k, d["at"], col, d.get("w", 2000.0), "SPOT", d.get("r", 0.6), d["to"], d.get("spot", 40.0))
        else:
            add_light(coll, "LA_luz_%d" % k, d["at"], col, d.get("w", 500.0), radius=d.get("r", 0.3))
        n += 1
    sh = hall.get("shaft", {})
    if sh is not False:
        a = math.radians(az)
        back = Vector((-math.sin(a), math.cos(a), 0.0))              # para trás do assunto, visto da câmera
        src = focus + back * sh.get("back", 2.5) + Vector((0, 0, sh.get("h", 22.0)))
        add_light(coll, "LA_facho", src, sh.get("color", lightened(acc, 0.3)), sh.get("w", 13000.0), "SPOT", 1.2,
                  focus + Vector((0, 0, 1.0)), sh.get("angle", 34.0), 0.35)
        n += 1
    return n


def make_haze(coll, center, density, color, size=170.0, height=46.0):
    """Névoa volumétrica do salão (caixa em volta do assunto): as luzes ganham halo e o facho aparece no ar."""
    me = bpy.data.meshes.new("LA_haze")
    s, h = size * 0.5, height
    vs = [(x, y, zz) for zz in (-0.5, h) for x, y in ((-s, -s), (s, -s), (s, s), (-s, s))]
    me.from_pydata(vs, [], [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
    o = bpy.data.objects.new("LA_haze", me)
    o.location = (center.x, center.y, 0.0)
    coll.objects.link(o)
    m = bpy.data.materials.new("LA_haze")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vol = nt.nodes.new("ShaderNodeVolumeScatter")
    vol.inputs["Color"].default_value = lin(color)
    vol.inputs["Density"].default_value = density
    vol.inputs["Anisotropy"].default_value = 0.35
    nt.links.new(vol.outputs[0], out.inputs["Volume"])
    me.materials.append(m)
    o.visible_shadow = False
    return o


def dir_from(az, el):
    """Vetor unitário do alvo para quem olha de `az` (0 = sul) na elevação `el`."""
    a, e = math.radians(az), math.radians(el)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def resolve_cam(cam, z, glb_objs):
    at = cam["at"]
    town = z.get("town", {})
    if at == "town":
        c = town.get("center", [0, 0])
        at = (c[0], -c[1])
    elif isinstance(at, str) and at.startswith("obj:"):
        key = at[4:]
        pts = [o.matrix_world @ (sum((Vector(b) for b in o.bound_box), Vector()) / 8.0) for o in glb_objs if key in o.name]
        ctr = sum(pts, Vector()) / max(1, len(pts))
        at = (ctr.x, ctr.y)
    az = cam["az"]
    if az == "spawn":
        sp = z.get("spawn", [0, 0])
        dx, dy = sp[0] - at[0], -sp[1] - at[1]
        az = math.degrees(math.atan2(dx, -dy))
    az += cam.get("az_off", 0.0)
    return Vector((at[0], at[1], cam.get("h", 0.0))), az


def setup_render(sc, scale, samples, haze=False):
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    try:
        sc.render.engine = next(e for e in engines if "EEVEE" in e)
    except (StopIteration, TypeError):
        for e in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
            try:
                sc.render.engine = e
                break
            except TypeError as err:
                print("engine:", err)
    print("LA engine:", sc.render.engine)
    sc.render.resolution_x = int(W * scale)
    sc.render.resolution_y = int(H * scale)
    sc.render.resolution_percentage = 100
    for attr, val in (("taa_render_samples", samples), ("use_shadows", True), ("use_raytracing", False),
                      ("use_volumetric_shadows", False), ("shadow_ray_count", 2), ("shadow_step_count", 6)):
        try:
            setattr(sc.eevee, attr, val)
        except (AttributeError, TypeError) as err:
            print("eevee:", attr, err)
    if haze:
        for attr, val in (("volumetric_start", 0.5), ("volumetric_end", 220.0), ("volumetric_tile_size", "4"),
                          ("volumetric_samples", 96), ("volumetric_sample_distribution", 0.7), ("use_volumetric_shadows", True),
                          ("volumetric_shadow_samples", 16), ("volumetric_light_clamp", 0.0), ("shadow_pool_size", "1024")):
            try:
                setattr(sc.eevee, attr, val)
            except (AttributeError, TypeError) as err:
                print("eevee:", attr, err)
    try:
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
    except TypeError as err:
        print("view:", err)
    sc.render.film_transparent = False
    sc.render.use_file_extension = True


def set_format(sc, fmt, **kw):
    st = sc.render.image_settings
    try:
        st.media_type = "IMAGE"
    except (AttributeError, TypeError):
        pass
    st.file_format = fmt
    for k, v in kw.items():
        try:
            setattr(st, k, v)
        except (AttributeError, TypeError) as err:
            print("format:", k, err)


def build_zone(zid, top=False):
    """Cena nova com a zona pronta para a foto. Devolve (scene, zd, mood)."""
    zd = ZONES[zid]
    mood = dict(MOODS[zd["mood"]])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    coll = sc.collection
    dungeon = zd["mood"] == "dungeon"
    hall = zd.get("hall", {})
    bg = None
    if dungeon:
        amb = zd.get("ambient", (0.6, 0.6, 0.7))
        acc = accent(amb)
        mood["acc"] = acc
        for k in ("fog", "fog_start", "fog_max", "rim", "haze", "glow", "sun_w"):
            if k in hall:
                mood[k] = hall[k]
        mood["shadow"] = darkened(mix(amb, acc, 0.5), 1.0 - hall.get("fill", 0.42))      # o que a luz não alcança
        mood["hor"] = darkened(acc, 1.0 - hall.get("mist", 0.26))                          # névoa do fundo
        mood["top"] = darkened(acc, 0.955)
        mood["calm"] = darkened(acc, 0.9)
        mood["rim_col"] = lightened(acc, 0.25)
    if not dungeon:
        mood["fog_start"] = max(mood["fog_start"], zd["cam"]["dist"] * 0.8)      # o assunto fica nítido; a névoa começa atrás dele
    if top:
        mood["fog"] = 0.0
    group = make_shade_group(mood, bg)
    objs, mats = import_glb(os.path.join(MODELS, "map_%s.glb" % zid))
    map_materials(mats, zid, zd, group)
    for o in objs:
        if any(t in o.name for t in zd.get("hide", [])):
            o.hide_render = True
            o.hide_viewport = True
        if o.type == "MESH" and o.data.materials:
            names = [m.name for m in o.data.materials if m]
            if names and all(n.startswith(("patch_", "pave_", "det_vcol_chao", "det_vcol_mini", "glow_", "road", "street",
                                           "water", "agua_", "espuma_", "chasm", "bile", "icewater", "soul")) for n in names):
                o.visible_shadow = False
    if zd.get("sea"):
        with open(os.path.join(ZDATA, zid + ".json"), encoding="utf-8") as f:
            half = json.load(f).get("size", [260, 260])[1] * 0.5 + 45.0       # borda do chão do jogo (MapBuilder._ground)
        make_ground(zd, group, coll, south=-half)
        make_sea(group, coll, objs)
    else:
        make_ground(zd, group, coll)
    extra = [{"kind": "lamp", "pos": [p[0], -p[1]], "size": [0.4, 2.4, 0.4], "la_w": (p[2] if len(p) > 2 else 1.0)}
             for p in hall.get("lamps", [])]
    # peças só da foto (`extras`: obstáculos com `pos` em x, y do Blender; o resto como no JSON)
    extra += [dict(e, pos=[e["pos"][0], -e["pos"][1]]) for e in zd.get("extras", [])]
    z, n = place_props(zid, zd, group, coll, extra)
    bpy.context.view_layer.update()
    cam = zd["cam"]
    target, az = resolve_cam(cam, z, objs)
    sun_az = az + cam.get("sun_rel", mood["sun_rel"])
    sun_dir = dir_from(sun_az, cam.get("sun_el", mood["sun_el"]))
    sc.world = make_world(mood, sun_dir, bg)
    sd = bpy.data.lights.new("LA_sun", "SUN")
    sd.energy = math.pi          # difuso branco de frente para o sol = 1
    if dungeon and not top:
        sd.energy = math.pi * mood["sun_w"]          # só um contraluz fraco na cor da masmorra; o resto é hall_lights
        sd.color = lin(lightened(mood["acc"], 0.2))[:3]
        nl = hall_lights(zd, z, objs, coll, target, az, mood)
        boss = place_boss(zd, z, group, coll, sc, target + dir_from(az, cam["elev"]) * cam["dist"], mood["acc"])
        if boss and zd["boss"].get("no_glow"):
            # vínculo de luz: as luzes das peças que brilham deixam o chefe de fora
            rc = bpy.data.collections.new("LA_sem_brilho")
            for o in boss:
                if o.type == "MESH":
                    rc.objects.link(o)
            for ch in rc.collection_objects:
                ch.light_linking.link_state = "EXCLUDE"
            for o in coll.objects:
                if o.name.startswith("LA_luz_glow_"):
                    o.light_linking.receiver_collection = rc
        if mood.get("haze", 0.0) > 0.0:
            make_haze(coll, target, mood["haze"], lightened(mood["acc"], 0.45))
        print("LA hall %s: %d luzes" % (zid, nl))
    sd.angle = math.radians(1.5)
    so = bpy.data.objects.new("LA_sun", sd)
    so.rotation_euler = (-sun_dir).to_track_quat("-Z", "Y").to_euler()
    coll.objects.link(so)
    cd = bpy.data.cameras.new("LA_cam")
    co = bpy.data.objects.new("LA_cam", cd)
    coll.objects.link(co)
    sc.camera = co
    cd.clip_start, cd.clip_end = 0.5, 4000.0
    if top:
        size = max(z.get("size", [260, 260])) + 60
        cd.type = "ORTHO"
        cd.ortho_scale = size
        co.location = (0, 0, 600)
    else:
        cd.sensor_fit = "VERTICAL"
        cd.angle_y = math.radians(cam.get("fov", 46))
        co.location = target + dir_from(az, cam["elev"]) * cam["dist"]
        look = -dir_from(az + cam.get("pan", 0.0), cam.get("pitch", cam["elev"] - 6))
        co.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    print("LA zone %s: %d pecas do glb, %d props, alvo (%.1f, %.1f) az %.1f" % (zid, len(objs), n, target.x, target.y, az))
    return sc, zd, mood


# ---------------------------------------------------------------------------------------------------------------------
# pós (numpy): halo do que brilha, base do quadro mais calma, JPEG

def _box(a, r, axis):
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis, dtype=np.float64)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return ((hi - lo) / (2 * r + 1)).astype(np.float32)


def _blur(a, r, passes=3):
    for _ in range(passes):
        a = _box(_box(a, r, 0), r, 1)
    return a


def post(px, mood):
    """px: (h, w, 3) linear, linha 0 = base do quadro."""
    h, w, _ = px.shape
    k = max(1, w // 400)
    # halo: o que passa de 1 espalha
    over = np.clip(px - 1.0, 0.0, 6.0)
    small = over[: h // k * k, : w // k * k].reshape(h // k, k, w // k, k, 3).mean(axis=(1, 3))
    halo = _blur(small, 5) * 1.5 + _blur(small, 16) * 1.3
    halo = np.repeat(np.repeat(halo, k, axis=0), k, axis=1)
    halo = np.pad(halo, ((0, h - halo.shape[0]), (0, w - halo.shape[1]), (0, 0)), mode="edge")
    if k > 1:
        halo = _blur(halo, k, 1)
    px = px + halo
    # base calma (barra de progresso e dica): menos detalhe e contraste, puxando para a cor de sombra do clima
    y = (np.arange(h, dtype=np.float32) / (h - 1))[:, None, None]
    wgt = np.clip((0.34 - y) / 0.34, 0.0, 1.0) ** 1.3
    soft = _blur(px, max(2, w // 200), 2)
    px = px * (1 - wgt * 0.75) + soft * (wgt * 0.75)
    calm = np.array(lin(mood["calm"])[:3], dtype=np.float32)
    px = px * (1 - wgt * 0.5) + calm * (wgt * 0.5)
    # um pouco mais de cor (a névoa lava)
    lum = (px * np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)).sum(axis=2, keepdims=True)
    px = np.clip(lum + (px - lum) * 1.16, 0.0, None)
    # vinheta leve
    x = (np.arange(w, dtype=np.float32) / (w - 1))[None, :, None] - 0.5
    vig = 1.0 - 0.22 * np.clip((x * x * 1.6 + (y - 0.5) ** 2 * 1.2) * 2.4, 0.0, 1.0)
    return np.clip(px * vig, 0.0, 1.0)


def render_zone(zid, out_dir, scale=1.0, samples=32, top=False, tmp=None):
    sc, zd, mood = build_zone(zid, top)
    setup_render(sc, scale, samples, haze=zd["mood"] == "dungeon" and not top and mood.get("haze", 0.0) > 0.0)
    tmp = tmp or bpy.app.tempdir
    if top:
        sc.render.resolution_x = sc.render.resolution_y = int(900 * scale)
        set_format(sc, "PNG", color_mode="RGB")
        sc.render.filepath = os.path.join(out_dir, "top_%s.png" % zid)
        bpy.ops.render.render(write_still=True)
        return sc.render.filepath
    set_format(sc, "OPEN_EXR", color_mode="RGB", color_depth="16")
    raw = os.path.join(tmp, "la_%s.exr" % zid)
    sc.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(raw)
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    px = post(buf.reshape(h, w, 4)[:, :, :3].copy(), mood)
    res = bpy.data.images.new("la_out", w, h, alpha=False, float_buffer=True)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = px
    res.pixels.foreach_set(rgba.ravel())
    set_format(sc, "JPEG", color_mode="RGB", quality=QUALITY)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, zid + ".jpg")
    res.save_render(path, scene=sc)
    bpy.data.images.remove(img)
    bpy.data.images.remove(res)
    try:
        os.remove(raw)
    except OSError:
        pass
    print("LA saved:", path, os.path.getsize(path))
    return path


# ---------------------------------------------------------------------------------------------------------------------
# folha de contato (planos com as fotos + legenda, câmera ortográfica)

def contact_sheet(out_dir, path=SHEET, cols=4, ids=None):
    ids = [i for i in (ids or ZONES) if os.path.exists(os.path.join(out_dir, i + ".jpg"))]
    if not ids:
        print("LA sheet: nenhuma foto em", out_dir)
        return None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    setup_render(sc, 1.0, 8)
    cw, ch, gap, lab = 4.8, 2.7, 0.22, 0.42
    rows = (len(ids) + cols - 1) // cols
    tw, th = cols * (cw + gap) + gap, rows * (ch + lab + gap) + gap
    w = bpy.data.worlds.new("sheet")
    w.use_nodes = True
    w.node_tree.nodes.clear()
    o = w.node_tree.nodes.new("ShaderNodeOutputWorld")
    b = w.node_tree.nodes.new("ShaderNodeBackground")
    b.inputs["Color"].default_value = lin((0.1, 0.1, 0.13))
    w.node_tree.links.new(b.outputs[0], o.inputs["Surface"])
    sc.world = w
    tm = bpy.data.materials.new("sheet_text")
    tm.use_nodes = True
    tm.node_tree.nodes.clear()
    to = tm.node_tree.nodes.new("ShaderNodeOutputMaterial")
    te = tm.node_tree.nodes.new("ShaderNodeEmission")
    te.inputs["Color"].default_value = lin((0.92, 0.9, 0.84))
    tm.node_tree.links.new(te.outputs[0], to.inputs["Surface"])
    for k, zid in enumerate(ids):
        cx = gap + (k % cols) * (cw + gap) + cw * 0.5
        top = th - gap - (k // cols) * (ch + lab + gap)
        me = bpy.data.meshes.new("card")
        me.from_pydata([(-cw / 2, -ch / 2, 0), (cw / 2, -ch / 2, 0), (cw / 2, ch / 2, 0), (-cw / 2, ch / 2, 0)], [], [(0, 1, 2, 3)])
        uv = me.uv_layers.new()
        for i, c in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
            uv.data[i].uv = c
        ob = bpy.data.objects.new("card_" + zid, me)
        ob.location = (cx, top - ch * 0.5, 0)
        sc.collection.objects.link(ob)
        m = bpy.data.materials.new("card_" + zid)
        m.use_nodes = True
        m.node_tree.nodes.clear()
        mo = m.node_tree.nodes.new("ShaderNodeOutputMaterial")
        em = m.node_tree.nodes.new("ShaderNodeEmission")
        tx = m.node_tree.nodes.new("ShaderNodeTexImage")
        tx.image = bpy.data.images.load(os.path.join(out_dir, zid + ".jpg"))
        m.node_tree.links.new(tx.outputs["Color"], em.inputs["Color"])
        m.node_tree.links.new(em.outputs[0], mo.inputs["Surface"])
        me.materials.append(m)
        cu = bpy.data.curves.new("txt_" + zid, "FONT")
        cu.body = "%s  -  %s" % (zid, ZONES[zid]["name"])
        cu.size = 0.24
        cu.align_x = "CENTER"
        cu.materials.append(tm)
        t = bpy.data.objects.new("txt_" + zid, cu)
        t.location = (cx, top - ch - 0.3, 0.01)
        sc.collection.objects.link(t)
    cd = bpy.data.cameras.new("sheet")
    cd.type = "ORTHO"
    cd.sensor_fit = "HORIZONTAL"
    cd.ortho_scale = tw
    co = bpy.data.objects.new("sheet", cd)
    co.location = (tw * 0.5, th * 0.5, 10)
    sc.collection.objects.link(co)
    sc.camera = co
    px = 100.0
    sc.render.resolution_x = int(tw * px)
    sc.render.resolution_y = int(th * px)
    set_format(sc, "PNG", color_mode="RGB")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("LA sheet:", path, len(ids), "fotos")
    return path


def run(only=None, out_dir=OUT_DIR, scale=1.0, samples=32, top=False, sheet=True, render=True, sheet_path=SHEET):
    ids = [i for i in ZONES if not only or i in only]
    if render:
        for zid in ids:
            if not os.path.exists(os.path.join(MODELS, "map_%s.glb" % zid)):
                print("LA sem modelo:", zid)
                continue
            render_zone(zid, out_dir, scale, samples, top)
    if sheet and not top:
        contact_sheet(out_dir, sheet_path)


def _main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {a.split("=")[0]: (a.split("=", 1)[1] if "=" in a else "") for a in argv}
    only = [s for s in opt.get("--only", "").split(",") if s]
    run(only=only or None, out_dir=opt.get("--out", OUT_DIR), scale=float(opt.get("--scale", 1.0)),
        samples=int(opt.get("--samples", 32)), top="--top" in opt, sheet="--sheet" in opt or not only,
        render="--no_render" not in opt, sheet_path=opt.get("--sheet") or SHEET)


if __name__ == "__main__":
    _main()
