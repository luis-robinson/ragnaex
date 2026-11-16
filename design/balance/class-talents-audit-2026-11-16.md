# Auditoria dos talentos de classe — 2026-11-16

Pedido do jogador: "o talento realmente condiz? (...) para que todas as classes tenham algo interessante".
Fonte: `data/catalog/class_talents_catalog.gd` (8 classes x 9 linhas x 3), builds em `classes_catalog.gd`,
nível das skills em `skills_catalog.gd`. Linhas 35/40/45 já são uma por build (feitas no Ato II) e estão ok
em todas as classes; a auditoria foca nas linhas 5-30.

Legenda do veredito: **ok** · **red** = redundante (duas opções da linha são a mesma ideia, ou repete outra linha)
· **fraco** = número/efeito sem graça ou genérico demais · **morto** = cita skill que só abre DEPOIS do nível da linha
(o talento não faz nada por N níveis) · **fora** = nenhuma opção serve a uma build.
"Serve" = build que tem a skill citada na lista de skills dela (é também como o bot escolhe).

Feito já (Parte 1): Necromante nv 5 = Exército Eterno (fica) / **Mortos sem Pressa** (invocações com tempo x2) /
**Podridão Lenta** (dano no tempo x1,25 duração, x1,15 por segundo). Ganchos novos `summon_time` e `dot_boost`.

## Achado transversal: talentos mortos

O teste de catálogo não confere o nível da skill citada. 34 citações apontam para skill de nível acima da linha.
Os piores (o talento fica vazio 8+ níveis):

| Classe | Linha | Talento | Skill citada (nível) |
|---|---|---|---|
| Elementalista | 5 | **as 3 opções** | elementais 10/14/17, Sobrecarga 16, Armadura de Gelo 8 |
| Druida | 5 | Guardião do Bosque | Ent (19) |
| Bispo | 5 | Proteção Eterna | Égide (13) |
| Bispo | 10 | Anjo Guardião | Asas (22) |
| Bispo | 15 | Martírio Partilhado | Mártir (24) |
| Bispo | 20 | Milagre Frequente | Milagre (28) |
| Ranger | 10 | Mira Certeira | Olho de Águia (24) |
| Ranger | 15 | Alcance Longo (Empalar) | Empalar (24), parcial |
| Assassino | 5 | Reflexos Natos | Reflexos (11) |
| Assassino | 10 | Foco Absoluto | Foco (23) |
| Paladino | 10 | Lâmina da Fé | Zelo (18) |
| Necromante | 15 | Rei Eterno | Rei Esqueleto (26) |
| Necromante | 10/25 | Maldições Amplas / Longa (Agonia) | Agonia (28), parcial |

Proposta de regra (check novo): toda opção da linha N precisa de pelo menos UMA skill citada com nível <= N
(as parciais passam). Isso força as trocas abaixo.

## Paladino (guardiao tanque · cruzado 2 mãos · templario escudo+fogo)

| Nv | Opções | Veredito |
|---|---|---|
| 5 | Voto do Escudo (Juramento 8) · Golpe Restaurador (cura 12%) · Determinação (+8% HP, +60 VIT) | ok; Determinação fraco (só número) |
| 10 | Baluarte (armadura+muralha sempre, 60%) · Aura de Proteção (as mesmas, em aura 40%) · Lâmina da Fé (Zelo sempre) | **red** (Baluarte x Aura = a mesma ideia), Lâmina da Fé **morto** até 18 |
| 15 | Égide (Escudo Divino no grupo) · Mãos Rápidas · Desafio Sagrado | **fora** para o Cruzado; Égide **morto** até 20 |
| 20 | Aura de Cruzada (Zelo aura) · Valor Eterno · Juiz (execução) | **red** (Zelo pela 2ª vez); Guardião sem opção |
| 25 | Retribuição Plena · Muralha Rápida · Solo Sagrado | ok |
| 30 | Último Bastião · Luz Final · Avatar | ok |

## Berserker (carniceiro 2 machados · executor 2 mãos · punhos)

| Nv | Opções | Veredito |
|---|---|---|
| 5 | Recusa a Morrer · Sede Eterna · Fera Ferida | ok |
| 10 | Fúria sem Fim · Grito de Guerra (Sede vira aura) · Machado Gêmeo | ok; Grito repete a Sede (linha 5) |
| 15 | Rachar Amplo · Massacre (abate renova a Sede) · Pele de Titã | **red**: Massacre não faz nada com Sede Eterna (linha 5) |
| 20 | Carnificina (+5% roubo) · Sangue Quente (+10% vel.) · Executor (execução) | **fraco** (3 números soltos); "Executor" = nome da build |
| 25 | Redemoinho Sedento · Salto Atordoante · Sangue Fervente (Fúria aura) | ok |
| 30 | Ira Ancestral (Fúria sempre) · Banho de Sangue · Gigante | **red**: Fúria aparece em 10, 25 e 30; Executor (sem Fúria) fica com Gigante |

## Bispo (sacerdote cura · inquisidor/Iluminado · batalha)

| Nv | Opções | Veredito |
|---|---|---|
| 5 | Bênção Eterna (aura) · Proteção Eterna (aura) · Radiante | **red** (duas "buff vira aura"), Proteção **morto** até 13, Iluminado só com Radiante |
| 10 | Anjo Guardião · Fervor Eterno · Cura Ampla | Anjo **morto** até 22; Fervor morto até 14 |
| 15 | Martírio Partilhado · Santuário Maior · Renovação | **fora** para Iluminado e quase para Batalha (3 de cura); Martírio morto até 24 |
| 20 | Radiância Plena · Milagre Frequente · Mão Firme | Milagre **morto** até 28 |
| 25 | Castigo · Coro · Mente Clara | ok |
| 30 | Intercessão · Ascensão · Juízo | ok |

## Druida (guardiao_verde Urso · fera Lobo · xama)

| Nv | Opções | Veredito |
|---|---|---|
| 5 | Matilha Fiel (lobos para sempre) · Guardião do Bosque (Ent para sempre) · Pele Eterna | **igual ao caso do necro**: 2 invocações do Xamã, Lobo sem nada, Ent **morto** até 19, lobos até 9 |
| 10 | Instinto (formas x1,4) · Bosque Vivo · Rebrotar Amplo | ok |
| 15 | Rugido do Bosque · Uivo Eterno · Espinhos Fundos | ok |
| 20 | Fera Primordial (formas x1,6) · Raízes Fundas · Alcateia | **red**: mesmo gancho da linha 10 (e somam: x2,24) |
| 25 | Caçador Noturno · Raiz Profunda (pet +60%) · Sangue Selvagem | ok; Raiz Profunda diz "Ent", mas `pet_pct` vale para os lobos também (texto) |
| 30 | Avatar da Natureza · Ciclo · Floresta Eterna (Bênção sempre) | **red** com Bosque Vivo (10) |

## Ranger (cacador arco+lince · atirador rifle+armadilhas · lanceiro)

| Nv | Opções | Veredito |
|---|---|---|
| 5 | Laço de Sangue (lince +40%) · Armadilheiro · Olho Treinado | **ok — modelo de linha boa** (uma por build) |
| 10 | Matilha · Mira Certeira · Marca do Bando | Mira **morto** até 24, Matilha até 16, Marca até 15 (linha toda vazia no 10) |
| 15 | Segundo Lince · Alcance Longo · Recuo Armado | ok |
| 20 | Caçador (execução) · Bote Brutal · Minas Grandes | ok |
| 25 | Laço Vital · Fôlego (-15% recarga) · Chuva de Flechas | Lanceiro sem opção própria (fica com Fôlego) |
| 30 | Alfa (lince +100%) · Tiro Fantasma · Sobrevivente | **red** com Laço de Sangue (5): mesmo gancho `pet_pct`; Lanceiro sem opção |

