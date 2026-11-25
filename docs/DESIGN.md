# RagnaEx — Documento de design (fonte da verdade para os agentes)

## Visão
"MMO" 2.5D single-player com bots que parecem jogadores. Referências: Ragnarok Online (câmera alta fixa, mundo 3D),
Tree of Savior (arte: chibi, pastel, pintado/flat, outline), Drakantos (combate de ação sem target-lock: personagem encara
o cursor, LMB básico, skills como skillshots/área no cursor).

## Pilares
1. **Responsividade**: input nunca é engolido (buffer de 15 ticks, que não vence enquanto a própria skill prepara), startup curto,
   recovery cancelável por movimento/dash, hit-stop curto. **Encadear (estilo Diablo)**: 0,05 s depois do impacto outra skill ou o
   básico já sai, sem esperar a animação acabar; o golpe atual sempre acerta (tudo é aplicado no impacto). Básico atrás de básico
   mantém o ritmo dele; monstros não encadeiam (`WorldSim._can_chain`, `Balance.CHAIN_AFTER_IMPACT`). **Canal** (`channel`: Mente
   Açoitada, Drenar Alma, Raio do Vazio, Ciclone do Titã): o básico (inclusive o segurado) espera o último pulso; skill, Suprema ou
   dash apertados ainda cortam o canal depois do 1º pulso (C1, 2026-11-23; check `_check_channel_hold`).
   **Dash com i-frames**: o dash inteiro (`Balance.DASH_IFRAMES`, 0,18 s) é invulnerável a golpe direto, skill, projétil e chuva
   de chefe, e efeito de inimigo (atordoar, prender, gancho) não pega; dano no tempo que já estava em você continua. Vale também
   no dash que cancela uma skill. Na tela aparece como esquiva (`Events.dodged`).
   **Recarga e cargas do dash** (2026-11-24): recarga `Balance.DASH_COOLDOWN` × `cooldown_mult` da evolução. Com 2+ cargas
   (Passo Duplo) o próximo dash sai depois de `DASH_CHARGE_WINDOW` × 0,25, e cada carga gasta volta sozinha, uma de cada vez
   (`WorldSim._tick_dash_refill`; antes só voltavam depois de gastar todas). Na tela: gomos nos pés do seu personagem só enquanto
   alguma carga enche (`DashGauge`), vaga Shift na barra com leque e número de cargas, brilho + som `dash_ready` quando uma carga
   volta. Checks `_check_dash_charge_refill`, `_check_dash_display`; foto: `-- --dash_shot=<pasta> [--dash_talent=<id>]`.
   **Skills cedo perto do início na teia** (2026-11-24, pedido do usuário): a malha de estradas é uma árvore sorteada e o caminho até uma casa vizinha podia dar a volta (Berserker pagava 12 pontos até as skills do nível 1). Agora skill inicial ou de nível <= `Balance.WEB_EARLY_LEVEL` (10) ganha atalhos: as estradas que faltam no caminho mais curto da grade até a entrada do círculo (`TreeCatalog._early_shortcuts`; só acrescenta nós, sem sorteio: ids/posições/saves iguais). Iniciais <= `WEB_START_REACH_MAX` (4) pontos, nível <= 10 <= `WEB_EARLY_REACH_MAX` (10). Medir: `web_probe.tscn -- --reach[=<classe>]`; check `_check_web_early_reach`.
   **Nós genéricos do dash** (2026-11-24, decisão do usuário): toda classe ganha na teia, em anel na casa do dash (depois da
   evolução própria dela), Passada Longa (10: +20% distância), Fôlego (20: −25% recarga), Esquiva Firme (20: +0,15 s invulnerável)
   e Passo Extra (30: +1 carga). Números em `Balance.DASH_NODES`/`DASH_NODE_COST`; ids `<prefixo>_t_dash_*` (`TalentsCatalog.dash_nodes`,
   anel em `TreeCatalog._dash_ring`). Cargas: `charges` fixa o mínimo (Passo Duplo), `charges_add` soma, teto `DASH_MAX_CHARGES` 3
   (só o Assassino chega a 3). A volta das cargas seguintes lê a recarga das evoluções (antes ignorava o `cooldown_mult` depois que o
   dash chegava). Check `_check_dash_nodes`.
2. **Mira pelo mouse**: toda skill tem forma no chão (retículo) — SELF / DIRECTION / GROUND / CONE / TARGET.
3. **Equipamento é poder, build é escolha**: atributos vêm só de itens; level dá HP/MP base e pontos de skill;
   a arma empunhada decide quais skills funcionam.
4. **Mundo vivo**: bots usam o mesmo pipeline do jogador; caçam, vendem, conversam, morrem.
5. **Pronto para rede**: `core/sim` é o servidor; apresentação é cliente burro.

## Controles
WASD mover · LMB ataque básico · RMB (segurar) bloqueio · 1-6 skills · F1-F3 poções · H montar · G voltar à cidade · Shift dash · Espaço pular · F interagir ·
Q/E girar câmera 45° · scroll zoom · I bolsa · C personagem · K skills/maestria · L quests · P grupo · Enter chat · Esc fecha · F11 tela cheia (padrão) ↔ janela 1920×1080.

## Atributos → stats (`core/sim/stats.gd`, constantes em `data/balance.gd`)
Os coeficientes valem por `Balance.ATTR_SCALE` (10) pontos de atributo: "/pt" na tabela = a cada 10 pontos.
| Atributo | Efeito |
|---|---|
| FOR | ATK físico (×2/pt); com escudo: +0.6%/pt chance de bloqueio (usa o maior entre FOR e WILL); com arma física: redução ao bloquear 30% + 0.5%/pt (cap 60%) |
| AGI | arco: substitui FOR (×2.2/pt); adaga: +1/pt; outras ×0.25; crit físico +0.4%/pt; **esquiva passiva** 10% × (AGI/140)^1,25 (só personagens, só golpe direto; soma com a do Assassino sob o teto de 45%) |
| VIT | HP +12/pt; DEF física +1.5/pt |
| WILL | cura +3%/pt; MP +8/pt; DEF mágica +1.5/pt |
| INT | MATK ×2.5/pt; crit mágico +0.4%/pt |

Esquiva da AGI (decisão do autor, 2026-11-12; `Stats.agi_evasion`, `Balance.EVASION_AGI_REF/REF_PCT/EXP`): AGI 140 (escala antiga, build toda em
AGI no 45) = 10%; 40 (força com AGI de passagem) = 2%; 78 (Carniceiro) = 4,8%; magos 0%. Monstros não esquivam; dano no tempo não é esquivado.
Lanceiro (decisão do autor, 2026-11-16, opção B): +5% de esquiva própria (`Balance.LANCEIRO_EVASION_PCT`) no notável **Passo do Caçador**,
o 1º notável do setor do Lanceiro na teia (`Balance.BUILD_WEB_NOTABLES` troca o bônus sorteado desse notável; mantém o atributo e o sorteio
da teia). Custa caminho na teia (não vem de graça no nível 1); o bot da build compra. A curva da AGI e as outras builds não mudam. Check `_check_lanceiro_evasion`.
Zona avisada no chão (assinaturas e perigos de chefe: ilhas, marca, chuva, anel, avalanche, contragolpe) não é esquivada pela AGI: só sair dela salva (decisão 2026-11-13; `BossSignatures._hit` → `_deal_damage(..., dodgeable=false)`).

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
| Paladino | Guardião (espada/maça + escudo, tank) · Cruzado (montante/martelo 2M, dps) · Templário (espada/maça + escudo, dps de fogo sagrado) |
| Berserker | Armas Gêmeas (2 machadinhas) · Executor (machado 2M) · Punhos de Fúria (2 garras, esquiva vira Fúria e contra-ataque) |
| Bispo | Sacerdote (maça + escudo; cura em grupo) · Iluminado (cetro 2M, dano sagrado) · Clérigo de Batalha (maça + escudo, placa; golpes que curam) |
| Druida | Guardião da Floresta (martelo 2M, tank) · Fera Selvagem (2 maças) · Xamã (varinha + orbe, magia) |
| Ranger | Caçador (arco + lince companheiro) · Atirador (mosquete + armadilhas) · Lanceiro (lança: caça de perto, salto, dardos, sangramento) |
| Assassino | Lâminas (2 adagas: veneno, esquiva, furtividade, pelas costas, ataque muito rápido) · Duelista (2 espadas, equilibrado) · Corsário (sabre + pistola: Bravata, tiros, Dados da Sorte, gancho) |
| Elementalista | Foco em Fogo · Gelo · Raio, todos de cajado (os ramos se misturam; conjuntos favorecem um elemento ou uma combinação) |
| Necromancer | Invocador · Ceifador · Sombras, todos de foice (focos que se misturam) |

**Arma exigida** (`SkillDef.requires`, alternativas): tipo da mão principal, `shield`/`orb`, `dual` (2 armas de 1 mão),
`dual_<tipo>` (ex. 2 espadas), `two_handed`. Skill com arma errada fica com ✖ na barra e não sai.
Ataque básico: cadência/alcance/tipo vêm da `ClassDef`; classe de distância com arma corpo a corpo ataca corpo a corpo.

## Armas e mãos
Principal: espada, montante, maça, martelo de guerra, machadinha, machado de guerra, adaga, arco, cajado, varinha, foice.
Secundária: escudo, orbe (mago) ou arma de 1 mão (espada/maça/machadinha/adaga; Shift+clique na bolsa).
Arma de 2 mãos (montante, martelo, machado de guerra, cajado, arco, foice) libera a secundária. Segunda arma soma 60% do ATK.

**Berserker** (machados; garras no Punhos de Fúria): **Machados Gêmeos** (dois machados de 1 mão, couro) = velocidade de ataque (`aspd_pct`, recarga do básico menor) e
roubo de vida (`lifesteal`, % do dano direto volta como vida; dano no tempo não conta), na árvore e no conjunto. Ritmo de feridas
(2026-11-19, GDD §8.2, `WoundSystem`): Talho Duplo abre o sangramento, **Presas Gêmeas** o estende (+2 s, até 8 s) e **Sangria** (era Turbilhão
de Aço, nível 12) cura 5% da vida máxima por atingido que sangrava (até 4; `Balance.WOUND_*`). **Executor** (machado de 2 mãos,
placa) = tanque de apoio: passivos e conjunto com vida e defesa sem perder ATK. **Punhos de Fúria** (duas garras/soqueiras, couro; monge da fúria,
2026-11-09, substituiu o Arremessador) = muita AGI e esquiva (árvore e conjunto): com duas garras, cada golpe direto esquivado dá uma carga de
**Fúria do Punho** (`FistSystem`; +6% ATK e +5% velocidade por carga, até 5, somem em 8 s sem esquivar) e contra-ataca quem está a até 3,2 m
(60% do ATK). Skills: Socos Repetidos, Onda de Choque (ki em linha, atravessa), Chakra (cura 25% da vida, 15% da mana, +DEF), Fenda na Terra (cone),
Postura do Contra-Golpe (+25% esquiva), Bote do Tigre (avanço que atordoa), Punho Final (gasta toda a Fúria: +30% de dano por carga), Cem Punhos
(+2 Fúria se acertar); mistura Dilacerar/Investida de Lâminas dos Gêmeos e os gritos gerais. Arma lendária: Punho Vingativo (contra-ataque mais forte).
Números em `Balance.FIST_*`; save antigo do Arremessador vira as peças do mesmo nível (`SaveSystem.RENAMED_ITEMS`). Tetos: `Balance.LIFESTEAL_CAP` 20%, `ATTACK_SPEED_CAP` 60%.
**Ascensão do Berserker (Ato II, 35; `design/gdd/ato2-horda.md` R6.1/F7/F9b)** — liberada por `ProgressionSystem.has_ascension` (nível
`Balance.ASC_LEVEL` + missão `hx_asc_berserker`), vale nas 3 builds. As skills de ascensão (`SkillDef.ascension`) ficam FORA da teia comum
(vão para a teia de ascensão, com pontos próprios) e na barra só nas vagas extras 7-0 (`Balance.ASC_SLOTS`). **Empunhadura de Titã**
(`TitanSystem`): Executor/Gêmeos põem machado de 2 mãos também na secundária (sem ascensão: "Requer Empunhadura de Titã"; principal de 1 mão
devolve o de 2 mãos à bolsa). A 2ª arma não soma ATK nem atributos: o básico e as skills com `titan_hit` batem com as duas (× 1 + 0,45 × ATK
dela ÷ ATK da principal) e o básico fica 25% mais lento; cada nó "titan_relief" (3, teia de ascensão) devolve 3% (F7: 1,0875 → 1,218). Valem as
skills de duas armas e de 2 mãos. **Garras de Titã** (Punhos ascendido): básico +90% (F5 2026-11-12: com +45% o Punhos dava ×0,98, porque no Modo Gladiador a Fúria vira Glória), empurra, −10% de velocidade. **Modo Gladiador**
(`GladiatorSystem`, liga/desliga): +7% de dano, −5% de defesa (a sonda pediu menos que os 10% do GDD; recalibrado no F5 de 2026-11-11); na postura crítico e abate dão
**Glória** (até 5, esfria em 12 s), a Fúria do Punho vira Glória; Lâminas Ígnea/Gélida/Trovejante (cone/linha, power 1,3 + 0,2 por Glória,
queima / lentidão e estilhaço / raio salta para 2), Investida do Gladiador (7 m, derruba), Brado da Arena (provoca a 8 m, +1 Glória por
provocado até 3), Golpe Final (gasta 5, power 3,5). Sair zera a Glória (Punhos guarda 6 s). Ciclone de Titã: 4 giros em 2 s.
Bots ascendidos aprendem e põem nas vagas extras postura + Lâmina Ígnea + Golpe Final (`AscensionCatalog.BOT_ORDER`); o Executor usa dois
machados de 2 mãos (`Balance.TITAN_BUILDS`). Números em `Balance.TITAN_*`/`GLORY_*`/`GLADIATOR_*`.
Toda arma corpo a corpo de duas mãos (montante, malho, machado; `Balance.BIG_SWING_WEAPONS`) tem golpe básico largo: alcance x1,4,
arco de 150° e até 4 alvos (`Balance.BIG_SWING_*`). Vale para Executor, Cruzado e Inquisidor; arco e cajado não mudam.

**Bispo**: **Sacerdote** (maça + escudo, suporte) = cura mais forte e bênçãos/escudos que duram mais (`buff_pct`, em você e nos aliados);
**Iluminado** (build `inquisidor`; **cetro** de duas mãos, arma mágica nova com ataque básico de luz à distância; túnicas) = dano mágico +
**Radiância** (`radiance`: % do dano mágico direto cura o aliado mais ferido a até 10 m, você incluso). Tetos em `Balance` (80% / 40%).
**Clérigo de Batalha** (build `batalha`; maça + escudo como o Sacerdote, mas de **placa** e na linha de frente; FOR/WILL) = golpes físicos que
curam o aliado mais ferido a até 10 m (efeito de skill `mend_pct_of_dmg`; em você mesmo rende só `Balance.MEND_SELF_MULT`; arma lendária Mão que Cura faz o mesmo em todo golpe), Hino de
Batalha (ATK/DEF no grupo) e as bênçãos do Sacerdote como apoio. Dano ~2x o do Sacerdote e ~55% de um dps puro: o resto vira cura.

**Paladino Templário** (build `templario`, "a build do martelo" desde 2026-11-18; martelo/maça + escudo, placa; FOR/INT) = dano com martelos
de luz que ainda queimam um pouco (fogo sagrado curto): **Martelo da Ira** (nv 2, assinatura: cai do céu no cursor, área, atordoa 0,4 s,
queima 3 s), **Martelo dos Justos** (nv 13, martelada que solta uma onda de luz em leque, queima 3 s) e **Martelos Abençoados** (nv 16, 3
martelos giram em espiral em volta por 6 s, batendo a cada 0,5 s com o poder do lançamento: efeito `orbit`, `AuraSystem.orbit_tick`);
Marca da Penitência (+15% de dano recebido), Ira Vingadora e Golpe Solar, misturados às skills de escudo do Guardião (Pancada, Golpe de Égide,
Retribuição). Toda skill dele exige escudo, então gasta o **Juramento** (cargas ao bloquear com escudo do Paladino, +8% de dano cada; o HUD
explica na dica do ícone). No conjunto lendário o **martelo** é a arma de ataque (Penitência) e a **espada** a de defesa (Baluarte)
(`GearCatalog.WEAPON_ROLES`; save antigo: `..._templario_<nv>_mace` vira `..._sword`, skills/nós antigos viram os novos em
`SaveSystem.SKILL_ID_MIGRATIONS`). O Cruzado trocou o Martelo de Luz pelo **Martelo da Justiça** (nv 9, martelo arremessado que atordoa
1 s e volta: `bounce` de 1 alvo com `stun`). Arma lendária **Penitência**: cada golpe põe uma carga no alvo; na 5ª ele
explode em fogo sagrado (`pct`% do ATK em 2,5 m). DPS ~10% abaixo do Cruzado (troca dano pelo escudo).

**VIT do Paladino** (decisão do usuário 2026-11-18, opção "Forte": o Guardião quase de dano). VIT na escala de hoje (a da janela; "2 VIT"
da proposta = 2 da escala antiga = 20 de hoje). (1) **Espada** (1 ou 2 mãos na mão principal, só Paladino, `Balance.VIT_SWORD_*`):
+1% de dano a cada 20 VIT (espada de 2 mãos: a cada 10, `VIT_SWORD_PER_PCT_2H`, o Cruzado tem pouca VIT), teto +40% (`Stats.vit_sword_pct` → `Stats.vit_dmg_pct`, multiplica o golpe em `Combat.calc_damage`; dano no
tempo não); maça não ganha. Mostra na dica da espada e na janela C ("Dano pela VIT"). (2) **Skill de escudo** (exige escudo, classe com
Juramento): +1% de poder a cada 20 VIT, teto +25% (era 45%: o Guardião passava o Cruzado), somado à DEF do escudo (`ShieldSystem.vit_power`/`def_power`,
`Balance.SHIELD_VIT_*`); dica da skill mostra os dois. Toda skill do Templário exige escudo, então ele também ganha (2). VIT medida
nos bots (teia + equipamento comum / lendário do nível): Guardião 30 ≈ 580 / 1280, 45 ≈ 1000 / 2020; Cruzado 30 ≈ 195 / 135,
45 ≈ 305 / 205; Templário 30 ≈ 330 / 125, 45 ≈ 500 / 205. Check `_check_paladin_vit`.

**Conversão do Druida** (2026-11-24, decisão do usuário: o Druida pode ser tudo, então a forma molda os atributos; sempre ligada, sem nó):
pela arma, que é a exigida pela forma (`Balance.ATTR_CONVERT`, 100% = `ATTR_CONVERT_PCT`), depois de somar equipamento/buffs/conjuntos/teia
(`Stats.convert_attrs`): cajado (humano/Pássaro) FOR→INT e AGI→WILL; duas maças (Lobo/Alfa) INT→FOR e WILL→AGI; malho (Urso/Ent) FOR→VIT e
INT→WILL. Total de pontos igual; a ficha C mostra o que converteu (`Stats.attr_converted`). Check `_check_druid_attr_convert`.

**Druida**: **Xamã** (cajado de duas mãos, túnicas) = magia da natureza, invocações (Lobos Espirituais, Ent Guardião) e Bênção do Bosque;
passivos de MATK e duração de bênçãos. **Lobo** (duas maças, couro) e **Urso** (malho, placa) viram bicho: `Forma de Lobo`/`Forma de Urso`
são skills que ligam/desligam (`SimEntity.form`; bot não desfaz). Transformado: stats da forma (`Balance.FORM_STATS`) e as skills da build
viram o golpe do bicho (`SkillsCatalog.FORM_MODS`, aplicado em `WorldSim.resolve_skill`; mesma recarga). Trocar para arma que a forma não aceita
desfaz a forma. **Espreitar** (só lobo): furtivo por 8 s (monstros não acham nem mantêm o alvo); o golpe que quebra vira emboscada (+60%).
Visual: `form_<wolf|bear>.glb` (`druid_sets.build_forms`) com a armadura de animal de cada conjunto (`FormModel`).

**Ranger**: **Caçador** (arco) com **companheiro** permanente (lince; `ran_companion` invoca
uma vez, fica até cair; vida/ataque/defesa são parte das do dono, `Balance.PET_*`, mais `pet_pct`), Ataque da Fera (o lince salta no
alvo e atordoa) e Instinto da Matilha (buff em você e nele). **Atirador**: **mosquete** de duas mãos (`rifle`: básico 1,8x mais lento e
1,9x mais forte, alcance maior, clipe `atk_rifle`) e **armadilhas no chão** (`trap` em `TrapSystem.place_trap/update_traps`: armam em
0,6 s, disparam quando um inimigo pisa, no máximo 3 por ranger, somem em 30 s; mandíbula prende, mina explode, gelo retarda).
**Lanceiro** (terceira build, substituiu o Patrulheiro de arco): caçador de feras que luta de perto com a **lança** (`spear`, duas mãos).
Básico = estocada em linha de `Balance.SPEAR_REACH` (3,3 m; espada ~1,9, montante ~2,7, arco 13), cone estreito (`SPEAR_ARC_DEG` 40°)
que atravessa até 3 (`SPEAR_MAX_TARGETS`), um pouco mais lenta e forte que o arco; clipe `atk_thrust`. ATK da lança: AGI x1,6 + FOR x1,0
(`PATK_PER_*_SPEAR`; o arco é AGI x2,2). Skills (todas exigem lança): Estocada Dupla (linha, sangra), Dardo de Caça (tira um dardo do cinto,
retarda; assinatura), Salto do Predador (salta no cursor e prende), Lança Giratória (giro que retarda), Armadilha Lançada (mandíbula
arremessada que prende e sangra na hora), Marca do Predador (maldição +18% de dano recebido, sangra), Instinto do Predador (velocidade,
crítico e roubo de vida), Empalar (avanço que atravessa a fila, atordoa e sangra). Divide com o Atirador a Armadilha de Mandíbula e a
Foco Mortal (`ran_mark`, buff; arco, mosquete ou lança; antes chamava "Marca do Caçador", nome que ficou só da lendária do Caçador). **Sangramento** = `dot` com `atk_pct` (% do ATK por segundo, renova). Arma lendária
**Ferida Aberta** (`open_wound`): cada golpe abre uma ferida no alvo (até 5, somem em `LEG_WOUND_TIME`), +2,4..4,8% do seu dano nele por
ferida; com as 5 abertas ele sangra. Árvore: ATK e vida; conjunto de 3 dá vida. Visual (`ranger_sets.LAN_SETS`/`RAN_SPEARS` `ran_l*`):
cabeça de bicho (javali, crânio de lobo, juba de leão, serpe, corvo, crânio chifrudo), gola de pelo, troféu no ombro esquerdo, dardos nas
costas; lanças de presa, folha, louro, ondulada, farpada e de asas. Save antigo do Patrulheiro: a armadura vira a do Lanceiro do mesmo
nível e o arco vira o do Caçador (`GameData.migrate_item_id`); a teia volta com os pontos. Rede voltou ao Caçador e a Armadilha de Gelo ao Atirador.
Bot do Lanceiro: `BotBrain` decide corpo a corpo pela classe (`basic_attack_is_ranged`), então ele se aproxima até ~75% da estocada e recua
se o alvo encosta (a 40% do alcance); funciona (boss_probe 23/40). Melhor seria o cérebro olhar a arma (`stats.is_ranged_weapon`).

**Assassino**: **Lâminas** (duas adagas, `aspd_pct`): Lâmina Pestilenta envenena as lâminas (`hit_poison`: todo golpe físico aplica
um veneno que renova, não acumula, `Balance.HIT_POISON_TIME`), **esquiva** (`evasion`, teto `Balance.EVASION_CAP`; golpe direto
esquivado não causa nada, evento `dodged`), Sumir (`stealth` sem forma: só o Lobo do Druida exige estar transformado) e **pelas costas**
(`backstab`: % de dano e +`BACKSTAB_CRIT` de crítico quando o atacante está atrás do alvo, `Combat.is_behind`). Venenos escalam com ATK.
Ritmo envenenar → **Eviscerar** (2026-11-19, GDD `skills-fill-2026-11-19` §8.1; `WoundSystem`): o golpe consome os venenos SEUS no alvo
(dano no tempo seu que não é queimadura nem o sangramento por % do ATK do Lanceiro), o que faltava explode ×1,25 e o golpe ganha +10%
por veneno (até 5; `Balance.EVISCERATE_POISON`, efeito `combust` com `kind: "poison"`; poder 2,2).
**Golpe Gêmeo × Corte Cruzado** (2026-11-25, eram a mesma skill com nomes diferentes): o Gêmeo (Lâminas) são 2 estocadas rápidas num
alvo (`strikes` 0,45/0,55 do poder 1,7, clipes `atk_dagger` → `atk_thrust`) e a 2ª deixa um veneno (`strikes.last_effects.dot`,
`Balance.TWIN_POISON`; é ferida, o Eviscerar consome); evolução Golpe Certeiro = a 2ª é sempre crítica. O Cruzado (Duelista) é UM X grande
(clipe `atk_claw`, tema sangue) no leque de 110° que sangra (`Balance.CROSS_BLEED`, % do ATK, renova); evolução Cruz Larga = raio e leque ×1,25;
talento Corte em X = +20% e SOMA ao sangramento (`Balance.CT_X_CUT_ADD`, 12%/s por 6 s). Dano por lançamento igual ao de antes (`_check_twin_cross`).
**Duelista** (duas espadas, `atk_pct`): **aparar e contra-atacar** (2026-11-19, GDD §8.3, `RiposteSystem`): a Guarda do Duelista abre uma janela de
1 s (recarga 8 s; buff `duel_guard`): golpe direto de perto (4 m) e de frente sai 0 (chefe: −60%), responde com 80% do ATK (+ a Riposte
lendária; até 2 por janela) e dá 1 **Ímpeto** (buff `impeto`, +5 de crítico por carga, até 3, 10 s). Dano no tempo, zona avisada e golpe pelas
costas não são aparados; a cópia permanente do talento não apara. O Golpe de Mestre gasta o Ímpeto (+20% por carga). Bots abrem a Guarda com
golpe vindo neles ou cercados (`BOT_RIPOSTE_*`). Números em `Balance.RIPOSTE_*`. Resto: golpes largos, Avanço, Turbilhão, Foco; árvore com
ATK/DEF/crítico e conjunto com DEF + crítico; Expor Fraqueza (alvo recebe +20% de todos, maldição `expose`) é dele.
**Corsário** (sabre = `sword` na direita + **pistola** na esquerda, `atk_pct`, AGI/FOR): a pistola (`pistol`) é arma só de mão
secundária (`ItemDef.OFFHAND_ONLY`, como escudo e orbe; ficha de exigência `"pistol"`), soma o ATK inteiro e não atira no básico — os
tiros saem das skills (`"shot"` = clarão na boca do cano + rastro no FX, clipe `atk_pistol`). **Bravata** (`Balance.BRAVADO_*`, buff
`bravado` com cargas, até 5): Tiro de Pistola +1, Corte e Tiro +2, Gancho/Bala Ricochete +1, Bordada +2, Bandeira Negra +3 (`combo_gain`);
o **Tiro Entre os Olhos** gasta tudo (`combo_spend`: +25% de dano e +0,3 s de atordoamento por carga). **Dados da Sorte** (`dice`):
sorteia com o rng da sim UM buff de 12 s (ATK, crítico, velocidade ou recarga; o HUD mostra qual). **Gancho de Abordagem**
(`dash_to_aim`): puxa até o ponto mirado. **Bala Ricochete**: `bounce` com `back: false` (bala some no último salto) e `taunt: 0`.
Mistura Estocada, Guarda e Expor do Duelista (aceitam `pistol`). Arma lendária **Bala na Agulha** (`spare_shot`): golpe às vezes
dispara a pistola de graça (% do ATK, +1 Bravata, `Balance.LEG_SHOT_ICD`). Visual (`assassin_sets.CORSAIR_SETS`/`CORSAIR_PISTOLS`):
tricórnio de abas viradas, bicorne atravessado ou bandana, casaca longa aberta com abas, faixa, boldrié, tapa-olho, dragonas, papagaio.
O Trapaceiro saiu: Abrolhos virou geral, Toxina Paralisante voltou às Lâminas; save antigo troca as peças `leg_assassin_trapaceiro_*`
pelas do Corsário (`SaveSystem.RENAMED_ITEMS`) e a teia é refeita com os pontos devolvidos. Envenenador e Sombra saíram antes.

**Elementalista**: só **cajado**; Fogo, Gelo e Raio são focos (ramos da árvore), não caminhos fechados: dá para pegar skills dos três.
Cada skill tem `SkillDef.elements` (o ramo dá; gerais e combinações em `SkillsCatalog.ELEMENTS`) e o dano multiplica pela média de
`fire_pct`/`frost_pct`/`storm_pct` desses elementos (`Stats.element_mult`, teto `Balance.ELEMENT_CAP`). Combinações gerais: Tempestade
de Brasas (fogo+raio), Choque Térmico (fogo+gelo), Granizo Trovejante (gelo+raio), Prisma Elemental (os três). Elementais de fogo/gelo/raio
(um por ramo): **um vivo por vez**, invocar outro substitui (`summon.replaces`). Conjuntos: 3 peças dão o elemento do foco; os de
combinação (`SET_VISUALS.favor`) dão o 2º elemento com 4 peças. Save com varinha/orbe: vão para a bolsa e o cajado inicial entra.
**Ascensão (35, missão `hx_asc_elementalist`; `ElementalSystem`, GDD `ato2-horda` R6.1/F6)**: o elemental vira companheiro persistente
(um só), ganha `elem_xp` = max(1, XP do abate ÷ `Balance.mob_xp(nível)`) em abates que dão XP a até `ELEM_XP_RADIUS` do mago (com ele
vivo; teto 400) e sobe Básico → Maior (120, nível 35) → Ancestral (400, nível 40) — nomes por forma: Salamandra/Ifrit, Golem de
Gelo/Ondina, Silfo/Tempestade; HP/ATK/área × `ELEM_STAGE_MULT` (ATK depois do `SUMMON_ATK_MAX`), skill nova por estágio, corpo maior.
Trocar de forma (skill da outra forma, quadro do HUD ou `InputCommand.elem_form`) mantém estágio e % de vida, recarga `ELEM_SWAP_CD`.
Morrer tira `ELEM_DEATH_LOSS` da experiência (estágio nunca cai) e a volta espera a mesma recarga; o Ifrit explode. Modos (Comando
Elemental, HUD, `elem_mode`): atacar (segue `last_target_id` do mago), proteger (provoca quem bate no mago, +DEF), apoiar (fogo ATK,
gelo escudo, raio velocidade no grupo). Fusão Elemental (40 s): golpe com o efeito da forma + buff `elem_fusion` (`ELEM_FUSION_*_PCT` 8% de MATK e do elemento × estágio; peso por forma em `ELEM_FUSION_FORM`: fogo 0,85, gelo 1,0, raio 0,4, vale no golpe e no buff). Refino do 40 por elemento (Salamandra / Golem de Gelo / Silfo, portões `elem_refine_<forma>`): o elemental naquela forma com +15% de ataque e vida. Bots: forma do
elemento da build, proteger se o chefe está neles, Fusão numa vaga extra (7+). Skills de ascensão têm `SkillDef.ascension`: ficam
fora da teia normal (teia de ascensão e barra 7-0: ver "Teia e barra de ascensão"; o estágio Ancestral pede o nó Chamado Ancestral, 40). Save v5: campo `elemental` (antigo: 0 de experiência, forma da barra).
**Dano no tempo** (2026-11-17, "impossível tancar"): todo dano no tempo (veneno, queimadura, sangramento, maldição) bate em **pulsos** de
`Balance.DOT_PULSE_S` (0,5 s; o 1º meio segundo depois de aplicar, o resto sai quando acaba: mesmo total de antes, sem um número por tick).
O de **monstro/chefe** (ou invocação de monstro) com o mesmo id e o mesmo tipo (fogo ou não) **renova** em vez de acumular: duração nova, maior
dps, o relógio do pulso continua (`WorldSim._renew_dot`), e **dura x0,7** (`Balance.MONSTER_DOT_TIME_MULT`, mesmo dps: total x0,7; sem
compensação, chefes com veneno/fogo ficam um pouco mais fáceis). O mágico do **jogador** leva o id da skill (`dot_<src>_<skill>`, marcado em
`_apply_skill`; `WorldSim.dot_id`) e acumula até `Balance.PLAYER_DOT_MAX_STACKS` (3) cópias por (quem lançou, skill): a 4ª tira a mais antiga
(`WorldSim._put_dot`, acumulado e pulso passam para a nova); skills diferentes têm teto próprio. Sangramento, veneno na lâmina e os das armas
lendárias continuam renovando por id. Medido (boneco, nível 30/40): o teto quase nunca prende (os acúmulos vêm de skills diferentes), nenhuma
build perdeu mais de 7% do dano no tempo, então os dps das skills não mudaram. `put_debuff` de dano no tempo guarda o acumulado e o relógio do
pulso. Checks `_check_dot_pulse`, `_check_dot_cap`; medir com `boss_probe -- --dot_stats`.
**Efeitos por elemento** (valem para qualquer classe, pelo elemento ou pelo tema visual da skill): **fogo queima** — todo dano no tempo
de skill de fogo é queimadura (número laranja, brasas no alvo); **gelo estilhaça** — skill de gelo em alvo retardado, preso ou atordoado
causa ×`Balance.FROST_SHATTER_MULT` (1,3; número azul com ❄), então vale abrir com Nova de Gelo/Lança e emendar; a **lentidão de gelo**
também tira `Balance.FROST_ASPD_SLOW` (25%) da velocidade de ataque (`Combat.frost_attack_mult`; não soma entre lentidões de gelo; a de
outras skills só retarda o movimento; 2026-11-19); a **Armadura de Gelo** não dá DEF: corta o dano recebido em 15% + 1% a cada 10 INT, até 40% (`Stats.frost_armor_dr`, `Balance.FROST_ARMOR_DR_*`; 2026-11-19); **raio atordoa** —
Trovão, Estilhaçar, Zero Absoluto e as combinações com raio sempre; as outras skills de raio com dano têm `Balance.STORM_STUN_CHANCE`
(15%) de atordoar `STORM_STUN_TIME` (0,5 s) no golpe direto (`Combat.storm_can_stun`; chefes: 40% da duração). Na tela: atordoado = estrelas girando, retardado/preso =
anel de gelo nos pés e tom azul, queimando = brasas e tom laranja (`EntityView._update_status`, parâmetro `status` do `toon.gdshader`).
**Controle em chefe** (`MonsterDef.resists_cc`, decisão 2026-11-17): só chefe de verdade resiste — atordoar dura 40%, provocar 50%,
gancho/empurrão não o move. O Rei que surge depois de muitos abates (elite, `elite_of`) continua `is_boss` para loot/barra/IA, mas leva
o controle cheio. **Retorno decrescente nos monstros** (C7, decisão 2026-11-23, `CcDrSystem`): por categoria (lentidão, raiz,
atordoar), a 2ª aplicação dentro de `CC_DR_WINDOW` 8 s da anterior dura 50%, a 3ª 25% (`CC_DR_MULTS`), depois imune 8 s àquela
categoria (tentar não estende). Os 40% do chefe multiplicam por cima. Jogador e bots não têm. Só conta o controle de skill
(`WorldSim._apply_effects`); lentidão de gelo (`slow.frost`) e de pulso de canal ficam cheias (decisão 2026-11-23, `CcDrSystem.slow_exempt`); chão que renova a cada pulso (zonas, miasma, tempestade) e a lentidão de golpe de equipamento ficam de fora.
Check `_check_cc_dr`. Talento de classe pode **somar** ao efeito da skill (`skill_mods.add`, depois de maestria e evolução: Golpe Restaurador
+12% de cura por dano, Golpe Ardente +5 s de queimadura, Castigo +0,4 s no Martelo de Luz) em vez de trocar o número (`effects`).

