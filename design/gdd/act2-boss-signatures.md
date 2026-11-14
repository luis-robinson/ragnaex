# Ato II — Assinaturas dos Chefes (APROVADO 2026-11-13)

> **Status**: rascunho para aprovação · **Autor**: game-designer · **Data**: 2026-11-13
> **Decisão de origem (usuário, 2026-11-13)**: "melhorar as mecânicas de chefe" → **só assinatura por chefe**.
> `Balance.BOSS_CROWD_MULT` não muda; nada de reescrever o sistema de chefes. Cada chefe do Ato II ganha **uma**
> mecânica nova, avisada e própria, que muda *como* a luta se joga (não só quanto dano dá).
> Relacionados: `design/gdd/ato2-horda.md` (Chefes), `design/gdd/kharzun-fase3-plan.md` §4, manual "Chefe com mecânica".
> Fora do escopo: Rainha Aranha (nível 20, Ato I) e os chefes do Ato I.

## 1. Overview

Os 11 chefes do Ato II (Mãe das Marés 33 → Durgash 45) hoje se diferenciam quase só pelo tema: todos usam o mesmo
molde (fase 70% `summon`, fase 40% `barrage` + `ward`, fase 15% `enrage`, `berserk_after`). Este documento dá a cada
um **uma assinatura** — uma regra que pede uma resposta diferente do grupo (sair, juntar, espalhar, interromper,
trocar de alvo, usar o terreno). As assinaturas reaproveitam a caixa de ferramentas atual (`barrage`/hazards,
`mob_pick`, `front_guard`, lacaios parados, `stun`) e acrescentam **4 regras compartilhadas** + 3 pequenas regras
únicas. O molde de fases continua igual.

## 2. Player Fantasy

- **Estética MDA alvo**: *Challenge* (ler e responder) e *Fellowship* (o grupo de bots reage junto). Cada chefe ensina
  um verbo; ao fim do Ato II o jogador "fala" todos eles e o Durgash cobra vários ao mesmo tempo.
- **SDT / Competência**: todo golpe da assinatura é avisado no chão ≥ 1,5 s antes (leitura da câmera alta, 52°) e a
  morte tem causa nomeada. **Fellowship**: os bots fazem a resposta certa na maior parte das vezes — e erram às vezes,
  o que torna visível que a mecânica existe.
- **Curva de ensino** (sawtooth): 33-38 ensinam um verbo de cada vez; 39-41 juntam verbo + pressão; 43-44 pedem
  leitura fina; 45 combina (juntar *contra* espalhar para os estandartes).

## 3. Detailed Design

Convenção: números marcados **(K)** são botões de ajuste (vão para `data/balance.gd` ou para o dicionário de efeito
da skill no catálogo, como o `barrage` já faz). `power` = multiplicador de ATK/MATK do chefe (mesmo uso das skills atuais).
"Assinatura ativa a partir de" = fase em que a skill entra (`phases[].skills`), salvo dito o contrário.

### 3.1 Mãe das Marés (`boss_tide_mother`, 33) — **Maré Cheia** · verbo: *juntar num lugar seguro*
- **Kit atual**: lança/laço da maré, onda em volta, crias (70%), gêiseres `barrage` + `ward` (40%), fúria (15%).
- **Fantasia**: o mar entra na enseada e só as pedras ficam secas.
- **Regra**: desde 100%, a cada **30 s (K)** ela grita "A maré sobe!"; surgem **N ilhas** (círculos de areia, raio
  **2,5 m (K)**) a 6-12 m dela, uma sempre perto do tanque. **3,0 s (K)** depois, todo inimigo **fora** de qualquer
  ilha leva `power` **1,6 (K)** mágico + `slow` 40% 3 s. N = `max(2, ceil(crowd/2))` (K): solo tem 2 ilhas, grupo de 4 tem 2.
- **Reusa**: lista `hazards`, `Events.hazard_placed`, `slow`. **Novo**: hazard com `invert: true` (R-A).
- **Bots**: com um hazard `invert` pendente e fora de toda ilha → andar para o centro da ilha mais perto (antes de
  qualquer outro desvio). Tanque leva o chefe junto (ele já anda até o alvo).
- **Leitura**: ilhas = disco de areia clara com borda branca; a água sobe da borda da arena como anel azul que fecha
  durante os 3 s. Contraste máximo com o chão escuro molhado.
- **Aceite**: check: entidade dentro da ilha leva 0, fora leva dano. Sonda (`boss_probe --party=4 --why`): ≤ 15% dos
  personagens atingidos por maré.

### 3.2 Agitador-Mor Grukk (`boss_agitator_lord`, 36) — **Rufar da Turba** · verbo: *interromper*
- **Kit atual**: aura de tambor, chamar turba, empalar, rede, tambor de guerra (área), chuva de lanças + `ward` (40%).
- **Fantasia**: se o tambor tocar até o fim, a turba vira um tumulto.
- **Regra**: a partir de 70%, a cada **35 s (K)** ele finca o tambor e **canaliza 4,0 s (K)** (parado). Terminou →
  lacaios e escolta a ≤ 20 m ganham **Frenesi** (+40% dano, 12 s) e curam 30%, e vêm +2 Turbas. **Quebra** se, durante o
  canal, ele levar `stun` (qualquer fonte) **ou** dano ≥ **6% da vida máxima (K)** → **Tambor Rasgado**: atordoado
  **3 s (K)** e +25% de dano recebido por 6 s (K).
