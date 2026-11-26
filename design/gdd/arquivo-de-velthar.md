# Arquivo de Vel'Thar (dg_archive) — mini-masmorra da Aurora 27-29
> **DECISÕES DO USUÁRIO (2026-11-25):** U1 = A (nível 27 + `oj11`); U2 = A (só mecânicas existentes); U3 = livros + estantes;
> Chefe medido: 96.000 de vida / 124 ATK (topo da faixa segura; trio ~28 s, solo 18/20) = **mantido** pelo usuário; os números de §3.4/§7 abaixo (84k/112) ficaram antigos.
> XP = quests mais leves (peso total ~8.000; as do 20-30 perdem ~4%; faixa fica em 45%, share 0,78 sem mudar).


> Status: **ESPECIFICAÇÃO** (world-builder, 2026-11-25, WP8 da `design/gdd/dawn-band-refactor-proposal.md`). Só este documento:
> nada foi alterado em `data/`, `core/`, `game/`, `tools/`.
> Decisões do usuário (2026-11-25): D1 = B (1 campo + 1 mini-masmorra), D2 = Azhar foi o último rei-sacerdote de Vel'Thar e
> comprou juramentos prometendo que os vivos falariam com os seus mortos (**Provisória**, confere o `narrative-director`).
> Entrada já reservada no Campo dos Juramentos: `design/gdd/campo-dos-juramentos.md` §3.8 (`places.DUNGEONS["dg_archive"]`
> com `reserved: True`, `arch: "ziggurat"`, gate (84, 6), boca a 180°, nível 27). Molde: `design/gdd/viveiro-de-seiva.md`.
> **Mecânica do eco**: desenhada só com ferramentas que já existem (§3.5, opção A). Precisa do OK do `game-designer`
> antes de virar dado; as opções B e C (código novo) estão em §3.5.1. Falas são **provisórias** (writer/narrative-director).

| Campo | Valor |
|---|---|
| Id do mapa | `dg_archive` "Arquivo de Vel'Thar" (`DUNGEON_DEFS`, parent `field_oaths`, `levels` 27-29) |
| Entrada | Campo dos Juramentos, pé do Zigurate, portão (84, 6), boca a 180° (para oeste); portal `to_dg_archive` (chegada (0, 44)) |
| Portão | `PORTAL_GATES["to_dg_archive"] = {"level": 27, "quest": "oj11_senna"}` (ver §3.1 e a decisão U1) |
| Visual | `assets/models/map_dg_archive.glb` + `data/zones/dg_archive.json` (`build_dungeons.py`, `places.DUNGEONS["dg_archive"]`) |
| Chefe | `boss_azhar_scribe` "O Escrivão de Azhar" (nv 29, chefe de grupo) |
| Recompensa de tier | `dawn_shard` Fragmento da Aurora (Doran: lendário 25+ do +6 ao +9), garantido 2-3 |
| Canon | Provisional · Visível: Sim (masmorra, livros, estantes) · Descobrível: os nomes que ele lê, a página de Vorhag · Oculto→revelado: a promessa de Azhar (quest `va4`) |

---

## 1. Overview

Debaixo do zigurate do Campo dos Juramentos fica o **Arquivo de Vel'Thar**: os salões onde a cidade antiga guardava o
registro de cada nascido e de cada morto. Azhar, o último rei-sacerdote, fez do Arquivo uma promessa: quem tem o nome
escrito lá pode ser **chamado de volta** e ouvido outra vez. O **Escrivão de Azhar** ainda trabalha: lê nomes em voz alta,
e o que responde é um **eco** do morto. O jogador desce por quatro salas — **Degraus do Zigurate**, **Salão dos Registros**
(lateral), **Sala de Leitura** e **A Mesa do Escrivão** — e luta com o Escrivão no meio dos livros dele. O quebra-cabeça leve
é duplo e legível de cima: **rasgar os Livros de Nomes** antes da luta (menos ecos) e **esconder-se atrás das estantes**
quando ele faz a Chamada (quem ele vê, ele nomeia). A recompensa garantida é o **Fragmento da Aurora** (`dawn_shard`), e a
última quest fecha o mistério do Campo: por que cavaleiros da Aurora juraram à noite.

## 2. Player Fantasy

"Achei quem lê os nomes." Depois do túmulo vazio de Vorhag, das listas "para o Escrivão" e da voz sob o zigurate, o jogador
desce a um lugar silencioso, seco, de papel e pó, onde uma voz lê sem parar. A fantasia é de **ser nomeado**: o chefe
escolhe alguém do grupo pelo nome e algo volta para buscá-lo; a defesa é cortar a leitura (interromper), não ser visto
(estante) e queimar o livro antes (preparo). Competência (SDT): três respostas claras para três ameaças diferentes.
Bartle: Explorador (Salão dos Registros, a página de Vorhag) e Conquistador (chefe de grupo que premia preparo e
interrupção). Pilares: exploração recompensada; leitura de cima (livros brilhando em anel, estantes de pé, barra de
canal com "interrompa!"); grupo primeiro (feito para 3-5).

---

## 3. Detailed Rules

### 3.1 Acesso
- Portal `to_dg_archive` no Campo (o Fable promove o `future_portals` ao exportar o `field_oaths` e o `dg_archive` **na mesma
  leva**; nunca um sem o outro: `_check_portal_arrivals`). Saída pela chegada padrão do `build_dungeons` para a frente da
  boca (`gate_return`: gate + direção da face × (GATE_R + 5)).
