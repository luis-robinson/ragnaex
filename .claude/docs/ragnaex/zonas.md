<!-- RagnaEx manual (pt-BR) — Layout de zonas. Moved VERBATIM from the old CLAUDE.md on 2026-11-08 (CCGS adoption); imported by CLAUDE.md. Edit here. -->

## Layout de zonas (estilo Erenshor, câmera de cima)

Referência: `C:\Users\luisf\Desktop\projects\erenpg` (`blender/scripts/build_vale_inicial.py`,
`godot/assets/maps/vale_inicial.png`, `ERENSHOR_LIKE_PROJECT.md`). Nada de mapa quadrado com caminhos em cruz/grade.

**Estrutura de toda zona** (1 unidade = 1 m; personagem ≈ 1.7 m; corrida ≈ 5.5 m/s):
- **Vale fechado** de ~240 × 240 m: borda natural (anel de penhascos/montanhas facetadas, floresta densa ou mar) —
  nunca uma borda reta visível. Portais para outras zonas ficam em gargantas/passagens na borda.
- **Hub no centro**: vila murada circular (raio ~25–30 m) com praça radial (chafariz/marco), mercado, NPCs de
  serviço (ferreiro, alquimista, mercador, quest), portões nas direções das estradas. Cabe 10+ bots sem travar.
- **3–5 POIs** a 60–120 m do hub (1–2 min de caminhada): floresta, ruínas com monumento, lago, acampamento,
  boca de caverna/dungeon. Cada POI tem identidade visual própria (cor do chão, props, marco) e seus spawners.
- **Estradas curvas** (catmull-rom, 4 m de largura) ligando hub↔POI e POI↔POI; nunca linha reta, sem becos
  sem saída acidentais. Rio/lago com **pontes** como únicos cruzamentos.
- **Landmark** visível de qualquer ponto (castelo na colina, torre em ruínas, árvore gigante) — fora das rotas
  principais para não esconder o jogador.
- **Leitura de cima** (a câmera é alta, 52°): o que define a zona é o que se vê no chão — estradas de terra,
  muros, telhados, manchas de cor por região (floresta escura, campo claro, pedra da vila, água). Nada alto
  (> 6 m) colado nas estradas perto do hub; o fade de oclusão existe, mas o layout não deve depender dele.
- **Altura**: a sim é plana (andável = plano y = 0). Verticalidade é visual: penhascos da borda, colinas e
  patamares como obstáculos sólidos (não andáveis), muros, castelo sobre base sólida. Rampas/colinas andáveis
  exigem altura na sim (heightmap) — ainda não existe; não prometa isso no layout.

**Pipeline** (Blender = fonte do layout; a sim continua 100% dados):
- `tools/blender/zones/build_<zona>.py` (usando `zone_lib.Zone`: estradas, rio, pontes, penhascos, paliçadas, morros,
  dispersão; e `nature.py`: `scatter`, `shore`, `fix_trees`, `woodland_floor`, `mountain_ring`) constrói a zona inteira por
  loops (nada objeto a objeto) dentro da Collection `Z_<zona>` e exporta o visual para `assets/models/map_<zona>.glb`
  (`MapDef.model = "map_<zona>"`). Sem janela: `blender -b --factory-startup --python <script>` chamando `build(export=True)`.
- A dispersão de uma zona muda quando lugares/trilhas mudam: chegadas de portal precisam estar reservadas (`block`/`spots`).
- Água e morros colidem na sim (`MapGeometry.build_collider_grid`): o rio só tem vão nas pontes, que nascem onde uma estrada
  (`kind: "road"`) cruza o rio. Bots usam `water_path`; mudou rio/ponte, rode os testes de travessia (`_cross_river`).
  Toda zona chama `nature.clear_banks` depois de espalhar a vegetação: corredor de 2 m livre nas margens (sem bolsões; há check).
- Marcadores no Blender viram dados da sim (exportados para `data/zones/<zona>.json` e lidos pelo `maps_catalog.gd`):
  `OB_box_<nome>` / `OB_circle_<nome>` (colisão: tamanho/rotação do objeto), `SPAWN_player_01`,
  `SPAWN_mob_<monster_id>_NN` (raio no nome ou custom prop `radius`), `SPAWN_npc_<npc_id>`,
  `SPAWN_hangout_NN` (pontos de bot), `TRIG_portal_<zona_destino>` (+ `SPAWN_chegada_<zona_origem>` no destino).
- Nomes do visual: `Z_<zona>_<tipo>_<nome>` (`terreno`, `estrada`, `agua`, `ponte`, `muro`, `casa`, `prop`,
  `arvore`, `penhasco`). Materiais `tint`/`roof` funcionam como nos props (cor vinda dos dados).
- Nunca apague objetos fora de `Z_<zona_atual>`, `OB_*`, `SPAWN_*`, `TRIG_*` da zona atual. Não salve `.blend`
  de outro projeto aberto no Blender do usuário — confira `bpy.data.filepath` antes.

**Loop de layout** (`/layout-zone <zona — descrição>`, `/layout-check`): blocagem primeiro (cores lisas), depois
detalhe. A cada iteração tire 3 screenshots — `CAM_top` (ortográfica sobre a zona), `CAM_game` (a câmera do jogo:
52°, distância 24 m, olhando o hub) e `CAM_poi` (câmera do jogo num POI) — e dê nota 0–2 em:
legibilidade (acho o hub de qualquer ponto?), fluxo (estradas curvas, sem becos), ritmo (hub→POI 60–120 m),
borda/altura (borda natural, landmark, patamares visuais), multidão (hub comporta 10+ bots). Corrija só os pontos
fracos e repita; pare com nota ≥ 8 (máx 6 iterações). Depois valide no jogo (tour de screenshots pela zona) e rode
testes + smoke (tour: `-- --tour=<pasta> [--tour_map=<zona>]` salva screenshots dos POIs).
