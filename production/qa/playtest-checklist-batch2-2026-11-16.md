# Playtest — adendo batch 2 (2026-11-16)

Complementa `playtest-checklist-2026-11-15.md` (roteiro, saves e formato de relato valem iguais). Batch 2 =
(a) arcos/rastro de golpe por família de arma + formas do Druida (lobo/urso/Alfa/Ent), (b) Alfa/Ent refeitos sem
furar o chão + sair do jogo sem vazamento, (c) escudo alto com corrida e guarda próprias (+ aparo leve no cotovelo, se
já entrou). Fontes: `attack-arcs-rollout-plan.md`, `attack-arc-colours.md`, `attack-arcs-wave6-spec.md`, notas
`agent-arcs-wave1..6.md`, `agent-post-int2.md`, `tall-shield-guard-study-2026-11-15.md`.
**Pré-requisito:** rodar na build integrada (post-int2 + attack-arcs). Sem `.exe` novo: `.\tools\godot.ps1 --path . -- <flags>`.

## 1. Arcos de golpe (8-10 min)

Atalhos (segure LMB num grupo de monstros; use 1-6 para as skills):
- Espada/maça 1M e 2M: `-- --autostart=paladin --level=30` · Machados (2M, Titã, pares): `--autostart=berserker --level=30`
- Lança: `--autostart=ranger --level=30` (build Lanceiro) · Adagas/garras/pares: `--autostart=assassin --level=30`
- Foice: `--autostart=necromancer --level=30` · Cetro/cajado (controle, deve ficar igual): `--autostart=bishop` / `elementalist`

- [ ] Cada golpe físico mostra UM desenho claro no impacto: crescente deitado (espada/maça), crescente em pé (2M e golpes
      de cima), cunha fina (estocada de lança), dois fiapos (duas armas), anel (giro)
- [ ] O lado do arco acompanha a lâmina (golpe da direita → arco corre para a esquerda e vice-versa); giro sempre no mesmo sentido
- [ ] Cor da família: aço frio (espada), aço quente (maça), ferro escuro com borda clara (machado/foice), rosado (garra);
      golpe de sangue (Berserker/Lanceiro) **suave**, não vermelho estourado
- [ ] Parada no impacto (hit-stop) sente-se mais pesada no 2M/machado e quase nada na adaga; nunca "trava" o boneco
- [ ] Marca no chão some rápido (≤ 0,2 s) e nunca vira anel ou disco cheio (isso é aviso de chefe)
- [ ] Magia (cajado/cetro/básico mágico da foice) continua com o rastro colorido antigo, sem arco
- Reportar: arma/skill, câmera (perto/longe), print no impacto; "arco do lado errado", "some atrás do corpo", "confunde com aviso de chefe"

## 2. Formas do Druida (6 min)

- Lobo/urso: `-- --autostart=druid --level=30` (skills de forma na barra) · Alfa/Ent: `-- --autostart=druid --ascend --level=45`
  (ascensão nas vagas 7, 8, 9, 0). Alternativa por conjunto: `--gear=<set_id> --form=wolf|bear`.
- [ ] Ataques de forma deixam **riscos de garra no chão** (3 riscos / mordida em V) na direção do golpe, não 5-7 m à frente
- [ ] Investida (pounce/estouro): os riscos aparecem **onde a forma pousa**
- [ ] Golpe em alvo (garra/mordida) mantém o corte em X sobre o alvo; golpe em cone empurra os riscos para a borda do cone
- [ ] Ent: pisão (slam) com duas marcas de pé; Golpe de Galho com crescente em pé + gancho do braço; cor casca/musgo (#C7CCBF)
- [ ] **Alfa e Ent não afundam no chão** em slam/maul/pounce (patas e braços acima da grama); antes o Ent sumia ~0,4 m
- Reportar: forma + skill, se os riscos ficam escondidos sob a cabeça/alvo (de costas para a câmera), print

## 3. Sair do jogo (3 min, rode pelo console para ver o log)

- [ ] Título → Sair → confirmar: fecha em < 1 s
- [ ] Título/Personagens/Criação → **X da janela**: fecha pelo mesmo caminho (sem travar, sem tela preta)
- [ ] No jogo → Esc → Sair: salva e fecha (o card abre normal depois, não "Save danificado")
- [ ] No jogo → X da janela: salva e fecha
- [ ] Log ao fechar **sem** `resources still in use` / `AudioStreamMP3` / `leaked`; música para limpa, sem estalo
- Reportar: de qual tela, como saiu, as últimas 10 linhas do console

## 4. Escudo alto (5 min)

- Paladino: `-- --autostart=paladin --level=30`; foto rápida da guarda: `--block_shot=<png> --shield=muro_suspiros`
  (também `palavra_deus`, `alado_negro`; Bispo: `--autostart=bishop ... --shield=abraco_criador`).
  Comparar sem jogar: `tools/lineup/lineup.tscn -- --shields --styles=suspiros,veredito --anim=run` (`--plain` = clipe antigo).
- [ ] Correndo, o braço do escudo balança pouco e o escudo **não bate no elmo** (antes batia na ida do braço)
- [ ] Guarda (bloqueio) mais baixa, escudo inclinado para fora; escudo rente ao antebraço, sem vão de mão
- [ ] Escudo pequeno/médio continua com a corrida e a guarda de antes; a cavalo, guarda alta também usa a pose nova
- [ ] Trocar de escudo (alto ↔ comum) troca a pose na hora, sem pulo de animação
- Reportar: nome do escudo, classe/sexo, conjunto vestido, clipe (corrida/guarda/montado), print de lado e da câmera do jogo

## 5. Conhecidos (não reportar)

- Areia da costa: arco claro lê fraco sobre areia clara (decisão pendente). Crescente do Ent aparece mais como cauda sobre a cabeça.
- Escudos altos já descem abaixo do chão em guarda/corrida (0,1-0,6 m, sob o pé; antigo); `veredito` e `asa_negra` ainda afastados.
- Alfa: emenda de clipe em maul/pounce/slam (preço das garras acima do chão).