**Necromancer**: só **foice**; Invocador, Ceifador e Sombras são focos que se misturam. Invocações com limite **por tipo**
(esqueletos, 2 cães de ossos, 1 lich de gelo, 1 Rei Esqueleto); o ataque delas sai do MATK do dono × força do monstro × `pet_pct`.
**Maldições** (efeito `curse`: `taken_pct` = recebe mais dano, `weaken_pct` = causa menos, teto `CURSE_WEAKEN_CAP`; a mesma maldição renova).
**Canalização** (efeito `channel: {ticks}`, fase ativa = duração): o efeito pulsa N vezes mirando o cursor; outra skill ou o dash cortam (bots seguram até o fim).
**Formas** do Ceifador: Fantasma (10 s, `Balance.FORM_DURATION`; `shaders/ghost.gdshader`: casca espectral com a cor das peças, rápido, esquiva) e Demônio (`form_demon.glb`, maior, HP/DEF/roubo de vida); golpes de foice mudam
(`FORM_MODS`). Save com cajado/varinha/orbe: voltam para a bolsa e a foice inicial entra.

**Preenchimento de skills (2026-11-19, `design/gdd/skills-fill-2026-11-19.md`)**: toda build tem ≥ 8 skills próprias e toda classe ≥ 4
gerais, sem contar ascensão (check `_check_skill_fill`). 13 skills novas, nos buracos da escada (níveis das antigas não mudaram):
Templário **Chão Sagrado** (10, zona 6 s que queima e dá +10% DEF a quem está dentro) e **Coluna da Alvorada** (22, coluna no cursor que
atordoa, queima e salta para 2); Executor **Fender Armadura** (8, cone que racha) e **Brado do Carrasco** (22, +20% DEF/+10% ATK e escudo de
12% no grupo a 8 m); Clérigo de Batalha **Estandarte da Fé** (17, zona 8 s que fere, retarda e cura o grupo dentro) e **Corrente da Fé** (23,
golpe que cura o mais ferido e salta para 2); Sacerdote **Luz Protetora** (3, cura + escudo de 10% no aliado); Urso **Lacerar** (15, sangra e
provoca; na forma de urso pega 3); Fogo **Semente Ígnea** (17); Raio **Passo Relampejante** (13, teleporte de 7 m que cai como raio);
Invocador **Oferenda Sombria** (21); Necromante (geral) **Garra da Cova** (16, puxa e prende; chefe não vem); Ranger (geral) **Curativo de
Campo** (11, cura 20% e +20% de velocidade; o lince ganha o buff se estiver, `pet_buff: "if_any"`). Mecânicas novas (números em `Balance`):
- **`zone`** (`TrapSystem.place_zone`, lista `m["traps"]` kind `zone`): o golpe bate normal e o chão fica `duration` s; a cada `pulse` s
  inimigos dentro levam `foe_power` × ATK/MATK (sem crítico; a AGI esquiva) e o `dot` renova, `foe_slow` retarda; aliados dentro (você
  incluso) ganham `ally_heal` × cura e o `ally_buff` por pulso + `ZONE_BUFF_LINGER`. Uma por (lançador, skill); some com o dono morto/fora.
- **`sunder`/`sunder_consume`** (`SunderSystem`): debuff `sunder` com cargas (+4% de dano recebido por carga, até 5, 8 s; é MARCA, teto
  `MARK_TAKEN_CAP`; chefe acumula). Golpe Avassalador, Executar e Decapitar gastam: power × (1 + 0,10 × cargas) e zeram. Executar e
  Decapitar perderam 10% de power (3,4 → 3,1; 4,4 → 4,0), como o GDD previa. Bot: com o Fender pronto, finalizador espera 3 cargas.
- **`seed`** (`SeedSystem`): semente `seed_<lançador>` no alvo; no fim (4 s) ou na morte dele explode em 3 m (140% do MATK, até 6, o alvo
  incluso se vivo) e espalha a queimadura da skill pelo teto de 3 cópias; não planta outra; relançar renova; dono morto/fora: some.
- **`sacrifice`** (`SummonRites`): até 4 invocações suas a 6 m do ponto (fora `Balance.SACRIFICE_EXCLUDE`) explodem em 3 m com power ×
  (0,5 + 0,5 × % de vida) e somem sem XP/saque; sem nenhuma a skill é recusada sem gastar MP. Bot: só com 3 perto do alvo.
**Urso**: a magia-assinatura passou de Fogo Lunar (cajado do Xamã) para **Esmagar** (`dru_maul`, o cone do malho que abre a build no nível 2),
peso `SIGNATURE_BUILD_POWER` 0,85. Correção junto: buff/cura % de SELF não sai mais duas vezes (Chakra curava 50%, não 25%).

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
**Montaria (H)**: conjuração de `Balance.MOUNT_CAST_TIME` (1,5 s; vale em combate e andando; barra de conjuração e leque no botão H); agir, pular, bloquear, começar a volta (G), ser atordoado ou levar golpe interrompe; H de novo cancela. Fora de forma animal; `Balance.MOUNT_SPEED_MULT` 1,7. Bots só montam fora de combate. Não monta em masmorra nem em interior (`MapDef.parent_map`), exceto masmorra com `MapDef.mounts_ok` (só a Cidadela de Kharzun: pátios abertos; `MapDef.no_mount()`).

**Ascensão do Paladino (Ato II, 35; `ProgressionSystem.has_ascension` = nível `Balance.ASC_LEVEL` + missão `hx_asc_paladin`)** — `MountedCombat` (core/sim/systems/mounted_combat.gd):
- As skills da ascensão (Carga Montada, Pisotear, Modo Arcano; `SkillDef.ascension`) ficam **fora da teia comum**: são compradas na teia de ascensão (com maestria) e vão na barra só nas vagas 7-0 (ver "Teia e barra de ascensão").
- **Combate Montado**: montado, o básico (+`MOUNT_REACH_BONUS` 0,8 m) e as skills `mountable` (escudo/aura/bênçãos/cura: `SkillsCatalog.MOUNTABLE`) saem a cavalo; as outras ficam apagadas na barra e são recusadas; Carga Montada e Pisotear são `mount_only`. Velocidade montado em combate `MOUNT_FIGHT_SPEED_MULT` 1,3 (fora 1,7). Golpe comum e lentidão não derrubam; atordoar, prender (rede) e gancho derrubam e dão `MOUNT_CC_IMMUNE` 2 s imune a controle (buff `unhorsed`). Dash e bloqueio descem. Visual: o boneco golpeia da sela (`RideLegs` prende as pernas, o clipe mexe braços/tronco).
- **Modo Arcano** (liga/desliga, efeito `arcane`): asas de luz (`ARCANE_WINGS` +24% ATK/MATK, +15% DEF/MDEF; família `wings` da `BuffAura`), gasta `ARCANE_MP_PER_S` (3 MP/s, além das skills) e a regeneração de MP cai para `ARCANE_REGEN_MULT` (metade); desliga com MP 0, ao lançar de novo ou ao montar (recarga `ARCANE_CD` 20 s); ligar desmonta e solta a rajada de penas (`ARCANE_BURST`: 4 m, 0,8, empurra 2 m; chefe não é empurrado).
- Bots (`BotBrain._ascension`): Modo Arcano em chefe (Guardião quando segura o aggro, os outros colados), desligam abaixo de `BOT_ARCANE_OFF_MP`; com a Carga na barra, em campo aberto montam para abrir a luta (antes do primeiro golpe, alvo a 6–14 m sem mirá-los) e descem com ela em recarga. Barra do bot ascendido: vagas 7-0 na ordem de `AscensionCatalog.BOT_ORDER`.
- Medir: `combat_probe -- --class=paladin --asc`; `boss_probe -- --comp=... --asc_level [--asc]` (linha `ASC` = usos por luta); evidência `-- --autostart=paladin --ride_shot=<pasta>`.
Atacar, usar skill, dash ou bloquear desmonta e a ação acontece; levar golpe derruba (`WorldSim.dismount`, evento `mount_changed`).
Bots montam às vezes andando fora de combate. Visual: `mob_horse.glb` (`mob_kit.horse`, pelagem "tint" com cor por entidade) e o boneco
no clipe "ride" gerado do idle (`RidePose.ensure_clip`, pernas/braços fixos). Revisar: `lineup.tscn -- --mounted [--front] [--nohorse]`.
**Drops no chão**: baú de tesouro chibi (`game/fx/loot_chest.gd`: madeira, aros dourados, gema na cor do item, brilho pela raridade,
facho de luz em épico/lendário) e moedas para ouro; malhas compartilhadas. Revisar: `-- --autostart=<classe> --loot_demo --screenshot=<png>`.
Save com nó de árvore que não existe mais (build removida): a árvore volta ao início e os pontos voltam (`SaveSystem.points_for_level`).

## Teia e barra de ascensão (Ato II, GDD `ato2-horda` R6)
Uma só regra para todas as classes: `ProgressionSystem.has_ascension` (nível `Balance.ASC_LEVEL` 35 + missão `hx_asc_<classe>`).
- **Skills**: `SkillDef.ascension = true`, `unlock_level` de `ASC_LEVEL` a `ASC_MAX_LEVEL` (45). Ficam fora da teia comum.
- **Teia** (`data/catalog/ascension_catalog.gd` → `GameData.asc_trees[<classe>]`, mesma forma da teia comum: `start`, `nodes`, `panes`,
  `clusters`): um ramo por build com conteúdo (+ Geral), em espinhas a partir do início; cada skill ganha entrada de atributo
  (`<classe>_a_in_<skill>`, `ASC_WEB_ENTRY_ATTR`), nó de skill (`_a_s_`) e maestria 0-5 (`_a_m_`); passivos e portões da classe em
  `AscensionCatalog.NODES` (`_a_x_<id>`; `stats` ou `flag`, lido por `ProgressionSystem.asc_flag`). Classe sem skill nem nó = sem teia.
- **Pontos próprios**, calculados (não salvos): `ASC_POINTS_PER_LEVEL` por nível do 35 ao 45 + `ASC_QUEST_POINTS` da missão
  (`ProgressionSystem.asc_points*`). Comprar/checar passa pelos mesmos `Sim.tree_allocate`/`tree_block_reason`; o reset de skills (Ancião)
  zera as duas teias, e `asc_reset` só a de ascensão.
- **Barra**: 6 vagas + `ASC_SLOTS` (4) com a ascensão (`SimEntity.slot_count`); teclas 7, 8, 9, 0 (`skill_7..skill_10`). Vagas 1-6 só
  aceitam skill comum, 7-0 só skill de ascensão (`set_skill_slot`, `try_cast`). Skill comprada cai na 1ª vaga livre de 7-0.
- **Save v5**: `asc_tree` (ids dos nós) e loadout de 10; save antigo ou nó que sumiu = teia de ascensão no início (pontos voltam).
- **Bots**: `ProgressionSystem.bot_spend_asc` (skills na ordem de `AscensionCatalog.BOT_ORDER`, chave `<classe>` ou `<classe>/<build>`,
  maestria, portões/passivos) e `WorldSim._slot_bot` (7-0 nessa ordem, menos `BOT_NO_SLOT`); nunca tiram skill da build.
- **UI**: aba "Ascensão" da janela K (mesma vista da teia, pontos de ascensão); a barra do HUD mostra 10 botões quando ascendido.
- **Revisar**: `-- --autostart=<classe> --ascend [--level=N] [--build_i=N]` (jogador ascendido, teias gastas como bot);
  `--bag_shot=<png> --wins=skills --ascend --asc_tab` (aba Ascensão); `--asc_shot=<png>` (Ranger: torreta e salto); `--choir_shot=<png>` (Bispo: cúpula, anjo e bênçãos);
  `combat_probe -- --class=<c> --asc`; `boss_probe -- --asc[=classe] | --asc_base=classe | --asc_level | --lvl=N` (F5: com/sem a ascensão no mesmo nível).
- **Como medir o F5** (rodada de 2026-11-11): grupo `tanque + cura + 2× a build`, nível 35, `--tank_lock` e 80+ lutas por braço (`--seed=N` soma rodadas independentes; a linha `TIME` dá média, mediana, erro-padrão e `freio`). **Sem `--tank_lock` a medida mente**: o bot que passa de `BOT_THREAT_HOLD` × a ameaça do tanque só usa o básico, e no grupo de 4 a dupla de dano fica 34-39% do tempo nesse freio — +20% de ATK aparecia como ×1,00 (Paladino) e a Fusão do fogo como ×1,01. Lutas de 20-30 s medem a abertura: use `--hp=2.5` nas builds que derrubam o chefe rápido (Elementalista). Mortes sob `--dmg` têm ruído de ±13-15% em 80 lutas: não resolvem 6-10% (300+ lutas por braço, no `--dmg` em que a base morre 1-2 por luta: ×1,5 com Urso tanque, ×3 com Guardião). `--why` imprime `BUFFS` (tempo de cada buff por membro), `INV` (invocações mortas) e `DPS ...+inv` (dano das invocações). Com `--comp` passe também `--party=4`: sem ele a sonda roda os tamanhos padrão 1 e 3 (só os primeiros membros da composição). Rodada de 2026-11-12 (depois do retrabalho da ameaça e dos portões da teia de ascensão comprados antes das maestrias): Lâminas ×1,084 (`ASC_BUILD_POWER` 0,9), Duelista ×1,082 (0,92), Corsário ×1,076, Punhos ×1,091 (`TITAN_CLAW_POWER` 0,9); Necromante só no tempo ×1,01-1,02; utilidade sob pressão (80 lutas por braço): Bispo `--dmg=3` −18% de mortes, Ent `--dmg=1.5` −38%, Necromante Invocador `--dmg=3` −31%.

- **F5 aos 35 com fator por nível** (decisão do usuário, 2026-11-13): os pesos do 45 (`ASC_BUILD_POWER`, `TITAN_CLAW_POWER` das Garras) passaram
  aos 35 de x1,32 (Lanceiro), x1,17 (Atirador), x1,12 (Caçador) e ficaram abaixo nos Assassinos/Punhos (x1,01-1,05). Agora todo peso de ascensão
  passa por `Balance.asc_power(build, nível)` (`asc_level_mult`): vale × `ASC_POWER_35_MULT[build]` no 35 e vai em linha reta até 1,0 no 45
  (no 45 e acima é exatamente 1,0: a calibragem do 45 não muda). Caminhos: torreta/salto/Brados (`RangerAscension`), falcão (`FalconSystem`),
  clone e Execução (`ShadowSystem`), matilha e penas (`DruidAscension`), Garras de Titã (`TitanSystem`). Check `_check_asc_power_35`.
  Medido (Agitador-Mor, nível 35, `--tank_lock`, 80 lutas por braço; razão base/asc): Lanceiro 0,1 → x1,078; Atirador 0,3 → x1,089;
  Caçador 0,6 → x1,097; Corsário 2,3 → x1,068; Duelista 1,4 → x1,077; Lâminas 1,2 → x1,099; Punhos 1,6 → x1,087; Xamã sem fator x1,069 (fatores da rodada do 35, antes do reajuste do 45 abaixo; o produto peso × fator no 35 ficou igual).
  **F5 no 45 na sala real do Kragmar** (2026-11-13; antes era a arena provisória do Ghar; cidadela com montaria, ward e golens, assinatura ligada;
  80 lutas por braço, razão base/asc ± erro): todo o quadro subiu ~0,1 (média 1,29 contra 1,194). Sem a assinatura (`--no_sig`) Cruzado 1,365
  (com 1,499) e Lanceiro 1,251 (com 1,249): a sala pesa mais que a assinatura. Reajustados pelo peso do 45 (`ASC_BUILD_POWER`), com o fator do 35
  compensado para o produto do 35 ficar igual (o 35 acima não muda): Lanceiro 3,3→2,35 x1,172; Atirador 6,5→4,0 x1,197 (2 sementes);
  Caçador 0,7→0,82 x1,175; Corsário 0,45→0,33 x1,201; Duelista 0,73→0,46 x1,222; Lâminas 0,9→0,51 x1,213; Fera 1,0→0,74 x1,218;
  Punhos (Garras 0,8) x1,202, Executor x1,222 sem mudança. Média desses 9: 1,203.
  **Pendente: medido na arena real do Kragmar, precisa de split por nível; ajustar depois** (usuário 2026-11-13: "commit agora, ajusta depois") —
  Cruzado x1,499, Templário x1,336, Fogo x1,399, Gelo x1,305, Raio x1,272, Xamã x1,260, Gêmeos (Carniceiro) x1,252. O ganho deles vem da
  mecânica do 35 (Combate Montado, elemental, Pássaro Arcano/`ANC_BOLT_POWER`, Empunhadura de Titã), que também vale no 35; os nós do 45 (+5,5% etc.)
  não bastam.
- **F5 no 45 com alvo ~1,30** (decisão do usuário, 2026-11-14: quem estava abaixo de 1,30 SOBE até ~1,30; nada é cortado: Fogo,
  Raio e Cruzado ficam acima). Medida: Kragmar na sala real, `--lvl=45 --tank_lock`, grupo `druid:guardiao_verde + bishop:sacerdote + 2× build`
  (tanque neutro, sem a ascensão do Guardião; Fera/Xamã com `paladin:guardiao`, senão `--asc=druid` ascende o tanque), Elementalista com
  `--elem_stage=2 --hp=2.5` (o mago 45 tem o Ancestral); 80 lutas por braço em 2 sementes (1337 + `--seed=7`), razão = média base / média asc,
  erro ~±0,03-0,05. O 35 não muda: os pesos do Ranger/Assassino/Fera/Garras mantêm o produto peso × `ASC_POWER_35_MULT`, e os outros botões são nós do 40/45.

  | build | botão (Balance) | antes | agora | F5@45 |
  |---|---|---|---|---|
  | Lanceiro | `ASC_BUILD_POWER` | 2,35 | 3,5 | 1,37 |
  | Atirador | `ASC_BUILD_POWER` | 4,0 | 11,5 | 1,33 |
  | Caçador | `ASC_BUILD_POWER` | 0,82 | 3,0 | 1,32 |
  | Lâminas | `ASC_BUILD_POWER` | 0,51 | 1,03 | 1,33 |
  | Duelista | `ASC_BUILD_POWER` | 0,46 | 1,0 | 1,30 |
  | Corsário | `ASC_BUILD_POWER` | 0,33 | 0,85 | 1,33 |
  | Fera | `ASC_BUILD_POWER` (só a matilha) | 0,74 | 1,6 | 1,32 |
  | Punhos | `TITAN_CLAW_POWER` | 0,8 | 1,35 | 1,36 |
  | Carniceiro (Gêmeos) | `TWIN_FURY_ATK` (nó 45) | 15 | 28 | 1,30 |
  | Executor | `ARENA_FINALE_ATK` (nó 45, novo `atk_pct`) | — | 16 | 1,31 |
  | Templário | `ASC_TEM_DAWN_ATK` (nó 45, novo `atk_pct`; MATK 3 fica) | — | 26 | 1,32 |
  | Gelo | `ASC_FROST_LORD_MATK` (nó 45, novo `matk_pct`; +% de gelo 9 fica) | — | 15 | 1,30 |
  | Xamã | `ANC_BIRD_ELDER_POWER` (2º refino do Pássaro, 45) | 0,06 | 0,21 | 1,31 |
  | Cruzado / Fogo / Raio | sem mudança | | | 1,30 / 1,72 / 1,46 |

  Achados: o MATK do nó Aurora do Templo não move o Templário (3 → 12 deu a mesma luta) e o +% de gelo não move o Gelo (já no `ELEMENT_CAP`),
  por isso os botões novos em ATK/MATK. Os nós de 5 pontos do 45 (Aurora do Templo, Senhora do Inverno) não eram comprados pelo bot (sobrava
  ~5 pontos na teia de ascensão): ganharam portão (`TEM_DAWN_FLAG`, `FROST_LORD_FLAG`, como a Fúria Gêmea; check `_check_asc_web_fill`).
  O Xamã ganhou peso próprio por refino (`ANC_REFINE_POWER_NODE`, `DruidAscension.refine_power`): só o refino do 45 sobe, o 35/40 ficam 0,06.
  O peso da Fera só multiplica a matilha (0,94-1,15 davam ~1,24 sem diferença). Bases medidas (s): Lanceiro 44,5, Atirador 39,9, Caçador 46,7,
  Lâminas 54,4, Duelista 54,7, Corsário 53,1, Fera 47,6, Punhos 48,5, Carniceiro 57,0, Executor 69,2, Templário 46,4, Gelo 88,4, Xamã 39,4.

## Ascensão do Ranger (Ato II, 35) — `RangerAscension` (core/sim/systems/ranger_ascension.gd)
Liberada por `ProgressionSystem.has_ascension` (nível `Balance.ASC_LEVEL` + missão `hx_asc_ranger`); as skills de ascensão
(`SkillDef.ascension`, nível `ASC_LEVEL`) ficam fora da teia comum: são compradas na teia de ascensão do Ranger (ramos Atirador e Lanceiro,
com maestria) e vão na barra só nas vagas 7/8/9/0. O Caçador é o Falcoeiro (seção seguinte).
Bots: `AscensionCatalog.BOT_ORDER` (Atirador: torreta; Lanceiro: salto, Chamas e depois os outros Brados; Caçador: falcão, Mergulho, Olhos do Céu). Peso F5 por build: `Balance.ASC_BUILD_POWER` (Atirador 3,5: a torreta com 0,55 do ATK a cada 1,4 s rendia 4% e as 3 montagens custavam 5% ao atirador — ×0,98 em grupo). Refinos da torreta como portões da teia: **Torreta Firme** (40, `ran_turret_firm`) e **Torreta Veterana** (45, `ran_turret_vet`), cada um +`TURRET_REFINE_TIME` 4 s e −`TURRET_REFINE_CD_PCT` 20% de recarga.
- **Torreta de Campo** (Atirador, GROUND): invocação parada no ponto mirado (chão andável mais perto) que atira sozinha no inimigo
  mais perto a `TURRET_RANGE` m por `TURRET_TIME` s; vida/ATK/DEF = do dono × `TURRET_*_SHARE`; monstros podem atacá-la; não teletransporta
  nem segue o dono para outro mapa (some). Exatamente `TURRET_MAX` = 1 (a mais antiga some); stat `turret_max` soma (Ápice do Atirador);
  `RangerAscension.near_turret` lê a área `TURRET_AREA` em volta (conjuntos futuros). Refino 40/45 (só dado): `TURRET_REFINE_TIME`/`_CD_PCT`.
  Bot: abre a luta com ela, do lado de cá do tanque (`BOT_TURRET_GAP`).
- **Salto Dracônico** (Lanceiro, GROUND 9 m): decola no fim do preparo e fica `DRAGON_JUMP_AIR` s fora do chão (sem golpe, projétil, chuva
  nem mira — `sky_left`; quem o mirava volta ao maior de ameaça, e sem outro na ameaça fica nele sem largar a luta), cai no ponto mirado (ajustado para chão andável): `DRAGON_JUMP_POWER` no centro
  (`DRAGON_JUMP_INNER` m), `DRAGON_JUMP_EDGE` na borda (3 m); com Brado ativo a queda leva o elemento. Dash + salto sem parar: ≤ `UNTOUCHABLE_MAX`
  do tempo (combat_probe). Bot: fecha distância a `BOT_JUMP_MIN`-9 m e esquiva golpe avisado caindo colado no alvo (`jump_spot`).
- **Brados Elementais** (Lanceiro, SELF, `SHOUT_TIME` s, recarga `SHOUT_CD`, um por vez; provocam `SHOUT_TAUNT_TIME` s a `SHOUT_TAUNT_RADIUS` m):
  o grito não provoca chefe. Chamas (a lança queima `SHOUT_BURN_PCT`% do ATK/s; grupo a 10 m +`SHOUT_BUFF`% de fogo), Geada (a lança deixa lento; inimigos a 6 m atacam `SHOUT_BUFF`% mais devagar),
  Trovão (o golpe salta para 1 vizinho com `SHOUT_ARC_PCT`%; grupo +`SHOUT_BUFF`% de velocidade). Bot compra Chamas primeiro e nunca grita com outro Brado ativo.

## Ascensão do Necromante (Ato II, 35) — Senhor dos Mortos, `NecroAscension` (core/sim/systems/necro_ascension.gd)
Liberada por `ProgressionSystem.has_ascension` (nível 35 + missão `hx_asc_necromancer`). Vale para as 3 builds (skills sem build, de foice);
números em `Balance.LORD_*` (GDD `ato2-horda` R6.1, AC-30b). Check `_check_lord_of_dead` / `_check_lord_of_dead_bots`.
- **De graça com a ascensão**: invocações temporárias duram × `LORD_SUMMON_TIME_MULT` (1,5) e cabe +`LORD_SUMMON_EXTRA` (1) por tipo
  (soma com talentos; as permanentes só ganham a vaga).
- **Pacto dos Mortos** (o "Pacto Sombrio" do GDD; o nome mudou porque o Invocador já tem a skill Pacto Sombrio — SELF, 12 s, recarga 20 s,
  efeito `summon_pact`): as invocações que estão a `LORD_PACT_RADIUS` (15 m) ao lançar ganham +25% de dano (no golpe, `_deal_damage`),
  +20% de velocidade de movimento e 10% do dano delas cura o necromante; quem chega depois não recebe. Buffs `lord_pact` (mago) e `lord_pact_minion`.
- **Miasma** (GROUND 9 m, raio 4 m, 8 s, recarga 16 s, efeito `miasma`): nuvem em `m["lord_zones"]` (uma por necromante) que pulsa a cada
  `LORD_MIASMA_PULSE` s: inimigo dentro causa 20% menos dano (maldição `weaken_pct`, soma com as outras até `CURSE_WEAKEN_CAP`) e anda 15% mais
  devagar; fora da nuvem o efeito some em `LORD_MIASMA_KEEP` s. O desenho usa o canal das armadilhas (`trap_placed` com `kind` "miasma").
- **Marca da Cova** (GROUND 9 m, raio 3,5 m, recarga 24 s, efeito `grave_mark`): marca os inimigos da área por 10 s; monstro comum (não chefe,
  não elite) que morre marcado levanta onde caiu como esqueleto aliado por 15 s (`SimEntity.grave`: não ocupa vaga do Erguer Mortos, não leva o
  × 1,5; até `LORD_GRAVE_MAX` 4 de pé).
- **Forma de Lich** (nível 45, forma `lich`, 15 s, recarga 60 s): +30% MATK (`FORM_STATS`), a maldição lançada passa para os inimigos a
  `LORD_LICH_SPREAD` (4 m) do alvo e cabe +1 invocação por tipo; ao sair (tempo, troca de forma ou morte) o que passa do limite normal some da
  mais antiga para a mais nova (`trim_summons`). Visual provisório: o modelo do Lich-Rei (`FormModel.FORM_PATHS`), até existir `form_lich.glb`.
- **Teia de ascensão** (40 pontos de conteúdo para 36 aos 45): 4 skills com maestria no ramo Geral + nós `AscensionCatalog.NODES["necromancer"]`
  (`flag` lido por `ProgressionSystem.asc_flag`): Geral — Vínculo Sombrio (37, Pacto +3 s), Névoa Espessa (39, Miasma +2 s), Cova Funda
  (42, erguidos +5 s); Invocador — **Exército** (40, custo 2: +1 invocação por tipo e +20% da vida do mago nelas), Pacto de Sangue (45, roubo de
  vida × 2); Ceifador — **Foice que Comanda** (40, custo 2: o golpe manda as invocações no mesmo alvo por 4 s), Ceifa do Lich (45, forma +5 s);
  Sombras — **Miasma Largo** (40, custo 2: Miasma e Marca com +50% de raio), Praga do Lich (45, espalha a 6 m). Os três refinos do GDD saíram
  de `ASC_REFINES_PENDING`. Os nós de raio/duração entram em `ProgressionSystem.resolve_skill` (`NecroAscension.resolve`).
- **Bots** (`NecroAscension.bot_score`, chamado em `BotBrain._best_skill`): Pacto com `BOT_LORD_PACT_MIN` (2)+ invocações a 15 m em luta; Miasma
  no chefe/elite ou onde há `BOT_LORD_PACK` (3)+ inimigos (uma nuvem por vez); Marca da Cova no bando comum (2+) com alguém abaixo de 50% de vida,
  nunca no chefe; Forma de Lich contra chefe/elite ou bando. Ordem de compra: `AscensionCatalog.BOT_ORDER` (Invocador: Pacto primeiro; os outros: Miasma).
- Revisar: `-- --autostart=necromancer --ascend [--level=45]`, `combat_probe -- --class=necromancer --asc`, `boss_probe -- --asc=necromancer | --asc_base=necromancer`.

## Ascensão do Assassino (Ato II, 35) — Sombras Gêmeas, `ShadowSystem` (core/sim/systems/shadow_system.gd)
Liberada por `ProgressionSystem.has_ascension` (nível `Balance.ASC_LEVEL` + missão `hx_asc_assassin`). As três skills (`SkillDef.ascension`)
ficam fora da teia comum, compradas na teia de ascensão do Assassino (Geral + Lâminas, Duelista, Corsário), nas vagas 7/8/9/0.
- **Sombra Gêmea** (SELF, recarga `SHADOW_CD` 30 s, efeito `shadow_clone`): clone de sombra por `SHADOW_TIME` 6 s. É uma invocação com a
  classe, o visual e o equipamento do dono e `SimEntity.shade`: **não é hostil a ninguém** (`is_hostile_to`): monstros não o miram nem o
  acertam, ele não entra na ameaça e não segura aggro. Fica ao lado do dono (`SHADOW_SIDE`; longe demais, aparece do lado). Cada **golpe
  direto** do dono que causa dano (`WorldSim._strike`: skill, básico, projétil; dano no tempo não) entra na fila `echo` do clone, que faz o
  mesmo gesto e, no impacto dele (preparo da skill, no máximo `SHADOW_ECHO_MAX` 0,3 s depois), causa `SHADOW_SHARE` 50% do dano **em nome
  do dono** (tipo `shadow`: ameaça, abate, roubo de vida e talentos são do dono). Golpe novo antes do anterior sair: a fila sai na hora.
  Some no fim do tempo (soltando o que estava na fila) ou na hora se o dono cair/trocar de mapa. Um clone por dono (lançar de novo renova).
  Buff `twin_shadow` no dono enquanto dura. Visual: o kit do dono no `ghost.gdshader` escuro com borda violeta (`EntityView`, sem GLB novo).
- **Execução** (TARGET corpo a corpo, recarga `EXECUTION_CD` 10 s, efeito `execute`): poder `EXECUTION_POWER` 3,0 em alvo **abaixo de
  `EXECUTION_BELOW` 25%** da vida, `EXECUTION_WEAK` 0,8 acima. Chefe segue a mesma regra (o limiar; o corte de fase/ward dele continua valendo).
- **Refinos 40** (nós da teia de ascensão, saíram do `ASC_REFINES_PENDING`): Lâminas — **Sombra Furtiva** (portão `ass_shadow_stealth`): sair
  da furtividade golpeando chama o clone por `SHADOW_STEALTH_TIME` 3 s sem gastar a recarga; Duelista — **Contra-Ataque em Cadeia**
  (`ass_chain_counter`): cada esquiva deixa a Execução pronta e a próxima sai sem recarga (buff `exec_ready`, 1 carga, `CHAIN_COUNTER_TIME` 8 s);
  Corsário — **Canhão de Mão** (skill, nível 40, pistola, DIRECTION 9 m): tiro que atravessa, `HAND_CANNON_POWER` 2,6, empurra
  `HAND_CANNON_PUSH` 3 m (efeito `knockback`; chefe não é empurrado), +2 Bravata.
