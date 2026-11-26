"""Arquivo de Vel'Thar (dg_archive, 27-29; GDD design/gdd/arquivo-de-velthar.md §3.4, §3.6 e §9): os modelos novos.

  mob_azhar_scribe   O Escrivão de Azhar (chefe; humanoide do kit, alto e magro: pernas e tronco esticados por
                     lumeria_mobs._stretch). Capuz de pergaminho com o rosto coberto por uma página de nomes (filete âmbar),
                     manto de tiras de pergaminho, rolo nas costas, livro ABERTO preso ao peito do lado esquerdo e a pena-lança
                     enorme na mão direita (no lugar do cajado do kit: mesmo eixo). Sépia + âmbar. Clipes de chefe
                     (MOB_BOSS_KEEP): `cast_channel` PRÓPRIO = Ler um Nome (cabeça baixa no livro, mão esquerda segura a
                     página, a pena escreve no ar; impacto no quadro 14, repete na fase ativa: EntityView.ACTIVE_LOOP),
                     `cast_ground` = Tinta Derramada, `attack` = golpe de duas mãos da pena (Pena de Ferro).
  mob_name_ledger    Livro de Nomes (parado; "ovo" do Escrivão): atril de madeira escura (osso `root`) com o livro aberto
                     inclinado para quem olha. Ossos do livro ao longo da LOMBADA (eixo local y = lombada): `body` capa de
                     baixo e o miolo, `arm_r`/`arm_l` as metades (+X/-X), `head` a folha que vira, `core` as letras acesas
                     que boiam sobre o livro, `floor` as folhas rasgadas no chão (escala ~0 até o die).
                     Clipes: idle (a folha vira, as letras pulsam) run (parado) attack cast hit die (rasga: as metades
                     despencam pelos lados do atril, a folha voa, as letras apagam, folhas no chão).
  mob_archive_shelf  Estante de pé (cobertura da Chamada; molde do mob_standing_mirror): estante DUPLA (livros dos dois
                     lados: a sim não diz para onde ela olha), 2,6 x 0,7 x 2,5 m. `body` gira na quina de trás de baixo
                     (tomba para trás, +Y), `head` o remate com a placa de nomes, `arm_r`/`arm_l` as fileiras de cima que
                     saem na queda, `core` livros e papel espalhados no chão (escala ~0 com a estante de pé).
                     Clipes: idle run attack hit die + `crack` (tomba, 1 vez) e `idle_cracked` (laço já tombada).
  mob_blind_copyist  Copista Sem Olhos (opcional): humanoide do kit em túnica sépia, venda de pano com letras sobre os
                     olhos, capuz baixo, pena na mão direita (no lugar da varinha) e prancheta com folha na esquerda.
                     Clipes de monstro com varinha (os do mob_cultist).

Peças rígidas (ledger, estante): uma malha por osso (lp.export_glb); todo clipe grava TODOS os ossos (lumeria_bosses._sclip).
Ossos de pé: x = X, y = para cima, z = -Y (frente); rot x positivo = inclina para a frente.

    import mob_kit; mob_kit.build_all(r"<abs>/assets/models", only=set(archive_mobs.BUILDERS))
    blender -b --factory-startup --python tools/blender/lumeria_mobs_preview.py -- --module=archive_mobs --out=<abs> --ground --export=<abs assets/models>
"""
import math

import bpy
from mathutils import Matrix, Vector

import chibi_kit as ck
import mob_kit as mk
import lumeria_bosses as lb
import lumeria_mobs as lm
import oaths_mobs as om

V = Vector
Z0, ONE, NIL = (0, 0, 0), (1, 1, 1), (0.001, 0.001, 0.001)
r = lb.r
_Parts, _flat, _sclip, _sc, _loop, _vine, _hoop = lb._Parts, lb._flat, lb._sclip, lb._sc, lb._loop, lb._vine, lb._hoop
s, c = math.sin, math.cos

PARCH = (0.86, 0.78, 0.6)          # pergaminho
PARCH_D = (0.66, 0.56, 0.4)
SEPIA = (0.56, 0.44, 0.3)          # pano sépia
SEPIA_D = (0.36, 0.27, 0.19)
INK = (0.12, 0.1, 0.09)
AMBER = (0.98, 0.76, 0.4)          # filete/letras acesas (o glow da masmorra; nunca azul: azul = morto do Lich)
WOOD = (0.34, 0.24, 0.17)
WOOD_L = (0.5, 0.37, 0.25)
BRASS = (0.68, 0.54, 0.3)
LEATHER = (0.46, 0.22, 0.16)       # capa dos livros de nomes (couro vinho-velho)
BOOKS = ((0.52, 0.26, 0.2), (0.32, 0.36, 0.27), (0.58, 0.44, 0.24), (0.33, 0.28, 0.38), (0.64, 0.52, 0.36), (0.42, 0.3, 0.22))


def _mats(cid):
    m = lambda n, col, rough=0.85, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    M = {"parch": m("parch", PARCH, 0.9), "parch_d": m("parch_d", PARCH_D, 0.9), "sepia": m("sepia", SEPIA), "sepia_d": m("sepia_d", SEPIA_D),
         "ink": m("ink", INK, 0.6), "glow": m("glow_amber", AMBER, 0.3, 2.0), "wood": m("wood", WOOD, 0.8), "wood_l": m("wood_l", WOOD_L, 0.8),
         "brass": m("brass", BRASS, 0.45), "leather": m("leather", LEATHER, 0.8)}
    M["books"] = [m("book%d" % i, col, 0.8) for i, col in enumerate(BOOKS)]
    return M


