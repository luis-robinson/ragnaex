# Porto Esperança — portal na frente de NPC de quest e "muro no meio" (diagnóstico, 2026-11-17)

Só diagnóstico; nada de zona/Blender/catálogo foi mudado. Worktree `post-int2`.

## O que o jogador quis dizer

Porto Esperança (`city_port`), cais. O "mapa anterior" é o Bastião (`field_ruins`): é de lá que o jogador chega de navio.

### A. Portal do navio na boca do cais oeste, na frente da Pescadora Iara

| Coisa | Posição (x, z) | Fonte |
|---|---|---|
| Chegada do Bastião (spawn) | (-3, 52) | `build_city_port.SHIP_ARRIVE` |
| Portal `ship_field_ruins` → Bastião | (-8, 60), raio 1,8 no jogo | `SHIP_PORTAL`, `build()` l.178 |
| Cais oeste (só visual) | x = -8, de z 61 a 96, largura 3,2 | `sea.pier(z, "oeste", (-8, 61), (-8, 96))` l.236 |
| **Pescadora Iara** (`port_vil_fisher`, quests `hx_pe_scales/reef/mother`) | (-7,8, 71), em cima do cais, `reach` +2 m | `MapsCatalog.PORT_VILLAGERS` l.816 |
| Marinheira Dora (`port_sailor`, dá `hx_crossing`) | (-4, 57) | `build_city_port` l.240 |
| Fim da estrada `cais` | (-6, 62) | road `cais` l.233 |

O portal fica **exatamente na cabeceira do cais oeste** (1 m antes da 1ª tábua), alinhado com a Iara (eixo x = -8).
Quem desce do largo do cais para falar com ela anda pelo eixo do cais e entra no anel do portal (o navio leva
para o Bastião) ou tem de contornar o anel pela areia. A própria estrada `cais` termina no portal, então ela
*conduz* o jogador para dentro dele. Do portal (borda em z 61,8) até a água da sim (z 67,8) sobra uma faixa de
areia de ~6 m, e é só dali que dá para falar com a Iara (alcance 2,6 + 2,0 = 4,6 m a partir de z ≈ 66,4).
O arco de pé do portal (anel com r 1,9, `MapBuilder._portal`) ainda cobre a vista do cais na câmera do jogo.

Prova: `production/qa/evidence/port-layout/tour/tour_city_port_13_cais_oeste.png` (o anel "Navio para o Bastião"
na boca do cais; a Iara mais à frente no tabuleiro) e `tour_city_port_00_chegada_navio.png` (chegada).

### B. "Mais à frente tem um muro no meio" — a parede invisível do mar atravessa o cais

O cais é só visual (`sea.pier`: "sobre a água; só visual"). Na sim o mar é um círculo sólido
(`MapGeometry`: lago (0, 172), r 105 − `WATER_SHORE` 0,5 = 104,5), sem vão para o cais. Em x = -8 a água
começa em **z = 67,8**: quem contorna o portal e sobe no tabuleiro bate numa parede invisível a ~7 m da
cabeceira, enquanto o cais desenhado segue até z = 96. É a única coisa sólida "no meio do caminho" nessa área.
O mesmo vale para o cais leste (água a partir de z ≈ 67; pescador Duarte, sem quest).

Descartados (conferidos no JSON): nenhum obstáculo sólido (`wall`/`box`/`Dress.solid`) cruza alguma estrada
do porto; os 23 colisores `if: hx_palisade` estão só nos vãos da paliçada (198–245°, 25–60°), longe das estradas;
os portões têm ~7,8 m livres entre as torres. Se o jogador falava de outro lugar, o candidato seguinte não existe
nos dados — perguntar a ele (ver "Pendente").

### Vizinhos (mesma checagem)
- Costa (`field_coast`): portal `coast_to_port` (110,3, 15,5), chegada (101,4, 14,2); o NPC mais perto é o
  Santuário Afogado a 18,5 m (sem quest). Sem problema.
- Bastião (`field_ruins`): portal `to_city_port` (100,7, -27,0); Capitão Bren a 3,4 m dele (sem quest; portal com
  portão só avisa). Sem problema de quest, mas o mesmo padrão "NPC colado no portal".

Desenho de cima: `production/qa/evidence/port-layout/cais_topdown_annotated.png` (16 px/m, x -26..26, z 38..100,
mar para baixo). Legenda (o renderizador de SVG não desenhou os textos): círculo azul = portal; tira marrom = cais;
bolinha amarela no cais = Iara com o alcance de fala tracejado; bolinha amarela acima do portal = Dora;
triângulo verde = chegada; linha laranja = caminho reto até a Iara (passa no portal); tracejado vermelho = onde
a água da sim começa (parede invisível); cinza = colisores.