- **Reusa**: `stun`, `put_buff`, `spawn_adds`. **Novo**: efeito `channel` (R-C).
- **Bots**: com o chefe no buff de canal, todo DPS usa a skill de maior dano pronta no chefe; quem tem skill com `stun`
  a guarda para o canal (não gasta em lacaio quando o chefe está a < 50% da recarga do Rufar).
- **Leitura**: anel no chão em volta dele que se enche (barra de progresso circular) + fala "INTERROMPAM O TAMBOR!" no
  aviso; quebra = anel estoura em lascas.
- **Aceite**: check: 6% de dano no canal quebra; sem dano, completa e dá Frenesi. Sonda: grupo de 4 quebra ≥ 60% dos canais.

### 3.3 Troll Rei-da-Rocha (`boss_troll_king`, 38) — **Avalanche** · verbo: *usar o terreno (cobertura)*
- **Kit atual**: regeneração 0,3, chamar trolls, pancada, chuva de pedras, pedregulho, abalo; desabamento + `ward` (40%).
- **Fantasia**: ele arremessa a montanha; o que sobra no chão é o único abrigo.
- **Regra**: cada Chuva de Pedras deixa **1 Pedregulho** (lacaio parado, intocável, raio **1,2 m (K)**, dura 40 s,
  máx. 3). A partir de 70%, a cada **30 s (K)**: 2,5 s de preparo (ele ergue os braços) e uma onda em 360° até 18 m,
  `power` **2,2 (K)** + `stun` 1 s, em todo alvo que **não** tenha um Pedregulho entre ele e o chefe (segmento
  chefe→alvo cruza o círculo da pedra). O Pedregulho que protegeu alguém racha e some. Sem pedra no chão ao começar →
  ele arremessa 2 antes (garantia).
- **Reusa**: lacaio parado (padrão do estandarte do Durgash), pedregulho/chuva de pedras. **Novo**: cobertura (R-E, única).
- **Bots**: no preparo da Avalanche, ir para `pedra + dir(chefe→pedra) × (raio + 0,8 m)` da pedra mais perto e livre.
- **Leitura**: durante o preparo, uma "sombra" clara em cunha atrás de cada pedra no chão (zona segura) — de cima é
  a forma mais legível possível.
- **Aceite**: check: alvo atrás da pedra leva 0; pedra que protege some. Sonda: ≤ 1 atingido por Avalanche (média) no grupo de 4.

### 3.4 Mestre Besteiro Vorgul (`boss_crossbow_master`, 39) — **Marca do Atirador** · verbo: *espalhar*
- **Kit atual**: atiradores `far`, barris de pólvora, virote, chuva de fogo; tempestade de fogo + `ward` (40%).
- **Fantasia**: o virote dele não erra — o que você controla é quem está do seu lado quando ele chegar.
- **Regra**: desde 100%, a cada **18 s (K)** marca **M** vítimas (`mob_pick: random`, sem o tanque se houver outro;
  M = 1 solo, 2 em grupo (K)) com uma mira que **segue** a vítima por **4 s (K)**; então explode raio **4 m (K)**,
  `power` **1,5 (K)** em todos dentro e deixa fogo no chão 4 s.
- **Reusa**: `mob_pick`, `burn`/dot de fogo. **Novo**: marca que segue (R-B, modo `spread`).
- **Bots**: o marcado anda para o ponto (8 direções, até 8 m) mais longe dos aliados e das outras marcas; os demais
  tratam a marca como hazard móvel (já fogem de círculo).
- **Leitura**: retícula vermelha no chão em volta do marcado + anel que encolhe até a explosão.
- **Aceite**: check: a marca segue a vítima e acerta quem está no raio. Sonda: aliados atingidos por marca ≤ 0,3 por marca.

### 3.5 Senhor da Guerra Ghar (`boss_ghar`, 40) — **Muralha de Escudos** · verbo: *posicionar (flanco)*
- **Kit atual**: vanguarda, investida, talho, brado; terra rachada + `ward` (40%).
- **Fantasia**: o general que só se derruba pelas costas.
- **Regra**: desde 100%, a cada **25 s (K)** ergue o escudo por **6 s (K)**: golpes **físicos e mágicos** vindos do arco
  frontal (120°, mesmo `Combat.in_guard_arc`) perdem **90% (K)**; cada golpe bloqueado soma 1 **Fúria Contida**. No fim,
  **Contragolpe** em cone 150° à frente: `power` 1,0 + 0,15 × fúria (K, teto 2,5).
- **Reusa**: `front_guard` e `in_guard_arc` (do Guarda de Clã), cone. **Novo**: buff que dá `front_guard` temporário
  e conta fúria (R-G, pequeno).
- **Bots**: com o buff da muralha, quem não é tanque vai para trás (`chefe − frente × alcance`) e não ataca de frente;
  o tanque segura de frente e bloqueia (já faz).
- **Leitura**: escudo-torre erguido no modelo + cunha frontal âmbar no chão; contagem de fúria como pips sobre a cabeça.
- **Aceite**: check: golpe de frente perde 90%, de costas não. Sonda: fúria média ≤ 3 por muralha (grupo de 4).

### 3.6 Presa-de-Cinza, a Mãe-Loba (`boss_dire_mother`, 41, campo, solável) — **Três Botes** · verbo: *esquivar em ritmo*
- **Kit atual**: salto, mordida; uivo + filhotes (60%); fúria (30%).
- **Fantasia**: a loba escolhe a presa e dá o bote três vezes.
- **Regra**: a partir de 60%, a cada **20 s (K)** escolhe uma vítima (`far`; solo = o jogador) e dá **3 botes**
  seguidos em linha (largura 1,6 m, alcance 10 m, `power` **1,2 (K)**), cada um mirado onde a vítima está, com aviso
  em linha de **0,8 s (K)** e **0,6 s (K)** entre eles. Ignora a ameaça durante a sequência. `root`/`stun` nela cortam a sequência.
