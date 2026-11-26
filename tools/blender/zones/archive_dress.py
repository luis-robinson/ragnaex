"""Acabamento do Arquivo de Vel'Thar (dg_archive; Campo dos Juramentos, GDD design/gdd/arquivo-de-velthar.md §3.2 e §9):
os salões onde Vel'Thar guardava o registro de cada nascido e de cada morto, debaixo do zigurate. Chamado pelo
build_dungeons (tabela `DRESS`), depois da rocha e antes do `z.finish`; salões e ligações vêm de places.DUNGEONS["dg_archive"].

Cada salão lê-se de cima pela cor do chão e pelo que há na parede:
  degraus   (Degraus do Zigurate)    pedra clara, faixas de degraus pintadas em tons do chão descendo da chegada,
                                     arquibancada de degraus de pedra na parede, estelas de nomes e colunas partidas
  registros (Salão dos Registros)    papel velho; estantes altas em raios (corredores de arquivo) e escaninhos de rolos na
                                     parede; o miolo fica livre para a colheita da Página de Vorhag (3 m de raio sem sólido)
  leitura   (Sala de Leitura)        tábua clara; estantes BAIXAS encostadas na parede, mesas de copista com banquinho junto
                                     à parede e os 3 pousos dos Livros de Nomes (lacaios `name_ledger` parados, um spawner por
                                     pouso, raio 0,5; o atril é do modelo `mob_name_ledger`)
  mesa      (A Mesa do Escrivão)     anéis de leitura em tons do chão, a Mesa (visual, SEM colisor) com o rolo desenrolado
                                     até o meio, estantes altas e faixas de nomes riscados SÓ na parede; os 4 pousos do anel
                                     dos livros (r 7) e os 4 pontos de estante (cobertura da Chamada, ~10 m a 45/135/225/315)

Regras de chão (art review 2026-11-13): tinta de chão só em tons do PRÓPRIO chão (`Halls.tones`), nada de anel saturado
nem `glow_*` no chão; poças de tinta FOSCAS (cinza-tinta, não preto puro) e pequenas. Brilho só nas lamparinas âmbar
(`glow_lamparina`, o `glow` da dungeon) penduradas na parede e nos postes; velas apagadas.

Pilha de planos nos salões (mm): praça 14 · chão do salão 20 · manchas 22,2-22,6 · faixas de degrau/anéis 23,0-23,2 ·
pousos 23,4-23,7 · poça de tinta 24,0 · papel solto (caixa fina) a partir de 24,4.

Grava data["boss_hint"]: `adds` = os 4 pousos do anel dos livros (MonsterDef.eggs r 7, ângulo 0,3 rad + i*90),
`cover` = os 4 pontos de estante (relativos ao ponto de nascer: 10 m a 45/135/225/315 graus), `ledgers` = os 3 pousos da
Sala de Leitura, `gather` = o ponto da Página de Vorhag, `clear_r`.
"""
import math

from mathutils import Vector

from act2_dress import Halls
from act3_dress import P, tang, stains, opposite, _hint, _floors
from build_lumeria import loc
from dress import Dress

AMBER = (0.86, 0.7, 0.42)          # places.DUNGEONS["dg_archive"]["glow"]
STONE = (0.66, 0.62, 0.53)
STONE_L = (0.76, 0.72, 0.62)
STONE_D = (0.46, 0.42, 0.36)
WOOD = (0.4, 0.29, 0.2)            # madeira escura das estantes
WOOD_L = (0.55, 0.41, 0.27)
PAPER = (0.9, 0.84, 0.69)
PAPER_D = (0.76, 0.68, 0.52)
INK = (0.17, 0.15, 0.14)           # tinta das letras e pavios
INK_POOL = (0.27, 0.24, 0.22)      # poça de tinta derramada: fosca e cinza-tinta (preto puro lê como buraco no toon)
WAX = (0.88, 0.84, 0.74)
BRASS = (0.6, 0.48, 0.28)
BOOKS = ((0.52, 0.26, 0.2), (0.32, 0.36, 0.27), (0.58, 0.44, 0.24), (0.33, 0.28, 0.38), (0.64, 0.52, 0.36), (0.42, 0.3, 0.22),
         (0.7, 0.62, 0.46))
