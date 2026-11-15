# Fluxo de início — spec de UX + plano de implementação

Status: RASCUNHO revisado · 2026-11-14 · dono: ux-designer · implementação: ui-programmer
Revisão técnica (godot-specialist, 2026-11-14, `production/session-state/review-start-flow.md`): **aprovar com mudanças**;
as 6 mudanças pedidas estão aplicadas abaixo (§5, §7, §8, §9 nova, §12).
Decisões fixas do usuário (não reabrir): cena própria `game/menu/start.tscn`; cenário 3D pequeno e iluminado
atrás do menu, boneco num pedestal na criação; escopo = Título, Personagens, Criação refeita, Carregamento.

## 1. Objetivo para o jogador

Abrir o jogo e estar jogando em poucos cliques, sem ver o mundo "por trás" do menu. Cada tela tem UMA ação
principal (Enter) e UMA saída (Esc). O mundo (sim + mapas + bots) só existe depois que o personagem foi escolhido.

## 2. Fluxo

```text
Boot (autoloads: GameData.load_all) ──> start.tscn
          │  (flag de autostart? ──> main.tscn direto, montagem síncrona, sem tela de Carregamento)
          v
        TÍTULO ──Jogar──> PERSONAGENS ──Novo / espaço vazio──> CRIAÇÃO (Classe -> Visual)
          │  Configurações (painel sobreposto)  │  Jogar (card)          │  Começar aventura
          │  Sair (confirma)                    v                        v
          │                              CARREGAMENTO ──ok──> main.tscn (jogo)
          │                                     │ falha ──> PERSONAGENS + aviso
          │                                     │
        jogo: Esc → "Salvar e voltar ao menu" ──> salva, Sim.reset_world ──> start.tscn em PERSONAGENS
```

Atalho: com 0 personagens, "Jogar" no título abre direto a CRIAÇÃO (sem lista vazia). Voltar da Criação com 0
personagens volta ao TÍTULO.

## 3. Telas (base 1600x900; 1920x1080 e 1280x720 pelo stretch do projeto)

Base: o projeto renderiza em 1600x900 (`canvas_items` + `expand`, `project.godot:29-35`) com janela 1920x1080; a UI é
feita para 1600x900 e escala. Regra: nenhum texto < 12 px na base (= 9,6 px a 1280x720, nosso mínimo legível); alvos de
clique ≥ 40 px de altura. Em 21:9 o canvas fica mais LARGO: tudo centrado por âncoras, nunca por x fixo. As câmeras do GLB
mantêm o FOV vertical, então o ultrawide mostra mais do cenário: conferir que `menu_set` tem borda larga o bastante.

**Cenário (todas as telas):** o acampamento com fogueira na beira de Aldara (`menu_set.glb`, ver Decisões), 3D na própria
cena. Câmera fixa por tela (`CAM_title`, `CAM_create`...), transição suave de 0,6 s, pulável com clique/Enter.

**Título**
- Logo "RAGNAEX" no terço superior, centralizado. Coluna de 3 botões (280x48) no centro-baixo: Jogar (foco inicial),
  Configurações, Sair. Versão do jogo no canto inferior direito (12 px, cor MUTED).
- 1280x720: mesma coluna; logo reduz para 70%.

**Personagens**
- Faixa horizontal de 5 cards (5 espaços = `SaveSystem.SLOTS`), centrada por âncoras no terço inferior; o cenário fica
  visível em cima. Card 260x340 (5 × 260 + 4 × 16 = 1364 < 1600). `HBoxContainer` de `PanelContainer` com
  `focus_mode = FOCUS_ALL` (←/→ pela navegação de foco do Godot).
- Card ocupado: retrato (`user://portrait_<n>.png`, ícone da classe se não houver), nome (GOLD 18), "Classe · Nível N" (14),
  nome do mapa (12 MUTED), borda na cor da classe. Card vazio: "+ Novo personagem", borda tracejada/apagada.
- Card selecionado: borda clara + boneco do personagem no pedestal (mesmo `KitModel` da criação, ocioso).
- Barra de ações sob a faixa: [Voltar] ... [Excluir] [Jogar] (Jogar é o maior, cor GOLD). Ações agem no card selecionado.

