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
