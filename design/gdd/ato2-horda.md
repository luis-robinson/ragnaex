# Ato II — A Horda

> **Status**: Designed (aguarda `/design-review` em sessão nova)
> **Author**: Luis Robinson + Claude
> **Last Updated**: 2026-11-10
> **Last Verified**: 2026-11-10
> **Implements Pillar**: 4 (Mundo vivo) e o foco em grupo (bots + chefes que escalam com o grupo); 3 (Equipamento é poder, build é escolha)
> **Origem**: plano aprovado em 2026-11-10 (`~/.claude/plans/goofy-yawning-charm.md`). Sistema fora de índice (o projeto não tem `systems-index.md`; o design legado vive em `docs/DESIGN.md`).

## Summary

O Ato II leva o jogador e os bots ao continente de **Kharzun**, níveis **30 a 45**, contra a **Horda**: clãs de orcs, goblins e
trolls unidos à força pelo **Grão-Senhor da Guerra** porque fogem de algo pior que vem do leste. São três cenários (Costa
Partida, Estepes de Cinza, Monte Kharzun) que **mudam com as missões**, como a Floresta e o Bastião do Ato I; uma linha de
inimigos em evolução inspirada nos arquétipos dos Northerners de Wesnoth (nomes e visual próprios); missões paralelas por
lugar; e uma **ascensão por classe** (35/40/45) que abre estratégias mais fortes, como combate montado, elemental que evolui e
duas armas de duas mãos.

> **Quick reference** — Layer: `Feature` · Priority: `Full Vision (Ato II)` · Key deps: `Progression, Bosses, Combat & Skills, RaidSystem, WorldState, Party/Bot AI`

## Overview

**O que é.** Uma expansão de conteúdo e progressão: o nível máximo passa de 30 para 45, um continente novo entra no mapa do
mundo pelo cais do Bastião, e o jogo ganha um inimigo com identidade própria — uma Horda organizada em linhas de unidades que
evoluem (recruta → guerreiro → senhor da guerra; filhote de troll → troll → lança-pedras; ginete de lobo → saqueador → ginete do
lobo atroz; arqueiro → besteiro → arco de fogo; assassino goblin → matador; lanceiro goblin → empalador → agitador), mais as
nagas da costa.

**Como o jogador vive isso.** Chega de navio a uma colônia sitiada, ajuda a defendê-la das investidas de ginetes, empurra a
Horda costa adentro, toma os três acampamentos de guerra das estepes um por um e termina numa raide de cinco pessoas contra o
Grão-Senhor na cidadela da montanha. **Cada missão principal muda o cenário** (regra do Ato I: `WorldState` lido de
`quests_completed`): investidas ficam menores ou maiores, colonos ocupam o que foi retomado, NPCs novos aparecem, rotas se
abrem. As **missões paralelas também crescem**: começam como pedidos pequenos de um morador e viram cadeias que mudam um
lugar (o farol aceso traz navios e um mercador; os desertores ajudados viram um acampamento aliado; os escravos libertados
viram ferreiros). No meio do caminho, cada classe faz a sua **missão de ascensão** e ganha uma mecânica nova que muda o jeito
de jogar em grupo.

**Por que existe.** O Ato I terminou com o mundo salvo e nada para fazer além de farmar. O jogo é de grupo e o foco é a IA dos
bots: o Ato II dá um inimigo que pede grupo (bandos com líder, aura de agitador, trolls que regeneram, assassinos que pegam
quem fica para trás), chefes que já escalam com o número de pessoas, e ascensões que dão a cada papel uma ferramenta nova de
grupo. Sem ele, o progresso de build para no 30 e as builds novas (montado, elemental evoluído, titã) não têm onde existir.

**Fora de escopo deste documento**: fórmulas de dano e de atributos (`combat-skills.md`), regras gerais de chefe
(`bosses.md`), curva de XP do Ato I (`progression.md` — este documento só estende as faixas).

## Detailed Design

### Core Rules

#### R1. Chegada e travessia
1. O cais fica no lado leste do Bastião (`field_ruins`), hoje sem saída. O **Capitão Bren** (NPC do cais) oferece "Zarpar para
   Kharzun" como portal-NPC para `city_port`.
2. Portão de progressão (`MapsCatalog.PORTAL_GATES`): nível 30 e a missão `dw_epilogue` concluída. A volta (navio de chegada
   no cais de Porto Esperança → Bastião) não tem portão.
3. Bots usam o mesmo portal (`PortalSystem.portal_towards` / `BotBrain._find_portal`) e escolhem caçar em Kharzun pelo
   `MapDef.level_range` dos mapas novos, como hoje.
4. O cristal de retorno de Porto Esperança (`role: crystal`) pode ser vinculado; G leva ao ponto vinculado (regra do Ato I).

#### R2. Faixas, mapas e o que cada um tem
| Faixa | Campo | Hub | Masmorra / forte | Chefes (grupo, com reforço por pessoas) |
|---|---|---|---|---|
| 30–35 | `field_coast` — Costa Partida | `city_port` — Porto Esperança | `dg_goblin` — Grutas Goblin (3 salões + selo) | Mãe das Marés (naga, campo), Agitador-Mor (grutas) |
| 35–40 | `field_steppe` — Estepes de Cinza | Posto da Caravana (dentro do campo, muralha de carroças) | `fort_trolls`, `fort_fire`, `fort_war` (acampamentos de guerra, conquistáveis) | Troll Rei-da-Rocha, Mestre Besteiro, Senhor da Guerra Ghar |
| 40–45 | `field_kharzun` — Monte Kharzun | (acampamento avançado da Aurora no sopé) | `dg_slayers` — Salão dos Matadores; `kharzun_citadel` — a cidadela | Mestre Matador, três Chefes de Clã (cidadela), **Grão-Senhor da Guerra** (raide de 5) |

Toda zona segue o layout do Ato I (vale ~240 m, hub, 3–5 POIs a 60–120 m, estradas curvas, marco visível de qualquer
ponto, borda natural) e os quatro tipos de lugar por zona (`_check_places`: cabana com NPC, acampamento, santuário, entrada
de masmorra). Os POIs de cada zona são os do plano: Costa = Praia dos Naufrágios, Aldeia Goblin de Palafitas, Falésias dos
Ninhos, Acampamento dos Ginetes, Santuário Afogado (marco: o farol); Estepes = os três acampamentos, Cemitério dos Mamutes,
Acampamento dos Desertores (marco: o Totem Partido); Kharzun = Minas de Escravos, Canil dos Lobos Atrozes, Forja Negra, Salão
dos Matadores, Portão da Cidadela (marco: a cidadela no pico).

#### R3. A Horda — linhas de evolução
Cada linha tem 2–3 estágios em faixas crescentes; o estágio de cima sempre aparece **liderando** os de baixo (escolta,
`MonsterDef.escort`) — o grupo aprende a matar o líder ou a aguentar o bando.

| Linha | Estágios (nível) | Faixa | Papel | Mecânica própria |
|---|---|---|---|---|
| Goblins | Lanceiro Goblin (30) → Empalador (33) → **Agitador** (36) | 30–40 | bando barato / estocada que atravessa | o Agitador dá **aura** de dano e velocidade aos aliados perto; morto, o bando desanima (perde a aura) |
| Ginetes | Ginete de Lobo (31) → Saqueador (35) → Ginete do Lobo Atroz (41) | 30–45 | rápidos, flanqueiam quem cura/atira | Saqueador joga **rede** (prende); são o grosso das investidas |
| Orcs | Recruta Orc (32) → Guerreiro Orc (37) → Senhor da Guerra (42) | 30–45 | corpo a corpo pesado | o Senhor lidera escolta e dá grito de guerra (buff do bando) |
| Trolls | Trollzinho (35) → Troll (38) → Lança-Pedras / Brutamontes (41) | 35–45 | tanques inimigos | **regeneração** de vida; fogo e veneno cortam a regeneração enquanto queimam |
| Arqueiros | Arqueiro Orc (35) → Besteiro (38) → Arco de Fogo (42) | 35–45 | à distância | chuva de flechas de fogo em círculos avisados (`barrage`) |
| Assassinos | Assassino Goblin (40) → Matador (43) | 40–45 | caçadores de quem fica isolado | **somem** (furtividade simples) e aparecem pelas costas com faca envenenada |
| Nagas | Naga das Marés (31) → Guerreira Naga (34) | 30–35 | costa | puxam para a água, golpe em linha |

#### R4. Cenários que crescem com as missões (o coração do Ato II)
Cada zona tem **estágios** lidos de `quests_completed` (`WorldState`): monstros, NPCs, investidas e passagens mudam quando
a missão que os controla é concluída — sem campo novo no save. As cadeias paralelas também mexem no mundo. O detalhe por
zona está em States and Transitions.

#### R5. Missões
- **Linha principal**: 8–10 missões por faixa (padrão do Ato I), cada uma mudando o cenário ao terminar.
- **Paralelas que crescem**: toda cabana/acampamento abre uma cadeia de 2–4 missões; a última muda o lugar (NPC novo, serviço
  novo, aliado, montaria). As do plano: Costa — *O Farol Apagado*, *Náufragos*, *Pérolas das Marés*, *Goblin Comerciante*
  (Nikki), *O Diário do Capitão*, quadro de caçadas da taverna; Estepes — *A Caravana*, *Os Desertores* (escolha: ajudar ou
  entregar — muda NPC e recompensa), *Marfim de Mamute*, *Totem dos Ventos*, *Corrida dos Lobos*; Kharzun — *Correntes
  Quebradas*, *O Ferreiro Anão*, *Ecos da Noite* (gancho do Ato III), *Ovos do Lobo Atroz* (montaria lobo atroz).
- **Ascensão de classe**: uma missão por classe aos 35 (na Costa), com mestre próprio no porto; refinamentos aos 40 e 45 pelas
  linhas de talento novas.
- XP de missão segue `QuestsCatalog.scale_xp` (40–50% da faixa, 10+ missões por faixa — checks existentes).

