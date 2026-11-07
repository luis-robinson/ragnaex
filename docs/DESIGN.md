# RagnaEx — Documento de design (fonte da verdade para os agentes)

## Visão
"MMO" 2.5D single-player com bots que parecem jogadores. Referências: Ragnarok Online (câmera alta fixa, mundo 3D),
Tree of Savior (arte: chibi, pastel, pintado/flat, outline), Drakantos (combate de ação sem target-lock: personagem encara
o cursor, LMB básico, skills como skillshots/área no cursor).

## Pilares
1. **Responsividade**: input nunca é engolido (buffer de 15 ticks, que não vence enquanto a própria skill prepara), startup curto,
   recovery cancelável por movimento/dash, hit-stop curto. **Encadear (estilo Diablo)**: 0,05 s depois do impacto outra skill ou o
   básico já sai, sem esperar a animação acabar; o golpe atual sempre acerta (tudo é aplicado no impacto). Básico atrás de básico
   mantém o ritmo dele; monstros não encadeiam (`WorldSim._can_chain`, `Balance.CHAIN_AFTER_IMPACT`).
2. **Mira pelo mouse**: toda skill tem forma no chão (retículo) — SELF / DIRECTION / GROUND / CONE / TARGET.
3. **Equipamento é poder, build é escolha**: atributos vêm só de itens; level dá HP/MP base e pontos de skill;
   a arma empunhada decide quais skills funcionam.
4. **Mundo vivo**: bots usam o mesmo pipeline do jogador; caçam, vendem, conversam, morrem.
5. **Pronto para rede**: `core/sim` é o servidor; apresentação é cliente burro.

## Controles
WASD mover · LMB ataque básico · RMB (segurar) bloqueio · 1-6 skills · F1-F3 poções · Shift dash · Espaço pular · F interagir ·
Q/E girar câmera 45° · scroll zoom · I bolsa · C personagem · K skills/maestria · L quests · P grupo · Enter chat · Esc fecha · F11 tela cheia (padrão) ↔ janela 1920×1080.

## Atributos → stats (`core/sim/stats.gd`, constantes em `data/balance.gd`)
| Atributo | Efeito |
|---|---|
| FOR | ATK físico (×2/pt); com escudo: +0.6%/pt chance de bloqueio (usa o maior entre FOR e WILL); com arma física: redução ao bloquear 30% + 0.5%/pt (cap 60%) |
| AGI | arco: substitui FOR (×2.2/pt); adaga: +1/pt; outras ×0.25; crit físico +0.4%/pt |
| VIT | HP +12/pt; DEF física +1.5/pt |
| WILL | cura +3%/pt; MP +8/pt; DEF mágica +1.5/pt |
| INT | MATK ×2.5/pt; crit mágico +0.4%/pt |

Dano = (ATK × poder − DEF × 0.5, mín. 15% do bruto) × variação ±10% × crit 1.5. Bloqueio ativo (RMB) sempre bloqueia e soma +25% de redução
(+10% com escudo), custa 2 MP/s e reduz velocidade a 50%. Bloqueio passivo só com escudo (chance).
A guarda é direcional: bloqueio ativo, chance passiva, aparo e reação do escudo só valem num arco de 140° à frente
(`Balance.BLOCK_ARC_DEG`, `Combat.in_guard_arc`). Fora dele o golpe entra inteiro, não gasta o aparo e o jogador vê
"FLANQUEADO!". Corpo a corpo vem de quem bate (investida: de onde partiu), projétil do lado de onde chega, área no chão do ponto de impacto;
dano no tempo ignora a guarda. O jogador vê o arco no chão enquanto segura o botão.
Investida (skill DIRECTION com `dash`) anda reto em passos e acerta toda a faixa percorrida; obstáculo a para sem
deslizar e corta o alcance que sobraria além do avanço. Saltos e teleportes (GROUND/SELF) não varrem o caminho.

## Classes e builds (jogo focado em build)
Cada classe tem **20+ skills** (`skills_catalog.gd`), mas só **6 vão na barra**. A build = arma empunhada + skills aprendidas
+ evoluções + conjunto lendário. Builds (`ClassDef.builds`, guiam bots, conjuntos e a janela K):

| Classe | Builds (arma) |
|---|---|
| Paladino | Guardião (espada/maça + escudo, tank) · Cruzado (montante/martelo 2M, dps) |
| Berserker | Armas Gêmeas (2 armas de 1 mão: machadinhas e/ou espadas) · Executor (machado/montante 2M) |
| Bispo | Sacerdote (maça + orbe ou escudo, ou cajado; cura em grupo) · Inquisidor (martelo 2M, dano sagrado) |
| Druida | Guardião da Floresta (martelo 2M, tank) · Fera Selvagem (2 maças) · Xamã (varinha + orbe, magia) |
| Ranger | Atirador (arco, alvo único) · Caçador (arco, área/controle) · Patrulheiro (2 armas de 1 mão) |
| Assassino | Lâminas (2 adagas: veneno, esquiva, furtividade, pelas costas, ataque muito rápido) · Duelista (2 espadas, equilibrado) |
| Elementalista | Foco em Fogo · Gelo · Raio, todos de cajado (os ramos se misturam; conjuntos favorecem um elemento ou uma combinação) |
| Necromancer | Invocador · Ceifador · Sombras, todos de foice (focos que se misturam) |

**Arma exigida** (`SkillDef.requires`, alternativas): tipo da mão principal, `shield`/`orb`, `dual` (2 armas de 1 mão),
`dual_<tipo>` (ex. 2 espadas), `two_handed`. Skill com arma errada fica com ✖ na barra e não sai.
Ataque básico: cadência/alcance/tipo vêm da `ClassDef`; classe de distância com arma corpo a corpo ataca corpo a corpo.

## Armas e mãos
Principal: espada, montante, maça, martelo de guerra, machadinha, machado de guerra, adaga, arco, cajado, varinha, foice.
Secundária: escudo, orbe (mago) ou arma de 1 mão (espada/maça/machadinha/adaga; Shift+clique na bolsa).
Arma de 2 mãos (montante, martelo, machado de guerra, cajado, arco, foice) libera a secundária. Segunda arma soma 60% do ATK.

**Berserker** (só machados): **Machados Gêmeos** (dois machados de 1 mão, couro) = velocidade de ataque (`aspd_pct`, recarga do básico menor) e
roubo de vida (`lifesteal`, % do dano direto volta como vida; dano no tempo não conta), na árvore e no conjunto. **Executor** (machado de 2 mãos,
placa) = tanque de apoio: passivos e conjunto com vida e defesa sem perder ATK. Tetos: `Balance.LIFESTEAL_CAP` 20%, `ATTACK_SPEED_CAP` 60%.
Toda arma corpo a corpo de duas mãos (montante, malho, machado; `Balance.BIG_SWING_WEAPONS`) tem golpe básico largo: alcance x1,4,
arco de 150° e até 4 alvos (`Balance.BIG_SWING_*`). Vale para Executor, Cruzado e Inquisidor; arco e cajado não mudam.

**Bispo**: **Sacerdote** (maça + escudo, suporte) = cura mais forte e bênçãos/escudos que duram mais (`buff_pct`, em você e nos aliados);
**Iluminado** (build `inquisidor`; **cetro** de duas mãos, arma mágica nova com ataque básico de luz à distância; túnicas) = dano mágico +
**Radiância** (`radiance`: % do dano mágico direto cura o aliado mais ferido a até 10 m, você incluso). Tetos em `Balance` (80% / 40%).

**Druida**: **Xamã** (cajado de duas mãos, túnicas) = magia da natureza, invocações (Lobos Espirituais, Ent Guardião) e Bênção do Bosque;
passivos de MATK e duração de bênçãos. **Lobo** (duas maças, couro) e **Urso** (malho, placa) viram bicho: `Forma de Lobo`/`Forma de Urso`
são skills que ligam/desligam (`SimEntity.form`; bot não desfaz). Transformado: stats da forma (`Balance.FORM_STATS`) e as skills da build
viram o golpe do bicho (`SkillsCatalog.FORM_MODS`, aplicado em `WorldSim.resolve_skill`; mesma recarga). Trocar para arma que a forma não aceita
desfaz a forma. **Espreitar** (só lobo): furtivo por 8 s (monstros não acham nem mantêm o alvo); o golpe que quebra vira emboscada (+60%).
Visual: `form_<wolf|bear>.glb` (`druid_sets.build_forms`) com a armadura de animal de cada conjunto (`FormModel`).