## Assassino (laminas · duelista · corsario)

| Nv | Opções | Veredito |
|---|---|---|
| 5 | Lâmina Envenenada · Reflexos Natos · Emboscada | **red**: 2 permanentes das Lâminas; Reflexos **morto** até 11; Corsário/Duelista só Emboscada |
| 10 | Sombra Rápida · Foco Absoluto · Bailarino | Foco **morto** até 23; Corsário sem opção |
| 15 | Duelista (Guarda sempre) · Pelas Costas · Toxina Forte | ok; nome "Duelista" = nome da build |
| 20 | Sombra (abate some) · Dança de Lâminas (+10% vel.) · Olho Frio (+6% crit) | **fraco/red**: dois números soltos |
| 25 | Fuga · Golpe Final · Lâmina Sedenta | ok |
| 30 | Morte Certa · Fantasma · Mil Cortes | ok |

## Elementalista (fogo · gelo · raio)

| Nv | Opções | Veredito |
|---|---|---|
| 5 | Elemental Vinculado · Sobrecarga Contínua · Armadura Gélida | **morto**: nenhuma das 3 funciona no 5 (8/10/16); Fogo sem opção |
| 10 | Coração de Fogo · de Gelo · de Raio (+10%) | ok (uma por build; sem graça mas claro) |
| 15 | Elemental Forte · Fusão · Piscar Rápido | Fusão parcialmente morta (combos 16-29) |
| 20 | Estilhaço · Brasa Viva · Corrente Longa | ok (uma por build) |
| 25 | Fonte de Mana · Escudo de Mana · Mente Arcana | **red**: 3 opções de mana |
| 30 | Arquimago · Avatar Elemental · Cataclismo | ok (Arquimago bate no teto CDR_CAP 25) |

## Necromante (invocador · ceifador · pestilento/Sombras)

| Nv | Opções | Veredito |
|---|---|---|
| 5 | Exército Eterno · Mortos sem Pressa · Podridão Lenta | **feito hoje**; Ceifador ainda sem opção própria |
| 10 | Legião · Maldições Amplas · Ossos Vivos | ok (uma por build); Ossos morto até 18 |
| 15 | Rei Eterno · Lich Eterno · Sede de Almas | **red** (2 invocações permanentes, o mesmo problema do 5); Rei **morto** até 26; Ceifador sem nada |
| 20 | Demônio Desperto · Fantasma Longo · Ceifador | **fora**: as 3 são do Ceifador; Demônio só abre no 22 |
| 25 | Colheita · Cadáveres · Maldição Longa | ok |
| 30 | Senhor dos Mortos · Filactério · Praga | ok |

## Propostas de troca (uma linha cada)

Formato: **Nome** — efeito (números) — build — gancho.

### Necromante
- 15 Rei Eterno -> **Foice Sedenta** — Ceifar e Giro da Morte curam o dobro (heal_pct_of_dmg 0,15->0,30 / 0,10->0,20) — ceifador — `skill_mods.effects`.
- 20 Demônio Desperto -> **Maldição Contagiosa** — Condenação e Fraqueza 30% maiores e +2 s — pestilento — `skill_mods` (radius 1,3, duration).
  (o Ceifador fica com Fantasma Longo/Ceifador; Demônio Desperto pode virar opção do 25 no lugar de Colheita se quiser manter formas)
- 5 (ceifador): sem opção hoje; candidata futura **Lâmina da Morte** — Ceifar +20% de dano — ceifador — `skill_mods`.

### Druida
- 5 Guardião do Bosque (Ent, morto até 19) -> **Garras Afiadas** — Garras e Dilacerar +20% de dano e o sangramento das Garras dura 2 s a mais — fera — `skill_mods` (dru_claw nv 2, dru_maim).
- 5 Matilha Fiel: manter (lobos abrem no 9; aceitável) ou trocar por **Espinhos Vivos** (Espinhos atravessam) se a regra do nível entrar.
- 20 Fera Primordial (repete Instinto) -> **Uivo da Lua** — formas: +15% de velocidade de ataque enquanto na forma — fera/urso — gancho novo `form_stats` (stats que só valem na forma; o `regen.form` já faz isso para cura).
- 30 Floresta Eterna (repete Bosque Vivo) -> **Raiz Mestra** — Enredar e Ciclone recarregam 30% mais rápido — xama — `skill_mods`.

### Elementalista
- 5 Elemental Vinculado: manter, mas texto "a partir do nível 10". 5 Sobrecarga (16) -> **Faísca Viva** — Faísca +25% de dano e atravessa — raio — `skill_mods` (ele_spark, nível 1).
- 5 Armadura Gélida (8) -> **Lança Fria** — Lança de Gelo atravessa e +15% de dano — gelo — `skill_mods` (set projectile_pierce); Fogo ganha **Bola Ardente** no lugar do Vinculado se a regra do nível entrar — explosão da Bola de Fogo 30% maior — `skill_mods` (radius; hoje Brasa Viva no 20 faz +25%: subir lá para Combustão só).
- 25 Mente Arcana (3a de mana) -> **Elementos Instáveis** — +8% de crítico mágico — todas — `stats` (crit; já existe).

### Bispo
- 5 Proteção Eterna (morto, repete a aura) -> **Luz que Fere** — Luz Sagrada +20% de dano e atravessa — inquisidor/batalha — `skill_mods` (bis_light, nível 1; tira o pierce de Mão Firme no 20).
- 15 Martírio Partilhado (morto até 24) -> **Martelo Abençoado** — Martelada da Fé e Castigo do Escudo +20% de dano — batalha — `skill_mods`.
- 10 Anjo Guardião (morto até 22) -> mover para a linha 25 no lugar de Coro (que repete Prece do 40).
- 20 Milagre Frequente (morto até 28) -> mover para a 30 no lugar de Ascensão; no 20 entra **Nova Radiante** — Nova Sagrada 30% maior e +20% de dano — todas (nv 12) — `skill_mods`.

### Paladino
- 10 Aura de Proteção (repete Baluarte) -> **Golpe Ardente** — Chama Sagrada +20% de dano e queima 1 s a mais — templario — `skill_mods` (skill de nível baixo).
- 15 Égide (morto até 20) -> **Investida Firme** — Estocada Sagrada recarrega 30% mais rápido — cruzado — `skill_mods`.
- 20 Aura de Cruzada (Zelo 2a vez) -> **Bastião Vivo** — Aura do Bastião 30% maior — guardiao — `skill_mods` (radius).

### Berserker
- 15 Massacre (morto com Sede Eterna) -> **Sangue no Machado** — Dilacerar (ber_rend) sangra 50% mais forte — carniceiro/punhos — `skill_mods.effects.dot`.
- 20 Executor (nome da build, número solto) -> renomear **Carrasco**; ok como execução.
- 30 Ira Ancestral (Fúria 3a vez) -> **Terra Partida** — Racha-Terra 25% maior e atordoa 0,5 s — executor — `skill_mods`.

### Ranger
- 10 Mira Certeira (morto até 24) -> **Lança Leve** — Estocada Dupla e Dardo +20% de dano — lanceiro — `skill_mods` (ran_double_thrust, ran_javelin).
- 30 Alfa (repete Laço de Sangue) -> **Presa Escolhida** — Marca do Predador dura 50% a mais e recarrega 20% mais rápido — lanceiro — `skill_mods` (ran_predator nv 15).

