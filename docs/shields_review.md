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

Depois disso: contorno soldado (`shield_kit.hull`) acabou com os traços soltos; giro por escudo (`SPINS`) e suporte próprio (`wpn_off_grip`, que não existe mais: ver "Montagem rente") tiraram topo e pontas de cima da cabeça e do braço. Duas notas independentes seguintes deram 8,0 e 7,9 no desenho e reprovaram a montagem; a última, 6,9, puxada pela barra que cruzava a face. A correção dessa barra veio depois e não foi avaliada.

Contato medido por `tools/blender/shield_clip.py` (clipes do GLB, corpo e armadura de placa). Ele não vê a sobreposição na tela, então a checagem final continua sendo a folha do `lineup --shields`. Zero contato com o escudo longe do braço foi pior: virou maça num bastão. Essa montagem afastada (0,29 m do antebraço, duas hastes douradas) valeu até 2026-11-15.

Tamanhos finais: `SHIELD_SCALE` 1,16 e `SIZES`/`INNER` por escudo. Contato zero nas 95 medições de `shield_clip.py` (corpo e placa pesada, idle e bloqueio) com o suporte mais curto. `INNER` encurta só o lado do braço: um escudo de nível alto perde o contato sem perder tamanho.

## Montagem rente (2026-11-15)

A montagem afastada deixava 0,16-0,22 m de ar entre o antebraço e as costas da placa em 42 dos 43 estilos. Agora todo escudo do jogador tem a sua montagem em `chibi_kit.SHIELD_MOUNTS` (mesma rotação de antes; muda só a distância, a descida e o deslocamento ao longo do braço), achada por `tools/blender/shield_mount_study.py` e gravada por `shield_mount_apply.py`. A regra da busca: nenhum toque no corpo comum em idle, corrida e guarda (a do `shield_mount.py -- --check`, em mais quadros); depois, o menor afastamento.

- 26 estilos ficam encostados (0,01-0,05 m de ar), 7 a meio caminho (0,07-0,11 m) e 10 continuam afastados (0,13-0,19 m): os de 1,3-1,6 m com pontas ou asas do lado do braço, que mais perto entram na cabeça na guarda.
- O suporte `wpn_off_grip` (e o `wpn_off_grip_tabuas`) saiu. No lugar há uma alça (tira de couro no antebraço + dois calços de ferro) soldada na malha de cada escudo (`kit_shield_strap`): nenhuma malha a mais; o kit do paladino tem 195 e o do bispo 175 (eram 197 e 177).
- A alça é aparada na silhueta da placa (`STRAP_CLIP`): em 11 estilos estreitos, recortados ou com o braço perto da borda (`asa`, `sol`, `presa`, `prisma`, `escama`, `veredito`, `cruel`, `pal_g25`, `pal_g30`, `bis_s25`, `bis_b25`) ela passava da placa e aparecia de frente e no ícone; ali vira meia braçadeira ou calço mais curto. De cima e de trás o braço e a alça continuam à vista, como devem.
- Monstros com escudo (`mob_kit.humanoid`, escudo-torre de Kharzun) ficam na montagem afastada, sem alça: a rente foi medida só no corpo do jogador.
- Custo: a placa rente encosta mais em elmos e peitorais de conjunto na guarda (escondido atrás da própria placa); não foi revisto conjunto a conjunto no jogo.

Números por escudo, folhas antes/depois e o que ficou em aberto: `production/qa/shields-mount-2026-11-15.md` e `production/qa/evidence/shields-mount/`. As notas das seções acima são da montagem antiga; a rente não passou por revisor independente.

## Animação do bloqueio

Clipes separados: `block_shield` (guarda com escudo) e `block` (sem escudo, arma à frente do rosto). A face do escudo aponta para o cotovelo: erguer o antebraço a vira para o chão, então a pose saiu de uma busca por cinemática direta, não de tentativa. Andando, `LegOverlay` mexe as pernas. Filme real: `lineup.tscn -- --block_film --shot=<png>` (erguer, soltar e andar, com a mesma mistura da `EntityView`).
