# Playtest — build post-int (2026-11-15)

O que mudou desde o master `39b41b8`: fluxo de início novo (splash, título, lista, criação, carregamento), save atômico,
spawn de bots ~17 s → ~1 s, arte de carregamento por zona, revisão r5 do Kharzun, polimento de UI, **balanceamento do
nível 45 (bal45)** e o **ramo de arte**: machados refeitos (inclusive Ghar/Durgash e o Machado do Trono), escudos rente
ao antebraço (43), armas sem furar o chão. Fontes: `production/commit-plan-post-int.md` (18 commits),
`design/ux/start-flow.md` (§ Implementação). **Não** estão nesta build: os arcos de golpe novos.

## 1. Como abrir

- Exe: `.claude/worktrees/post-int/build/windows/RagnaEx.exe` (pck embutido). Duplo clique, sem flags.
- Saves: `%APPDATA%\Godot\app_userdata\RagnaEx\save_<n>.json` (5 espaços, `save_0..4`) — os MESMOS do jogo rodado
  pelo projeto. Os personagens que você já tem aparecem na lista. **Copie a pasta antes** (o passo 8 exclui personagens).
- Novo nesta build: gravação via `save_<n>.json.tmp` + renomear e retrato `portrait_<n>.png` na mesma pasta.
- Formato do save não mudou: saves antigos devem abrir.
- Nível 45 sem personagem próprio (não grava): `RagnaEx.exe -- --autostart=berserker --ascend --level=45`.

## 2. Roteiro (25-35 min)

1. **Abertura** (30 s): o logo (splash) aparece logo após o duplo clique; anote o tempo até o título.
2. **Título** (1 min): logo, acampamento com fogueira, música de Aldara. ↑/↓ e Enter; abra Configurações
   (gráficos, volumes, dicas), feche com Esc. Sair → "Sair do jogo?" → cancele.
3. **Personagens** (2 min): Jogar. Lista de 5 cards com retrato/classe/nível/mapa; ←/→ troca e o boneco no pedestal
   acompanha; card vazio mostra a silhueta. Num card ocupado, aperte **Enter duas vezes rápido**: só uma carga.
4. **Criar personagem** (4 min): card vazio → Criação. Passe por 3-4 classes (o boneco toca a skill-assinatura em laço).
   Arraste para girar, roda aproxima. Passo Visual: abas Corpo/Cabelo/Rosto, nome + sorteio. Esc volta um passo.
   Termine com um **Berserker** (machado) ou **Paladino** (escudo) → Começar aventura.
5. **Carregamento** (~10 s): arte da zona, barra que só avança, texto da etapa, dica. Anote o tempo clique → jogo.
6. **Aldara** (4 min): praça; tapete na porta da Botica; nomes sobre NPCs e bots; painéis de chat/Quests opacos.
   Olhe escudos e machados nos bots e sentinelas de perto.
7. **Combate** (8 min): campo, LMB, skills 1-6, dash. Pontas de arma no chão em salto/finalização/dash;
   "Esquiva!" juntando em "×N". Berserker: dash várias vezes e pare para ver a pose final. Druida: lobo e urso.
8. **Esc → "Salvar e voltar ao menu"** (2 min): volta à lista com o seu card selecionado e retrato novo.
9. **Continuar e excluir** (3 min): Jogar no mesmo card → mesmo mapa, nível, bolsa. Exclua um personagem de teste.
   Com a pasta de saves copiada, deixe só 1 personagem e exclua-o: deve ir direto para a Criação.
10. **Nível 45** (opcional, 10 min): com a linha `--autostart ... --level=45`, lute contra Kragmar ou Durgash
    (Kharzun) com bots. Anote vitória/derrota e tempo aproximado.
11. (Opcional) Feche a janela no meio do jogo e reabra: o card deve abrir normal, não "Save danificado".

## 3. O que observar

**Fluxo de início**
- [ ] Splash com logo logo após abrir; nada de tela preta longa antes do título
- [ ] Enter = ação principal e Esc = voltar em todas as telas; o foco nunca some depois de trocar de tela
- [ ] Enter duplo (ou duplo clique) em Jogar/Começar aventura inicia **uma** carga só
- [ ] Duplo clique num card ocupado = Jogar; Delete = Excluir
- [ ] Transições de câmera suaves (0,6 s) e puláveis com clique/Enter
- [ ] Criação: boneco grande, cabeça inteira; pés/pedestal acima da barra do nome (16:9 e, se tiver, 21:9)
- [ ] Versão no canto do título: "RagnaEx Ato II — protótipo"

