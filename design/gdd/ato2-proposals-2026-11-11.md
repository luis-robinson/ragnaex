# Ato II — Propostas (2026-11-11): Fusões dos conjuntos híbridos e Ascensão do Caçador

> **Histórico (2026-11-16):** 16 de 24 Fusões substituídas pelo Ápice (`design/gdd/apice-sets.md`): saíram P1, P2, B1-B3, Bi1, Bi2,
> D1-D3, R1-R3, A1-A3; ficaram P3, Bi3, E1-E3, N1-N3. As fichas removidas ficam aqui só como registro (o código e os números foram apagados).

> **Decisões do autor (2026-11-11)**: Caçador = **A. Falcoeiro** (aprovado); Fusão **substitui** o 5 peças do conjunto híbrido e tem **duas faces** quando o par usa armas diferentes (aprovado); Atirador = **1 torreta**, refino 40/45 = +4 s e −20% de recarga (aprovado). Pendente: D3 face Xamã (decidir quando o Druida entrar), revisão fina das 24 fichas pelo autor.

> **Status:** proposta para o autor revisar (systems-designer). **Não altera** `design/gdd/ato2-horda.md`; o que for aprovado
> entra lá depois (R6.1, R7.1, F5, F10). Fontes lidas: R6, R6.1, R7, R7.1, F5, F10 do GDD; `classes_catalog.gd` (as 24 builds);
> `gear_catalog.gd` (`set_bonuses`, padrão `SET_FAVOR_*`); `Balance.SET_*`/`LEGEND_NUMBERS`; `legend_effects.gd` (tipos de efeito);
> `class_talents_catalog.gd` (ganchos). Todo número marcado **(H)** é hipótese a calibrar com `boss_probe --comp`.

---

## 1. As 24 Fusões (bônus de 5 peças dos conjuntos híbridos)

### 1.1 Regras comuns

1. **Onde entra.** Pela R7.1 o conjunto híbrido A+B dá: 2 peças = 2 peças de A; 3 peças = 3 peças de B; 4 peças = metade do
   bônus de 4 peças de A e de B; **5 peças = Fusão**. A Fusão **substitui** o bônus de 5 peças normal (`SET_5PC_STAT_PCT` +
   `SET_5PC_CDR`), não soma com ele. Por isso o orçamento dela é o do 5 peças normal (F-FUS2), não um ganho novo.
2. **Duas faces quando as armas diferem.** A R7.1 deixa o híbrido trocar de lado trocando só a arma. Então toda Fusão de par com
   armas diferentes tem uma **face A** (vale com a arma de A) e uma **face B** (com a arma de B), e cada face funciona sozinha —
   os bots não trocam de arma no meio da luta, então nenhuma face pode depender da outra arma. Pares com a mesma arma
   (Elementalista, Necromante, Templário+Guardião, Punhos+Gêmeos, Batalha+Sacerdote) têm uma face só.
3. **Efeito lendário emprestado.** Quando a Fusão usa um tipo de efeito de arma lendária (Penitência, Ferida Aberta, Frenesi,
   veneno, Mão que Cura, Égide...), ela traz **os próprios números** (`Balance.FUSION_NUMBERS`), mais fracos que os da arma
   lendária. Se a pessoa também usa a arma lendária do mesmo tipo, vale **o maior** dos dois, nunca a soma.
4. **Elemental e companheiro contam.** No Elementalista, os ataques do elemental contam como do mago para a Fusão **se a forma
   dele for de um dos dois elementos do par** (liga com a ascensão R6.1). No Ranger, "companheiro" = o bicho do Caçador, seja qual
   for a ascensão escolhida na Parte 2 (lince, falcão...): nenhuma Fusão depende do Tigre Dente-de-Sabre.
5. **Forma dos dados.** Um campo novo `SetDef.fusion = {"id": "<a>+<b>"}` e um sistema estático `FusionEffects`
   (`core/sim/systems/`) que chama as funções que já existem. Os números ficam em `Balance.FUSION_NUMBERS[id] = {chave: [v35,
   passo]}`, no mesmo formato `[base, por tier]` de `LEGEND_NUMBERS`. Isso é **infraestrutura** e não conta como gancho novo.
6. **O que conta como gancho novo:** um ponto da sim que hoje **nenhum** efeito de conjunto, arma lendária ou talento escuta.
   Gatilhos que já existem e são reaproveitados: golpe que acerta (`legend_on_hit`), ser atingido (`legend_weapon`,
   `cast_when_hit`), abate (`legend_on_kill`, `on_kill` com `minions`), bloqueio (cargas de Juramento/Graça), esquiva
   (`riposte`/`fist_counter`), sair da furtividade (`ambush_mult`), lançar skill (`skill_mods` com `effects`), Bravata
   (`gain_bravado`), limites (`trap_max`, `summon_extra`), auras (`aura`, `regen` com `aura`), lançar de graça (`legend_cast`).
   **Ganchos novos nesta proposta: 3 de 6 permitidos** (tabela 1.4).
7. **Bots.** Pela R7.1 o bot escolhe o híbrido com a build dele e a outra build que a teia dele mais comprou. Cada Fusão diz abaixo
   se pede uma regra nova no `BotBrain` ou se acontece sozinha (passiva). Alvo, igual ao da R6: um bot com a Fusão a dispara ao
   menos 1× em 60 s de luta contra chefe.

### 1.2 Fórmulas

#### F-FUS1. Número da Fusão por tier
`valor(i) = v35 + passo × (i − 6)`, com `i` = índice do tier lendário (6 = nível 35, 7 = 40, 8 = 45).

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| i | int | 6–8 | índice do tier (`LEGENDARY_LEVELS`) |
| v35 | float | por Fusão | valor no tier 35 |
| passo | float | ≈ 5–10% de v35 (negativo em tempos de recarga) | crescimento por tier — mesmo espírito da F10 (bônus percentuais acima do índice 5 crescem pela metade) |
| valor | float | v35 … v35 + 2 × passo | número usado pela sim |

**Faixa de saída:** limitada pelos dois extremos acima (3 tiers). Nenhuma Fusão chega a zero ou negativo: recargas têm passo
negativo pequeno (no máx. −10% de v35 por tier), então o mínimo é 80% de v35.
**Exemplo:** Juramento Rubro, `oath_icd` = [1,5, −0,15] → 35: **1,5 s**, 40: **1,35 s**, 45: **1,2 s**.