INK_Y = 0.0240
EGG_R = 7.0                        # = boss_azhar_scribe.eggs["r"] (monsters_catalog): anel dos Livros de Nomes na Mesa
COVER_D = 10.0                     # distância dos 4 pontos de estante ao ponto de nascer
COVER_ANGLES = (45.0, 135.0, 225.0, 315.0)
LEDGERS = 3
GATHER_FREE = 3.0                  # miolo do Salão dos Registros sem sólido (a página nasce no centro, raio 6 do GATHER)


def book_row(d, c, rot, w, y0, depth, hmax, g="estante", gap=0.12):
    """Fileira de lombadas num vão de estante: livros em pé de largura/altura sorteadas, às vezes um vão ou um deitado."""
    x = -w * 0.5 + 0.03
    while x < w * 0.5 - 0.08:
        bw = d.rnd.uniform(0.12, 0.26)                       # largo: de cima a lombada é só cor (menos caixas no GLB)
        if x + bw > w * 0.5 - 0.03:
            break
        k = d.rnd.random()
        col = BOOKS[d.rnd.randrange(len(BOOKS))]
        m = d.m("livro_%d_%d_%d" % (int(col[0] * 100), int(col[1] * 100), int(col[2] * 100)), col)
        if k < gap:                                          # vão (livro levado)
            x += bw
            continue
        if k < gap + 0.06:                                   # livro deitado na prateleira
            d.box(g, m, loc(c, rot, x + 0.12, 0.0), (0.26, 0.06, depth * 0.8), rot, y0)
            x += 0.28
            continue
        hh = hmax * d.rnd.uniform(0.7, 0.98)
        d.box(g, m, loc(c, rot, x + bw * 0.5, 0.02), (bw, hh, depth * 0.82), rot + d.rnd.uniform(-4, 4), y0)
        x += bw + 0.01


def bookshelf(d, c, rot, w=2.2, h=2.5, depth=0.55, rows=4, g="estante", wood=WOOD):
    """Estante de pé: laterais, fundo, prateleiras e fileiras de livros; a frente (+yb) olha para `rot` + 90 (tang)."""
    m, ml = d.m("estante_%d" % int(wood[0] * 100), wood), d.m("estante_clara", WOOD_L)
    back = d.m("estante_fundo", tuple(k * 0.75 for k in wood))
    d.box(g, back, loc(c, rot, 0.0, -depth * 0.45), (w, h, 0.06), rot, 0.0)
    for s in (-1, 1):
        d.box(g, m, loc(c, rot, s * (w * 0.5 - 0.05), 0.0), (0.1, h, depth), rot, 0.0)
    d.box(g, ml, c, (w + 0.14, 0.12, depth + 0.1), rot, h)                     # cornija
    step = (h - 0.2) / rows
    for i in range(rows):
        y = 0.1 + i * step
        d.box(g, m, c, (w - 0.1, 0.05, depth), rot, y)
        book_row(d, c, rot, w - 0.2, y + 0.05, depth, step - 0.1, g)


def scroll_rack(d, c, rot, w=2.4, h=2.3, g="escaninho"):
    """Escaninho de rolos: grade de madeira com a ponta dos rolos (papel) para fora."""
    m = d.m("estante_%d" % int(WOOD[0] * 100), WOOD)
    pm = d.m("rolo", PAPER)
    pd = d.m("rolo_esc", PAPER_D)
    d.box(g, d.m("estante_fundo", tuple(k * 0.75 for k in WOOD)), loc(c, rot, 0.0, -0.22), (w, h, 0.06), rot, 0.0)
    nx, ny = int(w / 0.4), int(h / 0.4)
    for i in range(nx + 1):
        d.box(g, m, loc(c, rot, -w * 0.5 + i * w / nx, 0.0), (0.05, h, 0.48), rot, 0.0)
    for j in range(ny + 1):
        d.box(g, m, c, (w, 0.05, 0.48), rot, j * h / ny)
    for i in range(nx):
        for j in range(ny):
            if d.rnd.random() < 0.18:
                continue
            for k in range(d.rnd.randint(1, 3)):
                q = loc(c, rot, -w * 0.5 + (i + 0.5) * w / nx + d.rnd.uniform(-0.08, 0.08), -0.18)
                d.cyl(g, pm if k % 2 == 0 else pd, q, 0.05, 0.05, 0.5, (j + 0.5) * h / ny - 0.05 + d.rnd.uniform(-0.04, 0.04), 5, rot, (-90, 0))