- **Teia** (custo total 36 = os pontos do 45): 3 skills com entrada e maestria 0-5; Geral: Sombra Persistente (+1 s), Sombra Afiada (+5% no
  clone), Golpe de Misericórdia (+10% Execução), Fio Gêmeo; cada build: 2-3 passivos e o refino dela (stats `shadow_time`, `shadow_share`, `execute_pct`).
- **Bots** (`AscensionCatalog.BOT_ORDER["assassin"]`, `BotBrain._best_skill`): Sombra Gêmea ao colar no alvo (`BOT_SHADOW_RANGE`) e sempre
  que recarrega; Execução só com o alvo abaixo de 25%. Peso F5 por build em `Balance.ASC_BUILD_POWER` (multiplica o dano do clone e a Execução cheia).
- Revisar: `-- --autostart=assassin --asc_shot=<png>` (`_clone`, `_golpe`, `_execucao`); `combat_probe -- --class=assassin --asc`;
  `boss_probe -- --comp=paladin:guardiao,bishop:sacerdote,assassin:<build>,assassin:<build> --party=4 --asc_level --asc=assassin | --asc_base=assassin`.

## Ascensão do Bispo (Ato II, 35) — Coro Celeste, `ChoirSystem` (core/sim/systems/choir_system.gd)
Liberada por `ProgressionSystem.has_ascension` (nível 35 + missão `hx_asc_bishop`); vale para as 3 builds (skills com `build: ""`).
Ascensão de **utilidade**: o F5 dela é a queda de mortes do grupo sob pressão (`boss_probe --comp ... --dmg=6`), não o tempo de luta.
Números em `Balance.BARRIER_*` / `ANGEL_*` / `BLESS_*` / `RES_*` (GDD `ato2-horda` R6.1 e F9).
- **Anjo Guardião** (`bis_choir_angel`, SELF, `ANGEL_TIME` s, recarga `ANGEL_CD`): entidade SUMMON com `SimEntity.spirit` — ninguém a mira
  nem acerta (`is_hostile_to` falso nos dois sentidos), não empurra, cura/buff de área não gastam alvo nela, sem cérebro. `ChoirSystem.tick`
  a faz voar atrás do Bispo (por cima de tudo) e, a cada `ANGEL_HEAL_EVERY` s, curar com `ANGEL_HEAL` × maestria pela cura do Bispo
  (`Combat.calc_heal` do dono): o tanque abaixo de `ANGEL_TANK_BELOW` primeiro, senão o mais ferido a `ANGEL_RANGE` m. No fim do tempo a
  **Luz de Partida** cura em área (`ANGEL_PARTING_*`). Some com o Bispo (morte, troca de mapa). Um por vez (chamar de novo troca).
- **Barreira Sagrada** (`bis_choir_barrier`, GROUND a `BARRIER_RANGE` m, raio `BARRIER_RADIUS`, `BARRIER_TIME` s, recarga `BARRIER_CD`):
  cúpula em `m["barriers"]`. Aliado dentro recebe −`BARRIER_DR`% de dano (`ChoirSystem.damage_in`, em `_deal_damage`; duas cúpulas não somam,
  vale a de maior tempo restante); projétil de inimigo que veio de fora para na borda (`stops_projectile`) e a chuva de chefe (`barrage`)
  não cai em quem está dentro se o chefe está fora (`shelters`). A cúpula **anda com o Bispo**: persegue (Bispo + deslocamento do
  lançamento) `BARRIER_LAG` m/s mais devagar que ele — se ele corre, ela fica para trás e o grupo tem de andar junto.
- **Bênçãos de grupo** (`BLESS_RADIUS` m, `BLESS_TIME` s, recarga `BLESS_CD`; renovam pelo id): **Asas da Aurora** (`BLESS_WINGS`: movimento
  e velocidade de ataque) e **Égide Coral** (`BLESS_AEGIS`: DEF e MDEF; golpe direto recebido cura `BLESS_AEGIS_HEAL`% da vida, no máximo
  uma vez a cada `BLESS_AEGIS_HEAL_ICD` s por aliado).
- **Retorno** (`bis_choir_return`, nível `RES_LEVEL` 45, GROUND, conjuração `RES_CAST`, alcance `RES_RANGE`, recarga `RES_CD`): levanta ali
  mesmo o caído do grupo mais perto do ponto mirado com `RES_HP_PCT` da vida. Enquanto o Bispo conjura, o caído não renasce na cidade
  (`SimEntity.res_hold`). **Um por aliado por luta** (`SimEntity.returned`, limpo quando ninguém do grupo está em combate): a 2ª vez é
  recusada com "já voltou nesta luta".
- **Nós da teia** (`AscensionCatalog.NODES["bishop"]`, portões lidos por `asc_flag`): Geral — Santuário da Barreira (45: nos primeiros
  `BARRIER_HOLD` s da cúpula ninguém dentro cai abaixo de 1 de vida); Sacerdote — Anjo Forte (40, +`ANGEL_STRONG_PCT`% de cura) e Dois
  Anjos (45); Iluminado — Barreira que Fere (40, `BARRIER_BURN_POWER` por segundo em inimigo dentro); Batalha — Barreira em Marcha (40: a
  cúpula anda colada nele, até na investida, e dá escudo de `BARRIER_MARCH_SHIELD`% ao lançar) e Retorno Blindado (45, escudo de
  `RES_BATTLE_SHIELD`%). Conteúdo: 36 pontos no ramo Geral + 1-2 da build para 36 ganhos aos 45.
- **Bots** (`BotBrain._choir`, antes da cura): Retorno em quem caiu; Barreira no meio do grupo quando há chuva/golpe avisado de chefe
  por perto ou `BOT_BARRIER_HURT_N` membros abaixo de `BOT_BARRIER_HURT`; Anjo sempre que pronto em luta de chefe (fora dela, com alguém
  ferido); bênçãos pelo `_best_skill`. Os outros bots do grupo **entram e ficam na cúpula** enquanto ela existir (`BotBrain._fight`;
  seguem a cúpula, não o Bispo) — menos quem está com o aggro do alvo (o tanque não arrasta o chefe) e o próprio dono.
- **Visual**: cúpula de luz com aro no chão (`FxManager._update_domes`, lê `m["barriers"]`; brilha mais durante o Santuário), anjo
  procedural que paira e bate asas (`EntityView`, forma `angel`), fio de luz na cura, `BuffLooks` `choir_wings`/`choir_aegis`.
  Revisar: `-- --autostart=bishop --choir_shot=<png>`.

## Ascensão do Druida (Ato II, 35) — Forma Ancestral, `DruidAscension` (core/sim/systems/druid_ascension.gd)
Liberada por `ProgressionSystem.has_ascension` (nível `Balance.ASC_LEVEL` + missão `hx_asc_druid`). Cada build ganha uma **3ª forma**
(skill de ligar/desligar como Lobo/Urso: `SimEntity.form` = `ent` | `alpha` | `bird`, bônus em `Balance.FORM_STATS`, arma em `FORM_REQUIRES`)
e duas skills que só saem nela (`SkillDef.requires_form`); tudo `SkillDef.ascension` (teia de ascensão, barra 7/8/9/0). Na forma, as skills
da build viram as variantes de `SkillsCatalog.ANCESTRAL_MODS` (mesmo formato de `FORM_MODS`; skill sem variante própria usa a da forma de
base, `Balance.ANC_FORM_BASE`: Ent → urso, Lobo Alfa → lobo, e a ancestral vale pela base em `requires_form`, ex. Espreitar como Lobo Alfa).
A forma não é salva, cai ao morrer e ao trocar a arma; trocar Urso → Ent (ou Lobo → Alfa) é direto. Números em `Balance.ANC_*` (H).
- **Ent** (Urso, malho): tanque — mais DEF/HP que o Urso e +ameaça. *Raízes Ancestrais* (SELF 6 m): dano, prende `ANC_ROOTS_ROOT` s e
  **provoca em área** `ANC_ROOTS_TAUNT` s (efeito `provoke`: como `taunt`, mas a skill ainda fere e prende; chefes metade). *Bosque Protetor*:
  o grupo a 8 m recebe `ANC_GROVE_DR`% menos dano por `ANC_GROVE_TIME` s. Variantes: Golpe de Galho, Chamado do Bosque (grito 50% maior),
  Tremor de Raízes (atordoa e prende), Marcha do Ent, Chuva de Troncos, Casca Milenar.
- **Lobo Alfa** (Lobo, duas maças): *Chamar a Matilha* (efeito `pack`): `ANC_PACK_COUNT` lobos (`pack_wolf`) por `ANC_PACK_TIME` s com
  vida/ATK/DEF = do dono × `ANC_PACK_*_SHARE` (20 s, ATK 0,9: com 15 s e 0,4 a ascensão dava ×1,02-1,04 em grupo); chamar de novo troca a matilha. *Uivo do Alfa*: grupo a 10 m com +`ANC_HOWL_SPEED`% de
  velocidade e +`ANC_HOWL_ASPD`% de velocidade de ataque. Variantes: os golpes do lobo mais fortes (Mordida/Salto/Dilacerar do Alfa...).
- **Pássaro Arcano** (Xamã, cajado): voa por cima do chão — **só desenho** (`ANC_BIRD_LIFT` na `EntityView`; a sim é plana e golpe de chão
  o acerta normalmente), +velocidade e MATK (+3%). Variantes: Fogo Lunar → **Raio em Cadeia** (`chain`), Chuva Estelar → **Chuva de Penas de Luz**
  (efeito `area_heal`: além do dano, cura × MATK os aliados embaixo), Ciclone → **Rajada de Vento** (efeito `knockback`: empurra
  `ANC_GUST_PUSH` m para longe do centro; chefe e quem está em torre não), Tempestade de Raios, Pena Cortante. Skills da forma:
  *Relâmpago Arcano* (GROUND, poder `ANC_BOLT_POWER` 2,0, raio + 2 saltos) e *Revoada de Luz* (cura o grupo a 8 m + velocidade).
- **Teia** (`AscensionCatalog.NODES["druid"]`, um ramo por build, 36 pontos cada aos 45): 3 skills com maestria (21) + 2 passivos (36, 38),
  refino do 40 (`anc_<forma>`), passivo (43) e refino do 45 (`anc_<forma>_2`). Cada refino comprado: na forma ancestral, variantes e skills
  da forma com +`ANC_REFINE_POWER` de poder e +`ANC_REFINE_TIME` de duração (prender, atordoar, lentidão, provocar, buffs, matilha).
  Os refinos saíram de `ASC_REFINES_PENDING`.
- **Bots** (`BOT_ORDER` por build; `Balance.BOT_AUTO_FORMS`): entram na forma ancestral com inimigo perto (antes de bater), não voltam para a
  forma de base enquanto têm a ancestral na barra e não pedem skill de outra forma (`DruidAscension.bot_skips`).
- **Modelos**: `tools/blender/druid_ancestral.py` → `form_ent.glb`, `form_alpha.glb`, `form_bird.glb` (rig dos monstros, gestos
  `maul/pounce/slam/roar/brace` como Lobo/Urso, armadura `frm_<estilo>_<slot>_<osso>` de cada conjunto da build). Revisar:
  `lineup.tscn -- --strip=druid --set=<build> --form=<ent|alpha|bird>` e `lineup.tscn -- --mob_strip=form_<forma> --anim=<clipe>`.
  Checks `_check_ancestral_forms` / `_check_ancestral_bots`.

## Ascensão do Caçador — Falcoeiro: Olhos do Céu — `FalconSystem` (core/sim/systems/falcon_system.gd)
Proposta aprovada: `design/gdd/ato2-proposals-2026-11-11.md` §2 opção A. O lince continua; o falcão é o segundo companheiro.
- **Falcão intocável**: não é entidade (sem vida, sem aggro, sem chão): é estado do dono (`SimEntity.falcon`, `falcon_cd`,
  `falcon_target`), 1 por caçador, fica até o dono cair (não é salvo: chamar de novo). A cada `FALCON_DIVE_CD` (6 s) mergulha no
  **alvo do caçador** = o último inimigo que o caçador acertou com golpe direto (`_strike`), se estiver a `FalconSystem.reach()`
  (`FALCON_RANGE` 14 m × `ARCHER_RANGE_MULT`, como toda skill de arco): poder `FALCON_DIVE_POWER` 0,8 com o ATK do caçador
  (vem de cima e por trás: guarda de frente não bloqueia) e marca a **Presa**. Sem alvo válido o mergulho espera (não gasta a recarga).
- **Presa** (maldição-marca `falcon_prey`, `FALCON_PREY_TIME` 8 s, renova): o alvo recebe +`FALCON_TAKEN` 3% de dano **de todos**.
  Cada caçador tem a sua Presa no alvo. Desenho: quatro garras âmbar girando sobre a cabeça (não os fiapos roxos de maldição).
- **Teto das marcas** (`MARK_TAKEN_CAP` 25%, `Combat.taken_pct`): as maldições de `MARK_CURSES` (Marca do Predador do Lanceiro,
  Presa, arma lendária `mark` "Marca do Caçador"; de qualquer fonte) somam "dano recebido" até 25%; as outras maldições (Necromante,
  Assassino, Paladino) somam por fora, como antes. Efeito colateral: a evolução "Presa Escolhida" (Predador 26%) sozinha vale 25%.
- **Skills** (teia de ascensão, ramo Caçador, arco): **Chamado do Falcão** (SELF; recusado com o falcão no ar) · **Mergulho**
  (TARGET, alcance do falcão, recarga `FALCON_STOOP_CD` 12 s: poder `FALCON_STOOP_POWER` 1,6, atordoa `FALCON_STOOP_STUN` 0,6 s — em chefe
  vale a regra de controle ×0,4 —, marca a Presa, o falcão passa a seguir esse alvo e os linces saltam nele e o seguram
  `PET_COMMAND_FOCUS` s, sem a mordida extra do Ataque da Fera) · **Olhos do Céu** (SELF, `FALCON_EYES_TIME` 10 s, recarga 30 s: você e o
  grupo a `FALCON_EYES_RADIUS` 15 m ganham o buff `sky_eyes`: +`FALCON_EYES_CRIT` 4 de crítico contra alvo com Presa — stat `prey_crit`,
  não soma entre falcoeiros — e +10% de velocidade de movimento). Mergulho e Olhos do Céu pedem o falcão chamado.
- **Refinos como portões da teia** (saíram de `ASC_REFINES_PENDING`): **Falcão Real** (40, `falcon_royal`): quando a Presa morre, passa
  para o inimigo mais perto a `FALCON_ROYAL_RANGE` 8 m que ainda não tem a Presa desse caçador (duração cheia) · **Revoada** (45,
  `falcon_flock`): Olhos do Céu solta `FALCON_FLOCK` 3 falcões que mergulham (poder do mergulho automático + Presa) em 3 alvos
  diferentes: o do caçador primeiro, depois os mais perto já em luta (monstro quieto não é puxado).
- **Teia** (36 pontos aos 45, o ramo inteiro): 3 skills × (entrada + skill + maestria 0-5) = 21; Luva de Falcoaria (35, +16 AGI, 2),
  Garras Afiadas/de Aço/do Céu (36/38/43, +`FALCON_WEB_PCT` 15% de dano do mergulho cada, stat `falcon_pct`, 1 cada), Caçada a Três
  (37, +15% lince, 2), Falcão Real (40, 3), Vista Aguçada (42, +2% crítico, 2), Revoada (45, 3).
- **Bots** (`FalconSystem.bot_score/bot_eyes_slot/bot_dive_aim`, ganchos em `BotBrain._fight/_best_skill`): chamam o falcão ao entrar
  em luta; Mergulho sempre que sai da recarga, no alvo do tanque; Olhos do Céu em chefe (abertura e a cada recarga) e na hora em que
  há círculos de barragem no chão (mesmo fugindo deles).
- **Desenho**: `game/entities/falcon_view.gd` (ave procedural que plana em círculo a `FALCON_HOVER` m sobre o dono e desce a cada
  mergulho anotado pela sim em `falcon_dive_time/_pos`; na Revoada aparecem 3). Revisar: `-- --autostart=ranger --falcon_shot=<png>`
  (`_falcao`, `_mergulho`, `_revoada`). Peso F5: `ASC_BUILD_POWER["cacador"]` 0,3 (multiplica só o dano dos mergulhos; com 1,0, Presa 6% e crítico 8 o Falcoeiro dava ×1,18 sem o freio da ameaça).

## Supremas do nível 40 (GDD `design/gdd/ultimates-lv40.md`; onda A 2026-11-19) — `UltimateSystem`

- **Liberação**: nível `Balance.ULT_LEVEL` (40) **e** a ascensão da classe (`hx_asc_<classe>`). Uma Suprema por build
  (`SkillDef.ultimate`), a da build principal (`ProgressionSystem.main_build`) e só com a arma da build na mão. Fica fora
  da teia, da teia de ascensão, da barra 1-0, do rank e de `ClassDef.skill_ids` (`GameData.ultimates[classe][build]`).
- **Tecla R** (ação `ultimate`, `InputCommand.ultimate`, de 1 vez): mesmo pipeline das skills (preparo/ativa/recuperação,
  encarar o cursor); desmonta; custo 0 e sem recarga própria. A carga só é gasta quando a skill **sai** (cancelada no
  preparo, fica). Ao sair: carga zero e `ULT_MIN_GAP` s sem encher.
- **Carga Suprema** (0-`ULT_MAX`, não vai no save): dano causado = poder do golpe (sem ATK/DEF/crítico) × `ULT_GAIN_PER_POWER`
  × peso do papel, até `ULT_AOE_TARGETS` alvos por ação, dano no tempo × `ULT_DOT_MULT`, invocação × `ULT_SUMMON_MULT`;
  cura efetiva (sobrecura 0; escudo conta ao absorver; poção não) / cura de poder 1 do lançador × `ULT_GAIN_HEAL`; dano
  recebido = % da vida × `ULT_GAIN_TAKEN` (teto `ULT_TAKEN_HIT_CAP` por golpe; a parte redirecionada pela Proteção não
  conta); `ULT_TRICKLE`/s em combate. Pesos `ULT_ROLE_WEIGHTS` (tanque: dano 0,6 / cura 0,5 / apanhar 1,6; cura: 0,9 / 1,7 / 0,6; os outros 1,0 / 0,5 / 0,5). Fora de combate por
  `ULT_DECAY_DELAY` s esvazia `ULT_DECAY_RATE`/s; morrer e trocar de mapa zeram. O dano da própria Suprema nunca enche.
  O boneco de treino enche no ritmo normal.
  **Teto de ritmo** (calibragem 2026-11-19): dano/cura/apanhar enchem no máximo `ULT_RATE_CAP` pts/s com estoque
  `ULT_RATE_BURST` (o gotejar fica fora); sem ele o poder/s variava 1,5-10 pts/s entre builds. Medido com
  `boss_probe -- --boss=boss_ghar --lvl=40 --asc --ult --tank_lock --hp=2.5` (11 grupos tanque + Sacerdote + 2 builds, 4 lutas):
  as 24 builds enchiam em 50-58 s (mediana ~53 s); em 2026-11-19 o usuário pediu metade: ganhos, gotejar, teto de ritmo (2,6/s), reserva (20) e teto por golpe x2, intervalo depois de soltar 10 s; medido ~22-25 s de combate numa luta de chefe em grupo.
- **HUD**: moldura redonda à esquerda do 1-6 (`ActionBar.UltFrame`): anel dourado de carga, brilho + "PRONTA" + som
  `ult_ready` quando cheia, cinza com os segundos na trava, cadeado com o motivo quando travada. Janela J: a Suprema aparece
  no fim da aba da build. Aviso dos golpes de Suprema no chão em areia/dourado (nunca o vermelho de chefe).
- **Bots**: `SkillDef.ult_bot` = `boss` (chefe/elite ou `BOT_ULT_PACK`+ inimigos), `save` (`BOT_ULT_SAVE_ALLIES` aliados
  abaixo de `BOT_ULT_SAVE_HP`% ou tanque abaixo de `BOT_ULT_TANK_HP`%), `self` (cercado ou vida baixa). No grupo do jogador
  seguram `BOT_ULT_HOLD` s esperando chefe; dois do grupo não soltam a menos de `BOT_ULT_STAGGER` s (`UltimateSystem.bot_release`).
- **Mecânicas novas** (efeitos em `SkillDef.EFFECT_KEYS`, contrato no `skill_def.gd`): `storm` (`StormSystem`: tempestade
  presa no chão ou que segue o lançador; golpes avisados ou pulsos com lentidão que acumula e congelar uma vez),
  `hop_strikes` (`HopSystem`), `intercept` (`InterceptSystem`, fora do `DR_CAP`, vale o protetor mais perto), `dot_amp` e
  `curse_spread` (`UltEffects`), `pet_revive`, `barrage` de personagem (lista própria `ally_strikes`, bots não fogem), chave
  `ignore_max` no `summon` e chaves de buff `end_cast`/`oath_lock`.
- **Onda A** (2026-11-19): o sistema inteiro + a Chuva de Meteoros (Fogo, presa onde o mago lançou, decisão do usuário).
  As outras 23 entram na onda B com os números em `Balance.ULT_NUMBERS`.
- **Onda B1** (2026-11-19, Paladino/Berserker/Bispo/Druida; catálogo `SkillsCatalog._ultimates_b1`): Bastião da Aurora (provoca,
  escudo, Juramento cheio `oath_fill`, Proteção), Juízo da Alvorada (salto `leap_iframe` + `strikes`: o `dash` sai só no 1º golpe e
  `strikes.last_effects` só no último), Céu de Martelos (`orbit` com `oath_lock` e `effects` por batida; o relógio do orbit é
  `AURA_TICK` 0,5 s, então 0,42 × 20 batidas ≈ 8,4 no lugar de "0,5 a cada 0,6 s"), Festim de Sangue (buff `wound_hold`: suas
  feridas não fecham, `WoundSystem.hold`; fecha com a skill de apoio sem classe `ber_ult_blood_feast_end`), Veredito do Carrasco
  (`sunder_fill` antes do golpe + `ult_execute`), Sete Ventos e Garras da Lua Rubra (`hop_strikes`; o limite de pulos sem chão
  agora vale por salto), Cúpula da Graça (`grace_dome` → `ChoirSystem.place_dome`: cúpula parada; com a Barreira Sagrada vale a
  maior redução, `ChoirSystem.dr_of`), Sol do Julgamento (zona com `mend_pct`), Avatar da Fé (`ally_heal` + stat `phys_mend`),
  Colosso Primevo (`force_form` urso, recusa Ent/outras formas; buff `keep_hp`: a vida ganha entra cheia e no fim a % fica;
  `form_bound`: sair do urso acaba o Colosso), Coração do Bosque Ancião (zona com `foe_radius`/`foe_max`: Fogo Lunar nos 3 mais
  perto a 10 m, cura a 6 m). Boneco maior (Avatar ×1,25, Colosso ×1,5): chave de buff `scale`, só desenho (`EntityView.buff_scale`,
  transição `Balance.ULT_SCALE_TIME`).
- **Onda B2** (2026-11-19, Ranger/Assassino/Elementalista Gelo e Raio/Necromante; catálogo `SkillsCatalog._ultimates_b2`):
  Laço Selvagem (`pet_revive` com `buff` no lince: +ATK `pet_atk_pct`, resistência a controle e `scale` 1,4; `spirit` = 2º lince
  `free_summon` com 70% da ficha), Disparo do Fim (mira = `startup` 1,2 s, `ULT_NUMBERS.aim`, única exceção ao teto de 0,3 s; o
  clipe segura o quadro do tiro; projétil de 30 m com `sure_crit` e `pierce_rest` 0,6; empurra), Lança Incansável (`channel` de 12
  estocadas em linha que sangram e renovam a Marca do Predador; `channel_end` arremessa a lança e prende), Toxina Real (`dot_amp`
  ×2 por 8 s, detona ×2 e espalha a 4 m; marca verde girando sobre o alvo), Duelo Supremo (janela da Guarda por 6 s com
  `riposte_arc` 140°, `riposte_gain` 2 de Ímpeto, `riposte_gap` 0,5 s sem o teto de respostas; `end_cast` Golpe de Mestre com
  `momentum_fill`; leque prateado no chão), Chamado da Frota (`storm` presa no ponto, 14 balas avisadas em areia, bala cai do céu,
  empurra 1 m do ponto da queda; Bravata cheia), Inverno Eterno (`storm` de pulsos presa no ponto, congela no 3º), Olho da
  Tempestade (`storm` que segue o mago, raio do céu + `chain`; buff de velocidade; `cd_reset` do Passo Relampejante), Maré dos
  Mortos (6 esqueletos `ignore_max`; `buff_first` = o +MATK vale para eles; `summon_buff` nas suas invocações; `expire_blast` =
  explodem ao sumir × vida restante; a Oferenda não os pega), Ceifa das Almas (`hit_heal` 6%/atingido até 5, buff; variantes em
  `FORM_MODS`, só a da forma: `UltEffects.form_variant`), Eclipse do Vazio (`storm` de pulsos sem dano: lentidão, `dot_amp` 1,5 e
  `curse_spread`; `end` = implosão que puxa). Aparo inteiro do Duelista não enche a carga (golpe que não pegou, GDD §3.2).
  Força em alvo único medida por `_check_ultimate_b2_power` (régua: Chuva de Meteoros).
- **Força das Supremas de dano** (decisão do usuário 2026-11-19): +60% sobre o orçamento antigo de 10-14, alvo
  `Balance.ULT_POWER_BAND` = **16-22 de poder** em alvo único somando a duração (~1 por luta de chefe; medidor igual).
  Medida: `_check_ultimate_b2_power` lança cada uma contra um chefe parado e soma `SimEntity.ult_dealt` (dano que a sim marca
  como de Suprema: `WorldSim.ult_tag` em volta do `_apply_skill` da Suprema e de skill `*_ult_*`, golpes de `storm`/`hop`,
  martelos do `orbit`, zonas, dots marcados `ult`, o que o `dot_amp` acrescenta, a detonação, o fecho `end_cast` e as respostas
  do Duelo) ÷ o golpe médio de poder 1,0 de quem lança; média de 5 lançamentos, folga de ±1,5 no check. Festim e Duelo (buffs):
  diferença batendo de básico com e sem. Dano + utilidade com faixa própria da parte de dano (`ULT_POWER_PART`: Ceifa, Eclipse).
  Utilidade (Bastião, Cúpula, Avatar, Colosso, Laço, Maré) mantém os números. `boss_probe` imprime `ULTDMG` (parte do dano de
  cada build no chefe que veio da Suprema). Dots de Suprema (todos agora marcados `ult`, inclusive a sangria do Festim) não enchem a carga.
- **Duelo Supremo, contador do Duelo** (decisão do usuário 2026-11-19): na guarda, cada golpe direto do próprio duelista
  (básico ou skill) soma `hit_gain` 1 (até `hit_cap` 8 golpes) e cada aparo soma `gain` 2; teto `duel_cap` 10. O Golpe de Mestre
  do fim (Ímpeto cheio, como antes) vale × `end_power` × (1 + `duel_per` 0,06 × contador): forte mesmo sem ninguém bater nele
  (o chefe olha o tanque). `RiposteSystem.duel_hit` (chamado no `_strike`, só para o golpe da própria ação: básico ou a skill em
  andamento; procs e lançamentos de graça não contam), `UltEffects.end_cast`.
- Cúpula da Graça fica até acabar mesmo com o Sacerdote caído/fora do mapa (decisão 2026-11-19); com ela de pé os bots do Coro
  não lançam a Barreira Sagrada. Companheiro guarda a defesa herdada do dono em `SimEntity.summon_pdef` (o fim do Laço
  Selvagem/Maré não a perde). `WorldSim.ult_tag` volta a 0 no começo de cada tique (medição nunca muda o jogo).

## Pontos de skill: teia (estilo Path of Exile)
**Skills pelo nível e rank no Mestre de Skills (2026-11-18)**: toda skill comum da classe (de todas as builds; fora as de ascensão)
chega sozinha no nível dela (`ProgressionSystem.grant_level_skills`: spawn, subir de nível, carregar o save; as novas vão para a 1ª vaga
livre de 1-6 se a arma serve). Arma e build continuam decidindo o que dá para usar; a barra continua com 6. O **rank 1-5** da skill
(o antigo nível de maestria, `e.mastery`: mesmos efeitos de `SkillDef.mastery`/`MASTERY_*_PER_LV`) sobe com **ouro + materiais da faixa
da skill** num NPC de papel `trainer` ("Mestre de Skills", `Balance.SKILL_TRAINER_ROLES`, `STATION_RANGE`): ouro =
`SKILL_RANK_GOLD_BASE` (40) × (tier + 1) × rank^1,5 (tier pelo nível da skill em `COMMON_TIER_LEVELS`), materiais `SKILL_RANK_MATS[tier]`
= rank unidades do comum (era rank + 1; ferro virava gargalo no 1-10) e, do rank 4 (`SKILL_RANK_RARE_FROM`), rank − 3 do raro (os pares das joias); rank r pede nível ≥ nível da skill +
`SKILL_RANK_LEVEL_STEP` (3) × (r − 1). Ex.: skill do nível 1, rank 1 = 40 de ouro + 1 Minério de Ferro; rank 5 = 447 + 5 Minérios + 2
Carapaças, nível 13. API `ProgressionSystem.rank_cost/rank_error/rank_up` (`Sim.skill_rank_cost/skill_rank_error/skill_rank_up`); a
skill de ascensão continua com maestria na teia dela. **Na teia**, o círculo da skill fica igual: o centro (`<classe>_s_<id>`) virou
**"<Skill> Aprimorada"** (+`SKILL_UP_POWER` 15% de poder/cura) e o antigo nó de maestria (`<classe>_m_<id>`) virou **"<Skill> Ágil"**
(−`SKILL_QUICK_PCT` 12% de recarga e de MP), 1 ponto cada, uma vez (`ProgressionSystem._web_upgrades` no `resolve_skill`, MP no
`try_cast`). As skills iniciais não vêm mais com o nó comprado. Pontos: 8 → **7 por nível** (+1 no 10/20/30/40) = 206 no 30, 277 no
40, 312 no 45 (a maestria gastava ~45-65 pontos no 30; web_probe antes/depois: 30 ATK x1,31→1,32, HP x1,30→1,33; 40 1,35/1,29→1,36/1,31;
45 1,42/1,31→1,42/1,32). Bots não pagam rank: nível / `BOT_SKILL_RANK_PER_LEVELS` (6) nas skills da build, até o que o nível
libera (`bot_rank`); compram Aprimorada e Ágil das skills da build e só põem na barra skills da build/gerais. Começo rápido: skills do
nível e ranks de bot nas skills da barra. Reset da teia mantém skills e ranks. **Save v7**: nó `_m_` sai da teia antes da checagem de
nó desconhecido, o rank fica e cada nível volta como 1 ponto; `_s_` comprado vira Aprimorada (`SaveSystem.migrate_skill_ranks`).
Checks `_check_level_skills`, `_check_skill_upgrade_nodes`, `_check_skill_ranks`, `_check_save_skill_ranks`.

Regras completas, fórmulas e critérios em `design/gdd/progression.md` (a teia está descrita em "Teia de skills" mais abaixo). A barra 1-6 se troca em qualquer lugar (`Balance.LOADOUT_TOWN_ONLY`, liberado em 2026-11-16); resetar a teia é grátis perto do Ancião ou do Sumo Sacerdote (`SKILL_RESET_NPCS`).

**Notáveis de papel (playtest 2026-11-18, "o assassino tinha 500 de vida e o paladino 4k")**: `Balance.ROLE_NOTABLES` troca o bônus
dos notáveis da teia do 30 mais perto do início (mantém atributo, ids e posições; `TreeCatalog._role_notables`). Classes que não são
tanque ganham 4 de **sobrevivência** temáticos (Assassino: esquiva, crítico que cura; Ranger: HP, golpe físico que deixa lento;
Elementalista: Barreira de Mana; Necromante: Armadura de Ossos, dreno; Berserker: roubo de vida abaixo de 35%; Bispo/Druida: cura
recebida, redução de dano); os tanques (Guardião, Urso) ganham 3 de **dano** no ramo deles (DEF vira ATK, bloqueio devolve dano,
crítico depois de bloquear, +dano em quem tem você como alvo, espinhos). Stats novos em `Stats.STAT_KEYS`, regras em `Combat.role_*`.
O HP base por nível das classes que não são tanque subiu 10-15% (`classes_catalog.gd`; Urso/Ent compensados em `FORM_STATS`).
Alvo do usuário: rota completa = +25-35% de HP efetivo contra antes (medir: `tools/tests/hp_probe.tscn -- [--levels=30,45] [--notes]`).
Bots buscam os do papel deles (`ProgressionSystem._bot_role_notes`, até `BOT_ROLE_NOTE_PATH` nós). Check `_check_role_notables`.

