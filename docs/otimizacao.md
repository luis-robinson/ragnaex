# Otimização (passe 3, 2026-11-07)

Pedido: "otimizar o jogo, procurar estratégias, olhar a documentação do Godot". Passes anteriores (não refeitos):
poda do kit + materiais preguiçosos, mapas longe a cada N ticks, `RigidMerge`, `KitModel._remerge`, corte de bonecos
a 58 m, distância de desenho dos props, dizimação (`TRI_BUDGET`), grade de vizinhos e monstros dormindo, `max_physics_steps_per_frame = 3`, FSR 2.

## Como medir

| O quê | Comando | Observação |
|---|---|---|
| Sim sem tela (estável) | `--headless --path . tools/tests/sim_probe.tscn -- [--phases] [--ticks=1200]` | mundo inteiro, semente fixa; a **soma de conferência** tem de ser igual antes/depois (otimização não muda comportamento) |
| Cidade cheia (janela) | `--path . -- --perf [--perf_at=x,z]` | agora imprime `canvas_pass`, `visible_pass` e `shadow_pass` (objetos e draws de cada passada) e `entity_surfaces` |
| Jogando | `--path . -- --autostart=<c> --soak=<s>` | FPS a cada 5 s, perfil da sim no fim |

A máquina tinha outros Godot/Blender rodando em paralelo: FPS absoluto varia muito. Só valem comparações A/B
alternadas (HEAD, otimizado, HEAD, ...), 2-3 rodadas, e contadores que não dependem de carga (draws, superfícies).

## Antes / depois (cidade cheia, `--perf`, 1920x1080, 3 rodadas A/B alternadas)

| | antes (HEAD) | depois |
|---|---|---|
| FPS | 36 / 38 / 42 | 59 / 57 / 59 (perto do vsync) |
| draw calls | ~4.550 | ~1.560 |
| — 2D (HUD) | ~1.700 | ~330 |
| — sombras | ~850 | ~840 |
| superfícies dos bonecos (kit) | ~550 | ~105 |
| superfícies dos monstros/cavalos fundidos | 144-177 | 40-47 |
| CPU de render (ms) | 4,1-4,9 | 1,8-2,0 |
| GPU (ms) | 7,5-8,2 | 5,6 |
| tick da sim (ms) | 6,3-7,0 | 5,1-5,5 |
| ticks por quadro | 1,4-1,6 | 1,0 |

`sim_probe` (sem tela, A/B alternado, carga alta na máquina): 9,6-11,3 → 6,4-8,2 ms/tick (~30%), soma de conferência idêntica.
Fases: `think_bot` 2,0 → 0,8 ms/tick, `think_mob` 1,2 → 0,46. Teste de desempenho do `run_all`: 24,6 s (limite 32 s).

Cavalo novo (primeira montada de cada bot): a fusão custava ~1,5 ms; com a cor no vértice passou a 58 ms (malha por pelagem)
e voltou a ~1,1 ms com o cache de geometria (abaixo).

## Aplicado

1. **Minimapa assado numa textura** (`Minimap._bake_static`). A camada estática desenhava cada árvore/pedra/casa
   como círculo ou retângulo, o mapa inteiro, todo quadro: ~1.500 draw calls de 2D (o maior custo de draws do jogo,
   achado com `VIEWPORT_RENDER_INFO_TYPE_CANVAS`). Agora uma `SubViewport` desenha uma vez por mapa (`UPDATE_ONCE`,
   5 px/m, até 4096 px) e o minimapa mostra a textura. Doc: *Viewports* / *Custom drawing in 2D*.
2. **Cor no vértice nas malhas fundidas** (`KitModel._remerge`, `RigidMerge.merge/merge_skinned`). Peças que só mudam de
   cor dividem uma superfície: a cor da peça (sRGB) e a força do brilho (`spec_strength`, no alfa) vão no `COLOR` do vértice;
   o material da fusão é branco com `vcol_srgb = true` (toon e ghost convertem para linear; `toon_light` lê o brilho por
   `#define TOON_VSPEC`). Cada superfície custava cor + contorno + prepass + 2 cascatas de sombra.
   O material branco é o do grupo (está em `kit.mats` / `_mats`): hit flash e estado continuam. Sobram grupos só por
   emissão, brilho de aprimoramento (+N), contorno e textura. `--no_vcol_merge` volta ao antigo (medir/comparar).
   Doc: *Optimizing 3D performance* (draw calls, materiais), *GPU optimization* (reduzir trocas de estado).
