---
name: build-models
description: Gera/atualiza os modelos 3D (personagens, monstros, props) no Blender via MCP e exporta GLB para assets/models (/build-models [personagens|monstros|props|<nome>]).
---
Delegue ao subagente `blender-modeler` com o argumento recebido (`$ARGUMENTS`; vazio = tudo via `build_all.run`).
Antes, verifique se o MCP `blender` responde (`get_scene_info`); se não, instrua o usuário a abrir o Blender e clicar "Connect to Claude" no painel BlenderMCP.
Ao final, rode `/test` para garantir que os GLB carregam sem `SCRIPT ERROR`.