**Notáveis de base (2026-11-21)**: anel de 5 notáveis em volta do Início da teia (`Balance.CORE_NOTABLES`, `TreeCatalog._core_ring`, ids
`<classe>_core_N`), nível 1, 1 ponto cada, todos compráveis; bots compram os 5 antes de tudo. Mecânicas novas (regras em `Combat.core_*`,
`WorldSim._deal_damage`/`_heal`, tetos em `Balance`): Mana em Carne (`mp_to_hp`, +HP = % do MP), Escudo de Carne (`summon_guard`, parte do
dano vai para a sua invocação mais perto), Fúria dos Mortos (`summon_frenzy`, invocação abaixo de 50% bate mais), Sangue em Ossos / Sangue
que Sobra (`leech_shield`, roubo que passa do máximo vira barreira), Escudo dos Irmãos (`ally_guard`, parte do dano dos aliados do grupo a
até 8 m vai para você), Firme na Queda (`low_dr`, menos dano abaixo de 50%), Fúria da Beira (`low_hp_atk`, mais dano quanto menor a vida),
Graça Transbordante (`overheal_share`, a cura que passa do máximo vai ao aliado do grupo mais ferido). O "% da DEF em ATK" é extra (a DEF fica).
O anel soma ~+5% de HP em todas as classes: `WEB_GAIN_HP` 1,35 -> 1,42 e teto próprio do Elementalista (`WEB_GAIN_BUILD_CLASS`).
Check `_check_core_notables`; testes de outras mecânicas tiram o anel do bot (`_strip_core`).

**Orla (Ato III parte 1, níveis 46-50; GDD `ato3-excesso-45-50` §6.5)**: anel de casas por fora da Fronteira (`TreeCatalog._rim_web`,
sorteio próprio `<classe>_teia_ato3`: a teia do 45 não muda; a escolha de casas e as estradas da Fronteira e da Orla saem do mesmo
`TreeCatalog._grow`). Por setor de build `WEB_RIM_CELLS` (3) círculos: notável da build (`RIM_BUILD_NAMES`, 2 passivos da build ×
`WEB_RIM_PASSIVE_MULT`), notável de elo com a vizinha e uma **pedra-angular menor** (KEYSTONES × `WEB_RIM_KEYSTONE_SCALE`, "... Menor",
nível `WEB_RIM_KEYSTONE_LEVEL` 48); o Geral 2 (notável "Maior" + pedra menor). Casas de `WEB_RIM_MIN_K` a `WEB_RIM_GRID_K` casas do
centro, nível `WEB_RIM_LEVEL` (46 perto, 49 longe). Pontos: 7 por nível + 1 no 50 = 348 no 50. Faixa `WEB_GAIN_LATE[50]` (ATK x1,4-1,75,
HP x1,12-1,42, build x1,35-3,0; Elementalista x1,35-3,2). Checks `_check_web_rim`, `_check_web_strength`.

## Lendários com visual próprio (`GearCatalog.SET_VISUALS`)
Arte de referência em `reference/<classe>/set_N/` (frente, costas, ícones). Cada um vira um estilo do kit (`chibi_kit.SET_STYLES`,
peças `arm_<estilo>_<slot>_*`), ícones renderizados em `assets/icons/<icone>_<peça>.png` e nomes da referência.
Nomes das peças por regra (2026-11-10, `GearCatalog.set_piece_name`): substantivo da build (`PIECE_NOUNS`; `nouns` no conjunto troca
uma peça, ex.: capuz) + complemento do conjunto (`suffix` "da Galhada", ou `adj` que concorda: `ADJ_FORMS` x `NOUN_FORM`); `names`
só nos 2 conjuntos escritos à mão. Corrigiu 39 nomes ("Manoplas Rubro" -> "Manoplas Rubras"). Check `_check_set_names`.
- Paladino Guardião lv5 — **Conjunto Cavaleiro da Fortaleza** (`pal1`): placa violeta sobre traje branco, elmo com crista e
  aletas + viseira, ombreiras em bloco, emblema em V, manoplas, faldas e joelheiras. "Polainas" não tem slot no RagnaEx: vêm com a armadura.

## Conjunto inicial (`ItemsCatalog.STARTER_SETS`)
Cada classe começa com arma(s) + elmo, corpo, luvas e botas próprios (estilo e cor da classe: Escudeiro, Saqueador, Noviço,
Bosque, Batedor, Sombras, Aprendiz Arcano, Acólito). O corpo tem os atributos da antiga peça única; o resto só dá defesa.

## Equipamento lendário e conjuntos (`data/catalog/gear_catalog.gd`, gerado por loops)
A cada 5 níveis (5/10/15/20/25/30, 35/40/45 no Ato II e 50 no Ato III) cada **build** tem um conjunto lendário: elmo, corpo, luvas, botas, arma (+ secundária).
Os conjuntos do 35, do 40 e do 45 reaproveitam o visual do 30 (`GearCatalog.visual_of`, nomes genéricos "... da Ascensão", "... do Triunfo" e "... do Apogeu") até ganharem modelos próprios.
Bônus: (2) +atributo secundário · (3) +atributo principal (ex. INT +2) · (4) +20% na skill assinatura (ex. Bola de Fogo) ·
(5) +% no stat da build e −% de recarga de outra skill. Os números crescem por tier (`Balance.SET_*`); os percentuais, acima do tier 5,
crescem pela metade (`Balance.set_pct_tier`: 4 peças 42% no 35, 44% no 40, 46% no 45 e 48% no 50; 5 peças 17/18/19/20%, recarga 21/22/23/24%).
**Ato III, 50 (GDD `ato3-excesso-45-50` §8, D6 do usuário)**: SÓ o conjunto da build (24) e os acessórios lendários 50; híbridos e Ápices
param no 45 (`Balance.HYBRID_LEVELS` = 35/40/45). A malha é a do Ato II da build numa 4ª cor da escada (`Balance.ACT2_SET_LEVELS` =
35/40/45/50 indexa `colors`/`accents`/`glows` de `GearCatalog.ACT2_VISUALS`; 50 = "porcelana e ouro velho", marfim + ouro velho + brilho
rosa-pó, PROVISÓRIA e igual em todas as builds até a paleta ser aprovada), epíteto "da Aurora Clara" (provisório).
**35/40/45: mais dois tipos coexistem com o da build** (138 conjuntos): **híbridos** (só P3 Templário+Guardião, Bi3 Batalha+Sacerdote e os
3 pares do Elementalista e do Necromante; 5 peças = Fusão) e **Ápices** (`design/gdd/apice-sets.md`; 14 builds: as 3 do Berserker, Ranger,
Druida e Assassino, mais Cruzado e Iluminado). Ápice = armadura/atributos da build, as armas da build como peças alternativas (efeito
lendário próprio), 2-4 peças iguais às do conjunto da build e um 5 peças "de identidade" (`GearCatalog.APEX`, `Balance.APEX_NUMBERS`,
regras em `FusionEffects`, id `apice_<build>`) que só liga com a arma da build na mão. Cor = a do conjunto 30 escurecida e dourada.
Cai e troca como o da build (Relicária: só na aba da build); bots 35+ vestem o Ápice (Guardião/Templário P3, Sacerdote/Batalha Bi3).
Calibração F-AP2 (2026-11-17; Ghar 40, `--hp=2 --tank_lock --asc`, 80-160 lutas; ruído ±0,04 em G): dentro do alvo `min(G_5n; 0,12) ± 0,02` —
Carniceiro, Executor (`heavy` 11: G_ap 0,11), Punhos, Iluminado (`aurora` 16: 0,12). Fora, decisão pendente do usuário: **Cruzado** G_ap ~0,04 contra
0,09 (já no teto +30%: `judged` 10,4, `stun_ch` 7,8); **Lobo** 0,06-0,16 entre rodadas (alvo 0,12; `hunt` 13, no teto); **Xamã** 0,04-0,10 contra
0,076 (`moon` 12, `jump` 65). As bases b4/b5 são de antes das mudanças de DoT/CC do mesmo dia: refazer F-AP2 inteiro antes de mexer de novo.
Save 6: peças dos híbridos que saíram viram as do Ápice (`SaveSystem._migrate_hybrid`). Equipamento comum: tiers 1/8/16/24/32/40/48 (o do 32, "de Adamante", o do 40, "de Oricalco", e o do 48, "de Astralita" (Ato III), só gerados; raridade épica; Oricalco e Astralita têm cor própria, `GearCatalog.COMMON_TIER_TINT`). Joias/capas 48 e rank de skill 48+ usam, PROVISORIAMENTE, materiais de Kharzun (Aço Anão, Basalto Rúnico, Pele de Lobo Atroz, Escama de Salamandra) até a Fita do Festim e a Porcelana Chorosa existirem.
Drop: o lendário cai como **Moeda Lendária** (1 em 100 monstros; chefes 40% e 2 moedas; Reis sempre). **Iara, a Relicária** (praça de Aldara)
troca moedas por qualquer peça lendária da sua classe (conjuntos das builds, maça do conjunto, escudos nomeados): tier i de
`LEGENDARY_LEVELS` custa i+1 moedas (nível 5 = 1, nível 10 = 2 ... nível 30 = 6, nível 35 = 7, nível 40 = 8, nível 45 = 9, nível 50 = 10), até o seu nível (`WorldSim.relic_*`). A janela tem uma aba por build (abre na do conjunto que você veste, senão na do braço da teia com mais nós) e uma linha
por conjunto (bônus, armadura | arma, maça, escudo; ✓ = já tem, vestida, na bolsa ou no depósito); **Trocar o que falta** leva de uma vez as peças
de armadura que você ainda não tem (moedas × peças; a arma troca à parte). Escudos nomeados ficam na aba Escudos. Ela também vende
Moeda Lendária por ouro (`Balance.LEGEND_COIN_PRICE` = 500, `ItemSystem.buy_legend_coin`). **Reset das skills** com o Ancião Ravi
(`Balance.SKILL_RESET_NPCS`, `ProgressionSystem.reset_tree`, grátis, segundo clique confirma): a árvore volta ao início com as skills
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
sorteio fixo por classe; parte das estradas some, então há várias rotas) com círculos pendurados nas casas: o de skill ("<Skill>
Aprimorada" no centro; "<Skill> Ágil", evoluções e passivos da build em volta) e o de notável (anel de atributos com o notável no meio, duas entradas =
atalho). Cada ramo (Geral + builds) tem o seu setor em volta do início, como as regiões do PoE; skill de nível alto fica mais longe.
Estradas e junções custam 1 ponto e dão +1 do atributo do setor; os atributos maiores e os bônus ficam nos círculos. 7 pontos por nível
(+1 no 10/20/30/40; eram 8 até 2026-11-18) = 206 no 30, 241 no 35 e 277 no 40, numa teia de ~250-360 nós. Medido com `tools/tests/web_probe.tscn`: no 30 a teia dá
~x1,4 de ataque e ~x1,2 de HP a um bot da build. No 40 (`-- --level=40`, medido 2026-11-11): média ATK x1,31 e HP x1,32 (HP 0,02 acima da faixa do 30), builds com ATK×HP de 1,30 a 2,10.
Save antigo recebe os pontos de volta. Bots compram o caminho mais curto até a Aprimorada das skills da build, a Ágil ao lado e depois
notáveis/atributos (`ProgressionSystem.bot_spend`).
**Cargas de skill** (2026-11-21, combate de rajada): toda skill de dano ou controle (físico/mágico) com recarga base ≥ 8 s
(`SKILL_CHARGE_MIN_CD`), fora buffs longos, auras, formas, invocações, Supremas e ascensão (`TreeCatalog.charge_ok`), ganha no círculo dela o nó
**"<Skill> em Cargas"** (`<classe>_k_<id>`, 1 ponto, no lugar do último passivo do círculo). Com ele a skill guarda até 3 usos
(`SKILL_CHARGE_MAX`); MP a cada uso; as cargas voltam **uma de cada vez** (fila), cada uma em recarga do lançamento (já com Ágil, rank e
redução) × 1,3 (`SKILL_CHARGE_RECHARGE_MULT`). Sem o nó nada muda. Dash antes do impacto devolve a carga; encadear gasta a próxima.
As cargas não vão no save (carrega cheio). Barra: número de cargas no canto do ícone e leque claro da próxima carga (escuro com todas gastas);
ficha J: "Cargas: 3 (recarga X s cada)". Bots compram o nó das skills da build depois da Ágil e guardam a última carga para chefe/elite
(no lixo só gastam com 2+ prontas). Hoje: Paladino 12, Berserker 15, Bispo 11, Druida 11, Ranger 11, Assassino 18, Elementalista 19,
Necromante 13 skills com o nó. Check `_check_skill_charges`. Medido antes/depois (2026-11-21): web_probe 30 ATK x1,33→1,32 / HP x1,40→1,40,
50 ATK x1,45→1,44 / HP x1,36→1,36 (faixas passam); combat_probe 0 FLAG; dps_probe nv 30 (boneco, bot guarda a última carga) mediana
2060→2099, Punhos +29% (era o mais baixo), demais −5%..+10%; boss_probe grupo de 4 (Guardião, Sacerdote, Fogo, Lâminas), 20 lutas:
Senhor da Cripta 28,6→26,3 s, Rei Elfo 36,1→34,5 s, Rei Lich 30,6→30,9 s, 20/20 vitórias.
**Talentos de classe** (aba "Talentos"): a cada 5 níveis (5 a 45) uma linha com 3 escolhas que mudam o jeito de jogar
(`ClassTalentsCatalog`): buffs que ficam **permanentes** ou viram **aura** para o grupo (15 m), invocações que **ficam para sempre**
(elemental, esqueletos, lobos, Ent), **recusa a morrer** (1 HP e imortal por alguns segundos, com recarga), execução, emboscada mais forte,
mana como escudo, cura no abate etc. Um por linha, grátis (liberado pelo nível), trocar na cidade (`Balance.PICK_SWAP_TOWN_ONLY`); o reset
das skills mantém as escolhas. Bots (2026-11-16) escolhem sem sorteio pela nota `ClassTalentSystem.bot_score`: opção marcada para a build (35+) > cita skill da build (quanto mais cedo na prioridade, melhor) > gancho genérico que serve > só números (o Coração do elemento da build vale mais) > sem uso (Juramento sem escudo, armadilha sem skill de armadilha, gancho tipado sem skill do tipo); empate pelo tipo que o papel da build prefere, depois a ordem do catálogo. Exceções por build x linha em `ClassTalentsCatalog.BOT_PREFER` vencem a nota (onde a sobrevivência carrega a build solo): Cruzado 5 Determinação, Lâminas 25 Lâmina Sedenta, Gelo 25 Escudo de Mana (medição na auditoria, "Bots: exceções por build"). Necromante nv 5 (2026-11-16, pedido do jogador): Exército Eterno, **Mortos sem Pressa** (invocações com tempo ×`NEC_TALENT_SUMMON_TIME` 2, gancho `summon_time`) e **Podridão Lenta** (dano no tempo mágico ×`NEC_TALENT_DOT_TIME` 1,25 de duração e ×`NEC_TALENT_DOT_DPS` 1,15 por segundo, gancho `dot_boost`); bot fica com o gancho genérico se a build tem skill do tipo (`ClassTalentSystem._hook_fits`); escolha que sai do catálogo só some do save (a teia fica). Auditoria das 8 classes: `design/balance/class-talents-audit-2026-11-16.md`. Aplicada no mesmo dia (opção A): **regra dos talentos vivos** — toda opção da linha N cita uma skill que abre até o nível N (gancho genérico precisa de skill do tipo aberta; check `_check_talent_unlock_levels`); as 22 opções mortas e as repetidas saíram ou mudaram de linha (Elementalista 5 Bola Ardente/Faísca Viva/Lança Fria, Druida 5 Garras Afiadas/Lua Crescente, Druida 20 **Uivo da Lua** = +15% de velocidade de ataque só na forma, gancho `form_stats`, Necromante 15 Foice Sedenta e 20 Maldição Contagiosa, Bispo 5 Luz que Fere e 15 Martelo Abençoado, Assassino 5 Tiro de Abertura, Ranger 30 Presa Escolhida, Paladino 10 Golpe Ardente e 20 Bastião Vivo; lista completa na seção "Applied" da auditoria; números em `Balance.CT_*`). Talento que mudou de linha sai do save se ficou acima do nível ou repetiu a linha (`ClassTalentSystem.sanitize_picks`); os mods das escolhas valem na ordem das linhas (`set`/`effects` antes dos `mult`) e `mult.radius` numa skill de aura estica o raio do grupo e do pulso. **Ato II**: linhas novas aos **35, 40 e 45** (9 linhas no total), com uma escolha pensada para cada
build da classe (`build` na opção, sem trava; o bot fica com a da build dele). A 35 reforça a identidade da build para as lutas do Ato II
(bandos com líder, trolls, assassinos, investidas) sem depender da ascensão; 40/45 são refinos de skills que já existem. Os refinos de
ascensão do GDD (R6.1) que precisam de mecânica ainda não feita ficam listados em `ClassTalentsCatalog.ASC_REFINES_PENDING` (só dados). Em 2026-11-11 saíram de lá para portões da teia de ascensão: Lança Pesada (Cruzado 40, `pal_long_lance`: Carga Montada ×`MOUNT_LANCE_MULT` 1,3), Torreta Firme/Veterana e Salamandra/Golem de Gelo/Silfo; o refino da Corrente de Luz (skill cortada) foi removido. Em 2026-11-12 saíram os últimos (a lista está vazia; check `_check_asc_refines`), todos portões de custo 3:
  - Paladino: **Asas com Bloqueio** (Guardião 40, `pal_wing_guard`; substitui o refino cortado da Corrente: as asas dão +`ARCANE_GUARD_BLOCK` 10% de bloqueio, stat `block`, só com escudo), **Asas Protetoras** (Templário 40, `pal_wing_ward`: Modo Arcano gasta ×`ARCANE_WARD_MP_MULT` 0,5 de MP e o grupo a 6 m ganha `arcane_ward` −10% de dano, renovado no `AuraSystem.tick`), **Muralha a Cavalo** (Guardião 45, `pal_mounted_wall`: Provocar sai montado e bloquear não desce), **Estandarte** (Templário 45, `pal_banner`: montado, raio das auras de grupo ×`MOUNT_BANNER_MULT` 1,5, `MountedCombat.banner_mult`). Guardião e Templário ficam com 42 pontos de conteúdo para 36: a build escolhe o que deixa de fora.
  - Berserker: **Giro dos Dois Machados** (Gêmeos 40: Ciclone de Titã com 6 giros em 3 s, `TitanSystem.resolve`), **Segundo Machado** (Executor 40: com dois machados de 2 mãos, alvo abaixo de 20% da vida apanha o golpe duplo em toda skill, `TitanSystem.second_axe_mult` no `_strike`), **Fúria Acesa** (Punhos 40: lançar o Ciclone soma 6 s ao tempo da Fúria do Punho e da Glória), **Golpe Final da Arena** (Executor 45: Golpe Final ×1,2 e atordoa 1 s, `GladiatorSystem.resolve`), **Glória que Não Esfria** (Punhos 45: a Glória esfria em 18 s em vez de 12, e fica 12 s ao sair da postura).
  - Lanceiro: **Salto Duplo** (40: no pouso a recarga zera e abre 1 s para o 2º salto; sem uso, a recarga cheia começa quando a janela fecha; depois do 2º salto a recarga é ×`DOUBLE_JUMP_CD_MULT` 2 — com ×1 o `combat_probe --asc --level=45` dava 30% de luta intocável, máx 25%), **Brado Combinado** (45: gritar um Brado com outro ativo mantém os dois, o anterior até 8 s, recarga 40 s em `cooldowns["shout_combo"]`; a lança aplica os dois elementos; o bot usa).
  - Bots compram os portões da build (e do Geral) logo depois das skills, antes das maestrias (`ProgressionSystem.bot_spend_asc`). `combat_probe -- --asc --level=45` mede com a teia gasta.
  As teias de ascensão do Paladino e do Elementalista têm 36+ pontos de conteúdo por build aos 45 (passivos por build + Geral; check `_check_asc_web_fill`).
A aba abre rolada na linha liberada mais nova. Buff de talento aparece com ∞ na barra e não acumula com o lançado (mesmo id; o lançado vale enquanto dura).
Todo buff ativo aparece **no boneco** enquanto dura (borda/padrão na pele, bolha de escudo, cristal de gelo, chama, auréola, rastros, gotas,
fumaça; buff de talento ou aura do grupo só com a borda fraca) — tabela e revisão em `docs/buffs_visual.md`; buff novo precisa de linha em `BuffLooks.LOOKS`.
Nível 30 só cai do Dragonete. Raridades: comum, incomum, raro, épico, **lendário** (laranja).

### Lendários do 50: efeito em toda peça (onda 0, 2026-11-21; GDD `design/gdd/ato3-lendarios-50.md`)
- Cada peça do conjunto de build do 50 (cabeça, peito, calça, luvas, botas, arma, 2ª arma do Paladino, mão secundária) tem
  `ItemDef.piece_fx` (fichas em `GearCatalog.LEG50`, números SÓ em `Balance.LEG50_NUMBERS`; regras em `PieceEffects`).
  Cada peça vale sozinha (pode misturar builds da mesma classe); efeito que cita skill só age se o personagem a tem; o bônus de 2-5 peças continua por conjunto.
- Famílias: `stat`/`mana_guard_eff` (somam como bônus de item no `Stats.compute`), `charges` (luvas: a skill vira "em Cargas";
  com o nó da teia +1, teto `LEG50_CHARGE_CAP` 4), `cap_up` (Juramento, Bravata, Ímpeto, teto da Barreira até 40, torreta, Graça,
  respostas do aparo, Estilhaçar, Penitência), `skill_mods` (formato dos talentos), `legend_up`/`legend_wake` (a arma do 50 **desperta**:
  mantém `legend.kind` e números, ganha `legend.wake`; só com a arma da build), `form_up`, `dot_up`, `zone_on_cast`, `on_trigger`
  (bloquear, aparar, esquivar, abater, lançar/acertar skill, atordoar do Julgamento, explosão da Penitência, armadilha, Determinação cheia).
- Orçamento F-L50a: soma das peças ≤ `LEG50_GAIN_MAX` 0,12 (medido 0,118 no Durgash, grupo Guardião/Sacerdote/Executor/Fogo no 50,
  `boss_probe --l50_off=all`). Sondas: `boss_probe --set=b5 --set_lv=50 --set_weapon --l50_off=<peça|all>`, `dps_probe --levels=50 --l50`,
  `hp_probe --levels=50 --l50`. Checks `--only=leg50`.

## Equilíbrio entre builds

- **Princípio (2026-11-10, decisão do jogador):** o RagnaEx é jogo de grupo; o foco é a IA dos bots. Build não precisa vencer chefe
  de grupo sozinha: equilíbrio se mede em grupo (cada build liderando um grupo de bots: `boss_probe --party=4 --lead=<classe>:<build>`),
  e a vitória solo vira só sinal de alerta (0/40 com mortes = a IA ou a build quebrou), não alvo.
- `Balance.BUILD_POWER` multiplica o poder das skills do setor de uma build (ao carregar). Mexe no dano, pouco na sobrevivência.
- Medir: `dps_probe.tscn -- --levels=30` (dano no boneco) e `boss_probe.tscn -- --party=1 --trials=10 --lead=<classe>:<build>
  --boss=count_vargo,elf_king,death_knight,lich_king` (vitórias solo de 40). Depois do retrabalho dos chefes (2026-11-09) os 4 são
  chefes de GRUPO: o alvo antigo (18-30) caiu; solo bom = 8-30 de 40, tank e cura podem ficar abaixo. `--why` mostra a linha LIDER
  (armas, atributos, barra, forma vista).
- Bot druida entra na forma (Lobo/Urso, `Balance.BOT_AUTO_FORMS`) com inimigo a `BOT_FORM_RANGE` m; antes nunca se transformava e
  lutava como humano (Lobo e Urso 0/40). Check `_check_bot_form`.
- Rodada 2026-11-09 ("só consertar as quebradas", sem cortar as fortes): `BUILD_POWER` Lâminas 2,3, Duelista 1,7, Fera 1,6, Raio 1,35,
  Guardião 1,5; Sacerdote ganhou Nova Sagrada na prioridade. Vitórias de 40: Sacerdote 0, Lâminas 6, Caçador 6, Lanceiro 7, Xamã 8,
  Duelista 10, Lobo 10, Gelo 10, Corsário 11, Raio 11, Cruzado 14, Guardião 14, Fogo 15, Atirador 15, Executor 16, Templário 16, Urso 18,
  Invocador 25, Ceifador 26, Punhos 28, Sombras 29, Batalha 31, Gêmeos 34, Iluminado 40.
  Sacerdote: não morre mas estoura o tempo (chefe ~45% em 300 s; MATK metade do Iluminado). Decisão 2026-11-10: aceito como build
  de suporte — fraco sozinho contra chefe de grupo, forte em grupo; não subir o dano.
  Lâminas (2026-11-10): furtividade de abertura, esquiva, vida e roubo de vida pequenos ficaram no ruído (~5/40). Reflexos ganhou
  -30% de dano sofrido por 5 s e entrou na barra do bot no lugar da Estocada Rápida. Caçador e Lanceiro seguem em 6-7.
- Bot não escolhe skill que a sim recusaria (sem companheiro, invocação no limite, aura ligada, já na forma) nem canaliza com
  o chefe mirando nele: as duas coisas o deixavam parado até morrer (Caçador 2 → 23, Pestilento 2 → 11).
- Necromantes: a força vinha da sustentação da classe (Drenar Vida 40% a cada 2,5 s, Muralha de Ossos), não das invocações
  (sem invocação nenhuma o Invocador ainda vencia 31/32, só mais devagar). Dreno 20% a cada 5 s, Muralha 24 s, invocações 45% do MATK.
- Fim de 2026-11-07 (vitórias de 40): Carniceiro 36, Inquisidor 34, Pestilento 34, Clérigo 33, Ceifador 32, Invocador 32, Cruzado 30,
  Xamã 29, Templário 28, Arremessador 26, Duelista 25, Caçador 23, Lanceiro 23 (2026-11-07, substituiu o Patrulheiro), Fogo 22, Guardião 21, Gelo 20, Fera 19, Executor 18, Trapaceiro 18,
  Raio 17, Sacerdote 17, Guardião Verde 16, Atirador 16, Lâminas 14 (antes do retrabalho dos chefes; histórico).
- **Dano em alvo único ±25% (combat-plan C5, 2026-11-23; decisão do usuário: "trazer os conjuradores para baixo").** Regra: builds de
  dano dentro de ±`Balance.DPS_SPREAD_PCT` (25%) da mediana no 30 e no 45 (tanque e cura fora). Medida: `dps_probe.tscn -- --on_only
  --full_rot --levels=30,40,45` (linhas SPREAD/MEDIAN; `--full_rot` usa buffs/invocações e liga a forma; `--real_mp` não enche a mana:
  difere <= 5 pontos, a mana cheia não favorecia os conjuradores; `--by_skill` = % do dano por fonte; `--old_gear` = equipamento de bot
  antigo). Check `_check_dps_spread` (lutas de 30 s, ~1 min).
  Causa do salto x3,3 dos conjuradores do 30 ao 45: (1) **bug do equipamento de bot** (`WorldSim._gear_scan`): cabeça/peito/luvas/botas
  ficavam com a última peça da lista (pano), então TODO bot corpo a corpo/AGI do 32+ vestia INT/VON (Executor 45: FOR 992, vida 1617;
  conserto: FOR 1262, vida 2452) e capa/amuleto de FOR vinham do Caçador; (2) o pano dá **INT de atributo principal** (a placa dá VIT e a
  FOR só de 2º) e a INT rende MATK e crítico mágico juntos: do 32 em diante (as peças geradas trazem cabeça/luvas/botas) o conjurador
  ganhava o dobro do atributo de dano. O couro faz o mesmo com a AGI do arco/mosquete/lança. Conserto na fonte: **cauda** da INT
  (`Stats.int_power`: acima de `INT_TAIL_REF` 75, escala antiga, cada ponto vale `INT_TAIL_MULT` 0,5 no MATK e no crítico mágico) e da
  AGI de arco/mosquete/lança (`Stats.agi_ranged_power`, `AGI_TAIL_*`; crítico e esquiva continuam pela AGI inteira); o 30 quase não muda.
  Depois, `BUILD_POWER` centrou cada build (ver comentário no `balance.gd`).
  | Build (% da mediana) | 30 antes | 30 depois | 45 antes | 45 depois |
  |---|---|---|---|---|
  | Raio | +81 | +4 | +151 | +4 |
  | Fogo | +46 | +14 | +92 | +11 |
  | Gelo | +25 | +2 | +59 | -1 |
  | Iluminado | +45 | +15 | +53 | -6 |
  | Xamã | +0 | +17 | +23 | +7 |
  | Cruzado | +41 | +22 | +19 | +7 |
  | Atirador | +32 | -2 | +18 | +2 |
  | Executor | -10 | -8 | -31 | -16 |
  | Gêmeos | -8 | -15 | -27 | -20 |
  | Lobo | -29 | -11 | -37 | -15 |
  | Invocador | -41 | +17 | -32 | +2 |
  | Ceifador | -11 | +15 | +11 | -15 |
  | Sombras | +0 | -9 | +12 | -15 |
  | Corsário | -11 | +0 | -22 | -4 |
  Antes = rotação só de dano, equipamento antigo (mediana 2104 / 5252); depois = `--full_rot` (mediana 2476 / 5820); fora de ±25%: 12 -> 0.
  Bots Cruzado/Templário ganharam notáveis de sobrevivência (`ROLE_NOTABLES.paladin[1]`, C10; compravam 0). Piso do `skill_audit`
  (60% da mediana da classe, sem o `BUILD_POWER`): `_check_skill_audit_floor`, utilidades em `run_tests.AUDIT_UTILITY`.
- **Tempo de abate de lixo e elite (combat-plan C11, 2026-11-23).** Duas medidas:
  (a) parada (check `_check_ttk_targets`, `Balance.TTK_TARGETS`): Duelista (perto da mediana de dano) no nível do monstro contra o
  monstro sem cérebro; lixo = vida mediana da faixa, elite = maior vida (fora chefe/Rei). Medido: 1-10 0,4 / 2,3 s · 10-20 0,4 / 2,5 ·
  20-30 0,4 / 0,9 · 30-40 0,7 / 1,1 · 40-45 1,2 / 2,0 · 45-50 1,2 / 2,0; alvo = x0,5..x2 disso.
  (b) caçada (`band_probe.tscn -- --only=duel --from=1 --to=45 --trials=4`; 4 seguidos, movimento e dano recebido): lixo ~1,0 s (1-10),
  ~1,7 (10-20), ~1,1 (20-30), ~1,0 (30-40), ~1,4 (40-45), ~3,5 (45-50, arena); elites 3-8,5 s (Guardiã élfica 8,5, Trent 5,8, Carniçal 4,8,
  Senhor da Guerra 3,4, Troll Bruto 3,6, Golem de Basalto 3,3). Leitura: o lixo cai em 1-2 golpes de skill (o próprio band_probe marca
  "trivial" < 3 s em 30 dos 70); subir a vida do lixo é decisão de mundo (world-builder/usuário), não destas metas.

## Progressão (lenta)
Lv 1-50 (Ato I até o 30, Ato II 30-45, Ato III parte 1 45-50; fórmula no parágrafo "Ritmo" abaixo e em `design/gdd/progression.md`).
Spawners enchem de uma vez ao carregar o mapa (`primed`); depois cada abate volta no tempo de respawn. Monstro sem alvo e sem personagem
a `Balance.DORMANT_RANGE` (40 m) dorme (não pensa/anda/atualiza). Separação usa grade de 3 m por tick (`WorldSim._index_map`) e monstros
procuram alvo só na lista de personagens do tick. Dungeons do mapa (`build_dungeons.py`): bando no meio de cada corredor (menos o da
chegada), salões com área de spawn do tamanho do salão.
**XP exigida em dobro** (2026-11-24, pedido do usuário: os mapas já têm opcionais bastante): `Balance.xp_for_level` = `xp_base_for_level` × `XP_LEVEL_MULT` (2,0). A curva base (abaixo, números F1) continua calibrando as **recompensas** (`QuestsCatalog.scale_xp` pela `band_xp_base`, eventos de estrada): quests dão a mesma XP de antes, ~metade da fatia planejada da faixa exigida; o resto vem de caçadas, quadros, eventos e masmorras. Os tempos em horas abaixo são da curva base.
**Repetíveis de nível baixo**: personagem mais de `Balance.QUEST_LOW_LEVEL_GAP` (3) níveis acima da repetível = "Nível baixo" (cinza no NPC/quadro e no painel; vai para o fim das listas: `QuestSystem.is_low_level/by_relevance`). Check `_check_quest_low_level`.

Ritmo (MVP até o 30, ~15 h): `Balance.xp_for_level` sai do tempo planejado no nível (6,5 + 1,75×(lv−1) min) × 3 abates/min ×
XP de um monstro do nível (6 + 4,5×lv) ÷ 0,55. Ato II (nível máximo 45, Monte Kharzun 40-45): do 30 em diante os minutos crescem só 0,75 por nível
(`XP_MIN_PER_LEVEL_ACT2`; 30→31 = 44 030, 34→35 = 52 250, 35→36 = 54 400, 39→40 = 63 360, 44→45 = 75 390; faixa 35-40 = 294 200 de XP, ~5,2 h; faixa 40-45 ~5,5 h); faixas 30-35 e 35-40 com 55% de quest, 40-45 com 50%; +1 ponto de teia também no 40 (312 pontos no 45); pontos de ascensão: 21 no 40, 36 no 45. Ato III parte 1 (nível máximo 50, GDD `ato3-excesso-45-50` §6.1): mesma F1, 45→46 = 77 900 ... 49→50 = 88 340, faixa 45-50 ~5,8 h com 50% de quest; +1 ponto de teia no 50 (348 no 50); ascensão parada no 45 (D5: nenhum ponto nem refino novo); save do 45 com XP 0 volta a subir. Quests não repetíveis dão 50% / 55% / 65% de cada faixa (1-10, 10-20, 20-30; `XP_QUEST_SHARE_BAND`; a curva conta 45%, então quem faz quest sobe mais rápido que o tempo planejado):
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
Estradas (material `road`) nas zonas abertas usam a cor do Blender (`MapBuilder._blender_road`; dungeons/fortalezas/cidadelas seguem com a terra do chão) e a ponta que chega num portal fica sem grama até a largura da malha (`_mask_portal_end`).

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
prende com teia, o Senhor da Cripta ergue servos e no fim drena vida. Rei e Rainha entram em fúria no fim. Números atuais na seção Chefes.
Visual de dungeon (`MapBuilder.is_dungeon`): fundo escuro sem céu, névoa densa, luz fria e fraca, bordas da tela escurecidas;
o jogador leva uma luz quente (`main._torch`, sem especular para não deixar reflexo no chão).
Câmera: 52°, 24 m por padrão, zoom de 14 a 34 m. Render a 125% da tela com MSAA 4x e sem FXAA; neblina fraca, porque ela cresce com a distância da câmera.