def _xf(objs, mtx):
    """Aplica uma matriz 4x4 nos vértices (peça modelada num quadro local e levada ao lugar)."""
    for o in objs:
        for v in o.data.vertices:
            v.co = mtx @ v.co
    return objs


# ---------------------------------------------------------------------------
# Livro de Nomes (parado)
# ---------------------------------------------------------------------------
LEDGER_SLANT = 26.0                # graus: o tampo do atril desce para a frente (-Y); a câmera alta vê as páginas
LEDGER_C = V((0, 0.02, 1.06))      # centro da lombada
LEDGER_HALF = 0.3                  # meia-lombada (a página tem 0,6 m de altura)


def _ledger_frame():
    return Matrix.Translation(LEDGER_C) @ Matrix.Rotation(math.radians(LEDGER_SLANT), 4, "X")


def _ledger_bones():
    mt = _ledger_frame()
    s0, s1 = mt @ V((0, -LEDGER_HALF, 0.04)), mt @ V((0, LEDGER_HALF, 0.04))
    t = tuple
    return {
        "root": ((0, 0, 0), (0, 0, 0.2), None),                       # atril
        "body": (t(s0), t(s1), "root"),                               # capa de baixo, lombada e o miolo
        "arm_r": (t(s0), t(s1), "body"),                              # metade +X
        "arm_l": (t(s0), t(s1), "body"),                              # metade -X
        "head": (t(s0 + (s1 - s0) * 0.02), t(s1), "body"),            # a folha que vira
        "core": ((0, -0.1, 1.3), (0, -0.1, 1.5), "root"),             # letras acesas que boiam
        "floor": ((0, -0.3, 0.02), (0, -0.3, 0.2), "root"),           # folhas rasgadas no chão
    }


def _half(name, sx, M, open_deg=9.0, pages=True):
    """Metade do livro no quadro do livro (lombada em y, folhas em z+): capa de couro, bloco de folhas, cantoneiras e as
    linhas de nomes (tinta) com duas linhas acesas."""
    w, hh = 0.42, LEDGER_HALF
    out = [ck.box(name + "_cover", (w + 0.03, hh * 2 + 0.05, 0.03), (sx * (w * 0.5 + 0.01), 0, 0.015), M["leather"])]
    if pages:
        out.append(ck.box(name + "_pages", (w - 0.02, hh * 2 - 0.04, 0.07), (sx * (w * 0.5), 0, 0.065), M["parch"]))
        for k in range(6):                                   # linhas de nomes
            y = hh * 0.72 - k * hh * 0.26
            L = w * (0.55 + 0.25 * ((k * 3) % 4) / 3.0)
            mat_ = M["glow"] if k in (1, 4) else M["ink"]
            out.append(ck.box("%s_line%d" % (name, k), (L, 0.022, 0.012), (sx * (0.05 + L * 0.5), y, 0.104), mat_))
        out.append(ck.box(name + "_strike", (w * 0.6, 0.016, 0.014), (sx * (0.05 + w * 0.3), hh * 0.72 - 2 * hh * 0.26, 0.108), M["ink"]))
    for k in (-1, 1):                                        # cantoneiras de latão
        out.append(ck.box("%s_corner%d" % (name, k), (0.07, 0.07, 0.04), (sx * (w + 0.005), k * (hh + 0.01), 0.018), M["brass"]))
    rot = Matrix.Rotation(math.radians(-sx * open_deg), 4, "Y")       # o V do livro aberto (as metades sobem um pouco)
    return _xf(out, rot)