### Assassino
- 5 Reflexos Natos (morto até 11, 2a das Lâminas) -> **Tiro de Abertura** — Tiro de Pistola +25% de dano e recarrega 20% mais rápido — corsario — `skill_mods` (ass_pistol_shot).
- 10 Foco Absoluto (morto até 23) -> **Corte em X** — Corte Cruzado +20% de dano e sangra — duelista — `skill_mods`.
- 20 Dança de Lâminas / Olho Frio (dois números) -> **Dados Viciados** — Dados da Sorte sempre tiram o bônus maior — corsario — gancho novo `dice_min` (ou `skill_mods` se os Dados já tiverem campo).

## Top 10 (maior diferença primeiro)

1. **Elementalista 5**: as 3 opções não funcionam no nível 5 — trocar Sobrecarga/Armadura por Faísca Viva / Lança Fria (skills de nível baixo).
2. **Druida 5**: o mesmo caso do necro (2 invocações do Xamã, Ent morto até 19, Lobo sem nada) — Guardião do Bosque -> Garras Afiadas.
3. **Necromante 15**: Rei Eterno morto até 26 e repete Lich Eterno — trocar por Foice Sedenta (Ceifador).
4. **Necromante 20**: as 3 são do Ceifador — Demônio Desperto -> Maldição Contagiosa (Sombras).
5. **Bispo 5**: duas "buff vira aura" e o Iluminado sem opção — Proteção Eterna -> Luz que Fere.
6. **Regra nova + check**: toda opção cita ao menos uma skill com nível <= linha (pega os 13 casos da tabela).
7. **Assassino 5**: Reflexos morto até 11 e Corsário sem opção — Tiro de Abertura.
8. **Druida 20 / Ranger 30**: mesmo gancho que outra linha (form_mult, pet_pct) — Uivo da Lua / Presa Escolhida.
9. **Bispo 15**: 3 opções de cura (Iluminado/Batalha fora) e Martírio morto até 24 — Martelo Abençoado.
10. **Paladino 10/20**: Zelo em 3 talentos e Baluarte x Aura de Proteção — Golpe Ardente (Templário) e Bastião Vivo (Guardião).

Notas: números das propostas são ponto de partida (medir com `boss_probe --class=<c> --build=<b>` antes/depois, como na Parte 1).
Bots escolhem pelas skills citadas (ou pela marca `build` nas 35+); trocas por `skill_mods` já entram certas no bot.
Ganchos novos só em `form_stats` (Druida 20) e `dice_min` (Corsário, opcional). Save: talento que sai do catálogo
agora só some da teia (`SaveSystem`, desde a Parte 1), sem devolver todos os pontos.

## Applied 2026-11-16 (opção A, decisão do usuário)

Regra nova + check `_check_talent_unlock_levels` (`run_tests.gd`, roda dentro de `_check_class_talents`; `--only=talent_unlock`):
toda opção da linha N cita ao menos uma skill com `unlock_level` <= N; gancho genérico que depende de um tipo de skill
(`summon_time`, `dot_boost`, `form_stats`, `form_mult`, `form_time`, `stats.pet_pct`) precisa de uma skill da classe desse tipo
aberta até N (`ClassTalentSystem._hook_fits`); opção só de números vale desde a linha. Visto falhar antes das trocas:
**22 opções mortas** (as 34 citações da tabela acima contam as parciais): pal zeal/aegis/valor, ber titan, bis blessing/ward/angel/zealot/
martyr/miracle, dru pack/grove_guard, ran pack/deadeye/mark, ass reflex/focus, ele bound/overload/armor, nec bones/king. Depois: 0.

Números novos em `data/balance.gd` (bloco `CT_*`). Ids que saíram do catálogo só somem do save (a teia fica, `SaveSystem`);
ids que mudaram de linha passam por `ClassTalentSystem.sanitize_picks` ao carregar (escolha acima do nível ou segunda na mesma linha sai).

### Top 10 (como no documento, com os desvios anotados)
| # | Classe nv | Saiu | Entrou |
|---|---|---|---|
| 1 | Elementalista 5 | Sobrecarga Contínua, Armadura Gélida, Elemental Vinculado (foi para a 15) | **Bola Ardente** (fogo: Bola de Fogo +20% e queima 2 s a mais), **Faísca Viva** (raio: Faísca +25%, atravessa até 3), **Lança Fria** (gelo: Lança de Gelo atravessa, +15%) |
| 2 | Druida 5 | Guardião do Bosque (Ent 19), Matilha Fiel (foi para a 10) | **Garras Afiadas** (fera: Garras e Dilacerar +20%, Garras sangram 2 s a mais), **Lua Crescente** (xamã: Fogo Lunar +20% e queima 2 s a mais) |
| 3 | Necromante 15 | Rei Eterno (Rei 26) | **Foice Sedenta** (ceifador: Ceifar cura 30% e Giro da Morte 20% do dano) |
| 4 | Necromante 20 | Demônio Desperto | **Maldição Contagiosa** (pestilento: Condenação e Fraqueza 30% mais FORTES e +2 s; o doc dizia "maiores", mas raio já é a Maldições Amplas do 10 e a Condenação é de alvo único) |
| 5 | Bispo 5 | Proteção Eterna (Égide 13), Bênção Eterna (Bênção 6: foi para a 10) | **Luz que Fere** (Luz Sagrada +20% e atravessa; Mão Firme do 20 perdeu o atravessar), Cura Ampla (veio da 10) |
| 6 | Regra + check | - | acima |
| 7 | Assassino 5 | Reflexos Natos (Reflexos 11) | **Tiro de Abertura** (corsário: Tiro de Pistola +25%, recarga x0,8) |
| 8a | Druida 20 | Fera Primordial (repetia o Instinto) | **Uivo da Lua** (Lobo/Urso: +15% de velocidade de ataque só na forma; gancho novo `form_stats`) |
| 8b | Ranger 30 | Alfa (repetia o Laço de Sangue) | **Presa Escolhida** (lanceiro: Marca do Predador dura x1,5 e recarrega x0,8) |
| 9 | Bispo 15 | Martírio Partilhado (Mártir 24) | **Martelo Abençoado** (batalha: Martelada da Fé e Castigo do Escudo +20%) |
| 10 | Paladino 10/20 | Aura de Proteção (repetia o Baluarte); no 20 saiu **Valor Eterno** (Valor 22, morto) e não a Aura de Cruzada | **Golpe Ardente** (templário: Chama Sagrada +20%, queima 1 s a mais), **Bastião Vivo** (guardião: Aura do Bastião alcança 30% mais longe, grupo e pulso). Desvio: o doc trocava a Aura de Cruzada; ela ficou (é o único Zelo que sobra, check "Zelo em um talento só") porque o Valor Eterno no 20 estava morto |

`dice_min` (Dados Viciados) não entrou (opcional, o corsário já ganhou o 5).

