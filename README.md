# RagnaEx

Protótipo de "MMO" 2.5D single-player com bots, feito em **Godot 4.7.2 + GDScript**.
Referências: Ragnarok Online (câmera alta, mundo 3D), Tree of Savior (arte pastel, chibi, toon) e
Drakantos (combate de ação: personagem encara o cursor, skillshots, mira estilo MOBA).

## Rodar

1. Instale o [Godot 4.7.2](https://godotengine.org/download) (versão padrão, sem .NET).
2. Abra o Godot → *Importar* → selecione `project.godot` desta pasta.
3. Pressione **F5**. Escolha uma classe, dê um nome e jogue.

Até 5 personagens salvos (`user://save_<n>.json`; o `save.json` antigo vira o 1º): a tela inicial lista cada um com Jogar/Excluir e o novo vai
para um espaço livre. Salva sozinho a cada 60 s e ao fechar; **Esc** (sem janela aberta) abre o menu: Salvar, Salvar e voltar ao menu, Salvar e sair.

### Testes (sem janela)

```
godot --headless --path . tools/tests/tests.tscn          # 8000+ checks de catálogo, fórmulas, quests, craft e 3000 ticks de simulação
godot --headless --path . -- --autostart=berserker        # smoke test: joga sozinho por alguns segundos e sai
```

## Controles

| Tecla | Ação |
|---|---|
| **W A S D** | mover (relativo à câmera) |
| **Botão esquerdo** | ataque básico (segurar = contínuo) |
| **Botão direito** (segurar) | bloquear para onde o cursor aponta (arco de 140° à frente; reduz dano; custa um pouco de MP) |
| **1 – 6** | skills (segure para ver a mira/alcance no chão) |
| **F1 F2 F3** | poções (configure na bolsa: Shift+clique no item) |
| **Shift** | dash (também cancela a recovery de uma skill) |
| **Espaço** | pular |
| **F** | falar com NPC |
| **Q / E** | girar câmera em passos de 45° · scroll = zoom |
| **I / C / K / L** | bolsa · personagem · skills & maestria · quests |
| **Enter** | chat (os bots respondem) · **Esc** fecha janelas · **F11** tela cheia / janela 1920×1080 |

Mira é pelo mouse como num MOBA: skills `DIRECTION` vão para onde o cursor aponta, `GROUND` caem no
cursor (limitado ao alcance), `CONE` à frente, `TARGET` no inimigo sob o cursor, `SELF` em volta de você.

## Regras

* **Atributos vêm só do equipamento**: FOR (ATK físico, bloqueio), AGI (arco/adagas, crit), VIT (HP, DEF),
  WILL (cura, MP, DEF mágica), INT (dano/crit mágico). Fórmulas em `core/sim/stats.gd`; constantes em `data/balance.gd`.
* **8 classes**, 2-3 **builds** cada (ex.: Paladino tank de escudo, cruzado de duas mãos ou templário de fogo sagrado; Bispo sacerdote, iluminado ou clérigo de batalha; Elementalista de fogo, gelo ou raio; Ranger caçador com lince, atirador de mosquete ou patrulheiro veloz de armadilhas e lentidão),
  **20+ skills por classe**, 6 na barra. **Pontos de skill** (2 por nível) aprendem skills, sobem maestria 0–5 e
  compram **evoluções** (inclusive do dash: paladino atordoa, mago atravessa objetos, assassino dash duplo, ranger rola).
  Skills exigem arma (escudo, duas armas, martelo de duas mãos…): **a arma é a build**. Detalhes em `docs/DESIGN.md`.
* **Equipamento**: espada/montante, maça/martelo, machadinha/machado de guerra, adaga, arco, cajado, varinha, foice,
  escudo e orbe; duas armas de 1 mão (Shift+clique na bolsa). **Lendários a cada 5 níveis** com bônus de conjunto
  (3 peças: INT +2; 4 peças: Bola de Fogo +20%…).
* **Nível máximo 30, progressão lenta** (~3800 kills). Morrer custa 3 % do XP e você renasce em Aldara.
* **Vale de Aldara** (zona estilo Erenshor feita no Blender): vila murada no centro (NPCs: Ancião, Capitã, Ferreiro,
  Alquimista, Mercador, Quadro) cercada pela **Campina** (1–10: lago, bosque, colinas, clareira, fazenda), rio com pontes,
  castelo na colina e penhascos; desfiladeiros levam à **Floresta Sombria** (10–20: Posto dos Caçadores murado sob **investidas élficas** periódicas, defendido por sentinelas que lutam; paliçada dos bandidos, Árvore-Mãe; a garganta norte leva à **Cidade Élfica** (17–21: Árvore-Mãe Ancestral, trents, grifos, Guardiões e o Rei Élfico no Coração da Árvore)) e às
  **Ruínas de Vel'Thar** (20–30: cemitério, pântano, pedreira, altar do dragonete, zigurate). Cada área tem um mini-boss; as **Catacumbas do Conde** (8–13) são uma dungeon ramificada com 3 chefes, para grupo. 39 quests (história, laterais e 9 recompensas repetíveis), com portões de progressão entre as zonas, 47 receitas.
* **Bots** são jogadores falsos: caçam no campo do nível deles, voltam pra vender, conversam no chat (do lugar onde estão, da classe/build e, no seu grupo, com você pelo nome), morrem e renascem.
  Eles usam exatamente o mesmo `InputCommand` que você — a simulação não sabe quem é humano.

## Arquitetura

```
core/            SIMULAÇÃO (sem nós 3D) — o futuro "servidor"
  sim/world_sim.gd   tick fixo 60 Hz, todos os mapas/entidades, comandos, skills, dano/cura/morte, movimento
  sim/systems/       regras por assunto (funções estáticas sobre o WorldSim): map_geometry (colisão/água),
                     party, loot, legend_effects, shield, item, portal, progression, gather, npc, trap, mob
  sim/entity.gd      SimEntity (jogador, bot, monstro, NPC, invocação)
  sim/input_command.gd  pacote de input por tick (jogador e bots produzem isso)
  sim/combat.gd      dano/cura/bloqueio/crit + seleção de alvos (SELF/DIRECTION/GROUND/CONE/TARGET)
  sim/stats.gd       atributos → stats derivados
  sim/ai/            bot_brain.gd (FSM de "jogador"), monster_brain.gd
  systems/           quest_system.gd, craft_system.gd (também loja)
  events.gd          EventBus: a sim emite, a apresentação escuta
  save_system.gd     espaços de save (user://save_<n>.json)
data/            dados do jogo (Resources construídos em data/catalog/*.gd; schemas em data/schemas/)
game/            APRESENTAÇÃO — só lê a sim e manda InputCommand
  main.gd            liga tudo, troca de mapa, fade de obstáculos
  dev/               modos de revisão/medição da linha de comando: dev_args.gd (DevArgs), dev_runner.gd
                     (smoke, --bag_shot, --tour, --soak, --perf...), perf_watch.gd, showcase.gd (bancada de skills)
  visual/            materials.gd (toon/outline em cache)
  player/            camera_rig.gd (pitch 52°, yaw em 45°), player_controller.gd
  entities/entity_view.gd  placeholder chibi procedural OU GLB de assets/models com animações
  world/map_builder.gd     blockout a partir do MapDef (ou props GLB quando existirem)
  fx/fx_manager.gd   dano flutuante, hit-stop, retículo de mira, projéteis, loot
  ui/                HUD, janelas, NPC/loja/craft, seleção de classe
shaders/         toon.gdshader (2 bandas) + toon_light.gdshaderinc, outline.gdshader (inverted hull), ground_reticle,
                 ground.gdshader, grass.gdshader
tools/blender/   scripts que geram os modelos low-poly e exportam GLB (zones/: layout das zonas)
tools/icons/     geradores de ícones (skills, itens, conjuntos, escudos)
tools/lineup/    filmes/fotos de bonecos e clipes para revisão
tools/tests/     testes headless (`-- --only=<pedaço>` roda só parte)
```

Para virar online: `WorldSim` roda headless no servidor; clientes enviam `InputCommand` por RPC e recebem
o estado; a apresentação não muda.

## Modelos no Blender

Os modelos são gerados por script (chibi ToS-like, flat shading, rig simples e animações
`idle/run/attack/cast/hit/die/block`). O jogo roda com placeholders enquanto os GLB não existem;
assim que um `assets/models/<nome>.glb` aparecer, ele é usado automaticamente.

**Com Blender MCP** (addon [ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp) + `uvx blender-mcp`):
peça ao Claude para rodar, via `execute_blender_code`:

```python
import sys; sys.path.append(r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender")
import build_all; build_all.run(r"C:/Users/luisf/Desktop/projects/ragnaex/assets/models")
```

**Sem MCP (headless):**

```
blender -b --python tools/blender/build_all.py -- "C:/Users/luisf/Desktop/projects/ragnaex/assets/models"
```

Nomes esperados: `kit_male.glb`, `kit_female.glb` (personagens/NPCs com todas as peças de equipamento), `mob_slime.glb … mob_dragon.glb`,
`prop_house.glb … prop_fence.glb` (lista em `tools/blender/build_props.py`).

## Próximos passos sugeridos

* Modelos finais no Blender (os scripts são um ponto de partida; vale esculpir à mão por cima).
* Mapas em GLB (`MapDef.model`) com navmesh, em vez do blockout.
* Rede: `ENetMultiplayerPeer` + `WorldSim` headless (ver `core/sim`).
* Áudio e música.

## Trabalhando com o Claude Code

Abra um terminal na pasta e rode `claude`. O projeto já traz:

* `CLAUDE.md` — regras e comandos; `docs/DESIGN.md` — regras de jogo (fonte da verdade).
* `.mcp.json` — servidor `blender` (`uvx blender-mcp`; precisa do addon ligado no Blender e de `uv` instalado).
* Agentes (`.claude/agents/`): **blender-modeler** (modelos/animações via MCP), **class-designer** (classes, skills,
  atributos, bonecos, feel de combate), **world-builder** (monstros, mapas, cidades, quests, craft, bots),
  **qa-tester** (roda os testes) e **reviewer** (confere o trabalho e dá veredito).
* Skills: `/test`, `/build-models`, `/new-content <tipo> <descrição>`, `/review`, `/layout-zone`, `/layout-check`, `blender-layout`.

Exemplo: `/new-content skill nova ultimate do Ranger que marca o chão e dispara uma rajada` → o `class-designer`
implementa com testes → `/review` confere.

**G**: voltar para Aldara (3 s parado, fora de combate).