- **Vale de Aldara** (`city_aldara`, 300 m — cresceu 20% em volta da vila com `places.grow_aldara`, `tools/blender/zones/build_city_aldara.py` → `map_city_aldara.glb` +
  `data/zones/city_aldara.json`): vila murada (raio 42 desde 2026-11-21; portões onde as estradas de fora cruzam o muro) em bairros:
  praça aberta no centro (Balança do Trigo, cristal, Quadro; ponto de encontro dos bots), **Quartel** junto ao portão norte (Capitã Mira,
  pátio de treino com a Mestra de Skills e os bonecos), **Ofícios** a oeste (Ferraria = Oficina, Brom na bigorna; Botica, Lyra no balcão),
  **Mercado** a leste (avenida das bancas, loja do Tobias, Relicária, Armazém do Guarda-volumes), **Casa do Ancião** de frente para a praça
  e o **sul residencial** (Taverna, celeiro com as galinhas, casas). Todo NPC de serviço fica do lado de fora, na porta/balcão do prédio
  dele (`_check_town_identity`). Ruas: quatro avenidas curvas da praça aos portões + uma rua em anel; guardas nos portões. A vila é uma **região** do mapa
  (`MapDef.town_radius`/`in_town`): só dentro dela vale "cidade" (bots não lutam).
  **Praia dos Caranguejos (3-8, 2026-11-21)**: zona à parte (`field_crab_beach`, `build_field_crab_beach.py`), portal na garganta ao sul
  do lago de Aldara. Enseada de ~220 m (mar a oeste com rebentação: `WaterFx.SURF_MAPS`), rancho e píer do **Pescador Joca** na chegada
  (quest repetível `beach_shells`: 10 cascos), Recife do Rei na outra ponta (Caranguejo-Rei da Praia sai do mar, `emerge`). Área de farm:
  11 matilhas, ~70 caranguejos (comum, **Eremita** que se fecha na concha `mob_shell_hide`, **da Areia** que dá o bote `mob_sand_leap`;
  mesmo saque `lt_crab`). Medir: `tools/tests/farm_probe.tscn` (abates/min por bot; use `vivos_medio`/`zerou`). Check `_check_crab_beach`.
  **2026-11-24 (pedido do usuário: "o mapa é muito vazio")**: x2 por `Balance.SPAWN_MAP_MULT` (por cima do `SPAWN_COUNT_MULT`; raio x √2,
  mesma densidade por bando e mais área; o Caranguejo-Rei segue único): ~130 caranguejos. Sim igual (9,3 ms/tick; a maioria dorme). As
  caçadas repetíveis da praia (Caranguejo, Eremita, da Areia) saem do **Joca** (`QuestsCatalog.HUNT_GIVERS`), não mais do quadro de Aldara.
  Check `_check_crab_beach_more`.
  O build desenha com o mar ao sul e gira o mapa 90° no fim (`TURN`, `(x, z) -> (-z, x)`): a chegada fica no rumo oposto à saída de Aldara.
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
  Chefes com repertório (calibragem na seção Chefes). Todo chefe da faixa tem `intro` (fala ao entrar em combate, de novo depois de um reset) e `last_words`.
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
  com 2 grifos) e **Ilwen, Guardiã da Seiva** (L, com 2 trents e espíritos); números na seção Chefes (`boss_probe`).
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
    - **Cerco dos três lados (2026-11-21):** os fronts atacam JUNTOS num relógio único (`Balance.RAID_SYNC_MAPS`: 1º ataque em 90 s,
      depois 240 ± 30 s contados do fim da última leva; parado enquanto alguma leva vive e com o jogador fora do mapa; `RaidSystem.start_sync`).
      Fortaleza retomada cala só o lado dela. Levas +50%: Carniçal 75 (+3 ursos a cada 2), Ossos 38, Torre 38 (+3 cavaleiros a cada 2),
      teto `RAID_WAVE_CAP_MAP["field_ruins"]` 80 por leva. A força acompanha o jogador até o nível 30 (`RAID_SCALE_TO_MAP`; passo 5 no 20, 15 no 30:
      vida x2,2, ATK/DEF x1,9 sobre o base). Medir: `raid_probe.tscn -- --map=field_ruins --sync --bots=0,3 --level=N --raid_level=N`.
    - O leste é o lado seguro (Aldara, cabanas, rochedo do Dragonete).
    - **Guerra que muda com a conquista:**
      - **Fúria:** cada fortaleza retomada multiplica as levas dos fronts que sobram por `RAID_RECLAIM_MULT` (1,5) e soma elites (`reclaim_extra`), com teto de `RAID_WAVE_CAP_MAP["field_ruins"]` (80) por leva (`RaidSystem.reclaimed`).
      - **Reforços:** cada fortaleza retomada manda até `Balance.REINFORCE_MAX` (3) soldados ao Bastião a cada 2 min (`ASSAULTS["field_ruins"]["reforco_<lado>"]`):
        a rota da investida até o portão do lado, a avenida e a borda da praça. Eram até 8 por fortaleza e espalhavam a última investida (2026-11-10).
      - **Último front** (as outras duas retomadas): leva x `RAID_LAST_FRONT_MULT` (2) além da fúria, teto `RAID_WAVE_CAP_LAST` (80) e um líder elite
        (`RAIDS[..]["leader"]`). raid_probe `--reclaimed=2 --reinforce=2` (reforços já na praça): antes 24 reforços; agora 6, e um bot do 24 cai em toda leva.
        Desempenho (`-- --autostart=paladin --siege_perf=<png>`, com janela): leva de 84, FPS médio 71; na chegada ao portão
        ~37 FPS por ~5 s (leva antiga de 55: ~62). A sim do Bastião já passava de 5 ms/tick (~8 ms) antes da leva maior.
      - **Surtida:** quando uma leva chega à muralha, 20 soldados saem da porta da catedral até o portão atacado (`MapDef.sortie`, `SORTIES`, recarga `RAID_SORTIE_COOLDOWN` 180 s) e voltam/somem quando a leva acaba.
      - Com duas retomadas, o último front (~60) só cai com o jogador e o grupo (3 bots nv 27: 4/4).
      - **Torres:** 10 torres na muralha com besteiros no alto (`guard_wall_crossbow`, `npc_data.perch` = altura visual; `SimEntity.is_perched`). Atiram por cima do muro com pouco dano, não andam, não são alvo, não tomam dano e não puxam aggro.
      - **Serviços:** catedral a 72%. Na praça, Relicário (lendárias por moeda) e Depósito; a Alta Sacerdotisa também reseta skills (`Balance.SKILL_RESET_NPCS`).
  - **Covil do Carniçal (praga):** layout próprio de pântano-ninho (`build_dawn_forts.build_ghoul`), sem o molde de muralha das outras: rio de bile que corta o vale com duas pontes de osso, lagoas de bile, duas trilhas de lama em volta da lagoa do meio (e um atalho estreito), ninhos de carcaça no lugar dos postos, e o covil é o cadáver do bicho: costelas colossais em anel com brecha ao sul, crânio gigante e coluna ao norte, monte de carne e poço de bile no pátio. Ovos de larva, ossadas, pústulas e moscas pelo charco, com o dobro de criaturas. Retomado, a Aurora acampa dentro das costelas.
    - O Carniçal Gigante tem feridas com pus, rasgo na barriga, chifre, nuvem de moscas, sino enferrujado, chaminés de gás e cutelo.
    - Os chefes das fortalezas renascem em 2 min enquanto a quest de retomada não sai.
  - **Fortalezas** (`build_dawn_forts.py`, um mapa por laço): Covil do Carniçal (20-23), Fortaleza dos Ossos (21-24), Torre do Mago Gélido (23-26) (rótulos do ritmo real, D8 2026-11-25). Retomado: Restos da Noite no front e um bolsão no fundo do forte com o eco repetível do chefe (`MapsCatalog.CATALOG_SPAWNERS`, caçada na Capela dos Pedidos). Bastião vivo (2026-11-25): `LIVING_NPCS["field_ruins"]` (aguadeiras, virotes, carroça dos mortos até os 3 fortes caírem, carroça da escavação, refugiados com `alarm` nas portas da catedral, vigia com `alarm_cry`; pedreiros depois do Lich), bichos em `AMBIENT_LIFE` e o evento "Relíquia na Estrada" (Penitentes, `unless: dw_lich`, pontos em `CATALOG_EVENT_POINTS` até o build gravar `events`).
    - Layout próprio de cada uma (2026-11-09; a Cidadela também, abaixo): Covil = pântano-ninho (acima);
      **Fortaleza dos Ossos** = necrópole na colina (`build_bones`): fenda funda que corta o vale de borda a borda (material
      `chasm`, só a ponte de ossos da estrada e a passarela da cripta leste atravessam, com postes de crânio), campos de túmulos
      e sarcófagos na encosta, mausoléus, muros de ossuário coroados de crânios ao longo da estrada em zigue-zague, criptas
      abertas no lugar dos postos, e dois patamares em volta da torre negra (o de fora com crânios e entrada a sudoeste: a
      estrada dá a volta entre eles até o portão sul); **Torre do Mago Gélido** = lago congelado (`build_frost`): gelo com
      placas e rachaduras, buracos de água escura (material `icewater`, bloqueiam), navios presos no gelo, montes de neve,
      acampamentos de cultistas em ilhas de neve (tenda, círculo de runas, braseiro de fogo azul) e a torre numa ilha cercada
      por um canal de água escura que só as pontes de gelo (sul e norte) cruzam. Check `_check_fort_lairs` (tudo alcançável;
      sem as pontes, o chefe fica isolado).
    - Cada uma tem estrada, dois postos para retomar, muralha com marco no pátio, prisioneiros e chefe:
      - Carniçal Gigante: ninhada de larvas e bile;
      - Vorhag, o Cavaleiro da Morte: ergue soldados, onda de morte;
      - Morvath, o Arquimago Gélido: gelo, prisão, nevasca, espectros.
    - **Conquista por personagem** (`WorldState`: spawner/NPC/rota/assalto com `if`/`unless` pela quest do jogador):
      - a quest dos postos põe guardas da Aurora nos postos;
      - a do chefe cala a fortaleza e a investida do lado;
      - os prisioneiros saem e nasce o assentamento (capitão, ferreiro de campo, mercador) com guarnição;
      - a fortaleza seguinte passa a receber a **leva aliada** (`MapDef.assaults`/`ASSAULTS`, `GuardBrain` em marcha) subindo a estrada:
        apoio, não limpeza — até `ASSAULT_FORT_MAX` (4) por vez a cada 90 s, vida e ataque x `ASSAULT_FORT_POWER` (0,5, `WorldState.assault_def`).
        Eram 10 a cada 45 s com 1.800-3.200 de vida contra mortos de 260-420 e limpavam os postos sozinhos. Checks `_check_assault_routes`
        (nenhum trecho de rota passa por sólido) e `_check_assault_march` (a leva dos Ossos chega ao pátio).
  - **Cidadela do Lich** (30, selo NE do Bastião, abre com as três): a Ofensiva da Aurora sobe junto, elites das três fortalezas, e Azhar, o Lich-Rei (três fases).
    - Layout = **necrópole** (`build_dawn_forts.build_citadel`): uma cidade morta inteira. Muralha externa em ruínas (portão da cidade com
      torreões de chama de almas ao sul + quatro brechas), avenida torta subindo até a praça, duas ruas de volta (oeste/leste) e becos,
      ~80 casas sem teto (prop `ruin`, abertas para a rua; sobrados mais altos), torres de ossos com chama verde, poços de almas (material
      `soulwater`, bloqueiam), cemitério atrás do palácio. Os três portões da subida são a muralha da cidade, o anel do ossuário (muro
      coroado de crânios com três passagens) e o muro do palácio. Na praça: o palácio do Lich com a agulha de almas (36 m, o marco) e o
      trono em degraus com as colunas da arena de antes (mesma colisão). Postos = pracinhas com torre de ossos.
      Check `_check_citadel` (tudo alcançável; a Ofensiva anda a avenida; fechar o meio da avenida ou o portão da cidade ainda chega ao trono).
  - **Fim do Ato I (e do MVP):** depois do Lich, o Comandante dá `dw_epilogue` (De Volta a Aldara): falar com o Ancião Ravi. Com o Lich morto
    (`MapsCatalog.VICTORY_QUEST`), Aldara e o Bastião festejam: festeiros condicionais (`MapsCatalog.FESTIVAL`, `if`), fogos sobre a praça
    (`FestivalFx`, com som) e bots comemorando no chat (`place:victory`, `Balance.BOT_CHAT_VICTORY`). Entregar o epílogo abre a tela
    "Fim do Ato I" (`hud.show_act_end`); o jogo continua depois. Revisar: `-- --autostart=<c> --act_end_shot=<png>`.
  - **Trevas:** Guardião de Ossos/Guarda da Cidadela bloqueiam golpe físico de frente (`MonsterDef.front_guard`); por trás ou com magia passa.
  - **Recompensas:** Prata Consagrada (+1..+5) e Fragmento da Aurora (+6..+9) aprimoram lendários 25+ (`PLUS_DAWN_*`); quests principais e chefes dão Moedas Lendárias.
  - **Calibrado**: tabela na seção Chefes.

    `raid_probe --route` repele os três fronts com a guarnição (2-9 guardas caem por leva).
- Loot: materiais por campo (gel, pele, presa, erva, minério, seda, casca, insígnia, osso, essência, núcleo, escama) + raros.

### Cidades com identidade e mapas vivos (Ato I; GDD `design/gdd/living-towns.md`, P1 2026-11-17)
- **Aldara = Feira do Trigo**: no centro a Mó/Balança do Trigo (pedra de 3,5 m + braço de 3,8 m) e 6 bancas com toldo listrado na borda da praça
  (trigo e azul, raio 8,6 m, de frente para o MEIO: freguês, jogador e o mercador dentro, feirante atrás do balcão; anel livre de ~6 m em volta da mó;
  os 4 eixos das ruas e as 4 diagonais ficam abertos e duas vagas ficam sem banca: a do Cristal de Retorno e a que dá vista para o Ancião e o
  Quadro; praça aberta em 2026-11-18, depois do playtest "tudo muito socado": antes eram 8 bancas a 7,6 m viradas para fora), 2 carroças paradas. O chafariz e a estátua do centro
  saíram; a estátua virou a **Estátua do Fundador** (o Semeador, NPC-placa `founder_statue`) no pátio do portão norte; o Cristal de Retorno
  foi para a borda da feira; o poço foi para o Pátio do Fundador e o ponto de chegada fica na boca da rua sul (0, 10,4), fora da roseta. Quadrantes: **Pátio da Forja do Brom** a NE (o ferreiro atende lá), **Celeiro e cercado** ao S (a oeste do
  portão sul). Mercador Tobias na frente de uma banca. Tudo ≤ 4 m de altura (`tools/blender/zones/town_dress.py`, lotes `Dress`;
  resumo em `town.centerpiece` do JSON; check `_check_town_identity`).
- **Rotinas** (`MapsCatalog.LIVING_NPCS["city_aldara"]`, `VILLAGER_EXTRAS`): Carroça da Colheita (carroceiro + cavalo `cart_draft`: fazenda →
  ponte → portão sul → celeiro, 18 s descarregando, volta; ~3 min a volta), feirantes parados com pregão (Rosa, Zefa, Malaquias, Tico, Dora),
  4 fregueses de banca em banca, Juca leva sacos do celeiro às bancas, galinhas no cercado/fazenda e corvos no trigal (`AMBIENT_LIFE`).
  Rota com `flow` não para nos pontos de passagem; ponto `[x, z, s]` = parada de `s` segundos (`NpcSystem`). Check `_check_living_routes`.
- **Posto dos Caçadores = Fogueira Comunal** (`town_dress.posto`): fogueira de 5 m com o caldeirão da Bia no lugar do poço e da estátua, roda de
  4 carroças de lona dos refugiados (as quatro ruas dos portões passam entre elas; o cristal fica no vão norte), varais de peles a SO e a Trompa
  do Cerco junto ao portão norte (só visual por enquanto). Rotina R8: dois lenhadores com tora (mata do oeste ↔ forja) e um caçador com as peles
  (estrada sul ↔ mercado); corvos e mariposas (`AMBIENT_LIFE`). Ainda sem evento de estrada na Floresta (E2/E4/E5 são P2).
- **Eventos de estrada** (`RoadEventSystem`, `MapsCatalog.ROAD_EVENTS`, pontos `SPAWN_event_*` → `MapDef.road_events`, números `Balance.EVENT_*`):
  só no mapa do jogador, 1 ativo por mapa, o 1º entre 90 e 270 s e depois a cada 4-7 min, num ponto a 35-70 m do jogador (recarga de 10 min
  por ponto), nunca durante investida. **E1 Lobos no Lavrador** (Aldara, 4 pontos: colinas do norte e estrada da fazenda): 2-3 Lobos Famintos
  do nível do spawner mais perto cercam o Lavrador Chico (NPC, não morre); expira em 120 s sem ninguém a 30 m, 90 s para resolver depois que
  alguém chega; os lobos não passam de 30 m do ponto e não dão XP/ouro/saque/quest. Prêmio único para quem contribuiu: XP = 4% do nível,
  5 + 2/nível moedas (dividido) e 2 Poções de Vida (P). Bots de fora do grupo esperam 25 s (`EVENT_BOT_GRACE`) e avisam no chat quando
  resolvem sozinhos. Minimapa: ponto dourado que pulsa. Nada vai para o save. Check `_check_road_events`.
- **Faixa élfica viva** (GDD `design/gdd/elf-band-living.md`, 2026-11-24): Cidade Élfica, fortes, acampamentos do cerco e Posto com rotinas
  (`LIVING_NPCS["elf_city"]`, `elv_*`; Mensageira Aryn para em cada forte). Só a queda do Rei (`el6_king`) muda o mundo: conjunto "guerra"
  (`unless`) troca pelo "trégua" (`if`: luto, emissário humano, presos somem dos fortes e o marido da Dalva aparece no Posto; sino de luto
  `Sfx.PLACE_BELLS` `since`). Alarme do Posto: com leva viva, moradores com `alarm` correm para a Fogueira Comunal e a trompa toca.
  Eventos: **Emboscada na Trilha** (Floresta, salteadores) e **Patrulha com Prisioneiro** (estradas dos fortes, só até o Rei).

## Chefes (mecânicas e calibragem, 2026-11-09)
Todo chefe de grupo tem resposta de longe, invocação e três fases; quem kita não fica de graça.
- **Mira**: `SkillDef.mob_pick` (`far`/`random`/`soft`, `SkillsCatalog.BOSS_PICK`): num chefe a skill escolhe outra vítima e o aggro
  fica no tanque. Golpe TARGET do chefe segue a vítima até o impacto (`MobSystem.follow_victim`, `Balance.BOSS_FOLLOW`); o aviso fica nela.
- **Efeitos**: `barrage` (círculos avisados que caem depois, `m["hazards"]`; bots saem deles) e `pull` (gancho; parede segura).
  Invocar e buff de chefe valem a qualquer distância (`MonsterBrain._skill_reach`).
- **Fases** (`MonsterDef.phases`): `summon` (+`pick`), `skills`, `ward` (corte de dano enquanto um lacaio vive), `enrage`;
  `berserk_after` = s de luta até o dano × `Balance.BOSS_BERSERK_MULT` (corta luta solo longa sem mexer no trio, que acaba em 30-70 s).
- **Gente contra o chefe** (2026-11-10, `MobSystem.crowd_of/crowd_mult`): dano do chefe × `Balance.BOSS_CROWD_MULT[pessoas]`
  (1 · 1 · 1 · 2 · 3,5 · 5 para 0..5). Conta quem o atingiu a até `BOSS_CROWD_RANGE` m e o grupo dessas pessoas (quem só cura conta;
  quem só passa, não); reconta a cada `BOSS_CROWD_CHECK` s e avisa no chat quando passa do máximo da luta; reset tira. Antes um grupo
  completo não ficava abaixo de 35% de vida nem com o chefe a 4×. Medido (8 chefes de grupo × 6): grupo completo de 4 (Guardião,
  Sacerdote, Machados, Fogo) 48/48 com 0,39 morte e 1,7 poção por luta (antes 0 e 0); completo de 5 46/48, 0,83 morte; 4 sorteados
  36/48; trio sorteado 42/48 (antes 45/48); solo igual (30/48). Os números da tabela abaixo são sem reforço (solo e trio).
- **Faixas** (`boss_probe --bands`): campo/elite = solo 60-100%, trio 90-100%; grupo = solo 20-40%, trio 75-100% em 30-150 s,
  4+ skills/min, 35%+ do tempo golpeando, 4+ lacaios, 10%+ do dano fora do alvo, 2+ golpes/min em quem kita a 9,5 m.
  Com 20 lutas o solo oscila ±10 pontos entre rodadas (sorteio muda com a ordem dos chefes): mire no meio da faixa e confirme com 40. Desde o dash com i-frames (os bots desviam pelo dash) o solo subiu ~5-10 pontos; Chefe dos Bandidos (52 mil, fúria 120 s), Golem Ancestral (27 mil, 130 s) e Rei Élfico (55 mil, 110 s) foram reajustados com 40 lutas.
- **Sonda**: o bot da sonda (`StayBrain`) não sai da sala e volta ao chefe que resetou (antes ficava parado a 30 m e a luta contava
  como derrota). `--why` mostra dano por fonte, estado do chefe (`STATES`) e onde cada um estava numa luta que não começou.

| Chefe | Sozinho | Trio | Trio (s) |
|---|---|---|---|
| Chefe dos Bandidos | 28% | 98% | 40 |
| Rainha Aranha | 35% | 100% | 42 |
| Senhor da Cripta | 30% | 100% | 37 |
| Capitão de Ossos | 35% | 100% | 42 |
| Viúva Lamentosa | 40% | 100% | 37 |
| Conde Vargo | 15-30% | 100% | 41 |
| Rei Élfico | 33% | 100% | 50 |
| Golem Ancestral | 40% | 100% | 44 |
| Guardiã de Cristal | 30% | 100% | 40 |
| Coração da Pedreira | 25% | 100% | 66 |
| Sylvara (Caçadora) | 40% | 85% | 36 |
| Aerion (Grifos) | 25% | 100% | 40 |
| Ilwen (Seiva) | 20% | 100% | 65 |
| Carniçal Gigante | 30% | 95% | 44 |
| Vorhag | 25% | 95% | 33 |
| Morvath | 20-45% | 100% | 31 |
| Lich-Rei | 30% | 95% | 40 |
| Dragonete Ancestral (opcional; medido com grupo de 4) | 30% | 100% (mortes 0,2) | 60 |

Campo (Caranguejo-Rei, Rei Slime, Presa-Rachada, Rei Javali) e elite (Trent, Guardião Élfico): 95-100% sozinho.

Dragonete Ancestral (2026-11-10, rochedo leste do Bastião, volta em 2 min, quest no 30): 140.000 de vida, ATK/MATK ~1,3x o Lich-Rei;
sopro (cone que queima), varrida de cauda, mergulho de asa no mais longe, rugido que atordoa e, aos 70%, chuva de meteoros + 2 filhotes;
aos 40% fica protegido (ward) enquanto um filhote vive e chama a ninhada; fúria aos 40% e 15%, berserk aos 200 s. Gestos próprios
no modelo (`mob_kit.quad_dragon_gestures`: cast_fire, atk_sweep, atk_charge, shout, cast_ground, summon). Antes: 4.200 de vida e só o bafo.
A sonda agora para as investidas no mapa do chefe (os bots largavam o chefe para defender o portão do Bastião).
**Covil do Dragonete (2026-11-21):** o Dragonete saiu do campo para uma masmorra só dele (`dg_covil_dragao`, boca no rochedo leste do
Bastião, túnel + salão redondo com ninho; volta em 2 min). Ninho de 6 **Ovos de Dragão** (`MonsterDef.eggs`, `MobSystem.ensure_eggs`):
lacaios parados, 1.500 de vida, sem XP; não seguram o escudo da fase. Aos 70% metade dos ovos inteiros choca em filhotes, aos 40% o
resto (`hatch`, `MobSystem.hatch`; no lugar dos 2 filhotes do nada): quebrar ovos antes = menos filhotes. Reset devolve o ninho inteiro.
Sonda (20 lutas): grupo de 4 vence 19/20 (mortes 0,8, 37 s); grupo de 5 13/20 (mortes 2,3: o multiplicador de multidão de 5). Check `_check_dragon_eggs`.

**Ato II, a Horda 30-35** (2026-11-11, `design/gdd/ato2-horda.md` R3/F2/F4): atributos pela fórmula F2 (`Balance.horde_stat`,
`MonsterDef.stat_role` + `unit_mods`; check `_check_horde_stats`). Linhas: Lanceiro Goblin 30 → Empalador 33 (estocada em linha que
atravessa) → Agitador 36; Ginete de Lobo 31 → Saqueador 35 (rede: prende 2 s e, com o dano, derruba do cavalo); Recruta Orc 32; Naga das
Marés 31 → Guerreira Naga 34 (laço que puxa até ela, lança em linha). O estágio de cima nasce com escolta dos de baixo.
**Aura de facção** (`MonsterDef.faction`/`aura` → `Balance.MOB_AURAS`, `AuraSystem.mob_aura`): o Agitador dá +20% ATK, +10% vel. de
ataque e de movimento aos monstros da Horda a 10 m (chefe: +30%, 14 m), renovando pelo id (duas não somam; some 1,3 s depois);
morto, quem está a 12 m fica 8 s desanimado (−15% ATK, −10% movimento). Em monstro, só buff marcado `mob_stat` mexe nos atributos.
Chefes (sonda `boss_probe --party=4 --trials=40`, bots no nível do chefe com equipamento de tier 3; arena provisória nas Ruínas):
| Chefe | 4 sorteados | 4 completo (Guardião, Sacerdote, Machados, Fogo) |
|---|---|---|
| Mãe das Marés (33, campo da Costa) | 72%, 1,4 morte, 40 s | 100%, 0,3 morte, 39 s |
| Agitador-Mor Grukk (36, Grutas) | 75%, 1,6 morte, 57 s | 100%, 0,3 morte, 51 s |

**Ato II, a Horda 35-40: Estepes de Cinza** (2026-11-11, `design/gdd/ato2-horda.md` R3/F2/F3; checks `_check_steppe_horde`, `_check_troll_regen`).
Linhas (todas da facção `horde`, números pela F2): Trollzinho 35 → Troll 38 (bruto, vida ×1,8 = 3283/116/52, pancada que retarda;
lidera 2 Trollzinhos); Arqueiro Orc 35 → Besteiro Orc 38 (à distância, 9-10 m; lidera 2 Arqueiros; virote em linha que atravessa);
Guerreiro Orc 37 (lidera 1 Recruta; talho + grito de guerra). O Agitador 36 e o Saqueador 35 da fase 1 também nascem nas Estepes.
**Regeneração do troll** (`MonsterDef.regen` × `Balance.TROLL_REGEN_PCT` 1,5% da vida máxima por segundo, em luta ou não;
`MobSystem.update_regen`): para enquanto o troll **queima ou está envenenado** e por `TROLL_REGEN_LINGER` 2 s depois do último efeito
(os dois juntos param uma vez só). "Envenenado" = qualquer dano no tempo que não seja sangramento (veneno, maldição, praga); sangramento
sozinho não corta. Tempo efetivo: `Balance.troll_ttk(T)` = T ÷ (1 − r × T): T = 10 s → 11,8 s; T = 33 s → ~66 s; r × T ≥ 1 = não morre.
Regenerando, o troll leva o buff `troll_regen` (brilho verde, `BuffLooks`), que some quando queima. Bots dão peso ×1,6
(`Balance.BOT_REGEN_CUT_SCORE`) à skill de fogo/veneno contra troll regenerando (`BotBrain.cuts_regen`); trocar de alvo para o troll
ainda não existe.
**Chuva de flechas de fogo**: `mob_fire_arrows` (Arqueiro/Besteiro: 2 círculos avisados de 2 m que caem 1,5 s depois e queimam 3 s);
no chefe, `mob_fire_rain` (5 círculos) e `mob_fire_storm` (6 círculos de 2,6 m, fase 2). **Grito de guerra**: efeito novo `rally`
(`MobSystem.rally`): quem grita e os monstros da mesma facção a 9 m ganham +15% ATK e +10% movimento por 8 s (Ghar: 14 m, +20%, 10 s);
renova pelo id `war_cry`, não soma com outro grito (soma com a aura do Agitador, que é outro id).
Chefes dos acampamentos (3 fases, lacaios de 0 XP, ward 0,5 na fase 2, berserk aos 180 s, `BOSS_CROWD_MULT` sem mudança):
Troll Rei-da-Rocha 38 (Toca; regeneração ×0,3; pancada, chuva de pedras, pedregulho no mais longe, abalo que atordoa; Crias da Rocha que
regeneram; fase 2 desabamento), Mestre Besteiro Vorgul 39 (Paliçada; bate de perto e atira de longe: virote, barris, chuva e tempestade de
fogo; Atiradores da Paliçada em quem está longe), Senhor da Guerra Ghar 40 (Arraial; escolta de 2 Guerreiros, brado, investida, talho de
120°, terra rachada na fase 2; Vanguarda de Ghar).
Sonda `boss_probe --party=4 --trials=40` nos mapas dos acampamentos, bots no nível do chefe (38-40, acima do `MAX_LEVEL` 35 de hoje):
| Chefe | 4 sorteados | 4 completo (Guardião, Sacerdote, Carniceiro, Fogo) |
|---|---|---|
| Troll Rei-da-Rocha (38, `fort_trolls`) | 80% (20/25: a rodada de 40 não terminou; a sonda fica lenta a cada luta perdida), ~1 morte, ~55 s | 100%, 0,4 morte, 57 s |
| Mestre Besteiro Vorgul (39, `fort_fire`) | 87%, 0,9 morte, 43 s | 100%, 0,3 morte, 45 s |
| Senhor da Guerra Ghar (40, `fort_war`) | 82%, 1,1 morte, 55 s | 100%, 0,8 morte, 57 s |

**Nova sonda depois da correção do `_danger_escape`** (2026-11-12; bot não foge mais do golpe básico nem de buff do monstro; 40 lutas
por linha com `--seed`, completo = Guardião, Sacerdote, Executor, Fogo; mortes contam quem caiu ou saiu do mapa):
| Chefe | 4 sorteados | 4 completo |
|---|---|---|
| Mãe das Marés | 65%, 2,2 mortes, 36 s | 100%, 0,17, 36 s |
| Agitador-Mor Grukk | 72%, 1,8, 38 s | 100%, 0,20, 39 s |
| Troll Rei-da-Rocha | 75%, 1,6, 57 s | 100%, 0,35, 56 s |
| Mestre Besteiro Vorgul (ATK 1,25 → 1,1) | 58% → 65%, 2,5 → 2,2, 54 s | 100%, 1,18 → 1,05, 60 s |
| Senhor da Guerra Ghar | 75%, 1,9, 39 s | 100%, 0,30, 40 s |
| Rainha Aranha / Senhor da Cripta / Conde Vargo | 98% / 85% / 79% | 100% (0,00 / 0,70 / 0,47) |
| Rei Élfico / Coração da Pedreira / Lich-Rei | 100% / 82% / 88% | 100% (0,00 / 0,03 / 0,15) |
No Ato II o Fogo tirava o chefe do tanque nos 5 s de abertura em quase toda luta (`PERDAS` do `--why`): era dele a maioria das mortes do
grupo completo (no Besteiro, que bate forte de perto, passava de 1). Rainha Aranha e Rei Élfico ficavam acima de 85% com 4 sorteados
(o contrato do Ato I é solo/trio, tabela acima).