#### R6. Ascensões de classe (35 / 40 / 45)
A missão de ascensão (35) libera a mecânica-assinatura da classe para **todas as builds** dela; aos 40 e 45 chegam linhas de
talento novas (`class_talents_catalog.gd`, 3 escolhas por linha, cada uma pensada para uma das 3 builds, sem trava) e nós novos na teia. Toda ascensão
tem uso pelos bots (`BotBrain`; alvo: bot ascendido usa a ascensão ao menos 1× em 60 s de luta contra chefe) — sem isso ela não entra.
| Classe | Ascensão (35) | Regra principal | 40 / 45 (refinos por build) |
|---|---|---|---|
| Paladino | **Combate Montado** + **Modo Arcano** | montado, o paladino ataca e usa skills montáveis (Carga Montada, Pisotear; atordoar/prender/gancho derrubam); **Corrente de Luz** puxa o alvo até ele; **Modo Arcano** (liga/desliga) abre **asas de luz** e troca os golpes por versões arcanas | Guardião: corrente provoca · Cruzado: lança pesada · Templário: Modo Arcano mais longo e asas que protegem o grupo |
| Elementalista | **Elemental que evolui e muda de forma** | o elemental (um por vez, regra atual) ganha **experiência** com abates feitos perto do mago e evolui: Básico → **Maior** (35) → **Ancestral** (40/45); o mago **troca a forma** entre fogo/gelo/raio sem perder o estágio; cada forma tem skills e um **modo** (atacar, proteger, apoiar) | Fogo: Salamandra → Ifrit (área) · Gelo: Golem de Gelo → Ondina (escudo no grupo) · Raio: Silfo → Tempestade (velocidade) |
| Berserker | **Empunhadura de Titã** + **Modo Gladiador** | duas armas de duas mãos (Executor e Machados Gêmeos; Punhos: Garras de Titã); **Modo Gladiador** (postura de arena): a Fúria vira **Glória**, golpes elementais na arma, investida e grito para a plateia | Machados Gêmeos: os dois machados giram juntos · Executor: golpe final da arena · Punhos: Glória não esfria |
| Bispo | **Coro Celeste** | **Anjo Guardião** invocado que cura o grupo, **Barreira Sagrada** em área (mecânica de grupo e de movimento: o grupo se junta dentro, ela anda com o Bispo) e **bênçãos** de grupo novas; ressurreição em combate aos 45 | Sacerdote: anjo mais forte · Iluminado: barreira que fere quem entra · Batalha: barreira que vai junto na carga |
| Druida | **Forma Ancestral** | terceira forma por build: Urso → **Ent** (raízes, provoca em área); Lobo → **Lobo Alfa** (chama a matilha); Xamã → **Pássaro Arcano** (forma mágica alada: voa por cima do chão, raios e chuva de penas de luz) | variantes de skill por forma (como Lobo/Urso hoje) |
| Ranger | **Companheiro Evoluído** / **Lanceiro Dracônico** | Caçador: lince → **Tigre Dente-de-Sabre**; Atirador: **torreta** de campo; Lanceiro: **Salto Dracônico** (sobe e some do chão, cai com a lança em área) e **Brados Elementais** (gritos que dão elemento à lança e ao grupo) | tigre com investida · torreta dupla · salto duplo e brado combinado |
| Assassino | **Sombras Gêmeas** | **clone de sombra** que repete seus golpes por alguns segundos + **execução** (dano enorme em alvo abaixo de 25%) | Duelista: contra-ataque em cadeia · Corsário: canhão de mão |
| Necromante | **Senhor dos Mortos** | invocações **duram mais** e +1 por tipo, **Pacto Sombrio** (buff nas invocações) e **debuffs em área** (Miasma, Marca da Cova); Forma de Lich aos 45 | Invocador: exército · Ceifador: as invocações batem junto com a foice · Sombras: debuffs em área mais largos |

#### R6.1 Especificação das ascensões (proposta para revisar — Pergunta aberta 6)
Formato comum: **missão de ascensão** (mestre da classe em Porto Esperança, nível 35, 1 cadeia de 3 passos: provar, buscar, enfrentar)
→ a mecânica liberada vale para as 3 builds; **skills novas** entram na teia (nós de skill aos 35) e seguem as regras de skill
(`SkillDef`, mira pelo mouse, maestria 0–5); **refinos** aos 40 e 45 são as linhas de talento novas; **bots** usam pela regra
descrita; números em `Balance.ASC_*` dentro do orçamento F5. Skills/mecânicas marcadas **(H)** são calibradas na fase.

**Paladino — Combate Montado** (pedido do autor)
- Mestre: Sir Aldwin, cavaleiro da Aurora no porto; missão: domar o corcel de guerra (*O Corcel de Guerra*).
- Regra: com a ascensão, montar (H) não impede lutar. Skills com `mountable: true` saem montadas; as outras ficam apagadas na
  barra enquanto montado. Básico montado: alcance +0,8 m (F8). Aura do Paladino vale montado.
- Skills novas: **Carga Montada** (DIRECTION, 11,2 m, atropela todos na linha, power 1,6, recarga 14 s); **Pisotear** (SELF,
  raio 3,5, power 0,9, lentidão 30% 2 s, recarga 8 s). As skills de escudo/aura/bênção existentes ganham `mountable`.
- Cai do cavalo: atordoar, prender, gancho, rede; 2 s imune a controle; remontar 1,5 s. Não monta em masmorra (regra atual).
- Refinos: Guardião provoca montado e bloqueia com escudo a cavalo · Cruzado: lança pesada (Carga ×1,3 de distância) · Templário:
  estandarte (aura do grupo +50% de raio montado).
- Bots: montam ao entrar em combate em campo aberto; usam a Carga para abrir a luta e quando o alvo está a 6–11 m em linha livre.
- **Corrente de Luz** (TARGET, 10 m, recarga 12 s; pedido do autor "skill de puxar"): corrente sagrada que **puxa o alvo** até o
  paladino (efeito `pull` que já existe; chefe não é puxado, mas é **provocado** por 3 s). Vale montado. Guardião: provoca também
  os monstros a 3 m do alvo puxado.
- **Modo Arcano** (liga/desliga, como as formas; dura até desligar ou a MP acabar, consome `ARCANE_MP_PER_S`; recarga 20 s ao
  desligar; pedido do autor "asas, modo arcano"): **asas de luz** se abrem nas costas (visual, a sim continua plana); o básico e as
  skills de golpe viram **dano mágico** escalando com INT/WILL (FOR conta metade), com alcance +1 m (golpe de luz); **Asas
  Arcanas** (SELF, ao ligar e a cada 8 s no modo: rajada de penas de luz em volta, raio 4 m, power 0,8, empurra); **Voo
  Arcano** (o dash vira um planeio de 6 m que passa por cima de golpes de chão — os mesmos i-frames do dash, mais longo).
  Não monta no Modo Arcano (montar desliga o modo).
- Refinos (40/45): Guardião — corrente provoca em área · Cruzado — Carga mais longa · Templário (INT) — Modo Arcano consome metade
  da MP e as asas dão 10% de redução de dano ao grupo a 6 m.
- Bots: Templário liga o Modo Arcano em luta de chefe; Guardião usa a Corrente em quem bate no curandeiro; Corrente no alvo a 6–10 m.

**Elementalista — Elemental que evolui e muda de forma** (pedido do autor)
- Mestra: Ysolde, arquimaga da frota; missão: *O Núcleo Elemental* (juntar 3 essências na Costa e despertar o núcleo).
- Regra: o elemental vira **companheiro persistente** (um por vez, como hoje): ganha `elem_xp` (F6), evolui Básico → Maior →
  Ancestral, e o mago escolhe a **forma** (fogo, gelo, raio) e o **modo**: *atacar* (foca o alvo do mago), *proteger* (provoca o que
  bate no mago, ganha DEF), *apoiar* (buff/escudo no grupo). Troca de forma: recarga 20 s, mantém estágio e % de vida.
- Formas por estágio: Fogo — Salamandra (cospe fogo em cone) → Ifrit (área que queima, explosão ao morrer); Gelo — Golem de Gelo
  (provoca, lentidão) → Ondina (escudo d'água no grupo); Raio — Silfo (rápido, salta entre alvos) → Tempestade (raios em cadeia,
  +velocidade do grupo).
- Skills novas do mago: **Comando Elemental** (troca o modo, sem recarga), **Fusão** (por 8 s o mago ganha a skill-assinatura
  da forma do elemental; recarga 40 s).
- Refinos: Fogo/Gelo/Raio fortalecem a forma do próprio elemento (o mago ainda pode trocar para as outras).
- Save: `elem_xp`, forma e modo (campo novo, `save_version`). Bots: modo *atacar* por padrão; *proteger* se forem o alvo do chefe.

**Berserker — Empunhadura de Titã** (pedido do autor)
- Mestre: Gorm Duas-Lâminas, mercenário no porto; missão: *O Peso do Titã* (erguer os machados do campeão caído na Praia).
- Regra: Executor e Machados Gêmeos podem pôr **machado de 2 mãos na mão secundária** (`Stats.meets`/`ItemSystem.equip` aceitam
  com a ascensão); golpe duplo (F7: 2ª arma ×0,45, −25% de velocidade de ataque, a teia devolve até 9%).
- Punhos de Fúria: **Garras de Titã** — garras ganham perfil de arma pesada (golpe +35% e empurrão, −20% de velocidade) **(H)**.
- Skill nova: **Ciclone de Titã** (SELF, raio 3, gira com as duas armas por 2 s, power 0,6 por giro, recarga 12 s).
- Refinos: Gêmeos — os dois machados giram juntos (Ciclone mais longo) · Executor — execução com o 2º machado abaixo de 20% · Punhos —
  a Fúria não esfria por 6 s depois do Ciclone.
- Bots: equipam a 2ª arma de 2 mãos se tiverem; Ciclone com 3+ inimigos a 3 m.
- **Modo Gladiador** (postura liga/desliga; referência de arquétipo: o gladiador de arena dos táticos — golpes elementais na arma,
  investida e plateia —, nomes e regras nossos): enquanto ligado, a **Fúria vira Glória** — cada abate e cada golpe crítico dá 1
  de Glória (máx. `GLORY_MAX` 5), e a Glória gasta reforça os golpes da arena; a postura dá +10% de dano e −10% de defesa.
  - **Lâmina Ígnea / Gélida / Trovejante** (DIRECTION/CONE, uma de cada elemento, recarga 8 s cada): golpe da arma com o
    elemento (fogo queima, gelo deixa lento e estilhaça, raio salta para 2 vizinhos), power 1,3 + 0,2 por Glória gasta.
  - **Investida do Gladiador** (avanço 7 m que derruba o primeiro atingido, recarga 10 s).
  - **Brado da Arena** (SELF, raio 8 m, recarga 25 s): provoca os monstros em volta por 2 s e dá +1 Glória por inimigo provocado
    (até 3) — a "plateia".
  - **Golpe Final** (gasta 5 de Glória): golpe com as duas armas, power 3,5, área de 3 m na frente.
- Combina com a Empunhadura de Titã (as Lâminas Elementais batem com as duas armas). Punhos: Glória não esfria fora de combate
  por 6 s.
- Bots: ligam a postura em luta de chefe; usam a Lâmina do elemento que o alvo não resiste (fogo no troll); Golpe Final com 5 de Glória.