### Correções menores (as outras opções mortas)
- Paladino 10: Lâmina da Fé (Zelo 18) -> **Arco da Fé** (cruzado: Arco Radiante e Martelo de Luz +20%).
- Paladino 15: Égide (Escudo Divino 20) -> **Investida Firme** (cruzado: Estocada Sagrada recarrega x0,75; o doc dizia x0,7, mas a linha 40 já dá x0,7 e somavam x0,49).
- Berserker 15: Pele de Titã (Pegada 17) -> **Terra Partida** (executor: Racha-Terra 25% mais largo e atordoa 0,5 s; era a proposta do doc para a 30, trazida para cá). A 30 ficou como estava.
- Bispo 10: Anjo Guardião (Asas 22) foi para a 25 no lugar do Coro; Coro (Prece 8) veio para a 10; Fervor Eterno (Fervor 14) foi para a 15 no lugar da **Renovação** (saiu: a aura de regeneração repetia a Luz Final do Paladino e o Inquisidor não tinha nada na 15); no 10 entrou **Mão do Inquisidor** (Castigar e Martelo de Luz +20%).
- Bispo 20: Milagre Frequente (Milagre 28) foi para a 30 no lugar da **Ascensão** (saiu); no 20 entrou **Nova Radiante** (Nova Sagrada 30% maior e +20%).
- Druida 10: Matilha Fiel (lobos 9) veio da 5 no lugar de **Rebrotar Amplo** (saiu: só alcance).
- Druida 25: texto da Raiz Profunda diz "suas invocações (Ent e lobos)" (o `pet_pct` vale para todas).
- Ranger 10 (a linha toda morta): Matilha (Instinto 16) foi para a 30 no lugar de **Sobrevivente** (saiu); Mira Certeira (Olho de Águia 24) e Marca do Bando (Marca 15) saíram; entraram **Âncora Pesada** (caçador/atirador: Flecha Âncora +20% e prende 1 s a mais), **Flechas em Leque** (caçador: Tiro Múltiplo e Flecha Explosiva +20%) e **Lança Leve** (lanceiro, proposta do doc: Estocada Dupla e Dardo +20%).
- Assassino 10: Foco Absoluto (Foco 23) -> **Corte em X** (duelista, proposta do doc: Corte Cruzado +20% e sangra 12% do ATK/s por 4 s).
- Elementalista 15: Elemental Vinculado (veio da 5) no lugar de **Elemental Forte** (saiu). Elementalista 20: Brasa Viva agora só Combustão (30% maior e +20%), já que a Bola de Fogo ganhou o 5.
- Necromante 10: Ossos Vivos (Armadura de Ossos 18) -> **Lâmina da Morte** (ceifador: Ceifar +20%; a candidata do doc para o 5 — o 5 ficou como o jogador pediu, então o Ceifador ganhou a dele no 10).

Sistema: `apply_mods` agora aplica `set`/`effects` de todas as escolhas antes dos `mult` (a ordem de compra não muda o resultado) e
`mult.radius` numa skill de aura (`effects.aura`) estica também o raio do grupo e do pulso; `picked()` sai na ordem das linhas.
Bots: `_hook_fits` conhece `form_stats`/`form_mult`/`form_time` (build com skill de forma) e `stats.pet_pct` (build com invocação).

### Medição (boss_probe --party=1, 20 lutas, crab_king/slime_king/trent/elf_warden/death_knight, as 24 builds, antes/depois)
Quase tudo dentro de ±10% do tempo; as marcas >15% são lutas de 2-8 s (arredondamento) ou ruído de semente (Atirador crab_king 10->14 s:
com --seed=2/3 dá 8,7/9,6 s; a linha 5 dele nem mudou, só o sorteio do bot). Fera slime_king -16% (Garras Afiadas, esperado).
**Cruzado caiu de verdade aos 26**: death_knight solo 28/40 -> 7/40 (sementes 1337+2), tempo das vitórias igual. Ele perdeu Lâmina da Fé
(Zelo 50% sempre) e Valor Eterno (Valor 40% sempre), que estavam mortos até 18/22 mas fortes depois. Ajuste: Aura de Cruzada 35% -> 60%
(`Balance.CT_CRUSADE_AURA`, vale para o grupo): 13/40. Jogo de grupo, então ficou assim; ver "em aberto".

### Ainda em aberto
- Cruzado 20-30 solo mais fraco que antes (death_knight 13/40 contra 28/40). O bot sorteia Aura de Cruzada ou Juiz (genérico) no 20; se quiser
  devolver a força, opções: bot preferir a opção que cita skill da build, ou um talento do Cruzado no 25 (hoje só Solo Sagrado).
- Necromante 5: o Ceifador continua sem opção própria (a linha é a que o jogador pediu; ele ganhou a Lâmina da Morte no 10).
- Necromante 20: o Invocador não tem opção própria (Maldição Contagiosa é das Sombras; Fantasma Longo e Ceifador são do Ceifador).
- Assassino 10: o Corsário segue sem opção própria (Bailarino é genérico). Dados Viciados (`dice_min`) não foi feito.
- Não feitas (fora do top 10, passam na regra): Berserker 15 Massacre / 20 Executor->Carrasco / 30 Ira Ancestral; Druida 30 Floresta Eterna -> Raiz Mestra;
  Elementalista 25 Mente Arcana -> Elementos Instáveis; Assassino 20 Dança/Olho Frio -> Dados Viciados; Ranger 25 Lanceiro sem opção.

## Bots: escolha por build, sem sorteio (2026-11-16, decisão do usuário)

Regra (`ClassTalentSystem.bot_score` / `bot_choice`; antes o bot sorteava com `sim.rng` entre as opções "que servem"):
opção marcada para a build (`build`, 35+) 5000 > cita skill da build 4000 + 10 × (tamanho da lista − posição da skill citada mais cedo)
> gancho tipado que serve (`_hook_fits`) 3000 > gancho genérico sem tipo (cheat_death, execute, low_hp...) 2000 > só números 1000
(+500 se o número é do elemento da build: `fire/frost/storm_pct` contra `build.element`) > sem uso 0 (outra build, gancho tipado sem skill
do tipo, `oath_max` sem escudo na build, `trap_max` sem skill de armadilha). Desempate: tipo que o papel prefere (+2/+1: dps/ranged/caster
dano > aura > permanente; tank sobrevivência > aura > utilidade; healer aura > sobrevivência > utilidade), depois a ordem do catálogo.
O rng da sim não anda mais na escolha. Check `_check_bot_talent_prefs` (visto falhar no código antigo: Cruzado 20 Aura/Juiz, Cruzado 5
Voto do Escudo sem escudo, rng andando; depois passa) + "toda build x linha tem escolha que serve" (nenhuma build fica com nota < 1000).