#### F-FUS2. Orçamento da Fusão
`G_fus = T4 ÷ T_fus − 1` e `G_5n = T4 ÷ T_5n − 1`; **critério:** `|G_fus − G_5n| ≤ FUSION_TOL`.

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| T4 | float (s) | 60–180 | tempo do grupo de 4 (`boss_probe --comp`) com 4 peças do híbrido |
| T_fus | float (s) | < T4 | mesmo grupo, 5 peças com a Fusão |
| T_5n | float (s) | < T4 | mesmo grupo, 5 peças com o bônus normal (stat% + recarga) — referência |
| G_5n | float | estimado 0,06–0,09 **(H)** | ganho do 5 peças normal (17–19% de stat e 21–23% de recarga, F10) |
| G_fus | float | alvo 0,06–0,10 (35) · teto 0,12 (45) | ganho da Fusão |
| FUSION_TOL | float | 0,02 | tolerância (mesma ideia dos ±3 p.p. da F5) |

**Faixa de saída:** `G_fus` é limitado por cima em **0,12** em qualquer tier (acima disso a Fusão vira obrigatória e as builds
puras somem — o oposto da decisão "coexistem"). Fusões de **utilidade** (cura, proteção, controle) são medidas como na F5: sob
pressão (`--dmg=6`), ganho = queda relativa de mortes por luta, alvo 6–10%.
**Exemplo:** grupo com Gêmeos+Executor mata o chefe em 100 s com 4 peças, 92,6 s com o 5 peças normal (`G_5n` = 0,080) e 91,7 s
com a Fusão (`G_fus` = 0,091) → diferença 0,011 ≤ 0,02, **dentro**.
**Passo 0 da calibragem:** medir `G_5n` das 24 builds antes de qualquer Fusão (hoje é estimado, nunca foi medido).

#### F-FUS3. Estimativa de papel (usada nas fichas abaixo)
`G_est = u × m × s`

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| u | float | 0–1 | fração do tempo de luta em que o efeito está ligado (uptime) |
| m | float | 0–1+ | tamanho do efeito quando ligado (ex.: +40% = 0,4) |
| s | float | 0–1 | parte do dano da build que o efeito toca |
| G_est | float | 0–0,12 | ganho estimado; só serve para escolher v35 antes do probe |

**Faixa de saída:** 0 (efeito nunca liga) até `m` (efeito sempre ligado em todo o dano). Só é usada para chutar v35; a verdade é
a F-FUS2. **Exemplo:** +40% (m) na skill sagrada que é 20% do dano (s), ligado 100% das vezes que ela sai (u = 1) → **0,08**.

### 1.3 As 24 Fusões

Formato: **Nome** (par) · Regra · Números `[v35, passo]` (F-FUS1) · Ganho esperado (F-FUS3) · Gancho · Bots.

#### Paladino (Guardião = espada/maça + escudo, tanque, Juramento · Cruzado = 2 mãos, Julgamento/atordoar · Templário = espada + escudo, INT, Penitência)

**P1. Juramento Rubro** (Guardião + Cruzado)
- *Face 2 mãos:* cada golpe direto (básico ou skill de 1–2 alvos) dá **1 carga de Juramento** (no máx. 1 a cada `oath_icd`). Skill
  sagrada que consome **3+ cargas** **provoca por `taunt` s** quem ela acerta — o Cruzado vira tanque reserva.
- *Face escudo:* com Juramento cheio (5), o bloqueio ganha o Julgamento: `stun_ch`% de atordoar o atacante por 0,8 s (ICD 6 s,
  regra de controle em chefe vale).
- Números: `oath_icd` [1,5, −0,15] s · `taunt` [2,0, 0,25] s · `stun_ch` [12, 1,5] %. Poder por carga = `SHIELD_OATH_POWER` (0,08, sem mudar).
- Ganho: face 2 mãos ≈ 5 cargas a cada ~7,5 s → skill sagrada +40% (m) × ~20% do dano (s) = **~0,08**; face escudo: utilidade
  (controle no tanque).
- Gancho: **reuso** — cargas de Juramento (`shield_charge: oath`), `legend_on_hit`, bloqueio, efeito `stun`/`taunt`.
- Bots: Cruzado com 3+ cargas usa Onda Sagrada no chefe quando o chefe está batendo em alguém que **não** é o tanque (regra de
  "tirar" que já existe na IA de grupo). Guardião: nada novo.

**P2. Sentença Ardente** (Cruzado + Templário)
- *Face 2 mãos:* golpes diretos põem **Penitência** no alvo (1 carga; **2** se o alvo está atordoado, preso ou lento). Com 5
  cargas a Penitência explode: `pen_pct`% do ATK em 2,5 m (regra atual de `penance_hit`).
- *Face espada + escudo:* a Penitência que explode **atordoa o alvo principal** por `pen_stun` s (ICD 8 s).
- Números: `pen_pct` [80, 6] % (a arma lendária do Templário dá 120+24/tier; vale o maior) · `pen_stun` [0,6, 0,05] s · carga no
  máx. 1 a cada 0,8 s por alvo (segura a velocidade de ataque).
- Ganho: explosão a cada ~4,5 s = 0,8 ATK ÷ 4,5 s ≈ 0,18 ATK/s sobre ~2 ATK/s do Cruzado → **~0,08** em alvo único, mais em
  bando; face Templário: utilidade + ~0,03.
- Gancho: **reuso** — `penance_hit` com números da Fusão, condição de alvo (`Combat.is_chilled`, atordoado/preso), `stun`.
- Bots: skills que deixam lento/prendem sobem 1 posição na prioridade do bot com este conjunto (preparam as cargas duplas).

**P3. Égide Ardente** (Templário + Guardião — os dois de escudo, uma face)
- Bloquear põe **1 carga de Penitência no atacante** (ICD 1 s). A Penitência que explode dá **2 cargas de Juramento** ao dono.
  Laço: bloqueio → Penitência → explosão → Juramento → skill sagrada mais forte.
- Números: `pen_pct` [80, 6] % · `block_icd` 1,0 s · `oath_gain` 2 (fixo).
- Ganho: tanque bloqueando a cada ~1,5 s → explosão a cada ~7 s; dano do tanque +10–15% (pouco no total do grupo, ~0,03); o
  Templário (mais ativo no bloqueio quando segura aggro) ~0,06. Medir como **utilidade + dano**.
- Gancho: **reuso** — bloqueio (onde hoje nasce o Juramento), `penance_hit`.
- Bots: nenhuma regra nova (bloquear já é o comportamento do tanque).

#### Berserker (Gêmeos = machado + machado, Frenesi · Executor = machado 2 mãos, execução · Punhos = garras, esquiva/contra-ataque)