- `PORTAL_GATES["to_dg_archive"] = {"level": 27, "quest": "oj11_senna", "text": "A porta do zigurate tem nomes riscados
  até a soleira. Sem saber o que se lê lá dentro, ela não abre: fale com a Erudita Senna (nível 27)."}` (provisório).
  O `oj11` é nível 28 e espera o Sir Edran (`oj10`) e o Vorhag (`dw_bones_boss` via `oj4`): na prática o Arquivo abre no 28.
  Ver decisão U1 (manter a quest no portão ou só nível).
- `MapsCatalog.archive_ready()` (molde `viveiro_ready()`): sem `data/zones/dg_archive.json`, `dg_archive` fica fora de
  `build()` e as quests `va*` não carregam.
- Masmorra compartilhada (`parent_map`), `bot_population` 0; bots só entram seguindo o grupo do jogador.

### 3.2 Salas (o Fable monta `places.DUNGEONS["dg_archive"]["layout"]`, ver §9)
| Sala | Pos | Raio | Conteúdo (spawners do JSON) | Papel |
|---|---|---|---|---|
| `chegada` | (0, 44) | — | nada | largo de chegada no pé da escada |
| `degraus` Degraus do Zigurate | (0, 20) | 11 | `archive_warden` ×2 + `archive_copyist` ×2 | aquecimento: tanque segura o guardião, quem bate corre ao copista |
| `registros` Salão dos Registros (lateral) | (30, 6) | 10 | `ink_wraith` ×3 + `archive_copyist` ×1 | ala opcional; colheita da página de Vorhag (§3.7) |
| `leitura` Sala de Leitura | (-26, -8) | 12 | `name_ledger` ×3 (parados nos atris) + `archive_copyist` ×2 | **ensina** o livro: quebra, solta tinta, não revida; os copistas leem em voz alta perto dele |
| `mesa` A Mesa do Escrivão | (4, -36) | 16 | `boss_azhar_scribe` ×1 (+ 4 livros dele, nascem sozinhos) | chefe; miolo livre, 4 estantes fixas (pontos em `boss_hint`) |
| ligações | — | — | `degraus>registros` `ink_wraith` 2 · `degraus>leitura` `archive_copyist` 2 · `leitura>mesa` `archive_warden` 1 | |

### 3.3 O quebra-cabeça leve (só mecânica existente)
O pedido da proposta ("placas na ordem certa") **não existe** como sistema: nenhuma regra da sim pune ou premia a ordem de
interação (quest encadeada só ordena, não falha; selo de portal só vale entre dois mapas). Em vez de pedir código, a Sala de
Leitura e a Mesa usam duas ferramentas já testadas:

**(a) Livros de Nomes = ovos do chefe** (`MonsterDef.eggs` + fase `hatch`, `MobSystem.ensure_eggs/hatch`; Dragonete e
Muda-Mãe). Fora de luta o Escrivão repõe **4 `name_ledger`** num anel de **7 m** em volta do ponto de nascer dele. Livro não
ataca, não anda, 0 XP; quebrar dá Tinta de Vel'Thar.
- **70%**: metade dos livros inteiros (para cima) **é lida**: o livro some e nasce um `named_echo` "Eco Nomeado" (§3.5).
- **40%**: os livros que sobraram são lidos + **ward 0,5** enquanto houver eco vivo (livro inteiro não segura o ward,
  regra do ovo) + entra a **Chamada**.
- **15%**: fúria ×1,3.
- A Sala de Leitura ensina antes: 3 livros parados, copistas por perto; o jogador vê que o livro quebra fácil e não revida.

**(b) Estantes = cobertura** (R-E do `BossSignatures`, `avalanche` com pontos fixos `mirrors`, como o Olhar Que Julga da
Condessa): a **Chamada** lê a sala inteira; quem tem o Escrivão à vista toma o golpe; quem está **atrás de uma estante** (o
segmento chefe→jogador cruza o círculo da estante) não toma, e a estante que protegeu **tomba** (`cracked`) e não protege
mais até a próxima Chamada, que repõe as 4. Leitura: "quem ele vê, ele nomeia".

Resultado: o grupo que quebra os 4 livros antes de puxar luta sem ecos de fase e sem ward; o que ignora enfrenta até 4 ecos
+ ward na fase em que a Chamada também começa. Nada disso é novo para a sim nem para os bots (fogem de `hazards`, batem no
lacaio, `cover` já é lido pela IA de grupo da Condessa — **a confirmar** no WP9 que o `BotBrain` procura cobertura também
fora do Ato III; se não, a Chamada só pune bots e precisa de power menor, §7).

### 3.4 Monstros (27-29)
Reuso de modelos do Ato I (mortos-vivos e culto), recoloridos pela cor do `MonsterDef`; novos marcados (padrão
`VIVEIRO_MODELS`: `ARCHIVE_MODELS = {id: [novo, reserva]}`, o catálogo usa a reserva até o GLB existir).