def name_ledger(cid="mob_name_ledger"):
    arm = mk.lp.make_armature("rig_" + cid, _ledger_bones())
    M = _mats(cid)
    P = _Parts()
    mt = _ledger_frame()
    # atril (root): base em cruz, coluna torneada, tampo inclinado com a borda de apoio
    for k in range(4):
        a = math.radians(45 + 90 * k)
        P.add("root", _vine("leg%d" % k, [(0, 0, 0.16), (c(a) * 0.22, s(a) * 0.22, 0.08), (c(a) * 0.34, s(a) * 0.34, 0.03)], 0.045, 0.035, M["wood"], 5, 2),
              ck.ball("foot%d" % k, 0.05, (c(a) * 0.34, s(a) * 0.34, 0.035), M["brass"]))
    P.add("root", _flat(ck.tube("column", (0, 0, 0.06), (0, 0, 0.92), 0.07, 0.055, M["wood"], 8)),
          ck.ball("knot_a", 0.09, (0, 0, 0.32), M["wood_l"], (1, 1, 0.6)), ck.ball("knot_b", 0.08, (0, 0, 0.7), M["wood_l"], (1, 1, 0.6)))
    top = [ck.box("desk", (1.0, 0.7, 0.05), (0, 0, -0.03), M["wood_l"]), ck.box("ledge", (0.96, 0.06, 0.08), (0, -0.37, 0.0), M["wood"])]
    P.add("root", _xf(top, mt), _xf([ck.box("chain_ring", (0.05, 0.05, 0.05), (0.5, 0.3, 0.0), M["brass"])], mt))
    P.add("root", _flat(ck.tube("neck", (0, 0, 0.9), (0, 0.02, 1.0), 0.06, 0.08, M["wood"], 6)))
    # livro: capa de baixo + lombada (body), metades (arm_r/arm_l), a folha que vira (head)
    P.add("body", _xf([ck.box("spine", (0.09, LEDGER_HALF * 2 + 0.06, 0.05), (0, 0, 0.02), M["leather"]),
                       ck.box("ribbon", (0.04, 0.02, 0.34), (0.02, -LEDGER_HALF - 0.02, -0.12), M["glow"])], mt))
    P.add("arm_r", _xf(_half("right", 1, M), mt))
    P.add("arm_l", _xf(_half("left", -1, M), mt))
    leaf = [ck.box("leaf", (0.4, LEDGER_HALF * 2 - 0.06, 0.012), (0.21, 0, 0.11), M["parch_d"])]
    for k in range(4):
        leaf.append(ck.box("leaf_line%d" % k, (0.26, 0.02, 0.008), (0.2, LEDGER_HALF * 0.6 - k * 0.14, 0.12), M["ink"]))
    P.add("head", _xf(_xf(leaf, Matrix.Rotation(math.radians(-14), 4, "Y")), mt))
    # letras acesas que boiam sobre o livro (core): três losangos e uma linha
    for k, (x, y, z) in enumerate(((-0.16, -0.12, 1.36), (0.12, -0.06, 1.44), (0.02, -0.16, 1.52))):
        P.add("core", ck.blade("rune%d" % k, (x, y, z - 0.06), (x, y, z + 0.06), 0.07, 0.015, M["glow"], (1, 0, 0), 0.5))
    # folhas rasgadas no chão (floor, escala ~0 até o die)
    for k in range(9):
        a = k * 2.4
        rr = 0.28 + 0.07 * (k % 4)
        P.add("floor", _flat(ck.box("torn%d" % k, (0.24, 0.3, 0.008), (c(a) * rr, s(a) * rr - 0.1, 0.012 + 0.004 * (k % 3)), M["parch"] if k % 3 else M["parch_d"])))
    P.finish(arm, cid)

    hide = lambda bone, end: {bone: [(1, Z0, Z0, NIL), (end, Z0, Z0, NIL)]}      # _sclip fecharia em escala 1
    # idle (48): a folha vira devagar da direita para a esquerda e volta (um respiro), as letras sobem e pulsam
    turn = [(1, r(0, 0, 0), Z0), (14, r(0, -40, 0), Z0), (22, r(0, -120, 0), Z0), (28, r(0, -150, 0), Z0), (34, r(0, -120, 0), Z0),
            (42, r(0, -30, 0), Z0), (48, r(0, 0, 0), Z0)]
    pulse = [(f, Z0, (0, 0.03 * s((f - 1) / 47 * math.tau), 0), (1 + 0.15 * s((f - 1) / 47 * math.tau * 2),) * 3) for f in list(range(1, 48, 4)) + [48]]
    _sclip(arm, "idle", 48, dict(hide("floor", 48), head=turn, core=pulse,
                                  arm_r=[(1, Z0, Z0), (24, r(0, -2, 0), Z0), (48, Z0, Z0)], arm_l=[(1, Z0, Z0), (24, r(0, 2, 0), Z0), (48, Z0, Z0)]), loop=True)
    _sclip(arm, "run", 16, dict(hide("floor", 16), core=_sc([(1, 1.0), (16, 1.0)])), loop=True)
    # cast (10): as metades se erguem, as folhas folheiam e as letras crescem
    clap = {"arm_r": [(4, r(0, 6, 0), Z0), (10, r(0, -34, 0), Z0), (14, r(0, -20, 0), Z0), (20, Z0, Z0)],
            "arm_l": [(4, r(0, -6, 0), Z0), (10, r(0, 34, 0), Z0), (14, r(0, 20, 0), Z0), (20, Z0, Z0)],
            "head": [(4, r(0, -10, 0), Z0), (8, r(0, -90, 0), Z0), (10, r(0, -150, 0), Z0), (16, r(0, -60, 0), Z0), (20, Z0, Z0)],
            "core": _sc([(4, 0.8), (10, 1.6), (14, 1.25), (20, 1.0)])}
    _sclip(arm, "cast", 22, dict(hide("floor", 22), **clap))
    _sclip(arm, "attack", 17, dict(hide("floor", 17), **lb._retime(clap, 10, 5)))
    _sclip(arm, "hit", 10, dict(hide("floor", 10), body=[(2, r(-6, 0, 3), Z0), (5, r(3, 0, -2), Z0), (8, Z0, Z0)],
                                arm_r=[(2, r(0, -16, 0), Z0), (6, r(0, 3, 0), Z0), (9, Z0, Z0)], arm_l=[(2, r(0, 16, 0), Z0), (6, r(0, -3, 0), Z0), (9, Z0, Z0)],
                                head=[(2, r(0, -50, 0), Z0), (6, r(0, -8, 0), Z0), (9, Z0, Z0)], core=_sc([(2, 0.5), (7, 1.0)])))
    # die: o livro rasga pela lombada; as metades despencam pelos lados do atril, a folha voa e cai, as letras apagam e as
    # folhas rasgadas aparecem no chão
    _sclip(arm, "die", 30, {
        "arm_r": [(3, r(0, -20, 0), Z0), (7, r(0, 30, 0), (0.05, -0.02, 0.02)), (12, r(0, 105, 0), (0.1, -0.08, -0.06)), (16, r(0, 96, 0), (0.1, -0.08, -0.06)),
                  (19, r(0, 102, 0), (0.1, -0.08, -0.06))],
        "arm_l": [(3, r(0, 20, 0), Z0), (8, r(0, -30, 0), (-0.05, -0.02, 0.02)), (13, r(0, -105, 0), (-0.1, -0.08, -0.06)), (17, r(0, -96, 0), (-0.1, -0.08, -0.06)),
                  (20, r(0, -102, 0), (-0.1, -0.08, -0.06))],
        "head": [(3, r(0, -60, 0), Z0, ONE), (8, r(30, -150, 20), (0.1, 0.1, 0.35), ONE), (14, r(80, -200, 60), (0.3, -0.2, 0.2), (0.8, 0.8, 0.8)),
                 (20, r(110, -230, 80), (0.45, -0.6, -0.4), (0.4, 0.4, 0.4)), (24, r(120, -240, 90), (0.5, -0.8, -0.7), NIL)],
        "body": [(3, r(-6, 0, 0), Z0), (10, r(8, 0, 4), (0, -0.04, 0)), (16, r(12, 0, 5), (0, -0.06, 0))],
        "core": _sc([(2, 1.6), (6, 0.6), (10, 0.001)]),
        "floor": [(1, Z0, Z0, NIL), (8, Z0, Z0, NIL), (13, Z0, Z0, (0.7, 0.7, 0.7)), (17, Z0, Z0, (1.05, 1.05, 1.05)), (20, Z0, Z0, ONE)]})
    return arm