**B1. Carrasco Frenético** (Gêmeos + Executor)
- Golpe direto dá **1 Frenesi** (máx. 5, +`frenzy`% de velocidade de ataque por carga, 4 s). O **limiar de execução** da Fusão
  sobe com o Frenesi: `30% + exec_step × cargas` (até 40%); abaixo dele os golpes dão +`exec_dmg`% de dano. Vale nas duas faces
  (dois machados, machado de 2 mãos ou Empunhadura de Titã).
- Números: `frenzy` [1,6, 0,2] %/carga · `exec_step` 2 p.p. (fixo) · `exec_dmg` [20, 2] %.
- Ganho: +8% de velocidade de ataque com ~90% de uptime ≈ 0,07; execução: +10% da vida do chefe na janela × 20% ≈ 0,02 →
  **~0,09**. Com a arma lendária do Executor, o limiar maior **não** se aplica ao Carrasco da arma (só ao bônus da Fusão).
- Gancho: **reuso** — tipos `frenzy` e `execute` (`legend_power`).
- Bots: a skill de execução é usada abaixo do **limiar atual** da Fusão (o bot lê o limiar em vez de 30% fixo).

**B2. Peso do Titã** (Executor + Punhos)
- Cada **crítico ou esquiva** dá 1 carga de **Peso** (máx. 3, no máx. 1 a cada 0,5 s). A próxima **skill** de golpe consome
  todas: +`weight`% de dano por carga e empurra 1,5 m (chefe não é empurrado).
- *Face machado 2 mãos:* +`eva`% de esquiva e o **Punho Vingativo** (contra-ataque ao esquivar) com o machado, a `counter`% do ATK.
- *Face garras:* só a regra comum (as garras já têm o contra-ataque).
- Números: `weight` [12, 1] %/carga · `eva` [6, 1] % · `counter` [25, 3] % do ATK.
- Ganho: ~1,1 carga por skill (críticos ~25%, ~1,5 golpe/s, skill a cada ~3 s) → +13% em ~40% do dano ≈ **0,05** + sobrevivência
  (esquiva) ≈ **0,07** no total.
- Gancho: **reuso** — `legend_on_hit` (flag de crítico), esquiva (`fist_counter`), `stats`.
- Bots: passiva, nenhuma regra nova.
- Nota de grupo: em luta de chefe o DPS quase não é atacado; por isso o gatilho principal é o **crítico**, não a esquiva.

**B3. Turbilhão Feroz** (Punhos + Gêmeos — duas armas, uma face)
- Cada **crítico ou esquiva** dá **2 Frenesi** (máx. 5). Com Frenesi cheio: +`eva2`% de esquiva e contra-ataque ao esquivar a
  `counter`% do ATK (ICD 1 s). Laço positivo crítico → Frenesi → velocidade → mais críticos, **travado** por: Frenesi máx. 5,
  `EVASION_CAP` 45%, ICD do contra-ataque.
- Números: `frenzy` [1,6, 0,2] %/carga · `eva2` [6, 1] % · `counter` [25, 3] %.
- Ganho: +8% de velocidade com ~95% de uptime ≈ **0,08** + sobrevivência. **Risco:** é o laço mais forte das 24; medir o uptime de
  Frenesi cheio no `combat_probe` (alvo ≤ 95%).
- Gancho: **reuso** — `frenzy`, `fist_counter`, `stats`.
- Bots: passiva. Sem sinergia extra com Glória (Modo Gladiador) para não somar com a F5.

#### Bispo (Sacerdote = maça + escudo, cura, Égide/Graça · Iluminado = cetro, INT, Radiância, Castigo · Batalha = maça + escudo, Mão que Cura)

**Bi1. Luz que Julga** (Sacerdote + Iluminado)
- A cura que passa do HP máximo do aliado (**sobrecura**) vira **dano sagrado** no inimigo mais perto desse aliado (até 8 m):
  `ovh`% da sobrecura, com teto de `ovh_cap` × MATK por segundo. A cura da Radiância também conta. **O dano que nasce daqui não
  gera Radiância** (senão o laço dano → cura → sobrecura → dano não fecha).
- Números: `ovh` [40, 5] % · `ovh_cap` [1,0, 0,1] × MATK/s.
- Ganho: em grupo a sobrecura costuma ser 20–40% da cura; o Sacerdote ganha dano real, o grupo ganha ~0,03–0,05 em tempo. Medir
  como **dano + utilidade**.
- Gancho: **NOVO (1/3)** — evento de sobrecura (hoje a cura excedente se perde sem aviso).
- Bots: nenhuma regra nova; **não** induzir o bot a curar à toa (gasta MP; a sobrecura acontece sozinha).

**Bi2. Martelo da Aurora** (Iluminado + Batalha)
- Golpe de arma (básico de maça ou de cetro) dá **1 Fé** (máx. 5, 6 s): +`faith`% de Radiância por Fé (dentro de
  `RADIANCE_CAP`). Magia sagrada (Castigo, Martelo, Martelo Divino) **consome as Fés** e cura o aliado mais ferido em `mend`% do
  dano por Fé (a Mão que Cura do Clérigo de Batalha nas magias).
- Números: `faith` [2,0, 0,2] % · `mend` [3,0, 0,3] %/Fé (até 15–18% do dano da magia).
- Ganho: híbrido corpo a corpo/magia com cura; utilidade sob pressão + ~0,04 de dano.
- Gancho: **reuso** — tipo `mend`, buff em pilha (padrão do `frenzy`), stat `radiance`.
- Bots: Batalha com 5 Fés e um aliado abaixo de 60% lança a magia sagrada no alvo (em vez de seguir no básico).

**Bi3. Graça em Combate** (Batalha + Sacerdote — maça + escudo, uma face)
- A cada `grace_hits` golpes de maça, a **Graça** dispara como se tivesse bloqueado (cura 5% do HP do aliado mais ferido, regra
  atual, respeita `SHIELD_GRACE_CD`) e o aliado curado ganha a **Égide** (absorve `ward`% do HP máx dele, 4 s).
- Números: `grace_hits` 3 (fixo) · `ward` [6, 0,6] % do HP do aliado · `SHIELD_GRACE_CD` 4 s sem mudar (a Fusão não acelera a recarga).
- Ganho: Graça a cada 4 s garantida mesmo sem ser atacado (em grupo o Bispo quase não bloqueia) + escudos; **utilidade** (alvo
  −6–10% de mortes).