### Antes (conjunto que o bot sorteava, linhas 5-30)
| Classe/build | 5 | 10 | 15 | 20 | 25 | 30 |
|---|---|---|---|---|---|---|
| paladin/guardiao | Voto do Escudo/Golpe Restaurador/Determinação | Baluarte | Mãos Rápidas/Desafio Sagrado | Bastião Vivo/Juiz | Retribuição Plena/Muralha Rápida | Último Bastião/Luz Final/Avatar |
| paladin/cruzado | Voto do Escudo/Golpe Restaurador/Determinação | Arco da Fé | Investida Firme | Aura de Cruzada/Juiz | Solo Sagrado | Último Bastião/Luz Final/Avatar |
| paladin/templario | Voto do Escudo/Golpe Restaurador/Determinação | Baluarte/Golpe Ardente | Mãos Rápidas | Juiz | Retribuição Plena/Solo Sagrado | Último Bastião/Luz Final/Avatar |
| berserker/carniceiro | Recusa a Morrer/Fera Ferida | Fúria sem Fim/Machado Gêmeo | Rachar Amplo/Massacre | Carnificina/Sangue Quente/Executor | Redemoinho Sedento/Salto Atordoante/Sangue Fervente | Ira Ancestral/Banho de Sangue/Gigante |
| berserker/executor | Recusa a Morrer/Sede Eterna/Fera Ferida | Grito de Guerra | Rachar Amplo/Massacre/Terra Partida | Carnificina/Sangue Quente/Executor | Redemoinho Sedento | Banho de Sangue/Gigante |
| berserker/punhos | Recusa a Morrer/Sede Eterna/Fera Ferida | Fúria sem Fim/Grito de Guerra/Machado Gêmeo | Rachar Amplo/Massacre | Carnificina/Sangue Quente/Executor | Salto Atordoante/Sangue Fervente | Ira Ancestral/Banho de Sangue/Gigante |
| bishop/sacerdote | Cura Ampla/Luz que Fere/Radiante | Bênção Eterna/Coro | Santuário Maior | Radiância Plena/Nova Radiante/Mão Firme | Anjo Guardião/Mente Clara | Intercessão/Milagre Frequente |
| bishop/inquisidor | Luz que Fere/Radiante | Mão do Inquisidor | Fervor Eterno | Radiância Plena/Nova Radiante/Mão Firme | Castigo/Mente Clara | Intercessão/Juízo |
| bishop/batalha | Cura Ampla/Luz que Fere/Radiante | Bênção Eterna/Coro | Martelo Abençoado | Radiância Plena/Nova Radiante/Mão Firme | Mente Clara | Intercessão/Juízo |
| druid/guardiao_verde | Pele Eterna | Instinto | Rugido do Bosque/Espinhos Fundos | Uivo da Lua | Sangue Selvagem | Avatar da Natureza/Ciclo |
| druid/fera | Garras Afiadas | Instinto | Uivo Eterno/Espinhos Fundos | Uivo da Lua/Raízes Fundas | Caçador Noturno/Sangue Selvagem | Avatar da Natureza/Ciclo |
| druid/xama | Lua Crescente | Bosque Vivo/Matilha Fiel | Espinhos Fundos | Raízes Fundas/Alcateia | Raiz Profunda/Sangue Selvagem | Avatar da Natureza/Ciclo/Floresta Eterna |
| ranger/cacador | Laço de Sangue/Olho Treinado | Âncora Pesada/Flechas em Leque | Segundo Lince/Alcance Longo/Recuo Armado | Caçador/Bote Brutal | Laço Vital/Fôlego/Chuva de Flechas | Matilha |
| ranger/atirador | Armadilheiro/Olho Treinado | Âncora Pesada | Alcance Longo/Recuo Armado | Caçador/Minas Grandes | Laço Vital/Fôlego | Tiro Fantasma |
| ranger/lanceiro | Armadilheiro/Olho Treinado | Lança Leve | Alcance Longo/Recuo Armado | Caçador/Minas Grandes | Laço Vital/Fôlego | Presa Escolhida |
| assassin/laminas | Lâmina Envenenada/Emboscada | Sombra Rápida/Bailarino | Pelas Costas/Toxina Forte | Sombra/Dança de Lâminas/Olho Frio | Fuga/Golpe Final/Lâmina Sedenta | Morte Certa/Fantasma/Mil Cortes |
| assassin/duelista | Emboscada | Corte em X/Bailarino | Duelista/Pelas Costas | Sombra/Dança de Lâminas/Olho Frio | Golpe Final/Lâmina Sedenta | Morte Certa/Fantasma |
| assassin/corsario | Tiro de Abertura/Emboscada | Bailarino | Duelista/Pelas Costas | Sombra/Dança de Lâminas/Olho Frio | Golpe Final/Lâmina Sedenta | Morte Certa/Fantasma |
| elementalist/fogo | Bola Ardente | Coração de Fogo/Coração de Gelo/Coração de Raio | Elemental Vinculado/Fusão/Piscar Rápido | Brasa Viva | Fonte de Mana/Escudo de Mana/Mente Arcana | Arquimago/Avatar Elemental/Cataclismo |
| elementalist/gelo | Bola Ardente/Lança Fria | Coração de Fogo/Coração de Gelo/Coração de Raio | Elemental Vinculado/Fusão/Piscar Rápido | Estilhaço | Fonte de Mana/Escudo de Mana/Mente Arcana | Arquimago/Avatar Elemental/Cataclismo |
| elementalist/raio | Faísca Viva | Coração de Fogo/Coração de Gelo/Coração de Raio | Elemental Vinculado/Fusão/Piscar Rápido | Corrente Longa | Fonte de Mana/Escudo de Mana/Mente Arcana | Arquimago/Avatar Elemental |
| necromancer/invocador | Exército Eterno/Mortos sem Pressa | Legião/Maldições Amplas | Lich Eterno | Maldição Contagiosa | Colheita/Cadáveres/Maldição Longa | Senhor dos Mortos/Filactério |
| necromancer/ceifador | Exército Eterno/Mortos sem Pressa/Podridão Lenta | Lâmina da Morte | Foice Sedenta | Fantasma Longo/Ceifador | Colheita | Filactério |
| necromancer/pestilento | Podridão Lenta | Maldições Amplas | Sede de Almas | Maldição Contagiosa | Colheita/Maldição Longa | Filactério/Praga |

### Depois
| Classe/build | 5 | 10 | 15 | 20 | 25 | 30 |
|---|---|---|---|---|---|---|
| paladin/guardiao | Golpe Restaurador | Baluarte | Desafio Sagrado | Bastião Vivo | Retribuição Plena | Último Bastião |
| paladin/cruzado | Golpe Restaurador | Arco da Fé | Investida Firme | Aura de Cruzada | Solo Sagrado | Luz Final |
| paladin/templario | Golpe Restaurador | Golpe Ardente | Mãos Rápidas | Juiz | Solo Sagrado | Luz Final |
| berserker/carniceiro | Fera Ferida | Machado Gêmeo | Rachar Amplo | Executor | Redemoinho Sedento | Ira Ancestral |
| berserker/executor | Sede Eterna | Grito de Guerra | Rachar Amplo | Executor | Redemoinho Sedento | Banho de Sangue |
| berserker/punhos | Sede Eterna | Machado Gêmeo | Rachar Amplo | Executor | Sangue Fervente | Ira Ancestral |
| bishop/sacerdote | Cura Ampla | Coro | Santuário Maior | Mão Firme | Anjo Guardião | Milagre Frequente |
| bishop/inquisidor | Luz que Fere | Mão do Inquisidor | Fervor Eterno | Mão Firme | Castigo | Juízo |
| bishop/batalha | Cura Ampla | Bênção Eterna | Martelo Abençoado | Mão Firme | Mente Clara | Juízo |
| druid/guardiao_verde | Pele Eterna | Instinto | Rugido do Bosque | Uivo da Lua | Sangue Selvagem | Ciclo |
| druid/fera | Garras Afiadas | Instinto | Espinhos Fundos | Raízes Fundas | Caçador Noturno | Ciclo |
| druid/xama | Lua Crescente | Bosque Vivo | Espinhos Fundos | Raízes Fundas | Raiz Profunda | Floresta Eterna |
| ranger/cacador | Laço de Sangue | Flechas em Leque | Segundo Lince | Bote Brutal | Chuva de Flechas | Matilha |
| ranger/atirador | Armadilheiro | Âncora Pesada | Alcance Longo | Minas Grandes | Laço Vital | Tiro Fantasma |
| ranger/lanceiro | Armadilheiro | Lança Leve | Alcance Longo | Minas Grandes | Laço Vital | Presa Escolhida |
| assassin/laminas | Lâmina Envenenada | Sombra Rápida | Toxina Forte | Sombra | Fuga | Mil Cortes |
| assassin/duelista | Emboscada | Corte em X | Duelista | Sombra | Golpe Final | Morte Certa |
| assassin/corsario | Tiro de Abertura | Bailarino | Duelista | Sombra | Golpe Final | Morte Certa |
| elementalist/fogo | Bola Ardente | Coração de Fogo | Elemental Vinculado | Brasa Viva | Fonte de Mana | Cataclismo |
| elementalist/gelo | Lança Fria | Coração de Gelo | Elemental Vinculado | Estilhaço | Fonte de Mana | Cataclismo |
| elementalist/raio | Faísca Viva | Coração de Raio | Fusão | Corrente Longa | Fonte de Mana | Avatar Elemental |
| necromancer/invocador | Exército Eterno | Legião | Lich Eterno | Maldição Contagiosa | Maldição Longa | Senhor dos Mortos |
| necromancer/ceifador | Podridão Lenta | Lâmina da Morte | Foice Sedenta | Ceifador | Colheita | Filactério |
| necromancer/pestilento | Podridão Lenta | Maldições Amplas | Sede de Almas | Maldição Contagiosa | Maldição Longa | Praga |