**Criação**
- Esquerda (≈ 40%): o pedestal 3D no cenário (`SPOT_pedestal`, `CAM_create`; sem SubViewport), boneco ~70% da altura.
  Arrastar gira e roda do mouse aproxima, via `_unhandled_input` só sobre os 40% da esquerda (não briga com os Controls).
  Abaixo: Nome + botão de sorteio, "Visual aleatório".
- Direita (≈ 55%, painel `UiKit.panel`): passos "1 Classe" / "2 Visual". Classe = grade com todas as classes
  (`GameData.class_list()`) (ícone + nome) e, abaixo, descrição, armas, papéis das builds. Visual = abas Corpo / Cabelo / Rosto.
- **Classe em ação:** ao selecionar uma classe o boneco toca em laço o clipe da skill-assinatura (só animação, sem efeito,
  sem sim), voltando ao idle a cada 4 s; na aba Visual fica em idle, de frente, sem chapéu. O clipe vem do helper estático
  da §9 (o mesmo que o jogo usa), nunca de um mapeamento copiado.
- Rodapé: [← Personagens] ... seletor "Começo" (ver Q6) ... [Próximo: visual →] / [Começar aventura].

**Carregamento**
- Tela cheia: arte/nome da zona de destino (foto do mapa ou cor da zona + nome grande), barra de progresso no terço inferior
  (largura 60%), texto da etapa ("Carregando mapas…", "Chamando aventureiros…", "Preparando Aldara…"), e um cartão de dica
  sorteado de `Tips.TIPS`. A barra nunca anda para trás; com tudo pronto, segura 0,3 s em 100% e corta para o jogo.
- Os pesos das etapas saem dos tempos medidos (`BOOT`, §7), não de chute.

**Configurações (painel sobre o Título)**: Gráficos (`GraphicsSettings.cycle`), volumes (`AudioSettings.BUSES`), Dicas
ligadas/desligadas. Mesmo bloco do menu Esc: extrair para um painel compartilhado (`game/ui/settings_panel.gd`).

## 4. Entradas

| Tela | Enter | Esc | Outras |
|---|---|---|---|
| Título | ativa o botão em foco (Jogar) | fecha Configurações; senão nada | ↑/↓ movem o foco; Sair pede confirmação |
| Personagens | Jogar (card ocupado) / Novo (card vazio) | volta ao Título | ←/→ escolhem o card; Delete = Excluir |
| Criação | Próximo → Começar aventura | volta um passo (Visual→Classe→Personagens) | Tab/Shift+Tab nos campos; Nome: `text_submitted` confirma, Esc tratado em `_unhandled_input` (o `LineEdit` engole Enter/Esc) |
| Confirmar exclusão | Cancelar tem o foco | cancela | botão Excluir em vermelho |
| Carregamento | — | — | F11 continua valendo (nó na raiz, §9) |

Foco: toda reconstrução de tela (hoje por `queue_free`, que derruba o foco) termina com `grab_focus.call_deferred()` no
controle padrão da tela. Mouse: tudo clicável; duplo clique num card ocupado = Jogar. Gamepad: fora do escopo, mas a
navegação de foco do Godot deixa o gamepad barato depois.

## 5. Estados e casos de borda

- **0 personagens:** Título → Jogar abre a Criação; Personagens nunca aparece vazia.
- **5 espaços cheios:** card "Novo" não existe; barra mostra "Todos os 5 espaços ocupados: exclua um para criar outro."
- **Excluir:** diálogo modal "Excluir <Nome> (Classe, Nível N)? Isso não pode ser desfeito." [Cancelar] [Excluir]. Substitui
  o "clique duas vezes" atual. Apaga também `user://portrait_<n>.png`.
- **Save corrompido** (bug confirmado na revisão): `has_slot` só olha se o arquivo existe, `first_free_slot` pula o espaço,
  `load_data`/`slot_summary` devolvem `{}` e `_build_slots` não cria card — o espaço some, não dá para usar nem excluir, e
  `has_save()` verdadeiro pode abrir a lista com zero cards. Novo: `SaveSystem.slot_state(i) -> "empty"|"ok"|"corrupt"`,
  onde **corrupt = arquivo existe e (JSON inválido OU dicionário vazio `{}` OU sem a chave `class`)**. Card "Save danificado"
  (ícone de aviso, sem Jogar), só Excluir (a confirmação diz o nome do arquivo).
  Causa provável: `save_player` grava por cima do arquivo; fechar no meio trunca. Gravar em `.tmp` + renomear = Q7 (aberta).