**Bispo — Coro Celeste** (direção do autor: buffs, anjo que cura, barreira em área com mecânica de grupo e movimento)
- Mestra: Madre Celene, capelã da frota; missão: *A Chama do Coro* (reacender o altar do Santuário Afogado e chamar o anjo).
- **Anjo Guardião** (SUMMON, um por vez, 30 s, recarga 40 s): voa atrás do Bispo, cura o membro mais ferido a 12 m (tanque
  primeiro, mesma ordem dos bots), e no fim da duração solta uma **Luz de Partida** (cura em área). Invocação do Bispo escala com
  WILL (`summon_patk` vira `summon_heal`).
- **Barreira Sagrada** (GROUND, cúpula de raio 5 m, 8 s, recarga 30 s): dentro, o grupo recebe −30% de dano e **projéteis de fora
  param na borda**; a cúpula **anda com o Bispo** (vai até 2 m/s mais devagar que ele — o grupo precisa se mover junto). Mecânica
  de grupo: contra chuva de flechas de fogo e golpes "far" dos chefes, quem fica fora da cúpula apanha.
- **Bênçãos novas** (BUFF, grupo a 12 m, 20 s, recarga 25 s): **Asas da Aurora** (+15% de velocidade de movimento e de ataque) e
  **Égide Coral** (+12% DEF/MDEF e 4% de cura por golpe recebido). Não somam com elas mesmas (renovam pelo id).
- 45: **Retorno** (ressurreição em combate, uma por aliado por luta; F9) e a barreira passa a segurar a vida em 1 por 3 s quando
  é lançada (o "santuário" vira o primeiro instante da barreira).
- Refinos: Sacerdote — anjo com +50% de cura e 2 anjos aos 45 · Iluminado — a barreira fere inimigos que entram (power 0,4/s) ·
  Batalha — a barreira acompanha a velocidade dele (mesma velocidade) e dá escudo de 10% a quem está dentro ao lançar.
- Bots: Anjo sempre que pronto em luta de chefe; Barreira quando o chefe começa `barrage`/golpe "far" avisado ou 2+ membros estão
  abaixo de 50%; os outros bots do grupo **entram e ficam na cúpula** enquanto ela existir (regra nova de posição em `BotBrain`).

**Druida — Forma Ancestral** (proposta)
- Mestre: Ancião Bhoran, druida náufrago; missão: *Raízes no Sal* (plantar a semente ancestral no mangue).
- Regra: cada build ganha uma 3ª forma (liga/desliga, igual às formas atuais, com variantes das skills): Urso → **Ent** (tanque:
  raízes que prendem em área, provoca, +DEF); Lobo → **Lobo Alfa** (chama 2 lobos da matilha por 15 s, uivo que dá velocidade ao
  grupo); Xamã → **Pássaro Arcano** (forma mágica alada, como Lobo/Urso hoje: voa acima do chão — o visual sobe, a sim continua plana —,
  ganha velocidade, troca as magias por variantes: raio em cadeia, chuva de penas de luz que cura o grupo embaixo, rajada de
  vento que empurra). Modelos em `druid_sets.build_forms` (`form_bird.glb`).
- Refinos: duração e força das variantes de skill na forma ancestral.
- Bots: entram na forma ancestral no começo de luta de chefe (mesma regra de `BOT_AUTO_FORMS`).

**Ranger — Companheiro Evoluído (Caçador, Atirador) e Lanceiro Dracônico** (Lanceiro: direção do autor — referência de
arquétipo: o cavaleiro do dragão de Final Fantasy, salto e gritos elementais; nomes e regras nossos)
- Mestra: Kaya Olho-de-Falcão, batedora da colônia; missão: *O Rastro do Dente-de-Sabre* (Lanceiro: *O Ninho nas Falésias* —
  provar o salto nas Falésias dos Ninhos e receber a bênção do dragão de pedra do Santuário Afogado).
- Caçador: o lince evolui para **Tigre Dente-de-Sabre** (mais vida, investida que derruba, rugido que provoca o alvo).
  Atirador: **Torreta** (GROUND, armadilha que atira no inimigo mais perto por 12 s, até 2 ativas). *(propostas — confirmar)*
