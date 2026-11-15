# Proposta: split por nível do F5 no 45 (7 builds acima do alvo)

Status: SUPERADA pela decisão do usuário de 2026-11-14 (alvo do 45 passa a ~1,30; ninguém é cortado, quem está abaixo sobe; ver §8).
Autor: systems-designer, 2026-11-14.
Base lida em `.claude/worktrees/k-int` (somente leitura): `agent-k-qa2.md` (sessões 2-3), `agent-k-bal.md`,
`data/balance.gd`, `docs/DESIGN.md` (bullet "F5 aos 35 com fator por nível"), `tools/tests/boss_probe.gd`.
Nenhuma sonda nova rodou (sem shell nesta sessão): os números são os medidos pelo k-qa2/k-bal; as estimativas estão marcadas como (E).

## 1. Situação medida

F5 = razão `tempo(asc_base) / tempo(asc)`, Kragmar na sala real, `--lvl=45 --tank_lock --trials=80`, grupo
`paladin:guardiao, bishop:sacerdote, 2× build` (`--hp=2.5` no Elementalista). Alvo do 45: média dos 9 ajustados 1,203, faixa ±3 p.p. (1,173-1,233).
F5@35 (Agitador-Mor) tem alvo 1,06-1,10 e está dentro para os ajustados.

| build | F5@45 | ± EP | excesso vs 1,203 | ganho a manter `g = 0,203/(r-1)` |
|---|---|---|---|---|
| cruzado | 1,499 | .053 | +0,296 | 0,41 |
| fogo | 1,399 | .065 | +0,196 | 0,51 |
| templario | 1,336 | .034 | +0,133 | 0,60 |
| gelo | 1,305 | .050 | +0,102 | 0,67 |
| raio | 1,272 | .031 | +0,069 | 0,75 |
| xama | 1,260 | .029 | +0,057 | 0,78 |
| carniceiro | 1,252 | .046 | +0,049 | 0,81 |

## 2. O que gera o excesso (por build)

| build | mecânica de ascensão (vale desde o 35) | constantes compartilhadas 35/45 | nós só 40/45 (já "por nível") |
|---|---|---|---|
| cruzado | Combate Montado + Modo Arcano | `ARCANE_WINGS` {atk 24, matk 24, def 15}, `MOUNT_CHARGE_POWER` 1,6, `MOUNT_TRAMPLE.power` 0,9, `ARCANE_BURST.power` 0,8 | `ASC_CRU_WRATH_ATK` 5,5 (45), `MOUNT_LANCE_MULT` 1,3 (40) |
| templario | idem | idem | `ASC_TEM_DAWN_MATK` 3 (45), `ASC_TEM_RUNE_INT` 10 (40), `MOUNT_BANNER_MULT` 1,5 (45) |
| fogo/gelo/raio | Elemental + Fusão + apoio | `ELEM_FUSION_MATK_PCT`/`ELEMENT_PCT` 8, `ELEM_FUSION_FORM` {0,85/1,0/0,4}, `ELEM_SUPPORT`, `ELEM_STAGE_MULT[0..1]` | `ASC_FIRE_LORD_PCT`/`ASC_FROST_LORD_PCT` 9 (45), `ELEM_FORM_REFINE` (40), `ELEM_STAGE_MULT[2]` (Ancestral, 40+) |
| xama | Pássaro Arcano | `ANC_BOLT_POWER` 2,6 (assado no `SkillDef.power` de `dru_bird_bolt`), `ANC_FLOCK_*` | `ANC_REFINE_POWER` 0,06 × 2 refinos (compartilhado com Ent/Alfa) |
| carniceiro | Modo Gladiador + Ciclone de Titã | `GLADIATOR_STANCE` atk 7, `GLADIATOR_BLADE_POWER` 1,3 | `TWIN_FURY_ATK` 15 (45), `CYCLONE_LONG_MULT` 1,5 (40) |

Por que `ASC_BUILD_POWER` não alcança: `Balance.asc_power` só é lido por Ranger, Falcão, Sombras e Druida (matilha e penas).
`ASC_BUILD_POWER["xama"]` existe, mas só pesa a cura das penas; o raio do Pássaro não passa por ele. Paladino, Elementalista e Berserker (fora as Garras) não têm caminho.

### 2.1 Três achados que mudam a leitura (antes de calibrar)

1. **Cruzado/Templário estão contaminados pelo tanque.** `--asc=paladin` ascende TODOS os paladinos do grupo, inclusive o Guardião tanque
   (DPS do tanque 1287 asc contra 938 base na rodada do Cruzado). Parte do 1,499 / 1,336 é a ascensão do Guardião, não da build.
   Remedir com tanque de outra classe antes de calibrar (ex.: `--comp=druid:guardiao_verde,bishop:sacerdote,paladin:cruzado,paladin:cruzado`)
   ou aceitar a contaminação como "o grupo real" (decisão D1).