| Id | Nome | Nv | HP | ATK/MATK | DEF/MDEF | XP | Papel | Skill | Modelo (novo → reserva) |
|---|---|---|---|---|---|---|---|---|---|
| `archive_copyist` | Copista Sem Olhos | 27 | 560 | 22/78 | 10/26 | 165 | atirador mágico (`ranged`) | `mob_soul_drain` | **`mob_blind_copyist`** → modelo do `cultist` (pergaminho/sépia) |
| `archive_warden` | Guardião do Registro | 28 | 1.050 | 88 | 32/14 | 230 | corpo a corpo, `front_guard` 0,5 | `mob_charge` | modelo do `skel_guard` (osso velho + tinta preta) |
| `ink_wraith` | Borrão de Tinta | 28 | 520 | 72 | 8/18 | 200 | corpo a corpo rápido, frágil, em trio | — | modelo do `wraith` (preto-tinta, borda sépia) |
| `name_ledger` | Livro de Nomes | 28 | 900 | 1 | 16/16 | 0 | parado (`egg`), quebrável | — | **`mob_name_ledger`** → `mob_dragon_egg` |
| `named_echo` | Eco Nomeado | 29 | 1.300 | 70/70 | 14/14 | 0 | lacaio, base de metamorfose (§3.5) | — | modelo do `ghost` (sépia, mesma cor da `vel_shade`) |
| `named_echo_knight` | Eco (Cavaleiro) | 29 | 1.300 | 82 | 26/12 | 0 | forma corpo a corpo | `mob_charge` | modelo do `skel_guard` translúcido sépia |
| `named_echo_archer` | Eco (Besteiro) | 29 | 1.300 | 64 | 12/12 | 0 | forma atiradora (`ranged`, `kite`) | `mob_volley` | modelo do `skel_archer` translúcido sépia |
| `named_echo_priest` | Eco (Sacerdote) | 29 | 1.300 | 24/72 | 10/24 | 0 | forma conjuradora (`ranged`) | `mob_soul_drain` | modelo do `cultist` translúcido sépia |
| `loose_page` | Página Solta | 29 | 340 | 46 | 6/14 | 0 | lacaio rápido (Virar a Página) | — | modelo do `wraith` ×0,6 (papel claro) |
| `boss_azhar_scribe` | O Escrivão de Azhar | 29 | 84.000 | 112/96 | 30/30 | 1.500 | chefe de grupo (`is_boss`) | §3.6 | **`mob_azhar_scribe`** → modelo do `cultist` ×1,8 |

Os nomes dos modelos de reserva (`skel_guard`, `wraith`, `ghost`, `cultist`, `skel_archer`) são os ids dos monstros
cujo `model` o catálogo copia; o GLB exato sai do `MonsterDef` deles ao preencher o `ARCHIVE_MODELS`.
Eco com cor sépia (morto da cidade antiga), **nunca** azul (azul = morto do Lich) — mesma regra da `vel_shade` no Campo.
Rei de campo: o sistema de elite já cobre os comuns.

### 3.5 O eco que "copia o nomeado" (mecânica — `game-designer` aprova)
**Opção A (recomendada para agora; só ferramentas existentes).** O Escrivão não copia o jogador: ele lê **o nome de um morto
de Vel'Thar escrito na mesma linha que o seu**, e o morto que responde vem atrás de você.
- Skill **Ler um Nome** `mob_read_name` = canal interrompível R-C (`boss_channel`, como o Rufar da Turba e o Banquete do
  Varo): 4,0 s de canal com barra "interrompa!" na `BossBar`; o grupo quebra causando `Balance.BOSS_CHANNEL_BREAK_PCT` (6%
  da vida = 5.040) de dano durante o canal **ou** atordoando. Quebrado: atordoado `BOSS_CHANNEL_STAGGER` + +25% de dano
  recebido (`BOSS_CHANNEL_VULN`), fala "A pena... caiu." Completo: `on_done.summon` = 1 `named_echo` (máx 3 vivos) com
  **`pick: "soft"`** (`MobSystem.spawn_adds`: o eco nasce já com o alvo no curador/atirador, quem o chefe "nomeou").
- O eco é base de **metamorfose** (`MonsterDef.shift_forms`, `ShiftSystem`): ao nascer com alvo ele conjura `SHIFT_CAST_S`
  (o "tomar forma", janela visível de 1 s+ para o grupo bater) e vira uma de 3 formas sorteadas (rng da sim): Cavaleiro
  (peso 1), Besteiro (1), Sacerdote (1). Morre como a forma; XP/saque contam pela base (0 / nenhum).
- Os ecos dos **livros** (fases 70%/40%) nascem pela regra do ovo (sem `pick`: alvo = o do chefe, o tanque) e também tomam
  forma. Diferença legível: eco de livro = "o arquivo acorda" (tanque segura); eco do canal = "ele leu o seu nome" (corre
  para o curador; alguém tira).
- Por que serve à fantasia: o "nomeado" é escolhido pela leitura (a vítima é marcada pelo alvo do eco e pela fala), e a
  defesa é **não deixar ler** (interromper). Custo: zero código; tudo é dado (`boss_channel.on_done.summon.pick` já existe).

#### 3.5.1 Alternativas que pedem código (decisão do `game-designer`, depois do usuário)
| Opção | O que muda | Código | Risco |
|---|---|---|---|
| **B. Eco pelo papel do nomeado** | a forma não é sorteada: o eco copia o **papel** da vítima (tanque → Cavaleiro com `front_guard`; curador → Sacerdote que cura os outros ecos; dano → Besteiro) | `ShiftSystem.begin` ganha `shift_by_role` (lê `build` da vítima pelo papel que a IA de grupo já usa) + check; ~30 linhas, sem schema novo além de 1 campo | baixo; mantém modelos genéricos |
| **C. Cópia de verdade** | o eco veste o `KitModel` da vítima (classe, cor, arma) e usa 2-3 skills da build dela | sim + apresentação (`EntityView` com kit de personagem em monstro), skills de jogador em monstro, IA | alto; escopo de Ato III, quebra a regra "monstro = `mob_*`" |
Recomendação: **A agora**, **B** se o playtest pedir mais "é o meu eco". C fica fora do escopo do WP8.