### mudou
| build | nv | antes (sorteio entre) | agora |
|---|---|---|---|
| paladin/guardiao | 5 | Voto do Escudo ou Golpe Restaurador ou Determinação | **Golpe Restaurador** |
| paladin/guardiao | 15 | Mãos Rápidas ou Desafio Sagrado | **Desafio Sagrado** |
| paladin/guardiao | 20 | Bastião Vivo ou Juiz | **Bastião Vivo** |
| paladin/guardiao | 25 | Retribuição Plena ou Muralha Rápida | **Retribuição Plena** |
| paladin/guardiao | 30 | Último Bastião ou Luz Final ou Avatar | **Último Bastião** |
| paladin/cruzado | 5 | Voto do Escudo ou Golpe Restaurador ou Determinação | **Golpe Restaurador** |
| paladin/cruzado | 20 | Aura de Cruzada ou Juiz | **Aura de Cruzada** |
| paladin/cruzado | 30 | Último Bastião ou Luz Final ou Avatar | **Luz Final** |
| paladin/templario | 5 | Voto do Escudo ou Golpe Restaurador ou Determinação | **Golpe Restaurador** |
| paladin/templario | 10 | Baluarte ou Golpe Ardente | **Golpe Ardente** |
| paladin/templario | 25 | Retribuição Plena ou Solo Sagrado | **Solo Sagrado** |
| paladin/templario | 30 | Último Bastião ou Luz Final ou Avatar | **Luz Final** |
| berserker/carniceiro | 5 | Recusa a Morrer ou Fera Ferida | **Fera Ferida** |
| berserker/carniceiro | 10 | Fúria sem Fim ou Machado Gêmeo | **Machado Gêmeo** |
| berserker/carniceiro | 15 | Rachar Amplo ou Massacre | **Rachar Amplo** |
| berserker/carniceiro | 20 | Carnificina ou Sangue Quente ou Executor | **Executor** |
| berserker/carniceiro | 25 | Redemoinho Sedento ou Salto Atordoante ou Sangue Fervente | **Redemoinho Sedento** |
| berserker/carniceiro | 30 | Ira Ancestral ou Banho de Sangue ou Gigante | **Ira Ancestral** |
| berserker/executor | 5 | Recusa a Morrer ou Sede Eterna ou Fera Ferida | **Sede Eterna** |
| berserker/executor | 15 | Rachar Amplo ou Massacre ou Terra Partida | **Rachar Amplo** |
| berserker/executor | 20 | Carnificina ou Sangue Quente ou Executor | **Executor** |
| berserker/executor | 30 | Banho de Sangue ou Gigante | **Banho de Sangue** |
| berserker/punhos | 5 | Recusa a Morrer ou Sede Eterna ou Fera Ferida | **Sede Eterna** |
| berserker/punhos | 10 | Fúria sem Fim ou Grito de Guerra ou Machado Gêmeo | **Machado Gêmeo** |
| berserker/punhos | 15 | Rachar Amplo ou Massacre | **Rachar Amplo** |
| berserker/punhos | 20 | Carnificina ou Sangue Quente ou Executor | **Executor** |
| berserker/punhos | 25 | Salto Atordoante ou Sangue Fervente | **Sangue Fervente** |
| berserker/punhos | 30 | Ira Ancestral ou Banho de Sangue ou Gigante | **Ira Ancestral** |
| bishop/sacerdote | 5 | Cura Ampla ou Luz que Fere ou Radiante | **Cura Ampla** |
| bishop/sacerdote | 10 | Bênção Eterna ou Coro | **Coro** |
| bishop/sacerdote | 20 | Radiância Plena ou Nova Radiante ou Mão Firme | **Mão Firme** |
| bishop/sacerdote | 25 | Anjo Guardião ou Mente Clara | **Anjo Guardião** |
| bishop/sacerdote | 30 | Intercessão ou Milagre Frequente | **Milagre Frequente** |
| bishop/inquisidor | 5 | Luz que Fere ou Radiante | **Luz que Fere** |
| bishop/inquisidor | 20 | Radiância Plena ou Nova Radiante ou Mão Firme | **Mão Firme** |
| bishop/inquisidor | 25 | Castigo ou Mente Clara | **Castigo** |
| bishop/inquisidor | 30 | Intercessão ou Juízo | **Juízo** |
| bishop/batalha | 5 | Cura Ampla ou Luz que Fere ou Radiante | **Cura Ampla** |
| bishop/batalha | 10 | Bênção Eterna ou Coro | **Bênção Eterna** |
| bishop/batalha | 20 | Radiância Plena ou Nova Radiante ou Mão Firme | **Mão Firme** |
| bishop/batalha | 30 | Intercessão ou Juízo | **Juízo** |
| druid/guardiao_verde | 15 | Rugido do Bosque ou Espinhos Fundos | **Rugido do Bosque** |
| druid/guardiao_verde | 30 | Avatar da Natureza ou Ciclo | **Ciclo** |
| druid/fera | 15 | Uivo Eterno ou Espinhos Fundos | **Espinhos Fundos** |
| druid/fera | 20 | Uivo da Lua ou Raízes Fundas | **Raízes Fundas** |
| druid/fera | 25 | Caçador Noturno ou Sangue Selvagem | **Caçador Noturno** |
| druid/fera | 30 | Avatar da Natureza ou Ciclo | **Ciclo** |
| druid/xama | 10 | Bosque Vivo ou Matilha Fiel | **Bosque Vivo** |
| druid/xama | 20 | Raízes Fundas ou Alcateia | **Raízes Fundas** |
| druid/xama | 25 | Raiz Profunda ou Sangue Selvagem | **Raiz Profunda** |
| druid/xama | 30 | Avatar da Natureza ou Ciclo ou Floresta Eterna | **Floresta Eterna** |
| ranger/cacador | 5 | Laço de Sangue ou Olho Treinado | **Laço de Sangue** |
| ranger/cacador | 10 | Âncora Pesada ou Flechas em Leque | **Flechas em Leque** |
| ranger/cacador | 15 | Segundo Lince ou Alcance Longo ou Recuo Armado | **Segundo Lince** |
| ranger/cacador | 20 | Caçador ou Bote Brutal | **Bote Brutal** |
| ranger/cacador | 25 | Laço Vital ou Fôlego ou Chuva de Flechas | **Chuva de Flechas** |
| ranger/atirador | 5 | Armadilheiro ou Olho Treinado | **Armadilheiro** |
| ranger/atirador | 15 | Alcance Longo ou Recuo Armado | **Alcance Longo** |
| ranger/atirador | 20 | Caçador ou Minas Grandes | **Minas Grandes** |
| ranger/atirador | 25 | Laço Vital ou Fôlego | **Laço Vital** |
| ranger/lanceiro | 5 | Armadilheiro ou Olho Treinado | **Armadilheiro** |
| ranger/lanceiro | 15 | Alcance Longo ou Recuo Armado | **Alcance Longo** |
| ranger/lanceiro | 20 | Caçador ou Minas Grandes | **Minas Grandes** |
| ranger/lanceiro | 25 | Laço Vital ou Fôlego | **Laço Vital** |
| assassin/laminas | 5 | Lâmina Envenenada ou Emboscada | **Lâmina Envenenada** |
| assassin/laminas | 10 | Sombra Rápida ou Bailarino | **Sombra Rápida** |
| assassin/laminas | 15 | Pelas Costas ou Toxina Forte | **Toxina Forte** |
| assassin/laminas | 20 | Sombra ou Dança de Lâminas ou Olho Frio | **Sombra** |
| assassin/laminas | 25 | Fuga ou Golpe Final ou Lâmina Sedenta | **Fuga** |
| assassin/laminas | 30 | Morte Certa ou Fantasma ou Mil Cortes | **Mil Cortes** |
| assassin/duelista | 10 | Corte em X ou Bailarino | **Corte em X** |
| assassin/duelista | 15 | Duelista ou Pelas Costas | **Duelista** |
| assassin/duelista | 20 | Sombra ou Dança de Lâminas ou Olho Frio | **Sombra** |
| assassin/duelista | 25 | Golpe Final ou Lâmina Sedenta | **Golpe Final** |
| assassin/duelista | 30 | Morte Certa ou Fantasma | **Morte Certa** |
| assassin/corsario | 5 | Tiro de Abertura ou Emboscada | **Tiro de Abertura** |
| assassin/corsario | 15 | Duelista ou Pelas Costas | **Duelista** |
| assassin/corsario | 20 | Sombra ou Dança de Lâminas ou Olho Frio | **Sombra** |
| assassin/corsario | 25 | Golpe Final ou Lâmina Sedenta | **Golpe Final** |
| assassin/corsario | 30 | Morte Certa ou Fantasma | **Morte Certa** |
| elementalist/fogo | 10 | Coração de Fogo ou Coração de Gelo ou Coração de Raio | **Coração de Fogo** |
| elementalist/fogo | 15 | Elemental Vinculado ou Fusão ou Piscar Rápido | **Elemental Vinculado** |
| elementalist/fogo | 25 | Fonte de Mana ou Escudo de Mana ou Mente Arcana | **Fonte de Mana** |
| elementalist/fogo | 30 | Arquimago ou Avatar Elemental ou Cataclismo | **Cataclismo** |
| elementalist/gelo | 5 | Bola Ardente ou Lança Fria | **Lança Fria** |
| elementalist/gelo | 10 | Coração de Fogo ou Coração de Gelo ou Coração de Raio | **Coração de Gelo** |
| elementalist/gelo | 15 | Elemental Vinculado ou Fusão ou Piscar Rápido | **Elemental Vinculado** |
| elementalist/gelo | 25 | Fonte de Mana ou Escudo de Mana ou Mente Arcana | **Fonte de Mana** |
| elementalist/gelo | 30 | Arquimago ou Avatar Elemental ou Cataclismo | **Cataclismo** |
| elementalist/raio | 10 | Coração de Fogo ou Coração de Gelo ou Coração de Raio | **Coração de Raio** |
| elementalist/raio | 15 | Elemental Vinculado ou Fusão ou Piscar Rápido | **Fusão** |
| elementalist/raio | 25 | Fonte de Mana ou Escudo de Mana ou Mente Arcana | **Fonte de Mana** |
| elementalist/raio | 30 | Arquimago ou Avatar Elemental | **Avatar Elemental** |
| necromancer/invocador | 5 | Exército Eterno ou Mortos sem Pressa | **Exército Eterno** |
| necromancer/invocador | 10 | Legião ou Maldições Amplas | **Legião** |
| necromancer/invocador | 25 | Colheita ou Cadáveres ou Maldição Longa | **Maldição Longa** |
| necromancer/invocador | 30 | Senhor dos Mortos ou Filactério | **Senhor dos Mortos** |
| necromancer/ceifador | 5 | Exército Eterno ou Mortos sem Pressa ou Podridão Lenta | **Podridão Lenta** |
| necromancer/ceifador | 20 | Fantasma Longo ou Ceifador | **Ceifador** |
| necromancer/pestilento | 25 | Colheita ou Maldição Longa | **Maldição Longa** |
| necromancer/pestilento | 30 | Filactério ou Praga | **Praga** |

