# Supremas do nível 40 (rascunho de design, 2026-11-19)

> Status: **RASCUNHO salvo, a tabela das 24 ainda em análise pelo usuário** ("salve isso, vou pensando", 2026-11-19).
> Nenhum código, catálogo, `Balance` ou teste foi alterado.
> **Decisões do usuário sobre este rascunho (2026-11-19):** ritmo ok (~1 Suprema por luta de chefe, 45-60 s, +0,25/s em
> combate); **Chuva de Meteoros PRESA no ponto do lançamento** (não segue o mago; `storm.anchor = "ground"`, centro = posição
> do mago ao lançar); **as 7 mecânicas novas ficam todas** (sem os recuos do §9). Falta: aprovar/ajustar a tabela das 24.
> Dono: `class-designer`. Pedido do usuário (2026-11-19): "Precisamos da skill ultimate de cada classe e build, no lv 40."
> Decisões já tomadas pelo usuário: **tecla própria R** (moldura especial na barra; não usa 1-6 nem 7 8 9 0);
> **carga por combate** (medidor que enche com dano/cura/dano recebido, solta quando cheio); **libera no nível 40 E com a
> missão de ascensão** (`hx_asc_<classe>`, `ProgressionSystem.has_ascension`); **sobreposição**: a skill antiga fica e a
> suprema é claramente a versão grande. Ideias do usuário usadas: Fogo (meteoros 10 s em volta do mago), Gelo (tempestade
> que congela), Raio (tempestade), Sacerdote (barreira em área −50%), Urso (cresce, ganha armadura/HP/DEF/dano).
> Nome no jogo: **Suprema** (a skill) e **Carga Suprema** (o medidor). "Ímpeto", "Glória", "Ápice", "Determinação" e
> "Juramento" já existem e não foram reaproveitados.

## 1. Visão geral

Cada uma das 24 builds (8 classes × 3, `ClassesCatalog._b`) ganha **uma Suprema** no nível 40. Ela não ocupa vaga da
barra: mora na tecla **R**, numa moldura própria, e só pode ser solta quando a **Carga Suprema** (0-100) está cheia. A
carga enche lutando (dano causado, cura efetiva, dano recebido, com pesos por papel), esvazia fora de combate e zera ao
morrer ou trocar de mapa. A Suprema certa é a da **build principal** (`ProgressionSystem.main_build`): trocar de arma para
outra build troca a Suprema (a carga é a mesma). Meta de ritmo: **uma Suprema por luta de chefe** (encher em 45-60 s de luta
de verdade), duas numa luta longa. Força: "momento de chefe", grande mas nunca apaga um chefe sozinho (equilíbrio em grupo
com bots, `boss_probe --comp`).

## 2. Fantasia do jogador

- A luta tem um **arco**: você constrói a carga fazendo o seu papel e a Suprema é o clímax que o grupo sente.
- Cada Suprema é a **assinatura da build em tamanho grande**: o Fogo vira uma chuva de meteoros que anda com você, o Urso
  vira um colosso, o Sacerdote ergue a cúpula que salva o grupo, o Duelista entra num duelo em que nada passa.
- Tanque e cura enchem a carga **fazendo o trabalho deles** (apanhar e curar), não precisando bater.
- A moldura do R acende quando enche (anel dourado + brilho + som): o jogador sabe sem olhar números.

## 3. Regras detalhadas

### 3.1 Liberação e Suprema da build