**Carregamento / arte**
- [ ] Arte certa para o mapa do personagem (26 zonas); nada esticado ou preto
- [ ] Barra nunca volta; segura em 100% e corta para o jogo sem tela cinza

**Save / exclusão**
- [ ] Voltar ao menu salva (nível, mapa, bolsa batem ao continuar)
- [ ] Excluir: Cancelar com foco, Esc cancela, Excluir em vermelho; retrato some junto
- [ ] Excluir o **último** personagem leva direto à Criação (não a 5 cards vazios)
- [ ] Nenhum card some ou fica impossível de usar/excluir

**Machados**
- [ ] Machados do Berserker e dos chefes Ghar/Durgash com lâmina nova (crescente/barbuda/dupla), sem cara de porrete
- [ ] Machado do Trono (prop da luta) com a lâmina nova
- [ ] Brilho do fio do Berserker **suave e na cor do conjunto** (não pêssego desbotado, não estourado)
- [ ] Ícones dos machados e da skill de machado batem com o modelo

**Escudos**
- [ ] Escudos do Paladino/Bispo colados ao antebraço esquerdo em idle, corrida e bloqueio; alça curta, sem haste dourada solta
- [ ] Escudos grandes com espinhos/asas: um pouco afastados é esperado (ver § 4); anote se algum **flutua** ou atravessa o corpo
- [ ] Monstros com escudo: montagem antiga (longe do braço) é esperada; anote só se o escudo sumir ou girar errado

**Armas / animação**
- [ ] Armas não furam o chão em ataque, cast e dash (todas as classes)
- [ ] Fim do dash do Berserker: o machado **não** gira por trás do corpo na pose final
- [ ] Lobo/urso: patas da frente sem virar ao contrário em maul/pounce/slam

**Polimento de UI**
- [ ] Nomes: tamanho constante com a distância, acima de modelos altos, escondidos sob os painéis do HUD
- [ ] Grito de chefe aparece na faixa do HUD (não como balão solto)
- [ ] "Esquiva!" sem texto fantasma ao lado do ×2; sem anel de aura sob monstros hostis

**Nível 45 (bal45)**
- [ ] Build no 45 sente-se forte, sem skill/nó de ascensão sem efeito visível
- [ ] Kragmar/Durgash vencíveis com bots (referência: ~+2-3 e ~+1-2 vitórias em 20 lutas; Durgash 10-14% mais curto)
- [ ] Ulgra/Gorbash: sem mudança esperada; anote se algo parecer bem mais fácil ou difícil

**Desempenho**
- [ ] Duplo clique → início da carga de dados ~3,5-4 s (exe)
- [ ] Clique → mundo **aprox.** 7,5 s (medido antes no projeto, não no exe); sem engasgo longo ao entrar
- [ ] Voltar ao menu e entrar de novo: 2ª carga igual ou mais rápida

## 4. Problemas conhecidos (não reportar)

- Nome do chefe **Ulgra** baixo demais sobre o modelo.
- Linhas de chefe ainda podem mostrar número de multidão no texto (R2 #13).
- **Fim do dash** (geral): mão um pouco deslocada da arma na pose final (aceito; testes passam).
- **10 escudos grandes** (1,3-1,6 m, espinhos/asas: Relicário, Veredito, Asa Negra, Suspiros...) ainda mais afastados do braço; 7 ficam a meia distância.
- Alguns escudos tocam elmos de conjunto em guarda.
- Monstros humanoides com escudo seguram o escudo longe do braço (montagem antiga, de propósito).
- Arcos de golpe novos não estão nesta build.
- Nível 40: balanceamento ainda sendo medido; diferenças lá não são conclusivas.

## 5. Como reportar

Uma nota por problema, neste formato (cole no chat ou num arquivo de texto):

```text
[Área] título curto
Onde: tela/mapa (ex.: Criação, Druida; Aldara, praça)
Passos: 1) ... 2) ... 3) ...
Esperado: ...   Visto: ...
Frequência: sempre / às vezes / 1 vez     Gravidade: trava / grave / médio / cosmético
Print: nome do arquivo
```

- **Screenshot**: o jogo não tem tecla de foto (só F11 = tela cheia). Use **Print Screen** ou **Win+Shift+S**
  e salve com nome descritivo; anexe o caminho na nota.
- Travou ou fechou sozinho: anote o horário e o que fazia; se rodar pelo console, copie as linhas `SCRIPT ERROR`.
- Lentidão: anote mapa e lugar; o log fica em `%APPDATA%\Godot\app_userdata\RagnaEx\perf_log.txt`.
- Depois do playtest, as notas viram bugs com `/bug-report` (`production/qa/bugs/`).