# ---------------------------------------------------------------------------
# Estante de pé (cobertura da Chamada)
# ---------------------------------------------------------------------------
SHELF_W, SHELF_D, SHELF_H = 2.6, 0.7, 2.5
SHELF_PIVOT = (0, SHELF_D * 0.5, 0.08)       # quina de trás de baixo: a estante tomba para trás (+Y) em volta dela
SHELF_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),                                         # rodapé (fica no chão)
    "body": (SHELF_PIVOT, (0, SHELF_D * 0.5, 0.5), "root"),                         # caixa, prateleiras e o miolo dos livros
    "head": ((0, 0, SHELF_H), (0, 0, SHELF_H + 0.25), "body"),                      # remate com a placa de nomes
    "arm_r": ((0.6, 0, 1.6), (0.6, 0, 1.9), "body"),                                # fileiras de cima, metade +X (saem na queda)
    "arm_l": ((-0.6, 0, 1.6), (-0.6, 0, 1.9), "body"),                              # fileiras de cima, metade -X
    "core": ((0, -0.4, 0.02), (0, -0.4, 0.3), "root"),                              # livros e papel no chão (escala ~0 de pé)
}
SHELF_FALL = -84.0                 # graus (rot x negativo = para trás): deitada, com a frente para cima


def _book_row(P, bone, M, x0, x1, z, depth, hmax, side, seed):
    """Fileira de lombadas entre x0 e x1, numa face (side +1 = frente -Y, -1 = trás)."""
    x, k = x0, seed
    while x < x1 - 0.1:
        k = (k * 7 + 3) % 97
        bw = 0.1 + 0.08 * (k % 5) / 4.0
        if k % 11 == 0:
            x += bw
            continue
        hh = hmax * (0.72 + 0.26 * (k % 7) / 6.0)
        y = -side * (SHELF_D * 0.25)
        P.add(bone, ck.box("bk_%s_%d_%d" % (bone, int(z * 100), int(x * 100) + (0 if side > 0 else 500)), (bw, depth, hh), (x + bw * 0.5, y, z + hh * 0.5), M["books"][k % len(M["books"])]))
        x += bw + 0.012