**Monte Kharzun (Ato II fase 3, 40-45; `design/gdd/kharzun-fase3-plan.md` §4, WP7)** — seis chefes em
`MonstersCatalog._kharzun_bosses` (`KHARZUN_BOSSES`, `KHARZUN_BANNERS`, `KHARZUN_MODELS` = modelo pretendido do WP4; hoje
substitutos `mob_*` de chefe que têm os gestos das skills, check `_check_anim_review`). Lacaios são do chefe (0 XP, sem loot). Falas = placeholder (narrative-director).
| Chefe | Onde / nível | F2 / F3 / F4 | Substituto → modelo pretendido |
|---|---|---|---|
| Presa-de-Cinza, a Mãe-Loba (`boss_dire_mother`, **grupo** desde 2026-11-17; era campo) | Canil, 41 (chefe F2 hp ×1,85 (era ×0,6, ver abaixo), atk ×1,1 (era ×0,7), golpe a cada 1,0 s (era 1,2); prêmio do Ghar: 5800 XP, 480-760 ouro, 6-9 moedas) | 70%: uivo + 2 Crias + Três Botes; 40%: ward 0,5 + 2 Crias no frágil; 15%: fúria ×1,3. Berserk 120 s | `mob_boar` cinza (tem os gestos de chefe quadrúpede) → `mob_dire_mother` |
| Mestre Matador Shazka (`boss_shazka`) | `dg_slayers`, 43 | 70%: some (furtividade 1,5 s), Passo nas Costas no frágil, 2 Sombras-Aprendizes no frágil, ward 0,5; 35%: Nuvens de Veneno + Golpe de Misericórdia (frágil); 15%: fúria | `mob_agitator_lord` → `mob_shazka` |
| Ulgra Presa-Atroz (`boss_ulgra`) | cidadela W, 44 | 70%: Ginetes; 40%: ward 0,5 + Ginetes no mais longe; 15%: Chuva de Lanças + fúria. Investida 9 m, Corrente de Caça (puxa o mais longe) | `mob_ghar` → `mob_ulgra` |
| Gorbash Pele-de-Rocha (`boss_gorbash`) | cidadela E, 44 (regen ×0,3) | 70%: 2 Xamãs-Pedra que CURAM o chefe (`mob_stone_mend`), ward 0,5; 40%: abalo que atordoa + desabamento; 15%: fúria | `mob_troll_king` → `mob_gorbash` |
| Kragmar Martelo-Negro (`boss_kragmar`) | cidadela N-NE, 44 | 70%: Golens de Forja; 40%: ward 0,4; 15%: fúria ×1,35. Ondas de Lava (6 círculos), berserk aos 150 s | `mob_crossbow_master` → `mob_kragmar` |
| Durgash, o Grão-Senhor da Guerra (`boss_durgash`) | trono, 45, **raide de 5** (hp ×3,0, atk ×1,5) | 100%: Machado do Trono (assinatura, juntar para dividir); 70%: finca 3 Estandartes de Clã (três fases no mesmo limiar; ward 0,6 enquanto um vive; Lobo = aura `clan_wolf` +25% movimento/+20% vel. de ataque na Horda, Pedra = cura o chefe, Forja = brasas em volta); 40%: Corrente, Terra Rachada, Guarda do Trono a cada 30 s, ward 0,3; 15%: fúria ×1,35; berserk 240 s | `mob_ghar` → `mob_durgash`; estandartes = cone → `mob_clan_banner_*` |
Estandarte: vida ~4% da do Durgash, parado (velocidade 0, não golpeia). Check `_check_kharzun_bosses` (fases em ordem, falas, lacaios
0 XP, os 3 estandartes, ward 0,6 com um vivo e 0 com os três caídos na sim).
Sonda em **ARENA PROVISÓRIA** (`boss_probe.ARENA_AT`: forte do Ghar, no lugar dele) com bots no nível do chefe (41-45, acima do
`MAX_LEVEL` 40 desta base; equipamento até 40) — **refazer no mapa final e depois do teto 45 (WP1)**. 20 lutas por linha:
| Chefe | Alvo | Completo (Guardião, Sacerdote, Executor, Fogo [+ Bispo Batalha]) | Sorteados | Notas |
|---|---|---|---|---|
| Presa-de-Cinza (campo até 2026-11-16, `--bands`) | solo 60-100%, trio 90-100% | — | solo 18/20 (90%, 50 s), trio 20/20 (13 s), kite 6/6 | BAND OK |
| Presa-de-Cinza, hp ×0,6 → ×1,85 (2026-11-16, arena do Canil, 40 lutas) | campo + grupo `--asc` de 4-5 perto dos pares da faixa 40 (Troll Rei/Vorgul/Ghar 30-50 s) | `--asc` 4: 40/40 → 39/40, 10,3 → 28,4 s, 0,0 → 0,1 morte · 5: 40/40 → 38/40, 10,6 → 25,3 s, 0,0 → 0,3 | `--bands`: solo 20/20 68 s → 28/40 (70%) 156 s, trio 20/20 13 s → 37/40 46 s, kite 0/13 | BAND OK. Com ×0,6 caía antes de usar o kit (Três Botes 0,1 uso/luta). ×2,0 dava grupo 32/29 s mas solo 57% (fora do campo): ~28 s é o teto de um chefe que dá para solar. Check `_check_kharzun_bosses` (vida 0,9-1,3× a do Ghar) |
| Shazka (hp ×1,8, atk ×0,95) | completo ≥ 95%, 4 sorteados 65-85% | 20/20, 1,1 morte, 58 s (números anteriores, mais fortes) | 30/40 (75%), 1,8 morte, 43 s | |
| Ulgra (hp ×1,85, atk ×1,3; ×1,15 com a assinatura, ver Assinaturas) | idem | 20/20, 0,7 morte, 51 s (atk 1,4) | 28/40 (70%), 2,0, 45 s | |
| Gorbash (hp ×1,85, atk ×1,3; Xamã matk 50) | idem | 20/20, 0,2 morte, 60 s (atk 1,6) | 26/40 (65%), 1,8, 51 s | no piso |
| Kragmar (hp ×1,7, atk ×1,25) | idem | 20/20, 0,1 morte, 38 s (atk 1,45) | 27/40 (68%), 1,6, 38 s | |
| Durgash (hp ×3,0, atk ×1,0, berserk 120 s) | 5 completo ≥ 90%, 0,5-1,5 morte, 90-150 s; 5 sorteados 60-80%; 4 completo ≤ 85% | 5: 20/20, 1,4 morte, 88 s · **4: 20/20, 0,9 morte, 108 s (ALARME)** | 5 sorteados: 6/20 (30%), 4,1 mortes | **FORA**: ver abaixo |
Durgash fora do alvo em duas linhas, e o ATK não as resolve (atk 1,5 → 1,0: o 5 completo foi de 1,8 para 1,4 morte, o 4 completo continuou
20/20 e os 5 sorteados ficaram em 20-30%). O grupo de 4 com tanque e cura sobrevive ao berserk ×1,6 (`BOSS_BERSERK_MULT`, igual para
todos os chefes); um corte de DPS de verdade pede regra nova (ex.: berserk por chefe mais forte, ou um limite de tempo), decisão do autor.
Os 5 sorteados perdem por falta de tanque/cura contra o reforço ×5,0 de 5 pessoas e pelos estandartes que os bots ainda não miram (WP8).

**Kharzun no mapa final + IA de raide (WP8, 2026-11-13)**. A sonda agora luta na arena de verdade de cada chefe (`boss_probe.BOSSES`:
Canil no Monte Kharzun, `dg_slayers`, cidadela) e imprime `WARD` (lutas com ward, tempo até o 1º lacaio cair, quantas em 30 s).
IA de raide (`BotBrain`, números `Balance.BOT_*`, check `_check_bot_raid`): com ward ligado, quem não tanca nem cura vai no lacaio de ward
(estandarte primeiro, depois o mais perto, a até `BOT_WARD_RANGE` m: `_ward_add`); o tanque provoca de novo quando um chefe de golpe curto
em quem é frágil (Shazka: Misericórdia, Passo nas Costas) está em cima de quem cura (`soft_in_danger`), e quem cura sai do alcance dele
(`_evade_boss`, `BOT_HEALER_EVADE`); a frente do chefe é o cone mais largo dele (`front_arc`: talho de 150° do Durgash + `BOT_FRONT_ARC_PAD`),
cada membro ganha uma vaga própria em volta (`_slot`, `BOT_RANGED_SPREAD_STEP`) e o tanque vira o chefe de costas para o grupo quando
`BOT_TANK_TURN_MIN`+ estão na frente (`_turn_spot`).
**Durgash, raide de 5**: vida `unit_mods.hp` ×4,3 (era ×3,0: o grupo cheio leva ~100 s, decisão do autor 2026-11-13) e berserk próprio
(`MonsterDef.berserk_mult`; 0 = `Balance.BOSS_BERSERK_MULT`) aos **128 s, dano ×20** (o grupo cai
em 5-20 s) e reforço próprio de raide (`Balance.BOSS_CROWD_RAID`, no lugar de `BOSS_CROWD_MULT`; solo/dupla/trio iguais ao comum):
**×4,9 com 4, ×3,25 com 5** (tabela de raide aprovada pelo autor em 2026-11-13). Só o berserk não separava o 4 do 5 (o 4 leva ~16 s a mais, desvio de 10-13 s por luta: com berserk ×8-20
aos 80-95 s o 4 completo ficava em 35-90% e o 5 completo caía junto); com o reforço por tamanho, o grupo de 4 sofre mais e não chega ao
berserk. Varredura (20 lutas): ×1,6/120 s → 4 completo 20/20; ×20/85 s → 10/20; ×20/80 s → 7/20; reforço 4,9/4,2 → 5 sorteados 18/40;
3,5 → 23/40; 3,0 → 32/40; 3,25 escolhido (com vida ×3,0 e berserk 90 s: completo de 5 40/40 em 70 s, 5 sorteados 31/40,
completo de 4 6/40). Depois a vida subiu ×1,43 e o berserk foi junto (90 → 128 s) para a luta do grupo cheio ficar em ~100 s.
Os estandartes ficaram em 21.300 de vida (~2,8% do Durgash, era ~4%): com vida ×1,43 também neles (30.500) os 5 sorteados caíam
para 20/40 (e 21/40 com reforço 2,9 com 5).
Sonda, 20 lutas por linha (Durgash 40), bots no nível do chefe (Durgash `--lvl=45`); completo = Guardião, Sacerdote, Executor, Fogo, Bispo Batalha:
| Chefe | Completo de 5 | 5 sorteados | Completo de 4 |
|---|---|---|---|
| Presa-de-Cinza (campo, 41) | 20/20, 0,0 morte, 19 s | 20/20, 0,1, 12 s | — (campo: contrato solo/trio, BAND OK) |
| Mestre Matador Shazka (43) | 20/20, 0,4, 40 s | 15/20 (75%), 2,2, 29 s | — |
| Ulgra Presa-Atroz (44) | 20/20, 1,1, 48 s | 13/20 (65%), 2,8, 35 s | — |
| Gorbash Pele-de-Rocha (44) | 20/20, 0,0, 39 s | 15/20 (75%), 1,4, 28 s | — |
| Kragmar Martelo-Negro (44) | 20/20, 0,2, 32 s | 14/20 (70%), 1,8, 23 s | — |
| **Durgash (45, raide)** | **40/40, 0,8, 95 s** | **26/40 (65%), 2,8, 72 s** | **7/40 (18%), 3,5, 121 s** |
Fora do que se esperava: os quatro chefes da cidadela com 5 sorteados ficam em 65-75% (o alvo de 65-85% era para 4 sorteados; não medido com 4 nesta rodada).

**Tanque proativo** (2026-11-19, `BotBrain._tank_pull`, `Balance.BOT_TANK_PULL_*`/`PARTY_BIG_ASSIST_RANGE`; check `_check_tank_pull`): o tanque
seguidor não espera o líder chegar perto: com o líder a pé e fora da vila, abre no chefe a até `BOT_TANK_PULL_BOSS` 20 m do líder (elite: só a
`BOT_TANK_PULL_ELITE` 12 m) com caminho livre, que não briga com outro grupo, se tiver `BOT_TANK_PULL_HP` 60%+ de vida. O resto do grupo ajuda no
chefe/elite preso em alguém do grupo (ou em que o líder bateu de longe) a até `PARTY_BIG_ASSIST_RANGE` 22 m do líder (antes 14 m).

**Abertura do grupo** (2026-11-12, `BotBrain._opener`, `Balance.BOT_OPENER_*`; check `_check_bot_opener`; A/B com `boss_probe --no_opener`):
com tanque no grupo, quem não é o tanque não usa skill de dano no chefe/elite (nem área num lacaio a `BOT_OPENER_AOE_RANGE` 6 m dele)
até o chefe ficar `BOT_OPENER_TIME` 3 s preso no tanque com ameaça dele; até lá só o básico (e buff em si: forma, Sede de Sangue), e só
abaixo de `BOT_OPENER_RATIO` 0,5 × a ameaça do tanque. Tanque que não pega em `BOT_OPENER_WAIT` 6 s: luta normal. O tanque NÃO abre com a
provocação (1ª versão abria: com 12 s de recarga ela faltava quando o dps estourava logo depois, e o Executor passou a tirar o chefe).
Ato II, 5 chefes × 20 lutas (sem → com):
| Grupo | Vitórias | Mortes/luta | Perdas na abertura (5 s) | Perdas no total | Tempo médio |
|---|---|---|---|---|---|
| 4 completo (Guardião, Sacerdote, Executor, Fogo) | 99 → 99/100 | 0,34 → 0,54 | 97 → 14 | 121 → 59 | 44,6 → 51,2 s |
| 4 sorteados | 57 → 68/100 | 2,28 → 1,94 | — | — | 46,9 → 49,5 s (vitórias) |
O grupo completo já vencia tudo: as mortes a mais ficam no ruído de 20 lutas (0,1-0,4 por chefe) e a luta fica ~6 s mais longa (o grupo
espera o tanque pegar o chefe). Onde o grupo perde (sorteado), vence 11 pontos a mais.

**Ameaça prevista** (2026-11-12, `BotBrain._threat_budget/_skill_threat/_pending_threat`, `Balance.BOT_THREAT_PREDICT` 1,2; check
`_check_bot_threat_budget`; `boss_probe --why` imprime `PERDAS_COMO`: com o quê cada membro tirou o chefe do tanque). Depois da abertura as
perdas vinham de UM golpe grande saindo abaixo de `BOT_THREAT_HOLD` (Meteoro 13, Executar 5, Tempestade de Brasas, Redemoinho; ameaça
antes do golpe 0,6-0,8 da do tanque) e de queimadura caindo depois de o Fogo parar. Agora, com o chefe preso no tanque, a skill cuja
ameaça estimada (golpe com crítico médio + dano no tempo, × `BOT_THREAT_PREDICT`) passaria `BOT_THREAT_HOLD` × a do tanque espera (as
menores seguem), o básico que passaria `BOT_THREAT_STOP` também, e o dano no tempo que ainda vai cair conta como ameaça já feita (também
na abertura). Área num lacaio a 6 m do chefe preso usa o orçamento do chefe. `BOT_THREAT_PREDICT` 0 desliga.
Grupo completo, 5 chefes × 20 lutas (mesma semente):
| Versão | Perdas no total | Vitórias | Mortes/luta | Tempo médio |
|---|---|---|---|---|
| sem abertura (master) | 121 | 99/100 | 0,34 | 44,6 s |
| abertura | 51-59 (2 rodadas) | 99/100 | 0,46-0,54 | 51,2 s |
| + skill prevista | 30 | 100/100 | 0,42 | 51,4 s |
| + básico previsto (final) | 16 | 100/100 | 0,44 | 50,6 s |
As 16 que sobram são quase todas o básico do Executor na abertura do Besteiro (crítico acima da média estimada).

**Sonda com o código final** (2026-11-12, 40 lutas por linha = semente padrão + `--seed=7`; completo = Guardião, Sacerdote, Executor, Fogo;
mortes contam quem caiu ou saiu do mapa). Substitui a tabela "Nova sonda" acima:
| Chefe | 4 sorteados | 4 completo |
|---|---|---|
| Mãe das Marés | 67,5%, 2,2 mortes, 37 s | 100%, 0,35, 38 s |
| Agitador-Mor Grukk | 70%, 2,0, 40 s | 100%, 0,15, 46 s |
| Troll Rei-da-Rocha | 70%, 1,65, 70 s | 100%, 0,25, 61 s |
| Mestre Besteiro Vorgul | 75%, 2,0, 52 s | 100%, 0,95, 63 s |
| Senhor da Guerra Ghar | 72,5%, 2,0, 45 s | 97,5%, 0,5, 48 s |
| Rainha Aranha / Senhor da Cripta / Conde Vargo | 80% / 80% / 85% | — |
| Rei Élfico / Coração da Pedreira / Lich-Rei | 52,5% (× 1,5) → 80% (× 1,3, sozinho na sonda) / 90% / 87,5% | — |
O sorteio da sonda reveza as classes pela ordem dos chefes: o Rei Élfico deu 75% (× 1,5) rodando só com a Rainha e 52,5% no meio dos 6
chefes do Ato I (outros grupos). Com × 1,3: 80% rodando sozinho; a média esperada entre os dois sorteios fica ~65-75%.

**Reforço extra por chefe** (`Balance.BOSS_CROWD_EXTRA`, a partir de `BOSS_CROWD_EXTRA_FROM` 4 pessoas; `MobSystem.crowd_mult(n, id)`;
solo e trio não mudam): Rainha Aranha × 1,8 e Rei Élfico × 1,3 por cima do `BOSS_CROWD_MULT` (4 sorteados):
| Chefe | 4 sorteados antes | × 1,3 (20) | × 1,6 (40) | × 1,8 / × 1,5 (40) | Final |
|---|---|---|---|---|---|
| Rainha Aranha | 95-98% | 90% | 82,5% | 82,5% | × 1,8: 80-82,5%, 1,5 morte, 27 s |
| Rei Élfico | 95-100% | 85% | 67,5% | 75% (52,5% no meio do Ato I) | × 1,3: 80%, 1,5 morte, 38 s |
Solo e trio com o código da abertura (20 lutas): Rainha 35% / 90%, Rei Élfico 45% / 100% (no ruído da tabela do Ato I).

**Sorteio justo da sonda** (2026-11-12, `boss_probe.random_comp/fight_seed`; check `_check_probe_sampler`): antes as classes
se revezavam por luta e a build e a luta saíam do rng da sim, que vinha das lutas dos chefes anteriores (o mesmo chefe dava
75% numa lista e 52,5% noutra). Agora cada luta sorteia 4 classes distintas + build e ressemeia a sim só por (chefe, luta,
semente): o mesmo chefe dá o mesmo grupo sozinho ou numa lista (`--show_comp` imprime).
Baralho (2026-11-12): o sorteio livre deixava a cobertura torta por chefe (numa rodada de 40 lutas uma classe saía 6 vezes e
outra 13). Agora as classes saem de baralhos embaralhados por (chefe, baralho, semente), `party` cartas por luta (carta repetida
na virada troca com uma adiante do mesmo baralho), e a build de cada classe de um baralho das builds dela: em qualquer prefixo
de lutas cada classe aparece por igual ±1 e cada build da classe na sua vez ±1 (check `_check_probe_sampler`). `--rotation`
roda o rodízio antigo das classes (A/B) e `--comp_stats` só imprime a cobertura (sem lutar). São 8 classes; tanque = Guardião ou
Guardião Verde, cura = Sacerdote. Nos 11 chefes abaixo × 2 sementes × 20 lutas (440 grupos):
| Sorteio | Vezes por classe (mín-máx) | Com tanque | Com cura | Com os dois |
|---|---|---|---|---|
| rodízio antigo | 176-264 (o Paladino mais, o Ranger menos) | 32,3% | 17,7% | 5,0% |
| livre (anterior) | 207-232 | 29,1% | 17,0% | 4,3% |
| baralho (atual) | 220-220 | 30,0% | 17,0% | 3,9% |
A média de tanque/cura é a mesma nos três (só a forma de distribuir muda): a queda da tabela anterior não veio da composição.
4 sorteados, 40 lutas por chefe (semente padrão + `--seed=7`), baralho, com o dash da abertura corrigido (abaixo):
| Chefe | 4 sorteados (baralho) | antes (livre) | rodízio antigo, mesmo código | Mortes/luta | Tempo médio |
|---|---|---|---|---|---|
| Rainha Aranha | 85% | 60% | — | 1,35 | 30 s |
| Senhor da Cripta | 75% | 67,5% | — | 1,65 | 31 s |
| Conde Vargo | 70% | 82,5% | — | 1,55 | 25 s |
| Rei Élfico | 72,5% | 70% | — | 1,75 | 35 s |
| Coração da Pedreira | 70% (ATK/MATK 50 → 66; era 90%) | 77,5% | — | 1,8 | 46 s |
| Lich-Rei | 85% | 87,5% | — | 1,1 | 39 s |
| Mãe das Marés | **60%** | 60% | 72,5% | 2,2 | 37 s |
| Agitador-Mor Grukk | 77,5% | 67,5% | 62,5% | 1,65 | 37 s |
| Troll Rei-da-Rocha | **52,5%** | 52,5% | 70% | 2,1 | 54 s |
| Mestre Besteiro Vorgul | 75% | 47,5% | 72,5% | 1,95 | 52 s |
| Senhor da Guerra Ghar | 70% | 42,5% | 52,5% | 2,05 | 36 s |
Em negrito: fora de 65-85% no baralho (não reajustado). Com 40 lutas o erro é ±7 pontos (1 desvio) e o rodízio, no mesmo
código, vai para os dois lados (Marés +12,5, Troll +17,5, Ghar −17,5, Agitador −15): somados os 5 do Ato II, baralho 66,5% e
rodízio 66%. A diferença de sorteio é ruído; o Ato II fica no piso da faixa com 4 sorteados (Marés e Troll abaixo), a Pedreira
acima (reajustada em 2026-11-13: ATK/MATK 50 → 66 deu 70% em 40 lutas; 60 deu 77,5%). Vorgul e Ghar no sorteio livre estavam no azar das 40 lutas (e o Vorgul ainda tinha o dash da abertura).

**Básico previsto com crítico e assinatura** (2026-11-12, `BotBrain._skill_threat(..., crit_hit)`, `BotBrain._signature_threat`,
`Balance.BOT_THREAT_CRIT_CHANCE` 5%; checks em `_check_bot_threat_budget`): o básico (abertura e `BOT_THREAT_STOP`) conta o
golpe crítico no teto da variação e a magia-assinatura que ele pode lançar junto (Golpe Avassalador do Executor: 17% no 39,
fora da recarga dela), não a média; toda estimativa leva também o talento ferido/execução e as marcas no alvo.
Mestre Besteiro, grupo completo (Guardião, Sacerdote, Executor, Fogo), 20 lutas × 2 sementes:
| Versão | Vitórias | Perdas (abertura, Executor no básico) | Perdas no total | Mortes/luta | Tempo médio |
|---|---|---|---|---|---|
| antes | 40/40 | 8 (5) | 9 | 0,8 | 61,9 s |
| só crítico | 40/40 | 11 (7) | 15 | 0,85 | 63,5 s |
| crítico + assinatura (final) | 40/40 | 5 (5) | 5 | 0,9 | 62,3 s |
O que sobra (`--why`, linha `PERDA`: t, ameaça antes, golpe ÷ tanque, crítico, assinatura, alvo do bot): o Executor bate no
Arqueiro Orc da escolta colado no Besteiro a ~0,9 s, com o tanque ainda sem ameaça, e o cone pega o chefe — mesmo com a abertura
ativa. Procurar o chefe a 6 m do próprio bot (além do alvo) não mudou (5 perdas, +3 s) e foi desfeito.
Causa (2026-11-12, `--why` agora mostra o último lance do membro, "decisao"): não era o básico, era o **dash da fuga**. O
Arqueiro marca área, o Executor sai dela com dash (`BotBrain._danger_escape`) e o Avanço Brutal (`ber_t_crash`) fere em volta
da chegada, colada no Besteiro; a abertura só olhava básico e skills. Agora dash que fere (`BotBrain._dash_hits`: evolução com
`power`) não sai na fuga durante a abertura (sai andando) nem para encostar quando o básico está seguro (check em `_check_bot_opener`).
| Versão | s1337 | s7 | Perdas na abertura (Executor) | Perdas no total | Tempo médio |
|---|---|---|---|---|---|
| antes | 20/20, 64,7 s | 20/20, 59,9 s | 5 | 5 | 62,3 s |
| dash da fuga segurado | 20/20, 62,7 s | 20/20, 61,7 s | 1 (dash: Arqueiro a 6,1 m, fora dos 6 m) | 6 | 62,2 s |
O total oscila: 3 das perdas novas são skills do Executor depois da abertura (t 4,5-5,9 s), luta que divergiu.

**Casulo de Seda** (Rainha Aranha com 4+, 2026-11-12; GDD `design/gdd/spider-queen-4p.md`): o × 1,8 parou de responder porque o reforço
segue quem está vivo: na 1ª morte o grupo vira trio (× 6,3 → × 2) e o trio termina a luta. Mecânica nova que vale pelo PICO da luta
(`MonsterDef.crowd_skills`/`crowd_say`, `MobSystem._crowd_skills`; entra quando `crowd_peak` chega a `BOSS_CROWD_EXTRA_FROM` e só sai no
reset): `mob_cocoon` (alvo, `mob_pick` "soft", recarga 13 s) prende um frágil num casulo (`web_cocoon`, 2200 de vida, lacaio da Rainha:
conta para o `ward`) até ele cair; esgotados `Balance.COCOON_TIME` 7 s, aperta `COCOON_BURST` 0,45 da vida máxima (efeito `cocoon`,
`MobSystem.cocoon/cocoon_tick`). Bots que não são tanque nem curandeiro quebram o casulo de um aliado a até `BOT_COCOON_RANGE` 16 m
(`MobSystem.cocoon_of`). Check `_check_boss_crowd_cocoon`. Sonda (× 1,8 mantido):
| Rainha Aranha | 4 sorteados (40) | Solo (20) | Trio (20) | 4 completo (20) |
|---|---|---|---|---|
| antes | 80% (15/20 + 17/20), 1,5 morte, 27 s | 35% | 100% | — |
| com Casulo | 77,5% (17/20 + 14/20), 1,85 morte, 38 s | 35% (casulo nunca entra) | 100% | 100%, 0,9 morte (o Fogo é quem vai para o casulo), 50 s |

Monstros comuns (`band_probe --from=35 --to=40 --only=duel --trials=12 --seed=N`, 6 sementes): antes os 35+ eram "triviais" (o bot
matava em ~1,5 s com 0-0,1 golpe levado por monstro): o bot fugia do golpe BÁSICO e do grito do monstro como se fossem telegrafia
(`BotBrain._danger_escape`, corrigido: só foge de skill de verdade) e o bruto abria com a skill lenta. Ajuste de 2026-11-12
(`Balance.HORDE_LATE_35`, ATK sem mudar): brutos 35+ vida ×1,3, preparação ×0,5 e intervalo ×0,75 do básico; comuns 35+ preparação
×0,75 e intervalo ×0,85; os dois só usam skill especial 2 s depois de entrar na briga (`MonsterDef.skill_delay`). Resultado: vida
perdida 16% (30-34: 17%), tempo por abate 1,69 s (30-34: 1,60 s), 6 de 7 não triviais (o Saqueador segue leve, 5%). `--trace` mostra
o estado do monstro a cada mudança e `--late_<papel>=hp:..,startup:..,cooldown:..,skill_delay:..` experimenta o fator sem mexer no Balance. Investidas das Estepes (`raid_probe --map=field_steppe --route=0|1|2 --level=37`): `presos` 0
nos três lados; 3 bots repelem 100%; só as sentinelas perdem os lados 0 e 1 (a calibrar com as missões).
Investidas de Porto Esperança (`raid_probe --map=city_port --level=32 --raid_level=32`, 40 levas): depois da correção de IA e dos 35+
a guarnição sozinha caiu para 28/40 (C0) e 29/40 (C1); `Balance.PORT_GUARD_POWER` 1,2 (vida e ataque da guarnição e dos besteiros do
muro, como o `STEPPE_GUARD_POWER`): C0 35/40, C1 38/40, 1 bot 40/40 nos dois, 3 bots 40/40, presos 0 (1,15 dava 27/40 e 35/40; 1,25, 36 e 39).
**Cerco Vivo de Porto Esperança** (2026-11-17, GDD `design/gdd/act2-siege-life.md` P1, `SiegeSystem`; substitui o cerco/muralha de 240 s acima).
A paliçada tem três trechos em obra, cada um fechado por uma missão (ou por `hx_palisade`, que fecha o que faltar): Vão da Garganta
(`hx_stakes`), Trecho do Farolete (`hx_df_logs`, opcional: 6 Toras de Estaca do estaleiro) e Vão do Portão Norte (`hx_df_tower`, opcional,
tipo novo `DEFEND`: 2 levas repelidas com o jogador na defesa; ergue a torre de vigia). Trecho aberto = a Horda entra por ele (rota
`cerco_<id>`); fechado = colide, ganha 2 besteiros e a leva daquele lado vai ao portão norte. Um relógio por mapa solta **uma leva por vez**,
revezando os lados, a cada 90 s ±20% (cadência "Intenso", decisão do usuário), com 30 s de calmaria depois de uma repelida; entre as levas,
**assédio**: 2 Arqueiros Orcs aparecem na crista nordeste e 8 s depois cai uma salva de 3 círculos avisados (12% da vida cada, não esquivável,
no máximo 2 por alvo, nunca mata quem tinha 30%+; só jogador e bots; nunca perto de cristal, chegada, portal ou NPC de serviço); matar o
arqueiro antes cancela os círculos dele. **Batedores** (2 rondas de 2 ginetes, estrada da Costa e trilha da garganta) em luta há 6 s tocam a
trompa e adiantam a próxima leva em 20 s (até 2 por leva). **Leva** (retune do playtest de 2026-11-17, "os invasores eram fracos e a guarda limpava fácil"): 3 Ginetes de Lobo, 2 Lanceiros Goblin,
1 Arqueiro Orc (atira de trás) e 1 Saqueador Goblin de líder (rede e bote); a leva grande soma 2 Empaladores. Invasores do porto com vida e
ataque × 1,2 (`RAID_MAP_POWER["city_port"]`, sobre `RAID_POWER` e os passos de nível). **Pressão**: 2 na chegada (leva de 7, a grande a cada 3ª), 3 com `hx_banners`
(levas × 1,2, mais rápidas, grande a cada 2ª), 1 depois de `hx_riders_camp` (só a patrulha, ~10 min), 0 com `hx_warlord`. Repelir uma leva
estando no raio do Bastião do alvo dá **Colônia de Pé** (+10% de XP de abate no porto por 180 s, renova); leva que chega e não é repelida deixa
o porto em **Chamas** (fogo nas 3 casas queimadas, só visual) até a próxima repelida — nada se perde. Cenário: 3 casas queimadas (reerguidas
com andaime em `hx_palisade`), refugiados do Gaivota junto ao portão sul (até `hx_riders_camp`; dois viram moradores), enfermaria da Curandeira
Salete (vende poções) com feridos, fumaça no horizonte nordeste. Guarnição: 5 no portão norte + **reserva de 3** na praça; os lanceiros e o cavaleiro do portão e a reserva (6) correm para a brecha atacada, os
2 besteiros ficam no portão. `PORT_GUARD_POWER` 1,4 (vida e ataque) e `PORT_GUARD_HP` 1,8 (vida a mais só: a guarnição aguenta sem matar depressa,
então a luta dura e a ajuda pesa). Medido por rota, 20 levas, força da leva no nível 32 (`raid_probe --map=city_port --side=<lado> --bots=0,1,3
--level=32 --raid_level=32`), só a guarnição: Vão da Garganta 19/20 repelidas, luta mediana 50 s (leva inteira 77 s), 2,0 sentinelas mortas, 3,5 de
7,6 invasores dentro da brecha; Trecho do Farolete 19/20, 55 s (101 s), 1,1 mortas, 5,7 dentro; Vão do Portão Norte 20/20, 49 s (83 s), 1,7 mortas,
4,8 dentro; portão (C1) 20/20, 34 s (80 s), 2,8 mortas, 1,5 de 8,6 no portão; presos 0. Com 1 bot de nível 32 na brecha: 20/20, leva inteira 38-42 s,
0,4-1,1 invasores dentro; com 3 bots: 30 s, nenhum chega. Relógio de verdade, 30 min, 0 bots, jogador parado no cais (`--siege_run=1800`): C0 92%,
92% e 83% repelidas (3 sementes; 1 Chamas por meia hora), uma leva a cada ~135 s e um evento (leva ou assédio) a cada ~70 s; com a guarnição
sozinha a leva dura mais que os 90 s do relógio, com o jogador ajudando o ritmo volta a ~90 s. (`lifetime` da leva 200 s: com 110 s a leva recuava
antes de a guarnição terminar e a taxa caía a 42-85%.)
**Ajuste final do mesmo dia** (os ~9 bots do porto matavam a leva na garganta em ~27 s; um bot sozinho cortava a luta pela metade): invasores do porto
com vida × 1,4 a mais (`RAID_MAP_HP["city_port"]`, só vida) e no máximo `SIEGE_BOT_DEFENDERS` (1) bot avulso larga o que faz para defender cada leva (bots do
grupo do jogador vão sempre). Números finais, 12 levas por rota, só a guarnição: 12/12 em todas; luta mediana 67 s (Garganta), 80 s (Farolete), 73 s (Portão
Norte), 59 s (portão, C1); leva inteira 100-124 s; 2,3-3,9 sentinelas mortas por leva; 2,4-5,7 dos ~7,7 invasores dentro do alvo. Com 1 bot na brecha: leva
inteira 40-47 s; com 3: 39 s. Relógio de 30 min: 0 bots 11/11 repelidas (leva a cada ~165 s, evento a cada ~78 s); 6 bots soltos na praça 14/14 (leva a cada
~120 s). Os números do parágrafo acima são de antes deste ajuste.
**Cais** (playtest 2026-11-17): o portal do navio saiu da cabeceira do cais oeste (ficava na frente da Pescadora Iara) para a "prancha do
navio" em (-15, 58); a estrada do cais acaba no largo; os dois cais ganharam uma corrente "só tripulação" na linha da água (o tabuleiro é só
visual: ali a sim já não deixava passar). Check novo: nenhum NPC de quest a menos de 6 m de portal que não é porta, em todos os mapas.
Investidas de Kharzun (`raid_probe --map=field_kharzun --level=42 --raid_level=42`): o elenco 40+ mais forte (rodada de balanço de 2026-11-13)
derrubou a guarnição sozinha de 9/10 para 36/50 repelidas e 1 bot de 10/10 para 24/30. Decisão do usuário (2026-11-13): força só da investida,
`Balance.RAID_MAP_POWER` (vida/ATK/MATK dos invasores × isto, por mapa, em `RaidSystem.scaled_def`; os comuns do campo não mudam; check em
`_check_raid_scaling`). Kharzun 0,85: sem bots 46/50 (92%), 1 bot 30/30, presos 0.
Materiais novos: Couro de Troll, Presa de Troll, Pena de Flecha de Fogo, Aço Negro Orc; dos chefes: Coração de Rocha, Brasa do Mestre
Besteiro, Insígnia de Ghar. Modelos em `mob_kit.horde_parts` (trolls cinza-azulados com pedras incrustadas; orcs de elmo de ferro; Ghar
com chifres e estandarte). Besteiros empunham besta de verdade (`act2_bosses.crossbow`, clipe do mosquete) e os trolls têm corpo próprio (`chibi_kit.BODIES["troll"]`: ombros largos, braços compridos) e postura curvada somada a todos os clipes (`act2_bosses.posture`); os chefes do Ato II ganham peças grandes em `act2_bosses.boss_extras`. Pendente: som próprio do troll (usa a voz orc).