- Gancho: **reuso** — Graça (`shield_charge: grace`), tipo `ward`, `legend_on_hit`.
- Bots: o Batalha com este conjunto fica no corpo a corpo mesmo quando há cura a fazer (a cura vem do golpe).

#### Druida (Urso = maça 2 mãos, tanque · Lobo = duas maças, sangramento · Xamã = cajado, Fogo Lunar)

**D1. Bramido da Matilha** (Urso + Lobo)
- *Face maça 2 mãos:* **Urro da Mata** (provocar em área) chama **2 Lobos Espirituais** por `wolf_t` s e dá **Frenesi**
  (`dru_frenzy`) ao grupo a 10 m com `fr_str`% da força.
- *Face duas maças:* **Frenesi** lançado provoca por 1,5 s os inimigos a 5 m (o Lobo segura os lacaios que fogem do tanque).
- Números: `wolf_t` [8, 1] s · `fr_str` [40, 4] % · provocação 1,5 s (fixo).
- Ganho: Frenesi do grupo ~0,04 + lobos ~0,02; face Lobo: utilidade (tirar lacaio). Medir sob pressão.
- Gancho: **reuso** — `skill_mods` com `effects` (`summon`, `buff`, `taunt` já estão em `EFFECT_KEYS`).
- Bots: Urso usa Urro na abertura da luta de chefe e com 2+ lacaios; Lobo usa Frenesi quando um lacaio bate no curandeiro (regra
  de "tirar lacaio" da IA de grupo).

**D2. Lua Caçadora** (Lobo + Xamã)
- *Face duas maças:* golpes na forma de lobo têm `moon_ch`% de lançar **Fogo Lunar** (a assinatura do Xamã) a 60% do poder (ICD
  `LEG_CAST_ICD`).
- *Face cajado:* Fogo Lunar em alvo que **sangra** (sangramento de qualquer membro do grupo) explode em 2,5 m com `burst`% do dano.
- Números: `moon_ch` [12, 1] % · `burst` [50, 5] %.
- Ganho: face Lobo ~0,06; face Xamã ~0,07 em grupo com sangradores (Lobo, Lanceiro, Gêmeos), ~0,03 sem eles.
- Gancho: **reuso** — `cast_on_basic`/`legend_cast`, condição de debuff `bleed` no alvo.
- Bots: Xamã com o conjunto prefere Fogo Lunar em alvos que sangram.

**D3. Casca Partilhada** (Xamã + Urso)
- *Face maça 2 mãos:* **Casca Viva** (Pele de Carvalho ao ser atingido) também cobre o **aliado mais ferido a 12 m**, com ICD menor
  (`bark_icd`).
- *Face cajado:* magias em alvo **preso** (Enredar, raízes do Ent da ascensão) causam +`root_dmg`%.
- Números: `bark_icd` [16, −1] s (a arma lendária usa 20 s) · `root_dmg` [15, 1,5] %.
- Ganho: face Urso: utilidade (alvo −6–10% de mortes); face Xamã ~0,05 em bandos (**chefes imunes a prender** — conferir; se
  forem, a face Xamã vale só no lixo e precisa de alternativa: ver 1.8).
- Gancho: **reuso** — `cast_when_hit`, condição de alvo preso.
- Bots: Xamã lança Enredar antes das magias de área em bandos.

#### Ranger (Caçador = arco + companheiro · Atirador = rifle, armadilhas, torreta da ascensão · Lanceiro = lança, Ferida Aberta)

> Ideias do autor encaixadas aqui: **"jogadores perto da torreta recuperam HP"** → R2; **"um conjunto que permite uma segunda
> torreta"** → R1. Consequência: a ascensão do Atirador passa a ter **1 torreta ativa** (a R6.1 diz "até 2") e o refino
> "torreta dupla" de 40/45 precisa de outro efeito — decisão do autor em 1.8.

**R1. Posto de Caça** (Caçador + Atirador)
- *Face rifle:* **+1 torreta ativa** (a 2ª com `t2_pwr`% do poder); as torretas atiram primeiro no alvo **preso, retardado ou
  marcado** (armadilhas e marcas ganham uso).
- *Face arco:* **Ataque da Fera** arma de graça uma **Armadilha de Gelo** (`ran_frost_trap`, que já aceita arco) sob o alvo (conta no
  limite de armadilhas); o companheiro causa +`trap_taken`% em alvo dentro de armadilha sua.
- Números: `t2_pwr` [60, 5] % · `trap_taken` [8, 1] % · a armadilha sai no ritmo da recarga do Ataque da Fera (8 s).
- Ganho: face rifle ≈ 2ª torreta a 60% de uma fatia de ~10–12% do dano → **~0,07**; face arco ~0,04 + controle (lentidão em área).
- Gancho: **reuso** — limite por chave no padrão `trap_max` (`turret_max`), `legend_cast`, condição de alvo.
- Bots: Atirador põe a 2ª torreta quando a 1ª já está no chefe; Caçador abre a luta com Ataque da Fera no chefe.

**R2. Trincheira** (Atirador + Lanceiro) — *ideia do autor*
- *Face rifle:* aliados a `post_r` m de uma torreta sua **regeneram `regen`% do HP por segundo** (posto avançado).
- *Face lança:* o **Dardo de Caça** lançado pelo jogador (não pela assinatura) **crava no chão** onde para e vira uma **Estaca**
  (6 s, uma por vez) com a mesma regeneração — o Lanceiro monta o posto na linha de frente.
- Números: `regen` [0,8, 0,1] %/s (compare: talento Luz Final = 1%/s a 15 m) · `post_r` 5 m · torreta e estaca usam o mesmo id
  de efeito: ficar perto de duas **não soma**.
- Ganho: **utilidade de grupo** (alvo −6–10% de mortes sob `--dmg=6`); dano ~0.
- Gancho: **NOVO (2/3)** — aura/regeneração presa a um objeto colocado no chão (torreta, estaca), não ao dono.
- Bots: Atirador põe a torreta **onde o tanque está** (não no chefe); membros do grupo abaixo de 60% entram no raio do posto —
  **reaproveita a regra de posição da Barreira Sagrada** (R6.1, Bispo: "entram e ficam na cúpula").

**R3. Caça em Dupla** (Lanceiro + Caçador)
- *Face lança:* golpes em alvo **retardado ou preso** abrem **2 Feridas Abertas** (em vez de 1).
- *Face arco:* os golpes do **companheiro** abrem Feridas Abertas suas (1 a cada 1,5 s) e o companheiro causa +`pack`% de dano
  por Ferida no alvo.