- **Reusa**: investida `T_DIR` (bots já desviam de `DIRECTION`). **Novo**: `repeat` (R-D).
- **Bots**: nada novo além de não "voltar" para a linha (o desvio atual de `DIRECTION` cobre); quem tem `root` usa no 1º bote.
- **Leitura**: faixa vermelha no chão da loba até a vítima, uma por bote.
- **Aceite**: check: 3 botes, cada um re-mirado; `root` corta. Sonda solo: ≤ 1,2 botes acertados por sequência (faixa campo mantida).

### 3.7 Mestre Matador Shazka (`boss_shazka`, 43) — **Sombras Gêmeas** · verbo: *achar o alvo certo*
- **Kit atual**: faca; (70%) chamar aprendizes, sumir, passo sombrio + `ward`; (35%) nuvens de veneno, misericórdia.
- **Fantasia**: "qual de nós é o mestre?"
- **Regra**: cada vez que sai do Sumir na Fumaça reaparece com **2 cópias (K)** (mesmo modelo e nome). Cópia: morre com
  1 golpe, dano 30% (K), dura 10 s; **morrendo, solta nuvem de veneno** raio 2 m (K). O verdadeiro é o único que
  **projeta sombra no chão**. Golpe no verdadeiro durante as cópias = as cópias somem.
- **Reusa**: `summon` (lacaio 0 XP), nuvem de veneno. **Novo**: `MonsterDef.decoy` (R-F, única).
- **Bots**: mirar o verdadeiro com chance **70% (K)** (de propósito imperfeito); área mata cópia sem custo.
- **Leitura**: cópias sem sombra e levemente translúcidas; a câmera alta vê a sombra com clareza.
- **Aceite**: check: cópia morre com 1 golpe, solta veneno, não tem `boss_id` de XP. Sonda: tempo extra por Sumir ≤ 4 s.

### 3.8 Ulgra Presa-Atroz (`boss_ulgra`, 44) — **Estouro da Matilha** · verbo: *ler faixas e atravessar*
- **Kit atual**: investida, corrente `far`; (70%) ginetes; (40%) `ward`; (15%) lanças `barrage` + fúria.
- **Fantasia**: o clã inteiro atravessa a arena a galope.
- **Regra**: a partir de 70%, a cada **28 s (K)** ela recua à borda e marca **3 faixas paralelas (K)** de 3 m de
  largura cruzando a arena (uma sobre o tanque), com vãos de 3 m. As faixas caem em sequência **2,0 / 2,6 / 3,2 s (K)**:
  `power` **1,6 (K)** + derruba (`stun` 0,8 s). Visual: Ulgra galopa a 1ª, ginetes fantasmas as outras.
- **Reusa**: `barrage` (tempo, aviso, efeitos). **Novo**: forma `line` do hazard (R-A).
- **Bots**: o desvio de hazard passa a usar distância ao segmento (sair perpendicular à faixa, para o vão).
- **Leitura**: faixas de poeira marrom no chão com setas na direção do galope; ordem pelo brilho (1ª mais forte).
- **Aceite**: check: forma `line` acerta dentro da largura e não no vão. Sonda: ≤ 0,5 atingidos por estouro.

### 3.9 Gorbash Pele-de-Rocha (`boss_gorbash`, 44) — **Ondas da Montanha** · verbo: *ritmo (entrar e sair)*
- **Kit atual**: regeneração 0,3, pancada, pedregulho; (70%) xamãs + `ward`; (40%) abalo + desabamento.
- **Fantasia**: cada pisada dele empurra um anel de pedra pelo chão.
- **Regra**: a partir de 70%, a cada **24 s (K)** pisa 3 vezes; cada pisada solta um **anel** que nasce nele e se
  expande (largura 2 m, até 16 m) — modelado como 3 anéis por pisada em raios crescentes que caem a cada 0,5 s (K).
  `power` **1,1 (K)** por anel. Seguro: passar *através* do anel logo depois que ele cai (entra-sai), ou estar além de 16 m.
- **Reusa**: hazards. **Novo**: forma `ring` (`inner`/`radius`) do hazard (R-A).
- **Bots**: para anel, o escape é o lado mais perto (para dentro se `d − inner < radius − d`), não "para longe".
- **Leitura**: anéis de rachadura avisados no chão; o próximo anel fica aceso.
- **Aceite**: check: anel acerta entre `inner` e `radius`, não dentro nem fora. Sonda: ≤ 1 anel por pessoa por série.

### 3.10 Kragmar Martelo-Negro (`boss_kragmar`, 44) — **Têmpera na Lava** · verbo: *o tanque move o chefe*
- **Kit atual**: martelo, ondas de lava `barrage` `random`; (70%) golens; (40%) `ward`; fúria; berserk 150 s.
- **Fantasia**: o ferreiro que se tempera no próprio metal derretido.
- **Regra**: cada círculo de Ondas de Lava deixa **poça** por **20 s (K)** (tique de `power` 0,25/s em quem pisa). Kragmar
  **dentro** de uma poça ganha 1 **Têmpera** a cada 2 s (K): +8% dano por acúmulo (K, máx. 6) e cura 0,5%/s; sair da poça
  perde 1 acúmulo a cada 3 s.