def book_pile(d, c, n=None, g="pilha", lean=True):
    """Pilha de livros no chão, cada um girado um pouco."""
    n = n or d.rnd.randint(3, 7)
    y = 0.0
    rot = d.rnd.uniform(0, 180)
    for i in range(n):
        col = BOOKS[d.rnd.randrange(len(BOOKS))]
        hh = d.rnd.uniform(0.07, 0.13)
        sx, sz = d.rnd.uniform(0.34, 0.5), d.rnd.uniform(0.26, 0.36)
        d.box(g, d.m("livro_%d_%d_%d" % (int(col[0] * 100), int(col[1] * 100), int(col[2] * 100)), col),
              (c[0] + d.rnd.uniform(-0.04, 0.04), c[1] + d.rnd.uniform(-0.04, 0.04)), (sx, hh, sz), rot + d.rnd.uniform(-18, 18), y)
        d.box(g, d.m("folhas", PAPER), (c[0], c[1]), (sx - 0.05, hh * 0.7, sz - 0.04), rot, y + hh * 0.15)
        y += hh


def papers(d, c, n, spread, g="papel"):
    """Folhas soltas no chão (caixas finas, acima da pilha de planos)."""
    for i in range(n):
        q = (c[0] + d.rnd.uniform(-spread, spread), c[1] + d.rnd.uniform(-spread, spread))
        d.box(g, d.m("papel_solto" if i % 3 else "papel_solto_esc", PAPER if i % 3 else PAPER_D), q, (d.rnd.uniform(0.28, 0.42), 0.008, d.rnd.uniform(0.36, 0.5)),
              d.rnd.uniform(0, 180), 0.0244 + 0.0012 * (i % 4))


def ink_pool(d, c, r, rim, g="tinta"):
    """Poça de tinta derramada, FOSCA: borda no tom escuro do chão e a tinta cinza-escura (não brilha, não é anel)."""
    d.blob(g, rim, c, r * 1.25, INK_Y - 0.0004, 0.3)
    d.blob(g, d.m("patch_tinta", INK_POOL), c, r, INK_Y, 0.32)


def candle_stand(d, c, h=1.5, n=3):
    """Castiçal de latão com velas APAGADAS (pavio escuro, cera escorrida)."""
    br = d.m("latao", BRASS)
    d.cyl("castical", br, c, 0.2, 0.08, 0.12, 0.0, 6)
    d.cyl("castical", br, c, 0.045, 0.045, h, 0.1, 5)
    for k in range(n):
        q = P(c, 0.22 if n > 1 else 0.0, 120.0 * k + 15.0)
        d.cyl("castical", br, q, 0.05, 0.08, 0.06, h, 5)
        hh = d.rnd.uniform(0.12, 0.3)
        d.cyl("castical", d.m("cera", WAX), q, 0.045, 0.04, hh, h + 0.05, 5)
        d.cyl("castical", d.m("pavio", INK), q, 0.012, 0.012, 0.05, h + 0.05 + hh, 3)


def oil_lamp(d, c, h=2.4, out=0.0):
    """Lamparina âmbar num gancho de ferro (a luz da masmorra; só a chama brilha)."""
    iron = d.m("ferro_gancho", (0.3, 0.28, 0.26))
    d.cyl("lamparina", iron, c, 0.08, 0.06, h, 0.0, 5)
    q = (c[0] + math.cos(out) * 0.45, c[1] + math.sin(out) * 0.45)
    d.tube("lamparina", iron, [(c[0], h, c[1]), (q[0], h + 0.1, q[1]), (q[0], h - 0.1, q[1])], 0.035, 0.03, 4)
    d.cyl("lamparina", d.m("latao", BRASS), q, 0.06, 0.16, 0.16, h - 0.5, 6)
    d.cyl("lamparina", d.m("glow_lamparina", AMBER), q, 0.13, 0.06, 0.2, h - 0.34, 6)
    d.cyl("lamparina", d.m("latao", BRASS), q, 0.15, 0.03, 0.12, h - 0.14, 6)