2. **O elemental no 45 está no estágio Básico.** `boss_probe` usa `--elem_stage=` (padrão 0) e o XP do elemental não sobe na luta.
   Um mago 45 real tem o Ancestral (`ELEM_STAGE_LEVEL[2] = 40`). Ou seja, o 1,40/1,31/1,27 medido é o PISO; com `--elem_stage=2`
   a razão sobe. `ELEM_STAGE_MULT[2]` (atk 2,0) é um botão que só vale do 40 em diante e não mexe no 35 (decisão D2).
3. **Carniceiro já tem botão só-45.** `TWIN_FURY_ATK` é nó do 45 (k-bal: 10 → x1,152, 15 → x1,198 na sala antiga; ~0,009/ponto).
   (E) `TWIN_FURY_ATK` 15 → 10 leva 1,252 → ~1,21, sem código. O "impossível" do k-qa2 não vale para ele.

## 3. Opções

Notação comum: `t(L) = clamp((L - ASC_LEVEL) / (ASC_MAX_LEVEL - ASC_LEVEL), 0, 1)` (a mesma de `asc_level_mult`).
Estimativa linear do efeito (vale para A e B): se a mecânica cortada responde por uma fração `phi` do ganho da build,
`r' ≈ 1 + (r - 1) × (1 - phi × (1 - w))`, logo `w = 1 - (1 - g) / phi`, com `g` da tabela 1.

| Símbolo | Tipo | Faixa | Descrição |
|---|---|---|---|
| r | float | 1,0-1,6 | F5@45 medido |
| r* | float | 1,173-1,233 | alvo (1,203) |
| g | float | 0-1 | (r* - 1)/(r - 1): fração do ganho que fica |
| phi | float | 0-1 | parte do ganho que vem da mecânica cortada (medir com `--why`: `DPS ...+inv`, `BUFFS`) |
| w | float | 0,1-1,0 | peso no 45 da mecânica (resultado) |

Saída: `w < 0` = a mecânica sozinha não basta (phi pequeno demais): cortar mais de uma mecânica ou usar B. `w` limitado a [0,1; 1,0] (nunca zerar a mecânica).
Exemplo: fogo r = 1,399 → g = 0,51; se Fusão + elemental dão phi = 0,8 → w = 1 - 0,49/0,8 = 0,39.

### Opção A — curva por build nas mecânicas (estende `asc_power`, o padrão já aprovado)

Fórmula: `power_mec(L) = base_mec × Balance.asc_power(build, L)`, onde `asc_power = ASC_BUILD_POWER[build] × asc_level_mult(build, L)` e
`ASC_POWER_35_MULT[build] = 1 / ASC_BUILD_POWER[build]` (o produto no 35 fica 1,0 = idêntico ao de hoje; vai linear até `w` no 45).
Pontos de ligação (todos já são funções, um multiplicador cada):
- Paladino: `MountedCombat.wings_buff` (atk/matk das asas), `arcane_cast` (rajada), poder de `pal_mounted_charge`/`pal_trample` no dano.
- Elementalista: `ElementalSystem.fusion_weight`/`fusion_power_mult` + o buff de `fusion` (já tem `k`), `prepare` (`summon_patk`).
- Xamã: `dru_bird_bolt` (e variantes do Pássaro) multiplicado no dano por `asc_power("xama", L)`; a cura das penas ganha chave própria
  (`ASC_BUILD_POWER["xama_heal"]`) para não cair junto (D4).
- Berserker Gêmeos: `GLADIATOR_STANCE.atk_pct` / `GLADIATOR_BLADE_POWER` (só se o `TWIN_FURY_ATK` não bastar).
Arquivos: `data/balance.gd` (entradas novas em `ASC_BUILD_POWER`/`ASC_POWER_35_MULT`), `core/sim/systems/mounted_combat.gd`,
`elemental_system.gd`, `druid_ascension.gd` (ou o caminho do dano da skill), `gladiator_system.gd`; `run_tests.gd`.
Risco F5@35: nulo por construção (produto 1,0 no 35, conferido por check); 40-44: interpolado, sem alvo F5 medido lá (mesma aposta já aceita no 35→45).
Risco extra: o Guardião usa as mesmas asas; a chave é por build, então `guardiao` fica 1,0 (tanque intacto).
Prós: só a ascensão perde força, o kit base não muda; mesmo modelo e mesmo check do que já existe. Contras: 5 pontos de código; `phi` precisa ser medido.

### Opção B — multiplicador de saída por faixa (ascendido × build × nível)