- **Reusa**: `barrage`, dot de fogo. **Novo**: `linger` + `empower` do hazard (R-A).
- **Bots**: tanque: chefe em poça → andar para o ponto livre de poça mais perto a ≥ 4 m (o chefe vem atrás). Demais: já evitam círculos.
- **Leitura**: poças laranja persistentes; brilho no martelo cresce com a Têmpera (+ ícone com pilhas na barra de buffs).
- **Aceite**: check: Têmpera só sobe dentro da poça. Sonda: Têmpera média ≤ 2 no grupo de 4.

### 3.11 Durgash, o Grão-Senhor da Guerra (`boss_durgash`, 45, raide de 5) — **Machado do Trono** · verbo: *juntar para dividir*
- **Kit atual**: talho, investida, machado, brado; (70%) 3 estandartes + `ward`; (40%) corrente, terra rachada, guarda; (15%) fúria.
- **Fantasia**: um golpe que um só não aguenta, mas o grupo aguenta junto.
- **Regra**: desde 100%, a cada **26 s (K)** marca uma vítima (`random`, não o tanque) com um círculo de **3,5 m (K)**
  que a segue por **5 s (K)**; no impacto, `power` total **6,0 (K)** **dividido** entre todos os personagens dentro
  (mín. 1). Com 3+ dentro cada um leva ≤ 2,0; sozinho, ~letal. Na fase dos estandartes isso força o grupo a se
  reagrupar — tensão de propósito com "dividir para os estandartes".
- **Reusa**: `mob_pick`. **Novo**: marca que segue, modo `soak` (R-B).
- **Bots**: com marca `soak` ativa, todo bot não-tanque a ≤ 15 m vai para o marcado; o marcado para no lugar.
- **Leitura**: círculo dourado com 3 "vagas" desenhadas (pips) que acendem conforme gente entra.
- **Aceite**: check: dano dividido por N dentro. Sonda raide: ≤ 0,2 mortes por machado; vitória do 5 completo mantém ≥ 90%.

## 4. Formulas

- **F-S1 Divisão (soak)**: `dano_i = calc_damage(power_total / max(1, n_dentro))` para cada personagem dentro. Ex.: Durgash
  ATK 160 (chefe 45: 100 × 1,6; `unit_mods.atk` 1,0) × reforço de raide ×3,25 com 5 (`BOSS_CROWD_RAID`, entra no ATK) = 520;
  power **2,0** (calibrado; era 6,0) → base 1040; n=3 → 347 cada; n=1 → 1040 (antes de DEF). Com 4 na raide (×4,9): 1568 / 523.
  A DEF sai do pedaço de cada um (`calc_damage` por pessoa), então dividir rende mais que 1/N (check, power 6,0 sem reforço:
  679 / 440 / 202 por pessoa com 1 / 2 / 4 dentro). Fúria ×1,35 e berserk ×20 (128 s) multiplicam o ATK igual.
- **F-S2 Quebra de canal**: `quebra = stun_recebido OR dano_no_canal ≥ CHANNEL_BREAK_PCT × max_hp`. Grukk (vida ≈ 1,8 × chefe
  36): 6% ≈ 4 s de DPS de grupo de 4 a ~1,5%/s cada — alcançável só se o grupo focar.
- **F-S3 Têmpera**: `dmg_mult_kragmar *= 1 + TEMPER_STEP × acúmulos` (0..6 → ×1,00..×1,48), multiplica junto com `enrage`/crowd em `_apply_fury`.
- **F-S4 Ilhas da maré**: `N = max(ISLAND_MIN, ceil(crowd / 2))`, cada ilha comporta folgado 3 personagens (raio 2,5 m).
- **F-S5 Contragolpe de Ghar**: `power = COUNTER_BASE + COUNTER_STEP × min(fúria, (COUNTER_CAP − COUNTER_BASE)/COUNTER_STEP)`.
- Todo dano de assinatura passa pelo `dmg_mult` (fúria × berserk × crowd) como as skills atuais — o crowd **não** é mexido.

## 5. Edge Cases

- **Solo**: marcas viram 1 (Vorgul), soak sozinho não existe fora da raide (Durgash só é raide); ilhas mín. 2; Avalanche
  sempre garante pedras. Nenhuma assinatura exige 2 pessoas para ser sobrevivível, exceto o Machado do Trono (raide de 5, por desenho).
- **Chefe resetado** (`reset_boss`): hazards do dono já são limpos; acrescentar limpar marcas, canal, Têmpera, pedregulhos e cópias.
- **Chefe morre no meio**: hazards/marcas com dono morto somem (regra atual de `update_hazards`); cópias do Shazka somem juntas.
- **Sobreposição**: ilha não nasce sobre hazard pendente; durante a janela da Maré Cheia os gêiseres esperam (≤ 1 mecânica de chão por vez).
- **Vítima some** (morre, troca de mapa, furtividade) durante a marca: a marca fica parada onde estava e cai normalmente.
- **Canal + `ward`**: o dano do `ward` cortado conta como recebido? **Não** — conta o dano *aplicado* (depois do corte), para o
  ward continuar valendo matar lacaio primeiro.
- **Cobertura com invocação/pet**: pet atrás da pedra também é protegido; a pedra protege qualquer número de alvos, mas racha no fim.
- **Cópias e `mob_pick: soft`**: cópias não contam como chefe para crowd, ameaça, XP nem quests.
- **Muralha e skills sem origem** (dot, aura): só golpes com origem no arco frontal são cortados; dot já aplicado continua.
- **Degenerado**: ficar fora de alcance da Avalanche (> 18 m) — aceitável para atiradores, a pedra existe para o corpo a corpo;
  "kite eterno" do Kragmar fora das poças é o comportamento desejado, não exploração.