def stele(d, c, rot, h=2.2, w=1.1, g="estela"):
    """Estela de nomes: laje de pedra com linhas de nomes e alguns riscados (tinta fosca)."""
    st, sd = d.m("pedra_arquivo", STONE), d.m("pedra_arquivo_esc", STONE_D)
    d.box(g, sd, c, (w + 0.3, 0.25, 0.6), rot, 0.0)
    d.box(g, st, c, (w, h, 0.28), rot, 0.25)
    d.cyl(g, st, c, w * 0.5, w * 0.5, 0.28, 0.25 + h - 0.1, 8, rot, (90, 0))
    ink = d.m("pedra_entalhe", tuple(k * 0.55 for k in STONE))
    for i in range(6):
        y = 0.55 + i * (h - 0.6) / 6
        ww = w * d.rnd.uniform(0.5, 0.8)
        d.box(g, ink, loc(c, rot, d.rnd.uniform(-0.08, 0.08), 0.15), (ww, 0.05, 0.02), rot, y)
        if d.rnd.random() < 0.4:                              # nome riscado
            d.box(g, d.m("pavio", INK), loc(c, rot, 0.0, 0.165), (ww + 0.12, 0.035, 0.02), rot, y + 0.01, (0, d.rnd.choice((-8, 8))))


def name_banner(d, c, rot, h=3.2, w=0.9, drop=2.4, g="faixa"):
    """Faixa de nomes pendurada na parede: pano de papel com as linhas de nomes riscados."""
    d.cyl(g, d.m("estante_%d" % int(WOOD[0] * 100), WOOD), loc(c, rot, -(w + 0.3) * 0.5, 0.0), 0.04, 0.04, w + 0.3, h, 4, rot, (0, 90))
    d.cloth(g, d.m("faixa_papel", PAPER), c, w, drop, rot, h - drop - 0.05, -w * 0.5, "teeth", d.m("faixa_papel_esc", PAPER_D))
    for i in range(5):
        y = h - 0.35 - i * drop / 6.0
        d.box(g, d.m("pavio", INK), loc(c, rot, d.rnd.uniform(-0.05, 0.05), 0.07), (w * d.rnd.uniform(0.5, 0.75), 0.04, 0.015), rot, y,
              (0, d.rnd.choice((-6, 0, 6))))


def writing_desk(d, c, rot, w=1.6, g="escrivaninha", stool=True):
    """Mesa de copista: tampo inclinado com folha, tinteiro e pena; banquinho na frente (+yb)."""
    m, ml = d.m("estante_%d" % int(WOOD[0] * 100), WOOD), d.m("estante_clara", WOOD_L)
    for sx in (-1, 1):
        for sy in (-1, 1):
            d.box(g, m, loc(c, rot, sx * (w * 0.5 - 0.1), sy * 0.25), (0.08, 0.8, 0.08), rot, 0.0)
    d.box(g, ml, c, (w, 0.07, 0.7), rot, 0.8, (-12, 0))
    d.box(g, d.m("folhas", PAPER), loc(c, rot, -0.15, 0.03), (0.42, 0.02, 0.5), rot + 6.0, 0.87, (-12, 0))
    q = loc(c, rot, w * 0.32, -0.12)
    d.cyl(g, d.m("pavio", INK), q, 0.07, 0.06, 0.1, 0.88, 6)
    d.cyl(g, d.m("pena", (0.92, 0.9, 0.84)), q, 0.025, 0.0, 0.45, 0.96, 3, rot, (0, 28))
    if stool:
        d.cyl(g, m, loc(c, rot, 0.0, 0.75), 0.22, 0.2, 0.5, 0.0, 6)