- **Classe/mapa que não existe mais no save:** card mostra a classe padrão e mapa "?" (como hoje); carrega pela regra atual de `start_game`.
- **Falha no carregamento** (`ResourceLoader` com `THREAD_LOAD_FAILED`, ou erro ao montar): volta a Personagens com faixa
  vermelha "Não foi possível carregar. Tente de novo." e o erro no log; nada é gravado.
- **Fechar a janela no carregamento:** sai sem salvar (o personagem ainda não entrou).
- **Volta do jogo:** salva, `Sim.reset_world`, troca para `start.tscn` direto em Personagens com o card do personagem que
  acabou de sair selecionado. `reset_world` não zera `Sim.threaded`, `Engine.max_physics_steps_per_frame`, estáticos de dev
  (`away_every`, `KitModel.merge`) nem os caches (`MapBuilder._prop_cache`, RigidMerge, KitModel — bom manter: a 2ª carga é
  mais rápida); igual ao `reload_current_scene` de hoje. `returning` sai do `main` (static) e vai para `StartRequest`.
- **Nome vazio** → "Herói" (como hoje). Nome com mais de 16 letras é cortado no campo.

## 6. O que muda de lugar

- `game/ui/class_select.gd` → dividido em `game/menu/`: `start.gd` (máquina de telas), `title_screen.gd`, `char_list.gd`
  (cards), `delete_dialog.gd`, `char_create.gd` (passos, abas, nome, presets; reaproveita `_choice_row`, `_swatches`,
  `_rebuild_model`, `NAMES`, e o `--look` de `class_select.gd:59-68`), `loading_screen.gd`, `menu_set.gd` (cenário 3D +
  pedestal + câmeras), `portrait.gd`, `start_request.gd`. `class_select.gd` sai (exclusão de arquivo: aprovação do usuário).
- `hud.gd`: saem `show_class_select`, `reopen_class_select`, `on_class_chosen`, `class_select` (`hud.gd:1193-1210`); o bloco
  de configurações do menu Esc (`hud.gd:1111-1185`) vira `SettingsPanel` (usado pelos dois).
- `main.gd`: `_ready` deixa de mostrar a cidade de fundo e de chamar `show_class_select`; lê o `StartRequest` (classe, nome,
  load_save, look, preset, slot) e chama `build_world(staged)` (§7); `return_to_menu` troca para `start.tscn` em vez de
  `reload_current_scene`; o `_input` do F11 sai daqui (§9).
- `project.godot`: `run/main_scene` = `res://game/menu/start.tscn`.

## 7. Autoloads, a sim e a montagem

- `Events`, `Balance`, `GameData`, `SaveSystem` continuam carregando no boot (o menu precisa das classes, looks e saves).
  **`GameData.load_all` roda na inicialização dos autoloads, ANTES de qualquer cena** (todos os catálogos + JSONs de zona;
  `city_aldara.json` sozinho tem 35k linhas): nenhuma tela de Carregamento cobre esse tempo. Só o splash do boot ou um
  GameData mais enxuto (fora deste escopo).
- `Sim` existe mas fica VAZIO no menu: nenhum `Sim.load_map`, `spawn_*`, nem `SimSync.install` antes do Carregamento.
  Regra testada: na tela inicial `Sim.maps`, `Sim.entities` e `Sim.parties` vazios.
- **O custo real é o `main._ready`**, não o `main.tscn`: `Sim.load_map` de ~26 mapas (grade de colisão, colheita, NPCs;
  provavelmente o maior), `_populate_bots`, `MapBuilder.build` do destino e os kits. Hoje não há marcação de tempo (um
  `--autostart=paladin` headless levou 35,3 s, sem como separar por etapa). **Etapa A adiciona prints `BOOT <etapa> <ms>`**
  (`Time.get_ticks_msec()`) em cada passo, inclusive o fim dos autoloads, e os pesos da barra saem deles.