### Medição (boss_probe --party=1, 20 lutas)
| Build | Chefe | Antes | Depois |
|---|---|---|---|
| Cruzado | death_knight, seed 1337 | 7/20 (92 s) | 2/20 (97 s) |
| Cruzado | death_knight, seed 2 | 6/20 (98 s) | 1/20 (88 s) |
| Machados Gêmeos | crab/slime/elf_warden/trent/death_knight | 20/20 em todos; 9,4/9,3/7,8/5,2/79,7 s | 20/20; 9,7/9,0/7,5/4,8/75,7 s |
| Lâminas | idem | 20/20 x4; death_knight 9/20 (75,9 s) | 20/20 x4 (±0,6 s); death_knight **0/20** (1,0 morte) |
| Gelo | idem | 20/20 x4; death_knight 17/20 (64,7 s) | 20/20 x4 (±0,6 s); death_knight 12/20 (62,1 s) |

"Antes" das 3 builds = `after_*` do agente dos talentos (semente 1337, rodada anterior); Cruzado antes = medido nesta rodada.
`boss_probe --build` refaz a teia do bot (`bot_spend` com `fresh`), então as escolhas medidas são as da build forçada.
Tempo das lutas curtas não caiu em lugar nenhum. **Mas a regra NÃO devolveu a força ao Cruzado: piorou** (13/40 -> 3/40), e Lâminas
e Gelo também perderam no death_knight. Hipótese (não medida): death_knight solo é luta de sobreviver; o sorteio antigo dava a 1/3 dos
Cruzados a Determinação (+8% HP, +60 VIT) e à metade o Juiz; a regra nova escolhe sempre opção de skill (Golpe Restaurador, Aura de
Cruzada), e nas Lâminas troca Emboscada/Pelas Costas/Golpe Final/Lâmina Sedenta por Lâmina Envenenada/Toxina Forte/Fuga. Em aberto, para o usuário decidir.

### A/B em grupo: regra nova x sorteio antigo (2026-11-16, só medição)
Pergunta: a regra nova (sem sorteio) atrapalha em GRUPO? O jogo é balanceado para grupo com bots, não pelo solo.
Método: troca temporária em `ClassTalentSystem.bot_pick` (flag `--tp_old` = o sorteio antigo do `git diff`, com `sim.rng`;
`--tp_force=<build>:<opção>` = força uma escolha), desfeita no fim (arquivo voltou byte a byte: md5 igual ao de antes da troca).
O solo old/new reproduziu exatamente a medição anterior (7/20 e 6/20 contra 2/20 e 1/20), então a troca era fiel.
Grupo 4 = `paladin:cruzado,assassin:laminas,elementalist:gelo,bishop:sacerdote`; grupo 5 = `paladin:guardiao` + o grupo 4.
20 lutas por linha, sementes 1337 e 2 somadas (40 lutas). Tempo = média das sementes; baixa (s) e poções por luta.