def scribe_desk(d, c, rot, rim):
    """A Mesa do Escrivão (só visual): tampo largo, pilhas de livros, tinteiro grande, castiçais apagados e o rolo de nomes
    que desce da borda e se desenrola pelo chão até o meio da sala (fita em tom de papel, acima da pilha de planos)."""
    m, ml = d.m("estante_%d" % int(WOOD[0] * 100), WOOD), d.m("estante_clara", WOOD_L)
    st = d.m("pedra_arquivo", STONE)
    d.box("mesa", st, c, (3.4, 0.16, 1.6), rot, 0.0)                         # tablado de pedra baixo
    for sx in (-1, 1):
        d.box("mesa", m, loc(c, rot, sx * 1.35, 0.0), (0.3, 0.86, 1.1), rot, 0.16)
    d.box("mesa", ml, c, (3.1, 0.1, 1.3), rot, 1.02)
    d.box("mesa", m, loc(c, rot, 0.0, -0.55), (3.0, 0.5, 0.12), rot, 1.12)     # anteparo de trás
    for sx in (-1.1, 0.9):
        book_pile(d, loc(c, rot, sx, -0.2), 5, g="mesa")
    d.box("mesa", d.m("folhas", PAPER), loc(c, rot, -0.1, 0.15), (1.0, 0.04, 0.7), rot + 4.0, 1.12)
    d.box("mesa", d.m("livro_aberto", PAPER_D), loc(c, rot, -0.1, 0.15), (1.1, 0.02, 0.76), rot + 4.0, 1.11)
    q = loc(c, rot, 0.55, 0.2)
    d.cyl("mesa", d.m("pavio", INK), q, 0.14, 0.11, 0.18, 1.12, 8)
    d.cyl("mesa", d.m("pena", (0.92, 0.9, 0.84)), q, 0.05, 0.0, 0.9, 1.25, 3, rot, (0, 30))
    for sx in (-1, 1):
        candle_stand(d, loc(c, rot, sx * 1.75, -0.4), 1.5, 3)
    pts = [Vector(loc(c, rot, 0.2, 0.75))]                                    # o rolo desenrolado no chão
    for i in range(1, 8):
        u = i / 7.0
        pts.append(Vector(loc(c, rot, 0.2 + 0.5 * math.sin(u * 3.2), 0.75 + u * 4.2)))
    d.strip("rolo", d.m("patch_rolo", PAPER), pts, 0.62, 0.0244)
    for i in range(1, 7):
        a, b = pts[i], pts[i + 1]
        t = (b - a).normalized()
        n = Vector((-t.y, t.x))
        mid = a.lerp(b, 0.5)
        d.strip("rolo", d.m("patch_rolo_nome", INK), [mid - n * 0.2, mid + n * (0.05 + 0.15 * (i % 2))], 0.05, 0.0248)
    d.cyl("rolo", d.m("rolo", PAPER), (pts[-1].x, pts[-1].y), 0.11, 0.11, 0.7, 0.11, 6, math.degrees(math.atan2(-(pts[-1] - pts[-2]).y, (pts[-1] - pts[-2]).x)), (90, 0))
    ink_pool(d, loc(c, rot, 1.9, 0.6), 0.55, rim)


def steps(d, c, rot, w, n=3, tread=0.6, rise=0.3, g="degrau"):
    """Arquibancada de degraus de pedra encostada na parede: n degraus que sobem para o fundo (-yb)."""
    st, sl = d.m("pedra_arquivo", STONE), d.m("pedra_arquivo_clara", STONE_L)
    for i in range(n):
        d.box(g, st if i % 2 else sl, loc(c, rot, 0.0, -i * tread), (w - i * 0.3, rise * (i + 1), tread + 0.02), rot, 0.0)