def archive_shelf(cid="mob_archive_shelf"):
    arm = mk.lp.make_armature("rig_" + cid, SHELF_BONES)
    M = _mats(cid)
    P = _Parts()
    w, d, h = SHELF_W, SHELF_D, SHELF_H
    P.add("root", _flat(ck.box("plinth", (w + 0.1, d + 0.1, 0.08), (0, 0, 0.04), M["wood"])))
    for sx in (-1, 1):                                       # laterais, divisória do meio
        P.add("body", _flat(ck.box("side%d" % sx, (0.09, d, h - 0.08), (sx * (w * 0.5 - 0.045), 0, 0.08 + (h - 0.08) * 0.5), M["wood"])))
    P.add("body", _flat(ck.box("mid", (0.05, d, h - 0.08), (0, 0, 0.08 + (h - 0.08) * 0.5), M["wood"])),
          _flat(ck.box("back", (w - 0.1, 0.05, h - 0.1), (0, 0, 0.08 + (h - 0.1) * 0.5), M["wood_l"])))
    rows = 4
    step = (h - 0.2) / rows
    for i in range(rows + 1):
        P.add("body", _flat(ck.box("board%d" % i, (w - 0.1, d, 0.05), (0, 0, 0.1 + i * step), M["wood"])))
    for i in range(rows):
        z = 0.125 + i * step
        bone_of = lambda x: "body" if i < 2 else ("arm_r" if x > 0 else "arm_l")
        for side in (1, -1):
            for (x0, x1) in ((-w * 0.5 + 0.1, -0.03), (0.03, w * 0.5 - 0.1)):
                _book_row(P, bone_of(x0 + 0.1), M, x0, x1, z, d * 0.42, step - 0.09, side, i * 13 + (5 if side > 0 else 29) + int(x0 * 10))
    # remate: cornija e a placa com nomes riscados (de cima é o que se lê: tampo claro com linhas de tinta)
    P.add("head", _flat(ck.box("cornice", (w + 0.16, d + 0.12, 0.12), (0, 0, h + 0.06), M["wood_l"])))
    P.add("head", _flat(ck.box("crest", (w * 0.42, 0.08, 0.32), (0, 0, h + 0.28), M["wood"])),
          _flat(ck.box("plaque", (w * 0.36, 0.1, 0.22), (0, -0.01, h + 0.28), M["parch"])))
    for k in range(3):
        P.add("head", _flat(ck.box("plaque_line%d" % k, (w * 0.26, 0.11, 0.025), (0, -0.012, h + 0.22 + k * 0.06), M["ink"])))
    for k in range(5):                                       # linhas de nome no tampo (de cima)
        P.add("head", _flat(ck.box("top_line%d" % k, (w * (0.5 + 0.08 * (k % 3)), 0.035, 0.01), (0, -0.25 + k * 0.12, h + 0.125), M["ink"] if k != 2 else M["glow"])))
    # livros e papel caídos no chão à frente (core; escala ~0 de pé)
    for k in range(10):
        a = k * 1.9
        x, y = c(a) * (0.4 + 0.1 * (k % 4)) + (k - 5) * 0.12, -0.35 - 0.2 * (k % 3)
        if k % 3 == 0:
            P.add("core", _flat(ck.box("floor_page%d" % k, (0.3, 0.38, 0.008), (x, y, 0.012), M["parch"])))
        else:
            P.add("core", _flat(ck.box("floor_book%d" % k, (0.36, 0.28, 0.08), (x, y, 0.04 + 0.08 * (k % 2)), M["books"][k % len(M["books"])])))
    P.finish(arm, cid)

    bodyk = lambda seq: [(f, r(a, 0, b), Z0) for f, a, b in seq]
    fallen = lambda f, wob=0.0: (f, r(SHELF_FALL + wob, 0, 0), Z0)
    up_core = lambda end: {"core": [(1, Z0, Z0, NIL), (end, Z0, Z0, NIL)]}       # livros do chão escondidos com a estante de pé
    _sclip(arm, "idle", 64, dict(up_core(64), body=bodyk([(1, 0, 0), (16, 0.6, 0.3), (32, 0, 0), (48, -0.6, -0.3), (64, 0, 0)])), loop=True)
    _sclip(arm, "run", 32, dict(up_core(32)), loop=True)
    _sclip(arm, "attack", 14, dict(up_core(14)))
    _sclip(arm, "hit", 16, dict(up_core(16), body=bodyk([(2, -5, 1.5), (5, 3.5, -1), (9, -1.5, 0.5), (14, 0, 0)]),
                                head=[(2, r(-4, 0, 2), Z0), (6, r(3, 0, -1), Z0), (12, Z0, Z0)]))
    # crack: range, balança e tomba para trás, quica; as fileiras de cima escorregam para fora e os livros aparecem no chão
    spill_r = [(1, Z0, Z0), (6, Z0, Z0), (10, r(0, 0, -16), (0.12, -0.06, -0.1)), (14, r(0, 0, -24), (0.2, -0.12, -0.18)), (18, r(0, 0, -22), (0.2, -0.12, -0.18))]
    spill_l = [(1, Z0, Z0), (6, Z0, Z0), (10, r(0, 0, 16), (-0.12, -0.06, -0.1)), (14, r(0, 0, 24), (-0.2, -0.12, -0.18)), (18, r(0, 0, 22), (-0.2, -0.12, -0.18))]
    crack_body = [(1, Z0, Z0), (3, r(5, 0, 1), Z0), (5, r(-6, 0, -1), Z0), (9, r(-40, 0, 2), Z0), (12, r(SHELF_FALL, 0, 1), Z0), (14, r(SHELF_FALL + 7, 0, 0), Z0),
                  (16, r(SHELF_FALL + 1, 0, 0), Z0), (18, r(SHELF_FALL, 0, 0), Z0)]
    spill = [(1, Z0, Z0, NIL), (9, Z0, Z0, NIL), (12, Z0, (0, 0.06, 0), (0.6, 0.6, 0.6)), (15, Z0, Z0, (1.05, 1.0, 1.05)), (18, Z0, Z0, ONE)]
    _sclip(arm, "crack", 18, {"body": crack_body, "arm_r": spill_r, "arm_l": spill_l, "core": spill,
                              "head": [(1, Z0, Z0), (9, r(-10, 0, 3), Z0), (12, r(14, 0, -4), Z0), (15, r(4, 0, -6), Z0), (18, r(6, 0, -5), Z0)]})
    _sclip(arm, "idle_cracked", 64, {"body": [fallen(1), fallen(32, 0.5), fallen(64)], "arm_r": [(1,) + spill_r[-1][1:], (64,) + spill_r[-1][1:]],
                                     "arm_l": [(1,) + spill_l[-1][1:], (64,) + spill_l[-1][1:]], "core": [(1, Z0, Z0, ONE), (64, Z0, Z0, ONE)],
                                     "head": [(1, r(6, 0, -5), Z0), (32, r(6, 0, -6.5), Z0), (64, r(6, 0, -5), Z0)]}, loop=True)
    _sclip(arm, "die", 24, {"body": crack_body + [(20, r(SHELF_FALL, 0, 0), (0, -0.05, 0)), (24, r(SHELF_FALL, 0, 0), (0, -0.1, 0))],
                            "arm_r": spill_r + [(24, r(0, 0, -30), (0.3, -0.2, -0.24))], "arm_l": spill_l + [(24, r(0, 0, 30), (-0.3, -0.2, -0.24))],
                            "core": spill + [(24, Z0, Z0, ONE)], "head": [(1, Z0, Z0), (9, r(-10, 0, 3), Z0), (13, r(20, 0, -14), (0, -0.05, 0)), (24, r(24, 0, -16), (0, -0.08, 0))]})
    return arm