**Ranger** (sem corpo a corpo, isso é do Assassino): **Caçador** (arco) com **companheiro** permanente (lince; `ran_companion` invoca
uma vez, fica até cair; vida/ataque/defesa são parte das do dono, `Balance.PET_*`, mais `pet_pct`), Ataque da Fera (o lince salta no
alvo e atordoa) e Instinto da Matilha (buff em você e nele). **Atirador**: **mosquete** de duas mãos (`rifle`: básico 1,8x mais lento e
1,9x mais forte, alcance maior, clipe `atk_rifle`) e **armadilhas no chão** (`trap` em `TrapSystem.place_trap/update_traps`: armam em
0,6 s, disparam quando um inimigo pisa, no máximo 3 por ranger, somem em 30 s; mandíbula prende, mina explode, gelo retarda).

**Assassino**: **Lâminas** (duas adagas, `aspd_pct`): Lâmina Pestilenta envenena as lâminas (`hit_poison`: todo golpe físico aplica
um veneno que renova, não acumula, `Balance.HIT_POISON_TIME`), **esquiva** (`evasion`, teto `Balance.EVASION_CAP`; golpe direto
esquivado não causa nada, evento `dodged`), Sumir (`stealth` sem forma: só o Lobo do Druida exige estar transformado) e **pelas costas**
(`backstab`: % de dano e +`BACKSTAB_CRIT` de crítico quando o atacante está atrás do alvo, `Combat.is_behind`). Venenos escalam com ATK.
**Duelista** (duas espadas, `atk_pct`): golpes largos, Guarda (DEF + esquiva), Avanço, Turbilhão, Foco e Golpe de Mestre; árvore com
ATK/DEF/crítico e conjunto com DEF + crítico. Envenenador e Sombra saíram (save com nó antigo reseta a árvore e devolve os pontos).

**Elementalista**: só **cajado**; Fogo, Gelo e Raio são focos (ramos da árvore), não caminhos fechados: dá para pegar skills dos três.
Cada skill tem `SkillDef.elements` (o ramo dá; gerais e combinações em `SkillsCatalog.ELEMENTS`) e o dano multiplica pela média de
`fire_pct`/`frost_pct`/`storm_pct` desses elementos (`Stats.element_mult`, teto `Balance.ELEMENT_CAP`). Combinações gerais: Tempestade
de Brasas (fogo+raio), Choque Térmico (fogo+gelo), Granizo Trovejante (gelo+raio), Prisma Elemental (os três). Elementais de fogo/gelo/raio
(um por ramo): **um vivo por vez**, invocar outro substitui (`summon.replaces`). Conjuntos: 3 peças dão o elemento do foco; os de
combinação (`SET_VISUALS.favor`) dão o 2º elemento com 4 peças. Save com varinha/orbe: vão para a bolsa e o cajado inicial entra.
**Efeitos por elemento** (valem para qualquer classe, pelo elemento ou pelo tema visual da skill): **fogo queima** — todo dano no tempo
de skill de fogo é queimadura (número laranja, brasas no alvo); **gelo estilhaça** — skill de gelo em alvo retardado, preso ou atordoado
causa ×`Balance.FROST_SHATTER_MULT` (1,3; número azul com ❄), então vale abrir com Nova de Gelo/Lança e emendar; **raio atordoa** —
Trovão, Estilhaçar, Zero Absoluto e as combinações com raio sempre; as outras skills de raio com dano têm `Balance.STORM_STUN_CHANCE`
(15%) de atordoar `STORM_STUN_TIME` (0,5 s) no golpe direto (`Combat.storm_can_stun`; chefes: 40% da duração). Na tela: atordoado = estrelas girando, retardado/preso =
anel de gelo nos pés e tom azul, queimando = brasas e tom laranja (`EntityView._update_status`, parâmetro `status` do `toon.gdshader`).

**Necromancer**: só **foice**; Invocador, Ceifador e Sombras são focos que se misturam. Invocações com limite **por tipo**
(esqueletos, 2 cães de ossos, 1 lich de gelo, 1 Rei Esqueleto); o ataque delas sai do MATK do dono × força do monstro × `pet_pct`.
**Maldições** (efeito `curse`: `taken_pct` = recebe mais dano, `weaken_pct` = causa menos, teto `CURSE_WEAKEN_CAP`; a mesma maldição renova).
**Canalização** (efeito `channel: {ticks}`, fase ativa = duração): o efeito pulsa N vezes mirando o cursor; outra skill ou o dash cortam (bots seguram até o fim).
**Formas** do Ceifador: Fantasma (10 s, `Balance.FORM_DURATION`; `shaders/ghost.gdshader`: casca espectral com a cor das peças, rápido, esquiva) e Demônio (`form_demon.glb`, maior, HP/DEF/roubo de vida); golpes de foice mudam
(`FORM_MODS`). Save com cajado/varinha/orbe: voltam para a bolsa e a foice inicial entra.

**Mundo mais cheio**: os spawners exportados do Blender são multiplicados na carga (`Balance.SPAWN_COUNT_MULT` 1,6 nos campos,
`SPAWN_COUNT_MULT_DUNGEON` 1,3, chefes de count 1 não mudam) e renascem 25% mais rápido. **Caçadas repetíveis** geradas por loop
(`QuestsCatalog.hunts`): uma por monstro comum que aparece num mapa e não tem recompensa própria (quadro < nv10, pedra druídica < 20,
obelisco depois). NPC só com repetíveis mostra **↻ azul** (`QuestSystem.REPEAT`; fonte com reserva de símbolos `UiKit.mark_font`).
**Ranger**: básico de arco 13 m e skills de arco/mosquete × `ARCHER_RANGE_MULT` (1,35).

**Criação de personagem**: na tela inicial, depois da classe, escolhe-se sexo (todas as classes têm os dois), cabelo (6 estilos), cor do cabelo,
barba (4 + sem, só masculino) e cor, olhos (4 formas) e cor, com prévia 3D girável. O visual (`SimEntity.look`) é só apresentação: a sim não lê.
Bots sorteiam o visual (`LooksCatalog.random_look`); save antigo usa o padrão da classe.
Rosto: tom de pele (9), sobrancelhas, boca e marcas (cicatriz, sardas, pintura de guerra, rubor, tatuagem) com cor; 12 cabelos.
**Ofício por classe**: ferreiro e alquimista só listam receitas que a sua classe pode usar (`CraftSystem.for_class`: arma do tipo da classe,
peça restrita só para a classe dela; poções e materiais para todos) e `can_craft` recusa o resto.
**Ícones dos conjuntos** (`tools/icons/set_icons.tscn`): enquadramento automático pelos vértices; arma vista pela face larga em diagonal
(eixos principais), uma luva só, cabeça com o rosto do boneco como manequim.
**Montaria (H)**: só fora de combate (`combat_timer`), fora de forma animal e de dungeon; `Balance.MOUNT_SPEED_MULT` 1,7.
Atacar, usar skill, dash ou bloquear desmonta e a ação acontece; levar golpe derruba (`WorldSim.dismount`, evento `mount_changed`).
Bots montam às vezes andando fora de combate. Visual: `mob_horse.glb` (`mob_kit.horse`, pelagem "tint" com cor por entidade) e o boneco
no clipe "ride" gerado do idle (`RidePose.ensure_clip`, pernas/braços fixos). Revisar: `lineup.tscn -- --mounted [--front] [--nohorse]`.
**Drops no chão**: baú de tesouro chibi (`game/fx/loot_chest.gd`: madeira, aros dourados, gema na cor do item, brilho pela raridade,
facho de luz em épico/lendário) e moedas para ouro; malhas compartilhadas. Revisar: `-- --autostart=<classe> --loot_demo --screenshot=<png>`.
Save com nó de árvore que não existe mais (build removida): a árvore volta ao início e os pontos voltam (`SaveSystem.points_for_level`).

## Pontos de skill: árvore (estilo talentos do WoW)
2 pontos por nível (+1 nos níveis 10/20/30), ~61 no total, gastos SÓ na árvore da classe (`TreeCatalog`, gerada por loops;
tecla K). Um **painel por ramo**, lado a lado: **Geral** e um por **build** (título, papel e pontos gastos). O nó inicial fica em
cima, ligado ao topo de cada painel; cada painel desce por nível: skill → passivo → skill… Nós: **skill** (quadrado no meio;
aprende e vai pro 1º slot livre), **passivo** (círculo pequeno na linha: % de ATK/DEF/HP/MATK/MP/cura/crit pelo papel da build),
**maestria** (círculo "+1" à esquerda da skill), **evolução** (losango à direita; a do dash fica ao lado do início).
Dourado = comprado, verde = dá pra comprar agora, cinza = bloqueado; "Nv X" na margem marca a linha acima do seu nível.
Só se compra nó ligado a um já comprado, com nível e pontos (os ramos não se ligam entre si: cada build parte do início).
A árvore inteira custa mais que os pontos do jogo: escolher o caminho é a build.
A barra 1-6 só se troca na cidade. Testes: cada build, do 1 ao 30 comprando só pela árvore, pega todas as skills dela.