- **`main.build_world(staged: bool)`:**
  - `staged = true` só no caminho do jogador: `await get_tree().process_frame` entre etapas (um mapa da sim por quadro,
    bots, mapa visual, fila de views), emitindo progresso. Seguro: com `Sim.running == false` e `_queued_cmds` vazio o
    `SimSync`/`start_async` não roda tick. A sim fica na thread principal (rodar `load_map` num WorkerThreadPool é otimização futura).
  - `staged = false` no caminho dev/autostart: **síncrono, nenhum `await`**, como hoje. Motivo: `before_start` arma corrotinas
    e `call_deferred`/timers (`_perf_run` lê `Sim.player`/`main.map_node` após 1 s; `--gather_shot`, `--recall_shot`) que
    contam com o mundo pronto.
- **Carga em thread:** `ResourceLoader.load_threaded_request` de `main.tscn`, `map_<zona>.glb` do destino e
  `kit_<classe>_<sexo>.glb`. **Guardar os Resources devolvidos** (array no `StartRequest` ou na tela de Carregamento) até o
  `main` avisar "pronto": `MapBuilder.build` e `KitModel.create` chamam `load()` por conta própria e só acertam o cache
  enquanto há referência viva.
- **Overlay de Carregamento:** `CanvasLayer` simples adicionado a `get_tree().root` (NÃO autoload: autoload novo é decisão de
  arquitetura e ficaria vivo a sessão toda), `layer = 100` (HUD usa 10, class_select 20). Adicionado ANTES de
  `change_scene_to_packed` (a cena velha é liberada no fim do quadro), sobrevive à troca como o `SimSync`; o `main` o acha
  pelo nome ou pela referência no `StartRequest` e o libera depois do "pronto" + 0,3 s.

## 8. Flags de dev (todas continuam)

Regra: `start.gd` decide no `_ready`, ANTES de montar o cenário, com **só a decisão** extraída de `DevRunner.before_start`
para uma função estática pura: `DevRunner.autostart_class(args, returning) -> String`. `before_start` NÃO é puro
(`--showcase` cria `Showcase` com o `main`, `--gfx` mexe no viewport, `--perf` inicia corrotina, `--view_budget`/`--cull`
escrevem no `main`): esses efeitos ficam em `before_start`, no `main`. Classe ≠ "" → `StartRequest` de teste (slot -1, nome
"Smoke") e `main.tscn` direto com `build_world(false)`.

| Flag | Papel | Onde roda |
|---|---|---|
| `--autostart`, `--tour`, `--water_tour`, `--showcase`, `--playtest`, `--soak`, `--perf` | **decidem** o autostart (`dev_runner.gd:107-177`); `returning` cancela | `autostart_class` no start → main; `SaveSystem.slot = -1` mantido |
| `--preset`, `--level`, `--ascend`, `--gear` | **parâmetros**, nunca disparam autostart (`main.gd:101`, `dev_runner.gd:221-227`, :380) | main, sem mudança |
| `--gfx`, `--view_budget`, `--cull*`, `--sim_sync`, `--no_*`, `--screenshot`, `--welcome` (`main.gd:148`) | efeitos/ajustes | main, sem mudança |
| `--bag_shot`, `--wins`, `--shop`, `--enhance`, `--dnd_check`, `--hotbar_drag_check`, `*_shot`/`*_film` do `after_start` | fotos/checagens no jogo | main, sem mudança (dependem de `--autostart`) |
| `--title_shot` (+ `--title_class/_step/_tab`) | hoje armado em `before_start` (:168) e mexe em privados do `class_select` (:1554-1570) | **reescrito** num `StartDev` pequeno no start, contra uma API pública de teste de cada tela; `--title_step=title|slots|class|look|loading` |
| `--look` | hoje em `class_select.gd:59-68`, não no dev runner | vai com a criação para `char_create.gd` |
| `--select_shot` | hoje em `at_title` (:292-303), que supõe o `main` como título | start (`StartDev`) |
| `--return_check`, `--menu_shot`, `--return_shot` | `_menu_check` (:1601-1608) → `hud._menu_to_title` → `main.return_to_menu` | começo fica no main; **o `RETURN_CHECK ok entities=0 maps=0 parties=0 player=false` passa para `start.gd`** (sai de `at_title`) |
| Smoke do exportado (`RagnaEx.exe --headless -- --autostart=...`) | — | start → main; conferir o filtro do `export_presets.cfg` (incluir `game/menu/*` e `assets/models/menu_set.glb` se filtrar) |