- `ProgressionSystem.has_ultimate(e)` = `e.level >= Balance.ULT_LEVEL` (40) **e** `has_ascension(e)` (35 + `hx_asc_<classe>`).
- `ProgressionSystem.ultimate_of(sim, e) -> SkillDef`: a skill com `SkillDef.ultimate = true`, mesma classe, `build ==
  main_build(sim, e)` e `requires` atendido pelas armas na mão. Sem arma da build = sem Suprema (moldura apagada, "Arma da
  build necessária").
- `SkillDef.ultimate = true`: `unlock_level` 40, **fora da teia comum e da teia de ascensão**, recusada nas vagas 1-0
  (`set_skill_slot`), sem MP (custo 0), sem recarga própria (o medidor é o portão), sem rank/maestria no Mestre de Skills
  nesta versão (pergunta aberta 2). `try_cast` com a flag de Suprema checa `has_ultimate`, `ultimate_of`, carga cheia,
  `ULT_MIN_GAP` e os portões normais (atordoado, montado: a Suprema **desmonta** como as outras skills não-montáveis).
- A carga só é **gasta quando a skill sai** (passa do `startup`). Cancelada no preparo (dash, atordoado) = carga fica.

### 3.2 Carga Suprema (medidor, comum às 24)

Estado em tempo de execução no `SimEntity` (não vai no save): `ult_charge: float` (0..`ULT_MAX`), `ult_combat_t: float`
(último instante de combate), `ult_gap_until: float`. Regras num sistema novo estático `core/sim/systems/ultimate_system.gd`
(`UltimateSystem`), chamado de `WorldSim._deal_damage`, do caminho de cura (`_heal`/escudo absorvendo) e do tick.

**O que enche** (só com `has_ultimate`; nada enche durante a própria Suprema nem com o dano dela):
1. **Dano causado** em inimigo: `pts = ULT_GAIN_PER_POWER × poder do golpe × peso_dano(papel)`. "Poder do golpe" = o poder
   da skill (ou 1,0 do básico, ou a parte do `weights` do `strikes`) **antes** de DEF, crítico e bônus: independe do
   equipamento e da defesa do alvo. Dano no tempo: cada pulso vale `poder do pulso × ULT_DOT_MULT`. Dano das suas
   invocações/companheiros/torretas: × `ULT_SUMMON_MULT`. Uma ação (um lançamento ou um básico) conta no máximo
   `ULT_AOE_TARGETS` alvos (os de maior poder): área não enche 10× mais rápido.
2. **Cura efetiva** em aliado (você incluso): `pts = ULT_GAIN_HEAL × (cura efetiva / cura_ref) × peso_cura(papel)`, com
   `cura_ref = Combat.calc_heal(e, 1.0)` (a cura de poder 1,0 do próprio lançador). Sobrecura = 0. Escudo conta **quando
   absorve** (não ao ser posto), pela mesma régua. Cura de `heal_pct_of_dmg`/`mend` conta como cura.
3. **Dano recebido** de inimigo: `pts = ULT_GAIN_TAKEN × (dano bruto depois da DEF / HP máx × 100) × peso_apanhar(papel)`,
   contado **antes** de bloqueio, escudo, aparar e cúpula (tanque bem jogado não perde carga). "Aparar" aqui é o aparo do
   escudo (`parry`, que só reduz). O aparo **inteiro** do Duelista (Guarda do Duelista / Duelo Supremo, `RiposteSystem`
   devolve -1) é golpe que não pegou (item 5) e não enche; a resposta dele enche como dano causado (decisão da onda B2,
   2026-11-19: o golpe aparado inteiro não tem "dano bruto"; contar os dois seria encher duas vezes pelo mesmo golpe). No máximo `ULT_TAKEN_HIT_CAP`
   por golpe (golpe que mata metade da vida não enche de uma vez). Dano redirecionado pela Suprema do Guardião não conta.
4. **Gotejar em combate**: `ULT_TRICKLE` pts/s enquanto em combate com inimigo de verdade (garante que todo mundo chega).
5. **Teto de ritmo** (aprovado pelo usuário 2026-11-19, depois da calibragem da onda A): os itens 1-3 gastam um estoque por
   personagem que enche `ULT_RATE_CAP` pts/s até `ULT_RATE_BURST`; o que passar do estoque se perde. O gotejar (4) fica de
   fora. Motivo: sem teto, o poder/s variava 1,5-10 pts/s entre as 24 builds (Raio 10, Sacerdote 1,5) e nenhum peso global
   punha todas a ±20% da mediana. Com o teto, quem faz o papel enche no mesmo ritmo; os pesos por papel, o teto por área,
   o `ULT_DOT_MULT` e o `ULT_SUMMON_MULT` passam a valer sobretudo para quem fica **abaixo** do teto (cura que tem pouco a
   curar, invocador, quem fica fora da luta). Só golpe que **pegou** conta (esquiva, dash e aparar inteiro não enchem).

**Pesos por papel** (papel = `ProgressionSystem.role_of`, já existe: `tank`, `healer`, `dps`, `caster`, `ranged`):

| papel | dano | cura | apanhar |
|---|---|---|---|
| tank | 0,6 | 0,5 | 1,6 |
| healer | 0,9 | 1,7 | 0,6 |
| dps / caster / ranged | 1,0 | 0,5 | 0,5 |

O Clérigo de Batalha (papel `dps`) cura pelo `mend`: conta 0,5, igual a todo `dps`.

**Combate**: `ult_combat_t` renova ao causar/receber dano de um inimigo hostil ou curar um aliado em combate. O **boneco de
treino** (`MonsterDef.dummy`) conta como combate e enche no ritmo normal (dá para treinar a Suprema nele), mas não mais que
isso: ver a seção 5 (sem estoque levado para fora).

**O que esvazia**:
- Fora de combate por `ULT_DECAY_DELAY` s: perde `ULT_DECAY_RATE` pts/s.
- Morrer: zera. Trocar de mapa (portal, recall, porta de casa): zera.
- Soltar a Suprema: zera e abre `ULT_MIN_GAP` s em que nada enche (trava contra duas seguidas numa luta muito sangrenta).

### 3.3 Tecla R, comando e HUD

- **InputMap**: ação nova `ultimate` (tecla R; hoje R não está ligada a nada em `project.godot`). `PlayerController` põe
  `cmd.ultimate = true` no comando.
- **InputCommand**: campo novo `ultimate: bool` (ação de 1 vez: zerado no comando repetido entre pensamentos em
  `WorldSim.tick`, como `mount`/`recall`, e nos três pontos que já zeram `skill_slot`). Mira = o `aim` do comando, como as skills.
- **Sim**: `_apply_command` com `ultimate` → `try_cast(e, ultimate_of(...), ultimate = true)`; o pipeline de skill é o
  mesmo (`startup/active/recovery`, `cancel_after`, hit-stop, encarar o cursor). Repasse público `Sim.ultimate_charge(e)`,
  `Sim.ultimate_of(e)`, `Sim.has_ultimate(e)` no fim do `world_sim.gd`.
- **HUD** (`game/ui/action_bar.gd`): moldura redonda maior à **esquerda** da barra 1-6 (separada das vagas de ascensão),
  ícone da Suprema da build, anel de preenchimento dourado (0-100, sentido horário), "R" no canto. Cheia: anel aceso, brilho
  pulsando, som `ult_ready` (entrada nova em `Sfx.VOL`). Travada: cadeado + dica "Nível 40 e Ascensão" / "Arma da build
  necessária". Durante `ULT_MIN_GAP`: anel cinza. Ícones: `GLYPHS` em `tools/icons/make_icons.gd` (24 ids).
- **Evento**: `Events.post(&"ultimate_cast", e.id, skill_id)` (som/tela: leve tremor de câmera e faixa de nome da Suprema
  sobre o personagem, só para o jogador e o grupo dele).

### 3.4 Bots

- Bots usam o mesmo comando. Cada Suprema tem `SkillDef.ult_bot` (regra de uso):
  - `"boss"`: solta com a carga cheia quando o alvo é chefe/elite **ou** há `BOT_ULT_PACK` (3)+ inimigos na área da Suprema.
  - `"save"` (cura/tanque): solta quando `BOT_ULT_SAVE_ALLIES` (2)+ aliados na área estão abaixo de `BOT_ULT_SAVE_HP` (55%),
    ou o tanque do grupo abaixo de 35%, ou quando um aviso de chefe (`hazards`/assinatura) cobre 2+ aliados.
  - `"self"`: solta com 3+ inimigos em cima de si ou o próprio HP abaixo de 40% (Ceifador, Urso).
- No grupo do jogador: bot com carga cheia **segura** até `BOT_ULT_HOLD` (20) s esperando o chefe; depois usa em bando.
  Dois bots do mesmo grupo não soltam `boss` a menos de `BOT_ULT_STAGGER` (3) s um do outro (as `save` furam a fila).
- A IA (`BotBrain`, ramo `ultimate` no `_best_skill`) é território do `world-builder`: ver seção 6.

### 3.5 As 24 Supremas

Faixa de força (régua, nível 40): skills de 24-28 da build valem 3,0-4,2 de poder; a ascensão vale 2,2-3,5.
**Orçamento de Suprema**: dano em alvo único somando toda a duração ≈ **16-22 de poder** (decisão do usuário 2026-11-19: +60%
sobre os 10-14 do rascunho, ~1 por luta de chefe, medidor igual; `Balance.ULT_POWER_BAND`, medido como na §4 "Força medida");
em área, cada alvo a mais leva o mesmo, com os limites de alvo de cada uma. Suprema de utilidade (Guardião, Sacerdote,
Batalha, Urso, Caçador) mede-se pelas mortes do grupo sob pressão, não pelo dano. Todos os números vão para
`Balance.ULT_NUMBERS["<id>"]` (dicionário por Suprema) e os textos são gerados com eles.
Ids: `<prefixo>_ult_<nome>`. Controle em chefe segue as regras de sempre (`resists_cc`: atordoar/congelar ×0,4, provocar metade;
o Rei elite leva cheio). Tudo é PvE (não há PvP; nada atinge jogador/bot aliado).

#### Paladino

**1. Guardião — Bastião da Aurora** (`pal_ult_dawn_bastion`, SELF, `ult_bot: save`)
- Finca um estandarte de luz: provoca inimigos a 8 m (4 s; chefe 2 s), escudo de 35% do HP por 8 s, Juramento cheio (5).
- **Proteção** 8 s: aliados a 8 m recebem −30% de dano, e esses 30% vão para o paladino (passam pela DEF, bloqueio e escudo
  dele). Para sozinha se o paladino cair abaixo de 25% de vida (não suicida).
- Reusa: `taunt`, `shield`, Juramento (`SHIELD_OATH_*`). **Novo**: efeito `intercept` (redirecionar parte do dano; caminho
  próprio como a cúpula do Coro, fora do `DR_CAP`; duas proteções não somam).
- Visual: estandarte dourado no chão, fios de luz até cada aliado protegido. Clipe `buff_power`.

**2. Cruzado — Juízo da Alvorada** (`pal_ult_dawn_judgement`, GROUND 8 m, `ult_bot: boss`)
- Salta até o ponto (iframe no ar) e desce numa sequência de 3 golpes do montante em raio 3,5 m: `strikes` com poder total
  15,5 (era 12,0; +60%, 2026-11-19), `weights` 0,25/0,25/0,5 (3,9 + 3,9 + 7,8), último crítico garantido (`crit_last`), o último atordoa 1 s.
- Reusa: `dash`, `strikes`, clipes `atk_2h_chain_a/b/c` (já existem no kit do Paladino), `stun`. **Novo**: nenhum
  (confirmar se `strikes` aceita GROUND com `dash`; se não, ajuste pequeno no pipeline).
- Big version de Lâmina do Juízo (26): ela fica.

**3. Templário — Céu de Martelos** (`pal_ult_hammer_sky`, SELF, `ult_bot: boss`)
- 10 s: 8 martelos de luz gigantes giram em raio 4 m (`orbit`), cada passada 0,73 de poder por alvo a cada 0,5 s
  (era 0,42; ≈ 14,6 + Penitência em alvo único parado dentro, medido ~20); quem é atingido recebe a Marca da Penitência; o Juramento enche e não
  esfria enquanto durar (cada skill sagrada sai com +40%).
- Reusa: `orbit` (Martelos Abençoados), marca `pal_brand`, Juramento. **Novo**: nenhum (só números maiores no `orbit` e um
  buff que trava o Juramento: chave de buff `oath_lock`, pequena).
- Big version de Martelos Abençoados (16).

#### Berserker

**4. Machados Gêmeos (Carniceiro) — Festim de Sangue** (`ber_ult_blood_feast`, SELF, `ult_bot: boss`)
- 10 s: +45% velocidade de ataque (era 35), +10 roubo de vida; todo golpe abre ferida (sangramento seu de 100/s, era 30, conta como ferida da regra 8.1
  do GDD skills-fill), e suas feridas não expiram enquanto durar.
- Ao acabar: **Sangria gigante** sozinha (raio 4,5 m, poder 7,0 (era 3,0), cura 6% do HP por inimigo sangrando, até 5 = 30%).
- Reusa: buff (`aspd_pct`, `lifesteal`, `hit_poison` no papel de sangramento), `WoundSystem`. **Novo**: chave `end_cast`
  (skill grátis quando o buff acaba; pequena).

**5. Executor — Veredito do Carrasco** (`ber_ult_headsman_verdict`, TARGET 7 m, `ult_bot: boss`)
- Salta no alvo; põe rachadura máxima (5 cargas) no alvo e em quem estiver a 3,5 m; golpe de poder 11,5 (era 5,0) que consome a
  rachadura (+50% → 17,3) e vale ×1,5 se o alvo estiver abaixo de 30% (chefe ×1,25).
- Os vizinhos ficam com 5 cargas: o grupo e o próximo Executar/Decapitar colhem.
- Reusa: `dash`, `sunder`, `sunder_consume`, limiar de execução. **Novo**: nenhum. Clipe `atk_leap` → `atk_finisher`.

**6. Punhos de Fúria — Sete Ventos** (`ber_ult_seven_winds`, TARGET 8 m, `ult_bot: boss`)
- Some e reaparece em 7 golpes em 1,4 s, saltando entre inimigos a 8 m (um alvo só = 7 no mesmo), poder 2,7 cada (18,9; era 1,3);
  intocável (`iframe`) durante; termina ao lado do último alvo com a Fúria do Punho cheia (5).
- Reusa: Fúria do Punho (`FIST_FURY_*`), `iframe`. **Novo**: `hop_strikes` (sequência de golpes que teleporta entre alvos),
  partilhado com o Lobo.

#### Bispo

**7. Sacerdote — Cúpula da Graça** (`bis_ult_grace_dome`, GROUND 9 m, `ult_bot: save`) — ideia do usuário
- Cúpula **ancorada** (não anda) de raio 7 m por 8 s: aliados dentro recebem **−50% de dano**. Ao erguer, cura todos dentro
  com poder 1,5.
- Reusa: a cúpula do `ChoirSystem` (Barreira Sagrada, `BARRIER_*`), com parâmetros próprios (raio, tempo, redução, sem
  andar). Fora do `DR_CAP` 40% (mesmo caminho da cúpula do Coro). Com a Barreira Sagrada em cima: **vale a maior** (50%),
  não somam. **Novo**: nenhum.
- Big version de Barreira Sagrada (ascensão, 30%/5 m que anda).
- **Fica até acabar** (decisão 2026-11-19, o usuário pode mudar): é um efeito posto para salvar o grupo, então a cúpula continua
  os 8 s mesmo se o Sacerdote cair ou sair do mapa (`ChoirSystem._tick_barrier`: a cúpula só olha o tempo; a Barreira Sagrada
  continua presa ao Bispo vivo). Check `_check_ultimate_dome_stays`.
- **Bots do Coro**: com qualquer cúpula de pé no mapa (Barreira ou Cúpula da Graça, de qualquer Bispo; regra antiga de `BotBrain`, `m["barriers"]` não vazio), o bot não lança a Barreira Sagrada (não somam; vale a maior), e
  volta a lançar quando ela acaba.

**8. Iluminado — Sol do Julgamento** (`bis_ult_judgement_sun`, GROUND 10 m, `ult_bot: boss`)
- Raio de sol cai no ponto: impacto 4,0 (era 2,5) de poder mágico e atordoa 1 s em raio 4,5 m; o chão fica aceso 7 s (zona M1) com
  pulsos de 0,5 s de 1,4 (era 0,55) de poder, sem crítico (medido ~19) e 30% de todo esse dano cura o aliado mais ferido (Radiância).
- Reusa: `zone` (M1 do GDD skills-fill), `mend_pct_of_dmg`, `stun`. **Novo**: nenhum. Big version de Ira Divina (25).

**9. Clérigo de Batalha — Avatar da Fé** (`bis_ult_faith_avatar`, SELF, `ult_bot: self`)
- Martelo de luz no chão ao redor (raio 3,5 m, poder 3,0) + cura o grupo a 8 m com poder 1,0; depois 12 s de Avatar:
  +30% ATK, +25% DEF, +50 resistência a controle (`cc_resist_pct`, teto `CC_RESIST_CAP` 50), e 40% de todo dano físico seu
  cura o aliado mais ferido.
- Reusa: buff (`atk_pct`, `def_pct`, `cc_resist_pct`), `mend_pct_of_dmg` (como buff), `heal`. **Novo**: só visual (boneco
  ×1,25 durante o buff, `EntityView`).

#### Druida

**10. Urso (Guardião Verde) — Colosso Primevo** (`dru_ult_primal_colossus`, SELF, `ult_bot: self`) — ideia do usuário
- Exige forma de urso (em forma humana: vira urso na hora; em Ent: recusada, "Só em forma de Urso"). Rugido que provoca a
  8 m (Urro da Mata) e 15 s de Colosso: urso **×1,5 de tamanho**, +50% HP máx (a vida ganha entra cheia), +40% DEF,
  +30% ATK, +100% ameaça, +50 `cc_resist_pct`.
- Ao acabar, o HP máx volta e a **porcentagem** de vida é mantida (não mata, não cura).
- Reusa: buff com `hp_pct/def_pct/atk_pct/threat_pct/cc_resist_pct`, `taunt`. **Novo**: só visual (escala do `FormModel`
  com transição de 0,3 s) e a regra de manter a % de vida ao trocar o HP máx (conferir se `Stats` já faz isso no fim de buff).

**11. Lobo (Fera) — Garras da Lua Rubra** (`dru_ult_blood_moon`, SELF, `ult_bot: boss`)
- Exige forma de lobo (Alfa conta). 8 s: a cada 0,8 s o lobo salta sozinho num inimigo a 10 m (prefere quem não sangra),
  golpe de poder 0,8 (era 1,3: o lobo já media ~25 com o sangramento, acima da faixa; já com a emboscada embutida: NÃO multiplica por `AMBUSH_MULT` 1,6 nem tira da furtividade) +
  sangramento de Garras 2,5/s (era 4); medido ~18 em alvo único.
  Entre saltos o jogador anda; dash cancela o resto.
- Reusa: emboscada, `dot` de Garras. **Novo**: `hop_strikes` (o mesmo do Punhos, com intervalo maior e sem `iframe` contínuo:
  só 0,15 s no salto).

**12. Xamã — Coração do Bosque Ancião** (`dru_ult_elder_heart`, GROUND 9 m, `ult_bot: boss`)
- Uma árvore ancestral brota no ponto (invocação parada e intocável, como a torreta) por 12 s. Ao nascer: 2,0 (era 1,5) de poder e
  prende (root 2 s) inimigos a 6 m. A cada 1,5 s: Fogo Lunar em até 3 inimigos a 10 m (1,2 cada, era 0,9, + dano no tempo) e cura de
  poder 0,35 em aliados a 6 m (a cura não mudou; medido ~17 de dano num alvo com o tempo).
- Reusa: `summon` parado (padrão da Torreta de Campo), `root`, `dru_moonfire`. **Novo**: nenhum. Não conta no limite do Ent.

#### Ranger

**13. Caçador — Laço Selvagem** (`ran_ult_wild_bond`, SELF, `ult_bot: boss`)
- Lince morto: volta com a vida cheia. 12 s: você e o lince +35% de dano, lince +50 `cc_resist_pct` e ×1,4 de tamanho, e um
  2º lince espiritual (invocação de 12 s, mesma ficha do companheiro, 70% da força).
- Reusa: `ran_pack` (buff para você e o companheiro), `summon`. **Novo**: reviver o companheiro (pequeno, em `try_cast`
  já existe o `pet_of`).

**14. Atirador — Disparo do Fim** (`ran_ult_end_shot`, DIRECTION, `ult_bot: boss`)
- Mira 1,2 s parado (exceção ao teto de 0,3 s: é Suprema; dash cancela e a carga fica), projétil de 30 m que atravessa tudo:
  17,0 de poder no 1º (era 10,0), 60% nos outros, crítico garantido, empurra 2 m (chefe não).
- Reusa: `projectile_pierce`, knockback (`DruidAscension.knockback`). **Novo**: chaves `sure_crit` (crítico garantido do
  projétil) e `pierce_rest` (poder × isto depois do 1º atingido). Big version de Tiro na Cabeça (18).
- Implementação (onda B2): a mira é o `startup` da skill (`ULT_NUMBERS.aim` = 1,2 s, como o Tiro Certeiro com 0,45 s): o
  atirador fica parado encarando o cursor, o anel de preparo encolhe e o dash cancela antes da carga ser gasta. Única
  Suprema com startup acima de 0,3 s (o check aceita só quando bate com `aim`).

**15. Lanceiro — Lança Incansável** (`ran_ult_endless_lance`, DIRECTION, `ult_bot: boss`)
- Canal de 2,4 s: 12 estocadas numa linha de 6 m × 1,5 m, 0,84 de poder cada (10,1), cada uma renova o sangramento (28% do ATK/s) e a Marca
  do Predador; fim: arremessa a lança (12 m, 4,2, prende 1,5 s). Medido ~18 em alvo único.
- Reusa: `channel`, `bleed` do Lanceiro, `ran_predator`, `root`. **Novo**: nenhum.

#### Assassino

**16. Lâminas — Toxina Real** (`ass_ult_royal_toxin`, TARGET 3 m, `ult_bot: boss`)
- Golpe de 6,5 (era 2,0/3,0) que marca o alvo por 8 s: **seus venenos nele causam o dobro**. Ao acabar (ou o alvo morrer), todos os seus
  venenos no alvo detonam (`detonate` 3,8, era 1,5/2,0) e são copiados para inimigos a 4 m.
- Reusa: `combust` com `kind: poison` (`EVISCERATE_POISON`), `_put_dot`. **Novo**: `dot_amp` (debuff que multiplica os dots de
  um lançador no alvo; partilhado com as Sombras) e o espalhar na detonação.

**17. Duelista — Duelo Supremo** (`ass_ult_grand_duel`, SELF, `ult_bot: boss`)
- 6 s de guarda que **apara tudo** à frente (janela da `RiposteSystem` por 6 s, arco 140°, até 1 resposta a cada 0,5 s),
  cada aparo dá 2 de Ímpeto, +20 de crítico. Ao acabar: Golpe de Mestre grátis com Ímpeto cheio no inimigo à frente.
  Chefe: golpes passam com −60% (regra atual).
- **Contador do Duelo** (decisão do usuário 2026-11-19, jogo em grupo: o chefe olha o tanque, ninguém bate no Duelista):
  cada golpe direto seu durante a guarda (básico ou skill) soma +1 (até 8 golpes) e cada aparo soma +2; teto 10. O Golpe de
  Mestre do fim vale × 0,9 × (1 + 0,06 × contador): só com os próprios golpes ×1,48, com aparos ×1,6. Medido ~21 (fecho,
  respostas e o crítico a mais nos básicos). `RiposteSystem.duel_hit`, `UltEffects.end_cast`.
- Reusa: `RiposteSystem` (janela, `RIPOSTE_*`), `ass_master` + `momentum_spend`, `end_cast` (do Carniceiro). **Novo**: nenhum
  além de parâmetros. Piso: contra quem não bate (boneco, atirador longe) o Golpe de Mestre final ainda sai.

**18. Corsário — Chamado da Frota** (`ass_ult_fleet_call`, GROUND 12 m, `ult_bot: boss`)
- Um navio fora da tela bombardeia por 6 s: 14 balas de canhão em círculos de 2 m num raio de 6 m (metade sobre inimigos),
  cada uma avisada 0,4 s antes e de 2,0 (era 1,6) de poder + empurrão de 1 m (medido ~19 em alvo único); Bravata cheia (5) ao lançar.
- Reusa: `barrage` (`MobSystem.place_barrage/update_hazards`), Bravata. **Novo**: `barrage` com dono jogador (filtro hostil;
  aviso em areia/dourado, **nunca** vermelho: gramática de aviso de chefe).

#### Elementalista (as três usam um só sistema novo: `storm`)

**19. Fogo — Chuva de Meteoros** (`ele_ult_meteor_rain`, SELF, `ult_bot: boss`) — ideia do usuário
- 10 s, **presa no ponto do lançamento** (centro = onde o mago estava ao lançar): a cada 0,5 s cai um meteoro num ponto a até
  8 m desse centro (70% sobre um inimigo, preferindo quem não queima; 30% ao acaso), raio 2 m, poder 0,8 + queimadura 6,8/s (era 6; conta
  para a Combustão e a Semente). Aviso de 0,3 s (sombra laranja-areia). O mago anda e lança normalmente (não é canal) e pode
  sair da área. Medido ~20 em alvo único com as queimaduras (a medida antiga não contava a queimadura).
- Decisão do usuário (2026-11-19): **presa no ponto do lançamento** (`anchor: "ground"`), não segue o mago.
- **Novo**: `storm` (`{"anchor": "caster"|"ground", "duration", "every", "radius", "strike_radius", "power", "bias"}`), num
  sistema estático `StormSystem`. Big version de Meteoro (10).

**20. Gelo — Inverno Eterno** (`ele_ult_eternal_winter`, GROUND 9 m, `ult_bot: boss`) — ideia do usuário
- Tempestade de gelo **ancorada**, raio 6 m, 8 s; pulso a cada 1 s: 1,7 de poder (era 0,9/1,1) + lentidão 15% que acumula (até 45%).
  Quem leva 3 pulsos **congela** 2 s (atordoar; chefe ×0,4 = 0,8 s, uma vez por alvo por lançamento). Estilhaço ×1,3
  (`Combat.frost_mult`) pega em quem está retardado. Medido ~17-18 em alvo único.
- **Novo**: `storm` (ancorado) + contador de pulsos para congelar. Big version de Nevasca (20)/Zero Absoluto (26).

**21. Raio — Olho da Tempestade** (`ele_ult_storm_eye`, SELF, `ult_bot: boss`) — ideia do usuário
- 10 s, **segue o mago**, raio 9 m: a cada 0,4 s um raio cai num inimigo (prefere quem não levou nos últimos 0,8 s), 0,55 de
  poder (era 0,5/0,36), salta para 2 (`chain`, queda 0,6), 10% de chance de atordoar 0,4 s; ao lançar, +25% velocidade por 10 s e o Passo
  Relampejante volta da recarga. Medido ~19 em alvo único.
- **Novo**: `storm` (o mesmo). Big version de Senhor da Tempestade (28).

#### Necromante

**22. Invocador — Maré dos Mortos** (`nec_ult_tide_of_dead`, SELF, `ult_bot: boss`)
- Ergue 6 esqueletos (`skeleton_minion`) por 20 s **fora do limite** de invocações; 15 s de +40% MATK (as invocações escalam
  com o MATK do dono, `SUMMON_MATK_SHARE`) e +25% velocidade de ataque para as invocações. Quando os 6 somem, explodem
  (raio 3 m, poder 1,0 cada × vida restante, regra do `sacrifice`).
- Reusa: `summon` (com `ignore_max`), buff, `SummonRites` (`sacrifice`). **Novo**: só a chave `ignore_max` no `summon`.
  Big version de Exército dos Mortos (27).

**23. Ceifador — Ceifa das Almas** (`nec_ult_soul_reaping`, SELF, `ult_bot: self`)
- Giro enorme da foice: raio 6 m, poder 10,4 (era 4,5/6,5; só o giro é dano, medido ~10), cura 6% do HP por inimigo atingido (até 5 = 30%); depois 8 s de +25% ATK/MATK
  e +20 roubo de vida. Em Forma Demoníaca o giro vale ×1,2; em Fantasma, avança 3 m no giro.
- Reusa: dano em área, buff, variantes de forma (`FORM_VARIANTS` como Ceifeiro Sinistro). **Novo**: nenhum.

**24. Sombras — Eclipse do Vazio** (`nec_ult_void_eclipse`, GROUND 10 m, `ult_bot: boss`)
- Disco de vazio de raio 5 m por 8 s: inimigos dentro ficam 40% mais lentos, recebem cópia das suas maldições ao entrar e
  seus danos no tempo neles valem ×1,5. No fim, implosão: puxa ao centro (chefe não) e 7,0 de poder (era 3,0/4,0; implosão + o ×1,5 dos seus dots medidos ~9; o
  resto é controle).
- Reusa: `zone` (M1), `slow`, `pull`, `curse`. **Novo**: `dot_amp` (o das Lâminas) e `curse_spread` (copiar suas maldições).

**Chaves pequenas da onda B2** (implementação, 2026-11-19): `channel_end` (fim do canal arremessa a arma: Lança Incansável),
`sure_crit`/`pierce_rest` (Disparo do Fim), `hit_heal` {pct, max} (Ceifa das Almas), `cd_reset` [ids] (Olho da Tempestade
zera o Passo Relampejante), `pet_revive.buff`/`.spirit` (Laço Selvagem: buff no lince com `scale`, 2º lince espiritual
`free_summon`), `summon.buff_first`/`summon_buff`/`expire_blast` (Maré dos Mortos: o +MATK vale para os que nascem, buff de
velocidade nas suas invocações, explosão ao sumir × vida restante), guarda do Duelo com `riposte_arc/gain/gap` e
`momentum_fill`. O Chamado da Frota usa o `storm` (golpes avisados no tempo, lista própria `ally_strikes`) em vez da
`barrage` de uma vez só: 14 balas em 6 s pedem cadência. O Eclipse é um `storm` de pulsos sem dano (`strike_mult` 0) com
lentidão, `dot_amp` curto e `curse_spread`, e `end` = implosão. Ceifa das Almas nas formas: `FORM_MODS` (só a variante, sem
talentos/teia: `UltEffects.form_variant`).

## 4. Fórmulas

**Carga por golpe causado**
`g_dano = ULT_GAIN_PER_POWER × P × w_dano(papel) × m`
- `P` = poder do golpe antes de DEF/crítico (básico 1,0; skill = `SkillDef.power`; pulso de dot = poder do pulso). Faixa 0,1-6.
- `m` = 1 (direto), `ULT_DOT_MULT` (dot), `ULT_SUMMON_MULT` (invocação). Só os `ULT_AOE_TARGETS` maiores de cada ação.
- Exemplo (Lanceiro, `dps`): Empalar 3,8 num alvo → 1,4 × 3,8 × 1,0 = 5,3 pts (sai do estoque do teto de ritmo).

**Carga por cura**
`g_cura = ULT_GAIN_HEAL × (cura_efetiva / cura_ref) × w_cura(papel)`, `cura_ref = Combat.calc_heal(e, 1.0)`.
- Exemplo (Sacerdote, `healer`): Prece cura 1,4 × ref em 3 aliados feridos, 2,0 × ref efetivo no total → 1,0 × 2,0 × 1,7 = 3,4 pts (sai do estoque do teto de ritmo).

**Carga por dano recebido**
`g_apanhar = min(ULT_TAKEN_HIT_CAP, ULT_GAIN_TAKEN × 100 × dano / HP_máx) × w_apanhar(papel)` (cap antes do peso).
- Exemplo (Guardião, `tank`, golpe de chefe de 6% do HP): min(4, 0,4 × 6) = 2,4 × 1,6 = 3,84 pts (sai do estoque do teto de ritmo).

**Teto de ritmo**: `g_luta/s = min(g_dano + g_cura + g_apanhar, ULT_RATE_CAP)` em média (estoque de até `ULT_RATE_BURST`
para picos), mais `ULT_TRICKLE`.

**Ritmo-alvo** (sonda `boss_probe -- --lvl=40 --asc --ult`, seção 8): `t_cheia ≈ (ULT_MAX − ULT_RATE_BURST) / (ULT_RATE_CAP + ULT_TRICKLE)`
para quem passa do teto = (100 − 10) / (1,3 + 0,5) = **50 s**; quem fica abaixo do teto demora mais. Meta: **45-60 s** de luta
de chefe em grupo de 4 no nível 40, as 24 builds a ±20% da mediana.
Exemplos com os números finais (`ULT_GAIN_PER_POWER` 1,4):
- Lanceiro (`dps`), Empalar 3,8 num alvo: 1,4 × 3,8 × 1,0 = 5,3 pts pedidos; o estoque cheio (10) paga tudo, depois o ritmo
  médio fica no teto 1,3/s.
- Sacerdote (`healer`), Prece 2,0 × ref efetivo: 1,0 × 2,0 × 1,7 = 3,4 pts (abaixo do teto se curar menos de ~0,8 ref/s).
- Guardião (`tank`), golpe de chefe de 6% do HP: min(4, 0,4 × 6) × 1,6 = 3,84 pts.
**Medido (onda A, 2026-11-19)**: Ghar ×2,5 de vida, `--tank_lock`, 11 grupos tanque + Sacerdote + 2 builds, 4 lutas: as 24
builds enchem em **50,2-58,4 s** de luta de verdade (mediana ~53 s), contando de quando a carga sai do zero (quem morre e
volta recomeça do zero; o tempo de volta não conta). Histórico das 4 rodadas no relatório da onda A.

**Decaimento**: fora de combate por mais de `ULT_DECAY_DELAY`: `carga -= ULT_DECAY_RATE × dt`. Cheia → zero em
`ULT_DECAY_DELAY + ULT_MAX / ULT_DECAY_RATE` = 6 + 12,5 = 18,5 s.

**Força medida** (decisão do usuário 2026-11-19, `_check_ultimate_b2_power`): `ef = dano_da_Suprema / golpe_ref`
- `dano_da_Suprema` = `SimEntity.ult_dealt` no alvo nos 14 s depois de lançar contra um chefe parado: a sim soma o que sai sob
  `WorldSim.ult_tag` (o `_apply_skill` da Suprema e de skill `*_ult_*`, golpes de `storm`/`hop_strikes`, martelos do `orbit`,
  pulsos de zona, dots marcados `ult`, a parte que o `dot_amp` acrescenta, a detonação, o fecho `end_cast`, respostas do Duelo).
  Faixa típica: 3000-6000 de dano para golpe_ref 200-650.
- `golpe_ref` = média de 400 `Combat.calc_damage(lançador, alvo, 1,0)` (com crítico médio). Média de 5 lançamentos (15 nos
  de golpe único: Duelo, Veredito).
- Festim e Duelo (buffs): `ef = (dano batendo de básico 11 s com a Suprema − sem ela) / golpe_ref`.
- Alvo `ULT_POWER_BAND` 16-22 (check com folga de ±1,5 pelo crítico de golpe único e golpes sorteados); dano + utilidade só a
  parte de dano (`ULT_POWER_PART`: Ceifa 7-14, Eclipse 7-16). Exemplo: Disparo do Fim 17,0 de poder com crítico garantido
  (×1,5) ÷ golpe_ref com crítico médio (×~1,1-1,2) ≈ 19-21 medido.
- Medido (2026-11-19, `--only=ultimate`): Chuva 19,8, Disparo 21,6, Lança 17,8, Toxina 18,0, Frota 17,7, Inverno 16,7 (antes do
  1,6 -> 1,7), Olho 19,9, Juízo 19,0, Martelos 19,8, Veredito 18,1, Sete Ventos 20,0, Sol 18,0, Lua Rubra 17,4, Coração 16,2 (antes
  do 1,1 -> 1,2), Festim 20,2, Duelo 22,3, Ceifa 10,3, Eclipse 9,2.
- No grupo: `boss_probe -- --ult` imprime `ULTDMG <chefe> <classe:build>=<%>(suprema/total, suprema/luta)`: a parte do dano de
  cada build no chefe que veio da Suprema (meta ≥ ~8% sem derrubar uma fase de uma vez).

**Peso da Suprema na luta** (meta de calibragem): `razão = tempo sem Suprema / tempo com` em `boss_probe` (nível 40, 80 lutas por
braço, `--tank_lock`): **×1,08-1,15** para builds de dano; para Guardião, Sacerdote, Batalha, Urso: **−25 a −35% de mortes** do
grupo sob `--dmg` (mesma régua do F5 da ascensão em `docs/DESIGN.md`).

## 5. Casos de borda

- **Boneco de treino**: enche no ritmo normal e conta como combate (dá para praticar). Não há estoque: sair do boneco esvazia
  em 18,5 s e trocar de mapa zera; toda cidade com boneco fica longe disso de qualquer luta. Dano da Suprema no boneco não
  enche nada.
- **Morte** zera; **reviver** (Retorno do Bispo) começa do zero.
- **Troca de arma/build no meio da luta**: a carga fica; a Suprema passa a ser a da nova build principal.
- **Montado**: R desmonta e lança (como as skills não-montáveis). **Atordoado/preso**: recusada como qualquer skill (preso
  pode lançar as SELF/GROUND sem `dash`, regra atual de `root`).
- **Cancelada no preparo**: a carga fica (só é gasta quando sai).
- **Chefe**: atordoar/congelar ×0,4, provocar metade, empurrar/puxar não (regra atual de `resists_cc`); o Rei elite leva
  cheio. Inverno Eterno congela um chefe só uma vez por lançamento.
- **Duas cúpulas** (Cúpula da Graça + Barreira Sagrada, de qualquer Bispo): vale a maior redução. **Duas Proteções**
  (dois Guardiões): vale a do paladino mais perto; um paladino não protege outro paladino que esteja protegendo.
- **Guardião protegendo** chega a 25% de vida: a Proteção acaba (aviso no HUD).
- **Urso em Ent**: recusada. Urso desliga a forma durante o Colosso: o Colosso acaba junto, HP pela %.
- **Lince do Caçador**: com o falcão (ascensão) não muda nada; sem lince (morto) a Suprema o revive primeiro.
- **Invocador**: os 6 esqueletos não entram na conta do `max` nem no `sacrifice` da Oferenda Sombria (já explodem sozinhos).
- **Fogo/Raio seguindo o mago**: o mago trocou de mapa ou morreu → a tempestade some. Meteoro não cai fora da área andável
  (`MapGeometry`): se o ponto sorteado não é andável, sorteia de novo (até 3 tentativas, senão pula).
- **Sete Ventos / Lua Rubra**: sem inimigo no raio entre saltos → acaba na hora (sem desperdício: o resto não vale nada).
  O salto não atravessa parede (`MapGeometry.line_walkable`); alvo atrás de parede é pulado.
- **Disparo do Fim**: atravessa inimigos, não paredes; cancelar no preparo devolve a carga inteira.
- **PvE só**: nenhum efeito atinge jogador ou bot (não há PvP); aliados nunca levam dano de Suprema.
- **Dados aleatórios** (meteoros, raios): só o RNG da sim (determinístico por comando).

## 6. Dependências

- **Usa**: `ProgressionSystem` (`has_ascension`, `main_build`, `role_of`), `WorldSim` (`try_cast`, `_apply_command`,
  `_apply_effects`, `_deal_damage`, cura), `ChoirSystem` (cúpula), `RiposteSystem`, `WoundSystem`, `SunderSystem`,
  `SummonRites`, `TrapSystem` (zona M1), `AuraSystem` (`orbit`), `MobSystem.place_barrage/update_hazards`,
  `DruidAscension.knockback`, `Combat.calc_heal`/`frost_mult`, `SimEntity.put_buff`.
- **Novos** (todos em `core/`, sem Node): `UltimateSystem` (medidor), `StormSystem` (`storm`), efeitos `intercept`,
  `hop_strikes`, `dot_amp`, `curse_spread`, `end_cast`, chaves `ignore_max` (summon) e `oath_lock` (buff), `barrage` com dono
  jogador. Campos novos: `SkillDef.ultimate`, `SkillDef.ult_bot`; `SimEntity.ult_charge/ult_combat_t/ult_gap_until`;
  `InputCommand.ultimate`; ação `ultimate` no InputMap.
- **Pedido ao `world-builder`** (fora do meu território): ramo `ultimate` no `BotBrain` (regras `boss/save/self`, segurar
  `BOT_ULT_HOLD`, `BOT_ULT_STAGGER`). Os bots NÃO devem fugir dos círculos da barragem do Corsário nem da `storm` (são de
  aliado e não ferem): o desvio de `hazards` precisa olhar o dono.
- **Apresentação**: `action_bar.gd` (moldura R), `make_icons.gd` (24 glifos), `skill_fx.gd`/`fx_manager.gd` (24 VFX; o
  `storm` e a barragem do Corsário precisam de aviso que não seja vermelho), `EntityView` (escala do Avatar e do Colosso;
  `FormModel` do urso), `Sfx` (`ult_ready` + sons de impacto por Suprema), `BuffLooks.LOOKS` (buffs novos: Proteção,
  Festim, Avatar, Colosso, Laço, Duelo, Toxina Real, Eclipse).
- **Documentos a atualizar quando aprovado**: `docs/DESIGN.md` (seção nova "Supremas"), `.claude/docs/ragnaex/conteudo.md`
  ("Como adicionar conteúdo": Suprema), `design/gdd/ato2-horda.md` (R6: a ascensão agora também libera a Suprema no 40).
- **Save**: **formato inalterado**. A carga não é salva (recurso de combate); a vaga R é implícita (sai da build). Nenhum
  `save_version` novo.

## 7. Botões (Balance)

| Constante | Valor inicial | Faixa segura | Afeta |
|---|---|---|---|
| `ULT_LEVEL` | 40 | 40 | nível que libera (com a ascensão) |
| `ULT_MAX` | 100.0 | fixo | escala do medidor |
| `ULT_GAIN_PER_POWER` | 1.4 (era 1.0) | 0,6-1,4 | ritmo das builds de dano abaixo do teto |
| `ULT_GAIN_HEAL` | 1.0 | 0,6-1,4 | ritmo das curas |
| `ULT_GAIN_TAKEN` | 0.4 | 0,2-0,6 | ritmo dos tanques |
| `ULT_TAKEN_HIT_CAP` | 4.0 | 2-8 | golpe enorme não enche de uma vez |
| `ULT_TRICKLE` | 0.5 (era 0.25) | 0-0,5 | piso de ritmo em combate (fora do teto) |
| `ULT_RATE_CAP` | 1.3 (novo, aprovado 2026-11-19) | 1,0-1,8 | teto de pts/s de dano/cura/apanhar: o ritmo de quem faz o papel |
| `ULT_RATE_BURST` | 10 (novo, aprovado 2026-11-19) | 5-20 | estoque do teto: picos (abertura, golpe grande) |
| `ULT_DOT_MULT` | 0.6 | 0,4-1,0 | dano no tempo vs direto (vale abaixo do teto) |
| `ULT_SUMMON_MULT` | 0.8 (era 0.5) | 0,3-0,8 | invocações (Invocador, Xamã, Caçador) |
| `ULT_AOE_TARGETS` | 3 | 2-5 | área não enche demais (vale abaixo do teto) |
| `ULT_ROLE_WEIGHTS` | tabela 3.2; cura 0,9/1,7/0,6 | ±0,3 por célula | justiça entre papéis (vale abaixo do teto) |
| `ULT_DECAY_DELAY` | 6.0 | 4-10 | quanto a carga aguenta fora de luta |
| `ULT_DECAY_RATE` | 8.0 | 5-20 | quanto demora para esvaziar |
| `ULT_MIN_GAP` | 20.0 | 10-40 | trava contra duas seguidas |
| `ULT_NUMBERS[<id>]` | seção 3.5 | ±25% | força de cada Suprema |
| `ULT_POWER_BAND` | [16, 22] (era o orçamento 10-14; +60%, decisão do usuário 2026-11-19) | 14-24 | alvo da força em alvo único das Supremas de dano (check) |
| `ULT_POWER_PART` | Ceifa [7, 14], Eclipse [7, 16] | — | faixa só da parte de dano das que também são utilidade |
| Duelo: `hit_gain` / `hit_cap` / `gain` / `duel_cap` / `duel_per` | 1 / 8 / 2 / 10 / 0,06 | 0-2 / 4-12 / 1-3 / 6-14 / 0,03-0,1 | contador do Duelo: o fecho cresce com os seus golpes e aparos |
| `BOT_ULT_PACK` | 3 | 2-5 | bando mínimo para bot soltar |
| `BOT_ULT_SAVE_ALLIES` / `BOT_ULT_SAVE_HP` | 2 / 55 | 1-3 / 40-65 | quando a cura/tanque bot salva |
| `BOT_ULT_HOLD` | 20.0 | 0-40 | bot segura esperando o chefe |
| `BOT_ULT_STAGGER` | 3.0 | 0-6 | bots do grupo não soltam juntos |

## 8. Critérios de aceite (checks em `tools/tests/run_tests.gd`, `--only=ultimate`)

1. `_check_ultimate_unlock`: nível 39 com ascensão = sem Suprema; 40 sem `hx_asc_<classe>` = sem; 40 com = `ultimate_of`
   devolve a da build principal para as 24 builds (uma por build, ids únicos, `unlock_level` 40, `ultimate = true`).
2. `_check_ultimate_catalog`: as 24 estão fora da teia comum e da de ascensão; `set_skill_slot` recusa em 1-0; custo 0; texto e
   ícone existem; `ult_bot` é um de `boss/save/self`; todo número vem de `ULT_NUMBERS`.
3. `_check_ultimate_meter`: golpe de poder 2,0 de `dps` dá 2,0 pts; o mesmo em `tank` dá 1,2; dot conta × `ULT_DOT_MULT`; área com
   8 alvos conta 3; sobrecura dá 0; golpe recebido de 50% do HP dá no máx. `ULT_TAKEN_HIT_CAP` × peso; cheia não passa de 100.
4. `_check_ultimate_decay`: 6 s fora de luta não perde; depois perde 8/s; morrer zera; trocar de mapa zera; o boneco enche no ritmo
   normal e nada sobra 19 s depois de sair dele.
5. `_check_ultimate_cast`: R com carga < 100 é recusado; com 100 sai, zera e não enche por `ULT_MIN_GAP`; cancelado no preparo
   mantém a carga; o dano da própria Suprema não enche; `InputCommand.ultimate` é zerado no comando repetido.
6. Um check por mecânica nova: `intercept` (aliado leva −30%, paladino leva os 30%, para a 25%); `hop_strikes` (7 golpes, 1
   alvo = 7 no mesmo, iframe, não atravessa parede); `storm` (Fogo segue o mago ao andar 5 m; Gelo congela no 3º pulso, chefe
   0,8 s e uma vez); `dot_amp` (dot ×2 só do lançador); `curse_spread`; `end_cast` (Sangria grátis ao fim do Festim);
   `barrage` do jogador não fere aliado; Colosso mantém a % de vida ao acabar; Cúpula da Graça + Barreira não somam.
7. `_check_ultimate_bots`: bot `boss` solta contra chefe e não contra 1 bicho comum; bot `save` solta com 2 aliados a 50%;
   dois bots não soltam no mesmo segundo (com o ramo do `world-builder`).
8. Sondas (não checks): `boss_probe -- --lvl=40 --ult` (coluna `ULT` = segundos até a 1ª carga cheia por membro: 45-60 s,
   ±20% da mediana entre as 24) e `--ult_off` para a razão de força da seção 4; `combat_probe -- --class=<c> --ult` sem
   `FLAG`; `--showcase=<classe> --skill=<id>` filma as 24 (nota ≥ 8 em `docs/skills_review.md`); smoke
   `-- --autostart=<classe> --level=40 --ascend` sem `SCRIPT ERROR`; foto da moldura R (vazia, meia, cheia, travada) em
   `production/qa/evidence/ultimates/`.

## 9. Resumo das mecânicas novas e recuos

| Mecânica | Quem usa | Recuo se o usuário quiser menos |
|---|---|---|
| `UltimateSystem` (medidor) | todas | — (pedida) |
| `storm` | Fogo, Gelo, Raio | Gelo vira zona M1 com `slow`+`stun` no fim; Fogo/Raio viram 5 lançamentos de Meteoro/Trovão em sequência (`strikes` de GROUND) |
| `hop_strikes` | Punhos, Lobo | `strikes` no mesmo alvo com `dash` curto (perde o "saltar entre inimigos") |
| `intercept` | Guardião | buff de grupo −25% de dano (`dr_pct`, dentro do `DR_CAP`) + `taunt` |
| `dot_amp` + `curse_spread` | Lâminas, Sombras | Lâminas: Eviscerar grátis com `detonate` 1,8; Sombras: zona M1 + `curse` direto no impacto |
| `end_cast` | Carniceiro, Duelista | a Sangria/Golpe de Mestre sai no lançamento (perde o "fechamento") |
| `barrage` do jogador | Corsário | GROUND com `strikes` de 5 golpes em pontos fixos |
| `ignore_max`, `oath_lock`, reviver companheiro | Invocador, Templário, Caçador | chaves pequenas; sem recuo necessário |