## Lendários com visual próprio (`GearCatalog.SET_VISUALS`)
Arte de referência em `reference/<classe>/set_N/` (frente, costas, ícones). Cada um vira um estilo do kit (`chibi_kit.SET_STYLES`,
peças `arm_<estilo>_<slot>_*`), ícones renderizados em `assets/icons/<icone>_<peça>.png` e nomes da referência.
- Paladino Guardião lv5 — **Conjunto Cavaleiro da Fortaleza** (`pal1`): placa violeta sobre traje branco, elmo com crista e
  aletas + viseira, ombreiras em bloco, emblema em V, manoplas, faldas e joelheiras. "Polainas" não tem slot no RagnaEx: vêm com a armadura.

## Conjunto inicial (`ItemsCatalog.STARTER_SETS`)
Cada classe começa com arma(s) + elmo, corpo, luvas e botas próprios (estilo e cor da classe: Escudeiro, Saqueador, Noviço,
Bosque, Batedor, Sombras, Aprendiz Arcano, Acólito). O corpo tem os atributos da antiga peça única; o resto só dá defesa.

## Equipamento lendário e conjuntos (`data/catalog/gear_catalog.gd`, gerado por loops)
A cada 5 níveis (5/10/15/20/25/30) cada **build** tem um conjunto lendário: elmo, corpo, luvas, botas, arma (+ secundária).
Bônus: (2) +atributo secundário · (3) +atributo principal (ex. INT +2) · (4) +20% na skill assinatura (ex. Bola de Fogo) ·
(5) +% no stat da build e −% de recarga de outra skill. Os números crescem por tier (`Balance.SET_*`).
Drop: o lendário cai como **Moeda Lendária** (1 em 100 monstros; chefes 40% e 2 moedas; Reis sempre). **Iara, a Relicária** (praça de Aldara)
troca moedas por qualquer peça lendária da sua classe (conjuntos das builds, maça do conjunto, escudos nomeados): tier i de
`LEGENDARY_LEVELS` custa i+1 moedas (nível 5 = 1, nível 10 = 2 ... nível 30 = 6), até o seu nível (`WorldSim.relic_*`). Ela também vende
Moeda Lendária por ouro (`Balance.LEGEND_COIN_PRICE` = 500, `ItemSystem.buy_legend_coin`). **Reset das skills** com o Ancião Ravi
(`Balance.SKILL_RESET_NPC`, `ProgressionSystem.reset_tree`, grátis, segundo clique confirma): a árvore volta ao início com as skills
iniciais e devolve todos os pontos do nível; os talentos de classe ficam.
**Lendário é pessoal**: no grupo cada um que dividiu o abate rola o seu e ele fica preso ao dono por 110 s. O **jogador** no grupo também
recebe o saque comum pessoal a cada abate dividido (mesmo sem ter batido: suporte ganha); o rodízio fica entre os bots. No chão o jogador só
vê o que é dele ou o que já ficou livre (`WorldSim.loot_visible_to`).
No primeiro mapa (Vale de Aldara, `Balance.LEGENDARY_START_MAP`) o 1º conjunto (nível 5) cai em 1 de 25 (`LEGENDARY_START_MAP_CHANCE`), e o
**Javali Presa-Rachada** (mini-chefe nível 5 no bosque a leste, renasce em 90 s; chama 2 leitões a 50% e se enfurece a 25%) dá 40% como todo chefe.
Maestria: o nó +1 da árvore compra de novo até `MASTERY_MAX` (1 ponto por nível); é o único jeito de subir (usar a skill não sobe).
Cada nível: +12% de poder (dano/cura), -4% MP, -5% recarga e +`MASTERY_BONUS_PCT` (10%) nos bônus positivos de buffs e formas
(`SimEntity.scaled_bonus`, `form_mult`; penalidade e duração não mudam). A descrição de cada maestria sai dos dados (`TreeCatalog.mastery_desc`).
**Teia de skills** (janela K, estilo Path of Exile): uma teia por classe. É uma malha de junções e estradas (grade irregular,
sorteio fixo por classe; parte das estradas some, então há várias rotas) com círculos pendurados nas casas: o de skill (a skill no
centro; maestria, evoluções e passivos da build em volta) e o de notável (anel de atributos com o notável no meio, duas entradas =
atalho). Cada ramo (Geral + builds) tem o seu setor em volta do início, como as regiões do PoE; skill de nível alto fica mais longe.
Estradas e junções são só caminho (custam 1 ponto e não dão nada); atributos (+1) e bônus ficam nos círculos. 8 pontos por nível
(+1 no 10/20/30) = 235 no 30, numa teia de ~250-360 nós (+ maestrias). Medido com `tools/tests/web_probe.tscn`: no 30 a teia dá
~x1,4 de ataque e ~x1,2 de HP a um bot da build.
Save antigo recebe os pontos de volta. Bots compram o caminho mais curto até as skills da build e depois notáveis/atributos
(`ProgressionSystem.bot_spend`).
**Talentos de classe** (aba "Talentos"): a cada 5 níveis (5 a 30) uma linha com 3 escolhas que mudam o jeito de jogar
(`ClassTalentsCatalog`): buffs que ficam **permanentes** ou viram **aura** para o grupo (15 m), invocações que **ficam para sempre**
(elemental, esqueletos, lobos, Ent), **recusa a morrer** (1 HP e imortal por alguns segundos, com recarga), execução, emboscada mais forte,
mana como escudo, cura no abate etc. Um por linha, grátis (liberado pelo nível), trocar na cidade (`Balance.PICK_SWAP_TOWN_ONLY`); o reset
das skills mantém as escolhas. Buff de talento aparece com ∞ na barra e não acumula com o lançado (mesmo id; o lançado vale enquanto dura).
Nível 30 só cai do Dragonete. Raridades: comum, incomum, raro, épico, **lendário** (laranja).

## Progressão (lenta)
Lv 1-30. XP = 150 × 1.28^(lv−1): ~15 kills por nível no começo, ~500 perto do 30 (~3800 kills no total).
Spawners enchem de uma vez ao carregar o mapa (`primed`); depois cada abate volta no tempo de respawn. Monstro sem alvo e sem personagem
a `Balance.DORMANT_RANGE` (40 m) dorme (não pensa/anda/atualiza). Separação usa grade de 3 m por tick (`WorldSim._index_map`) e monstros
procuram alvo só na lista de personagens do tick. Dungeons do mapa (`build_dungeons.py`): bando no meio de cada corredor (menos o da
chegada), salões com área de spawn do tamanho do salão.
Ritmo (MVP até o 30, ~15 h): `Balance.xp_for_level` sai do tempo planejado no nível (6,5 + 1,75×(lv−1) min) × 3 abates/min ×
XP de um monstro do nível (6 + 4,5×lv) ÷ 0,55. Quests não repetíveis dão `XP_QUEST_SHARE` (45%) de cada faixa (1-10, 10-20, 20-30):
`QuestsCatalog.scale_xp` mantém o peso relativo escrito em cada quest e escala o total da faixa. Caçadas pagam no NPC da zona do monstro.
A faixa 1-10 dá 50% (`XP_QUEST_SHARE_BAND`) e cada nível de 2 a 19 tem quests valendo ≥ 35% do nível (há check): o 6-7 ganhou 7 laterais
de moradores de Aldara (`v1_tico`..`v7_marco`: javalis, chá do Ancião, peles e bando de lobos da Caçadora Ivy, Gruta, recibo para o Nils, Marco).
O 11-15 ganhou a cadeia da Pedreira (`p1_pedreira`..`p7_ferro`: Gunnar → Mestre Tadeu, golens de musgo, núcleos para a Rosa, os três chefes, volta ao Gunnar),
laterais do Posto e da mata (`t1_atadura`..`t5_teias`) e **repetíveis de material** (COLLECT `repeatable`: seda para a Maren, cogumelos para o Fen,
núcleos para o Gunnar, casca para o Dario). Quests do 16 e do 19 pesam mais para nenhum nível ficar abaixo de 35%.
Quests: cadeias (o Lago 6 passos até o Caranguejo-Rei, os bandidos 6, a erudita 4+), entregas (`QuestDef.give_items`: o NPC entrega o
pacote ao aceitar e outro recebe), colheita (pontos `MapsCatalog.GATHER` que a sim espalha em chão livre; F perto colhe em 1,1 s,
andar/atacar/apanhar cancela, volta em 75 s) e chefes/elite (Presa-Rachada, Caranguejo-Rei). Nenhum chefe tem duas quests de história.
Monstros: aviso de golpe com a forma de verdade (círculo/cone/faixa enchendo até o impacto), recuo no clipe "hit" ao apanhar,
corpo afunda e some, bando (`Balance.PACK_AGGRO_RADIUS`: puxar um chama os iguais parados por perto), nome colorido pelo nível
comparado ao jogador (cinza/verde/branco/amarelo/laranja/vermelho), chefes com loot próprio.
Morte: −3% XP, respawn em Aldara com 50% HP/MP. Monstros dão XP × clamp(1 + 0.08×(lvMob − lvPlayer), 0.3, 1.6).