def archive(z, rooms, edges):
    _floors(z, rooms)
    d = Dress(z, 937)
    rnd = d.rnd
    h = Halls(d, rooms, edges)
    T = {name: h.tones(name, 0.12) for name in rooms}
    for name, room in rooms.items():                         # manchas em tons do chão e papel solto pelo salão
        if name == "chegada":
            continue
        stains(d, h, name, room, int(room["r"] * (0.2 if name in ("mesa", "leitura") else 0.45)), "arq", 0.045, 0.8, 1.6)

    def side(q, ang):
        k = rnd.random()
        rot = math.degrees(-ang)
        if k < 0.3:
            oil_lamp(d, q, rnd.uniform(2.2, 2.6), ang + math.pi * 0.5)
        elif k < 0.55:
            book_pile(d, q)
            papers(d, q, 3, 0.8)
        elif k < 0.78:
            stele(d, q, rot, rnd.uniform(1.6, 2.1), 0.9)
        else:
            candle_stand(d, q, rnd.uniform(1.2, 1.6), 3)
    h.corridor(side, every=3.2)
    cx, cy = rooms["chegada"]["pos"]
    st, sd = d.m("pedra_arquivo", STONE), d.m("pedra_arquivo_esc", STONE_D)
    for s in (-1, 1):                                        # chegada: batentes de pedra sobre a saída e duas lamparinas
        oil_lamp(d, (cx + s * 4.6, cy + 1.5), 2.8, math.pi * (0.5 + 0.5 * s))
        d.box("arco", sd, (cx + s * 3.2, cy + 6.2), (1.0, 3.4, 1.0), 0.0, 0.0)
        stele(d, (cx + s * 5.6, cy - 2.4), 90.0 * s, 2.0, 1.0)
    d.box("arco", st, (cx, cy + 6.2), (7.4, 0.7, 1.2), 0.0, 3.4)

    # ---- Degraus do Zigurate: faixas de degraus pintadas descendo da chegada, arquibancada de pedra na parede, estelas e
    #      colunas partidas ----
    room = rooms["degraus"]
    x, y = room["pos"]
    r = room["r"]
    tones = T["degraus"]
    for i in range(7):                                       # faixas transversais (degraus vistos de cima), em tons do chão
        yy = y + r * 0.72 - i * r * 0.24
        half = math.sqrt(max(0.0, (r * 0.86) ** 2 - (yy - y) ** 2)) * 0.92
        if half < 1.5:
            continue
        d.strip("degraus", tones[1], [Vector((x - half, yy)), Vector((x, yy - 0.15)), Vector((x + half, yy))], 1.5, 0.0230)
        d.strip("degraus", tones[0], [Vector((x - half, yy + 0.95)), Vector((x, yy + 0.8)), Vector((x + half, yy + 0.95))], 0.4, 0.0232)
    for j, (p, a) in enumerate(h.rim("degraus", 14, 0.88, 0.9, 0.5)):
        rot = tang(a)
        if j % 3 == 0:
            steps(d, p, rot, 3.0, 3)
            d.solid(p[0], p[1], 3.0, 1.9, 0.9, rot)
        elif j % 3 == 1:
            stele(d, p, rot, rnd.uniform(2.2, 2.8), 1.2)
            d.solid(p[0], p[1], 1.5, 0.7, 2.4, rot)
        else:                                                # coluna partida (base, fuste curto e o tambor caído)
            d.cyl("coluna", st, p, 0.62, 0.62, 0.3, 0.0, 8)
            d.cyl("coluna", d.m("pedra_arquivo_clara", STONE_L), p, 0.48, 0.46, rnd.uniform(1.0, 2.2), 0.3, 8)
            q = P(p, 1.2, math.degrees(a) + 180.0 + rnd.uniform(-30, 30))
            d.cyl("coluna", d.m("pedra_arquivo_clara", STONE_L), q, 0.46, 0.46, 0.9, 0.46, 8, rnd.uniform(0, 180), (90, 0))
            d.solid(p[0], p[1], 1.3, 1.3, 2.0)
    for (p, a) in h.rim("degraus", 10, 0.98, 1.02, 0.5):
        oil_lamp(d, p, 2.6, a + math.pi)
    for (p, a) in h.rim("degraus", 8, 0.68, 0.78, 0.5):
        if h.put(p, 0.6):
            papers(d, p, 3, 0.7)

    # ---- Salão dos Registros: estantes altas em raios (corredores de arquivo), escaninhos de rolos na parede, tinta
    #      derramada; o miolo (GATHER_FREE) livre para a Página de Vorhag ----
    room = rooms["registros"]
    x, y = room["pos"]
    r = room["r"]
    tones = T["registros"]
    ms = h.mouths("registros")
    rays = []
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        if any(abs(math.atan2(math.sin(a - m), math.cos(a - m))) < 0.62 for m in ms):
            continue
        rays.append(a)
    for a in rays:                                           # estante dupla em raio, de r*0.42 até r*0.84 (frente nos dois lados)
        L = r * 0.4
        c0 = P((x, y), r * 0.63, math.degrees(a))
        rot = math.degrees(-a)                               # x local corre ao longo do raio
        for s in (-1, 1):
            bookshelf(d, loc(c0, rot, 0.0, s * 0.3), rot + (0.0 if s > 0 else 180.0), L, 2.7, 0.5, 5)
        d.solid(c0[0], c0[1], L + 0.2, 1.3, 2.8, rot)
        papers(d, P((x, y), r * 0.38, math.degrees(a) + 14.0), 2, 0.4)
    for j, (p, a) in enumerate(h.rim("registros", 12, 0.97, 1.0, 0.5)):
        scroll_rack(d, p, tang(a), rnd.uniform(2.0, 2.6), rnd.uniform(2.1, 2.6))
    for j, (p, a) in enumerate(h.rim("registros", 6, 0.86, 0.9, 0.5)):
        if j % 2 == 0:
            oil_lamp(d, p, 2.5, a + math.pi)
        elif h.put(p, 0.6):
            ink_pool(d, P((x, y), r * 0.82, math.degrees(a)), 0.6, tones[1])
    d.blob("pouso", tones[1], (x, y), 2.2, 0.0234, 0.04, 22)  # pouso da página no miolo (tom do chão)
    d.blob("pouso", tones[0], (x, y), 1.4, 0.0237, 0.04, 18)
    d.reserve(x, y, GATHER_FREE)

    # ---- Sala de Leitura: estantes BAIXAS encostadas na parede, mesas de copista junto à parede, tapete de leitura em
    #      tom do chão e os 3 pousos dos Livros de Nomes (atril = modelo do lacaio) ----
    room = rooms["leitura"]
    x, y = room["pos"]
    r = room["r"]
    tones = T["leitura"]
    back = opposite(h, "leitura")
    ms = h.mouths("leitura")
    ledgers = []
    for k in range(LEDGERS):                                 # o triângulo dos atris, girado para longe das bocas
        best = max((min(abs(math.atan2(math.sin(back + math.tau * k / LEDGERS + off - m), math.cos(back + math.tau * k / LEDGERS + off - m))) for m in ms), off)
                   for off in (0.0, 0.26, -0.26, 0.52, -0.52))[1]
        ledgers.append(P((x, y), r * 0.45, math.degrees(back + math.tau * k / LEDGERS + best)))
    h.rings("leitura", tones, (0.3,), y=0.0230, w=0.22)
    for q in ledgers:
        d.blob("pouso", tones[1], q, 1.6, 0.0234, 0.03, 20)
        d.blob("pouso", tones[0], q, 1.0, 0.0237, 0.03, 16)
        papers(d, q, 4, 1.2)
        z.spawner("name_ledger", round(q[0], 2), round(q[1], 2), 0.5, 1, 30.0)
    for i in range(-int(r), int(r) + 1):                     # tábuas: juntas em tom escuro do chão, de parede a parede
        half = math.sqrt(max(0.0, (r * 0.84) ** 2 - i * i))
        if half > 1.0:
            d.strip("leitura", tones[1], [Vector((x - half, y + i)), Vector((x + half, y + i))], 0.07, 0.0226)
    for j, (p, a) in enumerate(h.rim("leitura", 18, 0.9, 0.92, 0.42)):
        bookshelf(d, p, tang(a), rnd.uniform(1.8, 2.3), 1.35, 0.45, 2)
        d.solid(p[0], p[1], 2.2, 0.6, 1.4, tang(a))
    for j, (p, a) in enumerate(h.rim("leitura", 7, 0.76, 0.78, 0.55)):
        if j % 2 == 0:
            writing_desk(d, p, tang(a) + 180.0)
            d.solid(p[0], p[1], 1.7, 0.9, 1.0, tang(a))
        else:
            candle_stand(d, p, 1.4, 3)
            book_pile(d, P(p, 0.7, math.degrees(a) + 90.0))
    for (p, a) in h.rim("leitura", 6, 1.0, 1.03, 0.5):
        oil_lamp(d, p, 2.6, a + math.pi)

    # ---- A Mesa do Escrivão: anéis de leitura em tons do chão, estantes altas e faixas de nomes riscados NA parede,
    #      a Mesa (visual, sem colisor) logo atrás do ponto de nascer, o anel dos livros e os 4 pontos de estante ----
    room = rooms["mesa"]
    x, y = room["pos"]
    r = room["r"]
    tones = T["mesa"]
    back = opposite(h, "mesa")
    h.rings("mesa", tones, (0.22, 0.44, 0.66, 0.84), y=0.0230, w=0.24)
    for j, (p, a) in enumerate(h.rim("mesa", 40, 0.9, 0.91, 0.36)):
        if j % 5 == 2:
            name_banner(d, p, tang(a), 3.6, 1.1, 2.8)
        else:
            bookshelf(d, p, tang(a), 2.6, rnd.uniform(3.0, 3.5), 0.6, 5)
            d.solid(p[0], p[1], 2.6, 0.8, 3.2, tang(a))
    for j, (p, a) in enumerate(h.rim("mesa", 10, 0.85, 0.86, 0.5)):
        if j % 2 == 0:
            oil_lamp(d, p, 2.6, a + math.pi)
            d.solid(p[0], p[1], 0.4, 0.4, 2.0)
        else:
            book_pile(d, p)
            papers(d, p, 4, 1.0)
    dc = P((x, y), 2.6, math.degrees(back))                  # a Mesa: fundo virado para a parede de trás
    scribe_desk(d, dc, tang(back), tones[1])
    adds = [P((x, y), EGG_R, math.degrees(0.3) + 90.0 * k) for k in range(4)]
    for q in adds:                                           # pouso dos livros (tom do chão), papel em volta
        d.blob("pouso", tones[1], q, 1.0, 0.0234, 0.03, 16)
        d.blob("pouso", tones[0], q, 0.55, 0.0237, 0.03, 12)
    cover = [P((x, y), COVER_D, deg) for deg in COVER_ANGLES]
    for q in cover:                                          # onde a Chamada ergue as estantes: retângulo pintado + 2 livros
        rot = math.degrees(math.atan2(q[1] - y, q[0] - x))
        d.box("pouso", tones[1], q, (3.2, 0.0006, 1.5), -rot + 90.0, 0.0234)      # a pegada da estante (de lado para o centro)
        d.box("pouso", tones[0], q, (2.6, 0.0006, 0.9), -rot + 90.0, 0.0237)
    for k in range(5):                                       # tinta derramada fosca, perto da parede
        aa = back + math.pi * 0.25 + k * math.tau / 5
        ink_pool(d, P((x, y), r * rnd.uniform(0.72, 0.8), math.degrees(aa)), rnd.uniform(0.5, 0.8), tones[1])
    rr = rooms["registros"]
    _hint(z, room, "boss_azhar_scribe", clear_r=round(r * 0.8, 1), adds=adds, add_r=EGG_R, cover=cover, cover_r=1.6,
          cover_d=COVER_D, ledgers=ledgers, ledgers_room=[list(rooms["leitura"]["pos"])], gather=[list(rr["pos"])],
          desk=[dc],
          note="adds: os 4 pousos dos Livros de Nomes (MonsterDef.eggs r 7, angulo 0.3 rad + i*90); cover: os 4 pontos de estante "
               "da Chamada (10 m a 45/135/225/315 graus do ponto de nascer, = mirrors); ledgers: 3 name_ledger parados na Sala de "
               "Leitura (um spawner por pouso, raio 0.5); desk: a Mesa (visual, sem colisor); nenhum colisor dentro de clear_r")
    return d.flush()


DRESS = {"dg_archive": archive}