3. **Cache de geometria do `RigidMerge`** por forma (`_geo_cache`): bicho de outra cor só troca o array de cores
   (sem `SurfaceTool`); contagem de vértices por `surface_get_array_len` em vez de copiar os arrays.
4. **Sim: o barato primeiro.** `Combat.nearest_hostile` testa a distância antes de `is_alive/is_hostile_to` (era ~80% do
   pensamento dos bots; folga de 0,1% mantém o resultado exato, há check). `_separate` percorre as células da grade sem
   montar uma lista por entidade e descarta pela caixa antes de `is_alive`. `_update_entity` não copia buffs/debuffs/chaves
   de cooldown vazios. Comando repetido entre pensamentos reaproveita `SimEntity.repeat_cmd` (era um `InputCommand.new()`
   por entidade por tick). Chaves do perfil sem montar texto. Doc: *CPU optimization* (medir, evitar trabalho por quadro).
5. **Pequenos**: placa de nome compara campos em vez de 3 `get_meta` por boneco por quadro; HUD só troca a cor do texto
   de recarga quando muda (override de tema reavisa o Label).

## Considerado e não aplicado

- **MultiMesh para props** (árvores, pedras, arbustos). A passada de cor já junta instâncias iguais sozinha (Forward+:
  254 objetos → 96 draws no campo); o que sobra é sombra. Árvores são oclusores (somem na frente do jogador:
  transparência por nó), e MultiMesh não tem transparência por instância. Escondendo pedras/arbustos/flores/juncos
  inteiros no campo: só −180 draws. Não compensa a complexidade agora.
- **Alcance da sombra do sol 90 → 60 m**: −130 draws. A cascata 1 (0-9 m) quase não tem nada (a câmera está ~19 m
  acima do chão): `directional_shadow_split_1` maior deixaria as sombras perto mais nítidas, mas muda o visual —
  fica para revisar com o usuário.
- **Props pequenos sem sombra** (`--no_prop_shadow`: −600 draws na cidade): muda o visual (pedras e flores sem sombra).
  Candidato a opção de gráficos.
- **Processar bonecos longe a cada 2 quadros**: o deslize de posição ficaria visível. A animação já tem LOD.
- **Mapas longe com passo maior** (`AWAY_MAP_EVERY` 4 → 8): passo de 0,13 s muda colisão/combate; é balanceamento.
- **Occlusion culling** (OccluderInstance3D): câmera alta de cima, quase nada fica escondido atrás de outra coisa.
- **Mesh LOD / HLOD**: os props já são dizimados no export e têm `visibility_range`; a câmera fixa não vê longe.
- **Grama em blocos**: uma MultiMesh do mapa inteiro (~35 mil tufos) é sempre desenhada; dividir em blocos de ~32 m
  deixaria o frustum cortar a maior parte (ganho de GPU, não medido: GPU não era o gargalo aqui).
- **Pool de cavalos**: criar o cavalo na primeira montada ainda custa ~12 ms (instanciar o GLB + materiais).

## Fontes

- Godot docs — *Optimizing 3D performance*: https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html
- Godot docs — *CPU optimization*: https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html
- Godot docs — *GPU optimization*: https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html
- Fórum Godot — *Understanding batching in Godot 4*: https://forum.godotengine.org/t/understanding-batching-in-godot-4/65635

## Sim numa thread (2026-11-09)

O gargalo do mapa aberto cheio é a sim (9-13 ms por quadro na briga em elf_city), toda na thread principal. Agora o tick roda
numa WorkerThreadPool enquanto o quadro desenha: o physics só agenda (`WorldSim._queued_cmds`, um comando por passo),
`SimSync` chama `Sim.start_async` no `RenderingServer.frame_pre_draw` e `Sim.sync` espera antes de input/physics/process.
Events da thread vão para a fila (`Events.post`) e saem na thread principal no sync, com o mapa de cada um (`ticking_map`).
As views leem o estado do tick anterior (1 quadro a mais de atraso visual; o comando entra no mesmo passo de antes).