- Números (Ferida da Fusão; a arma lendária do Lanceiro vale se for maior): `pct` [2,0, 0,4] %/Ferida · `max` 5 · `bleed` [6, 1] %
  do ATK/s · `pack` [3, 0,3] %/Ferida.
- Ganho: face lança ~0,07 (o Lanceiro já tem lentidões: Dardo, Lança Giratória, Marca do Predador); face arco ~0,06.
- Gancho: **NOVO (3/3)** — golpe de **invocação** como gatilho (`summon_on_hit`; hoje `legend_on_hit` só vale para personagem).
  O mesmo gancho serve a N3.
- Bots: passiva; Lanceiro com o conjunto abre com Dardo de Caça (deixa lento) antes das estocadas.

#### Assassino (Lâminas = adagas, veneno, furtividade · Duelista = duas espadas, Riposte · Corsário = espada + pistola, Bravata)

**A1. Passo Fantasma** (Lâminas + Duelista) — *exemplo do autor, ajustado ao grupo*
- Sair de uma skill de **avanço** (Avanço do Duelista, Passo das Sombras, dash) **ou esquivar** deixa a próxima facada **furtiva**
  (dano de emboscada `AMBUSH_MULT` e o crítico de costas se estiver atrás), por até 3 s. ICD `ghost_icd`.
- Números: `ghost_icd` [5,0, −0,25] s · usa o `ambush_mult` da pessoa (o talento Emboscada 2,0× vale; ver teto em 1.5).
- Ganho: 1 golpe ×1,6 a cada ~5 s, golpe a cada ~0,5 s → +6% + crítico de costas ≈ **0,07**.
- Gancho: **reuso** — `skill_mods` põe um buff nas skills de avanço; o golpe lê o buff como lê a furtividade (`ambush_mult`); esquiva.
- Bots: usam o avanço para ir para as costas do chefe (arco de `BACKSTAB_ARC`) e batem em seguida.
- Por que mudou: em luta de chefe o DPS quase nunca é atacado, então só a esquiva quase não dispararia.

**A2. Duelo de Pólvora** (Duelista + Corsário)
- Crítico com espada dá **1 Bravata** (ICD 1 s; regra da Bravata atual, máx. 5).
- *Face pistola:* Bravata cheia → o próximo golpe de espada **dispara a pistola de graça** a `shot`% do ATK (`spare_shot`) e
  consome as Bravatas.
- *Face duas espadas:* Bravata cheia → **Foco do Duelista** (`ass_focus`) a `focus`% da força por 6 s e consome.
- Números: `shot` [45, 4] % · `focus` [60, 5] %.
- Ganho: ~0,07 nas duas faces.
- Gancho: **reuso** — `gain_bravado`, `spare_shot`, `buff`.
- Bots: passiva.

**A3. Pólvora Envenenada** (Corsário + Lâminas)
- *Face pistola:* tiros de pistola aplicam o **Veneno Letal** (`poison` % do ATK/s, 4 s); cada veneno seu no alvo dá +`per`% ao
  próximo tiro (máx. 3).
- *Face adagas:* Dardo Venenoso e Leque de Facas dão **1 Bravata** por alvo envenenado atingido (máx. 2 por lançamento).
- Números: `poison` [8, 0,8] % · `per` [6, 0,6] %.
- Ganho: face pistola ~0,07; face adagas ~0,05 (Bravata dá menos às adagas).
- Gancho: **reuso** — tipo `poison`, `spare_shot`, `gain_bravado`.
- Bots: passiva.

#### Elementalista (cajado nos três; Fusão vale para o elemental na forma de um dos dois elementos)

> Os conjuntos "favor" (`SET_FAVOR_*`) já dão % do 2º elemento; as Fusões abaixo mexem na **interação** entre elementos, não
> em mais % de elemento.

**E1. Vapor** (Fogo + Gelo) — *exemplo do autor: "gelo estilhaça as queimaduras"*
- Skill de gelo em alvo **queimando** apaga a queimadura e causa **na hora** `quench`% do dano que ela ainda faria (vapor, área
  2 m) e deixa o alvo 30% mais lento por 2 s (a próxima skill de gelo estilhaça: `FROST_SHATTER_MULT`).
- **Também (decisão do autor, 2026-11-12):** golpe de **fogo** em alvo retardado/gelado (`Combat.is_chilled`: lentidão, raiz ou atordoado) que queima com o seu fogo faz o mesmo Vapor, com recarga `FUSION_VAPOR_ICD` 2 s (o Vapor retarda: sem a recarga ele se encadearia sozinho); o de gelo segue sem recarga.
- Números: `quench` [150, 10] % na proposta; calibrado **[670, 30]** (ver §1.9).
- Ganho: queimadura ~20% do dano, consumida a ~150% do restante (+25% dela) ≈ 0,05 + estilhaço habilitado ≈ 0,03 → **~0,08**.
- Gancho: **reuso** — queimadura (`dot` de fogo), `Combat.frost_mult`, condição de alvo.
- Bots: com o conjunto, a skill de gelo sobe na prioridade quando o alvo está queimando.

**E2. Supercondutor** (Gelo + Raio)
- Raio em alvo **retardado/congelado** salta para **+1 alvo** e não perde dano entre alvos retardados; skill de gelo em alvo
  **eletrificado** (acertado por raio há ≤ 2 s) recebe +`super`% por cima do estilhaço.
- Números: `super` [10, 1] %.
- Ganho: ~0,07 (mais em bandos).
- Gancho: **reuso** — `max_targets` da corrente (padrão do talento Corrente Longa), condição de alvo.
- Bots: Corrente Elétrica sobe na prioridade em bando retardado.

**E3. Plasma** (Raio + Fogo)
- Raio que acerta alvo **queimando** espalha a queimadura para cada alvo do salto (`spread`% do dano por segundo, tempo restante);
  queimadura em alvo eletrificado causa +`plasma`%.
- Números: `spread` [60, 5] % · `plasma` [15, 1,5] %.
- Ganho: bando ~0,10; chefe sozinho ~0,04 (só a 2ª parte). **Risco:** fraca contra chefe sozinho; o teste de orçamento é em luta
  de chefe com lacaios (o padrão do `boss_probe`).
- Gancho: **reuso** — queimadura, corrente.
- Bots: Corrente Elétrica logo depois de Bola de Fogo no mesmo alvo.

#### Necromante (foice nos três · Invocador = exército · Ceifador = foice corpo a corpo, Ceifa · Sombras = maldições, Praga)

