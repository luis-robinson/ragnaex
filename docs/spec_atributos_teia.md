# Spec: atributos na teia (caminho +1, círculo +5, fundo +10)

**Status:** a fazer. A tentativa de 2026-11-07 foi descartada sem commit: não compilava e não foi calibrada. O estado atual é o commit `3b102d2`: estradas não dão nada e o círculo dá +1.

## Pedido
- Os caminhos (estradas e junções da teia) devem dar pelo menos um pouco de status relevante, por exemplo **+1 FOR**. O atributo depende da classe e do setor.
- Dentro dos nódulos (círculos), os nós dão **+5**.
- Quanto mais avançado na teia, mais dão, até **+10**.

## Problema
Na escala de hoje, 1 ponto de atributo vale muito. Com 8 pontos por nível (235 no nível 30), um bot compra cerca de 200 nós.
- Só +1 por nó já dava **×2-2,7 de ATK e ×2-3 de HP** (medido com `tools/tests/web_probe.tscn`).
- +5/+10 por nó, sem mudar a escala, quebraria o jogo.

## Solução: escala nova de atributos
- `Balance.ATTR_SCALE = 10`. Cada ponto de atributo vale 1/10 do antigo.
- **Equipamento:** os números do catálogo continuam na escala antiga e são multiplicados ao carregar.
  - Em `GameData.load_all`, depois do `GearCatalog`: `it.attributes[a] *= ATTR_SCALE`.
  - As telas mostram os números novos sozinhas. Uma peça que dava FOR +9 passa a mostrar FOR +90, com o mesmo efeito.
- **Conjuntos:** em `Stats.compute`, `s.attrs[a] += int(ba[a]) * ATTR_SCALE`. Em `UiKit.set_bonus_text`, o texto também ×ATTR_SCALE.
- **Conversão:** em `Stats.compute`, `FOR := s.attrs["FOR"] / float(ATTR_SCALE)` (idem para AGI/VIT/WILL/INT).
  - Atenção: declarar com tipo explícito, `var FOR: float = ...`. Com `:=` o Godot não infere o tipo de `attrs[...]`; foi esse o erro de parse da tentativa.
- **Talentos de classe:** `stats.attr_*` estão escritos na escala antiga. Multiplicar por ATTR_SCALE em `TreeCatalog._class_picks`.
- **Notáveis do catálogo:** os `attr_*` de `RING_NOTABLES` estão na escala antiga. Em `_scaled`, ×5 (ou ×ATTR_SCALE, a calibrar).
- **Aprimoramento +N** (`Stats.plus_attr`): usa a base já escalada. Conferir se o piso `pl / 3` não fica pequeno demais na escala nova; talvez ×ATTR_SCALE.

## Valores da teia (escala nova), em `data/catalog/tree_catalog.gd`
| Nó | Atributo |
|---|---|
| Estrada / junção | +1, atributo do setor (`ROAD_ATTR`) |
| Nó de círculo (entrada do círculo de skill; 3 de 5 do anel do notável) | +5 perto do início até +10 no fundo (`CLUSTER_ATTR = (5, 10)`) |
| Os outros 2 do anel do notável | +1 (como a estrada) |
| Notável (atributo principal) | +10..+20 pela profundidade (`NOTABLE_ATTR`) |

Profundidade: `_depth(c, intervalo)` com `t = clamp((|c| - CELL) / (CELL * (GRID_K - 1.5)), 0, 1)`, interpolando entre o mínimo e o máximo.

## Calibração (obrigatória)
- **Alvo:** `web_probe` no nível 30 em torno de **×1,4 de ATK e ×1,2 de HP** para um bot da build, igual ao de hoje.
- `boss_probe --party=1 --trials=10` perto da faixa atual:

  | Chefe | Vitórias solo |
  |---|---|
  | Conde Vargo | ~2/10 |
  | Lich | ~3/10 |
  | Cavaleiro da Morte | ~5/10 |
  | Mago Gélido | ~7/10 |

- Se passar do alvo, baixar primeiro `NOTABLE_SCALE` e os passivos de papel (×0,3), e só depois os intervalos de atributo.
- **Testes que podem mexer:**
  - "arma +9 bate mais";
  - valores de conjunto (`SET_*_ATTR`);
  - o check de coerência de atributos dos itens;
  - `_check_tree` (nós de atributo, rótulos).
- **Save:** os itens são escalados na carga, então o save não muda (guarda ids, não números).

## Revisar no fim
- `--bag_shot=<png> --wins=inventory,character`: números de atributo grandes na bolsa e na ficha.
- `--wins=skills --level=25`: rótulos +1/+5/+10 na teia.