## 6. Dependencies

- `core/sim/systems/mob_system.gd` (`place_barrage`, `update_hazards`, `update_boss`, `reset_boss`) — dono das regras R-A..R-D.
- `core/sim/world_sim.gd` (`_apply_effects`, cálculo do `front_guard` ~l.1611) — R-G, quebra de canal no dano.
- `core/sim/ai/bot_brain.gd` (`_danger_escape`) — formas novas, `invert`, marca, soak, canal; `core/sim/ai/monster_brain.gd` — `repeat`, recuo da Ulgra.
- `data/schemas/skill_def.gd` (`EFFECT_KEYS`: `channel`, `repeat`, `mark`), `data/schemas/monster_def.gd` (`decoy`), `data/balance.gd`.
- `game/` (apresentação): desenho dos hazards novos (linha, anel, ilha, poça, retícula, pips), anel de canal, `BuffLooks` para
  Frenesi/Têmpera/Muralha/canal, `Sfx` para cada aviso. **ux-designer** + **technical-artist** para leitura de cima.
- Atualizar `design/gdd/ato2-horda.md` (Chefes) e `kharzun-fase3-plan.md` §4 com um link para este doc; `docs/DESIGN.md` (Chefes).

### Regras novas compartilhadas (proposta de esquema)

| Id | Nome | Onde | Esquema | Usam |
|---|---|---|---|---|
| R-A | **Hazard v2** (formas e chão vivo) | `barrage` em `place_barrage/update_hazards` | `shape: "circle"\|"line"\|"ring"`, `width`, `inner`, `dir`; `invert: bool` (fora = dano); `linger: s` + `tick: s`; `empower: {buff, step}` | Maré, Ulgra, Gorbash, Kragmar |
| R-B | **Marca** (segue a vítima) | hazard com `follow: entity_id` | efeito `mark: {mode: "spread"\|"soak", count, radius, time, power, pick}` | Vorgul, Durgash |
| R-C | **Canal interrompível** | `SkillDef.effects.channel` | `{time, break_pct, on_done: {buff, heal_adds_pct, summon}, on_break: {stun, vuln, vuln_time}}` | Grukk (futuro: qualquer conjurador) |
| R-D | **Sequência** | `SkillDef.effects.repeat` | `{times, gap, reaim: true, lock_victim: true, cc_breaks: true}` | Mãe-Loba (futuro: Ulgra/Durgash investida) |
| R-E | Cobertura (única) | lacaio parado `MonsterDef.cover: radius` + efeito `avalanche` | segmento chefe→alvo × círculo | Troll Rei |
| R-F | Cópia (única) | `MonsterDef.decoy: bool` | 1 golpe, sem sombra, `on_death` nuvem | Shazka |
| R-G | Muralha (única, mínima) | buff com `front_guard` + contador | `SimEntity.front_guard_bonus`, `guard_hits` | Ghar |

## 7. Tuning Knobs

Globais (novos, `data/balance.gd`), por skill os do catálogo (como o `barrage`):

| Knob | Padrão | Faixa segura | Tipo | Efeito |
|---|---|---|---|---|
| `BOSS_SIG_WARN_MIN` | 1,5 s | 1,2-2,5 | feel | aviso mínimo de qualquer assinatura (check) |
| `BOSS_MARK_TIME` | 4,0 s | 3-6 | feel | tempo da marca até cair |
| `BOSS_SOAK_MIN` | 1 | 1 | curve | divisor mínimo |
| `BOSS_CHANNEL_BREAK_PCT` | 0,06 | 0,03-0,10 | gate | quanto dano quebra o canal |
| `BOSS_CHANNEL_STAGGER` / `_VULN` | 3,0 s / 0,25 | 2-4 / 0,1-0,4 | curve | recompensa da quebra |
| `BOSS_LINGER_TICK` | 1,0 s | 0,5-1,0 | feel | tique das poças |
| `KRAGMAR_TEMPER_STEP` / `_MAX` | 0,08 / 6 | 0,05-0,12 / 4-8 | curve | punição de deixar ele na lava |
| `GHAR_WALL_CUT` | 0,9 | 0,7-1,0 | curve | corte frontal da Muralha |
| `TIDE_ISLAND_MIN` | 2 | 2-3 | gate | ilhas mínimas |
| `TROLL_COVER_MAX` | 3 | 2-4 | gate | pedras ao mesmo tempo |
| `BOT_SIG_SKILL` | 0,7 | 0,5-0,9 | feel | chance do bot acertar a leitura (Shazka; sementes fixas) |

Intervalos (18-35 s), `power` e raios ficam no dicionário de efeito da skill, com check de faixa.

## 8. Acceptance Criteria

- **AC-S1** Cada um dos 11 chefes tem exatamente 1 skill marcada `signature` no catálogo (check `_check_boss_signatures`).
- **AC-S2** Todo hazard/marca/canal de assinatura avisa ≥ `BOSS_SIG_WARN_MIN` antes do dano (check sobre os dados).
- **AC-S3** Checks unitários por regra: forma `line`/`ring`/`invert`, `follow`, divisão `soak`, quebra de canal (stun e 6%),
  `repeat` cortado por `root`, cobertura, cópia de 1 golpe, Muralha 90% de frente e 0% de costas, Têmpera só na poça.
