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
- **Acabamento** (Ato II): `zones/dress.py` (`Dress`) junta detalhe de chão e adereços em lotes por célula de 36 m com a cor no
  vértice (materiais `det_vcol_chao` sem sombra/contorno, `det_vcol`, `det_vcol_mini` sem sombra; `glow_*` brilha) e
  `zones/act2_dress.py` tem a função de cada zona (`coast`, `port`, `steppe`, `fort`, `goblin`), chamada logo antes do `z.finish`.
  Peça grande só nasce onde `Dress.ok()` deixa e ganha colisor oculto com `Dress.solid()`; enfeite de conquista (`tag`) nunca colide.
  Usa Random próprio: a sim da zona não muda (só acrescenta colisores no fim). Check `_check_zone_dress`.
  `Zone.arrival()` faz o largo de chegada; `Zone.patch(y=)` separa manchas grandes (duas no mesmo plano brigam: faixas em leque).
  `Dress.mottle(y=, step=)` = altura do 1º tom e degrau entre os planos dos tons (padrão 0,8/0,8 mm; o antigo 0,2 mm brigava no z-buffer).
  **Pilha de planos por zona** (2026-11-13; tudo ABAIXO dos planos de `Zone.patch` 5,0 mm — exceto a lama do mangue — e das manchas/chão dos lugares 6,0+; dois planos
  nunca a menos de 0,4 mm, e 0,4 só onde a sobreposição é pouca): `act2_dress.dry_ground` (estepe, acampamentos, Kharzun) manchas 1,8/2,6/3,4
  (`mottle_y` 1,8, `mottle_step` 0,8) e risco de vento `streak_y` 4,2; chão do acampamento (`fort`) y 1,0; costa/porto campo 0,8/1,6/2,4,
  mata 3,2, areia 4,0, faixa do mangue 4,6, lama 5,2/5,6 (0,4). Mancha nova numa zona: escolha um vão livre dessa pilha e anote no comentário. Pano (bandeira, flâmula,
  estandarte) é dobrado, nunca placa chata: `Dress.cloth()`/`Dress.flag()` no acabamento, `horde.cloth()` nos builds sem `Dress` (cidadela, ruínas).
  Crosta/placa de rocha baixa (lava, basalto) = `Dress.slab()` (talude escuro + tampo claro; gasta os mesmos 3 sorteios do `blob`).
- **Cor do chão** (art review 2026-11-13): enfeite pintado no chão (anéis, raios, selos de arena) só em tons do PRÓPRIO chão
  (`act2_dress.floor_tones()` / `Halls.tones()`, ±13% de valor puxado para o cinza). Anel saturado, cheio ou brilhante no chão é dos avisos
  de golpe (`FxManager.DANGER*`); arena de chefe não é vermelha (basalto). Lava = superfície plana `glow_lava` (o `FIRE_SHADER` não clareia
  faces para cima). Poço de salão/lugar fosco: `pool_glow: False` (`build_dungeons`/`places.py`; sem isso a tinta vira `glow_pool_*`).
  Trilha de lugar conferida à mão que acusa `PLACE_CONFLICT` sem nada sólido no caminho: `trail_ok={"<lugar>"}` no `build_<zona>.py` (só cala o aviso).
- **Conquista no acabamento** (acampamentos da Horda, `act2_dress.fort`): o que troca de dono vai em dois lotes com `tag`, no mesmo ponto:
  `Dress(z, seed, tag="estandarte_horda_det")` (some na retomada) e `tag="estandarte_aurora_det"` (aparece), via `MapDef.conquest_vis`; hoje tendas do pátio,
  bonecos de treino, crânio/pano do pórtico e flâmulas. O colisor fica no lote neutro (um só, vale para os dois). Ao mover uma peça do lote neutro para um
  com tag, gaste no `d.rnd` os sorteios que ela gastava (cada `cyl` sorteia `segs` vezes): `data/zones/<zona>.json` tem de sair byte a byte igual.
  Check `_check_fort_tents`; refazer: `run_zone.py -- build_steppe_forts <pasta> --export --only=fort_trolls,fort_fire,fort_war --no_render`.
  Bonecos de treino: candidatos `[recuo, ângulo]` em `act2_dress.FORT_DRILL` (espelhados em `run_tests.FORT_DRILL`). Quadrantes longe da estrada:
  `act2_dress.fort_far` (rodízio `FAR_KINDS`: fogueira apagada, escaramuça, rastro, monturo, queimado, roda), tudo baixo, sem colisor, no fim do lote neutro.
- **Cor da estrada no jogo** (2026-11-13): zona aberta (vale, cidade) pinta o material `road` com a cor do Blender
  (`MapBuilder._blender_road` em `_zone_materials`, como os `patch_*`); fortalezas (`fort_*`), dungeons e cidadelas (`*_citadel`) mantêm a terra
  derivada do chão (`_dirt_color`), porque lá `road` é piso de pátio/corredor. A ponta de estrada que acaba num portal (≤ 6 m) tem o capim
  mascarado nos últimos 43 m e num disco na ponta (`_ends_at_portal`/`_mask_portal_end`, dentro do `_zone_mask`): a malha do GLB ali é mais larga
  que a polilinha da sim. Revisar: `production/qa/evidence/final-qa/roads/<mapa>/`.
- Mar com ondas quebrando na areia: mapa em `WaterFx.SURF_MAPS` (uniform `surf_amount` do `spatial_env_water.gdshader`, padrão 0). Foto de
  carregamento de zona com mar de outro lado: `"sea": "W"` em `loading_art.ZONES`. Zona girada no fim do build: `Zone.apply_turn` (Praia dos Caranguejos).
- **Ato III, Fenda e masmorras** (WP6, 2026-11-23): `build_rift.py` = `rift_garden` (laço: Posto da Aurora no centro com o Véu, anel de
  mármore, Pavilhão da Vessaline ao norte com 20 m livres, Alameda dos Espelhos, Lago de Perfume, Labirinto de Sebes, Porta do Coração);
  sebe = `build_rift.hedge/hedge_ring` (muro baixo com colisor). Masmorras `dg_cellars`, `dg_mirrors`, `dg_conservatory` e a raide
  `rift_heart` saem do `build_dungeons` (entradas em `places.DUNGEONS` com `return`; opções novas de salão `pillars: False` e bando de
  ligação `None` = sem bando) e o acabamento de `zones/act3_dress.py` (`DRESS[<id>]`; pontos da mecânica do chefe em `data["boss_hint"]`).
  Passagem para mapa ainda fora do catálogo fica em `future_portals`; quando o mapa entra: id em `act3_ready.READY` e
  `python tools/blender/zones/act3_ready.py --apply` (reescreve só o JSON, igual ao que o build gravaria; os builds chamam `promote`).
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