### 3.6 O Escrivão de Azhar (chefe)
- Fica no miolo da Mesa (`move_speed` 3,4, alcance 3,0), `leash_range` 22 (sala r 16: o reset não esconde o berserk;
  memória do Ato III), `berserk_after` 160 s. `intro`: "Nome. Data. Causa. Próximo." `last_words`: "Esqueceram de... me
  escrever..." (provisórias).
- Skills (números iniciais; calibrar com `boss_probe`, F4):
  1. **Pena de Ferro** `mob_quill_slash` — CONE 100°, raio 3,6, power 1,5, recarga 7 s, preparo 0,6 s, tema `blood`
     (golpe físico de monstro).
  2. **Ler um Nome** `mob_read_name` — `boss_signature`, canal 4,0 s (§3.5), recarga 26 s (1ª aos 12 s de luta), clipe
     `cast_channel`, aviso roxo (controle/sombra na gramática de cor). `SIG_WARN` + `SIG_EFFECT` no `Sfx` (check exige).
  3. **Tinta Derramada** `mob_ink_rain` — `barrage` GROUND `mob_pick: random`, 4 círculos de 2,4 m (spread 9) que caem
     1,5 s depois, power 1,1 + lento 30% 2 s. Não esquivável pela AGI (chão de chefe). Cor dano (vermelho-laranja), poça
     **fosca** (tinta preta não brilha; nada de anel saturado no chão).
  4. **Virar a Página** `mob_page_turn` (a partir de 70%) — `boss_summon` 2 `loose_page` a cada 30 s (máx 3). Lacaio
     periódico do kit de chefe de grupo (`_check_boss_mechanics`; lição do Viveiro com o Brotar).
  5. **Chamada** `mob_roll_call` (a partir de 40%) — `avalanche` com `mirrors` = os 4 pontos de estante do `boss_hint`
     (deslocamento do ponto de nascer), raio 18 (a sala inteira), power 2,0 + atordoa 1,0 s, recarga 30 s, preparo igual ao
     Olhar Que Julga (aviso longo, fala "Chamada! Respondam pelos nomes!"). Estante: `cover` com `model`
     `mob_archive_shelf`, raio 1,6, tomba ao proteger (`ACT3_MIRROR_CRACKED_S` no chão).
- Fases: §3.3 (70% livros + Virar a Página · 40% livros + ward 0,5 + Chamada · 15% fúria ×1,3).
- Dica de jogo (para o `dialog_progress` do `va3`): "Tanque, segure-o no meio da sala: as estantes só cobrem se ele
  estiver no centro. Quando a barra dele disser 'interrompa!', todo mundo bate ou atordoa."

### 3.7 Saque, colheita e economia
Material novo (`items_catalog.gd`, `_mat`; preço de venda = 50%):
| Id | Nome | Preço | Fonte | Uso |
|---|---|---|---|---|
| `vel_ink` | Tinta de Vel'Thar | 28 | `name_ledger` 0,6 (1-2), `archive_copyist` 0,45, `ink_wraith` 0,4 | material de faixa (rank de skill 25-30); quest `va2` |
| `vorhag_page` | Página de Vorhag | 0 | colheita no Salão dos Registros (quest) | quest `va4` (pista) |

Tabelas (`_lt`):
- `lt_archive_copyist`: `vel_ink` 0,45 · `ancient_relic` 0,35 · `potion_mp_m` 0,1 · `crown_spectral` 0,03.
- `lt_archive_warden`: `bone_shard` 0,5 · `vel_ink` 0,3 · `holy_silver` 0,12 · `ring_spectral` 0,04.
- `lt_ink_wraith`: `vel_ink` 0,4 · `ghost_essence` 0,45 · `potion_hp_m` 0,06.
- `lt_name_ledger`: `vel_ink` 0,6 (1-2).
- `lt_azhar_scribe`: **`dawn_shard` 1,0 (2-3)** · `holy_silver` 1,0 (3-5) · `vel_ink` 1,0 (3-5) · `ghost_essence` 1,0 (2-3) ·
  `crown_spectral` 0,3 · `elixir_might` 0,5 · `legend_coin` 0,3.

Material de tier do Doran: `ItemSystem.enhance_cost`, lendário de nível ≥ `PLUS_DAWN_LEVEL` (25) usa `holy_silver` até +5 e
`dawn_shard` do +6 ao +9 (1, 2, 3, 4 = 10 fragmentos para um +9). Hoje o fragmento sai garantido só do Morvath (1), do Lich
(2-3) e de quest (1); raro nos chefes (Carniçal 0,5, Vorhag 0,7, ecos 0,10-0,15, Edran 0,15) e na Cidadela (0,05). O Arquivo
vira a 1ª fonte **repetível garantida de grupo antes do Lich**: +2-3 por limpeza (mesmo papel da `mother_sap` no Viveiro).
Ouro do chefe na faixa dos vizinhos (Senhor da Cripta/Edran); `vel_ink` vende a 14: nenhuma fonte de ouro infinito.

Colheita (`MapsCatalog.GATHER["dg_archive"]`): `vorhag_page` forma `relic`, centro do Salão dos Registros (30, 6), raio 6,
quantos 1 (só serve à quest; renasce no ritmo normal da colheita).

