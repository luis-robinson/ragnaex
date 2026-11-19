# Preenchimento de skills por build (rascunho de design, 2026-11-19)

> Status: **RASCUNHO para aprovação**. Nenhum código, catálogo, `Balance` ou teste foi alterado.
> Dono: `class-designer`. Decisões do usuário (2026-11-19): toda build com **≥ 8 skills próprias**, toda classe com
> **≥ 4 skills gerais** (build `""`), sem contar ascensão (`Balance.ASC_LEVEL`/`RES_LEVEL`); níveis das skills atuais não
> mudam; as novas ocupam buracos da escada (2-28); mecânica nova é permitida; inspiração em Diablo 2/3/4 e World of
> Warcraft só para ideia e sensação (nomes e textos nossos); **cada build com identidade própria**.

## 1. Visão geral

Contagem medida em `data/catalog/skills_catalog.gd` (originais + `_more()`, sem ascensão):

| Classe | Build | Hoje | Alvo | Faltam | Níveis livres na escada |
|---|---|---|---|---|---|
| Paladino | Templário | 6 (2, 7, 13, 16, 19, 25) | 8 | +2 | 3-6, 8-12, 20-24, 26-28 |
| Berserker | Executor | 6 (4, 6, 11, 15, 17, 28) | 8 | +2 | 2-3, 5, 7-10, 12-14, 16, 18-27 |
| Bispo | Clérigo de Batalha | 6 (2, 7, 10, 14, 20, 26) | 8 | +2 | 3-6, 8-9, 11-13, 15-19, 21-25, 27-28 |
| Bispo | Sacerdote | 7 (6, 8, 10, 13, 17, 22, 28) | 8 | +1 | 2-5, 7, 9, 11-12, 14-16, 18-21, 23-27 |
| Druida | Urso | 7 (2, 3, 8, 8, 12, 18, 25) | 8 | +1 | 4-7, 9-11, 13-17, 19-24, 26-28 |
| Elementalista | Fogo | 7 (5, 9, 10, 10, 13, 22, 27) | 8 | +1 | 14-21 |
| Elementalista | Raio | 7 (4, 6, 11, 16, 17, 21, 28) | 8 | +1 | 12-15, 22-27 |
| Necromante | Invocador | 7 (3, 7, 8, 14, 16, 26, 27) | 8 | +1 | 17-25 |
| Necromante | geral | 3 (1, 1, 10) | 4 | +1 | — |
| Ranger | geral | 3 (1, 1, 6) | 4 | +1 | — |

Total: **13 skills novas**, **4 mecânicas novas** (seção 4). As demais builds já estão no alvo; a seção 3 mesmo assim
dá a identidade de cada uma e marca as que estão confusas.

## 2. Fantasia do jogador (o que muda)

- **Templário** deixa de ser "Guardião que bate": ganha chão sagrado que ele defende e uma coluna de luz que salta entre inimigos.
- **Executor** passa a ter ritmo próprio: **rachar a armadura → executar**, e um brado que o faz o tanque de apoio que o design promete.
- **Clérigo de Batalha** ganha um estandarte (chão que cura o grupo enquanto ele luta em cima) e um golpe que encadeia a luz.
- **Sacerdote** ganha a proteção preventiva clássica (escudo num aliado) já no nível 3.
- **Urso** ganha ameaça contínua num alvo (Lacerar), sem depender só do grito.
- **Fogo** ganha **espalhar** (semente que explode e acende os vizinhos), alimentando a Combustão.
- **Raio** vira o mago **móvel**: teleporte que cai como um raio.
- **Invocador** deixa de só esperar: **oferece** os próprios mortos-vivos como bombas.
- **Necromante (geral)**: puxar o alvo com uma garra da cova (serve ao Ceifador, ao Invocador e às Sombras).
- **Ranger (geral)**: um curativo de campo para as três armas (inclusive o Lanceiro, que só tinha o Recuar).

## 3. Identidade por build (uma a duas linhas) e alertas

Legenda: **OK** = identidade clara · **TURVA** = sugestão abaixo.