## Mundo
**Direção de layout (estilo Erenshor, câmera alta de sempre)** — regras em `CLAUDE.md` → "Layout de zonas":
cada zona é um vale fechado de ~240 m com borda natural, vila murada circular no hub, 3–5 POIs a 60–120 m ligados
por estradas curvas, rio/lago com pontes e um landmark; layout feito no Blender (`/layout-zone`) com nota ≥ 8.
As três zonas usam `tools/blender/zones/zone_lib.py` (estradas catmull, rio/lago, pontes, penhascos com gargantas,
paliçadas/muros em anel, morros em patamares, dispersão de vegetação) e `nature.py` (pinheiros, arbustos, juncos na margem,
chão de bosque, anel de montanhas com neve) e são lidas por `MapsCatalog.load_zone`.
Rios, lagos e morros colidem na sim (`MapGeometry.build_collider_grid`; rio tem vão só nas pontes, com 0,5 m de beirada rasa andável).
Margens têm corredor livre de 2 m (`nature.clear_banks`).

**Lugares** (`places.py`, lista `PLACES` de cada zona): cabanas com NPC de quest lateral, acampamentos de monstros, santuários (a pedra
central é um NPC de lore; o vão do círculo olha para a estrada) e entradas de dungeon, ligados à estrada por trilhas estreitas.
Marcados no minimapa por cor. **Dungeons** (`build_dungeons.py`, mapas compartilhados): Gruta Gotejante (Aldara, 6-10, Rei Slime),
Ninho Profundo (Floresta, 15-20, Rainha Aranha), Cripta de Vel'Thar (Ruínas, 25-30, Senhor da Cripta): chegada, três salões, chefe.
**Pedreira dos Golens** (Floresta, 11-15, entrada a oeste-sudoeste, `dg_pedreira`): acampamento de mineiros (Tadeu, Rosa) no vestíbulo, ala do musgo
(Golem Ancestral, modelo com árvore nas costas) e ala do cristal (Guardiã de Cristal), golens de musgo/pedra/cristal (variantes tingidas do `mob_golem`);
o Veio da Montanha leva ao Coração da Pedreira (`dg_pedreira_coracao`, selo dos dois guardiões). Salas com chão e enfeites próprios (`floor`/`decor` em
`places.DUNGEONS`, `build_dungeons._room_dress`). Chefes: `mob_kit.golem_boss`; sonda: solo 55-65%, grupo de 3 75-100%. Material: Núcleo de Pedra.
A Floresta ganhou mais aranhas, ents e o Trent Jovem (nv 14).
Cada chefe tem fases (`MonsterDef.phases`): o Rei Slime se divide em Slimezinhos e cospe ácido, a Rainha Aranha chama filhotes e
prende com teia, o Senhor da Cripta ergue servos e no fim drena vida. Rei e Rainha entram em fúria no fim. Calibrados com bot solo do nível (60-70% de vitória).
Visual de dungeon (`MapBuilder.is_dungeon`): fundo escuro sem céu, névoa densa, luz fria e fraca, bordas da tela escurecidas;
o jogador leva uma luz quente (`main._torch`, sem especular para não deixar reflexo no chão).
Câmera: 52°, 24 m por padrão, zoom de 14 a 34 m. Render a 125% da tela com MSAA 4x e sem FXAA; neblina fraca, porque ela cresce com a distância da câmera.

- **Vale de Aldara** (`city_aldara`, 300 m — cresceu 20% em volta da vila com `places.grow_aldara`, `tools/blender/zones/build_city_aldara.py` → `map_city_aldara.glb` +
  `data/zones/city_aldara.json`): vila murada (raio 30, portões N/L/S/O) com praça, chafariz e NPCs — Ancião Ravi, Capitã Mira,
  Brom (ferreiro), Lyra (alquimista), Tobias (mercador), Quadro, guardas nos portões. A vila é uma **região** do mapa
  (`MapDef.town_radius`/`in_town`): só dentro dela vale "cidade" (bots não lutam, troca de barra de skills).
  **Campina (1-10)** no mesmo vale: lago dos slimes (sul), slime azul no lago/fazenda, bosque dos javalis (leste),
  colinas dos lobos com torre em ruínas (norte), clareira do Rei Javali (oeste, além da ponte), castelo na colina (NE, landmark).
  Desfiladeiros na borda: leste → Floresta, oeste → Ruínas. Bots saem/entram pela vila pelos portões (`BotBrain._route`).
  **Vila viva**: 11 moradores passeiam (`MapsCatalog.VILLAGERS`, `wander` = raio em volta de casa ou `route` = ronda; `WorldSim._update_npc`,
  param para conversar via `Sim.hold_npc`). **5 casas abrem** (`MapsCatalog.INTERIORS`: Taverna do Javali Dourado, Casa do Ancião, Oficina,
  Botica, Casa da Família Sol): porta = portal `player_only` na frente da casa, sala montada em código (paredes `iwall`, móveis
  `prop_<table|stool|bed|counter|shelf|fireplace|barrel|rug|anvil|cauldron|door>`), `MapDef.interior` (luz quente, sem grama/névoa), NPCs dentro.
  **Praia dos Caranguejos** (margem sul do lago): Caranguejos (lv 4, `crab_shell`) e o **Caranguejo-Rei do Lago** (lv 8, 1700 HP):
  o spawner tem `emerge: [x, z, raio]`, então ele nasce na beira d'água (respingo `Events.monster_emerged` + aviso no chat), chama
  3 Caranguejinhos (0 XP) aos 60% e enfurece aos 30%. Trilhas (`places._trail`) desviam de lago, fazenda, castelo e morros
  (`avoid`); props e spawners em cima de estrada são tirados/empurrados no fim do build; `_check_layout_conflicts` garante isso.
- **Floresta Sombria (10-20)** (`build_field_forest.py`): **Posto dos Caçadores** no hub (povoado humano murado, r 24, um pouco a oeste
  por causa do rio): quartel, forja (Gunnar, aprimora a Glória), mercado (Ilsa), boticário (Fen), Comandante Hela (cadeia élfica), Ranger Teo e
  **8 sentinelas que lutam** (4 caçadoras com arco junto às torres, 4 soldados nos portões; NPC com `fighter` = atributos de `guard_*`,
  `GuardBrain`, renascem no posto em `GUARD_RESPAWN`, não roubam XP/loot). Ninhos de aranha (NO e SO), paliçada dos bandidos (NE),
  bosque dos ents (SE), rio com pontes, Árvore-Mãe ao norte. Gargantas: oeste → Aldara, **norte → Cidade Élfica** (rota das investidas).
  **Linha dos fora-da-lei** (referência: fora-da-lei de Battle for Wesnoth, nomes e arte nossos; `mob_kit.outlaw_parts`, cabeça própria por tipo):
  Trombadinha (nv 12, lenço, porrete, Pedrada que retarda, 5,8 m/s), Gatuno (13, capuz e máscara, duas adagas, Facada pelas Costas: frágil e
  perigoso), Clandestino (14, `bandit_archer`: chapéu de aba e aljava, arco, Laço que prende), Bandido (15, careca de malho, Porretada que
  atordoa), Fora-da-Lei (17, capuz e faixa vermelha, lidera 2 trombadinhas em ronda pelas estradas: `escort` + `route`), Capanga (lacaio do
  chefe) e o Chefe dos Bandidos (tricórnio com pluma, casaca, malho). Trombadinhas e gatunos na trilha leste (guardam a Carga Roubada), o
  bando pesado na paliçada, clandestinos de tocaia na emboscada (S). As quests de "bandido" contam a linha inteira (`also_counts`).
