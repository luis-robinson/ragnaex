"""Porto Esperança (city_port, hub do Ato II 30-35): a colônia da Aurora na baía de Kharzun. Paliçada de troncos claros
em anel (meio feita em C0: os vãos leste/oeste só têm andaime; em C1 a paliçada nova aparece), praça com o cristal e
os serviços, casas de colono, a Taverna da Âncora (abre), cais com o navio de chegada (volta ao Bastião) e o farolete
no quebra-mar (aceso em C2, quando chega o 2º navio). Os ginetes descem pela garganta nordeste (estrada do portão norte);
a Costa Partida fica a oeste: a estrada das hortas (portão oeste) leva à garganta oeste-noroeste.

    set RAGNAEX_ROOT=<projeto ou worktree>
    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_city_port <pasta_png> --export
"""
import math
import random
import act2_dress
import nature
import sea
import zone_lib
from zone_lib import Zone, box, cyl, cone, disc, mat

ZONE = "city_port"
SEA_C, SEA_R = (0.0, 172.0), 105.0
TOWN_C, TOWN_R = (0.0, 8.0), 36.0     # centro fixo: mestres (anel r=18) e memorial têm posição no maps_catalog
PLAZA_R = 22.0                          # praça grande: 6 serviços (r=10), cristal, memorial, 8 mestres (r=18..21) e 10+ bots
COAST_ARRIVE = (101.4, 14.2)            # chegada na Costa (build_field_coast imprime "BACK port")
BASTION_ARRIVE = (93.9, -25.2)          # chegada no Bastião (build_field_ruins imprime "BACK port")
SHIP_PORTAL = (-8.0, 60.0)              # pé do cais: navio para o Bastião
SHIP_ARRIVE = (-3.0, 52.0)              # quem chega do Bastião aparece aqui (o Capitão Bren aponta para cá)
TAVERN = (-29.0, 16.0)                  # = MapsCatalog.INTERIORS["in_port_tavern"]["house"]
GATES = [-90.0, 90.0, 0.0, 180.0]       # norte (garganta dos ginetes), sul (cais), leste (farolete), oeste (hortas, estaleiro e a Costa)
GATE_HALF = 8.5                         # graus do eixo do portão a cada torre
GAPS = [(198.0, 245.0), (25.0, 60.0)]   # arcos da paliçada ainda por fazer em C0 (noroeste e sudeste)
RAID_DEG = -40.0
COAST_DEG = -160.0                      # garganta da Costa Partida (oeste-noroeste)
PALISADE_Q, LIGHT_Q = "hx_palisade", "hx_lighthouse"


def H(r, a, c=TOWN_C):
    return (round(c[0] + math.cos(math.radians(a)) * r, 2), round(c[1] + math.sin(math.radians(a)) * r, 2))


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def in_gap(a):
    a = a % 360.0
    return any(lo <= a <= hi or lo <= a + 360.0 <= hi for lo, hi in GAPS)


