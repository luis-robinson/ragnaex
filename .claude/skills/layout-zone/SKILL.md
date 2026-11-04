---
name: layout-zone
description: Loop de layout de uma zona estilo Erenshor até nota ≥ 8 (/layout-zone <zona — descrição>). Ex.: /layout-zone Aldara + Campina — hub murado, floresta ao norte, ruínas a leste, lago ao sul.
---
Use a skill `blender-layout`. Zona: $ARGUMENTS.

Loop até o layout estar bom:
1. Construa/refine a blocagem pelo script `tools/blender/zones/build_<zona>.py`.
2. Tire as screenshots `CAM_top`, `CAM_game` (hub) e `CAM_poi` (um POI).
3. Avalie os 5 critérios (0–2 cada): legibilidade, fluxo, ritmo, borda/altura, multidão. Escreva a nota e o que está fraco.
4. Se total < 8: corrija SOMENTE os pontos fracos e volte ao passo 2. Se travar 2 iterações no mesmo problema,
   mude a abordagem (ex.: "mude o hub de lugar" em vez de "melhore o fluxo").
5. Com total ≥ 8 (ou após 6 iterações): exporte `map_<zona>.glb` + `data/zones/<zona>.json`, ligue no `maps_catalog.gd`,
   rode `--import`, testes e smoke, faça um tour de screenshots no jogo e mostre a última screenshot com o resumo
   das iterações (nota de cada uma).

Não peça confirmação entre iterações.