- **AC-S4** `reset_boss` limpa marcas, canal, Têmpera, pedregulhos e cópias (check).
- **AC-S5** `boss_probe`: métricas novas por assinatura (`sig_hits`, `canal_quebrado`, `tempera_med`, `furia_med`) e os alvos de 3.x;
  alvos R8 mantidos (grupo completo de 4 ≥ 95%, sorteados 65-85%; raide 5 ≥ 90%). Recalibrar só `unit_mods`/knobs, nunca o crowd.
- **AC-S6** `sim_probe`: ≤ 5 ms/tick com Kharzun carregado (AC-36) durante Ondas da Montanha e Machado do Trono.
- **AC-S7** (experiência, playtest) Em 1 luta de cada chefe com bots, o jogador consegue dizer o nome do verbo da
  assinatura sem ler este doc; captura retida em `production/qa/evidence/` de cada aviso visto da câmera do jogo.

## 9. Riscos

- **Bots ruins na mecânica** derrubam a vitória em grupo abaixo do R8 → mitigar: bots com reação embutida por regra
  (acima), calibrar com `--comp` antes de mexer em números.
- **Excesso de chão** (barrage + assinatura) ilegível de cima → regra de 1 mecânica de chão por vez (Edge Cases).
- **Solo dos chefes de campo** (Mãe-Loba): Três Botes não pode tirar a faixa campo; `power` baixo e `root` corta.
- **Custo da sim**: marcas e anéis são poucos por chefe (≤ 9 hazards vivos); medir com `sim_probe`.
- **Escopo de arte/FX**: 7 visuais novos no chão; desenho procedural (anéis, faixas) primeiro, arte depois.

## 10. Ordem de implementação sugerida

1. **R-A Hazard v2** (formas + `invert` + `linger`) → Ulgra, Gorbash, Maré, Kragmar (4 chefes com 1 regra) + `_danger_escape` com formas.
2. **R-B Marca** → Vorgul (spread), Durgash (soak) + bots de espalhar/juntar.
3. **R-C Canal** → Grukk + bots de interromper.
4. **R-D Sequência** → Mãe-Loba (bots quase prontos).
5. Únicas, menor para maior: **R-G** Ghar → **R-F** Shazka → **R-E** Troll Rei.
6. Por chefe: check, sonda (`boss_probe --party=4 --comp=... --why`, 40 lutas), recalibração, captura de evidência.

## Decisões do usuário (2026-11-13)

- Aprovado para os 11 chefes (implementar depois do merge do WP8/balanceamento).
- **OQ-1: SOMA.** A assinatura entra **por cima** do kit atual (não substitui nenhuma skill). Recalibrar duração/vitórias no `boss_probe` depois.
- **OQ-2: por chefe**, como está no rascunho (uns desde 100%, outros na fase de 70%).
- **OQ-3:** sem resposta explícita; segue a proposta (pedregulhos intocáveis).
- **OQ-4: bots SEMPRE perfeitos** nas mecânicas (sem chance de erro proposital; Shazka: bot acha o verdadeiro sempre).
- A escala por multidão (`Balance.BOSS_CROWD_MULT`) fica como está.

## Open Questions (histórico)

- **OQ-1** A assinatura **substitui** uma skill redundante do kit (ex.: Chuva de Fogo do Vorgul, Terra Rachada do Ghar) para manter
  o chefe legível, ou **soma**? Recomendado: substituir quando a skill é uma `barrage` genérica.
- **OQ-2** Ativar desde 100% (ensina cedo) ou a partir de 70% (como as fases)? Proposta mista acima; confirmar.
- **OQ-3** Pedregulhos do Troll Rei intocáveis (proposto) ou destrutíveis (mais tensão com área, mais erro de bot)?
- **OQ-4** Bots "imperfeitos de propósito" (Shazka 70%) são desejados, ou bots sempre perfeitos?

## Implementação (2026-11-13, 6 chefes fora de Kharzun)

Feito: regras R-A (formas `line`/`ring`, `invert`, `linger`+tique, `empower`), R-B (marca `spread`/`soak`), R-C, R-D, R-E e R-G em
`core/sim/systems/boss_signatures.gd` (`BossSignatures`); avisos em `game/fx/boss_sig_view.gd`; bots em `BotBrain._sig_spot`;
checks `_check_boss_signatures`, `_check_boss_sig_rules`, `_check_boss_sig_bots`; sonda `boss_probe` linha `SIG` e `--no_sig`;
fotos `-- --sig_shot=<pasta> [--boss=<id>]`. Assinaturas: Maré Cheia, Rufar da Turba, Avalanche, Marca do Atirador, Muralha de
Escudos, Três Botes. Os 5 de Kharzun (Shazka R-F, Ulgra, Gorbash, Kragmar, Durgash) ficam para o próximo trabalho: as regras
compartilhadas que eles usam (faixas, anéis, poça com Têmpera, marca de dividir) já existem e têm check.

Desvios do texto acima (para o game-designer revisar):
- O efeito do canal chama-se `boss_channel` (a chave `channel` já é a canalização do Necromante).
- `SkillDef.boss_signature` marca a assinatura (AC-S1); `signature` já é a magia-assinatura das builds.
- Três Botes avisam 0,8 s por bote (3.6) — abaixo do `BOSS_SIG_WARN_MIN` do AC-S2; o check usa `BOSS_SIG_REPEAT_WARN_MIN` 0,8 para `repeat`.
- Pedregulhos não são entidades (lista `m["covers"]`): intocáveis por construção e sem colisão; o da Chuva de Pedras nasce no último
  círculo (o que cai em volta do chefe). `MonsterDef.cover` diz quais skills deixam pedra.