- **Investidas élficas** (`RaidSystem`, `MapDef.raid`: rota no JSON do Blender, levas/ritmo/falas em `MapsCatalog.RAIDS`): a cada ~3,5 min
  (só com o jogador no mapa) uma leva (batedores, arqueiros, linces; a cada 3ª um grifo jovem) nasce na garganta, espera as trompas
  (`RAID_MUSTER`) e marcha pela estrada norte em passo cauteloso (`RAID_MARCH_PACE`; luta em velocidade cheia). Lutam com quem os
  ataca ou chega perto (jogador, bot, invocação, sentinela), largam quem foge (`calm`) e retomam a rota; no Posto atacam as sentinelas;
  depois de `lifetime` recuam e somem. **Evento central do 2º mapa**: leva base de 21 (9 batedores, 6 arqueiros, 3 linces, 3 magos; +linces/arqueiros
  a cada 2ª, 3 grifos de guerra a cada 3ª), invasores com `RAID_POWER` 1,5 de vida/ataque e `RAID_SMART` 1,5 de aggro e ritmo de skill;
  miram em quem cura, em quem está ferido e em quem está sozinho (`MonsterBrain._raid_target`); ferido e sozinho recua para a leva;
  arqueiros se espalham. Mago élfico (`mob_elf_mage`) invoca Espíritos da Mata que marcham e seguram a leva (somem se o mago cai);
  batedor abaixo de 40% guarda a espada e puxa o arco das costas (`MonsterDef.swap`, `SimEntity.stance`, `EntityView._apply_stance`);
  lince salta 8 m (`mob_lynx_leap`). 18 sentinelas (4 no portão norte, 2 nos outros, 8 caçadoras no muro), com a regeneração do Bastião.
  Calibrado com `tools/tests/raid_probe.tscn`: sentinelas sozinhas seguram ~1/6; com 1 bot ~2/3; com 3 bots todas; chegada em ~37 s.
  Revisar a leva de perto: `-- --autostart=<classe> --elf_shot=<png>`. Humanoides de monstro fundem as peças com pele (`RigidMerge.merge_skinned`)
  e só a roupa é tingida (`EntityView.KIT_FIXED`).
  Na tela: faixa no topo (`hud._update_raid_banner`, lendo `Sim.raid_status`) com "N de M inimigos marchando / nas muralhas / recuando"
  e, nos últimos 30 s antes da leva, a contagem; no minimapa os invasores são losangos laranja e o povoado atacado pulsa.
  **Defesa do portão** (`BotBrain._defend`): bot a até `RAID_DEFEND_RANGE` do povoado decide uma vez por leva (80%) se larga a caça;
  defensor vai ao portão atacado (`RaidSystem.gate_point`), pega o invasor mais perto até `RAID_DEFEND_LEASH` além da muralha, segura
  posição em leque e, com 35% de vida, recua para dentro até 70%. **Bastião** (`RaidSystem._rally`): jogador e bots junto das muralhas
  durante a leva ganham +40% de defesa e 1,5% de vida/s. Bots do nível 8+ usam e compram poções (M). raid_probe (20 levas, nível 15):
  1 bot repele 20/20 (antes 17/20) com 0,5 sentinela morta (antes 3,0); 3 bots, 20/20 e a leva nem chega.
  **Força pelo nível do jogador** (`RaidSystem.power_step/scaled_def`): um passo por nível do jogador no mapa acima de 15, até 20
  (5 passos). Cada passo: invasores +1 nível, +8% vida, +6% ataque, +6% defesa, +8% XP (mesmo id: quests e loot iguais);
  reforço na leva em `RAIDS["scale_extra"]` (passo 3: +1 batedor; passo 5: +1 arqueiro). A faixa mostra o nível da leva.
  raid_probe (`--raid_level=N`, bots do mesmo nível): sentinelas sozinhas repelem 85% na base, 40% no 16, 15% no 17 e nada do 18
  em diante; com 1 ajudante ~90% em todos, perdendo 0,5 sentinela na base e 1,3 no 20.
- **Faixa 10-20, teste de jogo** (`tools/tests/band_probe.tscn`, 2026-11-05): auditoria das quests (todo alvo nasce, todo item tem
  fonte) e caçada de bot do nível contra 4 monstros seguidos sem poção. Alvo: 3-5 s por monstro e 20-45% de vida no ponto mais baixo
  (elites sozinhos: 10-15 s). Antes os comuns morriam em 1-3 s quase sem bater; vida e ataque foram ajustados em voltas (XP sobe junto
  com a vida, ^0,6). Ent e Trent ganharam Chicote de Cipó (prende à distância; antes todo mundo os kitava).
  Monstro que persegue contorna obstáculo (`MonsterBrain._steer`); atirador cujo tiro não tira vida há 3 s chega mais perto
  (`_shots_blocked`): antes ficavam travados atrás de árvore/muro.
  Chefes com repertório (boss_probe, 20 lutas): Chefe dos Bandidos (facas envenenadas, bomba de fumaça, capangas, investida no fim;
  sozinho 75% em ~58 s, trio 95%), Rainha Aranha (poça de veneno, salto da rainha; sozinho 75% em ~44 s, trio 100%), Rei Élfico
  (lâmina da coroa, chuva de flechas, julgamento de espinhos; trio 85% em ~45 s), Conde Vargo (marca de sangue, revoada; trio 75% em
  ~56 s). Todo chefe da faixa tem `intro` (fala ao entrar em combate, de novo depois de um reset) e `last_words`.
  Sabor: moradores refugiados no Posto (`MapsCatalog.POST_VILLAGERS`) e falas de bot por mapa (`BotsCatalog.LINES["hunt_<mapa>"]`).
- **Colheita na Cidade Élfica**: Erva Azul no lago, cogumelos sob os trents, Pedra Estelar no Altar da Lua e caixotes de Aço Élfico
  no acampamento da patrulha (guardado).
- **Cidade Élfica (17-21)** (`build_elf_city.py`): anel élfico (muralha clara r 66, 6 portões) em volta da **Árvore-Mãe Ancestral**
  (copa alta, acima da câmera), dois anéis de casas (~50), bairros com chão próprio (mercado NE, quartel L, jardim com lago NO) e anel viário.
  **Exército** (hub hostil: `HOSTILE_HUBS` nos testes): 5 esquadrões de **Sargento Élfico** com 3 guerreiros de escolta fazendo ronda
  (`route` no spawner), arqueiros nos postos de vigia, guardas nos portões. **16 cidadãos neutros** (`MapsCatalog.ELF_CITIZENS`, modelos
  `mob_elf_citizen[_f]` tingidos pela cor do NPC) andam e falam. **Escolta** (`MonsterDef.escort {id, count}`, `MobSystem.spawn_escort`):
  seguidores nascem num anel em volta do líder, seguem a vaga dele (`MonsterBrain._follow_leader`), entram na briga dele e vice-versa,
  voltam a nascer (`ESCORT_RESPAWN`) enquanto ele vive; são monstros normais (XP/saque). **Fortes** (`places.fort`: paliçada, torres, cabanas)
  fora do muro com capitães chefes: **Sylvara, a Caçadora Veloz** (N, arqueira de 7 m/s com 5 linces), **Aerion, Senhor dos Grifos** (NO,
  com 2 grifos) e **Ilwen, Guardiã da Seiva** (L, com 2 trents e espíritos); sozinho nv 20 vence ~45-70%, grupo de 3 ~80-100% (`boss_probe`).
  Quests dos fortes com Yara/Caelir e a repetível "Patrulhas Élficas" no Altar da Lua (qualquer elfo conta). Ninho dos
  grifos (NO), bosque dos trents (NE, chão escuro), poço da lua (O), riacho com pontes, cerco humano na entrada sul
  (Batedora Yara), Caelir o exilado, Altar da Lua (caçadas). Uma porta entalhada no tronco da Árvore-Mãe (lado sudeste, de frente para a câmera; `places.DUNGEONS` `style: "tree"`, `places._tree_door`) abre o **Coração da Árvore** (`dg_coracao`, por dentro da árvore: paredes de casca altas, chão de raiz, poças de seiva, `floor`/`decor`/`inner`/`pool` por salão): raízes, seiva,
  trono do **Rei Élfico Aelthar** (Guarda Real aos 70%, raízes + grifos aos 45%, fúria aos 20%; grupo de 3 vence ~80% em ~50 s).
  **Moedas**: Rei solta 4-6 sempre, Guardião 5% de 4 (`MonsterDef.coin_*`). **Glória** (lendário nível 20) aprimora no ferreiro com
  Aço Élfico (+1..+5) e Seiva da Árvore-Mãe (+6..+9), ouro a 60% (`PLUS_ELF_*`).