**N1. Ceifa Partilhada** (Invocador + Ceifador)
- Abates das **invocações** curam você como a Ceifa (`reap`% do HP máx); cada golpe de foice cura a **invocação mais ferida** a 13 m
  em `mend`% do dano.
- Números: `reap` [3, 0,3] % · `mend` [20, 2] %.
- Ganho: invocações vivem mais (menos tempo reinvocando) ≈ 0,06 + sobrevivência do mago. Diferente do refino 40 do Ceifador
  ("invocações batem junto com a foice"): aqui é sustento, não ataque.
- Gancho: **reuso** — `on_kill` com `minions: true` (já existe no talento Colheita), tipo `mend` restrito a invocações.
- Bots: Ceifador com o conjunto luta no alvo das próprias invocações (fica junto do exército).

**N2. Colheita da Praga** (Ceifador + Sombras)
- Cada **maldição sua** no alvo dá à foice +`curse_dmg`% de dano e +`curse_ls`% de roubo de vida (máx. 3 maldições); alvo
  amaldiçoado que morre dispara **Explosão de Cadáver** de graça a `ce`%.
- Números: `curse_dmg` [4, 0,4] % · `curse_ls` [2, 0,2] % · `ce` [60, 5] %.
- Ganho: 3 maldições com ~70% de uptime no chefe → +12% × 0,7 ≈ **0,08**.
- Gancho: **reuso** — contagem de debuffs no alvo (padrão `wounds`), `legend_on_kill`, `legend_cast`.
- Bots: amaldiçoam o chefe antes dos golpes de foice (maldições sobem na prioridade).

**N3. Pestilência Viva** (Sombras + Invocador)
- Invocações aplicam **Agonia** (`nec_curse_agony`) ao acertar, a 50% da força (1 por alvo a cada `agony_icd` s); cada maldição no
  alvo dá às invocações +`minion_curse`% de dano (máx. 3).
- Números: `agony_icd` [8, −0,5] s · `minion_curse` [5, 0,5] %.
- Ganho: ~0,07.
- Gancho: **NOVO (3/3, o mesmo de R3)** — `summon_on_hit`.
- Bots: Sombras com o conjunto invoca (Erguer Mortos) antes de começar a canalizar.

### 1.4 Resumo dos ganchos

| # | Fusão | Gancho | | # | Fusão | Gancho |
|---|---|---|---|---|---|---|
| P1 | Juramento Rubro | reuso | | R1 | Posto de Caça | reuso (`turret_max` no padrão `trap_max`) |
| P2 | Sentença Ardente | reuso | | R2 | Trincheira | **NOVO: aura em objeto colocado** |
| P3 | Égide Ardente | reuso | | R3 | Caça em Dupla | **NOVO: `summon_on_hit`** |
| B1 | Carrasco Frenético | reuso | | A1 | Passo Fantasma | reuso |
| B2 | Peso do Titã | reuso | | A2 | Duelo de Pólvora | reuso |
| B3 | Turbilhão Feroz | reuso | | A3 | Pólvora Envenenada | reuso |
| Bi1 | Luz que Julga | **NOVO: sobrecura** | | E1 | Vapor | reuso |
| Bi2 | Martelo da Aurora | reuso | | E2 | Supercondutor | reuso |
| Bi3 | Graça em Combate | reuso | | E3 | Plasma | reuso |
| D1 | Bramido da Matilha | reuso | | N1 | Ceifa Partilhada | reuso |
| D2 | Lua Caçadora | reuso | | N2 | Colheita da Praga | reuso |
| D3 | Casca Partilhada | reuso | | N3 | Pestilência Viva | NOVO (o mesmo de R3) |

**3 ganchos novos** (sobrecura, aura em objeto, `summon_on_hit`), 4 Fusões que os usam; folga de 3 sob o teto de 6. Nenhuma é
"bastão de stat": todas dependem de uma mecânica de cada lado.

### 1.5 Casos-limite

- **2+3 de dois conjuntos** (híbrido + build, ou dois híbridos): nenhuma Fusão (precisa das 5 peças do mesmo híbrido). Regra atual.
- **Arma lendária do mesmo tipo** (ex.: Penitência do Templário + P2): vale o maior número, nunca a soma; a explosão sai uma vez.
- **Arma que não é de nenhum dos dois lados** (ex.: Guardião+Cruzado empunhando nada de 2 mãos nem escudo): a Fusão fica apagada
  (ícone cinza na janela C).
- **Troca de arma no meio da luta:** cargas próprias da Fusão (Peso, Fé) somem na troca; Juramento, Penitência e Feridas
  continuam (são do alvo/regra atual).
- **Laços positivos** (B3 crítico→Frenesi; P3 bloqueio→Penitência→Juramento; Bi1 dano→cura→sobrecura): cada um tem trava escrita na
  ficha (máx. de cargas, ICD, "o dano da sobrecura não gera Radiância"). O check precisa provar que o dano da Bi1 não gera cura.
- **Emboscada (A1) + talento Emboscada 2,0× + Lâminas:** o golpe "furtivo" da Fusão usa o multiplicador da pessoa; teto proposto
  `FUSION_AMBUSH_MAX` = 2,0 (o talento já chega lá; não passa).
- **Torreta (R1/R2)** depende da ascensão do Atirador (35). Sem a ascensão, a face rifle de R1/R2 fica apagada; a face lança de R2
  (Estaca) funciona sem ascensão.
- **Elemental (E1–E3)** em forma de outro elemento (ex.: Fogo+Gelo com o elemental de raio): o elemental não dispara a Fusão; o
  mago dispara.
- **Chefe imune a controle:** condições "preso/atordoado" (P2, D3, R3) contam também "lento", que chefes recebem; conferir a lista
  de imunidades (D3 fica só em "preso" — ver 1.8).
- **Invocação morre com cargas/feridas que abriu:** as feridas continuam no alvo (são do dono).

### 1.6 Botões de ajuste (`Balance`)

| Botão | Faixa segura | Afeta |
|---|---|---|
| `FUSION_NUMBERS[id][chave] = [v35, passo]` | v35 ±30% do proposto; passo ≤ 10% de v35 | força de cada Fusão (F-FUS1) |
| `FUSION_TOL` | 0,01–0,03 | quão perto do 5 peças normal cada Fusão tem de ficar |
| `FUSION_GAIN_MAX` | 0,10–0,12 | teto do ganho de qualquer Fusão (F-FUS2) |
| `FUSION_AMBUSH_MAX` | 1,8–2,0 | teto do golpe furtivo da A1 |
| `FUSION_POST_RADIUS` | 4–6 m | raio do posto da R2 (maior = grupo não precisa se mover) |
| `FUSION_OVH_CAP` | 0,8–1,2 × MATK/s | teto do dano da sobrecura (Bi1) |