| Classe | Build | Identidade (gancho · alcance · ritmo) | Estado |
|---|---|---|---|
| Paladino | Guardião | Escudo, aura e ricochete que provoca; segura o aggro e protege o grupo; ritmo de bloqueio → Juramento. | OK |
| Paladino | Cruzado | Montante, sequência de 3 golpes (`strikes`) e onda sagrada; burst corpo a corpo em leque. | OK |
| Paladino | Templário | Martelos de luz à meia distância + queimadura sagrada + marca; gasta o Juramento do escudo para bater. | **TURVA** |
| Berserker | Machados Gêmeos | Velocidade de ataque e roubo de vida; muitos golpes rápidos, sustenta-se batendo. | **TURVA** (redundância) |
| Berserker | Executor | Golpe pesado e lento, execução de alvo ferido, placa e VIT; "tanque de apoio". | **TURVA** |
| Berserker | Punhos de Fúria | Esquiva vira Fúria do Punho e contra-ataque; gasta tudo no Punho Final. | OK |
| Bispo | Sacerdote | Curas em grupo, bênçãos longas e escudos; fica atrás. | OK |
| Bispo | Iluminado | Dano mágico de cetro; Radiância cura o mais ferido com o dano. | OK |
| Bispo | Clérigo de Batalha | Placa na linha de frente; cada golpe físico cura o aliado mais ferido (`mend`). | leve (sobrepõe o Templário visualmente) |
| Druida | Urso | Forma de urso, provocar, atordoar, escudos de casca; segura a linha. | **TURVA** (assinatura) |
| Druida | Lobo | Forma de lobo, Espreitar → emboscada, sangramento, velocidade. | OK |
| Druida | Xamã | Magia de área da natureza, lobos/Ent invocados, Bênção do Bosque. | OK |
| Ranger | Caçador | Arco + lince permanente; controle em área (rede, gélida, explosiva). | OK |
| Ranger | Atirador | Mosquete lento e forte + armadilhas no chão; um tiro enorme. | OK |
| Ranger | Lanceiro | Lança de perto: estocada em linha, salto na presa, sangramento que renova. | OK |
| Assassino | Lâminas | Veneno na lâmina, esquiva, Sumir, pelas costas; muitos ganchos e nenhum "fechamento". | **TURVA** |
| Assassino | Duelista | "Equilibrado" não é identidade: cone, avanço, giro, buff e finalizador genéricos. | **TURVA** |
| Assassino | Corsário | Sabre + pistola; Bravata junta e o Tiro Entre os Olhos gasta. | OK |
| Elementalista | Fogo | Queimaduras acumulam e a Combustão detona; nega área (muralha). | OK → afiada pela Semente |
| Elementalista | Gelo | Controle (retardar/prender) e estilhaço ×1,3; mais vida (VIT). | OK |
| Elementalista | Raio | Saltos de raio e chance de atordoar; hoje são áreas genéricas + buff. | **TURVA** → afiada pelo Passo |
| Necromante | Invocador | Exército por tipo; hoje é passivo (invoca e espera). | **TURVA** → afiada pela Oferenda |
| Necromante | Ceifador | Foice corpo a corpo com roubo de vida e formas Fantasma/Demônio. | OK |
| Necromante | Sombras | Maldições + canalizações (Açoite, Sugar Alma, Raio do Vazio). | OK |

### Sugestões para as TURVAS

- **Templário**: 6 das 13 skills da lista do bot são do Guardião. Resolvido pelas 2 novas (Chão Sagrado, Coluna da Alvorada).
  Ajuste opcional: tirar `pal_aegis_slam` da lista do bot do Templário (`classes_catalog.gd`) para a barra dele ficar só de martelos.
- **Machados Gêmeos**: três giros (Tempestade de Aço 13, Turbilhão de Aço 12, Tempestade de Lâminas 26) e dois golpes únicos
  parecidos (Talho Duplo 2 / Presas Gêmeas 2). Sugestão (sem skill nova): transformar o **Turbilhão de Aço** em "Sangria" —
  giro que cura por sangramento ativo nos atingidos (`heal_pct_of_dmg` maior se o alvo sangra), reforçando o roubo de vida.
- **Executor**: resolvido por Fender Armadura (ritmo rachar → executar) e Brado do Carrasco (apoio de grupo).
- **Urso**: a assinatura da build é `dru_moonfire` (skill do Xamã, cajado; o Urso usa malho). Sugestão: assinatura = `dru_maul`
  (ou a nova `dru_lacerate`), `look: "nature"`. Lacerar dá ameaça contínua num alvo.
- **Lâminas**: veneno, esquiva, furtividade e costas sem um golpe que "feche" o ciclo. Sugestão (ajuste, sem skill nova):
  **Eviscerar** consome os venenos seus no alvo e causa o que faltava × 1,25 (o mesmo esquema do `combust`, generalizado para
  veneno: chave `combust: {"detonate": 1.25, "kind": "poison"}`). Ritmo: envenenar → Eviscerar.
- **Duelista**: sugestão de gancho = **aparar**. A Guarda do Duelista vira janela curta (0,8 s): golpe corpo a corpo recebido
  nela é aparado (0 de dano) e devolve uma resposta automática (60% do ATK) + 1 carga de "Ímpeto" (+5% de crítico, até 3);
  Golpe de Mestre gasta o Ímpeto. Combina com a lendária Riposte. É mecânica nova (contaria como 5ª): fica como proposta
  separada, fora deste pacote, se o usuário quiser.
- **Raio**: resolvido pelo Passo Relampejante (mobilidade). **Invocador**: resolvido pela Oferenda Sombria.

## 4. Mecânicas novas (4)

Todas na sim (`core/`), sem Node; números só em `Balance`; efeito novo entra em `SkillDef.EFFECT_KEYS` e no comentário do
`SkillDef.effects`; repasse em `world_sim.gd` só se algo de fora precisar.

### M1 `zone` — chão que fica (dano e/ou cura em pulsos)
- **Arquivo**: `core/sim/systems/trap_system.gd` (ao lado de `place_wall`; mesmo relógio de pulsos).
- **Formato**: `"zone": {"id": "hallowed", "duration": 6.0, "pulse": 1.0, "foe_power": 0.25, "ally_heal": 0.0, "ally_buff": {...}, "foe_slow": {...}}`.
- **Regra**: no impacto a skill bate normalmente (power, efeitos). Fica um círculo de `radius` no ponto (GROUND) por `duration` s.
  A cada `pulse` s: inimigos dentro levam `foe_power` × ATK/MATK (tipo da skill) e o `dot` da skill renova neles; aliados
  dentro (você incluso) recebem `ally_heal` × fórmula de cura (`Combat.calc_heal`) e o `ally_buff` com duração `pulse + 0,5` s
  (some ao sair). **Uma zona por (lançador, skill)**: lançar de novo apaga a antiga. Zona some se o dono morrer ou trocar de mapa.
  Pulso não critica e pode ser esquivado pela AGI (é golpe da skill, não aviso de chefe). Hit-stop só no impacto.