### 3.8 Quests (4 laterais; nenhuma é `prereq` da linha principal)
Prefixo `va` (livre, conferido 2026-11-25). Pesos de XP = número escrito (§4 F1).
| Id | Título | Tipo | Giver → turnin | Alvo | Nv | Pré | Peso XP | Ouro | Itens |
|---|---|---|---|---|---|---|---|---|---|
| `va1_zigurate` | Debaixo do Zigurate | REACH | `ruins_scholar` | `dg_archive` | 28 | `oj11_senna` | 1.200 | 150 | potion_hp_m ×3 |
| `va2_ledgers` | Livros de Nomes | KILL | `oaths_malcom` | `name_ledger` ×5 | 28 | `va1_zigurate` | 3.000 | 260 | potion_mp_m ×2 |
| `va3_scribe` | O Escrivão de Azhar | KILL | `oaths_malcom` | `boss_azhar_scribe` ×1 | 29 | `va1_zigurate`, `prereq_all` [`va2_ledgers`] | 7.000 | 600 | `reward_gear_tier` 3, elixir_might ×1 |
| `va4_promise` | O Que Azhar Prometeu | COLLECT (`vorhag_page` ×1) | `ruins_scholar` → `oaths_malcom` | `vorhag_page` | 29 | `va3_scribe` | 2.200 | 200 | dawn_shard ×1 |
Soma dos pesos **13.400**. `va2` conta livros da Sala de Leitura (spawner, respawn normal) **e** da Mesa: fecha sem o
chefe. `va4` pede a página do Salão dos Registros (a ala lateral ganha motivo) e a leva ao Malcom: revela §3.9.
Dicas práticas por `dialog_progress`: `va1` "A porta fica no pé do zigurate, a leste do acampamento. Leve grupo: lá dentro
o tanque segura o Guardião de frente; o Copista drena de longe, feche com dash (Shift)." · `va2` "Os livros não revidam:
bata neles com skills de área. Cada livro inteiro na Mesa vira um eco quando o Escrivão chega a 70% e 40%." · `va3` (§3.6)
· `va4` "A página está no Salão dos Registros, a ala à direita da escada. Aperte F perto dela."
Ganchos de texto (writer): a página é do registro dos mortos da peste, linha "família de Vorhag", e na margem, com outra
tinta, "chamar: Vorhag, cavaleiro, quando jurar".

### 3.9 Lore (canon provisório; cruzado com o existente)
- **Visível**: salões de estantes e atris, livros abertos com nomes, copistas sem olhos que escrevem sem tinta, um escrivão
  que lê sem parar; os ecos têm a cor sépia das Sombras de Vel'Thar, não o azul do Lich.
- **Descobrível**: os ecos não atacam por ódio: respondem ao nome (fala de eco ao morrer, provisória: "...presente."); o
  Escrivão chama o morto da linha **ao lado** do seu nome; as Ordens de Escavação (Campo, `oj8`) eram listas para ele ler.
- **Revelado no `va4`** (Oculto no GDD do Campo §3.9): Vel'Thar guardava no Arquivo o registro de todos os seus mortos.
  Azhar, último rei-sacerdote, prometeu aos vivos que quem tivesse o nome no Arquivo poderia ser chamado e ouvido outra vez
  — e cobrou um juramento por isso. Vorhag e Edran juraram à noite para ouvir de novo os seus mortos; o túmulo de Vorhag
  estava vazio porque ele já tinha descido ao Arquivo. **O que voltou não eram eles**: o eco repete o nome e a última
  palavra, nada mais. A promessa era verdade pela metade — o que liga a mentira de Azhar ao "coração da noite".