- **Terceiro andar (20-30): Luz contra Trevas.** Referência visual e de elenco: loyalists e mortos-vivos de Battle for Wesnoth (nomes e arte nossos).
  - **Bastião da Aurora** (`field_ruins`, `build_field_ruins.py`; o id antigo ficou, saves e portões não mudam):
    - Cidade murada r56 em volta da Catedral da Aurora (marco: torre com flecha dourada), com mercado, quartel, claustro e dois anéis de casas.
    - `hub` com cristal e serviços (Marechal Aldric, Alta Sacerdotisa Lyria, ferreiro Doran, Capela dos Pedidos).
    - **Guarnição** de 26 lutadores da Aurora (Lanceiro, Cavaleiro, Paladino, Sacerdotisa, Besteiro: `guard_*` com modelo `mob_loyal_*`), renascendo em 12 s (`DAWN_RESPAWN`).
    - **Três fronts** com chão e investida próprios:
      - oeste: pântano pútrido do Carniçal;
      - norte: ossos, com a Cripta;
      - sul: campo gelado da Torre.
    - Cada front tem a sua rota (`MapDef.raids`, `RAIDS["field_ruins"][lado]`) e monstros que somem quando a fortaleza do lado cai (`unless`).
    - O leste é o lado seguro (Aldara, cabanas, rochedo do Dragonete).
    - **Guerra que muda com a conquista:**
      - **Fúria:** cada fortaleza retomada multiplica as levas dos fronts que sobram por `RAID_RECLAIM_MULT` (1,5) e soma elites (`reclaim_extra`), com teto de `RAID_WAVE_CAP` (90) por leva (`RaidSystem.reclaimed`).
      - **Reforços:** cada fortaleza retomada manda soldados ao Bastião a cada 2 min (`ASSAULTS["field_ruins"]["reforco_<lado>"]`, a rota da investida ao contrário até a praça).
      - **Surtida:** quando uma leva chega à muralha, 20 soldados saem da porta da catedral até o portão atacado (`MapDef.sortie`, `SORTIES`, recarga `RAID_SORTIE_COOLDOWN` 180 s) e voltam/somem quando a leva acaba.
      - Com duas retomadas, o último front (~60) só cai com o jogador e o grupo (3 bots nv 27: 4/4).
      - **Torres:** 10 torres na muralha com besteiros no alto (`guard_wall_crossbow`, `npc_data.perch` = altura visual; `SimEntity.is_perched`). Atiram por cima do muro com pouco dano, não andam, não são alvo, não tomam dano e não puxam aggro.
      - **Serviços:** catedral a 72%. Na praça, Relicário (lendárias por moeda) e Depósito; a Alta Sacerdotisa também reseta skills (`Balance.SKILL_RESET_NPCS`).
  - **Covil do Carniçal (praga):** estrada de bile, jardins venenosos (cogumelos e flores doentes), montes de pústulas, enxames de moscas e poço de podridão no pátio, com o dobro de criaturas.
    - O Carniçal Gigante tem feridas com pus, rasgo na barriga, chifre, nuvem de moscas, sino enferrujado, chaminés de gás e cutelo.
    - Os chefes das fortalezas renascem em 2 min enquanto a quest de retomada não sai.
  - **Fortalezas** (`build_dawn_forts.py`, um mapa por laço): Covil do Carniçal (20-23), Fortaleza dos Ossos (23-26), Torre do Mago Gélido (26-29).
    - Cada uma tem estrada, dois postos para retomar, muralha com marco no pátio, prisioneiros e chefe:
      - Carniçal Gigante: ninhada de larvas e bile;
      - Vorhag, o Cavaleiro da Morte: ergue soldados, onda de morte;
      - Morvath, o Arquimago Gélido: gelo, prisão, nevasca, espectros.
    - **Conquista por personagem** (`WorldState`: spawner/NPC/rota/assalto com `if`/`unless` pela quest do jogador):
      - a quest dos postos põe guardas da Aurora nos postos;
      - a do chefe cala a fortaleza e a investida do lado;
      - os prisioneiros saem e nasce o assentamento (capitão, ferreiro de campo, mercador) com guarnição;
      - a fortaleza seguinte passa a receber a **leva aliada** (`MapDef.assaults`/`ASSAULTS`, `GuardBrain` em marcha) subindo a estrada.
  - **Cidadela do Lich** (30, selo NE do Bastião, abre com as três): portões internos, elites das três fortalezas, a Ofensiva da Aurora sobe junto, e Azhar, o Lich-Rei (três fases).
  - **Trevas:** Guardião de Ossos/Guarda da Cidadela bloqueiam golpe físico de frente (`MonsterDef.front_guard`); por trás ou com magia passa.
  - **Recompensas:** Prata Consagrada (+1..+5) e Fragmento da Aurora (+6..+9) aprimoram lendários 25+ (`PLUS_DAWN_*`); quests principais e chefes dão Moedas Lendárias.
  - **Calibrado** (`boss_probe` 20-24 lutas):

    | Chefe | Sozinho | Grupo de 3 |
    |---|---|---|
    | Carniçal | 67% | 87% |
    | Vorhag | 45% | 90% |
    | Morvath | 45% | 100% |
    | Lich-Rei | — | 70% |

    `raid_probe --route` repele os três fronts com a guarnição (2-9 guardas caem por leva).
- Loot: materiais por campo (gel, pele, presa, erva, minério, seda, casca, insígnia, osso, essência, núcleo, escama) + raros.

## Quests (cadeia)
q01 bem-vindo (TALK) → q02 slimes → q03 gel → q04 primeira poção (CRAFT) → q05 presas → q06 lobos → q07 rei javali →
c1 terra revirada (TALK) → c2 descida (REACH) → c3 Capitão + c4 Viúva (ramos) → c5 aviso à Capitã → q08 floresta (TALK) → q09 seda → q10 bandidos →
q10b Rainha Aranha → el1 trompas → el2 segurar o portão (investidas) → el3 além da garganta → el4 trents → el5 Guardiões → el6 Rei Élfico → q12 Bastião → dw_gates segurar os portões → postos e Carniçal Gigante → assentamento → postos e Vorhag → postos e Morvath → Ofensiva da Aurora (Lich-Rei); laterais: núcleos, Cripta, Dragonete. c6 (Conde Vargo) é opcional e pede grupo; q11 (Chefe dos Bandidos) e a linha do Dario viraram laterais.

Faixa do meio (10-20): monstros 1-2 níveis acima do antigo, quests de abate pedem 1,5x e a faixa toda paga mais em quest (`Balance.XP_QUEST_SHARE_BAND`: 55% em vez de 45%).

Laterais vêm das cabanas e de Bento, o Coveiro; recompensas repetíveis (`b_*`) ficam nos quadros e não acendem marcador. O jogador pode desistir de uma quest ativa.

**Portões** (`MapsCatalog.PORTAL_GATES`, só o jogador; bots passam): Catacumbas = nível 8 + c1; selo do Trono = Capitão e Viúva abatidos; Floresta = nível 10 + c5;
Cidade Élfica = nível 16 + el2; Ruínas = nível 20 + el6 (Rei Élfico; saves v<3 que já mataram o Chefe dos Bandidos ficam com o portão aberto). O chefe final nunca fecha um portal de zona, para precisar de grupo não travar quem joga sozinho. Portão aberto continua aberto.
Save sem `save_version` abre os portões de história que o nível alcança e o mapa onde já está; selos de chefe continuam valendo.

**Catacumbas do Conde (8-13)**: vestíbulo com a Irmã Odete, ala oeste (mortos, recrutas, Capitão de Ossos), ala leste (carniçais, aparições, alcova do Coveiro, Viúva Lamentosa),
selo ao norte → Trono do Conde (mapa à parte). Capitão: lacaios em 66% e 33%. Viúva: lamento em cone que retarda; em 50% almas e toque que corta cura (Murchar).
Conde: dreno, ergue mortos em 70%, fúria e onda de morte em 30%. Chefe sem alvo reseta por inteiro.

**Escudos**: 18 modelos únicos (`shield_kit.py`), usados por Paladino e pelo Sacerdote de maça. Com escudo da afinidade, o Paladino junta Juramento ao bloquear (até 5 cargas, aparar vale 2) e a próxima skill sagrada ou de escudo gasta tudo; skills de escudo também escalam com a DEF dele. O Bispo cura 5% do HP do aliado mais ferido ao bloquear (Graça, recarga de 4 s) e, ao aparar, protege quem está por perto. Com escudo, a chance de bloqueio usa o maior entre FOR e WILL. Guarda sem MP quebra: só volta soltando o botão e com `Balance.BLOCK_MIN_MP`. Dano no tempo não apara. Séries e plano de arte: `docs/equipment_series.md`.

**Grupo e papéis**: o alvo do monstro segue a ameaça (troca em 110%); Provocar prende por 4 s (chefes 2 s). O abate vai para quem causou mais dano real, com o grupo somado,
então provocar não rouba abate e estranho não rouba chefe. Saque tem dono por 20 s e gira entre o grupo; ouro de grupo é dividido direto.