- **Bots**: lançam no chão sob o alvo/sob o tanque e ficam dentro (Batalha); `BotBrain` já mira GROUND no alvo.
- **Usada por**: `pal_hallowed_ground`, `bis_faith_banner`. **Reuso futuro**: qualquer "consagração"/poça de jogador.
- **Visual**: disco no chão em tons do tema (nunca vermelho saturado: gramática de aviso de chefe), pulso fraco a cada tick.

### M2 `sunder` — rachadura que acumula e é consumida
- **Arquivo**: novo `core/sim/systems/sunder_system.gd` (estático, sem estado; guarda as cargas no debuff com `stacks`).
- **Formato**: na skill que aplica `"sunder": {"add": 1, "taken_per": 4, "max": 5, "duration": 8}`; na que consome `"sunder_consume": {"per": 0.10}`.
- **Regra**: cada acerto põe/renova o debuff `sunder` (id fixo, um por alvo, de qualquer Executor): +`taken_per`% de dano físico
  recebido por carga, até `max` (=20%). Conta como **marca** (entra em `Balance.MARK_CURSES`, teto `MARK_TAKEN_CAP` junto com
  Marca da Penitência/Expor). Skill com `sunder_consume`: antes do golpe lê as cargas no alvo, power × (1 + `per` × cargas),
  e zera o debuff. Chefe: acumula normal (não é controle).
- **Usada por**: `ber_sunder` (aplica); `ber_overhead`, `ber_execute`, `ber_decapitate` ganham `sunder_consume` (ajuste nelas).

### M3 `seed` — semente que explode e espalha
- **Arquivo**: novo `core/sim/systems/seed_system.gd`; gancho no fim do debuff e na morte do alvo (`WorldSim` caminho de abate).
- **Formato**: `"seed": {"delay": 4.0, "radius": 3.0, "power": 1.4, "spread_dot": true, "max_targets": 6}`.
- **Regra**: põe o debuff `seed_<lançador>` no alvo. Ao acabar o tempo **ou** ao alvo morrer antes: explosão em `radius` em volta
  da posição dele, `power` × MATK em até `max_targets` inimigos (o próprio alvo incluso se vivo) e, com `spread_dot`, aplica
  neles a queimadura da skill (pelo `_put_dot`, conta no teto de 3). A explosão **não** planta semente nova (sem cadeia infinita).
  Uma semente por (lançador, alvo): relançar renova o tempo. Dono morto/fora do mapa: a semente some sem explodir.
- **Usada por**: `ele_ember_seed`. Liga com a Combustão (que detona queimaduras espalhadas).

### M4 `sacrifice` — oferecer as próprias invocações
- **Arquivo**: `core/sim/systems/necro_ascension.gd` não (é da ascensão); novo `core/sim/systems/summon_rites.gd` (estático).
- **Formato**: `"sacrifice": {"pick_radius": 6.0, "max": 4, "blast_radius": 3.0, "power": 1.5, "hp_weight": 0.5}`.
- **Regra**: (GROUND) escolhe até `max` invocações **suas** a `pick_radius` m do ponto, das mais perto para as mais longe;
  exclui as de `Balance.SACRIFICE_EXCLUDE` (Rei Esqueleto, Lich, companheiros de outras classes) e as de grupo de outro dono.
  Cada uma explode em `blast_radius`: power × (1 − `hp_weight` + `hp_weight` × % de vida dela) × MATK, e morre (sem XP/saque).
  Sem nenhuma invocação elegível: a skill é **recusada** antes de gastar MP (motivo "Sem mortos-vivos por perto", como o
  `pet_of == null` do Caçador em `try_cast`). Inimigo atingido por várias explosões leva todas (até `max`).
- **Usada por**: `nec_dark_offering`.

**Se o usuário preferir menos mecânicas novas** (recuo para efeitos existentes):
- M1 → `pal_hallowed_ground` vira golpe único SELF com `dot` + `buff` (igual à Consagração); `bis_faith_banner` vira GROUND
  `area_heal` (já existe) + `slow`.
- M2 → `ber_sunder` vira `curse` `{"id": "sunder", "taken_pct": 15, "duration": 8}` sem acúmulo nem consumo (perde o ritmo).
- M3 → `ele_ember_seed` vira TARGET com raio, `dot` e `explode` imediato (perde o "espalhar depois").
- M4 → sem recuo bom; alternativa fraca: GROUND mágico comum (é o que a Explosão de Cadáver já faz). Recomendo manter M4.

## 5. As 13 skills

Convenções: power × ATK (físico) ou × MATK (mágico); MP e recarga no nível 0 de rank; maestria padrão (`_mastery()`).
Faixas vizinhas conferidas na mesma build/nível.

### Paladino — Templário (+2; exige `["shield"]`, gasta o Juramento como as outras)