- Muralha: quem o Ghar mira (tanque ou não) fica parado de guarda, sem golpe, enquanto ela dura; parar de bater e andar fazia o chefe
  virar para o grupo e a luta passava de 36 s para 55-60 s. Os outros vão para as costas.
- Maré Cheia: quem não é tanque prefere a ilha a ≥ `BOT_SIG_ISLAND_AVOID` m do chefe (a do tanque fica embaixo dele: golpe em volta).
- 1ª assinatura: `BOSS_SIG_OPEN_DELAY` (6 s) depois do começo da luta, ou `BOSS_SIG_PHASE_DELAY` (4 s) depois da fase que a traz.
- Calibragem (boss_probe, 4 sorteados): ver `docs/DESIGN.md` "Assinaturas dos chefes" — `power` da Marca do Atirador 1,5 → 0,9 e
  `unit_mods.atk` de Maré, Troll Rei, Vorgul e Ghar ajustados para ficar na faixa com a assinatura ligada.

### Implementação — Shazka, Ulgra, Gorbash (2026-11-13)

Feito: Sombras Gêmeas (`mob_shazka_twins`, R-F `MonsterDef.decoy`, monstro `shazka_decoy`), Estouro da Matilha (`mob_ulgra_stampede`,
`barrage.shape: line`), Ondas da Montanha (`mob_gorbash_waves`, `barrage.shape: ring` com `pulses`/`pulse_gap`/`pulse_shift`/`spacing`).
Check `_check_boss_sig_kharzun`. Kragmar e Durgash seguem em outro trabalho.

Desvios do texto acima (para o game-designer revisar):
- Sombras Gêmeas é uma skill própria (fumaça de 1,5 s + cópias, recarga 24 s, desde 70%), não um acréscimo ao Sumir na Fumaça: assim
  `--no_sig` compara o kit intacto (OQ-1: soma). O Sumir na Fumaça continua no kit.
- Cópia: mesma vida que o Shazka na barra (morre com 1 golpe por regra, não por vida baixa), dano 30% (`Balance.SHAZKA_DECOY_DMG`),
  nuvem de veneno ao morrer = 0,4 + veneno 10/s 3 s, fica 4 s. Golpe direto no verdadeiro (não dano no tempo) desfaz as cópias, sem veneno.
- Sombra: a cópia não projeta sombra e fica meio transparente (`SHAZKA_DECOY_FADE`); no chão escuro da masmorra a sombra real some, então
  o aviso desenha também um disco escuro sob o verdadeiro enquanto há cópias.
- Bots sempre acham o verdadeiro (OQ-4): o alvo vira o Shazka real (`BotBrain._decoy_real`); área mata cópia de passagem.
- Ulgra não recua à borda: as 3 faixas (30 m) correm na direção dela→tanque, centradas no tanque. A "galopada" é só o desenho (setas).
- Gorbash: anéis de 2 m em 2-4, 7-9, 12-14 m; a 2ª pisada anda 2 m para fora (4-6, 9-11, 14-16); 9 anéis por série, o que cai a seguir
  fica aceso. Bots: fogem só do que cai em até `BOT_SIG_REACT` s, para o lado que fica livre por mais tempo (`BotBrain._side_escape`,
  folga `BOT_SIG_PAD`); antes disso seguem lutando (sem isso a luta passava de 37 s para 88 s).

### Implementação — Kragmar (2026-11-13)

Feito: Têmpera na Lava (`mob_kragmar_temper`, `barrage` com `on_self` + `linger` + `empower`), regra da Têmpera em
`BossSignatures._empower` (1 acúmulo a cada `KRAGMAR_TEMPER_EVERY` 2 s, cura `KRAGMAR_TEMPER_HEAL` 0,5%/s uma vez por segundo
mesmo com poças sobrepostas, perde 1 a cada `KRAGMAR_TEMPER_DECAY` 3 s fora), bots em `BotBrain._sig_spot` (`_drag_spot`),
poça com o modelo `prop_kragmar_lavapool` em `BossSigView`, anel e brasas da Têmpera sobre o chefe. Check `_check_boss_sig_kragmar`.

Desvios do texto acima (para o game-designer revisar):
- A assinatura é uma skill própria (recarga 18 s, desde 100%) e não um acréscimo às Ondas de Lava: assim `--no_sig` compara o kit
  intacto (OQ-1: soma). As Ondas de Lava continuam como eram (círculos que não ficam).
- Uma poça só, embaixo do Kragmar (não em cada círculo). Com 3 poças (1 nele + 2 nos alvos) e tique 0,25 a luta de 5 sorteados ia de
  72,5% / 24-30 s para 52,5% / 46-58 s: o dano vinha das poças nos alvos (45% do dano recebido), não da Têmpera (média 0,3-0,8).
  Tique 0,25 → 0,15. Com 1 poça: 65%, 27-28 s.
- Quem arrasta é quem o Kragmar mira (o tanque no grupo completo; num grupo sorteado sem tanque, quem tiver o aggro), como a guarda
  da Muralha do Ghar.
- Bots (todas as poças que ficam, não só a do Kragmar): saem para o ponto livre mais perto, não para outra poça, e o lugar do papel
  no grupo é empurrado para fora da poça (`BotBrain._free_near`).

### Implementação — modelos, clipes e re-sonda (2026-11-13, k-sig5)

