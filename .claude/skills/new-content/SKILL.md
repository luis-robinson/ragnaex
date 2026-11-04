---
name: new-content
description: Cria conteúdo novo (skill, classe, monstro, mapa, quest, receita, item) seguindo os catálogos e adicionando testes (/new-content <tipo> <descrição>).
---
Interprete `$ARGUMENTS`:
- skill, classe, arma/equipamento, atributo, feel de combate → `class-designer`
- monstro, boss, mapa, cidade, campo, quest, receita, loot, loja, bot → `world-builder`
- modelo 3D/animação → `blender-modeler`
Peça ao agente escolhido para: editar o catálogo certo, adicionar `check(...)` nos testes, rodar `--import` + testes + smoke, e listar o que mudou.
Depois rode `/review` sobre o diff.