| Campo | `pal_hallowed_ground` **Chão Sagrado** | `pal_dawn_pillar` **Coluna da Alvorada** |
|---|---|---|
| Nível | 10 | 22 |
| Alvo / tipo | GROUND / PHYS | GROUND / PHYS |
| Power · MP · CD | 1,0 (+6 pulsos × 0,25) · 16 · 12 | 3,0 · 24 · 12 |
| Alcance / raio | 8 m / 3,0 m | 9 m / 2,2 m |
| Efeitos | **M1 zone** 6 s, pulso 1 s, `foe_power` 0,25, renova `_burn(5, 2)`; aliados dentro +10% DEF (`ally_buff` id `hallowed`) | `stun` 0,5 s, `_burn(6, 3)`, `chain` {count 3, radius 5, falloff 0,5} |
| Timing | startup 0,25, recovery 0,25, cancel 0,12, hit-stop 4 | startup 0,3, recovery 0,3, cancel 0,15, hit-stop 5 |
| Inspiração | à la Consagração do paladino do WoW / D3 | à la "coluna do céu" do Cruzado do D3 |
| Por que cabe | Templário luta parado com escudo: o chão premia ficar e bloquear (Juramento) | Martelo do céu com alcance; os saltos fecham o kit de área |
| VFX / clipe | `holy` / `cast_holy` (martelo fincado), disco dourado-claro | `holy` / `cast_holy`; raios do `chain` em dourado |
| Bot | Lança sob o alvo no começo da luta e fica dentro | Em ≥ 2 inimigos a 5 m um do outro, ou chefe fora de recarga |

Talento: a linha 10 do Templário pode citar Chão Sagrado (ex. "+2 s na zona"); conferir `_check_talent_unlock_levels`.

### Berserker — Executor (+2; exige `["two_handed"]`)

| Campo | `ber_sunder` **Fender Armadura** | `ber_headsman_roar` **Brado do Carrasco** |
|---|---|---|
| Nível | 8 | 22 |
| Alvo / tipo | CONE / PHYS | SELF (raio 8 m) / BUFF |
| Power · MP · CD | 1,6 · 10 · 5 | — · 22 · 30 |
| Alcance / raio | 2,8 m, 100° | 8 m |
| Efeitos | **M2 sunder** {add 1, taken_per 4, max 5, duration 8}; e `sunder_consume` {per 0,10} em Golpe Avassalador, Executar e Decapitar | `buff` {id `headsman_roar`, 10 s, `def_pct` 20, `atk_pct` 10} em você e aliados a 8 m; `shield` 12% do HP 6 s (você e aliados) |
| Timing | startup 0,22, recovery 0,3, cancel 0,15, hit-stop 4 | startup 0,15, recovery 0,2 |
| Inspiração | à la "rachar armadura" do guerreiro do WoW | à la grito de reunião do WoW / gritos do bárbaro do D2 |
| Por que cabe | Dá o ritmo do Executor: 3-5 golpes que racham, depois a execução | Executor é o "tanque de apoio" (placa/VIT): primeira ferramenta de grupo dele |
| VFX / clipe | `blood` / `atk_2h_slash` (família de golpe largo), lascas de metal no alvo | `blood` / `shout` |
| Bot | Abre a luta e mantém 5 cargas; só usa Executar/Decapitar com ≥ 3 cargas (ou alvo abaixo de 25%) | Em chefe ou com ≥ 3 aliados a 8 m, ou vida do grupo < 60% |

Ajuste nas existentes: `ber_overhead`, `ber_execute`, `ber_decapitate` ganham `sunder_consume` (dano médio sobe ~+30-50% quando o
Executor usa o ciclo; ver seção 6: possivelmente baixar o power base delas em 10%).
Confirmar na implementação: `shield` com raio chega aos aliados (o `buff` com raio já chega, ex. `bis_ward`).

### Bispo — Clérigo de Batalha (+2; exige `["mace"]`)

| Campo | `bis_faith_banner` **Estandarte da Fé** | `bis_chain_of_faith` **Corrente da Fé** |
|---|---|---|
| Nível | 17 | 23 |
| Alvo / tipo | GROUND / PHYS | TARGET / PHYS |
| Power · MP · CD | 1,2 (+8 × 0,2) · 22 · 18 | 3,2 · 22 · 11 |
| Alcance / raio | 6 m / 3,5 m | corpo a corpo (2,6 m) |
| Efeitos | **M1 zone** 8 s, pulso 1 s, `foe_power` 0,2, `ally_heal` 0,25 (aliados dentro), `foe_slow` 20% | `mend_pct_of_dmg` 0,25 (golpe principal), `chain` {count 2, radius 5, falloff 0,6} |
| Timing | startup 0,25, recovery 0,25, cancel 0,12, hit-stop 4 | startup 0,2, recovery 0,3, cancel 0,15, hit-stop 5 |
| Inspiração | à la estandartes/"leis" do Cruzado do D3 | à la choque sagrado do WoW que salta |
| Por que cabe | Ele luta em cima do estandarte; o grupo se junta ao clérigo | Mais um golpe que cura o mais ferido, agora pegando vários inimigos |
| VFX / clipe | `holy` / `cast_ground` (fincar), estandarte na tela | `holy` / `atk_1h_slash`; corrente dourada |
| Bot | Fincar sob o próprio tanque/alvo quando ≥ 2 aliados estão a 6 m | Rotação normal (prioridade logo após Martelada da Fé) |