Testes (`tools/tests/tests.tscn`) e sondas (`*_probe.tscn`) não usam a cena principal: não mudam.

## 9. Montagem que sai do `main` (nova)

- **Gráficos e áudio no start:** `start.gd._ready` chama `GraphicsSettings.load_and_apply(get_viewport())` e
  `AudioSettings.load_and_apply()` (estáticos, seguros de chamar duas vezes) ANTES de tocar ou desenhar algo: sem isso o menu 3D
  sai sem o preset salvo (FSR/125%) e o barramento `Music` ainda não existe (os volumes salvos seriam ignorados). `--gfx`
  continua sobrepondo em `before_start`.
- **Som do menu:** `Music` é um nó `class_name` criado no `main` (`main.gd:59-62`) e fica mudo sem `Sim.player`. **Não criar
  autoload `Music`** (o nome colide com o `class_name`). O menu tem um player próprio (`AudioStreamPlayer` tocando
  `assets/audio/music/aldara.ogg` no barramento `Music`) e um player pequeno de sons de UI com os sons existentes (o `Sfx`
  também depende do `main`).
- **F11:** sai do `main._input` (`main.gd:25-34`) para um nó na raiz (junto do `SimSync` ou instalado pelo start uma vez),
  valendo no menu, no Carregamento e no jogo.
- **Retrato:** `game/menu/portrait.gd` (estático `capture(entity_view, slot)`; nunca em `core/`, onde está o `SaveSystem`),
  chamado por `main`/`hud` nos pontos de salvar (nome da função combinado na P1). `SubViewport` com `own_world_3d`, fundo
  transparente e `UPDATE_ONCE` (ou recorte do viewport principal). Guarda: `DisplayServer.get_name() == "headless"` → não captura.
- **Clipe da classe em ação:** helper estático puro `clip_for_skill(skill, class_id) -> String` em
  `game/entities/entity_view.gd`, usado pelo `EntityView._action_clip` (que hoje precisa de `SimEntity`) e pela criação.
- **Kits na criação:** `KitModel.create` instancia o kit inteiro da classe (20 kits grandes; trocar classe/sexo dá tranco).
  Cache de `PackedScene` por chave, `load_threaded_request` ao passar o mouse/foco num card de classe, um boneco vivo só.
- **Pedestal = 3D na cena** (mesmas luzes, sombras e escala de gráficos, uma passada); SubViewport só para o retrato.

## 10. Testes (`tools/tests/run_tests.gd`)

- `_check_start_flow`: `DevRunner.autostart_class` para listas de args (vazio → "", `--autostart=druid` → druid,
  `--perf` → paladin, `--preset=20` sozinho → "", `--level=30` sozinho → "", `returning` → ""); `start.tscn` existe e é a
  `run/main_scene`; o menu montado em teste não carrega mapa na sim (`Sim.maps` antes == depois).
- `_check_save_slots` (ampliar): `slot_state` em `TEST_SLOT` com arquivo ok / JSON quebrado / `{}` / sem `class` / ausente;
  espaço corrompido não conta como livre E aparece como "corrupt" (nunca `save_0..4`).
- `_check_start_request`: `StartRequest` ida e volta (classe, nome, look, preset, slot) e `returning` limpo depois do uso.
- `_check_return_world`: depois de `reset_world`, `Sim.maps`/`entities`/`parties` vazios.
- `_check_loading_steps`: etapas com pesos somando 1 e textos não vazios; dica sorteada ∈ `Tips.TIPS`.
- `_check_clip_helper`: `clip_for_skill` da skill-assinatura de cada classe ≠ "" e igual ao que `_action_clip` escolhe.
- Smoke: `-- --autostart=berserker` 0 `SCRIPT ERROR`; `-- --autostart=paladin --return_check` imprime `entities=0 maps=0`.

## 11. Evidência (screenshots em `production/qa/evidence/start-flow/`)