- **Lanceiro Dracônico**:
  - **Salto Dracônico** (GROUND, até 9 m, recarga 14 s): o lanceiro **salta alto e some do chão por 1,2 s** (fora de alcance:
    golpes, projéteis e chuva não o pegam; o chefe perde o alvo e volta ao tanque) e **cai** no ponto mirado com a lança: power
    2,2 no centro (raio 1,5) e 1,0 na borda (raio 3). Se houver Brado ativo, a queda leva o elemento.
  - **Brados Elementais** (SELF, um de cada elemento, 12 s, recarga 20 s, só um ativo por vez): **Brado das Chamas** (a lança
    queima; grupo a 10 m +10% de dano de fogo), **Brado da Geada** (a lança deixa lento; inimigos a 6 m −10% de velocidade de
    ataque), **Brado do Trovão** (a lança salta para 1 vizinho; grupo a 10 m +10% de velocidade). O grito também **provoca** 1 s
    os monstros a 4 m (puxa a atenção na hora certa).
  - **Lança do Dragão** (DIRECTION, 10 m, recarga 10 s): arremesso que atravessa a fila e **volta** (substitui o "arremesso que
    salta" da proposta antiga).
  - Refinos: 40 — **Salto Duplo** (o segundo salto pode ser usado no ar em até 1 s, recarga só depois) · 45 — **Brado Combinado**
    (dois brados ativos ao mesmo tempo, por 8 s, recarga 40 s).
- Bots: Lanceiro salta para desviar de golpe grande avisado (usa o salto como esquiva) e para fechar distância a 6–9 m; Brado do
  elemento que o alvo não resiste (Chamas no troll) na abertura da luta; Lança do Dragão com 2+ inimigos em linha.

**Assassino — Sombras Gêmeas** (proposta)
- Mestre: "Ninguém", espião da Aurora na taverna; missão: *A Sombra que Anda Sozinha*.
- Skills novas: **Sombra Gêmea** (SELF, um clone semitransparente repete seus golpes com 50% do dano por 6 s, monstros o ignoram,
  recarga 30 s); **Execução** (TARGET corpo a corpo, power 3,0 em alvo abaixo de 25% de vida, 0,8 acima; recarga 10 s).
- Refinos: Lâminas — o clone sai da furtividade junto · Duelista — contra-ataque em cadeia (cada esquiva prepara a próxima
  Execução sem recarga, 1×) · Corsário — **Canhão de Mão** (DIRECTION, tiro pesado que empurra).
- Bots: Sombra Gêmea na abertura contra chefe; Execução com o alvo abaixo de 25%.

**Necromante — Senhor dos Mortos** (direção do autor: invocações duram mais, buff para elas, debuffs em área)
- Mestre: o Último Escriba de Azhar (prisioneiro arrependido no porto); missão: *O Filactério Vazio*.
- **Invocações duram mais**: duração das invocações temporárias ×1,5 e +1 no limite de cada tipo (`summon_extra`).
- **Pacto Sombrio** (BUFF nas invocações a 15 m, 12 s, recarga 20 s): +25% de dano, +20% de velocidade e roubo de vida de 10% para
  o mago (o que elas causam cura o necromante).
- **Debuffs em área**: **Miasma** (GROUND, raio 4 m, nuvem de 8 s: −20% de ATK e −15% de velocidade em quem está dentro,
  recarga 16 s) e **Marca da Cova** (GROUND, raio 3,5 m, marca por 10 s: quem morrer marcado levanta como esqueleto aliado por
  15 s; recarga 24 s). Somam com as maldições atuais.
- 45: **Forma de Lich** (liga por 15 s, recarga 60 s — forma nova como fantasma/demônio: magias +30%, maldições espalham para quem
  está perto). Ao sair, invocações acima do limite somem da mais antiga para a mais nova.
- Refinos: Invocador — exército (+1 invocação, elas ganham 20% da vida do mago) · Ceifador — invocações batem junto com a foice
  (cada golpe dele manda as invocações atacarem o mesmo alvo) · Sombras — Miasma e Marca com +50% de raio.
- Bots: Pacto Sombrio com 2+ invocações vivas em luta; Miasma onde há 3+ inimigos ou no chefe; Marca da Cova no bando com pouca vida.

#### R7. Progressão estendida
- Nível máximo **45**. XP por nível segue a mesma fórmula (Formulas F1); três faixas novas em `XP_BANDS` e `XP_QUEST_SHARE_BAND`.
- Teia: `points_at` continua 8 por nível, com **+1 ponto uma vez** ao chegar no 40 (`points_at(40)` = 9, como no 10/20/30); nós novos para as ascensões.
- Talentos de classe: linhas novas aos **35, 40, 45** (hoje 6 linhas de 5 a 30).
- Equipamento comum: tiers novos aos **32 e 40** (`COMMON_TIER_LEVELS`), pelos laços de `gear_catalog.gd`.
- Lendários: níveis **35, 40, 45** (`LEGENDARY_LEVELS`) — **dois tipos que coexistem** (decisão do autor): o conjunto **da build**
  (24 builds × 3 = 72, como no Ato I) e o **híbrido por par de builds** (R7.1: 8 classes × 3 pares × 3 tiers = 72) → **144**
  conjuntos. Nomes pela regra (`set_piece_name`); na fatia 1 o visual parte do conjunto de nível 30 (híbrido: lado A com detalhes
  do lado B), modelos próprios no polimento.
- Moedas Lendárias, Relicária e aprimoramento +1..+9 seguem iguais; preço em moedas continua `índice do tier + 1`.

#### R7.1 Conjuntos híbridos (35/40/45) — proposta do autor: "as builds ficam mais híbridas"
A partir do 35, a build cresce além do braço dela na teia (com muitos pontos, a maioria das builds fica híbrida — observação do
autor), então além do conjunto da build passa a existir um **por par de builds da mesma classe** — o mesmo padrão que os
conjuntos do Elementalista já usam (1º elemento manda, 2º "favorece": `SET_FAVOR_*`). **Coexistem** (decisão do autor): quem
fica pura usa o da build; quem mistura usa o híbrido ou combina os dois tipos.
- **Quantos**: por classe e por tier, 3 conjuntos híbridos (A+B, B+C, C+A) → 8 classes × 3 pares × 3 tiers = **72**, somados
  aos 72 da build = 144 nos tiers 35/40/45 (o dobro de arte: na fatia 1 o visual é reaproveitado; os modelos próprios vêm no
  polimento, por classe).
- **Peças**: 5 de armadura (contam para os bônus) + **as armas das duas builds** (a de A e a de B, como peças alternativas —
  igual à maça do conjunto hoje: `SetDef.alt_pieces`, não contam no total). Armadura e atributo principal vêm do lado A; o
  atributo secundário vem do lado B (`attr` de A + `attr` de B). Ex.: Guardião+Cruzado = placa, VIT e FOR, espada/maça + escudo
  e espada de 2 mãos.
- **Bônus**: 2 peças = o bônus de 2 peças de A · 3 peças = o de 3 peças de B · 4 peças = a skill-assinatura de A **e** a de B,
  cada uma com metade do bônus de 4 peças normal · 5 peças = **Fusão**: um efeito que liga as duas builds (ex.: Guardião+Cruzado —
  golpes de 2 mãos geram cargas de Juramento; Fogo+Gelo — gelo estilhaça as queimaduras; Caçador+Atirador — o tigre ataca o alvo
  da torreta; Lâminas+Duelista — esquiva deixa a próxima facada furtiva).
- **Liberdade**: misturar conjuntos do mesmo tier vale como hoje (cada conjunto conta as próprias peças) — 2+3 de um híbrido com
  o conjunto da build, ou de dois híbridos, ativa os bônus de 2 e 3 de cada lado. A arma usada decide as skills (regra atual), então a mesma pessoa pode trocar
  entre os dois lados do par trocando só a arma.
- **Nomes**: pela regra de `set_piece_name` com o par (ex.: "do Juramento Rubro"); visual: na fatia 1, base no conjunto de nível 30
  do lado A com detalhes (cor/emblema) do lado B; modelos próprios no polimento.
- **Relicária**: a aba da build mostra também os híbridos em que ela entra (cada híbrido aparece nas abas das duas builds).
- **Bots**: o bot escolhe o híbrido que inclui a build dele, preferindo o par com a outra build que a teia dele mais comprou.

#### R8. Loops de qualidade (decisão do autor: "use loops para garantir qualidade")
Nada fecha sem passar pelo loop medido da sua categoria:
- **Zona**: `/layout-zone` até nota ≥ 8 nos 5 critérios (máx. 6 iterações), depois tour de screenshots no jogo.
- **Faixa**: `band_probe --from --to` com 0 `travou` e tempo médio por abate a ±25% da média da faixa 20–30 do Ato I.
- **Chefe**: `boss_probe --comp` (40 lutas) — grupo completo de 4 vence ≥ 95% com 0,3–1 morte por luta; grupo de 4 sorteado vence 65–85%; o solo é só observado (alarme, sem alvo).
- **Investida/conquista**: `raid_probe` sem `presos`, repelida pela defesa do porto com bots.
- **Ascensão**: build com e sem a ascensão no `boss_probe --comp` e no `combat_probe` (0 FLAG); o ganho entra no orçamento de F5.
- **Desempenho**: `sim_probe` ≤ 5 ms/tick em média com Kharzun carregado (regra do projeto) e o porto em investida com 10+ bots sem trecho < 25 FPS no `PerfWatch`.
- **Missões**: auditoria do `band_probe` (XP 40–50% da faixa), checks de cadeia (pré-requisitos, NPCs existem).

### States and Transitions

Estágios de cada cenário (lidos de `quests_completed` pelo `WorldState`; cada linha é "o que muda quando a missão termina").

**Costa Partida / Porto Esperança**
| Estágio | Gatilho (missão concluída) | O que muda |
|---|---|---|
| C0 Cerco | chegada | porto com paliçada meio feita, investida de ginetes a cada 240 s (±20%), praia e mangue cheios de goblins, farol apagado |
| C1 Muralha | `hx_palisade` (ajudar a fechar a paliçada) | portões de terra prontos, sentinelas no muro, investidas maiores mas param no portão |
| C2 Farol | `hx_lighthouse` (paralela, *O Farol Apagado*) | farol aceso (luz visível), 2º navio no cais, mercador de importados |
| C3 Ginetes quebrados | `hx_riders_camp` (destruir o Acampamento dos Ginetes) | investida vira patrulha pequena; colonos montam fazenda no lugar do acampamento |
| C4 Grutas | `hx_goblin_boss` (Agitador-Mor) | Aldeia de Palafitas vira mista: goblins comerciantes (Nikki) e moradores; passagem para as Estepes abre |

**Estepes de Cinza**
| Estágio | Gatilho | O que muda |
|---|---|---|
| E0 Terra de ninguém | chegada ao Posto da Caravana | três acampamentos de guerra ativos, investidas sobre o Posto vindas dos três lados |
| E1/E2/E3 Acampamento retomado | `hx_fort_trolls` / `hx_fort_fire` / `hx_fort_war` (qualquer ordem) | o acampamento vira posto aliado (prisioneiros → colonos, ferreiro de campo), a frente dele para de mandar investida, as restantes ficam mais fortes (regra do Bastião, `RAID_RECLAIM_MULT`) |
| E4 Desertores | escolha em *Os Desertores* | ajudou: acampamento aliado com mercador orc e montaria de lobo à venda; entregou: recompensa em ouro/moedas e o acampamento some |
| E5 Caminho da montanha | os 3 acampamentos | passagem para Monte Kharzun abre; a Horda recua para a montanha |

**Monte Kharzun**
| Estágio | Gatilho | O que muda |
|---|---|---|
| K0 Sopé | chegada | acampamento avançado da Aurora, Minas e Forja controladas pela Horda |
| K1 Correntes | `hx_mines` (*Correntes Quebradas*) | escravos libertados viram ferreiros (o Ferreiro Anão melhora lendários 40+) e aliados que lutam no acampamento |
| K2 Portão | `hx_citadel_gate` | cidadela abre (portão de progressão) |
| K3 Clãs | os três Chefes de Clã | sala do trono abre |
| K4 Fim do Ato II | `hx_warlord` | Grão-Senhor cai; a Horda se rende em parte (festival no porto, como o do Bastião), *Ecos da Noite* revela o que vem do leste; tela "Fim do Ato II" |

**Ascensão (por personagem)**: `bloqueada` (nível < 35) → `disponível` (35, mestre no porto) → `concluída` (missão feita: mecânica liberada) → refinos 40/45 por talento. Conta como missão concluída (sem campo novo no save), exceto o estágio do elemental (ver Edge Cases).

### Interactions with Other Systems

| Sistema | Entra | Sai | Dono |
|---|---|---|---|
| Progression (`progression.md`) | `MAX_LEVEL` 45, faixas novas de XP, talentos 35/40/45, nós de ascensão | nível, pontos, ascensão liberada | Progression; este doc define os números das faixas novas |
| Bosses (`bosses.md`) | chefes novos com fases, `mob_pick`, `barrage`, lacaios | — | Bosses (regras); este doc define quem são e onde estão |
| Reforço por pessoas (`Balance.BOSS_CROWD_MULT`) | vale para todos os chefes novos sem mudança | — | Bosses |
| Combat & Skills (`combat-skills.md`) | skills das ascensões, regen/aura/furtividade de monstro | dano, cura, estados | Combat |
| `RaidSystem` + `GuardBrain` | rotas de investida das zonas novas, `MapsCatalog.RAIDS` | ondas, defesa | Raid (sem mudança de regra) |
| `WorldState` | condições `if`/`unless` de missão nos spawners/NPCs/investidas novos | estágios da zona | WorldState (sem mudança de regra) |
| Party / IA de bots | papéis, posição, cura; **uso das ascensões** e leitura das mecânicas novas (aura do Agitador = alvo prioritário, troll = foco com fogo/veneno, assassino = proteger quem cura) | comandos dos bots | BotBrain |
| Itens / Relicária | tiers 32/40, lendários 35/40/45, montaria lobo atroz | — | Gear |
| Save | ascensões e cenários por `quests_completed`; estágio/forma do elemental é campo novo (`save_version`) | — | SaveSystem |
| Música / Som | temas por mapa novo (`Music.MAP_THEME`), sons de orc/troll/lobo | — | Audio |

## Formulas

> Proposta do `systems-designer` (2026-11-10), baseada em `data/balance.gd`, `aura_system.gd` e nos monstros 20–30 de
> `monsters_catalog.gd`; decisões do autor marcadas. **(H)** = hipótese sem base no código, calibrar com as sondas.
> Toda constante nova vive só em `data/balance.gd`.

### F1. XP para o próximo nível (31–45) — decisão: **achatar**
A fórmula do Ato I continua (`progression.md` 3.1); só o tempo planejado por nível cresce mais devagar depois do 30.

`level_minutes(L) = XP_MIN_BASE + XP_MIN_PER_LEVEL × (L − 1)` se L < 30; `level_minutes_act1(30) + XP_MIN_PER_LEVEL_ACT2 × (L − 30)` se L ≥ 30, onde `level_minutes_act1(30)` = 6,5 + 1,75 × 29 = 57,25 (derivado, não constante)
`xp_for_level(L) = round10( level_minutes(L) × XP_KILLS_PER_MIN × mob_xp(L) ÷ (1 − XP_QUEST_SHARE) )`, 0 em `MAX_LEVEL` (45)

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| L | int | 30–44 | argumento | nível atual |
| XP_MIN_PER_LEVEL_ACT2 | float | 0.75 | data file | crescimento do tempo por nível depois do 30 (Ato I: 1.75) |
| mob_xp(L) | float | 141–204 | `6 + 4.5 × L` | XP de um monstro comum do nível |
| XP_KILLS_PER_MIN, XP_QUEST_SHARE | float | 3, 0.45 | data file | iguais ao Ato I; o divisor usa sempre o `XP_QUEST_SHARE` fixo (0,45) — o `XP_QUEST_SHARE_BAND` só escala a XP das missões (`scale_xp`) |

**Output Range:** 30→31 ≈ 44 030; 44→45 ≈ 75 mil. Faixas de ~4,9 h / 5,2 h / 5,5 h (Ato II ≈ 16 h; com a fórmula sem
achatar seriam 5,1 / 5,8 / 6,5 h).
**Example:** L = 34 → minutos 60,25; mob 159; 60,25 × 3 × 159 ÷ 0,55 = 52 252 → **52 250**.
Faixas novas: `XP_BANDS += [[30,35],[35,40],[40,45]]`, `XP_QUEST_SHARE_BAND += {30: 0.55, 35: 0.55, 40: 0.5}` **(H)**.
XP por papel: comum ×1,0 · bruto ×1,7 · elite `ELITE_XP_MULT` (6) · chefe ~×22 (Lich nível 30 = 3200 ≈ 22,7×) · escolta/lacaio 0.

### F2. Atributos dos monstros 30–45
`stat(papel, L) = ANCHOR30[papel][stat] × (1 + k_stat × (L − 30)) × mod_unidade[stat]`; DEF é somada: `def30 + d_def × (L − 30)`.

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ANCHOR30 | tabela | ver abaixo | data file | valores no nível 30 por papel, tirados dos monstros 22–30 |
| k_hp | float | 0.065 | data file | HP ×1,975 no 45 |
| k_atk | float | 0.04 | data file | ATK ×1,6 no 45 |
| d_def | float | 1.8 (comum 0.8) | data file | DEF por nível |
| mod_unidade | dict | hp/atk ×0,6–2,0 | data file (catálogo do monstro) | ajuste por unidade sobre o papel (ex.: troll `hp` ×1,8; goblin `hp` ×0,7) |

| Papel | HP 30 | ATK 30 | DEF 30 | Base no Ato I |
|---|---|---|---|---|
| comum | 720 | 60 | 12 | carniçal 22 (560/44), morcego 26 (ATK 66) |
| bruto | 1200 | 88 | 38 | horror/cavaleiro da cidadela 29 (1100–1150, 74–84) |
| elite | 3600 | 75 | 42 | cavaleiro-guarda 27 (3200/62/38) |
| chefe | 90 000 | 100 | 34 | Azhar 30 (88 mil), Senhor da Cripta |

**Output Range:** comum 45 = 1422 HP / 96 ATK; chefe 45 = 177 750 HP / 160 ATK, multiplicado por `BOSS_CROWD_MULT` como hoje.
O poder do jogador sobe ~×2 de 30 a 45 (ATK base ×1,43 × equipamento ×1,44) **(H)**: conferir com as sondas.
**Example:** Troll (bruto, tanque ×1,8 de HP) nível 38: HP 1200 × 1,52 × 1,8 = **3283**; ATK 88 × 1,32 = **116**; DEF 38 + 14,4 = **52**.

### F3. Regeneração do troll
`regen_por_s = TROLL_REGEN_PCT × max_hp`, zero enquanto queima ou está envenenado e por `TROLL_REGEN_LINGER` s depois.
Tempo efetivo para matar: `TTK_ef = T ÷ (1 − r × T)` (só vale com r × T < 1; acima disso o troll não morre).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| TROLL_REGEN_PCT (r) | float | 0.015 | data file | fração da vida por segundo |
| TROLL_REGEN_LINGER | float | 2.0 s | data file | regeneração parada depois do fogo/veneno |
| T | float | s | `max_hp ÷ dps` | tempo para matar sem regeneração |

**Output Range:** o grupo precisa de DPS acima de `r × max_hp` (abaixo disso o troll não morre: armadilha para build fraca sozinha).
**Example:** grupo de 4 com T = 10 s → r × T = 0,15 → TTK **11,8 s** (+18%); com fogo ou veneno, 10 s. Build fraca sozinha, T = 33 s → **66 s** **(H)**.

### F4. Aura do Agitador
Mesmo ritmo do `AuraSystem` (pulso 0,5 s, dura `AURA_KEEP` 1,3 s), com receptores por facção (os de hoje são só grupo/invocações).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| AGITATOR_RADIUS | float | 10 m (chefe 14) | data file | raio da aura |
| AGITATOR_AURA | dict | atk_pct 20 (chefe 30), aspd_pct 10, speed_pct 10 | data file | buff dos aliados perto |
| AGITATOR_DEMORALIZE | dict | atk_pct −15, speed_pct −10, 8 s, 12 m | data file | debuff nos aliados quando ele morre |

**Output Range:** várias auras não somam (renovam pelo id); some 1,3 s depois de o Agitador morrer ou de o aliado sair do raio.
**Example:** Guerreiro Orc nível 37, ATK 88 × 1,28 = 112,6 → com a aura **135**; depois da morte do Agitador, 95,7 por 8 s.

### F5. Orçamento de poder da ascensão — decisão: **+20% no total**
`ganho(tier) = ASC_GAIN[tier]`, `ASC_GAIN = [0.08 (35), 0.06 (40), 0.06 (45)]`, aplicado por `ASC_BUILD_POWER[build]` (padrão 1,0,
mesmo padrão de `BUILD_POWER`).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ASC_GAIN | array | 0.06–0.08 | data file | ganho por tier |
| razão | float | 1,06–1,10 (35), ≤ 1,215 (45, multiplicativo: 1,08 × 1,06 × 1,06) | `boss_probe --comp` | tempo do grupo de 4 sem ÷ com a ascensão |

**Output Range:** o ganho de cada build (razão − 1, em pontos percentuais) a ±3 p.p. da média das 24; `combat_probe` 0 FLAG; sempre
abaixo de um terço do ganho da teia (ATK ×1,3–1,5). Ascensões de utilidade (Bispo, Necromante, Druida) são medidas sob pressão
(`boss_probe --comp --dmg=6`): o ganho é a queda relativa de mortes por luta com/sem a ascensão, com o mesmo alvo (6–10% aos 35).
**Example:** Gêmeos mata o chefe em 100 s sem a Empunhadura de Titã e em 92 s com ela → razão **1,087**, dentro da faixa.

### F6. Evolução do elemental
`elem_xp += max(1, xp_do_abate ÷ mob_xp(nível_do_monstro))` por abate **que dá XP** (escolta e lacaio com 0 XP não contam) a até `ELEM_XP_RADIUS` do mago; teto `ELEM_XP_MAX` (400).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ELEM_XP_RADIUS | float | 13 m | data file | igual ao alcance de assistência das invocações |
| ELEM_STAGE_XP | array | [120 Maior, 400 Ancestral] | data file | limiares acumulados (~40 min e ~2,2 h no ritmo solo) |
| ELEM_STAGE_MULT | tabela | ver abaixo | data file | multiplicadores do estágio |
| ELEM_SWAP_CD | float | 20 s | data file | recarga da troca de forma (mantém estágio e % de vida) |
| ELEM_DEATH_LOSS | float | 0.10 | data file | parte do `elem_xp` perdida se o elemental morre **(H)** |

| Estágio | HP | ATK | Área |
|---|---|---|---|
| Básico | ×1,0 | ×1,0 | ×1,0 |
| Maior | ×1,6 | ×1,4 | ×1,15 |
| Ancestral | ×2,4 | ×2,0 | ×1,3 |

**Output Range:** `elem_xp` 0–400. O ATK de invocação já é limitado (`SUMMON_ATK_MAX` 2,5): o multiplicador do estágio vem
**depois** do limite, senão some no 35+.
**Example:** 30 comuns nível 36 (1 cada) + 2 chefes (22 cada) = **74** → ainda Básico.

### F7. Empunhadura de Titã
`razão_dps = (1 + TITAN_OFFHAND_MULT) × (1 − (TITAN_ASPD_PEN − TITAN_WEB_RELIEF × n))`, n = nós da teia (0–3).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| TITAN_OFFHAND_MULT | float | 0.45 | data file | dano da 2ª arma de 2 mãos (a mão secundária comum usa 0,6; a de 2 mãos tem mais ATK) **(H)** |
| TITAN_ASPD_PEN | float | 0.25 | data file | perda de velocidade de ataque |
| TITAN_WEB_RELIEF | float | 0.03 | data file | quanto cada nó da teia devolve |

**Output Range:** 1,0875 com n = 0 (+8,75%, bate com F5) até 1,218 com n = 3; nunca passa de +25%.
**Example:** machado de 2 mãos com 100 de DPS sozinho → **108,75** sem nós, **121,8** com 3 nós.

### F8. Combate montado (Paladino)
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| MOUNT_FIGHT_SPEED_MULT | float | 1.3 | data file | velocidade montado em combate (fora de combate continua `MOUNT_SPEED_MULT` 1,7) |
| MOUNT_REACH_BONUS | float | 0.8 m | data file | alcance a mais do básico montado |
| MOUNT_CHARGE_DIST | float | 11.2 m (`DASH_DISTANCE` × 3,5; lança pesada ×1,3) | data file | distância da Carga Montada; para em parede/água |
| MOUNT_CHARGE_POWER / CD | float | 1.6 × ATK / 14 s | data file | **(H)** |
| MOUNT_TRAMPLE | dict | raio 3,5, poder 0,9, recarga 8 s | data file | Pisotear **(H)** |
| MOUNT_CC_IMMUNE | float | 2 s | data file | imune a controle depois de cair (evita atordoar em cadeia) **(H)** |

Derrubam: atordoar, prender, gancho. Lentidão não derruba. Remontar leva `MOUNT_CAST_TIME` (1,5 s).
**Example:** paladino a 5,5 m/s a pé → **9,35** montado fora de combate, **7,15** montado em combate.

### F9. Coro Celeste (Bispo): barreira, anjo, bênçãos e ressurreição
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| BARRIER_TIME / RADIUS / CD | float | 8 s / 5 m / 30 s | data file | cúpula: −30% de dano dentro (`BARRIER_DR`), projéteis de fora param na borda |
| BARRIER_LAG | float | 2 m/s | data file | quanto a cúpula anda mais devagar que o Bispo (Batalha: 0) |
| BARRIER_HOLD | float | 3 s (45) | data file | ao lançar, a vida de quem está dentro não cai abaixo de 1 (antigo Santuário) |
| ANGEL_TIME / CD / HEAL | float | 30 s / 40 s / power 0,6 por 1,5 s | data file | Anjo Guardião, cura pela WILL do Bispo **(H)** |
| BLESS_* | dict | Asas: +15% mov./ataque · Égide: +12% DEF/MDEF, 4% de cura por golpe; 20 s, recarga 25 s | data file | bênçãos de grupo **(H)** |
| RES_HP_PCT / CAST / RANGE / CD | float | 0,35 / 2,5 s / 15 m / 120 s | data file | ressurreição em combate, uma por aliado por luta **(H)**; "luta" = do primeiro golpe num chefe até ele morrer ou resetar (`reset_boss`); fora de chefe, até o `combat_timer` do grupo zerar |
| RES_BATTLE_SHIELD | float | 0,20 do HP por 6 s | data file | refino do Clérigo de Batalha |

**Output Range:** barreira cobre ~27% de um ciclo de 30 s com −30% de dano; o "não morre" é só 3 s e só aos 45 (com o reforço
do chefe chegando a ×5, segurar mais que isso trivializa). Anjo + bênçãos entram no orçamento F5 (ascensão de utilidade).
**Example:** chefe tirando 20% da vida por segundo do grupo → dentro da barreira 14%/s; ao lançar aos 45, ninguém cai abaixo de 1
por 3 s; o anjo cura ~0,6 × WILL-escala por 1,5 s no mais ferido.

### F9b. Novas mecânicas de ascensão (Paladino, Berserker, Lanceiro) — **(H)**, calibrar na fase
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| ARCANE_MP_PER_S | float | 2–4 MP/s | data file | custo do Modo Arcano ligado |
| ARCANE_MAGIC_SHARE | float | INT/WILL 1,0, FOR 0,5 | data file | de onde vem o dano mágico no Modo Arcano |
| GLORY_MAX / GLORY_STEP | int / float | 5 / +0,2 de power por Glória | data file | Modo Gladiador |
| GLADIATOR_STANCE | dict | +10% dano, −10% DEF | data file | postura |
| DRAGON_JUMP_AIR | float | 1,2 s | data file | tempo fora do chão no Salto Dracônico (intocável) |
| DRAGON_JUMP_POWER | float | 2,2 centro / 1,0 borda | data file | dano da queda |
| SHOUT_TIME / CD / BUFF | float | 12 s / 20 s / +10% | data file | Brados Elementais |

Todas entram no orçamento F5 (+8% aos 35 sobre a build sem ascensão); o Salto Dracônico conta como esquiva longa: medir no
`combat_probe` (dash e salto não podem deixar o lanceiro intocável mais de 25% do tempo de luta).

### F10. Equipamento 35/40/45 — decisão: **moedas sem mudança (7/8/9)**
`gear_factor(L) = (L + 4) ÷ 28` (linear, já existe) → 30: 1,214 · 35: 1,393 · 40: 1,571 · 45: 1,75. `LEGENDARY_MULT` 1,2 igual.
`LEGENDARY_LEVELS += [35, 40, 45]` (índices 6, 7, 8); `COMMON_TIER_LEVELS += [32, 40]`.
Bônus percentuais de conjunto acima do índice 5 crescem pela metade, para não somar demais com a ascensão:
`i_ef = min(i, 5) + 0,5 × max(0, i − 5)` e `bônus% = base + por_tier × i_ef` (com `base`/`por_tier` atuais de `Balance.SET_*`) →
4 peças 42/44/46% de dano de skill (Ato I: 40%), 5 peças 17/18/19%, recarga 21/22/23% (valores conferidos por check).
Atributos continuam lineares. Preço em moedas `i + 1` = **7 / 8 / 9** (decisão do autor: o lendário do Ato II é objetivo de longo prazo).

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| L | int | 32–45 | catálogo | nível do item |
| i | int | 6–8 | `LEGENDARY_LEVELS` | índice do tier lendário |
| i_ef | float | 5,5–6,5 | calculado | índice efetivo dos bônus percentuais |

**Example:** lendário nível 40: fator de atributo 1,571 × 1,2 = **1,89** do item base 24; custa **8 moedas**.

## Edge Cases

> `systems-designer` não consultado nesta seção — modo lean. Revisar antes da produção.

**Travessia e progressão**
- **Se o jogador tem nível 30 mas não concluiu `dw_epilogue`**: o capitão recusa com o texto do portão ("Termine o que começou em Aldara").
- **Se um save do Ato I (nível 30, XP 0) carrega com o cap novo**: o personagem continua no 30 com XP 0 e passa a ganhar XP normalmente; não recebe pontos retroativos.
- **Se um bot de nível < 30 está no grupo do jogador que zarpa**: o portão vale só para o jogador (regra atual); o bot segue o líder, mas não escolhe Kharzun sozinho para caçar (fora do `level_range`).
- **Se o jogador volta ao Bastião no meio do Ato II**: tudo do Ato I continua como estava; o estágio das zonas de Kharzun não muda sem ele.

**Cenários que crescem**
- **Se a missão que muda o estágio é concluída com o jogador em outro mapa**: o estágio vale na próxima vez que o mapa carregar (WorldState lê `quests_completed` ao montar spawners/NPCs).
- **Se monstros de um estágio antigo estão vivos quando o estágio muda**: eles ficam até morrer ou até o mapa recarregar; nascimentos novos seguem o estágio novo (sem sumir monstros na frente do jogador).
- **Se os três acampamentos são retomados fora de ordem**: qualquer ordem vale; a última frente ativa recebe o reforço da regra do Bastião (`RAID_RECLAIM_MULT`, ×2 e líder).
- **Se o jogador entrega os Desertores**: o acampamento aliado nunca aparece; a montaria de lobo continua disponível pelos *Ovos do Lobo Atroz* em Kharzun (nenhum conteúdo fica inacessível por causa da escolha).

**Horda**
- **Se o Agitador morre com o aliado fora do raio**: o aliado não recebe o desânimo (só quem está a 12 m na hora).
- **Se dois Agitadores cobrem o mesmo orc**: a aura não soma (mesmo id renova); matar um não tira a aura do outro.
- **Se o troll está queimando e envenenado ao mesmo tempo**: a regeneração para uma vez só; volta 2 s depois do último efeito acabar.
- **Se o DPS do grupo é menor que a regeneração do troll**: o troll não morre; ele não reseta enquanto houver alguém em combate (o grupo precisa de fogo/veneno ou sair). Bots com fogo/veneno priorizam o troll.
- **Se o assassino some com a vida baixa**: a furtividade não cura; ele reaparece pelas costas de quem cura/atira (alvo `soft`), nunca do tanque.
- **Se a rede do Saqueador pega alguém montado**: derruba do cavalo (é "prender").

**Ascensões**
- **Se o Paladino montado é atordoado**: cai, fica 2 s imune a controle, e remontar leva 1,5 s.
- **Se o Paladino tenta montar dentro de masmorra**: proibido (regra atual de montaria); a ascensão vale onde montar vale.
- **Se o elemental morre**: perde 10% do `elem_xp` mas nunca cai de estágio (o estágio só sobe).
- **Se o mago troca de forma com o elemental ferido**: a nova forma nasce com a mesma % de vida; recarga 20 s.
- **Se o save é de antes do Ato II**: `elem_xp` = 0, forma = a do último elemental; `save_version` sobe e a migração preenche o padrão.
- **Se o Berserker sem ascensão tenta pôr arma de 2 mãos na secundária**: recusa com "requer Empunhadura de Titã"; se perder o acesso (respec não tira ascensão, então não acontece), a arma volta para a bolsa.
- **Se duas Barreiras se sobrepõem**: não somam; vale a de maior tempo restante.
- **Se alguém leva dano no exato tick em que o "segura em 1" (45) termina**: vale até o fim do tick (dano aplicado antes da expiração no mesmo tick é segurado em 1).
- **Se o Bispo corre mais que a Barreira**: a cúpula fica para trás (anda `BARRIER_LAG` mais devagar) — quem segue o Bispo sai dela; os bots seguem a cúpula, não o Bispo.
- **Se o Anjo é atacado**: monstros não o miram (como o clone de sombra); ele some se o Bispo morrer.
- **Se o Pássaro Arcano é atingido por golpe de chão**: a sim é plana, então ele leva o golpe normalmente (o voo é só visual).
- **Se a Marca da Cova levanta um chefe ou elite**: não levanta (só monstros comuns).
- **Se a ressurreição em combate é usada em quem já foi ressuscitado nesta luta**: recusa ("já voltou nesta luta").
- **Se o chefe tem golpe de execução ou fúria final**: o "segura em 1" da Barreira (45) vale, mas a regra do chefe pode furar (decisão por chefe em `bosses.md`, nunca global).
- **Se o clone de sombra recebe aggro**: o clone não segura aggro (monstros o ignoram); ele some ao fim do tempo ou se o dono morrer.
- **Se a Forma de Lich termina com mais invocações que o limite normal**: as que passam do limite somem da mais antiga para a mais nova.
- **Se o Pacto Sombrio é lançado com invocações longe**: só as que estão a 15 m recebem; as que chegam depois não.
- **Se o Lanceiro está no ar quando o alvo morre ou some**: cai no ponto mirado mesmo assim (o salto não persegue).
- **Se o Lanceiro salta sobre água/parede**: a queda é ajustada para o chão andável mais perto do ponto mirado (`MapGeometry`).
- **Se o chefe estava mirando o Lanceiro quando ele salta**: o chefe perde o alvo e volta ao maior de ameaça (normalmente o tanque).
- **Se o Paladino liga o Modo Arcano montado**: desmonta antes (as duas coisas não ficam juntas).
- **Se a MP acaba no Modo Arcano**: o modo desliga e entra a recarga de 20 s.
- **Se a Corrente de Luz mira um chefe**: não puxa (regra atual do `pull`), só provoca por 3 s.
- **Se o Berserker sai do Modo Gladiador com Glória acumulada**: a Glória zera (só existe na postura); Punhos guarda por 6 s.

## Dependencies

**Depende de (upstream)**
| Sistema | Tipo | Interface |
|---|---|---|
| Progression (`progression.md`) | **forte** | nível máximo, curva de XP, teia, talentos de classe; o Ato II estende as faixas e as linhas de talento |
| Bosses (`bosses.md`) | **forte** | fases, `mob_pick`, `barrage`, `berserk_after`, reforço por pessoas (`BOSS_CROWD_MULT`) |
| Combat & Skills (`combat-skills.md`) | **forte** | skills das ascensões, estados (prender, atordoar, queimar, envenenar), formas, invocações |
| `WorldState` (core/sim/systems/world_state.gd) | **forte** | estágios dos cenários por `quests_completed` |
| `RaidSystem` / `GuardBrain` | **forte** | investidas no porto, nas estepes e defesas |
| Party + IA dos bots (`BotBrain`, `PartySystem`) | **forte** | bots seguem, defendem, usam ascensões e leem as mecânicas novas |
| Pipeline de zonas (`tools/blender/zones/`, `places.py`, `build_dungeons.py`) | **forte** | mapas, colisão, lugares, masmorras |
| Gear (`gear_catalog.gd`, Relicária) | **forte** | tiers comuns e lendários novos |
| Montaria (H, cavalo) | **forte para o Paladino** | combate montado parte do estado montado que já existe |
| Música / Som (`Music`, `Sfx`) | fraca | temas e sons novos; sem eles o jogo roda mudo nesses mapas |

**Dependem dele (downstream)**: o futuro Ato III (gancho de *Ecos da Noite*), roteiros `docs/roteiro_30_35.md` / `35_40` /
`40_45`, os probes (`band_probe`, `boss_probe`, `raid_probe`, `web_probe --level=45`) que ganham faixas e chefes novos.

**Bidirecionalidade a corrigir**: `progression.md` e `bosses.md` ainda dizem "1 a 30" e não citam o Ato II; ao aprovar este
documento, acrescentar neles uma linha "estendido por `ato2-horda.md`".

## Visual/Audio Requirements

> `art-director` e `audio-director` não consultados — modo lean. Revisar antes da produção dos modelos.

**Leitura de cima (câmera alta, 52°)** — o que define cada zona é o chão e as manchas de cor:
- **Costa**: areia clara, mar turquesa com espuma na borda, mangue verde-escuro com palafitas marrons, paliçada de troncos
  claros (nova) contra pedra antiga da Aurora no Santuário Afogado; o farol branco com faixas é o marco.
- **Estepes**: capim dourado queimado, manchas de cinza cinzenta, rio largo azul-acinzentado, acampamentos de estacas escuras
  com estandartes vermelhos da Horda; o Totem Partido é o marco.
- **Kharzun**: rocha escura e basalto, rios de lava laranja (colidem como água), fumaça das forjas, cidadela entalhada no pico.
- **Mudança por estágio** precisa ser visível de cima: paliçada completa, farol aceso (luz), fazendas no lugar do acampamento
  dos ginetes, estandartes trocados (vermelho da Horda → branco-dourado da Aurora) nos acampamentos retomados.

**A Horda (modelos em `mob_kit`, chibi toon + contorno)**: orc = humanoide chibi com presas, pele verde-acinzentada, ombreiras
de osso/ferro escuro; **cada estágio da linha mais pesado e mais enfeitado** que o anterior (recruta de couro → guerreiro de
ferro → senhor da guerra com chifres e estandarte nas costas). Goblin = baixo, orelhas grandes, lança; o Agitador com tambor.
Troll = grande e curvado, pele cinza-azulada, pedras incrustadas; regeneração **visível** (brilho verde pulsando; some quando
queima). Ginete = lobo (`quadruped(kind="wolf")`) + goblin montado. Assassino com capuz e brilho de veneno nas facas. Naga
com cauda e escamas turquesa.

**Mecânicas que o grupo precisa ler**: aura do Agitador (anel vermelho no chão em volta dele e dos buffados), rede do Saqueador
(projétil visível + rede no alvo), chuva de flechas de fogo (círculos avisados, já existe), troll regenerando (brilho), assassino
reaparecendo (fumaça + aviso curto antes do golpe).

**Ascensões**: Paladino montado com clipes `ride_attack`/`ride_charge`; elemental com **três estágios visíveis** por forma
(tamanho, partículas e detalhe crescem); Berserker com o segundo machado de 2 mãos na esquerda (o kit já tem o nó da mão
secundária); Barreira Sagrada como cúpula de luz que anda com o Bispo e Anjo Guardião voando atrás dele; clone de sombra
semitransparente; Forma de Lich e nuvem de Miasma; Ent, Lobo Alfa e Pássaro Arcano (forma alada, penas de luz); tigre.

**Áudio**: temas novos (CC0 do OpenGameArt, `build_music.py`, licença conferida por faixa): porto (mar, esperança tensa),
costa, estepes (tambores), Kharzun (pesado), cidadela/raide; os temas "chefe" e "investida" do Ato I valem aqui. Sons novos em
`build_sfx.py`: grito orc, tambor do Agitador (laço enquanto a aura vive), troll, uivo de lobo, rede, cavalo galopando em combate.

## UI Requirements

- **Janela do elemental** (Elementalista com ascensão): estágio atual, barra de experiência até o próximo, forma e modo, troca
  de forma (com recarga). Pode morar na janela de skills (K) ou num quadro perto da barra de vida.
- **Combate montado**: a barra de ação mostra as skills montáveis acesas e as outras apagadas enquanto montado; ícone de
  "derrubado" ao cair do cavalo.
- **Ascensão**: entrada própria na janela K (aba Talentos) com a mecânica liberada e os refinos 40/45.
- **Estágio da zona**: o L (quests/roteiro) mostra o que cada missão principal vai mudar no cenário ("ao concluir: o farol acende").
- **Escolha dos Desertores**: diálogo com duas respostas e o resumo do que cada uma faz.
- **Tela "Fim do Ato II"** (como a do Ato I em `hud.gd`).
- Nada de UI nova para regeneração/aura de monstro além do visual no corpo e da barra de buffs/debuffs que já existe.

> 📌 **UX Flag — Ato II**: este sistema tem requisitos de UI (janela do elemental, barra montada, ascensão na K). Antes das
> histórias de UI, rodar `/ux-design` para essas telas.

## Cross-References

| Este documento usa | Do documento | Seção |
|---|---|---|
| curva de XP, teia, talentos de classe, `points_at` | `design/gdd/progression.md` | 2.1, 2.2, 2.5, 3.1–3.4 |
| fases, `mob_pick`, `barrage`, `berserk_after`, reforço por pessoas | `design/gdd/bosses.md` | 2.1–2.4, 3 |
| formas, invocações, estados, dano de fogo/veneno | `design/gdd/combat-skills.md` | — |
| layout de zona (vale, hub, POIs, marco, leitura de cima) | `.claude/docs/ragnaex/zonas.md` | Layout de zonas |
| conquista por `WorldState`, investidas, fortes | `docs/DESIGN.md` / `docs/roteiro_20_30.md` | Mundo / Bastião |
| linha de foras da lei estilo Wesnoth (precedente de arquétipo) | memória outlaw-line, `mob_kit.outlaw_parts` | — |
| IA de grupo por papel, `boss_probe --comp` | `docs/DESIGN.md` | IA dos bots no combate |

## Acceptance Criteria

> Rascunho do `qa-lead` (2026-11-10), com as 11 ambiguidades que ele apontou resolvidas no texto acima. Verificação: **check** =
> `check(...)` em `tools/tests/run_tests.gd` (nomes `_check_*` abaixo são **propostos**; hoje só existem `_check_places`,
> `_check_music`, `_check_web_strength`, `_check_build_entries`, `_check_catalog_keys`) · **sonda** = comando headless com alvo ·
> **evidência** = screenshot guardado em `production/qa/evidence/`.

### Travessia / Progressão
- **AC-01 (R1)** **GIVEN** jogador nível 30 sem `dw_epilogue`, **WHEN** fala com o Capitão Bren, **THEN** não viaja e vê "Termine o que começou em Aldara"; com nível 30 e `dw_epilogue` chega em `city_port`; a volta não tem portão. — check `_check_act2_gate`.
- **AC-02 (R1)** **GIVEN** bot nível 32 sem grupo no Bastião, **WHEN** escolhe onde caçar, **THEN** usa o portal-NPC e caça num mapa de Kharzun; bot nível 28 nunca escolhe Kharzun sozinho. — check `_check_act2_bot_travel`.
- **AC-03 (R1)** **GIVEN** cristal de Porto Esperança vinculado, **WHEN** aperta G, **THEN** chega ao cristal. — check `_check_act2_gate`.
- **AC-04 (R7)** **GIVEN** `MAX_LEVEL` 45, **THEN** `xp_for_level(45)` = 0, `XP_BANDS` tem 30–35/35–40/40–45, há linhas de talento aos 35/40/45 com 3 escolhas cada e `points_at(40)` = 9 (os demais 31–45 = 8). — check `_check_act2_progression`.
- **AC-05 (F1)** **GIVEN** L = 34, **THEN** `xp_for_level(34)` = 52 250; 30→31 ≈ 44 030 (±1%); 44→45 ≈ 75 390 (±1%); `level_minutes` cresce 0,75 por nível de 30 a 44. — check `_check_act2_xp_curve`.
- **AC-06 (save)** **GIVEN** save do Ato I (nível 30, XP 0, sem `elem_xp`), **WHEN** carrega, **THEN** fica no 30 com XP 0, sem pontos retroativos, `elem_xp` = 0, forma = a do último elemental, `save_version` sobe; usa `TEST_SLOT`. — check `_check_act2_save_migration`.

### Cenários
- **AC-07 (R2)** **GIVEN** as 3 zonas novas, **THEN** cada uma tem os 4 tipos de lugar, tudo alcançável a pé, `level_range` na faixa e tema de música. — checks `_check_places`, `_check_music`.
- **AC-08 (R2/R8)** **GIVEN** cada zona, **WHEN** passa por `/layout-zone`, **THEN** nota ≥ 8 em ≤ 6 iterações. — evidência: `CAM_top`/`CAM_game`/`CAM_poi` + tour `--tour=<pasta> --tour_map=<zona>`.
- **AC-09 (R4)** **GIVEN** `quests_completed` com o gatilho de cada estágio (C1–C4, E1–E5, K1–K4), **WHEN** o mapa monta spawners/NPCs/investidas, **THEN** o conteúdo é o do estágio; sem o gatilho, o anterior. — check `_check_act2_stages` (tabela).
- **AC-10 (R4)** **GIVEN** monstros do estágio antigo vivos, **WHEN** o estágio muda, **THEN** eles ficam até morrer e os nascimentos novos seguem o estágio novo. — check `_check_act2_stages`.
- **AC-11 (WorldState)** **GIVEN** os 3 acampamentos retomados em cada uma das 6 ordens, **THEN** a frente restante recebe `RAID_RECLAIM_MULT` e líder; depois dos 3, abre a passagem para Kharzun. — check `_check_act2_forts`.
- **AC-12 (E4)** **GIVEN** Desertores entregues, **THEN** o acampamento aliado não aparece e os Ovos do Lobo Atroz continuam disponíveis. — check `_check_act2_stages`.
- **AC-13 (R4)** **GIVEN** porto em C0 e em C3, **WHEN** roda a investida, **THEN** é repelida sem `presos`, o intervalo em C0 é 240 s ±20% e a leva em C3 é menor que em C0. — sonda `raid_probe -- --trials=20 --bots=0,1,3`.
- **AC-14 (R5)** **GIVEN** cada faixa nova, **THEN** 8–10 principais, toda cabana com cadeia de 2–4, todo giver existe, XP de missão 40–50% da faixa. — checks de missão existentes + sonda `band_probe -- --from=30 --to=45 --only=audit`.

### Horda
- **AC-15 (R3)** **GIVEN** o estágio de cima de cada linha, **THEN** nasce com `escort` dos de baixo. — check `_check_horde_lines`.
- **AC-16 (F2)** **GIVEN** monstros 30–45, **THEN** HP/ATK/DEF = fórmula F2 com `mod_unidade` (±2%); Troll 38 = 3283/116/52. — check `_check_horde_stats`.
- **AC-17 (F3)** **GIVEN** troll a 50% de vida, **WHEN** passa 1 s sem dano, **THEN** cura 1,5% do HP máximo; queimando ou envenenado cura 0 até 2 s depois do último efeito. — check `_check_troll_regen`.
- **AC-18 (F4)** **GIVEN** Guerreiro Orc 37 a 10 m de um Agitador, **THEN** ATK = 135; dois Agitadores não somam; morto o Agitador, a aura some em ≤ 1,3 s, quem está a ≤ 12 m fica com ATK 95,7 por 8 s e quem está a 13 m não. — check `_check_agitator_aura`.
- **AC-19 (R3)** **GIVEN** assassino furtivo, **WHEN** reaparece, **THEN** mira quem cura ou atira, nunca o tanque, e a furtividade não cura; a rede derruba quem está montado. — check `_check_horde_ai`.
- **AC-20 (bots)** **GIVEN** grupo de bots com fogo/veneno contra troll + Agitador, **THEN** o primeiro alvo focado é o Agitador e quem tem fogo/veneno ataca o troll. — check `_check_horde_ai`.
- **AC-21 (R8)** **GIVEN** a faixa 30–45, **THEN** `band_probe` dá 0 `travou` e tempo por abate a ±25% da faixa 20–30. — sonda `band_probe -- --from=30 --to=45 --trials=16 --why`.

### Chefes
- **AC-22 (R8)** **GIVEN** cada chefe novo, **THEN** grupo completo de 4 vence ≥ 95% com 0,3–1 morte por luta e grupo de 4 sorteado vence 65–85%, com `BOSS_CROWD_MULT` sem mudança. — sonda `boss_probe -- --comp=<...> --trials=40 --boss=<id>`.
- **AC-23 (K4)** **GIVEN** `hx_warlord` concluída, **THEN** festival no porto e tela "Fim do Ato II". — check do estágio + evidência: screenshot.

### Ascensões
- **AC-24 (R6)** **GIVEN** classe nível 35 sem a missão, **THEN** a mecânica fica travada; concluída a missão, liberada em todas as builds; o respec não a tira. — check `_check_ascensions`.
- **AC-25 (R6, bots)** **GIVEN** bot ascendido de cada classe, **WHEN** luta 60 s contra um chefe, **THEN** usa a ascensão ≥ 1 vez. — check `_check_ascension_bots`.
- **AC-26 (F5)** **GIVEN** cada build com e sem a ascensão, **THEN** razão de tempo 1,06–1,10 aos 35 e ≤ 1,215 aos 45; o ganho de cada build a ±3 p.p. da média; utilidade (Bispo, Necromante, Druida) medida pela queda de mortes a `--dmg=6` no mesmo alvo; `combat_probe` 0 FLAG. — sonda `boss_probe --comp` (+ `--dmg=6`) e `combat_probe -- --class=<id>`.
- **AC-27 (F6)** **GIVEN** 30 comuns nível 36 + 2 chefes mortos a ≤ 13 m do mago, **THEN** `elem_xp` = 74 e Básico; aos 120, Maior; lacaio/escolta com 0 XP não soma; morte perde 10% sem cair de estágio; trocar de forma mantém estágio e % de vida, recarga 20 s; o ATK do estágio vem depois de `SUMMON_ATK_MAX`. — check `_check_elemental_evolution`.
- **AC-28 (F7)** **GIVEN** machado de 2 mãos com 100 de DPS, **THEN** 108,75 com n = 0 e 121,8 com n = 3; sem a ascensão, a mão secundária recusa com "requer Empunhadura de Titã". — check `_check_titan_grip`.
- **AC-29 (F8)** **GIVEN** paladino a 5,5 m/s, **THEN** 9,35 montado fora de combate e 7,15 em combate; Carga anda 11,2 m e para em parede/água; atordoar/prender/gancho derrubam, lentidão não; 2 s imune depois de cair; remontar 1,5 s; não monta em masmorra. — check `_check_mounted_combat`.
- **AC-30 (F9)** **GIVEN** grupo dentro da Barreira Sagrada, **THEN** o dano recebido cai 30%, projétil vindo de fora para na borda, a cúpula anda 2 m/s mais devagar que o Bispo (Batalha: igual) e duas barreiras não somam; aos 45, ao lançar, ninguém dentro cai abaixo de 1 por 3 s, inclusive no tick da expiração; o Anjo cura o tanque primeiro e não é mirado; ressuscitar o mesmo aliado 2× na mesma luta é recusado; bots do grupo entram e ficam na cúpula. — check `_check_choir`.
- **AC-30b (R6.1)** **GIVEN** Necromante ascendido, **THEN** invocações temporárias duram ×1,5 e cabe +1 por tipo; Pacto Sombrio dá +25% de dano às invocações a 15 m; Miasma tira 20% de ATK de quem está dentro; Marca da Cova levanta comum (não chefe/elite) como aliado por 15 s. — check `_check_lord_of_dead`.
- **AC-30c (R6.1)** **GIVEN** Xamã ascendido, **WHEN** entra no Pássaro Arcano, **THEN** troca as magias pelas variantes da forma, como Lobo/Urso hoje, e o golpe de chão o atinge normalmente. — check `_check_ancestral_forms` + evidência `lineup --strip=druid --set=xama --form=bird`.
- **AC-31b (R6.1)** **GIVEN** Paladino ascendido, **THEN** a Corrente de Luz puxa monstro comum e só provoca chefe; o Modo Arcano abre as asas, troca o básico por dano mágico pela INT/WILL, consome MP e desmonta se estiver montado. — check `_check_paladin_ascension` + evidência `--autostart=paladin --screenshot` com as asas.
- **AC-31c (R6.1)** **GIVEN** Berserker no Modo Gladiador, **THEN** abate e crítico dão Glória (máx. 5), as Lâminas Elementais aplicam o elemento e ficam mais fortes com Glória, o Golpe Final gasta 5, e sair da postura zera a Glória (Punhos: 6 s). — check `_check_gladiator`.
- **AC-31d (R6.1)** **GIVEN** Lanceiro ascendido, **WHEN** usa o Salto Dracônico, **THEN** fica 1,2 s sem levar golpe/projétil/chuva, o chefe que o mirava volta ao tanque, e a queda causa 2,2/1,0 no ponto mirado (ajustado para chão andável); com Brado ativo, a queda leva o elemento; só um Brado por vez (45: dois por 8 s). — check `_check_dragon_lancer`; sonda `combat_probe -- --class=ranger` (tempo intocável ≤ 25%).
- **AC-31 (R6)** **GIVEN** clone de sombra, **THEN** monstros não o miram e ele some com o dono; execução vale abaixo de 25%; o fim da Forma de Lich remove o excesso de invocações da mais antiga para a mais nova. — check `_check_ascensions`.

### Equipamento
- **AC-32 (F10)** **GIVEN** lendários 35/40/45, **THEN** 144 conjuntos (72 da build + 72 híbridos), fator 40 = 1,89, preço 7/8/9 moedas, 4 peças 42/44/46%; tiers comuns aos 32 e 40. — checks `_check_act2_gear` + `_check_build_entries`.
- **AC-32b (R7.1)** **GIVEN** os conjuntos 35/40/45 de uma classe, **THEN** são 3 por tier (A+B, B+C, C+A); cada um tem 5 peças de armadura do lado A, atributo principal de A e secundário de B, e as armas das duas builds como peças alternativas (não contam no total); os bônus de 2/3/4/5 peças seguem R7.1; cada híbrido aparece na aba da Relicária das duas builds. — check `_check_hybrid_sets` + evidência `--bag_shot=<png> --wins= --relic`.
- **AC-32c (R7.1, bots)** **GIVEN** bot da build A com a teia mais comprada no braço B, **WHEN** escolhe lendário 35+, **THEN** pega o híbrido A+B. — check `_check_hybrid_sets`.
- **AC-33** **GIVEN** lendário 40+, **WHEN** K1 está ativo, **THEN** o Ferreiro Anão aprimora a peça. — check `_check_act2_stages` + evidência `--bag_shot=<png> --wins= --enhance`.

### Desempenho / Qualidade
- **AC-34** **GIVEN** testes completos + `--autostart` com classe ascendida, **THEN** 0 failed e 0 `SCRIPT ERROR`.
- **AC-35** **GIVEN** kits com as peças novas, **THEN** cada kit < 200 malhas. — check existente.
- **AC-36** **GIVEN** Kharzun carregado e o porto em investida com 10+ bots, **THEN** `sim_probe` ≤ 5 ms/tick em média e nenhum trecho < 25 FPS no `PerfWatch`. — sondas `sim_probe -- --phases` e `--perf --perf_at=<porto>`.

Valores **(H)** de Formulas (F3 66 s, Carga/Pisotear, `RES_*`, `ELEM_DEATH_LOSS`, poder do jogador ×2) são hipóteses: os critérios
checam a mecânica, e cada número é calibrado pela sonda na fase em que entra.

## Open Questions

| # | Pergunta | Dono | Quando resolver |
|---|---|---|---|
| 1 | O que exatamente vem do leste (a "noite" de Azhar, outra coisa)? Só o suficiente para *Ecos da Noite* — o Ato III decide o resto | autor | antes das missões de Kharzun (fase 3) |
| 2 | Visual próprio dos 72 conjuntos lendários: ordem por classe e quanto reaproveitar dos conjuntos de nível 30 | autor + art-director | fase 4 (polimento) |
| 3 | Valores marcados **(H)** em Formulas (quest share das faixas novas, poder do jogador ×2, tempo do troll solo, perda de `elem_xp`, Carga/Pisotear, ressurreição, imunidade depois de cair) | systems-designer + sondas | cada um na fase em que a mecânica entra |
| 4 | Combate montado vale para outras classes depois (ex.: Ranger atirador montado)? Hoje é só a ascensão do Paladino | autor | depois da fatia 1 |
| 5 | Montaria lobo atroz (*Ovos do Lobo Atroz*): só visual ou mais rápida que o cavalo? | autor | fase 3 |
| 6 | ~~As cinco ascensões propostas~~ — **resolvida** (2026-11-10): Assassino aprovado; Necromante → invocações mais longas + Pacto + debuffs em área; Druida aprovado + Pássaro Arcano no Xamã; Bispo → Coro Celeste (anjo, barreira móvel, bênçãos). Ranger: **Lanceiro Dracônico** definido (salto + brados); pendente só confirmar tigre (Caçador) e torreta (Atirador). Paladino ganhou Corrente de Luz + Modo Arcano com asas; Berserker ganhou Modo Gladiador | autor | antes de implementar Caçador/Atirador |
| 10 | Paladino: "skill de puxar, asas, modo arcano" foi lido como Corrente de Luz (puxa) + Modo Arcano com asas de luz — confirmar a leitura | autor | antes de implementar o Paladino (fase 1) |
| 9 | ~~Híbridos substituem ou coexistem?~~ — **resolvida**: coexistem (144 conjuntos). Pendente: os 24 efeitos de Fusão (5 peças), um por par | autor + systems-designer | antes do lendário 35 (fase 1) |
| 7 | Leitura das mecânicas novas pelos bots (focar o Agitador, fogo/veneno no troll, proteger quem cura do assassino): cabe na IA de grupo atual ou pede regras novas? | ai-programmer | fase 1 (Agitador) e fase 2 (troll) |
| 8 | Precisa de um `systems-index.md`/`game-concept.md` (hoje o projeto não tem; este documento ficou fora de índice)? | autor | quando rodar `/map-systems` |