### Bispo — Sacerdote (+1; exige `["mace", "shield"]`)

| Campo | `bis_guardian_light` **Luz Protetora** |
|---|---|
| Nível | 3 (primeira própria da build; a próxima é 6) |
| Alvo / tipo | TARGET (aliado sob o cursor, como Curar) / HEAL |
| Power · MP · CD | 0,8 · 14 · 8 |
| Alcance | 9 m |
| Efeitos | cura + `shield` 10% do HP do alvo por 5 s (o caminho de aliado já recebe os efeitos inteiros) |
| Timing | startup 0,2, recovery 0,25, cancel 0,12 |
| Inspiração | à la escudo de palavra de poder do sacerdote do WoW |
| Por que cabe | Sacerdote = prevenir; hoje ele só cura depois |
| VFX / clipe | `holy` / `cast_holy`; bolha clara no alvo (buff visual em `BuffLooks`) |
| Bot | No tanque antes do 1º golpe do chefe e a cada recarga; em aliado < 50% se Curar está em recarga |

Confirmar: `Combat.select_targets` de TARGET HEAL pega o aliado (Curar já faz) e o `shield` vai para ele, não para o lançador.

### Druida — Urso (+1; exige `["mace2h"]`)

| Campo | `dru_lacerate` **Lacerar** |
|---|---|
| Nível | 15 |
| Alvo / tipo | TARGET / PHYS |
| Power · MP · CD | 1,4 · 10 · 4 |
| Alcance | 2,6 m |
| Efeitos | `dot` (6/s, 6 s; mágico comum acumula 3 cópias pela regra do jogador) + `provoke` {duration 3} (chefe: metade) |
| Forma de urso (`FORM_MODS`) | "Garra Laceradora": power × 1,15, raio 2,2, `max_targets` 3 |
| Inspiração | à la "lacerar" do druida urso do WoW |
| Por que cabe | Ameaça contínua num alvo para o tanque, sem gastar o Urro |
| VFX / clipe | `nature` / `maul` na forma (família `FORM_CLIP`), riscos de garra (`FORM_ARC`) |
| Bot | Em chefe: manter 3 cópias; trocar de alvo para lacaio que foge do tanque |

Também a sugestão da seção 3: assinatura do Urso = `dru_maul` (ou `dru_lacerate`).

### Elementalista — Fogo (+1; exige `["staff"]`, `elements` = fire)

| Campo | `ele_ember_seed` **Semente Ígnea** |
|---|---|
| Nível | 17 |
| Alvo / tipo | TARGET / MAG |
| Power · MP · CD | 1,2 (+1,4 na explosão) · 18 · 8 |
| Alcance / raio | 9 m / explosão 3,0 m |
| Efeitos | `dot` 8/s 4 s (queimadura, tema fogo) + **M3 seed** {delay 4, radius 3, power 1,4, spread_dot, max 6} |
| Timing | startup 0,25, recovery 0,25, cancel 0,12, hit-stop 3 |
| Inspiração | à la bomba viva do mago do WoW / "espalhar" do fogo do D4 |
| Por que cabe | Fogo = acumular e detonar queimaduras; a semente espalha antes da Combustão |
| VFX / clipe | `fire` / `cast_fire`; brasa pulsando no alvo e estouro laranja |
| Bot | No alvo com mais vizinhos a 3 m; em matilha antes da Combustão |

### Elementalista — Raio (+1; exige `["staff"]`, `elements` = storm)

| Campo | `ele_bolt_step` **Passo Relampejante** |
|---|---|
| Nível | 13 |
| Alvo / tipo | GROUND / MAG |
| Power · MP · CD | 1,7 · 14 · 9 |
| Alcance / raio | 7 m / 2,4 m na chegada |
| Efeitos | `dash` 7 + `dash_to_aim` (vai até o ponto; já existe no Gancho do Corsário), golpe na chegada; atordoar do raio pela regra do elemento (15%) |
| Timing | startup 0,1, active 0,15, recovery 0,2, cancel 0,1, hit-stop 3; intocável na viagem (mesmo `iframe` do dash) |
| Inspiração | à la teleporte do feiticeiro do D4 |
| Por que cabe | Raio = mago rápido e móvel (Fogo nega área, Gelo controla) |
| VFX / clipe | `lightning` / `dash`; rastro elétrico e clarão no pouso |
| Bot | Para sair de corpo a corpo (alvo a < 3 m) ou para entrar numa matilha que o Corrente/Trovão pegam |
| Sem mecânica nova | Sim (`dash`, `dash_to_aim`) |

### Necromante — Invocador (+1; exige `["scythe"]`)

| Campo | `nec_dark_offering` **Oferenda Sombria** |
|---|---|
| Nível | 21 |
| Alvo / tipo | GROUND / MAG |
| Power · MP · CD | 1,5 por invocação (até 4) · 20 · 10 |
| Alcance / raio | 9 m / escolha 6 m, explosão 3 m |
| Efeitos | **M4 sacrifice** {pick_radius 6, max 4, blast_radius 3, power 1,5, hp_weight 0,5} |
| Timing | startup 0,3, recovery 0,3, cancel 0,15, hit-stop 4 |
| Inspiração | à la "explosão de cadáver" do D2 / sacrifício do necromante do D4 |
| Por que cabe | Invocador passa a jogar com o exército: ergue esqueletos baratos (Erguer Mortos, 12 s) e os detona |
| VFX / clipe | `bone` (ou `shadow`) / `summon`; cada morto-vivo incha e estoura em ossos |
| Bot | Com ≥ 3 esqueletos/cães a 6 m de ≥ 2 inimigos, ou esqueletos a < 30% de vida |