1. Título 1920x1080 e 1280x720 · 2. Configurações abertas · 3. Personagens com 0→(cai na criação), 3 e 5 espaços, e 1
corrompido · 4. Confirmação de exclusão · 5. Criação: passo Classe com 2 classes em ação (2 quadros cada) e Visual nas 3 abas,
nas duas resoluções · 6. Carregamento a ~50% · 7. Volta do jogo (`--return_shot`) com o card selecionado · 8. Título em 21:9.
Fotos com saves de teste: `--menu_saves=<n>` em `TEST_SLOT`/memória (Q5), nunca nos espaços reais.

## 12. Plano em etapas (divisão da revisão)

**P1 Base e roteamento** — serial, 1 agente, ~0,5–1 dia. Dono de `game/menu/start.tscn`, `start.gd`, `start_request.gd`,
`project.godot`, roteamento do `main.gd` (`return_to_menu`, leitura do `StartRequest`, esqueleto de `build_world(staged)`) e
`DevRunner.autostart_class`. Escreve também os **esqueletos e a interface das telas** (`title_screen.gd`, `char_list.gd`,
`char_create.gd`, `menu_set.gd`, `loading_screen.gd`: cada uma um Control/Node3D com sinais tipados que o `start.gd` liga) e
combina o nome do gancho do retrato. Menu provisório reaproveita o `class_select`. **Portão:** smoke `--autostart` e
`--return_check` passando antes do trabalho paralelo.

**Em paralelo** (cada agente na sua worktree; nenhum arquivo compartilhado):
- **A — Carregamento + main** (~1–1,5 dia). Dono de `game/main.gd`, `game/menu/loading_screen.gd`,
  `game/menu/start_request.gd`, `game/dev/dev_runner.gd`. Montagem em etapas, prints `BOOT`, cargas em thread com referência
  guardada, falha volta à lista, porte de `at_title`/`_menu_check`/`--select_shot` para o start, `StartDev`/`--title_shot`
  reescrito (contra as APIs dos esqueletos), F11 movido, chamada do gancho de retrato nos pontos de salvar.
- **B — Cenário + Título + Configurações** (~1 dia). Dono de `game/menu/menu_set.gd`, `game/menu/title_screen.gd`,
  `game/ui/settings_panel.gd`; no `hud.gd` mexe SÓ no bloco de configurações do Esc (:1111-1185). Também: player de música
  e sons de UI do menu, `AudioSettings`/`GraphicsSettings` no start, câmeras com transição, conferência do 21:9.
- **C — Personagens + save + retrato** (~1 dia). Dono de `core/save_system.gd` (`slot_state`), `game/menu/char_list.gd`,
  `game/menu/delete_dialog.gd` (novo), `game/menu/portrait.gd` (novo). Card corrompido, foco por teclado, `--menu_saves`.

**P5 Criação** (~1,5–2 dias) — 1 agente depois de B (precisa do pedestal e das câmeras do `menu_set`); pode sobrepor o fim
de A. Dono de `game/menu/char_create.gd` e do helper `clip_for_skill` (função nova em `game/entities/entity_view.gd`:
combinar com quem tiver esse arquivo), cache de kits, `--look`. Excluir `class_select.gd` e os métodos do `hud`
(:1193-1210) exige aprovação explícita do usuário.

**P6 Fechamento** (~0,5–1 dia) — serial: checks da §10, fotos da §11, README/`docs/DESIGN.md` (tela inicial), export e
smoke do `.exe` (com o filtro do `export_presets.cfg` conferido).

**Regras de merge**
- `tools/tests/run_tests.gd` (todo agente mexe): cada agente acrescenta SÓ suas funções `_check_*` novas + uma linha na
  tabela de despacho, juntado 3-way por arquivo no fim (método de merge das worktrees); ou o orquestrador põe todos os
  checks da §10 na P6.
- `hud.gd`: B (bloco de configurações) e depois P5 (remoção do class_select) — faixas diferentes, mas merge em série.

Estimativa: ~5–7 dias-agente em série; ~3,5–4,5 com A/B/C em paralelo.

## 13. Perguntas abertas