| Chefe | Grupo | Vitórias novo / antigo | Tempo novo / antigo | Mortes novo / antigo | baixa novo / antigo | Poções novo / antigo |
|---|---|---|---|---|---|---|
| death_knight | 4 | 39/40 / 38/40 | 20,2 / 19,8 s | 0,7 / 0,7 | 0,5 / 0,3 | 2,6 / 2,0 |
| ghoul_giant | 4 | 39/40 / 40/40 | 21,6 / 22,7 s | 0,65 / 0,8 | 0,45 / 0,6 | 2,8 / 2,45 |
| frost_mage | 4 | 40/40 / 40/40 | 21,6 / 21,7 s | 0,75 / 0,65 | 0,45 / 0,45 | 2,85 / 2,45 |
| death_knight | 5 | 40/40 / 39/40 | 28,5 / 30,5 s | 1,0 / 0,95 | 0,55 / 0,75 | 1,65 / 2,0 |
| ghoul_giant | 5 | 40/40 / 39/40 | 27,0 / 29,6 s | 0,25 / 0,5 | 0,4 / 0,95 | 1,85 / 2,7 |
| frost_mage | 5 | 40/40 / 40/40 | 27,5 / 29,7 s | 0,8 / 0,8 | 0,15 / 0,25 | 1,55 / 2,05 |

Em grupo a regra nova não perde: vitórias iguais (118/120 x 118/120 no grupo 4; 120/120 x 118/120 no grupo 5), e no grupo 5
(com tanque) as lutas ficam 2-3 s mais curtas, com menos baixa e menos poções. No grupo 4 (Cruzado de tanque, sem Guardião) fica
empatado dentro do ruído (o novo bebe ~0,4 poção a mais por luta). Pressão `--dmg=4` no grupo 4 (death_knight, ghoul_giant, 20 lutas):
todos morrem em quase todas as lutas (0-2/20 em novo, antigo e Determinação), forte demais para separar; não conclui nada.

Solo Cruzado x death_knight (`--party=1`, 20 lutas por semente):

| Escolhas (linha 5 / linha 20) | seed 1337 | seed 2 | Total | Mortes/luta |
|---|---|---|---|---|
| sorteio antigo | 7/20 | 6/20 | 13/40 | 0,7 |
| regra nova (Golpe Restaurador / Aura de Cruzada) | 2/20 | 1/20 | 3/40 | 0,9 |
| **Determinação** / Aura de Cruzada | 18/20 | 16/20 | **34/40** | 0,15 |
| Golpe Restaurador / **Juiz** | 0/20 | 1/20 | 1/40 | 0,95 |
| Determinação / Juiz | 16/20 | 15/20 | 31/40 | 0,25 |

Quem carregava o solo era a **Determinação** (+8% HP, +60 VIT) na linha 5: sozinha leva o Cruzado de 3/40 para 34/40,
bem acima do sorteio antigo (que dava a Determinação a ~1/3 dos bots). O Juiz não ajuda (piora um pouco contra a Aura).
A troca Golpe Restaurador -> Determinação também não pesou no grupo sob pressão (`--dmg=4`: 0/20 e 2/20 contra 0/20 e 1/20).

**Recomendação: manter a regra, deixando a opção de sobrevivência ganhar em linhas certas de builds certas** — no mínimo
Cruzado linha 5 = Determinação (o Golpe Restaurador cura 12% do Golpe Sagrado, pouco para quem bate de duas mãos sem escudo);
linha 20 continua Aura de Cruzada (ajuda o grupo; Juiz não ganha nem solo). Voltar ao sorteio não se justifica: em grupo
o novo empata ou ganha, e é determinístico. Lâminas e Gelo não foram separados por linha aqui; se o solo deles importar,
o mesmo A/B (`--tp_force`) nas linhas de sobrevivência (Lâminas 25 Fuga x Golpe Final/Lâmina Sedenta; Gelo 25 Fonte x Escudo de Mana) diria qual.
Decisão do usuário (não aplicado).

## Bots: exceções por build (2026-11-16, decisão do usuário: manter a regra + exceções de sobrevivência)

Mecanismo: `ClassTalentsCatalog.BOT_PREFER` ({build: {linha: id da opção}}), lido primeiro por `ClassTalentSystem.bot_choice`
(`level` = a linha; `bot_pick` passa). Check em `_check_bot_talent_prefs`: build de uma classe só, o id existe naquela linha
e vence a nota; Cruzado nv 5 = Determinação (visto falhar com id quebrado, 4 FAIL, e passar depois).

| Build | Linha | Regra pegava | Exceção |
|---|---|---|---|
| paladin/cruzado | 5 | Golpe Restaurador | **Determinação** (`pal_c_resolve`) |
| assassin/laminas | 25 | Fuga | **Lâmina Sedenta** (`ass_c_leech`) |
| elementalist/gelo | 25 | Fonte de Mana | **Escudo de Mana** (`ele_c_shield`) |

Linha 20 do Cruzado continua Aura de Cruzada.

### A/B solo (boss_probe `--party=1`, death_knight, 20 lutas x sementes 1337 e 2 = 40 lutas)
Troca temporária `--tp_force=<build>:<linha>:<id>` (removida; `boss_probe.gd` e `class_talent_system.gd` voltaram ao md5 de antes).
O death_knight é nível 26: só as linhas 5-25 entram (forçar a linha 30 dá exatamente a base).

| Build | Escolha forçada | Vitórias | Mortes/luta |
|---|---|---|---|
| Lâminas | regra (Lâmina Envenenada / Sombra Rápida / Toxina Forte / Sombra / Fuga) | 5/40 | 0,85 |
| Lâminas | 5 Emboscada | 6/40 | 0,8 |
| Lâminas | 10 Bailarino | 12/40 | 0,7 |
| Lâminas | 15 Pelas Costas | 2/40 | 0,9 |
| Lâminas | 20 Dança de Lâminas / Olho Frio | 0/40 / 0/40 | 1,0 |
| Lâminas | 25 Golpe Final | 5/40 | 0,85 |
| Lâminas | **25 Lâmina Sedenta** | **40/40** (84 s) | **0** |
| Gelo | regra (Lança Fria / Coração de Gelo / Elemental Vinculado / Estilhaço / Fonte de Mana) | 24/40 (63,5 s) | 0,35 |
| Gelo | 5 Bola Ardente | 24/40 | 0,35 |
| Gelo | 15 Fusão / Piscar Rápido | 27/40 / 27/40 | 0,3 |
| Gelo | **25 Escudo de Mana** | **36/40** (61,6 s) | **0,05** |
| Gelo | 25 Mente Arcana | 36/40 (57 s) | 0,1 |

Escudo de Mana e Mente Arcana empataram no solo; o grupo desempatou (abaixo).

### Grupo (`--party=5 --comp=paladin:guardiao,paladin:cruzado,assassin:laminas,elementalist:gelo,bishop:sacerdote`, 20 lutas x 2 sementes)

| Chefe | Variante | Vitórias | Tempo | Mortes | Poções |
|---|---|---|---|---|---|
| death_knight | só Cruzado 5 = Determinação | 40/40 | 28,4 s | 1,05 | 1,3 |
| death_knight | Cruzado 5 = Golpe Restaurador (sem exceção) | 40/40 | 28,5 s | 1,0 | 1,65 |
| death_knight | + Lâmina Sedenta + **Escudo de Mana** (adotado) | 40/40 | **26,3 s** | **0,6** | 2,35 |
| death_knight | + Lâmina Sedenta + Mente Arcana | 40/40 | 27,9 s | 1,0 | 1,75 |
| ghoul_giant | as quatro | 40/40 | 26,7-27,0 s | 0,25 | 1,45-1,85 |

O ghoul_giant é nível 23: a linha 25 não entra (as três variantes com Determinação saíram idênticas); a Determinação nele empata.
Em grupo nada piora: com as exceções o death_knight cai ~2 s mais rápido e com ~40% menos mortes; o custo é ~1 poção a mais por
luta (o Escudo de Mana gasta MP). Escolhido Escudo de Mana sobre Mente Arcana pelo grupo (menos mortes, mais rápido).
Não medido: linha 30 (Fantasma/Morte Certa das Lâminas, Arquimago do Gelo) — pede chefe nível 30+.