def palisade(z):
    """Anel de estacas. Fora dos vãos: estaca sólida (visual + colisão). Nos vãos: andaime e pilhas de tronco (C0,
    peças `andaime_*`) e a paliçada nova (C1, peças `palicada_nova_*`) — o jogo troca pelo MapDef.conquest_vis e a
    colisão do vão só vale em C1 (`if`: MapGeometry.sync_stage)."""
    wood = mat("estaca_clara", (0.82, 0.68, 0.48))
    new = mat("estaca_nova", (0.9, 0.78, 0.56))
    scaf = mat("andaime", (0.56, 0.42, 0.28))
    n = int(math.tau * TOWN_R / 2.2)
    for i in range(n):
        am = math.tau * (i + 0.5) / n
        deg = math.degrees(am)
        if any(zone_lib.angdiff(am, math.radians(g)) * TOWN_R < 4.4 for g in GATES):
            continue
        p = H(TOWN_R, deg)
        rot = zone_lib.along(-math.sin(am), math.cos(am))
        seg = math.tau * TOWN_R / n + 0.12
        if in_gap(deg):
            for k in (-0.25, 0.25):
                q = (p[0] - math.sin(am) * seg * k, p[1] + math.cos(am) * seg * k)
                cyl(z.coll, z.P + "palicada_nova_%d_%d" % (i, int(k * 4)), q, 0.42, 0.42, 3.4, new, 0.0, 6)
                cone(z.coll, z.P + "palicada_nova_ponta_%d_%d" % (i, int(k * 4)), q, 0.44, 0.7, new, 3.4, 6)
            if i % 3 == 0:
                box(z.coll, z.P + "andaime_%d" % i, p, (seg * 2.0, 0.2, 1.4), rot, scaf, 1.6)
                for s in (-1, 1):
                    q = (p[0] - math.sin(am) * seg * s, p[1] + math.cos(am) * seg * s)
                    cyl(z.coll, z.P + "andaime_poste_%d_%d" % (i, s), q, 0.12, 0.12, 2.4, scaf, 0.0, 5)
            else:
                box(z.coll, z.P + "andaime_toras_%d" % i, p, (seg * 1.4, 0.5, 0.9), rot + 15.0, scaf, 0.0)
            # C1: o vão fecha também na sim (colisor que só vale com a quest feita)
            z.ob("wall", p[0], p[1], (seg, 3.2, 1.4), rot, visible=False, when={"if": PALISADE_Q}, stage_solid=True)
            continue
        for k in (-0.25, 0.25):
            q = (p[0] - math.sin(am) * seg * k, p[1] + math.cos(am) * seg * k)
            h = 3.2 * (0.9 + 0.2 * ((i * 7 + int(k * 4)) % 5) / 5)
            cyl(z.coll, z.P + "palicada_%d_%d" % (i, int(k * 4)), q, 0.42, 0.42, h, wood, 0.0, 6)
            cone(z.coll, z.P + "palicada_ponta_%d_%d" % (i, int(k * 4)), q, 0.44, 0.7, wood, h, 6)
        z.ob("wall", p[0], p[1], (seg, 3.2, 1.4), rot, visible=False)
    for g in GATES:                                      # torres de vigia de tronco nos portões
        for s in (-1, 1):
            q = H(TOWN_R, g + s * GATE_HALF)
            cyl(z.coll, z.P + "portao_torre_%d_%d" % (int(g), s), q, 1.4, 1.2, 5.6, wood, 0.0, 8)
            cone(z.coll, z.P + "portao_teto_%d_%d" % (int(g), s), q, 1.8, 1.6, mat("teto_azul", (0.3, 0.42, 0.72)), 5.6, 8)
            z.ob("pillar", q[0], q[1], (2.8, 5.6, 2.8), visible=False)
    z.block(TOWN_C, TOWN_R + 2.0)


def beacon(z, c, root):
    """Farolete na ponta do quebra-mar (pedras da praia `root` até `c`, dentro do mar: só visual, a água já é sólida);
    torre baixa listrada; lanterna apagada/acesa como o farol da Costa."""
    stone = mat("quebramar_pedra", (0.5, 0.48, 0.46))
    n = 9
    for i in range(n):
        t = i / (n - 1.0)
        q = (root[0] + (c[0] - root[0]) * t + (1.2 if i % 2 else -1.2), root[1] + (c[1] - root[1]) * t)
        zone_lib.blob(z.coll, z.P + "quebramar_pedra_%d" % i, q, 2.6 - 0.25 * (i % 3), 0.2, stone, i, 0.55)
    top = z.hill("quebramar", c, 5.0, 1, rock="cliff_rock", top="cliff_rock_d", step=1.6)
    white = mat("farol_branco", (0.96, 0.95, 0.92))
    red = mat("farol_vermelho", (0.82, 0.22, 0.2))
    cyl(z.coll, z.P + "farolete_torre", c, 1.8, 1.3, 7.0, white, top, 12)
    cyl(z.coll, z.P + "farolete_faixa", c, 1.66, 1.56, 0.9, red, top + 3.0, 12)
    cyl(z.coll, z.P + "farolete_apagado_vidro", c, 1.0, 1.0, 1.4, mat("vidro_escuro", (0.18, 0.22, 0.28)), top + 7.0, 10)
    cyl(z.coll, z.P + "farolete_luz_vidro", c, 1.02, 1.02, 1.4, sea.emissive("farol_aceso", (1.0, 0.86, 0.45)), top + 7.0, 10)
    disc(z.coll, z.P + "farolete_luz_halo", c, 2.6, top + 7.8, sea.emissive("farol_halo", (1.0, 0.95, 0.7), 2.0), 20)
    cone(z.coll, z.P + "farolete_teto", c, 1.4, 1.6, red, top + 8.4, 10)