### Necromante — geral (+1; qualquer foice)

| Campo | `nec_grave_grasp` **Garra da Cova** |
|---|---|
| Nível | 16 |
| Alvo / tipo | TARGET / MAG |
| Power · MP · CD | 0,8 · 12 · 12 |
| Alcance | 9 m |
| Efeitos | `pull` {gap 1,5} + `root` 1 s (chefe não é puxado, regra atual) |
| Timing | startup 0,2, recovery 0,25, cancel 0,12, hit-stop 3 |
| Inspiração | à la "agarrão da morte" do cavaleiro da morte do WoW |
| Por que cabe | Serve às 3: Ceifador traz o alvo para a foice, Invocador para os mortos, Sombras prende para canalizar |
| VFX / clipe | `shadow` / `cast` com mão de ossos saindo do chão |
| Bot | Atirador/conjurador inimigo fora do grupo; nunca em chefe |
| Sem mecânica nova | Sim (`pull`, `root`) |

### Ranger — geral (+1; arco, mosquete ou lança: `requires` vazio)

| Campo | `ran_field_dressing` **Curativo de Campo** |
|---|---|
| Nível | 11 |
| Alvo / tipo | SELF / BUFF |
| Power · MP · CD | — · 14 · 20 |
| Efeitos | `heal_pct` 20 (20% da vida na hora, como o Chakra) + `buff` {id `field_dressing`, 4 s, `speed_pct` 20}; `pet_buff` (o lince ganha o buff) |
| Timing | startup 0,15, recovery 0,2, cancel 0,1 |
| Inspiração | à la "estimular" do caçador do WoW |
| Por que cabe | Ranger não tem cura; o Lanceiro (perto) só tinha o Recuar como geral |
| VFX / clipe | `nature` / `buff_power` (atar faixa) |
| Bot | Vida < 45% em combate |
| Sem mecânica nova | Sim |

## 6. Resumo, dependências e ajustes de números

| Build | Skill | Nv | Mecânica | Nova? |
|---|---|---|---|---|
| Templário | Chão Sagrado | 10 | chão sagrado 6 s: queima e +DEF a quem está dentro | s (M1) |
| Templário | Coluna da Alvorada | 22 | coluna de luz no cursor, atordoa e salta para 3 | n |
| Executor | Fender Armadura | 8 | cone que acumula rachadura (+4%/carga, até 5); finalizadores consomem | s (M2) |
| Executor | Brado do Carrasco | 22 | +20% DEF, +10% ATK e escudo 12% no grupo | n |
| Batalha | Estandarte da Fé | 17 | estandarte 8 s: fere inimigos e cura aliados dentro | s (M1) |
| Batalha | Corrente da Fé | 23 | golpe que cura o mais ferido e salta para 2 | n |
| Sacerdote | Luz Protetora | 3 | cura + escudo 10% num aliado | n |
| Urso | Lacerar | 15 | dano no tempo que acumula + provoca 3 s | n |
| Fogo | Semente Ígnea | 17 | semente explode em 4 s (ou na morte) e espalha a queimadura | s (M3) |
| Raio | Passo Relampejante | 13 | teleporte de 7 m que cai como raio | n |
| Invocador | Oferenda Sombria | 21 | detona até 4 invocações suas | s (M4) |
| Necro geral | Garra da Cova | 16 | puxa o alvo e prende 1 s | n |
| Ranger geral | Curativo de Campo | 11 | cura 20% e +20% de velocidade (você e o lince) | n |

**Dependências por skill** (o que a implementação tem de tocar, tudo no território do `class-designer` salvo indicado):
- `skills_catalog.gd` (`_more()`), `SkillDef.EFFECT_KEYS` + comentário (`zone`, `sunder`, `sunder_consume`, `seed`, `sacrifice`), `Balance.*` (números das 4 mecânicas, `SACRIFICE_EXCLUDE`, `MARK_CURSES` += `sunder`).
- Listas do bot em `classes_catalog.gd` (`_b(...)` skills em prioridade): inserir cada nova na build.
- Teia: entra sozinha (`tree_catalog.gd`, "Aprimorada"/"Ágil"); conferir folga `_check_web_strength`.
- Ícones: `GLYPHS` em `tools/icons/make_icons.gd` + `make_icons.tscn` + `--import`; tema VFX por palavra (`VFX_RULES`) ou `vfx`; clipe em `EntityView._action_clip` (só famílias existentes acima).
- Buffs/debuffs novos com visual em `BuffLooks.LOOKS`: `hallowed`, `headsman_roar`, `faith_banner` (se o pulso pôr buff), `field_dressing`, debuffs `sunder`, `seed_*`.
- Som: tema já existe para todos (`holy`, `blood`, `fire`, `lightning`, `shadow`, `nature`); M1/M3/M4 podem ganhar `EFFECT_SOUND`.
- Talentos (`class_talents_catalog.gd`): opcional citar Chão Sagrado (linha 10), Fender (linha 10), Semente (linha 20), Oferenda (linha 25).
- `docs/DESIGN.md` (seções das classes) e `.claude/docs/ragnaex/conteudo.md` (lista de efeitos suportados) na entrega.
- **Nada** em `core/sim/ai/*` é necessário para lançar: o `BotBrain` usa a lista da build. As notas de "Bot" acima (cargas do
  Fender, Oferenda com ≥ 3 mortos, Garra só fora de chefe) pedem condições no `BotBrain` → **pedido ao `world-builder`** (dono de `core/sim/ai`).