## Causa raiz
1. `build_city_port.py`: `SHIP_PORTAL = (-8.0, 60.0)` foi posto "no pé do cais" e o `sea.pier(... "oeste", (-8, 61) ...)`
   começa 1 m depois, no mesmo eixo; a estrada `cais` acaba no portal. Depois disso a Iara (quest) foi posta
   no cais oeste (`PORT_VILLAGERS`, posto = vara do cais oeste) sem conferir o portal.
2. `sea.pier` é só visual e `MapGeometry` não abre vão no lago para cais → o tabuleiro parece andável e não é.

## Proposta (não implementada)
Recomendado — **A1 + B1**:
- **A1. Tirar o portal da boca do cais**: o navio de volta vira o navio "chegada" (−17, 86), que já está no cais
  oeste; pôr o portal na areia ao lado, fora do eixo dos píeres e da faixa da Iara, p.ex. **(-15, 58)**
  (borda do largo, entre o largo e a vara do Anselmo (−13,1, 65,5); conferir ≥ 3 m do Anselmo e das rochas
  (−15,5, 64,6)), e a estrada `cais` deixa de terminar no portal (termina no largo, `(-2, 56)`), com um ramal curto
  para o portal. Alternativa mais simples: portal no lado LESTE do largo, (8, 56) — mas lá estão as caixas
  (4,5–7,7, 59–60,6) e o pilar (7,6, 62,6); exigiria mover as caixas.
  Ficção: "a prancha do navio" — o portal fica no fim de uma passarela curta para o navio, não na cabeceira do cais
  em que os pescadores trabalham.
- **B1. Cais sem parede no meio**: ou (a) a sim ganha "chão andável sobre água" por cais (retângulo que cancela
  a água; regra nova em `MapGeometry`, é mudança de sistema → decisão do usuário/`technical-director`), ou
  (b) mais barato e dentro da regra de hoje: encurtar os cais visuais até onde a sim deixa andar não serve (o
  navio precisa de cais); então **(c) recomendado barato**: uma barreira visual na linha da água (corrente/portão
  de tábuas, "cais dos pescadores — só tripulação") em z ≈ 67,5 nos dois cais, para a parede ter cara de parede.
  A Iara continua falável da areia (já é assim).

Alternativa A2 (sem mexer na zona): mover a Iara para a vara da areia `PORT_SHORE_POLE` (−3,5, 66,6) — tira a quest
de trás do portal, mas o portal continua na boca do cais e a estrada continua levando para dentro dele.

## O que a mudança toca
- `build_city_port.py` (`SHIP_PORTAL`, road `cais`, `z.block(SHIP_PORTAL, 5.0)`) → refazer `map_city_port.glb` +
  `data/zones/city_port.json`; a **dispersão muda** (o `block` muda de lugar; tufos/rochas da areia oeste e
  `act2_dress.port` re-sorteiam onde o `Dress.ok()` deixa) — conferir o diff do JSON.
- `act2_dress.port`: varas (`PORT_SHORE_POLE`) e lotes do cais; a barreira de B1(c) entra aqui como enfeite
  (`Dress`, sem colisor: a água já é sólida). Escolher um vão da pilha de planos se tiver mancha nova.
- `build_field_ruins.py`: `PORT_ARRIVE` não muda (é a chegada (-3, 52), não o portal). `BASTION_ARRIVE` não muda.
- `_check_places`/`_check_world_layout`/`_check_zone_dress`/checks de portal (portal sem obstáculo sólido, chegada
  andável) e `_cross_river` não devem quebrar, mas rodar a suíte. Adicionar check: "nenhum NPC com quest a < 6 m
  de um portal não-porta, e o segmento chegada→NPC não cruza o raio do portal".
- `z.data['raid']`: não toca (investida é no norte).
- Hangouts dos bots (3, 54) e (−6, 53): ficam; conferir que nenhum fique a < 3 m do portal novo
  (bots que passeiam no largo podiam entrar no navio sem querer — vale medir hoje também).
- `DevRunner.TOURS["city_port"]` (`cais_oeste`) e `loading_art.py` (`ZONES`: câmera/chão não mudam; refazer o
  `.jpg` só se o portal novo aparecer na foto). Mapa de bordo do `roteiro` se citar o cais.

## Pendente
- Confirmar com o usuário que o "muro no meio" é o fim invisível do cais (B). É a única barreira sólida nos dados
  ao longo do caminho chegada → cais → Iara.