NPCs mostram **!** dourado (quest nova), **!** cinza (quest ainda bloqueada por nível ou quest anterior) e **?** (entregar, ou conversar numa
quest de conversa), na cabeça e no minimapa: `QuestSystem.npc_marker`. No minimapa, ! dourado e ? longe ficam presos na borda, apontando o rumo.
**Seta amarela** no minimapa: objetivo da quest rastreada (a aceita por último; clique no título do rastreador troca, ▶ amarelo).
`QuestSystem.objective` acha o alvo pelo tipo (spawner, colheita, quem dropa, investida, NPC, lugar, bancada; pronta = quem recebe) e
`guide_point` aponta para ele ou, noutro mapa, para o portal do caminho (`PortalSystem.portal_towards`, busca no grafo de portais, também usada pelos bots).
Longe fica na borda; perto vira seta sobre o ponto com anel. Revisar: `-- --autostart=<classe> --quest_shot=<png>`.

## Combate: resposta
Anda durante golpes e magias rápidas (60%; magias longas 25%; investidas 0), o rosto segue o cursor depois do impacto, e o básico até o impacto.
Dash interrompe qualquer skill (antes do impacto devolve MP e recarga). Buffer de 0,25 s; o ataque segurado não apaga o que está na fila.
Pernas correm por cima do golpe (`LegOverlay`) e o clipe é ajustado em duas fases: preparo até o impacto, resto até o fim da skill.

## Escudos
14 escudos nomeados (`GearCatalog.SHIELDS`), lendários, cada um com silhueta, ícone e reação ao bloquear (cura, barreira, mana, reflexo, veneno, queimadura, lentidão, raiz, atordoar). A barreira dura `Balance.SHIELD_BARRIER_TIME` (5 s) e nunca encurta um escudo maior.
**Aparar**: erguer o escudo até 0,22 s antes do golpe tira 90% do dano, dobra a reação e atordoa quem bateu de perto (recarga 0,9 s; segurar não apara).

## Equipamento: slots
Toda classe usa arma, mão secundária, cabeça, peito, calça, luvas, botas, capa, amuleto e dois anéis. Calças, capas, amuletos e anéis são
gerados em `GearCatalog.wearables` (4 tiers, sem restrição de classe); capa, amuleto e anel têm temas Guerreiro, Caçador e Sábio.
Tiers 0 e 1 estão no mercador; todos caem de monstro (`Balance.GEAR_DROP_CHANCE`). Conjuntos lendários seguem com as peças de antes.

## Crafting / loja
Ferreiro: armas/armaduras físicas por tier (lv 5/14/24). Alquimista: poções, elixires, robes/varinhas/cajados/foices, acessórios mágicos.
Venda = 50% do preço. Tiers de equipamento: 0 (lv1) · 1 (lv8) · 2 (lv16) · 3 (lv24, materiais de boss).

## Bots
FSM: TOWN_IDLE ↔ TOWN_WALK → TRAVEL (portal, ou direto se a caça é no próprio vale) → HUNT (área do nível) → RETURN (HP < 30% ou bolsa > 60; volta à vila pelo portão ou portal) → SHOP (vende, recompra poções) → …
Usam skills, poções e bloqueio reativo; falam no chat (contexto cidade/caça/morte/level/viagem); respondem ao jogador.
**Conversa por contexto** (`core/sim/systems/bot_chat.gd`, falas em `BotsCatalog`, montadas por laços em `GameData.bot_chat`):
- *Onde*: `BotChat.place_kind` dá o tipo de lugar pelos dados (`MAP_KIND`, `interior`, `parent_map` = dungeon, dentro/fora da muralha):
  Aldara (vila/campina), Floresta/Posto, Cidade Élfica, Aurora/Bastião, fortes, Cidadela, dungeon, interior. Chefe vivo perto
  (`BOT_CHAT_BOSS_RANGE`) ou investida no mapa viram assunto (`BOT_CHAT_SITUATION`); `LINES["hunt_<mapa>"]` somam ao lugar.
- *Quem*: voz de cada classe (falas + modelos `CLASS_WANT`/`CLASS_DOING` × peças da classe) e toque por build (`BUILD_LINES`).
- *Grupo com o jogador*: o bot fala no canal do grupo, pelo nome (`{p}`; `_address` gera "fala", "{p}, fala", "fala, {p}"), e reage a
  entrar no grupo, vida baixa/morte/nível do jogador, chefe (início e queda), saque raro/lendário, cura (dada e recebida), entrar em
  dungeon/mapa, colheita, investida e `/p` (resposta pelas palavras: `REPLY_KEYS`). Voz da classe em `PARTY_CLASS`.
  Ritmo: fila com "digitação" (`PARTY_REACT_DELAY`), `PARTY_CHAT_GAP` entre falas, `PARTY_REACT_CD` por evento, conversa solta do
  grupo a cada `PARTY_CHAT_MIN..MAX`; estado no dicionário do grupo, falas recentes em `BotBrain.recent_lines` (nunca repete seguida).
Movimento: atravessam água só pelas pontes (`WorldSim.water_path`, grafo de cabeceiras + margens + anel dos lagos, seguido por
`BotBrain._water_step`); preso, o bot desvia a 90° e abre para 135°/180° se prender de novo (`BotBrain._steer`).

## Grupo (party) — `PartySystem` (`Sim.party_*`), constantes `Balance.PARTY_*`
- Até 5 membros. Convite → aceitar (expira em 30 s); quem convidou vira líder. Líder convida, expulsa e passa a liderança;
  quem sai do grupo de 2 desfaz o grupo; líder que sai passa a liderança ao próximo.
- **XP**: abate dividido entre os membros vivos no mesmo mapa a até 45 m e com até 15 níveis de diferença;
  total × (1 + 15% por membro extra) ÷ membros, cada um com o multiplicador do próprio nível. Quests de abate contam para todos eles.
- **Curas e buffs em área** só pegam você, o grupo e as invocações deles (`SimEntity.is_friend`); invocações herdam o grupo do dono.
- **Efeito-assinatura** (`ClassesCatalog.SIGNATURES`, `LegendEffects.signature_on_hit`): toda build lança de graça a magia dela ao acertar,
  sem depender da arma (Fogo: Bola de Fogo; Gelo: Lança de Gelo; Iluminado: Martelo de Luz; Caçador: Flecha Gélida...). Chance
  `SIGNATURE_BASIC_PCT` (+1%/5 níveis) no básico e `SIGNATURE_SKILL_PCT` por acerto de skill, recarga `SIGNATURE_ICD`, poder `SIGNATURE_POWER`
  x o peso da build; o que ela acerta não dispara outra. Arma lendária com a mesma magia (Brasa Viva) soma chance.
  Armas lendárias que lançam magia (Brasa Viva, Castigo Sagrado, Lua Cheia, Praga) disparam ao acertar com ataque OU habilidade
  (no máximo 1 por `LEG_CAST_ICD`); Arco Voltaico e Pólvora valem no básico e em habilidades de alvo único. O básico da build
  ganha a aparência do tema (`SkillDef.look`, só visual: não estilhaça nem atordoa) e perde `SIGNATURE_BASIC_TRIM`. Calibrado com
  `tools/tests/dps_probe.tscn` (cada build, nv 10/20/30, com x sem: -5%..+10%); revisar com `-- --autostart=<classe> --sig_film=<png>`.
- **Invocações lutam sozinhas** (`MonsterBrain._summon_target`): quem bate no dono, depois quem o dono ataca, quem bate nela, o monstro mais perto do dono
  (`SUMMON_ASSIST_RANGE`); coleira de `SUMMON_LEASH` no dono; usam as skills do monstro; as que atiram (`ranged`: elementais de gelo/raio, lich) recuam
  medindo do alvo. Ataque e magia vêm do dono. Ordem do companheiro segura o alvo `PET_COMMAND_FOCUS` s. Sonda: `tools/tests/pet_probe.tscn` (FLAG = sem alvo, golpe lento, atirador colado).
- **Bots**: aceitam convites (nível próximo); no grupo, quem não é líder segue o líder (por portais também), cura quem
  está abaixo de 60% de HP e ataca o que bate no grupo. Bot que sai pra caçar às vezes chama bots da vila e, raramente, o jogador
  (um convite por vez, com recarga). Grupo só de bots costuma se desfazer quando voltam à vila.
- **UI**: quadros dos membros abaixo do seu (HP/MP, ♛ líder, mapa se longe), janela Grupo (P) com membros e "Por perto" para convidar,
  popup de convite (Aceitar/Recusar), nomes e pontos do minimapa em verde. Chat: `/party` (até `PARTY_SEEK_MAX` bots do mapa, sozinhos ou líderes com vaga e de nível próximo, te convidam um por vez; recusou → o próximo), `/convidar nome`, `/sair`, `/expulsar nome`,
  `/lider nome`, `/p texto` (canal do grupo).