**Números a vigiar**: `sunder_consume` sobe o Executor (cinco cargas = +50% num finalizador). Se a sonda passar de +25% sobre a
mediana, baixar `taken_per` para 3 ou o power base de Executar/Decapitar em 10%. Chão Sagrado e Estandarte: dano total só vale se
o alvo fica 6-8 s dentro; em chefe parado é ~2,5× o impacto, por isso o impacto é baixo.

## 7. Riscos e testes

**Plano de balanceamento**
1. `--headless --path . tools/tests/skill_audit.tscn`: nenhuma das 13 em `WEAK` (< 60% da mediana). Para zonas/sementes/sacrifício,
   o audit precisa contar o dano dos pulsos/explosões (confirmar que soma pelo id da skill).
2. `tools/tests/dps_probe.tscn` / simulação nos testes (boneco, 10 s de básico + rotação, nível 30): cada build dentro de ±25% da
   mediana single-target; Executor medido com e sem o ciclo do Fender; Invocador com e sem a Oferenda.
3. `tools/tests/combat_probe.tscn -- --class=paladin,berserker,bishop,druid,elementalist,necromancer,ranger`: 0 `FLAG`
   (startup ≤ 0,3 s, impacto no tick do dano, `cancel_after` pequeno).
4. `boss_probe.tscn -- --party=5 --comp=...` com Clérigo de Batalha e Sacerdote: `cura_tq`/`baixa` não pioram; Executor com o Brado.
5. `--showcase=all --check` (lança todas sem erro) e folhas de bancada das 13 (nota ≥ 8 em `docs/skills_review.md`).

**Checks novos em `tools/tests/run_tests.gd`** (sugestão de nomes, rodam com `--only=`):
- `_check_skill_fill`: toda build com ≥ 8 próprias e toda classe com ≥ 4 gerais (sem ascensão); escada sem nível repetido proibido.
- `_check_zone`: zona pulsa N vezes em `duration`, cura aliado dentro, não cura fora, relançar apaga a antiga, some com o dono morto.
- `_check_sunder`: 5 acertos = 5 cargas (+20%), 6º não passa de 5, teto `MARK_TAKEN_CAP` com Penitência/Expor, consumo zera e multiplica o power.
- `_check_seed`: explode no tempo e na morte do alvo, espalha a queimadura, não planta semente nova, renova ao relançar.
- `_check_sacrifice`: recusa sem invocação (sem gastar MP), explode até 4, exclui Rei/Lich, invocação morre sem XP/saque.
- Existentes que vão pegar o resto: `_check_catalog_keys` (efeitos novos na lista), `_check_talent_unlock_levels`, `_check_web_strength`,
  check de `BuffLooks`, check de ícones/`GLYPHS`, `_check_build_entries`.

**Riscos**
- `shield` com raio em aliados (Brado) e `shield` em aliado via TARGET HEAL (Luz Protetora): confirmar o caminho antes de prometer.
- Semente + Combustão + teto de 3 queimaduras por skill: espalhar não pode furar o teto (usar `_put_dot`).
- Oferenda e o limite por tipo das invocações: matar 4 esqueletos libera vagas na hora (é a intenção), mas pode virar laço
  "ergue → explode" barato demais; recarga de Erguer Mortos (12 s) segura.
- Zonas e desempenho: 1 zona por (lançador, skill); laço só sobre entidades a ≤ raio (regra do `nearest_hostile`).
- Save: só ids novos, sem migração.

## 8. Onda 2 (aprovada pelo usuário em 2026-11-19): Eviscerar, Sangria e Aparar

Três ajustes de identidade das TURVAS da seção 3. Números só em `Balance` (blocos `EVISCERATE_*`, `WOUND_*`, `RIPOSTE_*`).

### 8.1 Lâminas: Eviscerar consome os venenos
- **Veneno / ferida** (definição única, `WoundSystem.is_wound`): debuff `kind: "dot"` **seu** (`src` = você) que não é
  queimadura (`fire`) nem o sangramento por % do ATK do Lanceiro (`bleed`). Entram: veneno da lâmina (`blade_poison_*`,
  Lâmina Pestilenta), Dardo Venenoso, Nuvem Tóxica, Veneno, Virulência, Estocada Dupla, sangramentos do Carniceiro
  (Talho Duplo, Dilacerar, Tempestade de Aço). Venenos de outro jogador no mesmo alvo não contam nem saem.
- **Regra** (efeito `combust` com `"kind": "poison"`, `Balance.EVISCERATE_POISON`): antes do golpe, cada veneno seu no alvo sai;
  o dano que faltava (dps × tempo restante + acumulado do pulso) explode na hora × `detonate` 1,25 (tipo `detonate`, como a
  Combustão), e o golpe ganha `per` +10% de poder por veneno consumido, até `max` 5 (+50%). Cópias do mesmo veneno (teto
  `PLAYER_DOT_MAX_STACKS` 3 por skill) contam uma a uma. Sem veneno: golpe comum.