**Cerco do Posto dos Caçadores** (2026-11-24, GDD `design/gdd/elf-siege-posto.md`; substitui a investida única de 240 s da Floresta).
Mesmo `SiegeSystem` do porto, em portões: a leva desce a garganta norte e ataca, revezando, o **Portão Oeste** (flanco das teias; fecha com
`els_steel`), o **portão norte** e o **Portão Leste** (flanco do bosque; fecha com `els_lynx`); portão fechado manda a leva ao norte. Pressão:
1 (patrulha rara) até `el1_alarm`, 2 depois, 3 com `el5_wardens`, **0 com `el6_king`** (paz; os fortes não mudam nada). Leva de 10-12 elfos a cada
~120 s (mesmo total de antes, dividido), nascendo em **escalões** (`Balance.SIEGE_STAGGER`: linces, espadas, arqueiros/magos, grifos, 4 s entre
eles, num arco de 12 m, cada um numa vaga lateral) longe da chegada do portal; assédio de 2 Arqueiros Batedores na crista nordeste (8% da vida
por círculo, `Balance.SIEGE_MAP`); 2 pares de linces batedores com trompa; reserva de 2 sentinelas. Invasores × 1,2 (`RAID_MAP_POWER`). Medido
(nível 16, só a guarnição): norte 20/20, oeste 16/20, leste 7/20; com 1 bot 18-20/20; relógio real 30 min 75/92/90% com 0/1/3 bots;
chegada espalhada (desvio 19-22 s), 13-18 vivos ao mesmo tempo (antes até 36). Rotas no `raids` de `data/zones/field_forest.json` (`build_field_forest.RAIDS`).

**Chefes de mundo do Ato III** (2026-11-23, WP8a; GDD `design/gdd/ato3-excesso-45-50.md` §4, D11) — `MonstersCatalog._act3_field_bosses`
(`ACT3_FIELD_BOSSES`), afinados para TRIO (faixa "grupo" do `boss_probe --bands`), spawner do `world_boss_hint` do JSON com renascimento
`Balance.WORLD_BOSS_RESPAWN_S` (600 s; `MapsCatalog._world_bosses`). Lacaios 0 XP. Saque: Porcelana Chorosa 2-3 + Fitas 4-6 garantidas, elixir, 30% moeda;
moedas lendárias 3-5 (menos que os chefes de grupo: renasce a cada 10 min). Check `_check_act3_field_bosses`.
| Chefe | Onde / nível | F2 | Fases | Assinatura |
|---|---|---|---|---|
| Dona Vindima, a Vinha que Bebe (`boss_vindima`) | `field_perfume`, Poço de Névoa, 47 | chefe hp ×2,0, atk ×1,1, berserk 180 s | 100%: Pisada (cone), Chicote de Vinha (puxa o mais longe), Cachos Maduros (3 círculos); 70%: 2 Vinhas (`vine_sprout`, até 3) + ward 0,4, Brotos a cada 22 s; 35%: Fumo Doce do Poço (3 poças 4 s) + fúria ×1,3 | **Prensa** (28 s): puxa todos a até 14 m (`barrage.pull` → `BossSignatures.pull_in`) e 1,5 s depois esmaga um círculo de 6 m em volta dela (power 2,2). `Balance.ACT3_PRESS_*` |
| A Prima-Donna do Palco (`boss_prima_donna`) | `field_parade`, Palco Grande, 48 | chefe hp ×2,0, atk ×1,1, matk = atk, berserk 180 s | 100%: Leque de Palco (cone), Duas Notas Agudas (círculos em 2 alvos), Fortíssimo (empurra 3 m); 70%: 2 Coristas do Palco (até 3) + ward 0,5, Coro a cada 22 s; 30%: fúria ×1,3 | **Ária em Três Tempos** (26 s): anéis 0-4, 4-8, 8-12 m caem em 1,5 / 2,7 / 3,9 s (R-A ring com stagger, molde das Ondas da Montanha; o `repeat` R-D re-lança a mesma skill e não serve para anéis diferentes) (power 1,4). `Balance.ACT3_ARIA_*` |
Sonda (40 lutas, `--bands`, semente 1337 / trio também `--seed=7`): Vindima solo 25% (132 s), trio 90% em 53 s (0,3 mortes; s7: 85% em 50 s), kite 0/13, BAND OK;
Prima-Donna solo 22,5% (99 s), trio 97,5% em 33 s (0,1 mortes; s7: 97,5% em 30 s), kite 0/13, BAND OK. Prensa acerta ~0,23 personagens por uso no trio; Ária ~0,7 por série.

**Assinaturas dos chefes** (2026-11-13, GDD `design/gdd/act2-boss-signatures.md`; regras em `BossSignatures`, avisos em
`BossSigView`, bots em `BotBrain._sig_spot`, checks `_check_boss_signatures`/`_check_boss_sig_rules`/`_check_boss_sig_bots`).
Cada chefe do Ato II ganha UMA mecânica própria por cima do kit (nada saiu); números globais em `Balance.BOSS_SIG_*`/`BOT_SIG_*`,
os de cada uma no efeito da skill (`SkillDef.boss_signature`). Bots sempre fazem a resposta certa.
| Chefe | Assinatura (desde) | Regra | Resposta |
|---|---|---|---|
| Mãe das Marés | Maré Cheia (100%, 30 s) | `islands`: N = max(2, ⌈grupo/2⌉) ilhas de 2,5 m (uma no tanque); 3 s depois, fora delas a 22 m do chefe = 1,6 + lento | juntar numa ilha (bots: a longe do chefe) |
| Agitador-Mor Grukk | Rufar da Turba (70%, 35 s) | `boss_channel` 4 s; atordoar ou 6% da vida quebra (3 s atordoado, +25% de dano 6 s); completo = Frenesi +40% na turba, cura 30%, +2 Turbas | interromper (todo mundo no chefe, atordoar guardado) |
| Troll Rei-da-Rocha | Avalanche (70%, 30 s) | Chuva de Pedras deixa pedregulho (`MonsterDef.cover`, máx. 3, 40 s; modelo `prop_avalanche_stone`); preparo 2,5 s; onda de 18 m 2,2 + atordoa em quem não tem pedra entre si e ele; a pedra que protegeu racha; sem pedra, ele joga 2 antes | atrás da pedra |
| Mestre Besteiro Vorgul | Marca do Atirador (100%, 18 s) | `mark` spread: 1 (solo) / 2 marcas que seguem a vítima 4 s, explodem 4 m (0,9) e deixam fogo 4 s | espalhar |
| Senhor da Guerra Ghar | Muralha de Escudos (100%, 25 s) | `wall` 6 s: golpe da frente (120°, físico e mágico) perde 90% e soma fúria; no fim, contragolpe em cone 150° = 1,0 + 0,15 × fúria (teto 2,5), que cai `Balance.GHAR_COUNTER_DELAY` 0,375 s depois (quadro 10 do clipe `wall_counter`; durante a muralha ele repete `guard_wall`) | quem ele mira fica de guarda parado; o resto nas costas |
| Presa-de-Cinza (grupo desde 2026-11-17) | Três Botes (70%, 20 s) | `repeat`: 3 investidas re-miradas na mesma vítima (aviso 0,8 s, 0,6 s entre elas); root/stun cortam | sair da faixa |
| Mestre Matador Shazka | Sombras Gêmeas (70%, 24 s) | some na fumaça 1,5 s e volta com 2 cópias (`decoys`, monstro `shazka_decoy` com `MonsterDef.decoy`): mesmo nome, modelo e vida, dano 30% (`Balance.SHAZKA_DECOY_DMG`), 10 s; cópia morre com 1 golpe e solta nuvem de veneno 2 m (0,4 + veneno, fica 4 s); golpe direto no verdadeiro desfaz as cópias; só ele projeta sombra; a cópia é roxo escuro com borda roxa e quase sólida (`EntityView.DECOY_TINT/DECOY_RIM/DECOY_FADE` 0,15; antes 0,35 de transparência lia como bug) | achar o verdadeiro (bots sempre; área mata cópia) |
| Ulgra Presa-Atroz | Estouro da Matilha (70%, 28 s) | `barrage.shape: line`: 3 faixas de 3 m × 30 m na direção dela→tanque (uma no tanque), vãos de 3 m, caem 2,0/2,6/3,2 s: 1,6 + derruba 0,8 s | sair de lado para o vão |
| Gorbash Pele-de-Rocha | Ondas da Montanha (70%, 24 s) | `barrage.shape: ring` com `pulses`: 3 pisadas (1,2 s), cada uma 3 anéis de 2 m (2-4, 7-9, 12-14; a 2ª pisada 2 m para fora, até 16 m) que caem a cada 0,5 s depois de 1,5 s de aviso; 1,1 por anel; o próximo anel fica aceso | entra-sai no ritmo |
| Kragmar Martelo-Negro | Têmpera na Lava (100%, 18 s) | `barrage` com `on_self` + `linger` + `empower`: círculo de 2,4 m embaixo dele (aviso 1,6 s, 1,0) vira poça por 20 s (modelo `prop_kragmar_lavapool`; 0,15/s em quem pisa); dentro dela ele ganha 1 Têmpera a cada 2 s (+8% de dano, máx. 6) e cura 0,5%/s (uma vez, mesmo com poças sobrepostas); fora perde 1 a cada 3 s (`Balance.KRAGMAR_TEMPER_*`) | o tanque arrasta (bots: quem ele mira anda ao ponto livre de poça mais perto a ≥ 4 m, `BOT_SIG_DRAG_DIST`; os outros saem da lava) |
| Durgash (raide de 5) | Machado do Trono (100%, 34 s) | `mark.mode: soak`: círculo de 4 m segue 5 s uma vítima que não é o tanque; 2,0 dividido por quem está dentro (`Balance.DURGASH_AXE_*`; a DEF sai de cada pedaço); `prop_durgash_throneaxe` desce sobre o círculo | juntar no marcado (bots: tanque fica; os 2 mais perto a até 15 m partem na hora certa e voltam ao estandarte; o marcado só para nos últimos 2,5 s; `BotBrain.soak_spot`) |
Durgash usa a marca de dividir (`mark.mode: soak`; check `_check_boss_sig_durgash`). Números finais da assinatura: power 2,0 / 34 s / raio 4,0 m
(`Balance.DURGASH_AXE_*`). `unit_mods` do Durgash ficam hp ×4,3, atk ×1,0: nenhum ATK/HP leva 5 sorteados a 62-65% sem o completo de 4
passar de 20% (varredura logo acima); o usuário aceitou 5 sorteados em 57,5% (2026-11-13). Poça que fica: bots saem para o ponto livre
mais perto (não para outra poça) e o lugar do papel no grupo não cai dentro dela (`BotBrain._free_near`). Uma mecânica de chão por vez: a chuva espera as ilhas caírem. Bots em faixa/anel: fogem do que cai primeiro,
para o lado que fica livre por mais tempo (`BotBrain._side_escape`, folga `BOT_SIG_PAD` 0,3 m, `BOT_SIG_LOOKAHEAD` 1,5 s); cópia do
Shazka: o bot troca o alvo pelo verdadeiro (`BotBrain._decoy_real`). Check `_check_boss_sig_kharzun`; Kragmar `_check_boss_sig_kragmar`.
Rever: `-- --sig_shot=<pasta> [--boss=<id>]` (foto do aviso de cada uma, câmera do jogo); `boss_probe -- --no_sig` = sem assinatura.
Modelos das assinaturas (só apresentação, `BossSigView._sig_model/_prop`: `MapBuilder._prop_model` + peças `glow_*` brilham; somem quando
a regra acaba; feitos em `tools/blender/sig_props_a/b/c.py`): Maré = `prop_tide_island` + `prop_tide_floodring` por ilha; Grukk =
`prop_grukk_wardrum` plantado ao lado dele no canal (`GRUKK_DRUM_GAP`); Troll = `prop_avalanche_stone`; Vorgul = `prop_vorgul_brand`
na vítima (escala pelo raio); Ghar = só `prop_ghar_shieldwall` dos lados (`GHAR_SIDE_SHIELDS`; o escudo da frente é o do braço do
modelo); Shazka = `prop_shazka_decoy_smoke` sob as cópias (`SHAZKA_SMOKE_ALPHA`); Ulgra = `prop_ulgra_stampede` ao longo de cada
faixa (cor quente/fria; `ULGRA_LANE_SINK`); Gorbash = `prop_gorbash_shockshard` só no anel aceso; Kragmar = `prop_kragmar_lavapool`.
Som: `Sfx.SIG_WARN` (aviso, `sig_warn`) e `SIG_EFFECT` (ex. `drum_tear` no canal quebrado).
**Gramática de cor dos avisos** (2026-11-13; `FxManager.DANGER*` em `game/fx/fx_manager.gd`, cabeçalho de `game/fx/boss_sig_view.gd`):
dano = vermelho-laranja (`DANGER`): área inteira fraca (`DANGER_BASE_A` 0,12) + borda forte (`DANGER_RIM`, 0,12 m, × 1,6 em chefe) +
miolo que cresce até o impacto (`DANGER_FILL_A` 0,30; o boneco continua visível); lugar seguro = frio/areia (ilhas da maré, sombra do
pedregulho); dividir = dourado (`GOLD` 0,30); sombra/controle = roxo (nuvem das cópias do Shazka, `VENOM`, com borda quente porque machuca).
A identidade do chefe vem da forma, nunca de cor contrária (as lascas do Gorbash, verdes no .glb, ganham `SHARD_GLOW` quente).
Golpe físico de monstro (`mob_*`) usa o tema de impacto quente `blood` (`MOB_HIT_THEME`), não o branco `physical`. Marcas TARGET
empilhadas no mesmo ponto (matilha no mesmo alvo) viram uma só (`_spot_taken`; seis empilhadas viravam disco opaco).

Sonda com a assinatura ligada (`boss_probe`, 4 sorteados, 40 lutas = semente padrão + `--seed=7`; completo = Guardião, Sacerdote,
Executor, Fogo, 20 lutas). Recalibrado só `unit_mods.atk` e o `power` da marca (nunca o crowd):
| Chefe | Antes (sem assinatura) | Com assinatura, 1ª medida (20) | Ajuste | Final 4 sorteados | Completo | Métrica da assinatura |
|---|---|---|---|---|---|---|
| Mãe das Marés | 60% | 40% (sem a regra da ilha longe) | bots preferem ilha longe; atk 1,6 → 1,5 | 62,5% | 100% | 0,2-0,4 atingidos por maré |
| Agitador-Mor Grukk | 77,5% | 75% | — | 75% | 100% | canal quebrado 92-100% |
| Troll Rei-da-Rocha | 52,5% | 55% (sem: 45%) | atk 1,75 → 1,35 | 67,5% | 100% | 0,05-0,15 atingidos por Avalanche |
| Mestre Besteiro Vorgul | 75% | 40% | marca 1,5 → 0,9; atk 1,1 → 1,0 → 0,9 | 72,5% (lutas 60-80 s, antes 52 s); **60%** (24/40, 51-68 s) depois que os bots passaram a sair de toda poça que fica (Kragmar) — na borda; próximo botão atk 0,9 → 0,85 | 100% | 0,01-0,04 aliados por marca |
| Senhor da Guerra Ghar | 70% | 45% | guarda parada do alvo; atk 1,45 → 1,3 | 80% | 100% | fúria média 2,8-4,0 |
| Presa-de-Cinza (então campo, hp ×0,6) | — | solo 95%, trio 100% | — | solo 95%, trio 100% | — | 0,3 sequências cortadas (solo) |

Kharzun (Shazka, Ulgra, Gorbash): faixa do usuário = **5 sorteados 60-80%**, completo de 5 (Guardião, Sacerdote, Executor, Fogo,
Bispo Batalha) ≥ 90%. 40 lutas = semente padrão + `--seed=7`; antes = `--no_sig` na mesma base:
| Chefe | Antes (5 sorteados, sem assinatura) | Com assinatura, 1ª medida | Ajuste | Final 5 sorteados | Completo de 5 | Métrica da assinatura |
|---|---|---|---|---|---|---|
| Mestre Matador Shazka | 77,5% (31/40) | 70% (28/40) | — | 70%, 30 s; **67,5%** (27/40, 29-53 s) depois da regra de poça do Kragmar | 20/20, 0,7 morte, 42 s | cópias vivas 0,8-1,4 s por uso (alvo ≤ 4 s); 0,2-0,5 cópias mortas por uso |
| Ulgra Presa-Atroz | 55% (22/40) | 47,5% (19/40) | atk 1,3 → 1,15 | 70% (28/40), 33-35 s | 20/20, 0,6 morte, 41 s | 0,5-0,7 atingidos por estouro (≈ 0,13 por pessoa) |
| Gorbash Pele-de-Rocha | 75% (30/40) | 70% (28/40) | bots só fogem do anel que cai em ≤ 1 s (sem isso 88 s de luta) | 70%, 41-50 s | 20/20, 0,3 morte, 45 s | 2,1-2,6 anéis por série no grupo (≈ 0,5 por pessoa; alvo ≤ 1) |
| Kragmar Martelo-Negro | 72,5% (29/40), 24-30 s | 52,5% (21/40), 46-58 s (3 poças: 1 nele + 2 nos alvos, 0,25/s) | bots saem da poça para o ponto livre; 3 → 1 poça (só a dele), tique 0,25 → 0,15 | 65% (26/40), 27-28 s | 20/20, 0,5 morte, 37 s | Têmpera média 0,06-0,14 (alvo ≤ 2); chefe na poça 4-8% da luta |
| Durgash (raide de 5) | 65% (52/80), 70-73 s | 15% (6/40), 1,2 morte por machado (power 6,0, 26 s, 3,5 m; completo de 5 34/40, 115 s) | power 6,0 → 2,0, 26 → 34 s, 3,5 → 4,0 m; só 2 ajudantes; marcado só para no fim | **57,5% (46/80), 68-74 s (abaixo da faixa; aceito pelo autor 2026-11-13)** | 40/40, 0,7 morte, 93 s; completo de 4 7/40 (18%), 3,6 mortes, 133 s | 2,8-3,7 dentro por machado; 0,02-0,13 morte por machado |
Durgash, varredura de `unit_mods` (2026-11-13, pedido do autor: 5 sorteados 62-65% sem passar o completo de 4 de 20%; `boss_probe --dmg/--hp`, 40 lutas, semente padrão): atk ×1,0 → 5 sorteados 23/40, completo de 4 7/40 · ×0,95 + vida ×1,04 → 23/40, 3/40 · ×0,92 → 23/40 · ×0,85 → 24/40 · ×0,85 + vida ×1,04 → 24/40, **13/40** · ×0,83 → 30/40, **18/40** · ×0,80 → 59/80 · ×0,75 → 31/40. O ATK do chefe solta o completo de 4 antes de mexer nos sorteados (o 4 perde no berserk dos 128 s; menos dano = chega vivo), então nenhum `unit_mods` cumpre as duas metas: ficou atk 1,0 / vida 4,3. O que separa 4 de 5 é o reforço de raide (`BOSS_CROWD_RAID`), decisão do autor.



### Ato III — chefes das masmorras (WP8b, 2026-11-23; GDD `ato3-excesso-45-50` §4)
Grupo de 4. Números das assinaturas só em `Balance.ACT3_BANQUET_*`/`GAZE_*`/`MIRROR_*`/`CANON_*`; pontos da sala = `boss_hint` do JSON
(check `_check_act3_dungeon_bosses`).
| Chefe | Onde | Kit e fases | Assinatura |
|---|---|---|---|
| Varo Taça-Cheia (`boss_varo`, hp ×4,0, atk ×1,95) | `dg_cellars`, 47 | Talho do Garrafão, Taça do Anfitrião (no mais longe), Barrigada (empurra); 70%: 3 Convidados nos pontos `adds` (escolta, sem ward); 35%: Fumo Doce em fileiras (R-A line, fica 4 s) + fúria ×1,15; berserk 200 s | **O Banquete** (R-C): canal 4 s a cada 35 s; no fim cura 6% e +25% ATK 12 s nele e nos convidados (`on_done.self`); quebrado = +15% de dano 6 s (`on_break`) |
| A Condessa Refletida (`boss_countess`, hp ×4,0, atk ×2,3) | `dg_mirrors`, 49 | Florete em Quatro Tempos (`strikes`, último crítico), Salto Leque; 65%: Máscaras Refletidas (3 cópias R-F, `countess_decoy`); 30%: Chuva de Cacos + fúria ×1,3; berserk 200 s | **Olhar Que Julga** (R-E): a cada 30 s sobem 3 Espelhos de Pé nos pontos `cover`; 3 s depois raio (2,4) em quem não tem espelho entre si e ela (30 m). **Espelhos = coberturas intocáveis** em `m["covers"]` (aprovado pelo usuário), não entidades; o que protegeu racha (`crack` → `idle_cracked`, `BossSigView`) e deixa de proteger |
| Mestra Ressoa (`boss_ressoa`, opcional, hp ×3,2, atk ×1,6, leash 36 m) | `dg_conservatory`, 49 | Estocada da Regente, Notas Agudas, Fermata (empurra 2 m); 65%: 4 Tubos de Órgão parados nos pontos `adds` (ward 0,6, Nota do Tubo); 30%: Uníssono (anel 4-9 m) + fúria ×1,3; berserk 200 s | **Cânone** (R-B spread + `touch`): 3 marcas (2 m, 4 s, nunca no tanque); marcas com centros a ≤ 4 m dobram o dano das duas |

Calibração (`boss_probe --asc`, 40 lutas por semente, 1337 e 7; completo = Guardião/Sacerdote/Executor/Fogo):
| Chefe | Completo de 4 (alvo ≥ 95%, 0,3-1 morte) | 4 sorteados (alvo 65-85%) | Assinatura |
|---|---|---|---|
| Varo | 80/80, 54-55 s, 0,7/0,8 morte | 65/80 (81%), 40-41 s | canal quebrado 94-96% |
| Condessa | 80/80, 54 s, 0,1/0,3 morte (média 0,2: um pouco abaixo) | 63/80 (79%), 46-51 s | 0,01 atingido por Olhar no completo; ~1/3 dos espelhos racha |
| Ressoa | 78/80 (97,5%), 54-65 s, 0,2/0,4 morte | 66/80 (82,5%), 44-48 s | ~40% das marcas dobram (bots espalham mal) |
Leash 26 → 36 m na Ressoa: com 26 ela resetava no meio da luta (os Tubos nasciam de novo: ~8 lacaios por luta e lutas de 115-225 s).

## Quests (cadeia)
q01 bem-vindo (TALK) → q02 slimes → q03 gel → q04 primeira poção (CRAFT) → q05 presas → q06 lobos → q07 rei javali →
c1 terra revirada (TALK) → c2 descida (REACH) → c3 Capitão + c4 Viúva (ramos) → c5 aviso à Capitã → q08 floresta (TALK) → q09 seda → q10 bandidos →
q10b Rainha Aranha → el1 trompas → el2 segurar o portão (investidas) → el3 além da garganta → el4 trents → el5 Guardiões → el6 Rei Élfico → q12 Bastião → dw_gates segurar os portões → postos e Carniçal Gigante → assentamento → postos e Vorhag → postos e Morvath → Ofensiva da Aurora (Lich-Rei) → De Volta a Aldara (epílogo, fim do Ato I); laterais: núcleos, Cripta, Dragonete. c6 (Conde Vargo) é opcional e pede grupo; q11 (Chefe dos Bandidos) e a linha do Dario viraram laterais.

**Ato II, 30-35** (`docs/roteiro_30_35.md`, `QuestsCatalog.act2`): Terra à Vista (Marinheira Dora, no cais da chegada) → Os Ginetes no Portão →
Cavilhas de Presa → Fechar a Paliçada (C1) → Olhos na Costa → O Mangue dos Lanceiros → Punhos Vermelhos → O Acampamento dos Ginetes (C3, exige C1)
→ A Boca das Grutas → O Tambor de Grukk (C4). Paralelas: O Farol Apagado (a última acende o farol, C2), Náufragos, Pérolas das Marés, O Diário do
Capitão, Goblin Comerciante (Nikki); a última de cada uma faz um NPC aparecer (`if` em `MapsCatalog`). Caçadas da Costa no Quadro da Taverna da Âncora.
**Ascensão** (35): 8 mestres na praça do porto (`QuestsCatalog.ASC_MASTERS`), cadeia de 3 (`hx_asc1_`/`hx_asc2_`/`hx_asc_<classe>`);
só a classe do mestre recebe (`QuestsCatalog.class_of` em `QuestSystem.can_accept`). Check `_check_act2_quests`.

**Ato II, Estepes de Cinza 35-40 — zonas** (2026-11-11, fase 2, só layout e dados de mapa; `design/gdd/ato2-horda.md` R2/R4 E0-E5):
`field_steppe` (`tools/blender/zones/build_field_steppe.py`, peças em `horde.py`) + três acampamentos de guerra como mapas próprios
(`fort_trolls`, `fort_fire`, `fort_war`: `build_steppe_forts.py`, em `MapsCatalog.FORT_DEFS`/`FORT_NPCS` como as fortalezas do Bastião).
Hub = Posto da Caravana (anel de carroças, quatro vãos; serviços, cristal, `caravan_master`). Entrada pela Costa (`to_field_steppe`, garganta
norte-nordeste; portão nível 35 + `hx_goblin_boss` = estágio C4); os acampamentos entram só por nível (35/36/37), em qualquer ordem.
Estágios pelas quests `hx_fort_trolls` / `hx_fort_fire` / `hx_fort_war`: a Horda do lado some, estandartes vermelhos viram branco-dourados
(`conquest_vis`), nasce o posto aliado (sentinelas `steppe_p_<lado>_*`, reforço `reforco_<lado>`), a investida daquele lado cala e as outras
crescem (`Balance.RAID_RECLAIM_MULT`, a regra do Bastião). Desertores: `unless hx_deserters_turn` (acampamento e chefe) e `if hx_deserters_help`
(mercadora orc, tratador de lobos, curral). Passo de Kharzun (E5): só visual, fechado na sim; a posição do portal futuro fica em
`future_portals` no JSON (o mapa `field_kharzun` ainda não existe). Monstros 35-40 ainda não existem: os spawners usam os ids do contrato
(`troll_whelp`, `troll`, `orc_archer`, `orc_crossbow`, `orc_warrior`, `boss_troll_king`, `boss_crossbow_master`, `boss_ghar`) e
`MapsCatalog.STAND_INS` troca por monstros da faixa 30-35 até o pacote chegar; as cabanas (`ivory_hunter`, `wolf_racer`) estão em
`PENDING_GIVERS` até o pacote de missões. Check: `_check_act2_steppe`.

**Ato II, Monte Kharzun 40-45 (fase 3)** — **plano aprovado em 2026-11-12, ainda não implementado**: [`design/gdd/kharzun-fase3-plan.md`](../design/gdd/kharzun-fase3-plan.md)
(decisões D1-D12, zonas, monstros, chefes, missões, estágios K0-K4, pacotes WP0-WP12, critérios KAC-01..17; regras-mãe em `design/gdd/ato2-horda.md` R2/R4/R5).
Em resumo: `MAX_LEVEL` 45; 3 mapas (`field_kharzun` com o Acampamento Avançado da Aurora como hub, `dg_slayers`, `kharzun_citadel`);
Contra-ataque da Horda em 2 frentes até K2, depois a Ofensiva da Aurora na cidadela; portão da cidadela nível 43 + `hx_citadel_gate`;
três Chefes de Clã como alas da cidadela (qualquer ordem) e o Grão-Senhor (provisório: Durgash) como raide de 5; Ferreiro Anão aprimora
lendários 40+; montaria lobo atroz com a velocidade do cavalo; Prova 45 opcional (título + moedas, 0 poder); *Ecos da Noite* mínimo.

**Recompensas de Kharzun (WP10, feito):**
- **Ferreiro Anão Thrain** (`dwarf_smith`, aparece no K1): só ele aprimora lendário **40+** (`ItemSystem.kharzun_tier`, `Balance.PLUS_KHARZUN_*`):
  Aço Anão no +1..+5 (2, 2, 3, 3, 4) e Brasa de Kharzun no +6..+9 (1, 2, 3, 4), ouro × 0,6 como a Aurora; os outros ferreiros recusam
  (`enhance_error(..., smith)`). Lendário 25-35 continua com Prata Consagrada/Fragmento da Aurora. Fala nova depois de `hx_dw_forge` (`dialog_after`).
- **Lobo atroz** (D5): `SimEntity.mount_kind` (`Balance.MOUNT_KINDS`, salvo como `mount`; save antigo = cavalo), mesma velocidade do cavalo.
  Entregar `hx_ov_hatch` libera e já troca; a **Tratadora Nara** (`kharzun_wolf_keeper`, acampamento, `if: hx_ov_hatch`) troca entre os liberados.
  Visual: `EntityView.MOUNT_LOOKS` (`mob_dire_wolf_mount`, pelagens cinza `WOLF_COATS`).
- **Joias e capas 45** (`GearCatalog.kharzun_jewels`, `RecipesCatalog.kharzun_recipes`): `<anel|amuleto|capa>_<tema>_k45`, épicas, nível 45, × 1,1;
  anel/amuleto (ferreiro) = 8 Aço Anão + 6 Basalto Rúnico + 1 Brasa + troféu do tema; capa (alquimia) = 8 Pele de Lobo Atroz + 6 Escamas +
  Estandarte de Durgash + troféu do tema; 1500 ouro. Troféus: Martelo Partido (Kragmar, guerreiro), Presa de Ulgra (caçador),
  Coração de Basalto (Gorbash, sábio), Estandarte de Durgash (capas). Os troféus caem dos chefes (loot do WP7).
- **Título da Prova 45**: `QuestDef.reward_title` ("Mestre <Classe>" em `hx_asc45_<classe>`), lido de `SimEntity.honor_title()` (sem campo no save):
  aparece na placa de nome e na janela do personagem. 0 poder.
- **Colheita por estágio**: entrada de `MapsCatalog.GATHER` aceita `{"if"/"unless": quest}` (WorldState); Brasa de Kharzun na Forja Negra só depois do K1c.
- Check: `_check_kharzun_rewards`. Evidência: `production/qa/evidence/kharzun/wp10_*`.

Faixa do meio (10-20): monstros 1-2 níveis acima do antigo, quests de abate pedem 1,5x e a faixa toda paga mais em quest (`Balance.XP_QUEST_SHARE_BAND`: 55% em vez de 45%).

Laterais vêm das cabanas e de Bento, o Coveiro; recompensas repetíveis (`b_*`) ficam nos quadros e não acendem marcador. O jogador pode desistir de uma quest ativa.

**Portões** (`MapsCatalog.PORTAL_GATES`, só o jogador; bots passam): Catacumbas = nível 8 + c1; selo do Trono = Capitão e Viúva abatidos; Floresta = nível 10 + c5;
Cidade Élfica = nível 16 + el2; Ruínas = nível 20 + el6 (Rei Élfico; saves v<3 que já mataram o Chefe dos Bandidos ficam com o portão aberto). O chefe final nunca fecha um portal de zona, para precisar de grupo não travar quem joga sozinho. Portão aberto continua aberto.
Save sem `save_version` abre os portões de história que o nível alcança e o mapa onde já está; selos de chefe continuam valendo.

**Catacumbas do Conde (8-13)**: vestíbulo com a Irmã Odete, ala oeste (mortos, recrutas, Capitão de Ossos), ala leste (carniçais, aparições, alcova do Coveiro, Viúva Lamentosa),
selo ao norte → Trono do Conde (mapa à parte). Capitão: lacaios em 66% e 33%. Viúva: lamento em cone que retarda; em 50% almas e toque que corta cura (Murchar).
Conde: dreno, ergue mortos em 70%, fúria e onda de morte em 30%. Chefe sem alvo reseta por inteiro.

**Escudos**: 18 modelos únicos (`shield_kit.py`), usados por Paladino e pelo Sacerdote de maça. Com escudo da afinidade, o Paladino junta Juramento ao bloquear (até 5 cargas, aparar vale 2) e a próxima skill sagrada ou de escudo gasta tudo; skills de escudo também escalam com a DEF dele e com a VIT do Paladino (+1% a cada 20 VIT, até +25%). O Bispo cura 5% do HP do aliado mais ferido ao bloquear (Graça, recarga de 4 s) e, ao aparar, protege quem está por perto. Com escudo, a chance de bloqueio usa o maior entre FOR e WILL. Guarda sem MP quebra: só volta soltando o botão e com `Balance.BLOCK_MIN_MP`. Dano no tempo não apara. Séries e plano de arte: `docs/equipment_series.md`.