def shipyard(z, c):
    """Estaleiro na areia: casco em construção (quilha + cavernas à mostra) sobre a carreira, guindaste, toras e tábuas."""
    wood = mat("estaleiro_madeira", (0.66, 0.5, 0.32))
    dark = mat("estaleiro_escuro", (0.4, 0.3, 0.2))
    z.patch("estaleiro", c, 13.0, (0.8, 0.7, 0.5))
    L, rot = 15.0, 20.0
    a = math.radians(rot)
    f = (math.cos(a), math.sin(a))
    n = (-f[1], f[0])
    box(z.coll, z.P + "estaleiro_quilha", c, (L, 0.5, 0.6), -rot, dark, 0.5)
    for i in range(-3, 4):                                # cavernas: as do meio mais abertas
        w = 4.4 - abs(i) * 0.75
        q = (c[0] + f[0] * i * 2.0, c[1] + f[1] * i * 2.0)
        for s in (-1, 1):
            e = (q[0] + n[0] * s * w * 0.5, q[1] + n[1] * s * w * 0.5)
            box(z.coll, z.P + "estaleiro_caverna_%d_%d" % (i + 3, s), e, (0.3, 2.4, 0.3), -rot, wood, 0.6)
        box(z.coll, z.P + "estaleiro_trave_%d" % (i + 3), q, (0.3, 0.3, w), -rot, wood, 0.6)
    for i in (-2, 0, 2):                                  # carreira (trilhos de tora sob o casco)
        q = (c[0] + f[0] * i * 3.0, c[1] + f[1] * i * 3.0)
        box(z.coll, z.P + "estaleiro_carreira_%d" % i, q, (0.5, 0.5, 6.4), -rot, dark, 0.0)
    z.ob("wall", c[0], c[1], (L, 2.6, 4.6), -rot, visible=False)
    g = (c[0] + n[0] * 6.5 - f[0] * 2.0, c[1] + n[1] * 6.5 - f[1] * 2.0)   # guindaste
    cyl(z.coll, z.P + "estaleiro_guindaste", g, 0.3, 0.24, 6.5, dark, 0.0, 6)
    box(z.coll, z.P + "estaleiro_guindaste_braco", (g[0] - n[0] * 1.6, g[1] - n[1] * 1.6), (0.3, 0.3, 4.6), -rot, dark, 6.0)
    z.ob("pillar", g[0], g[1], (0.9, 6.5, 0.9), visible=False)
    for k in range(4):
        q = (c[0] - n[0] * (6.5 + (k % 2) * 1.0) + f[0] * (k * 2.6 - 4.0), c[1] - n[1] * (6.5 + (k % 2) * 1.0) + f[1] * (k * 2.6 - 4.0))
        z.ob("log", q[0], q[1], (3.4, 0.7, 0.8), -rot + (8 if k % 2 else -6), color=(0.7, 0.56, 0.38))
    z.ob("crate", g[0] + 2.2, g[1] + 1.0, (1.0, 1.0, 1.0), 15.0)
    z.ob("barrel", g[0] + 3.4, g[1] - 0.4, (0.8, 1.0, 0.8))
    z.block(c, 14.0)


def gorge_post(z, c, toward):
    """Posto da Garganta: torre de vigia e barricadas de tora viradas para a garganta (fora da rota da investida)."""
    wood = mat("vigia", (0.52, 0.38, 0.24))
    for dx in (-1.3, 1.3):
        for dz in (-1.3, 1.3):
            cyl(z.coll, z.P + "posto_poste_%d_%d" % (dx > 0, dz > 0), (c[0] + dx, c[1] + dz), 0.22, 0.2, 5.4, wood, 0.0, 6)
    box(z.coll, z.P + "posto_plataforma", c, (3.6, 0.3, 3.6), 0.0, wood, 5.4)
    cone(z.coll, z.P + "posto_teto", c, 2.7, 1.7, mat("teto_azul", (0.3, 0.42, 0.72)), 6.9, 4)
    z.ob("pillar", c[0], c[1], (3.4, 5.4, 3.4), visible=False)
    a0 = math.atan2(toward[1] - c[1], toward[0] - c[0])
    for k in (-2, -1, 1, 2):
        a = a0 + k * 0.42
        z.ob("fence", c[0] + math.cos(a) * 7.0, c[1] + math.sin(a) * 7.0, (3.4, 1.1, 0.5), math.degrees(-a) + 90, color=(0.6, 0.46, 0.3))
    z.patch("posto_garganta", c, 9.0, (0.6, 0.5, 0.38))
    z.block(c, 10.0)