## Visual
Resolução nativa + MSAA 4x/FXAA, sombras 4096 suaves. Toon 3 tons (sombra azulada, meio-tom, rim e brilho especular —
`shaders/toon_light.gdshaderinc`, usado também pelo chão e grama) + outline inverted hull. Ambiente: céu procedural
(luz ambiente), SSAO + SSIL, glow suave, névoa de profundidade, Filmic + saturação. Chão pintado por ruído (`ground.gdshader`),
grama/flores em MultiMesh com vento (`grass.gdshader`). Monstros esculpidos em `tools/blender/mob_kit.py`.
Animações de combate (`chibi_kit.animate_combat`): golpe por família de arma — 1 mão (combo de 2 cortes), 2 mãos (pancada de
cima), duas armas (alterna mãos), adaga (estocada), arco (puxa e solta), cajado/varinha (projeta), magia em área, buff, giro e
estocada de skill. A EntityView reinicia o clip a cada ação e acelera o clip para o frame de impacto (`IMPACT_FRAME`) bater
com o startup da skill.
Ciclos v3 (`chibi_kit.animate_v3`): idle com respiração e peso (variantes `idle_bow`/`idle_staff` pela arma), corrida com torção quadril/peito, passada ampla e cabeça estável
(toca na velocidade real do personagem), pulo (impulso → encolhe), queda, pouso amortecido, dash, reação e morte em etapas. Arco: puxa até a bochecha e solta
(recuo); magia: junta no peito → braços em V ao lado da cabeça → empurra. Braços/pulsos das poses-chave (`ARM_V/FRONT/SIDE/CHEST`)
resolvidos numericamente no rig (chibi: o braço não alcança acima da cabeça).
**Pulo (Espaço)**: a sim guarda só a altura (`jump_h`, ~1 m, ~0,6 s, `Balance.JUMP_*`); no ar anda e dá dash, golpes e skills
esperam o pouso no buffer de input. O pulo não passa por cima de obstáculos (a sim é plana).
HUD (base 1600×900, escala com a janela): quadro do personagem (sup. esq.), minimapa redondo + nome do mapa + quests (sup. dir.),
chat / hotbar / dicas embaixo. Minimapa (`game/ui/minimap.gd`) desenhado do MapDef (chão do vale, água, estradas, vila, casas,
árvores, penhascos, portais) + pontos de bots/monstros/NPCs; gira com a câmera; roda do mouse = zoom.
Rastro de arma (`KitModel`): fita translúcida que segue a ponta da arma de golpe (não o arco) do fim da preparação até logo
após o impacto, na cor do item, some em 0,2 s. Revisar: `tools/lineup/lineup.tscn -- --anim=<golpe> --trail --t=0.3`.
Vale de Aldara, passe de detalhe: manchas de cor por região, fazenda com trigo/feno/moinho, píer no lago, fogueira do guarda,
placas nos cruzamentos, bancas e lampiões extras na vila, arbustos na beira das estradas e pedras no pé dos penhascos.
Janela C: boneco 3D (KitModel em SubViewport) com o equipamento, slots dos lados (clique desequipa), stats e conjuntos.
Props/construções em `tools/blender/prop_kit.py` (casas enxaimel com telhas, árvores, poço, chafariz...; materiais `tint`/`tint_l`/`roof`
recebem a cor do obstáculo no `MapDef`). Ruas de paralelepípedo e restos de calçamento nas ruínas vêm do `ground.gdshader` (voronoi). Câmera perspectiva FOV 35, pitch 52°, yaw em 45°.
Obstáculos entre câmera e jogador ficam 72% transparentes. Chibi: cabeça ≈ 1/3 da altura. Paleta: pedra creme, telhados terracota/azul, verdes suaves.

## Fora de escopo (por enquanto)
Rede real, PvP, guildas, dungeons instanciadas, áudio.

## Depósito

Guarda-volumes Nilo, na praça de Aldara (papel `storage`): bolsa ↔ depósito por clique (pilha toda; Shift = 1), até `Balance.STORAGE_SLOTS`
tipos de item, só a `STATION_RANGE` m do NPC (`WorldSim.storage_deposit/withdraw`). `SimEntity.storage` vai no save; cada personagem tem o seu.
Monstro que usa o modelo de outro (Slime Azul, Rei Slime, Presa-Rachada) recebe a própria cor no corpo (`EntityView.monster_tint`).

## Grupo segue o jogador / Reis

Jogador que entra num grupo de bots vira o líder. Quando o líder passa por um portal, os bots do grupo a até `PARTY_PORTAL_FOLLOW` m
passam junto (inclusive para dungeons); bot em outro mapa por mais de `PARTY_CATCHUP_TIME` s reaparece ao lado do líder. Lá dentro
seguem, curam, provocam e atacam o que bate no grupo (`BotBrain._follow`).
**Reis**: a cada `ELITE_KILLS` (40) abates do mesmo monstro comum num mapa surge o Rei dele num spawner do tipo (um vivo por tipo):
`ELITE_HP_MULT` 5x vida, 2x ataque, maior, coroa dourada, 6x XP/5x ouro, **lendário garantido** (no mínimo o 1º conjunto);
quests de abate contam o Rei como o monstro comum (`MonsterDef.elite_of`, `WorldSim.elite_def/_count_kill`).

**G** volta para a cidade: `Balance.RECALL_TIME` (3 s) parado e fora de combate; andar, agir, levar dano ou G de novo cancela; os bots do grupo por perto vêm junto (`WorldSim._update_recall`).
**Cristal de Retorno** (`MapsCatalog.CRYSTALS`: praça de Aldara e Posto dos Caçadores; role `crystal`, `prop_crystal`): "Vincular aqui" faz o G e o renascer
levarem para a frente dele (`SimEntity.bind_map/bind_pos`, `PortalSystem.home_of`, salvo em `bind`; save antigo = Aldara). O Posto é `MapDef.hub`: dentro do muro
dá para trocar skills e escolhas (`MapDef.in_hub`), sem virar a cidade inicial. Losango azul no minimapa (maior = o seu).

XP: `Balance.XP_BASE` 220 × `XP_GROWTH` 1,30^(nível−1) (subir é ~2x mais lento que antes).

## Conjuntos lendários (peças e arma)

Cada conjunto tem **5 peças de armadura** (cabeça, peito, **calça**, luvas, botas): os bônus saem com 2, 3, 4 e 5 delas. A arma (e a 2ª arma /
mão secundária) é do conjunto, mas **não conta** nas peças: a arma lendária tem **efeito próprio** pelo papel da build, crescendo por tier —
um por build (`GearCatalog.LEGEND_EFFECTS`, números [base, por tier]):
Guardião Retaliação (devolve corpo a corpo) · Cruzado Julgamento (chance de atordoar) · Gêmeos Frenesi (golpes acumulam vel. de ataque) ·
Executor Carrasco (+dano em alvo < 30%) · Sacerdote Égide (cura vira barreira) · Iluminado Castigo Sagrado (básico lança Castigar) ·
Urso Casca Viva (apanhou: Pele de Carvalho, 20 s) · Lobo Sangue da Matilha (sangramento) · Xamã Lua Cheia (básico lança Fogo Lunar) ·
Caçador Marca (alvo recebe mais dano de todos) · Atirador Pólvora (tiro explode em área) · Lâminas Veneno Letal · Duelista Riposte (esquivou,
contra-ataca) · Fogo Brasa Viva (básico lança Bola de Fogo) · Gelo Coração de Gelo (apanhou: Nova de Gelo, no máx. a cada 20 s) · Raio Arco
Voltaico (básico salta para +1 alvo) · Invocador Legião (abate levanta esqueleto) · Ceifador Ceifa (abate cura) · Sombras Praga (básico lança Agonia).
Atributos: toda peça lendária usa os dois atributos da build; escudos nomeados seguem a afinidade (Paladino VIT/FOR, Bispo VIT/WILL);
o Elementalista Raio é INT/WILL (AGI não serve a mago) e o conjunto inicial do Paladino é VIT/FOR.

## IA dos bots no combate (`BotBrain._fight`)

Alvo fixo enquanto vale (vivo, perto: `BOT_STICKY_RANGE`) — sem trocar a cada pensamento. Corpo a corpo: alcance do básico = raio do cone,
com histerese (entra a 75%, sai a 95%), fica parado durante o golpe, encosta num lado do alvo e usa o dash para fechar distância; se "no alcance"
o alvo não perde vida (obstáculo), chega mais perto; distância anda de lado até ter linha de tiro. Skill: a melhor pontuada (buff que não está
ativo, área quando há vários, a mais forte), invocação quando não há. Defesa: sai de área telegrafada de monstro (chão, em volta, cone, linha)
com dash se der; poção a 45% (corpo a corpo); sem poção e < 20% recua. Em grupo: segue o alvo do líder e entra quando ele briga.
Dungeons: 25% maiores (`build_dungeons.SCALE`) e `SPAWN_COUNT_MULT_DUNGEON` 2x de monstros, para grupos.