- Q1–Q4: decididas (ver abaixo).
- **Q5 Saves de teste para fotos:** flag dev `--menu_saves=<n>` que cria saves falsos só em `TEST_SLOT`/memória? (padrão proposto: sim)
- **Q6 Presets de começo rápido** (nível 10/16/20...) visíveis na criação final ou só em dev? (padrão proposto: só dev)
- **Q7 Gravação segura do save (mudança de escopo):** passar `save_player` a gravar em `save_<n>.json.tmp` e renomear, para
  não truncar o arquivo se o jogo fechar no meio? A detecção de corrompido (§5) entra de qualquer forma; isto evitaria a causa.

## Decisões do usuário (2026-11-14)
- Q1 Fundo: acampamento com fogueira na beira de Aldara — já modelado: `tools/blender/menu_set.py` → `assets/models/menu_set.glb` (nós `SPOT_pedestal`, `CAM_title`, `CAM_create`, `LIGHT_fire`, `LIGHT_lantern`, `MS_flames`; cores do entardecer em `menu_set.DUSK`; prévias em `production/qa/evidence/start-flow/`).
- Q2 Retrato do cartão: foto salva pelo jogo em `user://portrait_<n>.png` ao salvar; ícone da classe se não houver.
- Q3 Classe em ação: só a animação da skill-assinatura (sem efeito, sem sim no menu).
- Q4 Música/sons: tema de Aldara + sons de UI existentes (sem faixa nova).
- Q5/Q6: pendentes (padrão proposto: saves falsos só no `TEST_SLOT`/memória via flag dev; presets de início rápido só em dev).

## Implementação

Estado em 2026-11-14, worktree de integração `sf-int` (tudo sem commit; plano em `production/commit-plan-startflow.md`). Fechamento P6 pendente: ver o fim.

### O que saiu
- **P1 roteamento:** `run/main_scene` = `game/menu/start.tscn`; `start.gd` (máquina de telas), `start_request.gd` (`StartRequest`, estático: `new_character`, `pending`, `returning`, `last_slot`, `error`),
  `DevRunner.autostart_class(args, returning)` pura, `main.build_world(staged)`, `return_to_menu` troca para `start.tscn`. `class_select.gd` (+ `.uid`) removido, assim como `show_class_select/reopen_class_select/on_class_chosen` do `hud.gd`.
- **Save:** `SaveSystem.slot_state` (`empty|ok|corrupt`), gravação atômica `.tmp` + renomear, `_settle_tmp`, `first_free_slot` só vazio, `delete_slot` apaga `.tmp` e o retrato (Q7 aprovada e feita).
- **Personagens:** `char_list.gd` (5 cards, foco por teclado, card "Save danificado"; excluir o último personagem abre a Criação no 1º espaço livre, §5 "Personagens nunca aparece vazia", decisão 2026-11-15), `delete_dialog.gd` (Cancelar focado, Esc cancela), `portrait.gd` (`Portrait.capture(view, slot)` → `user://portrait_<n>.png`, Q2), `--menu_saves`, `--menu_delete` (Q5).
- **Cenário/Configurações/áudio:** `menu_set.gd` + `menu_set.glb` (Q1), `menu_audio.gd` (tema de Aldara + cliques, Q4), `settings_panel.gd` (usado pelo Título e pelo Esc do HUD; `hud._volume_row` saiu), `tools/menu_set_view.tscn`.
- **Título:** `title_screen.gd` (logo + subtítulo, Jogar/Configurações/Sair, versão, fade-in 0,6 s, teclado), `pedestal_preview.gd` (kit no pedestal do Título/lista; silhueta `menu_silhouette.glb` no espaço vazio).
- **Criação:** `char_create.gd` (passo Classe com a skill-assinatura em ação, passo Visual com abas Corpo/Cabelo/Rosto, nome, `--look`, `--dev_presets`/`--preset` com `StartCatalog.PRESETS`, Q3/Q6), `EntityView.clip_for_skill`.
- **Carregamento:** `loading_screen.gd` (overlay layer 100 na raiz, `STEPS` com pesos, arte `assets/ui/loading/<mapa>.jpg`, faixa de erro `LoadError`), cargas em thread com referência guardada, `main.save_game()`, F11 em `window_keys.gd`, `StartDev` (flags de revisão).
- **Testes:** `_check_start_flow`, `_check_char_create`, `_check_char_list`, `_check_menu_set`, `_check_settings_panel`, `_check_loading_steps`, `_check_save_slots`, `_check_title_screen`. Últimos números dos agentes: suíte 78 5xx-78 6xx passando, 0 falhas; smoke 0 `SCRIPT ERROR`; `RETURN_CHECK ok entities=0 maps=0 parties=0 player=false screen=list`.
  Rodar a suíte completa de novo no `sf-int` antes de commitar (os números são de worktrees separadas).