### 1.7 Critérios de aceitação

1. Check: as 24 Fusões existem (8 classes × 3 pares), cada uma com `id`, números nos 3 tiers e face(s) declarada(s).
2. Check: no máximo 6 ganchos novos registrados; todo tipo de efeito citado existe (como `_check_catalog_keys`).
3. `boss_probe --comp` (grupo de 4, 20+ lutas): `|G_fus − G_5n| ≤ FUSION_TOL` em cada uma das 24, e nenhuma acima de `FUSION_GAIN_MAX`.
4. Utilidade (Bi3, D1, D3 face Urso, R2): sob `--dmg=6`, queda de mortes 6–10% contra o 5 peças normal.
5. Bot com a Fusão a dispara ≥ 1× em 60 s de luta de chefe (contador por Fusão no probe).
6. Check do laço da Bi1: o dano vindo da sobrecura gera 0 de cura por Radiância.
7. `combat_probe` 0 FLAG com os conjuntos (B3 e A1 mexem no ritmo).

### 1.8 Decisões para o autor

1. **Torreta da ascensão do Atirador:** com a R1 dando a 2ª torreta, a ascensão passa a **1 torreta**. O refino 40/45 "torreta
   dupla" vira: (a) torreta +4 s e −20% de recarga **(recomendado)**, ou (b) torreta que deixa lento, ou (c) manter 2 na ascensão e
   a R1 dar a 3ª (estoura o orçamento da R1; não recomendado).
2. **Duas faces por Fusão** (regra 1.1.2): dobra o trabalho de calibragem (≈ 39 faces em vez de 24), mas sem ela metade das Fusões
   fica morta quando o bot usa a arma do outro lado. Recomendo manter.
3. **D3 face Xamã** se chefes forem imunes a prender: trocar "preso" por "preso ou dentro da área do Ent".
4. **Fusão substitui o 5 peças normal** (regra 1.1.1), como a R7.1 sugere — confirmar.


### 1.9 Redesenho aprovado (2026-11-12) das 4 Fusões fracas
Medidas na fase 1 (Ghar, nível 40, `--hp=2 --tank_lock`, 2 usuários): P2 G_fus 0,047 vs G_5n 0,223; Bi2 −0,023 vs 0,153;
D2 0,004 vs 0,123; N2 0,008 vs 0,082 (N2 e E1 nunca disparavam com bots). Causa comum: dependiam de proc raro, de outra build no
grupo ou de maldições que o Ceifador não aplica. Redesenho (decisão do autor): efeitos quase sempre ligados e que funcionam
sozinhos. P2/Bi2/D2 miram o teto 0,12 (o 5 peças normal delas passa do teto); N2 mira G_5n (0,082 ± 0,02).
- **P2 Sentença Ardente** — golpe direto põe 1 Penitência; cada Penitência no alvo dá +2,5% a todo o seu dano nele (máx 5 = +12,5%);
  ao chegar a 5 explode (regra atual de `penance_hit`) e volta a 2. Face escudo: igual + a explosão atordoa 0,6 s (ICD 8 s).
- **Bi2 Martelo da Aurora** — cada magia sagrada dá **Aurora** por 4 s: +10% de ATK e MATK; os golpes de arma curam o aliado mais
  ferido em 3% do dano.
- **D2 Lua Caçadora** — face duas maças: todo o seu dano em alvo sangrando ou com Fogo Lunar +10%. Face cajado: Fogo Lunar também
  faz o alvo sangrar (conta contra a regeneração do troll) e suas magias em alvo sangrando causam +10%.
- **N2 Colheita da Praga** — golpes de foice aplicam **Praga Menor** (conta como maldição, 6 s, até 3); cada maldição no alvo dá +4%
  de dano e +2% de roubo de vida à foice; alvo amaldiçoado que morre solta Explosão de Cadáver a 60%.
Números iniciais acima = v35; o passo por tier segue F-FUS1. Calibrar com mais lutas (ruído ±0,05 com 30 lutas).
**Calibrado (2026-11-12, Ghar 40, 60–90 lutas):** P2 +0,125 (`pen_dmg` 2,75, `pen_pct` 90, ICD 0,65 s) · Bi2 ~0,12 com Aurora
**+14%** (40% acima do v35; aprovado pelo autor) · D2 +0,132 (a Mordida do Lobo conta como sangramento; aprovado) · N2 +0,096
(`curse_dmg` 3,2) · E1 agora dispara com bots (regra de gelo em alvo queimando) e rende +0,065 (abaixo do G_5n 0,164; ajuste à parte).
**E1 Vapor (2026-11-12, Ghar 40, `--hp=2 --tank_lock`, 2 Fogo com h5 par Gelo; h4 300 lutas):** com só o gatilho de gelo, `quench` 160/210/535% (v40) davam G ≈ 0 / +0,016 / +0,048 (o Vapor disparava ~2 vezes por mago por luta: o Fogo só tem o Choque Térmico de gelo). Regra nova do autor: fogo em alvo retardado também faz Vapor (recarga 2 s) → ~10 Vapores por mago por luta (2/3 pelo fogo). Calibragem do `quench` (v40): 160% +0,028 · 450% +0,091 · 790% +0,214 · 650% +0,146 ± 0,026 (300 lutas) · **700% (`[670, 30]`) +0,164 ± 0,022 (300 lutas)** contra G_5n 0,164. Cada Vapor é um estouro de ~7× o que a queimadura ainda faria.

---

## 2. Ascensão do Caçador (arco + lince): 3 alternativas ao Tigre Dente-de-Sabre

Restrições usadas: jogo de grupo (o ganho conta no tempo do **grupo**, F5: razão 1,06–1,10 aos 35, 40 e 45 com +6% cada);
uso pelos bots obrigatório (R6); não repetir o Lobo Alfa do Druida ("chama a matilha") nem o Salto do Lanceiro; o lince continua
(é a identidade da build e as Fusões R1/R3 usam "o companheiro").

### Opção A — **Falcoeiro: Olhos do Céu** (RECOMENDADA)

- **Fantasia:** o caçador ganha um falcão que vê a luta de cima; o grupo caça o que o falcão marca. O lince luta no chão, o
  falcão aponta a presa.