Fórmula: `dmg' = dmg × lerpf(1.0, ASC_OUT_45[build], t(L))` para todo dano cujo dono (ou dono da invocação) está ascendido e é da build; 1,0 sem ascensão.
Estimativa com a parte `s` do DPS base que vem da dupla da build (s ≈ 0,5-0,6): `m = (r* - 1 + s) / (s + r - 1)`.
Com s = 0,6 (E): cruzado 0,73, fogo 0,80, templario 0,86, gelo 0,89, raio 0,92, xama 0,93, carniceiro 0,94.
Arquivos: `data/balance.gd` (`ASC_OUT_45`, função `asc_out_mult`), um gancho em `WorldSim._deal_damage` (dono da invocação incluso), `run_tests.gd`.
Risco F5@35: nulo (1,0 em t = 0). 40-44 e campo: o ascendido 45 bate 6-27% menos com TODO o kit, inclusive nas faixas 40-45 e na investida
(`band_probe` 40-45 e `raid_probe` precisam de nova rodada). Contras: é um "imposto de ascensão" invisível, castiga o kit base que já foi calibrado
(`BUILD_POWER`), e no tanque mexeria na ameaça (excluir builds de tanque). Prós: 1 gancho, alcança tudo, calibração quase linear.

### Opção C — cortar/limitar só nós do 40/45 (sem código, ou quase)

Botões: `TWIN_FURY_ATK`, `ASC_CRU_WRATH_ATK`, `ASC_TEM_DAWN_MATK`, `MOUNT_BANNER_MULT`, `ASC_FIRE_LORD_PCT`, `ASC_FROST_LORD_PCT`,
`ELEM_STAGE_MULT[2]`, `ELEM_FORM_REFINE`, `ANC_REFINE_POWER` (separar por forma: `{"ent","alpha","bird"}`, para não mexer no Fera 1,218).
Risco F5@35: nulo (portões de nível ≥ 40). Alcance (E, pelas inclinações do k-bal): carniceiro sim (15 → ~10); fogo não (Senhor das Chamas 9 → 0
tira ~0,11 de 0,196); gelo ~0,004/ponto (não); cruzado responde em degrau (5 → 1,151, 6 → 1,234) e não cobre 0,30; raio não tem nó do 45.
Nós não podem ir abaixo de 0 (nó que piora é ruim para quem compra). Resolve 1-2 builds; os outros 5 seguem fora.

## 4. Recomendação

**C para o Carniceiro + A para os outros 6, depois de corrigir a medida (achados 1 e 2).** A segue o modelo que o usuário já aprovou para o 35,
mantém o 35 idêntico por construção e tira força só da ascensão. B fica como reserva se `phi` medido for baixo demais (w < 0,1).

Ordem:
1. Remedir sem contaminação: Cruzado/Templário com tanque não-paladino; Elementalista com `--elem_stage=2` (se D2 = "o 45 conta com Ancestral").
2. Rodar `--why` (asc) por build para tirar `phi` da mecânica (DPS da invocação, tempo de `arcane_wings`/`elem_fusion`, dano de `dru_bird_bolt`).
3. Aplicar A com os valores iniciais abaixo; 80 lutas por braço, só braço asc (bases do M45 servem, exceto as remedidas no passo 1).
4. Dois degraus (como T1/T2 do k-qa2): ajustar `w` pela fórmula com o `r` novo; parar dentro de 1,173-1,233.

Valores iniciais (E; `phi` chutado até o passo 2, refazer depois):

| build | botão | hoje | início | `ASC_POWER_35_MULT` (= 1/w) | phi suposto |
|---|---|---|---|---|---|
| carniceiro | `TWIN_FURY_ATK` | 15 | 10 | — (nó do 45) | — |
| cruzado | `ASC_BUILD_POWER["cruzado"]` (asas + carga + pisotear) | 1,0 | 0,35 | 2,857 | 0,9 |
| templario | `ASC_BUILD_POWER["templario"]` | 1,0 | 0,50 | 2,0 | 0,8 |
| fogo | `ASC_BUILD_POWER["fogo"]` (Fusão + elemental) | 1,0 | 0,40 | 2,5 | 0,8 |
| gelo | `ASC_BUILD_POWER["gelo"]` | 1,0 | 0,55 | 1,818 | 0,75 |
| raio | `ASC_BUILD_POWER["raio"]` | 1,0 | 0,65 | 1,538 | 0,7 |
| xama | `ASC_BUILD_POWER["xama"]` (só o raio do Pássaro) | 1,0 | 0,70 | 1,429 | 0,7 |

Cruzado/Templário: se o passo 1 baixar a razão (parte era do Guardião), recalcular `g` antes; o valor da tabela supõe o pior caso.
Gelo e o Ancestral: se D2 = sim, o `r` do gelo/fogo/raio sobe e `ELEM_STAGE_MULT[2]` (C) entra antes de A.