# ---------------------------------------------------------------------------
# humanoides do kit
# ---------------------------------------------------------------------------
def _dims(base):
    b = base["b"]
    return (base["rig"], b, V(base["head_c"]), b["head"], ck.Z["chest"], ck.Z["waist"], b["chest"] * b["depth"], b["chest"])


def _rigid(objs, rig, bone):
    for o in objs:
        ck.skin_rigid(o, rig, bone)


SCRIBE_STRETCH = (0.16, 0.06)      # pernas, tronco: alto e magro (lumeria_mobs._stretch)


def scribe_parts(cid):
    def add(base, mats):
        rig, b, hc, rr, zc, zw, back, sw = _dims(base)
        front = -back
        M = _mats(cid)
        head, chest, spine = [], [], []
        # capuz de pergaminho (aberto na frente), ponta caída para trás, aro âmbar na boca do capuz
        hood_c = hc + V((0, rr * 0.22, rr * 0.12))
        head.append(lb._open_cap(cid + "_hood", rr * 1.22, hood_c, hc, M["parch_d"], rr * 0.15))
        head.append(mk.cone(cid + "_hood_tip", hood_c + V((0, rr * 0.75, rr * 0.75)), hood_c + V((0, rr * 1.75, rr * 0.05)), rr * 0.45, M["parch_d"], 7))
        # o rosto: uma página de nomes presa na testa, um pouco curvada, com as linhas em tinta e duas acesas
        for k, (dz, wk) in enumerate(((0.62, 1.0), (0.0, 1.06), (-0.62, 0.96))):
            head.append(ck.box("%s_page%d" % (cid, k), (rr * 1.3 * wk, 0.014, rr * 0.66), hc + V((0, -rr * (1.04 - 0.02 * abs(k - 1)), rr * dz)), M["parch"]))
        for k in range(6):
            zz = rr * (0.68 - k * 0.27)
            L = rr * (0.6 + 0.4 * ((k * 5) % 3) / 2.0)
            head.append(ck.box("%s_name%d" % (cid, k), (L, 0.01, rr * 0.055), hc + V((-rr * 0.05, -rr * 1.065, zz)), M["glow"] if k in (1, 4) else M["ink"]))
        head.append(ck.box(cid + "_name_strike", (rr * 0.9, 0.01, rr * 0.04), hc + V((0, -rr * 1.07, rr * 0.68 - 2 * rr * 0.27)), M["ink"]))
        # manto: gola larga de tiras de pergaminho sobre os ombros (o que a câmera alta vê), estola sépia na frente
        for k in range(14):
            a = math.tau * k / 14
            o = V((c(a), s(a) * 0.85, 0))
            root = V((0, 0, ck.Z["neck"] - 0.02)) + o * b["neck"] * 1.3
            tip = V((0, 0, zc - 0.06)) + o * (sw + 0.12) + V((0, 0, -0.02 * (k % 3)))
            chest.append(ck.blade("%s_mantle%d" % (cid, k), root, tip, 0.17, 0.02, M["parch"] if k % 2 else M["parch_d"], o.cross(V((0, 0, 1))), 0.6))
        for sx in (-1, 1):
            chest.append(ck.blade("%s_stole%d" % (cid, sx), V((sx * 0.07, front - 0.03, zc + 0.12)), V((sx * 0.09, front - 0.06, ck.Z["knee"] + 0.02)),
                                  0.12, 0.02, M["sepia_d"], (1, 0, 0), 0.2))
            chest.append(ck.box("%s_stole_hem%d" % (cid, sx), (0.12, 0.025, 0.04), V((sx * 0.09, front - 0.065, ck.Z["knee"] + 0.06)), M["glow"]))
        # o livro aberto preso ao peito do lado ESQUERDO (+X), páginas para a frente e para cima, correia cruzada
        book_c = V((0.11, front - 0.1, zc - 0.04))
        bk = []
        for sx in (-1, 1):
            bk.append(ck.box("%s_bk_cover%d" % (cid, sx), (0.17, 0.02, 0.24), V((sx * 0.085, 0, 0)), M["leather"]))
            bk.append(ck.box("%s_bk_pages%d" % (cid, sx), (0.15, 0.03, 0.22), V((sx * 0.08, -0.02, 0)), M["parch"]))
            for k in range(4):
                bk.append(ck.box("%s_bk_line%d_%d" % (cid, sx, k), (0.1, 0.006, 0.014), V((sx * 0.08, -0.037, 0.07 - k * 0.045)), M["glow"] if (k + sx) % 3 == 0 else M["ink"]))
        for o in bk:
            o.data.transform(Matrix.Translation(book_c) @ Matrix.Rotation(math.radians(-32), 4, "X") @ Matrix.Rotation(math.radians(12), 4, "Z"))
        chest += bk
        chest.append(ck.tube(cid + "_strap", V((-sw * 0.85, front - 0.02, zc + 0.16)), book_c + V((0.02, 0.03, -0.1)), 0.018, 0.018, M["leather"], 5))
        chest.append(ck.tube(cid + "_chain", book_c + V((-0.1, 0.0, -0.12)), V((-0.05, front - 0.04, zw)), 0.012, 0.012, M["brass"], 4))
        # nas costas: rolo de nomes comprido pendurado (de cima lê-se como uma faixa clara) e o tinteiro na cintura
        chest.append(ck.tube(cid + "_scroll", V((-0.2, back + 0.08, zc + 0.12)), V((0.2, back + 0.08, zc + 0.12)), 0.05, 0.05, M["parch_d"], 8))
        chest.append(ck.blade(cid + "_scroll_tail", V((0.0, back + 0.1, zc + 0.08)), V((0.04, back + 0.2, ck.Z["knee"] - 0.05)), 0.3, 0.015, M["parch"], (1, 0, 0), 0.15))
        for k in range(5):
            chest.append(ck.box("%s_scroll_line%d" % (cid, k), (0.2, 0.01, 0.018), V((0.02, back + 0.12 + k * 0.012, zc - 0.05 - k * 0.12)), M["ink"]))
        spine.append(ck.ball(cid + "_inkpot", 0.06, V((-sw * 0.6, front * 0.6, zw - 0.04)), M["ink"], (1, 1, 1.1)))
        spine.append(ck.tube(cid + "_inkpot_neck", V((-sw * 0.6, front * 0.6, zw + 0.01)), V((-sw * 0.6, front * 0.6, zw + 0.05)), 0.03, 0.03, M["brass"], 6))
        _rigid([ck._join(head, cid + "_x_head")], rig, "head")          # uma malha por osso (menos draw calls)
        _rigid([ck._join(chest, cid + "_x_chest")], rig, "chest")
        _rigid([ck._join(spine, cid + "_x_spine")], rig, "spine")
    return add


