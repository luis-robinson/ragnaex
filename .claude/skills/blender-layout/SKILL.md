---
name: blender-layout
description: Constrói ou refina o layout de uma zona no estilo Erenshor (vale fechado, vila murada no hub, estradas curvas, rio com pontes, POIs com marcos) no Blender via MCP, vista pela câmera alta do RagnaEx. Use ao criar/ajustar zonas, cidades, campos ou dungeons, ou quando o usuário pedir "layout".
---
Regras completas em `.claude/docs/ragnaex/zonas.md` → "Layout de zonas" (importado pelo `CLAUDE.md`). Referência visual e de código:
`C:\Users\luisf\Desktop\projects\erenpg\blender\scripts\build_vale_inicial.py` (terreno, catmull, rio, vila murada)
e o minimapa `C:\Users\luisf\Desktop\projects\erenpg\godot\assets\maps\vale_inicial.png`.

# Fluxo
1. `get_scene_info` + `bpy.data.filepath`: se houver um `.blend` de outro projeto aberto, NÃO salve nem apague nada dele —
   trabalhe numa cena nova (`bpy.data.scenes.new("RagnaEx_<zona>")`) ou peça para o usuário abrir um arquivo vazio.
2. Script em `tools/blender/zones/build_<zona>.py` (fonte da verdade; reexecutável): reconstrói só a Collection
   `Z_<zona>` + marcadores `OB_*`/`SPAWN_*`/`TRIG_*` da zona. Tudo por loops (catmull para estradas/rio, anéis para
   muros e penhascos, dispersão por ruído para árvores) — nunca objeto a objeto à mão.
3. Blocagem primeiro (cores lisas: chão verde, estrada bege, vila cinza, água azul, penhasco marrom). Detalhe
   (props do `prop_kit`, telhados, vegetação) só depois da nota ≥ 8.
4. Sempre colocar: hub murado no centro com praça e portões; 3–5 POIs a 60–120 m; estradas curvas hub↔POI e entre
   POIs; borda natural fechando o vale; rio/lago com pontes; landmark; portais nas gargantas da borda;
   `SPAWN_player_01`, `SPAWN_hangout_*` (6–12 no hub e POIs), `SPAWN_mob_<id>_NN` por POI, `SPAWN_npc_*` no hub.
5. Colisão: todo sólido andável-bloqueante tem um `OB_box_*`/`OB_circle_*` simples (a sim não lê malha).
   Penhascos da borda viram uma corrente de `OB_box` seguindo o anel.
6. Câmeras: `CAM_top` (ortográfica, cobre a zona), `CAM_game` (perspectiva FOV 35, pitch 52°, 24 m do alvo,
   olhando o hub) e `CAM_poi` (igual, num POI). Alterne com `bpy.context.scene.camera` e use `look`.
7. Avalie (0–2 cada): legibilidade, fluxo, ritmo, borda/altura, multidão. Escreva a nota e os pontos fracos.
8. Exporte o visual: só a Collection `Z_<zona>` (sem `OB_*`/`SPAWN_*`/`TRIG_*`) para
   `assets/models/map_<zona>.glb`; marcadores para `data/zones/<zona>.json` (posição xz em metros, tamanho,
   rotação em graus, ids). Eixos (export glTF Y-up): Blender (x, y, z) → jogo (x, z, -y); ou seja, no chão
   `pos_jogo = Vector3(x_b, 0, -y_b)` e rotação em Z do Blender = rotação em Y do jogo (mesmo sinal). A frente
   dos modelos é -Y no Blender (= +Z no jogo).
9. No Godot: `MapDef.model = "map_<zona>"`, `maps_catalog.gd` lê o JSON; `--import`, testes, smoke e um tour de
   screenshots pela zona com a câmera do jogo.

# Não fazer
- Mapa quadrado com caminhos em cruz/grade; borda reta visível; estrada reta hub→POI.
- Prometer subir rampa/colina: a sim é plana (y = 0). Altura é só visual (obstáculo sólido).
- Prédios altos colados nas estradas perto do hub (escondem o jogador com a câmera alta).