**Guardião (Paladino tanque)**: **Escudo Ricochete** (nível 6, exige escudo; efeito `bounce`) arremessa o escudo no alvo: ele voa, salta para o
inimigo mais perto ainda não atingido (3 alvos, 4 na maestria 3, 5 na 5; -15% de dano por salto), provoca cada um por 3 s (chefes metade),
atordoa 0,5 s quem estava preparando um golpe (interrompe) e volta para a mão (a mão do escudo fica vazia enquanto ele voa).
**Aura do Bastião** (nível 10, efeito `aura`, liga/desliga; `AuraSystem`): você gera +150% de ameaça, tem +10% DEF e, em combate, um pulso
de luz por segundo fere quem está a 3,5 m (40% do ATK; segura o bando todo); o grupo e as invocações a
12 m recebem 10% menos dano (`Stats.dr_pct`, teto `Balance.DR_CAP`) e +10% DEF, renovado a cada 0,5 s (some 1,3 s depois de sair do raio).
Morrer desliga; lançar de novo desliga; bot não desliga a própria. O bot Guardião leva na barra Golpe Sagrado, Ricochete, Aura, Provocar,
Imposição de Mãos e Retribuição (Muralha de Escudo no lugar dela antes do nível 24).
**Combustão** (Elementalista de fogo, `combust`): marca o alvo (aro que fecha nele durante o preparo de 0,3 s) e o faz explodir em 2,6 m;
as queimaduras SUAS em cada atingido detonam na hora (125% do que faltava, número laranja ✦) e o fogo reacende em todos por 4 s.
Combina com Bola de Fogo/Onda de Chamas/Muralha de Fogo antes.

**Grupo e papéis**: o alvo do monstro segue a ameaça (troca em 110%; `Stats.threat_pct` multiplica a ameaça do dano); Provocar prende por 4 s (chefes 2 s). O abate vai para quem causou mais dano real, com o grupo somado,
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
**Antecipação sem atraso** (V2, 2026-11-23; decisão D1: o preparo das skills rápidas não muda): a skill (não o básico, não a Suprema
nem a sequência de golpes) começa o clipe na 1ª pose de preparação (`EntityView.COIL_FRAME`, `coil_for`, `windup_timing(..., coil)`)
se o preparo ainda corre a ≥ `COIL_MIN_SPEED` 1x; o impacto continua no tick do dano (`combat_probe` 0 FLAG). Skill rápida de
personagem ganha brilho na arma / fagulha do tema na mão até o impacto (`WindupGlint`: golpe < 0,3 s, magia < 0,2 s) e o vento
`whoosh`/`whoosh_magic` `Sfx.WHOOSH_LEAD` 0,08 s antes do tick (cancelou = sem som; no golpe de skill ele substitui o `swing`).
**Gesto por arquétipo** (C1, 2026-11-23; só skill de classe, `SkillDef.clip` escrito vence): golpe físico de uma mão no chão =
salto (avanço) / arremesso (veneno, estrepes, zona) / golpe de cima, nunca `cast_ground`; canalização física = giro; magia em linha
= gesto da classe (`CAST_BY_CLASS`), nunca o básico; cura pelo tema da classe (`HEAL_BY_CLASS`: Druida natureza, Necromante dreno,
Bispo/Paladino luz); vento com gesto próprio; maldição do Necromante (`cast_curse`) ≠ veneno do Assassino (arremesso); invocação
do Necromante ergue do chão, Druida/Ranger chamam; buff de grupo das classes de luta = brado de ânimo; tiro de arco com preparo
≥ 0,2 s segura a corda; leque de pistolas. Clipes novos que o kit ainda não tem tocam o de antes (`CLIP_FALLBACK`); clipe novo no
kit precisa de `IMPACT_FRAME`. Ver tudo: `tools/tests/clip_route_probe.tscn`. Checks `_check_clip_routing`, `_check_anticipation`.
**Hit-stop** (C2, 2026-11-23): sempre LOCAL, só quem bateu e quem apanhou seguram o quadro (`EntityView.hit_react`); nada mexe no
`Engine.time_scale` (só o `--speed` de dev). Evento `Events.hit_stop(frames, attacker_id, target_ids)` sai só com o jogador envolvido;
degraus em `Combat.hit_stop_frames`: básico `HIT_STOP_FRAMES_BASIC` 2, golpe físico pesado (preparo ≥ `CAST_HEAVY_STARTUP`) e
finalizador ≥ `HIT_STOP_HEAVY_FRAMES` 6, teto `HIT_STOP_CAP_FRAMES` 12 (também depois do `stop_mult` da família de arma, `WeaponArcs`).
Arco de arma: `WeaponArcs.on_hit_stop`; o resto (golpe de monstro, projétil, aparar): `FxManager._local_stop`. Check `_check_hit_stop_local`.

## Escudos
14 escudos nomeados (`GearCatalog.SHIELDS`), lendários, cada um com silhueta, ícone e reação ao bloquear (cura, barreira, mana, reflexo, veneno, queimadura, lentidão, raiz, atordoar). A barreira dura `Balance.SHIELD_BARRIER_TIME` (5 s) e nunca encurta um escudo maior.
**Aparar**: erguer o escudo até 0,22 s antes do golpe tira 90% do que sobrou depois da redução da guarda (somados, ~98,5% com a guarda no teto), dobra a reação e atordoa quem bateu de perto (recarga 0,9 s; segurar não apara).

## Equipamento: slots
Toda classe usa arma, mão secundária, cabeça, peito, calça, luvas, botas, capa, amuleto e dois anéis. Calças, capas, amuletos e anéis são
gerados em `GearCatalog.wearables` (4 tiers, sem restrição de classe); capa, amuleto e anel têm temas Guerreiro, Caçador e Sábio.
**Joias de mana** (2026-11-16, Berserker sem mana): nos temas Guerreiro e Caçador o amuleto devolve % da mana máxima a cada abate
(`mp_on_kill`: 4/5/6/7/8/10% por tier, 12% no k45) e a capa regenera % da mana máxima por segundo só em combate (`mp_regen_combat`:
0,3-0,8%/s, 1% no k45); anéis sem. O Sábio tem a mana no amuleto: regen em combate (`mp_regen_combat` 0,15-0,4%/s, 0,5% no k45,
`Balance.MANA_SAGE_*`). Números em `Balance.MANA_*`, stat do item em `ItemDef.bonus`; medir com `tools/tests/mana_probe.tscn`.
**Acessórios (retrabalho 2026-11-17, spec `production/qa/accessory-rework-spec-2026-11-17.md`)**: capa, amuleto e anel seguem uma curva
exponencial ancorada no t2 (`GearCatalog.acc_curve/acc_attrs`): atributo = linear antiga no nível 16 × 1,5^((nível − 16)/8)
(`Balance.ACC_CURVE_*`), ~+50% por tier, nenhum tier abaixo do de antes. Somas (escala do jogo): anel/capa 24/30/44/67/99/149 e 211 no k45;
amuleto 26/34/52/77/116/174 e 246. DEF/MDEF da capa na mesma curva (4/3 no t2, 14/10 no t5, 20/14 no k45). Papéis (`GearCatalog.acc_roles`):
anel = ATK plano (MATK no Sábio) 0/1/2/3/4/5 por tier, 6 no k45 (`ItemDef.atk/matk`, `Balance.ACC_RING_ATK`; valores do spec: a alavanca
3/3/4 da sonda foi desfeita por decisão do autor, que aceitou os chefes 43-44 mais fáceis solo); amuleto = vida % (`hp_pct` 1-3%,
`Balance.ACC_AMULET_HP_PCT`) + a mana do tema; capa = DEF/MDEF + mana corpo a corpo. **Únicos** (`ItemsCatalog.UNIQUE_ACCESSORIES`,
`GearCatalog.unique_acc`): os números escritos são a proporção; o total = min(1,25 × a comum do mesmo slot e nível; 0,9 × a do tier
seguinte) (`Balance.ACC_UNIQUE_*`), com o papel do slot pelo 1º atributo (FOR/AGI → ATK/mana ao abater; INT/WILL → MATK/regen). Ex.: Anel
do Capitão 60 → FOR 19 VIT 19 + 1 ATK (o anel de forja do 16 tem 44 + 2 ATK); Amuleto do Golem 160 → 96. Manto do Conde DEF/MDEF 4/4.
Ganho das 4 joias do Guerreiro sobre as de antes: +3,6/+6,2/+4/+6/+14/+31,6/+53,8 de PATK (t0..t5, k45), vida +1/+2/+2/+2,5/+4/+7/+10%
(sentinela em `_check_accessory_curve`). Sonda antes → depois → com a alavanca (`boss_probe`, solo, 40 lutas = semente padrão + `--seed=7`):
Ulgra 17 → 22 → 19/40, Shazka 16 → 22 → 21/40, Kragmar 14 → 18 → 17/40, Mãe-Loba 19 → 21/40 (faixa de grupo: solo 20-40%); o grupo de 5
sorteado sobe 0-4 vitórias em 20 por chefe (Durgash `--lvl=45` 9 → 9/20, 73 → 63 s); `band_probe` 8-16 e `web_probe` 40/45 sem mudança.
Os chefes 41-45 ficam ~+10 pontos acima do teto solo: aceito pelo autor (2026-11-17), sem recalibrar.
**Acessórios lendários** (2026-11-17, spec `production/qa/legendary-accessories-spec-2026-11-16.md`): por build e nível 35/40/45, Manto (capa),
Medalhão (amuleto), Anel e Sinete (os dois no slot de anel), id `leg_acc_<classe>_<build>_<nível>_<peça>` (`GearCatalog.legendary_accessories`).
Não são conjunto (`set_id` vazio, não contam peças); atributos da build pela curva × `LEGENDARY_MULT` (anel principal 94/121/155, amuleto
109/141/181, capa DEF/MDEF 13/9, 17/12, 22/16); papéis no valor k45 (anel/sinete +6 ATK ou MATK, medalhão vida +3%) e mana herdada do k45
(build FOR/AGI: medalhão 12% ao abater, manto 1%/s em combate; INT/WILL: medalhão 0,5%/s em combate; VIT nada). Cada peça soma um bônus da
build (`Balance.LEG_ACC_BUILDS` → `LEG_ACC_STEP[stat][35/40/45/50]`, o 50 = 45 + o passo do 40→45 (Ato III §6.4), ajuste `LEG_ACC_BUILD_MULT`). A mesma peça nos dois anéis (ou ela e a +N)
dá o bônus uma vez (`Stats.compute`). Stats novos (tetos em `Balance`): `crit_dmg_pct` (crítico × `CRIT_MULT` + v/100, teto 40),
`dot_pct` (dano no tempo aplicado, fixado na aplicação, 60), `cc_resist_pct` (atordoar/prender/lentidão em você duram menos, 50),
`mp_cost_pct` (custo de skill, arredonda para cima, mínimo 1, 30), `summon_time_pct` (invocação com tempo; companheiro permanente igual, 60).
Fontes: o sorteio lendário do 35/40/45/50 dá acessório com chance `Balance.LEG_ACC_DROP_SHARE` (25%, fatia própria como o escudo nomeado) e a
Relicária troca (7/8/9/10 moedas; "trocar o conjunto" não inclui acessórios). Bots do mundo não vestem; `Sim.bot_legendary_accessories` (sonda
`boss_probe --acc=leg`). Sinete tem arte própria (`ItemIcons._a_ring_signet`).
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
**Faixa dos bots** (`BotBandSystem`, playtest 2026-11-18 "lv 40 no primeiro mapa"): a cidade nasce na faixa dela
(`level_range` até `BOT_BAND_SLACK` acima: Aldara 1-12, antes 1-30). Cada povoado com cristal (`MapsCatalog.CRYSTALS`) é a casa de uma faixa:
bot sem cristal volta (G, renascer, vender em RETURN/SHOP) ao de maior piso com piso + `BOT_HOME_STEP_UP` ≤ nível (Aldara até 11, Posto 12+,
Bastião 22+, Porto 32+, Estepes 37+, Kharzun 42+); no grupo do jogador a casa é a do jogador. Bot à toa num povoado de faixa bem mais baixa
(`below_band`) sai para caçar na faixa dele. Praça: o ponto de encontro sai de `BOT_HANGOUT_PICKS` sorteios (o com menos gente a
`BOT_HANGOUT_CROWD_R`) e, com `BOT_SQUARE_CAP` bots a `BOT_SQUARE_RADIUS` do centro, os da praça ficam de fora; os bots da cidade nascem
espalhados pelos pontos de encontro. Medir: `sim_probe.tscn -- --ticks=18000 --census` (linhas `BAND`/`BANDAVG`). Check `_check_bot_band`.

## Grupo (party) — `PartySystem` (`Sim.party_*`), constantes `Balance.PARTY_*`
- Até 5 membros. Convite → aceitar (expira em 30 s); quem convidou vira líder. Líder convida, expulsa e passa a liderança;
  quem sai do grupo de 2 desfaz o grupo; líder que sai passa a liderança ao próximo.
- **XP**: abate dividido entre os membros vivos no mesmo mapa a até 45 m e com até 15 níveis de diferença;
  total × (1 + 15% por membro extra) ÷ membros, cada um com o multiplicador do próprio nível. Quests de abate contam para todos eles.
- **Curas e buffs em área** só pegam você, o grupo e as invocações deles (`SimEntity.is_friend`); invocações herdam o grupo do dono.
- **Efeito-assinatura** (`signature` de cada build em `classes_catalog.gd`, `LegendEffects.signature_on_hit`): toda build lança de graça a magia dela ao acertar,
  sem depender da arma (Fogo: Bola de Fogo; Gelo: Lança de Gelo; Iluminado: Martelo de Luz; Caçador: Flecha Gélida...). Chance
  `SIGNATURE_BASIC_PCT` (+1%/5 níveis) no básico e `SIGNATURE_SKILL_PCT` por acerto de skill, recarga `SIGNATURE_ICD`, poder `SIGNATURE_POWER`
  x o peso da build; o que ela acerta não dispara outra. Arma lendária com a mesma magia (Brasa Viva) soma chance.
  Armas lendárias que lançam magia (Brasa Viva, Castigo Sagrado, Lua Cheia, Praga) disparam ao acertar com ataque OU habilidade
  (no máximo 1 por `LEG_CAST_ICD`); Arco Voltaico e Pólvora valem no básico e em habilidades de alvo único. O básico da build
  ganha a aparência do tema (`SkillDef.look`, só visual: não estilhaça nem atordoa) e perde `SIGNATURE_BASIC_TRIM`. Calibrado com
  `tools/tests/dps_probe.tscn` (cada build, nv 10/20/30, com x sem: -5%..+10%); revisar com `-- --autostart=<classe> --sig_film=<png>`.
- **Invocações lutam sozinhas** (`MonsterBrain._summon_target`): quem bate no dono, depois quem o dono ataca, quem bate nela, o monstro mais perto do dono
  (`SUMMON_ASSIST_RANGE`); coleira de `SUMMON_LEASH` no dono; a que ficar presa a mais de `SUMMON_TELEPORT` (36 m) aparece ao lado dele, e refazer a skill dispensa a que está fora da coleira e chama de novo (antes: "já está com você" com o bicho perdido); usam as skills do monstro; as que atiram (`ranged`: elementais de gelo/raio, lich) recuam
  medindo do alvo. Ataque e magia vêm do dono. Ordem do companheiro segura o alvo `PET_COMMAND_FOCUS` s. Sonda: `tools/tests/pet_probe.tscn` (FLAG = sem alvo, golpe lento, atirador colado).
- **Bots**: aceitam convites (nível próximo); no grupo, quem não é líder segue o líder (por portais também), cura quem
  está abaixo de 60% de HP e ataca o que bate no grupo. Bot que sai pra caçar às vezes chama bots da vila e, raramente, o jogador
  (um convite por vez, com recarga). Grupo só de bots costuma se desfazer quando voltam à vila.
- **Bot líder** (2026-11-23, `BotLeaderSystem`, `Balance.BOT_LEADER_*`): o jogador passa a liderança a um bot (P "Líder" ou `/lider nome`; retoma com
  "Retomar a liderança" ou `/lider`). O bot completa o grupo até 5 (bots livres do mapa a até 45 m e 5 níveis; tanque, depois cura, depois dano;
  um convite a cada 6 s; segura a saída na vila até 75 s ou ir ao ponto de encontro), espera o jogador que ficou a mais de 28 m (até 45 s) e conta o plano
  no chat do grupo ("[Grupo]", verde): o que falta, quem convidou, para onde vai caçar, chefe à vista, volta à cidade (no máx. 1 fala a cada 5 s).
- **UI**: quadros dos membros abaixo do seu (HP/MP, ♛ líder, mapa se longe), janela Grupo (P) com membros e "Por perto" para convidar (só quem aceitaria agora: fora de grupo, sem convite pendente, nível compatível, até `PARTY_NEARBY_RANGE` m; `PartySystem.invitable_near`; quem não é líder ou tem o grupo cheio vê o motivo),
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
**Texto de combate** (`FloatText`, game/fx/float_text.gd, 2026-11-13): pool de Label3D (teto `MAX_TOTAL` 48; a briga grande chegava a
383 num quadro), 4 faixas por alvo (centro, esquerda, direita, centro alto), o mesmo texto no mesmo alvo dentro de 0,6 s soma no pop
("Esquiva! ×5", repique), no máximo 4 pops vivos por alvo (o 5º apressa o mais velho); vida 1,3 s (sobe 1,4 m em 0,9 s). "Esquiva!" de
outros só a até 16 m. **Nomes na multidão** (`NameplateCrowd`, game/ui/nameplate_crowd.gd): monstro comum com ≥ 4 comuns a até 4 m
(contando ele) esconde o NOME (a barra fica); voltam o do mouse em cima (1,4 m), o alvo do jogador e os 2 agressores do jogador mais
perto; chefe, elite, NPC, bot e jogador sempre mostram. Passada única a cada 0,2 s em `main._cull_views`. Check `_check_float_text_crowd`.
**Brilho de monstro** (2026-11-13): o toon do monstro respeita a emissão do .glb (`EntityView.mob_glow/glow_color`): energia > 1,05 e cor
não preta, ou material `glow_*`, vira `emission_amount` (energia × 0,6 em degraus de 0,25, 0,25-1,75); o `m_white` (energia 1,0) não brilha.
Check `_check_mob_glow`. **Lava**: o `FIRE_SHADER` (game/visual/materials.gd) tira o miolo amarelo-claro das faces viradas para cima
(lava plana = cor base, emissão × 0,3-1, brilho que corre devagar); chamas, cones e braseiros não mudam.
**Aves e bichos do ar** (`game/world/ambient_life.gd`): asa com cor no vértice; aves grandes ganham corpo (meio fuso dentro da malha da asa,
1 draw), a gaivota tem ponta escura, corpo claro e mancha no chão (1 MultiMesh de sombra por bando, alfa pela altura 0,5-0,22); morcegos
ficam planos, mariposa/brasa sem corpo nem sombra. Check em `_check_living_act2`.

## Som — `Sfx` (game/audio/sfx.gd) e `Music` (game/audio/music.gd), volumes em `AudioSettings` (Esc → Volume geral / Música / Efeitos / Interface)
Música (2026-11-10): 12 faixas CC0 do OpenGameArt (`tools/audio/build_music.py`, créditos em `assets/audio/music/CREDITS.md`): Aldara, taverna,
campo, Cidade Élfica, Bastião, masmorra, caverna, Catacumbas, fortalezas, Cidadela; por cima, chefe em luta e investida no mapa; troca suave de 1,6 s.
Efeitos sonoros lidos dos `Events`. Banco em `assets/audio/sfx/<nome>_<n>` gerado por `tools/audio/build_sfx.py`:
golpes, impactos, bloqueio, monstros, itens e cliques vêm de pacotes CC0 (créditos em `assets/audio/CREDITS.md`); magias por tema,
preparação de magia, esquiva, crítico, arco/tiro, nível, quest e volta à cidade são sintetizados pelo script (semente fixa).
- Golpe físico: vento da arma na fase ativa (arco/rifle/pistola: disparo ao sair o projétil); acerto e crítico no alvo; você levando dano tem som próprio.
- Skill: som do TEMA visual (`FxManager.theme_of` → `Sfx.THEME_SOUND`; magia sem tema = arcano) no ponto mirado; magia com preparação ≥ 0,2 s zumbe antes.
- Volume pela distância ao jogador (cheio até 8 m, some em 40 m), direção pela câmera; briga dos outros -5 dB; cada som tem intervalo mínimo e no máximo 3 vozes iguais.
- Interface: todo botão clica, janela abre/fecha, nível, quest aceita/concluída, item (épico+ brilha), ouro, poção, equipar, forja, colheita, porta de casa.

## Dicas contextuais — `Tips` (game/ui/tips.gd)
Começo guiado sem tutorial travado: um cartão acima da barra aparece UMA vez quando a mecânica fica relevante (andar, atacar com monstro perto,
skills, dash/guarda ao levar dano, poção com vida baixa, colheita perto, quest, bolsa ao ganhar peça, teia no nível 2, cavalo no 3, talentos no 5,
voltar à cidade longe de casa, grupo no convite, câmera/mapa, morte). Some em 9 s ou no clique; vistas em `user://settings.cfg` (todos os personagens),
Esc → "Dicas" liga/desliga; partida automática não grava. Revisar: `-- --autostart=<c> --tip_shot=<png> [--tip=<id>]`.

## Tela inicial e fluxo de início (2026-11-14; spec e implementação em `design/ux/start-flow.md`)
Cena principal `game/menu/start.tscn`. Fluxo: **Título** (Jogar / Configurações / Sair, logo, música de Aldara) → **Personagens** (5 espaços, card com retrato,
Jogar/Excluir; sem personagem cai direto na Criação) → **Criação** (classe com a skill-assinatura em ação no pedestal, depois visual em 3 abas e nome) → **Carregamento**
(arte da zona + barra por etapas) → jogo. Cenário: acampamento de fogueira na beira de Aldara ao entardecer (`assets/models/menu_set.glb`), câmeras por tela.
- A sim fica vazia no menu (`Sim.maps/entities/parties` = 0); o mundo só é montado no Carregamento (`main.build_world(staged)`, etapas com barra).
- Save: `SaveSystem.slot_state(i)` = `empty|ok|corrupt`; gravação em `.tmp` + renomear; espaço danificado ocupa o lugar até ser excluído.
  Retrato do card em `user://portrait_<n>.png` (fotografado ao salvar; some com o personagem). `main.save_game()` é o ponto de salvar do HUD.
- Esc → "Salvar e voltar ao menu" volta direto a Personagens com o card do personagem selecionado. Falha no Carregamento também (faixa vermelha).
- Começos rápidos (`--preset=N`) e saves falsos só existem como flags de dev (`--dev_presets`, `--menu_saves`). Esc → Configurações é o mesmo `SettingsPanel` do Título.
- Configurações têm duas abas: **Geral** (Gráficos, volumes, Dicas) e **Acessibilidade** (`AccessSettings`, seção `access` do `settings.cfg`):
  Tremor da tela 0-100%, Clarões 0-100% (hit flash, clarões de skill/Suprema), Avisos Desligado / Alto contraste / Daltônico (padrão por mecânica:
  dano = borda grossa + listras, seguro = tracejada, dividir = anéis de dentro, espalhar = segmentada, controle = ondulada; Daltônico troca para
  laranja/azul/amarelo/roxo) e Efeitos dos aliados Tudo / Reduzido (1 em 2) / Mínimo (nunca os seus, nunca avisos). Padrões = o comportamento de antes.

## Fora de escopo (por enquanto)
Rede real, PvP, guildas, dungeons instanciadas, música e som ambiente.

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

**G** volta para a cidade: conjuração de `Balance.RECALL_TIME` (3,5 s), **vale em combate**. Começar correndo não vale; andar, agir (golpe, skill, dash,
pulo, guarda, H) ou G de novo cancela; **levar dano** (o que a barreira segura inteiro não conta) ou ser atordoado **interrompe** (`PortalSystem.update_recall/stop_recall`,
`Events.recall_cast` start/done/interrupted/cancel). Montado: desce e conjura. Barra de conjuração no HUD e na cabeça, gesto `cast_channel` em laço
(`EntityView`) e círculo de runas + coluna de luz (`game/fx/recall_fx.gd`); "Interrompido" boia na cabeça. Os bots do grupo por perto vêm junto.
Bot voltando para vender (bolsa cheia, pouca vida) fora da zona da cidade também conjura o G; interrompido, anda para o portal e tenta de novo depois de `Balance.BOT_RECALL_RETRY` s.
H (montaria) e G têm botão próprio na barra de ações (`ActionBar.UTIL`, ícones `action_mount`/`action_recall` de `make_icons.tscn -- --only=action`).
Poções: **cada atalho F1-F3 tem a sua recarga** (`SimEntity.potion_cds`); como o mesmo item não fica em dois F, por atalho = por poção.
`potion_cd` continua como leitura do F1 (cérebro dos bots).
Barreira (`shield_hp`, vida temporária) aparece nas barras de HP como faixa azul-clara listrada depois da vida (no fim da barra se passar do máximo)
e "(+N)" no texto (`ShieldOverlay`): quadro do jogador, quadros do grupo e barra sobre a cabeça. Revisar: `-- --autostart=<c> --recall_shot=<png> [--recall_close]`.
**Cristal de Retorno** (`MapsCatalog.CRYSTALS`: praça de Aldara e Posto dos Caçadores; role `crystal`, `prop_crystal`): "Vincular aqui" faz o G e o renascer
levarem para a frente dele (`SimEntity.bind_map/bind_pos`, `PortalSystem.home_of`, salvo em `bind`; save antigo = Aldara). O Posto é `MapDef.hub`: dentro do muro
dá para trocar skills e escolhas (`MapDef.in_hub`), sem virar a cidade inicial. Losango azul no minimapa (maior = o seu).

XP: `Balance.XP_BASE` 220 × `XP_GROWTH` 1,30^(nível−1) (subir é ~2x mais lento que antes).

## Conjuntos lendários (peças e arma)

Cada conjunto tem **5 peças de armadura** (cabeça, peito, **calça**, luvas, botas): os bônus saem com 2, 3, 4 e 5 delas. A arma (e a 2ª arma /
mão secundária) é do conjunto, mas **não conta** nas peças: a arma lendária tem **efeito próprio** pelo papel da build, crescendo por tier —
um por build (`legend` da build em `classes_catalog.gd`; números [base, por tier] em `Balance.LEGEND_NUMBERS`):
Guardião Lâmina Justa (chance de +% do ATK em dano sagrado, que conta ameaça) · Cruzado Julgamento (chance de atordoar) · Gêmeos Frenesi (golpes acumulam vel. de ataque) ·
Executor Carrasco (+dano em alvo < 30%) · Punhos de Fúria Punho Vingativo (contra-ataque da esquiva mais forte) · Sacerdote Égide (cura vira barreira) · Iluminado Castigo Sagrado (básico lança Castigar) ·
Templário Penitência (5ª carga explode em fogo sagrado) · Clérigo de Batalha Mão que Cura (golpe cura o aliado mais ferido) ·
Urso Casca Viva (apanhou: Pele de Carvalho, 20 s) · Lobo Sangue da Matilha (sangramento) · Xamã Lua Cheia (básico lança Fogo Lunar) ·
Caçador Marca (alvo recebe mais dano de todos) · Atirador Pólvora (tiro explode em área) · Lanceiro Ferida Aberta (feridas acumuladas: +dano seu e sangramento) · Lâminas Veneno Letal · Duelista Riposte (esquivou,
contra-ataca) · Corsário Bala na Agulha (golpe às vezes dispara a pistola de graça; +1 Bravata) · Fogo Brasa Viva (básico lança Bola de Fogo) · Gelo Coração de Gelo (apanhou: Nova de Gelo, no máx. a cada 20 s) · Raio Arco
Voltaico (básico salta para +1 alvo) · Invocador Legião (abate levanta esqueleto) · Ceifador Ceifa (abate cura) · Sombras Praga (básico lança Agonia).
Atributos: toda peça lendária usa os dois atributos da build; escudos nomeados seguem a afinidade (Paladino VIT/FOR, Bispo VIT/WILL);
o Elementalista Raio é INT/WILL (AGI não serve a mago) e o conjunto inicial do Paladino é VIT/FOR.
**Armas com papel** (2026-11-17, `GearCatalog.WEAPON_ROLES`, números em `Balance.LEG_ROLE_NUMBERS` / `LEG_SWORD_ATK_MULT` /
`LEG_MACE_DEF_PER_ATK` / `LEG_BATTLE_MACE_ATK_MULT`; vale nos conjuntos da build, Ato II, híbridos e Ápices): no Guardião, Templário e
Cruzado a **espada/montante ataca** (FOR + o outro atributo da build, sem MATK, ATK ×1,08, efeito da build: Lâmina Justa / Penitência /
Julgamento) e a **maça/martelo defende** (VIT + FOR, MATK 0, DEF = ATK ×0,4, **Baluarte**: golpe dá barreira de 3% + 0,6%/tier da vida
máxima por 5 s, no máximo a cada 4 s; renova, não acumula). O **escudo** dos conjuntos do Guardião, do Templário e do Clérigo de Batalha
dá **Determinação** (`Stats.shield_passive`, buff `legend_determination`): atacar dá 1 carga no máximo a cada 2 s (sem renovar o tempo),
levar golpe dá 1 carga e renova; até 5; cada carga +2% (+0,1/tier) de ATK/MATK e +3% (+0,15/tier) de cura recebida; 6 s sem apanhar
perde todas. Escudos nomeados (`GearCatalog.SHIELDS`) não mudam. Clérigo de Batalha: a maça do conjunto troca o MATK por ATK ×1,1 e DEF
(FOR + VIT) e mantém Mão que Cura; Sacerdote e Iluminado não mudam. Maças comuns continuam com MATK (o Sacerdote cura com ele).
A Égide Ardente (híbrido Templário + Guardião) ganhou a maça de defesa (`..._mix_templario_guardiao_<nv>_mace`). Bots com `--set_weapon`
na sonda (`Sim.bot_set_weapons`): tanque veste a maça, dps a espada (os bots do mundo não vestem lendário).

## IA dos bots no combate (`BotBrain._fight`)

Alvo fixo enquanto vale (vivo, perto: `BOT_STICKY_RANGE`) — sem trocar a cada pensamento. Corpo a corpo: alcance do básico = raio do cone,
com histerese (entra a 75%, sai a 95%), fica parado durante o golpe, encosta num lado do alvo e usa o dash para fechar distância; se "no alcance"
o alvo não perde vida (obstáculo), chega mais perto; distância anda de lado até ter linha de tiro. Skill: a melhor pontuada (buff que não está
ativo, área quando há vários, a mais forte), invocação quando não há. Defesa: sai de área telegrafada de monstro (chão, em volta, cone, linha)
com dash se der; poção a 45% (corpo a corpo); sem poção e < 20% recua. Em grupo: segue o alvo do líder e entra quando ele briga.

**Em grupo (2026-11-10)**: cada bot tem o papel da build (`role`: tank, healer, dps, caster, ranged; jogador = build principal,
`ProgressionSystem.main_build`). Contra chefe/elite preso no tanque, a "frente" é a direção do chefe até o tanque (estável; o
`forward` girava a cada golpe mirado em outro): corpo a corpo vai para as costas (espalhado por id), quem luta de longe fica a
`BOT_RANGED_DIST` m num flanco de trás e só se mexe se estiver na frente, colado ou fora do alcance; quem cura fica a até
`BOT_HEALER_LEASH` m do tanque. Lugar inalcançável: desiste por `BOT_PLACE_COOL` s. Ameaça: acima de `BOT_THREAT_HOLD` × a
do tanque só básico, acima de `BOT_THREAT_STOP` para. Cura: tanque primeiro abaixo de `BOT_HEAL_TANK_HP`, os outros abaixo de
`BOT_HEAL_HP`. Tanque (líder ou seguidor) provoca e vai buscar chefe que largou dele, e não foge do golpe de frente/em volta
do chefe que segura (bloqueia; círculos no chão ele evita). Nas costas do chefe ninguém fica de guarda. Dps de perto tira lacaio
de cima de quem cura/atira (`BOT_PEEL_RANGE`). Investida é desviada mesmo estreita. Medição (`boss_probe --comp`, 17 chefes de
grupo × 8, Guardião/Sacerdote/Machados/Atirador/Fogo): chefe no tanque 48% → 91% (dps liderando, como o jogador: 67% → 82%);
dano de golpe sem mira em quem não é tanque 36% → 13%; lutas 19,5 s → 25 s (ritmo do grupo 62% → 51%: o preço de ficar no lugar).
Cura: emergência (alguém < `BOT_HEAL_CRIT_HP`) passa na frente do tanque se ele estiver acima de `BOT_HEAL_TANK_SAFE`.
**Grupo sob pressão** (`--dmg`/`--under`, 2026-11-10): grupo de 4 (Guardião, Sacerdote, Machados, Fogo) contra chefe do nível vence
sem ninguém abaixo de 35% de vida até com o chefe batendo 4× mais forte, e também 11 níveis abaixo (só demora mais): **os chefes de
grupo batem pouco para um grupo completo** (decisão de equilíbrio em aberto). A 6× o grupo vence ~75-85%; ali a IA nova empata com
a antiga em vitórias (36 contra 41/48, a diferença é toda o Senhor da Cripta: o Dreno de Almas "far" a 6× mata de uma vez o conjurador
que fica no flanco a 7 m) e morre menos (1,86 contra 1,96 por luta).
Dungeons: 25% maiores (`build_dungeons.SCALE`) e `SPAWN_COUNT_MULT_DUNGEON` 2x de monstros, para grupos.