def scribe_quill(cid):
    """Depois das armas: o cajado do kit vira a pena-lança (mesma mão, mesmo eixo): haste escura manchada de tinta, pena
    grande de pergaminho e a ponta de metal com filete âmbar (o lado que fere)."""
    def add(base, mats):
        om._drop(("wpn_main_",))
        M = _mats(cid)
        g = V(ck.hand_center(base, ".R"))
        up = V((-0.22, -0.12, 1.0)).normalized()
        side = up.cross(V((0, 1, 0))).normalized()
        low, top = g - up * 0.42, g + up * 1.72
        parts = [ck.tube("shaft", low, top, 0.035, 0.028, M["wood"], 6),
                 ck.tube("grip", g - up * 0.12, g + up * 0.14, 0.045, 0.045, M["ink"], 6),
                 ck.tube("ferrule", low - up * 0.05, low + up * 0.06, 0.045, 0.04, M["brass"], 6),
                 ck.tube("collar", top - up * 0.04, top + up * 0.06, 0.05, 0.045, M["brass"], 6),
                 ck.blade("nib", top + up * 0.04, top + up * 0.5, 0.15, 0.04, M["ink"], side, 0.3),
                 ck.blade("nib_edge", top + up * 0.06, top + up * 0.5, 0.17, 0.02, M["glow"], side, 0.3),
                 ck.blade("vane_a", g + up * 0.5, top - up * 0.02, 0.42, 0.02, M["parch"], side, 0.62),
                 ck.blade("vane_b", g + up * 0.62, top - up * 0.14, 0.3, 0.025, M["parch_d"], side, 0.5),
                 ck.blade("vane_tip", top - up * 0.36, top - up * 0.02, 0.2, 0.03, M["ink"], side, 0.4)]
        for k in range(5):                                   # farpas: riscos escuros cruzando a pena
            q = g + up * (0.66 + k * 0.2)
            parts.append(ck.tube("barb%d" % k, q - side * 0.17, q + side * 0.19 + up * 0.08, 0.008, 0.008, M["sepia_d"], 4))
        obj = ck._join(parts, "wpn_main_staff")
        ck._smooth(obj.data)
        ck.skin_rigid(obj, base["rig"], "hand.R")
    return add


SCRIBE_READ_IMPACT = 14            # = chibi_kit.IMPACT["cast_channel"] (EntityView.IMPACT_FRAME)


def _scribe_channel(rig):
    """Ler um Nome: troca o `cast_channel` do kit. A cabeça desce sobre o livro do peito, a mão esquerda segura a página, a
    pena-lança sobe e "escreve" no ar em três traços (o do quadro 14 é o nome lido); volta à guarda no fim."""
    R = dict(ck.READY)
    legs = {"thigh.R": (-8, 0, 4), "shin.R": (10, 0, 0), "thigh.L": (4, 0, -4), "shin.L": (8, 0, 0)}
    read = dict(R, **legs, **{"spine": (8, 0, 0), "chest": (6, 0, 4), "neck": (8, 0, 0), "head": (22, 0, -10),
                              "upper_arm.L": (-58, 0, 12), "forearm.L": (-78, 0, 0), "hand.L": (0, 0, 20),
                              "upper_arm.R": (-70, 10, 26), "forearm.R": (-36, 0, 0), "hand.R": (40, 0, -20)})
    write_a = dict(read, **{"upper_arm.R": (-84, 14, 30), "forearm.R": (-24, 0, 0), "hand.R": (30, 0, -34), "head": (24, 0, -6)})
    write_b = dict(read, **{"upper_arm.R": (-62, 6, 18), "forearm.R": (-48, 0, 0), "hand.R": (52, 0, -10), "head": (20, 0, -12)})
    ck._pose_action(rig, "cast_channel", [(1, R, None), (5, read, (0, 0.01, -0.02)), (9, write_a, (0, 0.02, -0.02)),
                                          (SCRIBE_READ_IMPACT, write_b, (0, 0, -0.03)), (19, write_a, (0, 0.02, -0.02)), (24, write_b, (0, 0, -0.03)),
                                          (29, write_a, (0, 0.02, -0.02)), (34, read, (0, 0.01, -0.02)), (40, R, None)], 40)