def build(export=False):
    z = Zone(ZONE, size=220.0, rim=(98.0, 5.0, 3.0, 2.0), seed=17, palette={
        "road": (0.74, 0.64, 0.48), "street": (0.8, 0.72, 0.58), "cliff_rock": (0.6, 0.56, 0.5), "cliff_rock_d": (0.48, 0.45, 0.4),
        "cliff_grass": (0.5, 0.62, 0.38), "hill_grass": (0.54, 0.66, 0.4), "leaf": (0.36, 0.58, 0.34),
    })
    # a Costa fica a OESTE do porto (o mar é ao sul nos dois mapas e a Costa sai para cá pelo portão leste dela):
    # garganta oeste-noroeste, no rumo oposto ao da saída da Costa (teste _check_world_layout)
    portal = polar(z, COAST_DEG, 7)
    arrive = polar(z, COAST_DEG, 16)
    print("BACK coast", arrive)
    z.portal("to_field_coast", portal, "field_coast", COAST_ARRIVE, "Costa Partida (Lv 30-35)")
    # o navio de volta: portal no pé do cais, sem portão
    z.data["portals"].append({"id": "ship_field_ruins", "pos": list(SHIP_PORTAL), "radius": 2.0, "target_map": "field_ruins",
                              "target_pos": list(BASTION_ARRIVE), "label": "Navio para o Bastião"})
    z.block(SHIP_PORTAL, 5.0)
    z.data["spawn"] = list(SHIP_ARRIVE)
    z.cam_game = TOWN_C                                   # CAM_game olha a praça (o spawn é o cais)
    z.portal_angles.append(math.radians(RAID_DEG))       # garganta dos ginetes (sem portal): montanha baixa
    sea.sea(z, SEA_C, SEA_R, beach=12.0)

    # ---------- colônia: chão de terra batida, praça grande, paliçada, casas encostadas no muro ----------
    z.patch("colonia", TOWN_C, TOWN_R + 2.0, (0.66, 0.58, 0.44))
    z.M["pave_praca_porto"] = mat("pave_praca_porto", (0.78, 0.7, 0.56))
    z.plaza("praca", TOWN_C, PLAZA_R, "pave_praca_porto")
    palisade(z)
    z.data["town"] = {"center": list(TOWN_C), "radius": TOWN_R, "gates": [list(H(TOWN_R, g)) for g in GATES]}
    for g in GATES:
        z.road("av_%d" % int(g), [H(PLAZA_R - 1.0, g), H(TOWN_R - 2.0, g)], w=4.6, end_clearing=False)
    near_gate = lambda a, tol: any(abs((a - g + 180.0) % 360.0 - 180.0) < tol for g in GATES)
    face = lambda a: round(math.degrees(math.atan2(-math.cos(math.radians(a)), -math.sin(math.radians(a)))), 1)
    roofs = [(0.3, 0.42, 0.72), (0.62, 0.3, 0.24), (0.42, 0.52, 0.36), (0.7, 0.56, 0.34)]
    tav_a = math.degrees(math.atan2(TAVERN[1] - TOWN_C[1], TAVERN[0] - TOWN_C[0]))
    k = 0
    for i in range(20):
        a = 360.0 * (i + 0.5) / 20
        if near_gate(a, 13.0):
            continue
        x, y = H(31.0, a)
        if math.hypot(x - TAVERN[0], y - TAVERN[1]) < 9.5:
            continue
        z.ob("house", x, y, (4.6, 3.2, 4.0), face(a), color=(0.78, 0.66, 0.5), roof=roofs[k % 4])
        k += 1
    z.ob("house", TAVERN[0], TAVERN[1], (7.0, 4.0, 5.6), face(tav_a), color=(0.72, 0.56, 0.4), roof=(0.5, 0.26, 0.22))
    z.ob("statue", TOWN_C[0], TOWN_C[1] - 3.0, (1.6, 2.6, 1.6), color=(0.92, 0.88, 0.72))       # a âncora de pedra da fundação
    for a in range(15, 360, 30):                          # postes fora da praça, entre os raios dos mestres (múltiplos de 15 com folga)
        z.ob("lamp", *H(PLAZA_R + 0.9, a + 7.0), (0.4, 3.0, 0.4))
    for i, a in enumerate((60.0, 72.0, 108.0, 120.0)):    # mercado: duas barracas de cada lado da avenida do cais
        z.ob("stall", *H(26.0, a), (2.8, 2.2, 1.8), face(a), color=roofs[i])
    z.ob("well", *H(26.0, -40.0), (1.6, 1.4, 1.6))
    for a in (-125.0, -60.0, 140.0):                      # bancos na borda da praça (fora dos anéis de NPC)
        z.ob("bench", *H(PLAZA_R + 2.2, a), (1.8, 0.8, 0.6), face(a) + 90.0)
    # serviços no anel de dentro (r=10); os 8 mestres ficam no anel de fora (r=18, maps_catalog); mercador de importados só em C2
    for nid, a in (("port_governor", -100.0), ("port_smith", -30.0), ("port_alchemist", 30.0), ("port_merchant", 150.0),
                   ("port_storage", -150.0), ("port_import_merchant", 115.0)):
        x, y = H(10.0, a)
        z.npc(nid, x, y, face(a))
    for i, role in enumerate(["spearman", "spearman", "crossbow", "crossbow", "knight"]):     # defesa do portão norte (sempre)
        x, y = H(TOWN_R - 5.0 - (i // 2) * 2.5, -90.0 + (i % 2 * 2 - 1) * 7.0 - (3.5 if i == 4 else 0))
        z.npc("port_g_%s_%d" % (role, i), x, y, face(-90.0) + 180.0)
    for i in range(4):                                   # C1: besteiros nas torres e no muro novo
        a = [-80.0, -100.0, 42.0, 222.0][i]
        x, y = H(TOWN_R - 2.6, a)
        z.npc("port_w_crossbow_%d" % i, x, y, face(a) + 180.0)
    # pontos de bot: anel do meio da praça (entre serviços e mestres), frente da taverna, mercado e largo do cais
    z.data["hangouts"] = [list(H(14.2, a)) for a in range(15, 360, 30)] + [list(H(23.5, tav_a + 12.0)), list(H(24.0, 82.0)), [3.0, 54.0], [-6.0, 53.0]]

    # ---------- cais: estrada do portão sul, largo de tábuas, dois píeres, navio de chegada e (C2) o segundo navio ----------
    z.road("cais", [H(TOWN_R + 1.0, 90.0), (0.0, 50.0), (-6.0, 62.0)], w=4.6, end_clearing=False)
    z.M["pave_largo_cais"] = mat("pave_largo_cais", (0.7, 0.58, 0.42))
    z.plaza("largo_cais", (0.0, 55.0), 8.5, "pave_largo_cais")
    sea.pier(z, "oeste", (-8.0, 61.0), (-8.0, 96.0))
    sea.pier(z, "leste", (14.0, 63.0), (14.0, 92.0))
    sea.ship(z, "chegada", (-17.0, 86.0), 90.0, L=18.0)
    sea.ship(z, "segundo", (23.0, 84.0), 90.0, L=16.0, hull=(0.36, 0.3, 0.26), sail=(0.86, 0.9, 0.98), tag="navio2_")
    z.npc("port_sailor", -4.0, 57.0, 0.0)
    for i in range(6):
        z.ob("crate" if i % 2 else "barrel", 4.5 + (i % 3) * 1.6, 59.0 + (i // 3) * 1.6, (1.0, 1.0, 1.0) if i % 2 else (0.8, 1.0, 0.8), i * 25.0)
    z.block((0.0, 55.0), 10.0)
    # ---------- leste: trilha ao quebra-mar com o farolete; a trilha da praia fecha a volta até o cais ----------
    z.road("farolete", [H(TOWN_R + 1.0, 0.0), (51.0, 22.0), (48.0, 44.0), (45.0, 58.0)])
    z.road("praia", [(48.0, 44.0), (32.0, 54.0), (16.0, 57.0), (6.0, 55.0)], w=3.4, end_clearing=False)
    beacon(z, (49.0, 82.0), (45.0, 64.0))
    # ---------- norte: estrada do portão até a bifurcação; nordeste: a garganta dos ginetes e o posto de vigia ----------
    z.road("norte", [H(TOWN_R + 1.0, -90.0), (5.0, -36.0), (3.0, -46.0)], end_clearing=False)
    gorge_out, gorge_in = polar(z, RAID_DEG, 6), polar(z, RAID_DEG, 16)
    z.road("ginetes", [(3.0, -46.0), (30.0, -52.0), gorge_in], w=3.6)
    z.patch("garganta", gorge_in, 10.0, (0.56, 0.46, 0.34))
    z.block(gorge_in, 10.0)
    z.road("vigia", [(30.0, -52.0), (50.0, -34.0), (56.0, -10.0), (48.0, 4.0), H(TOWN_R + 1.0, 0.0)], w=3.4, end_clearing=False)
    gorge_post(z, (64.0, -30.0), gorge_in)
    gate_n = H(TOWN_R + 4.0, -90.0)
    z.data["raids"] = [
        {"side": "cerco", "from": list(gorge_in), "route": [[30.0, -52.0], [6.0, -42.0]], "target": list(TOWN_C), "radius": TOWN_R - 6.0,
         "unless": PALISADE_Q},
        {"side": "muralha", "from": list(gorge_in), "route": [[30.0, -52.0], [6.0, -42.0]], "target": list(gate_n), "radius": 7.0,
         "if": PALISADE_Q, "unless": "hx_riders_camp"},
        {"side": "patrulha", "from": list(gorge_in), "route": [[30.0, -52.0], [6.0, -42.0]], "target": list(gate_n), "radius": 7.0,
         "if": "hx_riders_camp"},
    ]
    # ---------- oeste: hortas dos colonos (casa de fazenda, cercas) e o estaleiro na praia; a estrada dá a volta ----------
    z.road("hortas", [H(TOWN_R + 1.0, 180.0), (-52.0, 2.0), (-62.0, -16.0), (-50.0, -40.0), (-24.0, -52.0), (2.0, -45.0)], w=3.6, end_clearing=False)
    z.road("costa", [(-62.0, -16.0), (-70.0, -24.0), arrive, portal], end_clearing=False)      # sai da volta das hortas para a garganta da Costa
    z.road("estaleiro", [(-52.0, 2.0), (-62.0, 24.0), (-56.0, 44.0), (-38.0, 55.0), (-18.0, 53.0), (-6.0, 53.0)], w=3.6, end_clearing=False)
    farm = (-74.0, 4.0)
    for i, (dx, dy) in enumerate(((2.0, -9.0), (8.0, 6.0), (-5.0, 9.0))):
        q = (farm[0] + dx, farm[1] + dy)
        z.patch("horta_%d" % i, q, 5.4, (0.5, 0.4, 0.26), grass=True)
        for j in range(5):
            z.ob("flowers", q[0] - 3.6 + j * 1.8, q[1] + (1.2 if j % 2 else -1.2), (1.6, 0.5, 1.6), solid=False, color=[(0.5, 0.72, 0.32), (0.86, 0.78, 0.36)][j % 2])
    z.ob("house", farm[0] - 9.0, farm[1] - 2.0, (4.6, 3.2, 4.0), 90.0, color=(0.82, 0.74, 0.58), roof=(0.7, 0.56, 0.34))
    z.ob("well", farm[0] + 1.0, farm[1] - 1.0, (1.5, 1.3, 1.5))
    z.block(farm, 17.0)
    shipyard(z, (-46.0, 69.0))
    z.cliffs(snow=False)
    sea.sink_cliffs(z)
    obs = z.data["obstacles"]
    z.scatter("tree", [((0, -62), 40, 26), ((-70, -40), 26, 14), ((72, 8), 22, 10), ((-30, -36), 14, 4)], 0, (2.0, 4.4, 2.0),
              [(0.32, 0.56, 0.34), (0.4, 0.62, 0.34)], margin=4.6, spacing=5.0, hub_r=TOWN_R + 12.0)
    z.rim_belt(80, (2.0, 4.4, 2.0), [(0.3, 0.5, 0.32), (0.36, 0.56, 0.34)])
    z.scatter("rock", [((0, 0), 90, 26)], 0, (1.4, 0.9, 1.2), [(0.66, 0.62, 0.56)], margin=3.5, spacing=3.0, hub_r=TOWN_R + 12.0, scale=(0.7, 1.6))
    nrnd = random.Random(61)
    fr = lambda x, zz, m: z.free(x, zz, m, TOWN_R + 10.0)
    nature.fix_trees(obs, nrnd, pine_frac=0.2)
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 90, 40)], (1.6, 0.85, 1.6), [(0.42, 0.56, 0.32), (0.5, 0.6, 0.34)],
                   solid=False, margin=2.6, spacing=3.0, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [((0, -62), 36, 8)], avoid=obs)
    act2_dress.port(z, SEA_C, SEA_R, TOWN_C, TOWN_R, PLAZA_R, GATES, GATE_HALF, farm, (-46.0, 69.0), (49.0, 82.0), (45.0, 64.0), (64.0, -30.0),
                    (-17.0, 86.0), 90.0, 18.0, [((-8.0, 61.0), (-8.0, 96.0)), ((14.0, 63.0), (14.0, 92.0))])
    return z.finish(export, poi=(0.0, 56.0), ground=(0.56, 0.66, 0.42))