- Muralha do Ghar: o contragolpe cai `Balance.GHAR_COUNTER_DELAY` 0,375 s depois do fim da muralha (estado `e.sig["counter"]`; o
  cérebro segura o chefe nesse tempo e os bots seguem de guarda). O `mob_ghar` repete o clipe `guard_wall` durante a muralha e toca
  `wall_counter` no contragolpe (`EntityView.IMPACT_FRAME["wall_counter"]` = 10 = 0,375 s; clipes só de monstro em `MOB_ONLY_CLIPS`).
  Modelo: só `prop_ghar_shieldwall` dos lados (`GHAR_SIDE_SHIELDS`); o escudo da frente é o do braço do modelo (`prop_ghar_towershield`
  ficou sem uso, para não mostrar dois escudos).
- Modelos de todas as assinaturas ligados em `BossSigView` (`_sig_model`/`_prop`, peças `glow_*` brilham, somem com a regra): ilha +
  anel de maré (Maré), tambor de guerra (Grukk), pedregulho (Troll), retícula/seta (Vorgul), fumaça sob as cópias (Shazka), faixas do
  estouro (Ulgra), lascas no anel aceso (Gorbash), poça de lava (Kragmar). Knobs só de apresentação em `Balance` (`GRUKK_DRUM_GAP`,
  `ULGRA_LANE_SINK`, `SHAZKA_SMOKE_ALPHA`, `GHAR_SHIELDWALL_SCALE`).
- Re-sonda depois da regra "bots saem de toda poça que fica" (Kragmar): Vorgul 60% (4 sorteados, 24/40; na borda da faixa, próximo
  botão `unit_mods.atk` 0,9 → 0,85), Shazka 67,5% (5 sorteados, 27/40).
- Final (faixa AC-S5 60-80%, grupo sorteado): Maré 62,5 · Grukk 75 · Troll Rei 67,5 · Vorgul 60 · Ghar 80 (4 sorteados) · Shazka 67,5 ·
  Ulgra 70 · Gorbash 70 · Kragmar 65 (5 sorteados); Mãe-Loba solo 95%, trio 100%; completos 20/20. Fora do Ato II: Coração da Pedreira
  70% (atk/matk 50 → 66). Durgash: ver a nota dele.

### Implementação — Durgash (2026-11-13)

Feito: Machado do Trono (`mob_durgash_throneaxe`, desde 100%, soma ao kit; `mark.mode: soak`, `no_tank`), números em
`Balance.DURGASH_AXE_*` (power 2,0, raio 4,0 m, 5 s, recarga 34 s). Morte pelo golpe dividido conta em `sig_stats.soak_kills`
(sonda: `dividir_n/marca`, `dividir_mortes/marca`). Bots (`BotBrain.soak_spot`/`_soak_move`/`_soak_helper`): o tanque segura o
chefe; vão dividir só os `BOT_SIG_SOAK_HELPERS` (2) personagens mais perto do círculo, a até 15 m (quem já está dentro conta), e
partem quando o tempo que falta mal dá para chegar (distância até a borda de dentro ÷ velocidade + `BOT_SIG_SOAK_MARGIN` 1,2 s),
passando na frente da cura; dentro, ficam (a cura não os tira de lá, `soak_pin`); caiu, voltam ao estandarte/vaga/cura. O marcado
segue no que fazia e só para nos últimos `BOT_SIG_SOAK_VICTIM_HOLD` 2,5 s. Visual: círculo dourado com 3 vagas e anel que fecha;
o `prop_durgash_throneaxe` gira sobre o círculo e desce até cravar quando cai. Som: `sig_warn` + `war_drum` no aviso, `troll_slam`
no impacto. Check `_check_boss_sig_durgash`; sonda `boss_probe -- --sig_tune=<skill>:power=X,cooldown=Y,radius=Z` varre os botões
sem editar o Balance. Foto: `production/qa/evidence/boss-signatures/boss_durgash.png`.

Desvios do texto acima (para o game-designer revisar):
- **power 6,0 → 2,0, recarga 26 → 34 s, raio 3,5 → 4,0 m.** Com 6,0 os 5 sorteados iam de 65% (sem assinatura) a 15% e o completo
  de 5 a 85% com 115 s de luta (berserk aos 128 s), mesmo com 3,6-4,1 dentro por machado (0,8-1,2 morte por machado). 3,0 e 2,5 davam
  35%: o golpe dividido quase não mata (0,03 por machado), mas deixa o grupo baixo para o resto do kit. Com 2,0 "sozinho ~letal" não
  vale (1040 antes de DEF contra ~4-6 mil de vida): a pressão real da mecânica é o tempo de juntar, não o golpe.
- **5 sorteados 57,5% (46/80), abaixo da faixa 60-80% em 2,5 pontos.** Nenhum botão da assinatura sobe isso: power 1,5 (0 morte por
  machado), recarga 40 s e raio 4,5 m deram 50-55% em 20-40 lutas; o custo (~8 pontos sobre os 65% sem assinatura) é juntar o grupo,
  não o dano. Ganhou-se com a IA (só 2 ajudantes, marcado só para no fim). Próximo passo, se o autor quiser a faixa: `unit_mods` do
  Durgash (fora do que esta tarefa podia mexer) ou aceitar 57,5%.
- Bots: só os 2 mais perto vão (não "todo bot não-tanque a ≤ 15 m"), partem na hora (não quando a marca aparece) e o marcado só para
  no fim: ir todos e na hora perdia o estandarte, a cura e o dano por 5 s a cada machado.
- Estandartes: já têm modelo próprio por clã (`mob_clan_banner_wolf/stone/forge`); o `prop_horde_warbanner_sig` não foi ligado a eles.