- **Números**: poder 3,0 → **2,2** (com 2 venenos = 2,64; com 4 = 3,08); a auditoria conta 2 venenos.
  O veneno da lâmina volta logo depois (o próprio golpe físico o reaplica: Lâmina Pestilenta ligada).
- **Casos**: chefe igual (não é controle). Alvo morre na detonação: o golpe não sai (alvo morto). Venenos de monstro
  (renovam por id) não existem num jogador-alvo: a regra só olha `src` = lançador.

### 8.2 Machados Gêmeos: Sangria (era Turbilhão de Aço) e Presas Gêmeas
- **Sangria** (`ber_steel_whirl`, nível 12, mesmo raio/poder/recarga): o giro **cura** `WOUND_WHIRL["pct"]` 5% da vida máxima
  por inimigo atingido **que estava sangrando** (ferida sua, regra 8.1, contada antes do golpe), até `max` 4 alvos (20%).
  Sai o `heal_pct_of_dmg` 0,15 genérico. Sem alvo sangrando = giro sem cura (ritmo: sangrar → girar).
- **Presas Gêmeas** (`ber_twin_fang`, nível 2): continua o leque que retarda, e agora **mantém as feridas abertas**: cada atingido
  tem as feridas suas estendidas em `WOUND_EXTEND["add"]` 2 s, sem passar de `cap` 8 s restantes. Talho Duplo abre (alvo único +
  sangramento), Presas estende (área), Sangria colhe.
- Talento Redemoinho Sedento (25): no Redemoinho segue cura 20% do dano; na Sangria sobe a cura por alvo para
  `WOUND_WHIRL_TALENT_PCT` 7%.

### 8.3 Duelista: aparar e contra-atacar (5ª mecânica nova, `RiposteSystem`)
- **Guarda do Duelista** (`ass_guard`, nível 9, mesma arma: `dual`/`pistol`, então o Corsário também apara) vira **janela de
  aparar**: SELF, preparo 0,05 s, buff `duel_guard` por `RIPOSTE_WINDOW` 1,0 s (com +30% DEF e +15% esquiva, que o talento
  "Duelista" de linha 15 deixa permanentes a 50% como antes; a cópia permanente `ct` **não** apara). Recarga `RIPOSTE_CD` 8 s, MP 8.
- **Aparar** (`WorldSim._deal_damage`, antes da esquiva): golpe **direto** (não dano no tempo, não zona avisada `dodgeable=false`,
  não de si mesmo) de um atacante a até `RIPOSTE_RANGE` 4 m e dentro do arco da guarda (`Combat.in_guard_arc`, 140° à frente)
  com a janela ativa: dano 0 (evento `blocked_hit`). **Chefe de verdade** (`is_boss`, inclui o Rei): o golpe passa com
  −`RIPOSTE_BOSS_CUT` 60% em vez de zerar (o resto segue o caminho normal: escudo, talentos).
- **Resposta**: cada golpe aparado devolve `RIPOSTE_COUNTER_PCT` 80% do ATK em quem bateu (tipo `riposte`: não gera outra
  resposta, não é aparada, não dá Fúria), + `pct` da arma lendária Riposte se ela estiver na mão. No máximo
  `RIPOSTE_MAX_COUNTERS` 2 respostas por janela (vários golpes no mesmo tick: todos aparados, só 2 respondem).
- **Ímpeto** (buff `impeto`, cargas): +1 por golpe aparado (e por esquiva que a Riposte lendária responde), até
  `RIPOSTE_MOMENTUM_MAX` 3; +`RIPOSTE_MOMENTUM_CRIT` 5 de crítico por carga; some em `RIPOSTE_MOMENTUM_TIME` 10 s sem ganhar.
  **Golpe de Mestre** (`ass_master`, efeito `momentum_spend`) gasta todas: poder × (1 + `RIPOSTE_SPEND_PCT` 20% × cargas), até +60%.
- **Riposte lendária** (já existia: esquivar contra-ataca `pct` do ATK) passa pelo mesmo `RiposteSystem.counter` e agora também
  dá Ímpeto; aparar com ela na mão soma o `pct` à resposta. Nada duplicado: uma função de resposta.
- **Bots** (`BotBrain._fill_ok` + ramo `riposte` no `_best_skill`, nota `BOT_RIPOSTE_SCORE`): lançam a Guarda só com um inimigo a
  até 4 m que o tem como alvo e está **no preparo** de um golpe (básico ou skill), ou com `BOT_RIPOSTE_CROWD` 2+ inimigos em cima.
- **Casos**: projétil de longe (> 4 m) não é aparado (esquiva normal). Golpe pelas costas não é aparado. Dash (`iframe`) vem antes.
  Morrer/trocar de mapa: o buff some como qualquer buff. Boneco de treino não bate: a sonda de DPS não mede o Ímpeto.
- **Teste** (`_check_riposte`): golpe aparado = 0 de dano e resposta no atacante; chefe passa 40%; dano no tempo e zona avisada
  passam; 3 golpes no mesmo tick = 2 respostas; Ímpeto até 3 e o Golpe de Mestre o gasta (+60%); a cópia `ct` não apara.