def azhar_scribe(cid="mob_azhar_scribe"):
    saved = lm._stretch(*SCRIBE_STRETCH)
    try:
        rig = mk.humanoid(cid, "cloth", SEPIA, "staff", skin=(0.62, 0.58, 0.52), eye=AMBER, hide_hair=True, head="none", attack="atk_2h",
                          extra=scribe_parts(cid), after=scribe_quill(cid))
        _scribe_channel(rig)
        return mk.act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.2}, "hand.R", ("wpn_main_",), front=True)
    finally:
        ck.Z.clear()
        ck.Z.update(saved)


def copyist_parts(cid):
    def add(base, mats):
        rig, b, hc, rr, zc, zw, back, sw = _dims(base)
        front = -back
        M = _mats(cid)
        head, chest = [], []
        # capuz baixo sépia e a venda de pano escuro com letras claras sobre os olhos (a marca do Copista Sem Olhos)
        hood_c = hc + V((0, rr * 0.2, rr * 0.16))
        head.append(lb._open_cap(cid + "_hood", rr * 1.16, hood_c, hc, M["sepia"], rr * 0.05))
        band = _hoop(cid + "_band", (0, 0, 0), rr * 1.03, rr * 0.11, M["sepia_d"], 18, 5)
        band.data.transform(Matrix.Translation(hc + V((0, 0, rr * 0.1))))
        head.append(band)
        for k in range(3):
            head.append(ck.box("%s_band_mark%d" % (cid, k), (rr * 0.18, 0.01, rr * 0.05), hc + V(((k - 1) * rr * 0.3, -rr * 1.11, rr * 0.1)), M["parch"]))
        for sx in (-1, 1):
            head.append(ck.blade("%s_band_tail%d" % (cid, sx), hc + V((sx * 0.03, rr * 1.0, rr * 0.08)), hc + V((sx * 0.1, rr * 1.5, -rr * 0.6)),
                                 rr * 0.22, 0.015, M["sepia_d"], (1, 0, 0), 0.3))
        # avental de escriba com manchas de tinta, bolsa de rolos na cintura
        chest.append(ck.blade(cid + "_apron", V((0, front - 0.035, zw + 0.06)), V((0, front - 0.06, ck.Z["knee"] + 0.04)), 0.3, 0.02, M["parch_d"], (1, 0, 0), 0.25))
        for k in range(3):
            chest.append(ck.ball("%s_blot%d" % (cid, k), 0.035 + 0.01 * k, V(((k - 1) * 0.07, front - 0.07, zw - 0.08 - k * 0.07)), M["ink"], (1.2, 0.3, 1.0)))
        chest.append(ck.tube(cid + "_case", V((sw * 0.7, back + 0.04, zc + 0.2)), V((-sw * 0.4, back + 0.06, zw - 0.1)), 0.06, 0.06, M["leather"], 8))
        _rigid([ck._join(head, cid + "_x_head")], rig, "head")
        _rigid([ck._join(chest, cid + "_x_chest")], rig, "chest")
    return add


def copyist_tools(cid):
    """Depois das armas: a varinha vira uma pena grande; na mão esquerda, a prancheta com a folha."""
    def add(base, mats):
        om._drop(("wpn_main_",))
        M = _mats(cid)
        g = V(ck.hand_center(base, ".R"))
        up = V((-0.2, -0.3, 1.0)).normalized()
        side = up.cross(V((0, 1, 0))).normalized()
        parts = [ck.tube("quill_shaft", g - up * 0.08, g + up * 0.5, 0.016, 0.01, M["parch_d"], 5),
                 ck.blade("quill_vane", g + up * 0.12, g + up * 0.58, 0.16, 0.015, M["parch"], side, 0.55),
                 ck.blade("quill_nib", g - up * 0.08, g - up * 0.2, 0.04, 0.015, M["ink"], side, 0.3)]
        obj = ck._join(parts, "wpn_main_wand")
        ck._smooth(obj.data)
        ck.skin_rigid(obj, base["rig"], "hand.R")
        gl = V(ck.hand_center(base, ".L"))
        board = [ck.box("board", (0.26, 0.02, 0.34), gl + V((0.02, -0.06, 0.04)), M["wood_l"]),
                 ck.box("board_sheet", (0.22, 0.012, 0.28), gl + V((0.02, -0.075, 0.04)), M["parch"]),
                 ck.box("board_clip", (0.08, 0.03, 0.03), gl + V((0.02, -0.075, 0.2)), M["brass"])]
        for k in range(4):
            board.append(ck.box("board_line%d" % k, (0.15, 0.006, 0.012), gl + V((0.02, -0.083, 0.12 - k * 0.05)), M["ink"]))
        obj = ck._join(board, "arch_copyist_board")
        ck.skin_rigid(obj, base["rig"], "hand.L")
    return add


def blind_copyist(cid="mob_blind_copyist"):
    return mk.humanoid(cid, "cloth", SEPIA, "wand", skin=(0.74, 0.7, 0.64), hide_hair=True, head="none",
                       extra=copyist_parts(cid), after=copyist_tools(cid))


# O Escrivão é chefe: guarda os gestos de chefe (MOB_BOSS_KEEP: cast_ground, cast_channel, atk_sweep, summon, shout...)
mk.BOSS_HUMANOIDS.add("mob_azhar_scribe")

# nome do GLB -> construtor; HUMANOIDS saem por chibi_kit.export_glb (malha skinned)
BUILDERS = {
    "mob_azhar_scribe": azhar_scribe,
    "mob_name_ledger": name_ledger,
    "mob_archive_shelf": archive_shelf,
    "mob_blind_copyist": blind_copyist,
}
HUMANOIDS = {"mob_azhar_scribe", "mob_blind_copyist"}