- **Contradictions check** (2026-11-25):
  - Senna (`oj11_senna` complete: "Vel'Thar tinha arquivos. Se alguém ainda lê os nomes lá embaixo, eu quero saber para
    quem.") = coerente: ela é a giver do `va1` e a pergunta recebe resposta.
  - Ordens de Escavação ("para o Escrivão", `digger_orders`) = coerente.
  - Vera ("O Senhor da Cripta ainda dá ordens. Ouvi.") = continua narradora não confiável; o Senhor da Cripta (`crypt_lord`,
    "Vel'Thar não dorme sozinho.") existe e é outro morto da mesma cidade; o Arquivo não o contradiz.
  - Alma Presa ("almas da cidade antiga no trono") e Azhar Lich-Rei (`lich_king`, nv 30) = coerentes: o Escrivão serve; o
    trono continua sendo a prisão. O Escrivão **não** é Azhar (modelo próprio; nada de reusar o modelo do Lich).
  - "Eco" já nomeia os **ecos de chefe** da capela (WP4, `echo_*`, `DAWN_ECHO_*`). Mesmo conceito no mundo (morto que
    volta como repetição) — coerente, e reforça a lore. Ids distintos (`named_echo*`). Nome "Eco Nomeado" evita
    confusão com "Eco do <chefe>". O `echo_decoy` "O Eco de Amarante" é Ato III e não toca isto.
  - Origem de Azhar (D2) segue **Provisória**; nenhum fato estabelecido muda.

### 3.10 Música, arte, bots
- `Music.MAP_THEME["dg_archive"]` = o tema que o `dg_cripta` usa hoje (mesma cidade enterrada; conferir em `music.gd`);
  `_check_music` exige a entrada. Tema próprio ("biblioteca morta") = pedido aberto ao sound-designer.
- `loading_art.ZONES["dg_archive"]` (nome, chão = `ground_color` do `DUNGEON_DEFS`) e `BOSSES["dg_archive"]`
  (`boss_azhar_scribe`, modelo `mob_azhar_scribe`, escala 1,8); `.jpg` refeito depois do GLB.
- Bots: só com o grupo do jogador; ninho, `hazards`, canal e lacaios já são tratados pelo `BotBrain`; cobertura: §3.3 nota.

---

## 4. Formulas

**F1 — XP de quest da faixa** (`QuestsCatalog.scale_xp`): `k = s × B / Σ`; cada quest recebe `round(peso × k / 10) × 10`.
`s` = `Balance.quest_share(20)` = **0,78** (decisão D7 extra); `B` = `band_xp_base(20, 30)` ≈ 305.500; `Σ` = pesos das quests
não repetíveis com `level_req` em [20, 30) — as `va*` (28/29) entram. Como `s × B` ≈ 238.300 é **fixo**, o audit
(`band_probe --only=audit`, hoje **45%**) **não muda** com as quests do Arquivo; elas só redistribuem.
Exemplo com `Σ_atual` ≈ 187.900 (o número de exemplo do GDD do Campo, já com o Campo; o real sai do audit no WP9):
`Σ_novo` = 201.300 → k = 1,184 (antes 1,268): as quests existentes da faixa dão **−6,7%**; o `va3` (7.000) dá ≈ 8.290 XP, o
`va1` (1.200) ≈ 1.420. Quem faz o Arquivo ganha 13.400/201.300 ≈ **6,7%** da XP de quest da faixa a mais que quem não faz.
Se a diluição incomodar: pesos −40% (8.000 no total) → −4%; ou `s` 0,78 → 0,83 (audit ~47,6%, ainda dentro de 44-48%).

**F2 — Tempo por abate** `t ≈ hp / (dps_bot × (1 − mit))`: comuns pela razão hp/nível dos vizinhos — `archive_copyist` 560
(27) vs `vel_shade` 440 (27) e `cultist` 380 (26), um pouco mais por ser de masmorra de grupo; `archive_warden` 1.050 (28)
vs `skel_guard` 880 (25) e `citadel_knight` 1.150 (29); `ink_wraith` 520 vs `carrion_crow` 420 (24) +4 níveis. Alvo
`band_probe --from=25 --to=30 --only=duel`: no tempo dos vizinhos, 0 `travou`.

**F3 — Livros e ecos**: inteiros na fase 70% = `L` (0-4) → lidos `ceil(L/2)`; na 40% os `L'` restantes. Ecos de livro ≤ `L`.
Ecos do canal: 1 por leitura completa, máx 3 vivos (soma com os de livro sob o `max` de cada `spawn_adds`). Ward ⇔ eco vivo
(livro e Página Solta não contam? **a confirmar**: o ward conta lacaios do chefe — `boss_id` —, então a Página também segura;
aceitar: tirar lacaio é trabalho de quem não tanqueia). Leituras esperadas numa luta de 50 s: 50/26 ≈ 2 → com grupo que
interrompe 1 de 2, ~1 eco do canal.
Canal: quebra com 0,06 × 84.000 = 5.040 de dano em 4,0 s = 1.260 dps de grupo (trio nv 29 equipado faz ~1.700-2.000 →
quebra se não estiver todo mundo correndo da Tinta); atordoar também quebra.

**F4 — Chefe**: HP 84.000 / ATK 112 por analogia: Senhor da Cripta 29 = 88.000/124 (masmorra 25-30), Sir Edran 28 = 72.000/110
(campo), Muda-Mãe 19 = 86.000/98 (mesmo papel de mini-masmorra). Dano escala com quem luta (`BOSS_CROWD_MULT`). Alvo
`boss_probe -- --boss=boss_azhar_scribe --party=1,3,5 --trials=20` (nível 29): **trio ≥ 90% em 35-65 s**; solo 30-60%
(masmorra de grupo, group-first); grupo de 5 registrado. Faixa segura em §7.

## 5. Edge Cases
- **Sem JSON** (`archive_ready()` falso): `dg_archive` fora de `gd.maps`; as 4 quests não carregam; monstros/skills/saque
  existem (sem spawner não aparecem); o portal continua em `future_portals` do Campo.
- **JSON do Campo sem o do Arquivo (ou o contrário)**: `_check_portal_arrivals` falha; exportar os dois na mesma leva.
- **Jogador sem `oj11`** (ex.: Arquivo aberto antes de Vorhag): o portão recusa com o texto; se U1 = "só nível", `va1`
  continua exigindo `oj11` (a quest some da Senna até lá), e a masmorra fica jogável sem história.
- **Wipe/reset**: `reset_boss` some com ecos e páginas, repõe os 4 livros fora de luta (`ensure_eggs`); estantes
  (`covers`) somem com o dono resetado (`_update_covers`) e voltam na próxima Chamada.
- **Livros mortos e chefe vivo**: ficam mortos até o reset; ler 0 livros = nada.
- **Canal com o chefe atordoado no início**: o canal não começa (o `try_cast` respeita o estado); recarga segue.
- **Eco cuja vítima morreu/saiu**: o eco perde o alvo e cai no aggro normal (tabela de ameaça do mapa); se ninguém, volta
  à base pelo `SHIFT_REVERT_S` e some no reset do chefe.
- **Chefe puxado para fora do centro**: as estantes ficam nos pontos fixos (relativos ao ponto de nascer); com o Escrivão a
  ≥ 6 m do centro a cobertura de algumas estantes falha. É regra legível ("segure-o no meio"), dita no `dialog_progress`.
- **Chamada sem estante inteira** (todas tombadas na anterior): a próxima Chamada sempre repõe as 4 antes (`raise_mirrors`).
- **Bots fora do grupo**: `bot_population` 0; nenhum bot entra sozinho.
- **Save antigo**: nada a migrar (mapa, itens e quests novos).

## 6. Dependencies
| Depende de | Como | Doc/arquivo |
|---|---|---|
| Campo dos Juramentos (`field_oaths`) | boca reservada, `oj11_senna` (portão e prereq), `oaths_malcom`, Sombras sépia | `design/gdd/campo-dos-juramentos.md` §3.8/§3.9 (já aponta para cá) |
| Bastião (`field_ruins`) | `ruins_scholar` (Senna): giver `va1`/`va4` | `maps_catalog.gd` |
| `ItemSystem.enhance_cost` (Doran) | `dawn_shard` = material +6..+9 do lendário 25+ | `PLUS_DAWN_LEVEL` |
| `MobSystem` (ovos/`hatch`/`ward`, `spawn_adds.pick`), `BossSignatures` (R-C canal, R-E `avalanche`+`mirrors`, `barrage`), `ShiftSystem` | sem mudança de código (opção A) | `core/sim/systems/` |
| `game-designer` | aprova o eco (A/B/C) | este doc §3.5 |
| Fable (Blender) | §9 | `places.py`, `build_dungeons.py` |
| WP9 (QA) | `boss_probe`, `band_probe`, audit, cobertura dos bots | `dawn-band-refactor-proposal.md` §8 |
A proposta (`dawn-band-refactor-proposal.md` §8 WP8) e o GDD do Campo (§6) devem citar este arquivo (o do Campo já cita).

## 7. Tuning Knobs
| Knob | Onde | Valor | Faixa segura | Afeta |
|---|---|---|---|---|
| HP/ATK do Escrivão | `monsters_catalog.gd` | 84.000 / 112 | 72-96k / 100-124 | trio 35-65 s |
| Livros (`eggs.count`, `r`) | idem | 4, 7 m | 3-6, 6-9 | ecos no pior caso |
| HP do livro | idem | 900 | 600-1.200 | custo de "rasgar antes" (2-4 s de grupo) |
| `ward` da fase 40% | idem | 0,5 | 0,3-0,6 | punição por ignorar livros/ecos |
| Canal Ler um Nome (duração/recarga) | `skills_catalog.gd` | 4,0 s / 26 s | 3-5 s / 20-35 s | pressão de interrupção |
| `pick` do eco do canal | idem | `soft` | `soft`/`far`/`random` | quem é "nomeado" |
| Chamada (power/atordoar/recarga) | idem | 2,0 / 1,0 s / 30 s | 1,4-2,4 / 0,5-1,5 / 25-40 | castigo de ficar à vista |
| Raio da estante (`cover.radius`) | `MonsterDef.cover` | 1,6 | 1,2-2,2 | facilidade de se esconder |
| `berserk_after` | `monsters_catalog.gd` | 160 s | 130-190 | grupo fraco |
| Pesos de XP das `va*` | `quests_catalog.gd` | 13.400 | 8.000-14.000 | diluição da faixa (F1) |
| `dawn_shard` do chefe | `lt_azhar_scribe` | 2-3 | 1-3 | ritmo do +6..+9 do lendário 25 |
| Portão | `PORTAL_GATES` | 27 + `oj11` | 26-28 | quando abre |
Constantes de sistema novas: nenhuma (`Balance` não muda; o canal usa `BOSS_CHANNEL_*`).

## 8. Acceptance Criteria
1. `_check_archive` passa: monstros/skills/tabelas existem; `boss_azhar_scribe` é chefe com `eggs` = `name_ledger` (egg),
   fases 70% hatch / 40% hatch+ward+Chamada / 15% enrage; `mob_read_name` é `boss_signature` com `boss_channel.on_done.summon`
   = `named_echo` com `pick`; `named_echo` tem 3 `shift_forms` existentes, 0 XP, sem saque (base e formas); garante `dawn_shard`
   (1,0); comuns com material principal 0,3-0,7; raro ≤ 0,05; `PORTAL_GATES["to_dg_archive"]` nível 27 (+ `oj11` se U1 = A);
   quests ligadas (giver/turnin existem, prereqs, nenhuma quest fora do Campo/Arquivo depende delas); música; `SIG_WARN`/
   `SIG_EFFECT` do canal e da Chamada.
2. Com o JSON: `dg_archive` registrado (27-29, parent `field_oaths`, `bot_population` 0), spawners dos comuns e do chefe,
   portal com chegada andável, anel dos livros (r 7) andável, 4 pontos de estante no `boss_hint` dentro da sala e a ≥ 3 m
   da parede; `_check_loading_art` e `_check_music` passam.
3. `boss_probe -- --boss=boss_azhar_scribe --party=1,3,5 --trials=20`: trio ≥ 90% em 35-65 s; `channel_breaks` > 0 no trio;
   `avalanche_hits` < `channels` × grupo (os bots se escondem ao menos parte das vezes) — senão a nota do §3.3 vale.
4. `band_probe -- --from=25 --to=30`: comuns do Arquivo no tempo dos vizinhos, 0 `travou`; audit continua 44-48%.
5. Suíte completa 0 falhas; smoke sem `SCRIPT ERROR`.

---

## 9. BLENDER REQUEST (Fable)

**Zona (`tools/blender/zones/places.py`)** — trocar a entrada reservada por esta (tira `reserved`, `rooms`/`boss` vazios):
```python
DUNGEONS["dg_archive"] = {
    "zone": "field_oaths", "gate": (84.0, 6.0), "face": 180.0, "name": "Arquivo de Vel'Thar", "seed": 37, "level": 27,
    "arch": "ziggurat", "rock": (0.7, 0.66, 0.56), "floor": (0.56, 0.52, 0.44), "glow": (0.86, 0.7, 0.42),
    "top": (0.42, 0.38, 0.32),        # alto das paredes: pedra de reboco escura (o chão claro lê-se de cima)
    "layout": {
        "rooms": {
            "degraus": {"pos": (0, 20), "r": 11, "mobs": [("archive_warden", 2), ("archive_copyist", 2)], "mob_off": (0.0, -6.0), "floor": (0.55, 0.5, 0.42)},
            "registros": {"pos": (30, 6), "r": 10, "mobs": [("ink_wraith", 3), ("archive_copyist", 1)], "floor": (0.5, 0.46, 0.4)},
            "leitura": {"pos": (-26, -8), "r": 12, "mobs": [("archive_copyist", 2)], "floor": (0.58, 0.53, 0.44)},
            "mesa": {"pos": (4, -36), "r": 16, "boss": "boss_azhar_scribe", "statue": False, "pillars": False, "floor": (0.6, 0.55, 0.46)},
        },
        "edges": [("chegada", "degraus"), ("degraus", "registros"), ("degraus", "leitura"), ("leitura", "mesa")],
        "packs": {"degraus>registros": ("ink_wraith", 2), "degraus>leitura": ("archive_copyist", 2), "leitura>mesa": ("archive_warden", 1)},
    },
}
```
- **Sala de Leitura**: 3 atris com `name_ledger` parados (spawners próprios, raio 0,5) em `data["boss_hint"]["ledgers"]`,
  como os tanques do Viveiro (`viveiro_dress`); estantes baixas encostadas na parede (sem colisor no meio).
- **Mesa do Escrivão**: miolo livre (sem estátua/pilar); mesa do Escrivão **visual, sem colisor** no ponto de nascer;
  anel dos livros r 7 andável; 4 pontos de estante em `data["boss_hint"]["cover"]` a ~10 m do centro em 45°/135°/225°/315°
  (o catálogo espelha esses pontos no `mirrors` da Chamada, padrão Condessa); estantes decorativas só na parede.
- **Salão dos Registros**: ponto de colheita da `vorhag_page` em (30, 6) livre ≥ 2 m de sólido.
- Corredores ≥ 3 m; cor do chão em tons do próprio chão (`floor_tones`), nada de anel saturado; poças de tinta **foscas**
  (`pool_glow: False`). Acabamento: função `archive` (molde `act3_dress`/`viveiro_dress`): estantes, pilhas de livros,
  atris, velas apagadas, papel no chão, faixas de nomes riscados nas paredes.
- **Zigurate** no Campo: já reservado; ao promover, só a passagem (`future_portals` → portal) muda — refazer `field_oaths` e
  `dg_archive` na mesma leva; o build do Campo divide o arquivo com WP3/WP4: exportar em série.

**Modelos novos** (`mob_kit` / módulo novo, ex. `velthar_mobs.py`):
| GLB | O quê | Clipes | Reserva até existir |
|---|---|---|---|
| `mob_azhar_scribe` | Escrivão: humanoide alto e magro (kit), manto de pergaminho, capuz com o rosto coberto por uma página, pena-lança enorme na direita, livro aberto preso ao peito na esquerda, cor sépia + filete âmbar | `MOB_BOSS_KEEP` + `cast_channel` (lendo o livro, em laço: `ACTIVE_LOOP`), `cast_ground` | modelo do `cultist` ×1,8 |
| `mob_name_ledger` | Livro de Nomes num atril (peças rígidas), páginas que viram no `idle`; `die` = livro rasga e cai | `idle run attack hit die` | `mob_dragon_egg` |
| `mob_archive_shelf` | Estante de pé (cobertura da Chamada), molde do `mob_standing_mirror` | `idle run attack hit die crack idle_cracked` | sem `model` = cobertura padrão |
| `mob_blind_copyist` (opcional) | Copista: humanoide do kit, venda nos olhos, pena e prancheta | padrão de monstro | modelo do `cultist` |

**Arte de carregamento**: `loading_art.ZONES["dg_archive"]` (nome "Arquivo de Vel'Thar", chão (0,56, 0,52, 0,44)) e
`BOSSES["dg_archive"]` (`mob_azhar_scribe`, 1,8); `.jpg` 1600×900 depois do GLB.

---

## 10. Decisões para o usuário
| # | Pergunta | Opções | Recomendada |
|---|---|---|---|
| U1 | Portão do Arquivo | A nível 27 + `oj11_senna` (abre de fato no 28, depois de Vorhag e Edran) · B só nível 27 (masmorra repetível de quem chega por outro caminho; quests ainda exigem `oj11`) | **A** (a história manda ao Arquivo; o mesmo do GDD do Campo) |
| U2 | Eco que "copia o nomeado" (o `game-designer` opina antes) | A só mecânica existente (canal + `pick` + metamorfose sorteada) · B eco pelo papel da vítima (código pequeno no `ShiftSystem`) · C cópia de verdade do personagem (fora do escopo) | **A** agora, B se o playtest pedir |
| U3 | "Placas na ordem certa" da proposta | trocar por livros (ovos) + estantes (cobertura), ambos existentes · pedir regra nova de ordem (código) | **trocar** |