### Desvios da spec
1. **Custo do Carregamento:** a spec supunha `Sim.load_map` como o maior custo; a medição `BOOT` mostra os **bots em ~82%** (~18-20 s de ~19-22 s; `sim_maps` ~0,25 s). Os pesos de `STEPS` seguem a medição (bots 0,82) e mapas e bots rodam em fatias de `LOAD_MAP_BUDGET_MS` = 24 ms/quadro
   (a spec previa um mapa da sim por quadro e os bots numa etapa só). `start_enter` ~5,5 s (autoloads) continua sem cobertura, como a spec avisava. Otimização do spawn de bots em outra worktree.
2. **Música:** a spec dizia `aldara.ogg`; o arquivo do repo é `assets/audio/music/aldara.mp3` (`MenuAudio` aceita os dois).
3. **Sair no Título** tem confirmação própria (`TitleScreen.request_quit/confirm_quit/cancel_quit`), não o `DeleteDialog` (fixo em "Excluir").
4. **Versão no Título:** `project.godot` não tem `application/config/version`; a linha usa o texto de reserva "RagnaEx Ato II — protótipo" (`TitleScreen.version_text()`).
5. **`_check_start_request` não existe:** a entrega do `StartRequest` é conferida dentro de `_check_start_flow`.
6. **Espaço corrompido** conta em `has_save/has_slot` (a lista abre para excluí-lo) e ocupa o lugar (`first_free_slot` não o devolve), o que a spec só dizia na §5 em termos de card.
   Save principal ok vence um `.tmp` completo mais novo (escolha conservadora do agente de save; perde no máximo os últimos segundos).
7. **Cache de kits:** o cache de `PackedScene` do `PedestalPreview` é por instância (um `static` vazava "resources still in use at exit"); a spec pedia um cache por chave sem dizer o escopo.
8. **Flags a mais que a spec não listava:** `--path_shot`/`--path_class`, `--title_wait`, `--title_settings`, `--loading_map`, `--menu_set_shot`/`--shot_cam`, `--menu_delete`. `--title_step` aceita também `slots`.
9. **Export:** `export_presets.cfg` usa `export_filter="all_resources"`, então não há filtro a ajustar para `game/menu/*` e `menu_set.glb`.
10. **Esc em jogo:** `return_to_menu` ainda chama `SaveSystem.save_player` direto (depois de esperar o retrato); os outros pontos de salvar (autosave, Esc → Salvar/Sair, fechar) usam `main.save_game()`.

### Sem check / ressalvas
- `tools/blender/loading_art.py`: `ZONES`/`BOSSES` espelham o catálogo à mão; `_check_loading_art` confere os `.jpg` de todo mapa com cenário (fora interiores), nome/chão de `ZONES`, modelo/escala de `BOSSES` e o chefe no mapa (o `.jpg` desatualizado em relação ao GLB da zona continua sem check: mapa mudou = refazer).
- Enquadramento da Criação: `MenuSet.SHOT_NUDGE[&"create"]` (recuo/baixa/lado por cima do `CAM_create` do GLB, sem reexportar) tira pés e pedestal de trás da barra do nome; `MenuSet.shot_transform` é a câmera final (check em `_check_menu_set`).
- Fotos de 1280x720, Título em 21:9 e Criação nas duas resoluções existem em parte (`b2_title_21x9`, `b2_list_21x9`, `c_list_21x9`, `p5_create_21x9`); a matriz completa da §11 não foi refeita na integração.

### Pendente (P6)
- Rodar na `sf-int`: `--import`, suíte completa, smokes `--autostart` e `--return_check`; export "Windows Desktop" e smoke do `.exe`.
- Fotos da §11 que faltam na integração; escolher e commitar só as chaves (plano de commits).
- Entram depois e vão acrescentar arquivos: desempenho do spawn de bots (reduz o peso de `bots`: remedir e ajustar `LoadingScreen.STEPS`) e o balanceamento do nível 45.
