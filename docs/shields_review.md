# Revisão dos escudos

Folha: `tools/lineup/lineup.tscn -- --shields --anim=idle --shot=<png>` (câmera ortográfica com o ângulo do jogo: paladino, bispo e o paladino de costas).
Bloqueio no jogo: `-- --autostart=paladin --block_shot=<png> --shield=<id>`.

Nota 0-2 em cada critério; passa com 8 ou mais. A nota é minha, olhando a folha: não vale como teste de jogador.

## O que cada iteração mudou

1. Modelos novos, montagem antiga: da câmera alta o escudo virava uma lasca. A face apontava para dentro e para a frente.
2. Montagem nova, para fora do braço e inclinada para cima: o desenho apareceu. Foi a maior mudança de toda a revisão.
3. Inclinação maior (`SHIELD_TILT`) e folha ortográfica, que tirou o falso problema das colunas da direita.
4. Escudos 28% maiores (`SHIELD_SCALE`); Relicário e Prisma ganharam tamanho próprio.

5. Um modelo por escudo (18), com primitivas curvas (`band`, `scroll`, `gem`, `rib`) depois de estudar os tiers altos do Priston Tale.
6. Joias de cor fixa, mais massa e ouro próprio dos escudos; ícones fotografados do modelo, para nunca divergirem.
7. Bloqueio: o escudo aberto para fora em vez de erguido. Erguer o antebraço virava a face para o chão, em qualquer giro.
8. Últimos ajustes: Gaia, Castelo, Asa, Pântano e as costelas douradas do Muro.

## Notas independentes

Revisor sem contexto, sobre as folhas de cada rodada, nota de 0 a 10:

| Rodada | Média | Abaixo de 7 |
|---|---|---|
| Modelos únicos | 6,7 | 5+ |
| Corpos escuros e modelos refeitos | 7,2 | 7 |
| Massa, joias e ícones | 7,6 | 4 |

A passada 8 veio depois da última nota e não foi avaliada. Layout estimado em 70-75% da referência e acabamento em 30-35%: pintura de metal, gravura e brilho de joia pedem textura, não geometria.

Depois disso: contorno soldado (`shield_kit.hull`) acabou com os traços soltos; giro por escudo (`SPINS`) e suporte próprio (`wpn_off_grip`) tiraram topo e pontas de cima da cabeça e do braço. Duas notas independentes seguintes deram 8,0 e 7,9 no desenho e reprovaram a montagem; a última, 6,9, puxada pela barra que cruzava a face. A correção dessa barra veio depois e não foi avaliada.

Contato medido por `tools/blender/shield_clip.py` (clipes do GLB, corpo e armadura de placa). Ele não vê a sobreposição na tela, então a checagem final continua sendo a folha do `lineup --shields`. Zero contato com o escudo longe do braço foi pior: virou maça num bastão.

Tamanhos finais: `SHIELD_SCALE` 1,16 e `SIZES`/`INNER` por escudo. Contato zero nas 95 medições de `shield_clip.py` (corpo e placa pesada, idle e bloqueio) com o suporte mais curto. `INNER` encurta só o lado do braço: um escudo de nível alto perde o contato sem perder tamanho.

## Animação do bloqueio

Clipes separados: `block_shield` (guarda com escudo) e `block` (sem escudo, arma à frente do rosto). A face do escudo aponta para o cotovelo: erguer o antebraço a vira para o chão, então a pose saiu de uma busca por cinemática direta, não de tentativa. Andando, `LegOverlay` mexe as pernas. Filme real: `lineup.tscn -- --block_film --shot=<png>` (erguer, soltar e andar, com a mesma mistura da `EntityView`).