`--perf` (cidade cheia), duas rodadas: síncrono 78,5 / 63,3 FPS (12,7 / 15,8 ms), com thread 109,9 / 88,6 FPS (9,1 / 11,3 ms): ~40%.
Próximo passo se precisar: a sim só sobrepõe o desenho; views/HUD (que leem a sim) ainda esperam o tick. Sobrepor também o
`_process` exigiria um retrato (snapshot) do estado para as views.

## Sim com o Ato II carregado (2026-11-11)

Pedido: o teste longo (`performance da simulação`, 3000 ticks, limite 32 s) ficou no limite com Costa/Porto/Grutas/Estepes
e as 3 fortalezas (1287 → 1747 entidades). Decisão do autor: otimizar a sim, sem cortar conteúdo nem mexer no limite.

**Onde estava o custo** (perfil com cronômetros temporários, mundo do teste): não nos sistemas novos. Auras de facção
(`mob_aura`), `sync_stage`, ascensões e investidas somam < 0,2 ms/tick. O custo é espalhado e por entidade acordada:
o mapa em foco (cidade com investida: ~60 monstros + 21 bots + 135 itens no chão) leva mais da metade do tick.
ms/tick antes: comandos 4,9 (pensar 1,6; aplicar 1,8), entidades 2,6, `_index_map` 0,84, loot 0,60, spawners 0,44.

**Como medir o mundo do teste sem rodar a suíte**: `sim_probe.tscn -- --suite --warm=0 --ticks=3000 [--phases] [--census]`
(`--suite` = jogador berserker na cidade, bots em rodízio de classe no ponto de entrada, como o `run_all`; `--census` =
entidades por mapa e tipo, monstros dormindo, loot). O mundo padrão da sonda é bem mais leve que o do teste.

### Aplicado (soma de conferência idêntica em tudo: sonda padrão 1200 e 3000 ticks, `--suite` 2000 e 3000, e o estado
### do mundo logo depois dos 3000 ticks dentro do próprio teste)

1. **Variável de laço tipada** (`for e: SimEntity in ...`) nos laços de entidade de `core/sim` (tick, `_index_map`,
   `_separate_from`, `Combat.nearest_hostile`, cérebros, sistemas): acesso a campo e chamada deixam de ser por nome.
   `_index_map` com uma busca no dicionário por entidade (era `has` + índice).
2. **Loot** (`LootSystem.update_loot`): era itens × personagens todo tick. Agora os personagens vivos entram num índice de
   células de 1 m (as 9 em volta; o alcance é 0,9 m) e cada item olha só a célula dele, na mesma ordem da lista do tick.
3. **Spawners** (`MobSystem.update_spawners`): a lista `alive` só é refeita quando alguém sumiu do mundo
   (`WorldSim.despawn_epoch`, sobe em `despawn`; era um `filter` com lambda por spawner por tick); spawner cheio e sem
   escolta sai antes do resto.
4. **Caminho comum sem chamadas** em `WorldSim`: monstro dormindo sai do laço de comandos sem chamar `_dormant`;
   `update_recall`/`update_gather` só são chamados com volta/colheita em curso (o primeiro montava um dicionário por
   personagem por tick); movimento sem `has_debuff`/`slow_factor`/`move_mult` quando não há debuff nem montaria;
   `_move` com o `clamp_inside` embutido; recargas só descontam o que está contando; MP cheio não recalcula;
   `_separate` sem o `{}` padrão por chamada.
5. **Portais** (`PortalSystem.check_portals`): descarte por distância (folga de 0,1%) antes do teste exato.

### Números (máquina com outros Godot rodando: só valem pares alternados base/otimizado)

| O quê | antes | depois |
|---|---|---|
| `sim_probe` padrão, 1200 ticks (máquina calma) | 7,07 / 7,27 / 8,18 ms/tick | 4,94 ms/tick |
| `sim_probe --suite`, 3000 ticks (máquina calma) | 9,6 ms/tick | 6,5 / 6,8 ms/tick (itens 1-4) |
| `sim_probe --suite`, 3000 ticks (carregada, alternado) | 10,6 / 11,4 / 10,9 ms/tick | 8,8 / 8,6 ms/tick |
| os 3000 ticks do teste (carregada, alternado) | 31,8 / 35,2 s | 28,9 / 26,9 s |