## 5. Checks a adicionar (`tools/tests/run_tests.gd`)

- Estender `_check_asc_power_35`: para cada build nova, `asc_power(build, 35) == 1.0` (produto 35 = hoje), `asc_power(build, 45) == ASC_BUILD_POWER[build]`,
  monótona entre 35 e 45; varredura de fonte: nenhum `ARCANE_WINGS`/`ELEM_FUSION_*`/`ANC_BOLT_POWER` lido em `core/` fora do caminho com `asc_power`.
- `_check_arcane_wings`: Cruzado 35 recebe atk_pct 24; Cruzado 45 recebe 24 × w; Guardião 45 recebe 24 (chave por build). Ver falhar sem o fator.
- Elementalista: buff `elem_fusion` e `summon_patk` no 45 = valor do 35 × w (por build do mago).
- Xamã: dano de `dru_bird_bolt` no boneco no 45 / no 35 (mesmo MATK) = w; cura das penas inalterada.
- `_check_twin_fury`: já existe; atualizar o valor esperado.
- Opção B (se escolhida): `asc_out_mult` = 1,0 sem ascensão e no 35; tanque excluído.

## 6. Como remedir (comandos)

Na raiz do worktree; até 2 Godot ao mesmo tempo; log fora do repo.
```bash
G="C:/Users/luisf/Desktop/Godot_v4.7.2-stable_win64.exe"
# F5@45, braço asc / base (repetir para cada classe:build; --hp=2.5 no elementalist)
timeout 900 "$G" --headless --path . tools/tests/boss_probe.tscn -- --party=4 --boss=boss_kragmar --lvl=45 --tank_lock --trials=80 \
  --comp=paladin:guardiao,bishop:sacerdote,elementalist:fogo,elementalist:fogo --hp=2.5 --asc=elementalist [--elem_stage=2] </dev/null > $LOG 2>&1
#   ... trocar --asc=<classe> por --asc_base=<classe> para o braço base; --why para phi; --seed=7 para 2ª semente
# Paladino sem o tanque ascendido
#   --comp=druid:guardiao_verde,bishop:sacerdote,paladin:cruzado,paladin:cruzado --asc=paladin
# F5@35 (deve ficar igual; spot-check de 2 builds tocadas)
timeout 900 "$G" --headless --path . tools/tests/boss_probe.tscn -- --party=4 --boss=boss_agitator_lord --lvl=35 --tank_lock --trials=80 \
  --comp=paladin:guardiao,bishop:sacerdote,X,X --asc=<classe> </dev/null > $LOG 2>&1
# Faixa e investida (só se B): band_probe --from=40 --to=45 --only=duel --trials=16 --why ; raid_probe field_kharzun --bots=0,1,3
# Testes: tools/tests/tests.tscn -- --only=asc_power_35,ascension,asc_web_fill,twin_fury,titan_grip,arcane,elemental ; depois o suite inteiro + smoke
```
Ler a linha `TIME` (média, ep); razão = média base / média asc. EP ~0,03-0,06 em 80 lutas: diferença < 0,05 entre dois valores pede 2ª semente.

## 7. Decisões do usuário

- **D1** Cruzado/Templário: medir com tanque de outra classe (só a build) ou manter o Guardião ascendido no grupo como "grupo real"?
- **D2** O F5@45 do Elementalista conta com o elemental Ancestral (`--elem_stage=2`, o que o jogador terá) ou com o Básico (medida atual)?
- **D3** Opção: A+C (recomendada), B (imposto de saída, 1 gancho) ou só C (resolve 1-2 builds)?
- **D4** Xamã: separar a cura das penas numa chave própria (`xama_heal`) para o corte do raio não tirar cura?

## 8. Decisão e resultado (usuário 2026-11-14; aplicado no worktree `bal45` 2026-11-15)

- Alvo novo do F5@45: **~1,30**. Nenhuma build é cortada (Cruzado 1,30, Fogo 1,72, Raio 1,46 ficam como estão); toda build abaixo sobe.
  As opções A/B/C acima (cortes) não foram aplicadas.
- D1 = tanque neutro (`druid:guardiao_verde`; Fera/Xamã com `paladin:guardiao`). D2 = Elementalista com `--elem_stage=2`.
- Botões só em `data/balance.gd` (+ três nós do 45 em `ascension_catalog.gd` com stat novo e portão de compra do bot; peso próprio do
  refino do 45 do Xamã em `DruidAscension.refine_power`). O 35 não muda.
- Resultado (80 lutas por braço, 2 sementes): tabela em `docs/DESIGN.md`, bullet "F5 no 45 com alvo ~1,30". Faixa final 1,30-1,37
  (Lanceiro 1,37 e Punhos 1,36 ficaram um pouco acima, dentro de ~1-2 erros-padrão).