- **Regra principal:** segundo companheiro, **falcão intocável** (não tem vida nem aggro, voa sobre o caçador; 1 por vez,
  permanente como o lince). A cada `FALCON_DIVE_CD` (6 s) ele mergulha no alvo do caçador: power 0,8 e aplica **Presa**
  (maldição `falcon_prey`, 8 s): o alvo recebe +`FALCON_TAKEN` (6%) de dano **de todos**.
- **Skills (nós de skill aos 35):**
  - **Chamado do Falcão** (SELF, invoca o falcão; regra do Companheiro).
  - **Mergulho** (TARGET, 14 m, recarga 12 s): power 1,6, atordoa 0,6 s (regra de controle em chefe) e manda o lince saltar no
    mesmo alvo (`pet_command`).
  - **Olhos do Céu** (SELF, 10 s, recarga 30 s): o grupo a 15 m ganha +8 de crítico contra a Presa e +10% de velocidade de
    movimento (sair dos círculos de barragem).
- **Bots:** chamam o falcão ao entrar em luta; Mergulho no alvo do tanque na abertura e quando sai da recarga; Olhos do Céu na
  abertura da luta de chefe e quando aparece `barrage`.
- **Refinos:** 40 — **Falcão Real**: quando a Presa morre, ela passa para o inimigo mais perto a 8 m (bom no lixo e nos lacaios) ·
  45 — **Revoada**: Olhos do Céu solta 3 falcões que mergulham em 3 alvos diferentes (Presa em área, 1× por uso).
- **Orçamento (F5):** Presa +6% com ~100% de uptime no chefe = razão do grupo ~1,06 + mergulhos ~0,02 → **~1,08** aos 35. O 40
  (Presa espalha) rende nos lacaios (+6% medido em luta com lacaios) e o 45 (Revoada) é pico de área.
- **Risco a travar:** marcas somadas (Marca do Caçador, Marca do Predador do Lanceiro, Presa, arma lendária `mark`). Proposta:
  teto `MARK_TAKEN_CAP` = 25% de "dano recebido" somando todas as marcas no alvo.
- **Por que recomendo:** (1) é **multiplicador de grupo** — melhora qualquer composição, o que combina com "group-first"; (2)
  IA barata e segura: o falcão não anda no chão, não prende em ponte/rio, não puxa aggro, não morre; (3) silhueta nova (ave) que
  não repete o dragão do Lanceiro nem a matilha do Druida; (4) mantém o lince e todas as Fusões do Caçador.

### Opção B — **Senhor das Feras: Guarda-Costas**

- **Fantasia:** o lince é um bicho de guerra treinado para proteger o grupo.
- **Regra principal:** comando **Guardar** (TARGET aliado): o lince fica colado no aliado, **toma para si 20%** do dano que ele
  recebe e provoca por 1 s quem o ataca (ICD 4 s); enquanto guarda, o lince tem +30% de vida.
- **Skills:** **Guardar** (TARGET aliado, sem recarga, troca de protegido) · **Resgate** (o lince corre até o aliado mais ferido
  abaixo de 35%, empurra quem está a 3 m e dá escudo de 10% do HP; recarga 25 s) · **Rugido do Bando** (grupo +10% de ATK por 8 s,
  recarga 30 s).
- **Bots:** guardam o curandeiro quando há lacaios; sem lacaios, o tanque se não houver curandeiro; Resgate em aliado < 35%.
- **Refinos:** 40 — guarda toma 30% e o lince regenera 1%/s enquanto guarda · 45 — o lince não morre 1× por luta (volta com 30%).
- **Orçamento:** utilidade (F5 sob `--dmg=6`, −6–10% de mortes).
- **Contras:** redirecionar dano é um gancho novo no meio do pipeline de dano; pisa no papel do Paladino e da Barreira do Bispo;
  o lince morre muito (o curandeiro passa a curar o pet); posicionamento colado em aliado é IA mais cara.

### Opção C — **Caçada Espiritual: Matilha do Grupo**

- **Fantasia:** o espírito do lince se divide e cada aliado ganha um lince-espírito por alguns segundos.
- **Regra principal:** **Grito da Caçada** (SELF, 12 s, recarga 45 s): cada membro do grupo a 15 m ganha um lince-espírito (40% do
  poder do lince do caçador) que ataca o alvo daquele aliado.
- **Skills:** **Grito da Caçada** · **Laço Espiritual** (TARGET aliado, 20 s: aliado e lince +10% de velocidade de ataque enquanto a
  6 m) · **Bote Coletivo** (todos os linces saltam no alvo do caçador, atordoa 0,5 s, recarga 20 s).
- **Bots:** Grito na abertura de chefe e com 2+ lacaios; Laço no tanque.
- **Refinos:** 40 — linces-espírito duram 16 s · 45 — Bote Coletivo aplica +8% de dano recebido.
- **Orçamento:** uptime 12/45 ≈ 27% × ~25% a mais por aliado ≈ razão ~1,07.
- **Contras:** repete o Lobo Alfa do Druida ("chama a matilha"); até 4 invocações a mais por caçador (desempenho na cidade com
  bots e IA de invocação, que já é o ponto caro); pico curto em vez de valor constante.

### Comparação

| | A. Falcoeiro | B. Guarda-Costas | C. Matilha do Grupo |
|---|---|---|---|
| Papel no grupo | multiplicador de dano constante | proteção (sub-tanque) | pico de dano curto |
| Ganchos novos | marca com teto (pequeno) | redirecionar dano (grande) | invocação por aliado (médio) |
| Risco de IA/desempenho | baixo (intocável, sem chão) | alto (posição, pet morre) | alto (até +4 entidades) |
| Repete outra ascensão? | não | Paladino/Bispo | Druida Lobo Alfa |
| Mantém o lince | sim | sim (é o centro) | sim |

---

## 3. Resumo das recomendações

1. Fusão **substitui** o 5 peças normal e tem o mesmo orçamento (`|G_fus − G_5n| ≤ 0,02`, teto 0,12); medir `G_5n` primeiro.
2. **Duas faces** por Fusão quando as armas do par diferem (bots não trocam de arma).
3. Efeito lendário emprestado traz números próprios, mais fracos; com a arma lendária vale o maior.
4. **3 ganchos novos** (sobrecura, aura em objeto colocado, `summon_on_hit`), dentro do teto de 6.
5. Torreta: R1 dá a 2ª torreta, R2 é o posto que cura; a ascensão do Atirador cai para 1 torreta e o refino muda.
6. Caçador: **Falcoeiro (Olhos do Céu)**, com teto de marcas somadas `MARK_TAKEN_CAP` 25%.