Ganho por passo no `--suite` (máquina calma): 1 → 9,6 para 8,7; 2-3 → 8,4; 4 → 6,5-6,8; 5 e a tipagem do resto dos
laços ficaram dentro do ruído.

### Considerado e não aplicado

- **Descarte por listas compactas no `MapGeometry.resolve_obstacles`** (centro/raio em `PackedFloat64Array`): mesma soma,
  sem ganho medível; revertido.
- **Lista só de monstros por mapa** para `nearest_hostile`/`_pick_monster` dos bots (o `nearest_hostile` de 9 m dos bots
  é ~0,35 ms/tick): precisa valer também para quem nasce no meio do tick e para teste que chama o cérebro direto.
- **Reaproveitar a grade de vizinhos em mapa onde todos dormem**: ganho estimado < 0,1 ms/tick (esses mapas já rodam
  a cada 4 ticks).
- **Grade exata para os alvos dos bots**: a grade do tick fica velha depois que as entidades andam; não dá a mesma soma.


## Sim com GvG/leilão/elenco (2026-11-27)

Pedido: o teste longo (`performance da simulação`, 3000 ticks, limite 40 s) passava raspando (37-45 s no master).
Perfil com cronômetros temporários (`sim_probe --suite --warm=0 --ticks=3000 --phases`, removidos depois): o custo
continua espalhado por entidade acordada; os sistemas novos (GvG, leilão, elenco) somam ~0 sem guerra/elenco ligados.
Achados: `update_spawners` 0,78 ms/tick (a lista `alive` de TODO spawner era refeita com lambda a cada despawn do
MUNDO: com 3000 entidades, quase todo tick), `_dormant` 0,39 (`has_meta` por monstro acordado), `_defend` 0,30
(`raid_status` montava um dicionário e copiava ids a cada pensamento de bot em mapa com investida), projéteis 0,55.

### Aplicado (soma de conferência idêntica antes/depois em todas as rodadas)

1. **Spawner sujo só quando um monstro DELE some**: `SimEntity.spawner_ref` (posto em `spawn_monster`), `despawn`
   marca `sp["dirty"]`; `MobSystem.update_spawners` só refaz a lista desse (0,78 → ~0,5 ms/tick).
2. `SimEntity.dorm_seen` no lugar do meta `dorm_seen`; o laço de comandos descarta o monstro dormindo antes de
   qualquer chamada (mesmas condições, outra ordem).
3. `BotBrain._defend`: `RaidSystem.any_active(m)` antes de `raid_status` (0,30 → 0,06 ms/tick).
4. `TrapSystem.update_traps` e `_update_projectiles` saem cedo com lista vazia; o teste de acerto do projétil mede a
   distância antes das condições (puras) de alvo (0,45 → 0,15-0,2 ms/tick).
5. Grade de separação com chave inteira (`WorldSim.sep_key`) no lugar de `Vector2i` (`_index_map`, `_separate`,
   `MonsterBrain._isolated`).

### Números (`sim_probe --suite --warm=0 --ticks=3000`, pares alternados)

| Rodada | base (ms/tick) | otimizado (ms/tick) |
|---|---|---|
| r1 (itens 1-4, máquina calma) | 10,99 / 11,26 | 10,84 / 10,39 |
| r2 (itens 1-5) | 11,72 / 11,08 | 10,75 / 10,19 |

Teste longo da suíte: 35,4 s (itens 1-4, máquina calma) contra 37,2-45,2 s antes; com os itens 1-5 e outros Godot
abertos ao mesmo tempo, 40,0 s: a medida da suíte oscila muito com a máquina ocupada (a calibração de 1 thread não
vê a disputa de memória). Meta de 32 s não alcançada.

### Ainda caro (próximos candidatos)

- `upd_MONSTER` ~1,6, `think_bot` ~1,5, `index_map` ~1,4, `apply_MONSTER` ~1,0, `upd_NPC` ~0,8 ms/tick (NPC parado
  só soma `state_time`); Aldara sozinha ~2,2 ms/tick (comandos 1,2). Um índice só de monstros por mapa para
  `nearest_hostile`/`_pick_monster` dos bots continua sendo o maior ganho provável (ver "Considerado e não aplicado").
