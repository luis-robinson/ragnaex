# RagnaEx Ato II - Notas da versão de teste (15/11/2026)

Esta é uma versão de teste. Seus personagens salvos continuam funcionando: o formato do save não mudou.

## Destaques

- **Tela inicial totalmente nova**: título com logo, acampamento à beira de Aldara com fogueira, lista de personagens e criação de personagem onde você vê a skill-assinatura de cada classe em ação.
- **Machados redesenhados**: todos os machados ganharam lâminas novas (crescente, barbuda, dupla), incluindo os dos chefes Ghar e Durgash e o Machado do Trono.
- **Escudos no antebraço**: os 43 escudos ganharam uma montagem nova, perto do braço, em vez de flutuarem ao lado dele.
- **Entrada no jogo muito mais rápida**: o logo aparece logo ao abrir, e os bots nascem em cerca de 1 s (antes ~17 s).
- **Nível 45 mais forte**: as 13 builds que estavam abaixo do alvo ficaram mais fortes no nível 45. Nenhuma build foi enfraquecida.

## Nova tela inicial e personagens

- Título com Jogar, Configurações e Sair (Sair pede confirmação), música de Aldara e versão do jogo no canto.
- Lista com 5 espaços de personagem: retrato, classe, nível e mapa. O boneco no pedestal acompanha o card escolhido; espaço vazio mostra uma silhueta.
- Excluir personagem tem diálogo de confirmação (Esc cancela) e remove o retrato junto. Se você excluir o último personagem, vai direto para a criação de um novo.
- Criação de personagem em passos: escolha da classe com a skill-assinatura tocando no pedestal, depois visual (corpo, cabelo, rosto), nome e sorteio. Arraste para girar e use a roda do mouse para aproximar.
- Atalhos: Enter confirma, Esc volta um passo, duplo clique num card joga, Delete exclui.
- Tela de carregamento com arte própria de cada uma das 26 zonas, barra que só avança, texto da etapa e dica.
- Esc dentro do jogo: "Salvar e voltar ao menu" leva à lista com o seu personagem selecionado.
- Saves ficaram mais seguros: a gravação é feita em duas etapas, e um save danificado aparece como "Save danificado" na lista, sem derrubar o jogo.

## Visual

**Machados**
- Lâminas novas para todos os machados: formatos largo, barbudo, crescente, cutelo, serrilhado e duplo, com corpo de aço escuro, para ler bem na câmera alta.
- Cada conjunto do Berserker tem a sua lâmina; o brilho do fio ficou mais suave e na cor de cada conjunto.
- Ghar e Durgash (e o Machado do Trono na luta) usam a nova família de machados.
- Ícones dos machados e da skill de machado refeitos.

**Escudos**
- Os 43 escudos (Paladino e Bispo) agora ficam junto ao antebraço, com uma alça de couro mais curta, e a haste dourada solta sumiu.
- O escudo inicial (Tábuas) também ficou colado ao braço em idle, corrida e bloqueio.
- Os ícones dos escudos foram refeitos.

**Armas, patas e animação**
- Armas não atravessam mais o chão em ataques, skills e dash, em todas as classes.
- Lobo e urso do Druida: as patas da frente não viram mais ao contrário em golpes e saltos.
- Berserker: no fim do dash, o machado não gira mais por trás do corpo.

**Telas de carregamento e logo**
- Uma foto por zona na tela de carregamento, tirada do próprio mapa.
- Logo novo do RagnaEx e subtítulo do Ato II, no título e na tela de abertura.

**Mundo**
- Kharzun revisado: pano dos lobos recolorido, riscos do santuário removidos, forja do covil goblin decorada e seixos de basalto na arena.
- Tapete na porta da Botica de Aldara (antes era uma mancha). Corvos e morcegos no ambiente.

## Interface

- Nomes sobre personagens mantêm tamanho constante com a distância, ficam acima de modelos altos e se escondem sob os painéis do HUD.
- Gritos de chefe aparecem na faixa do HUD, não mais como balão solto.
- Painéis de chat e de Quests agora são opacos.
- "Esquiva!" junta em "x2", "x3" sem deixar texto fantasma ao lado.
- Monstros hostis não mostram mais o anel de aura no chão.
- Configurações (gráficos, volumes, dicas) são o mesmo painel no título e no menu Esc.

## Equilíbrio

- **Nível 45 (ascensão)**: as 13 builds que estavam abaixo do alvo ficaram mais fortes no nível 45 e agora ficam entre 1,30 e 1,37 de força. Fogo, Raio e Cruzado já estavam acima e não mudaram. Nenhuma build foi enfraquecida.
- Alguns nós de ascensão do 45 (como o do Druida Xamã) ganharam bônus próprios; o nível 35 não mudou.
- Os chefes não mudaram, mas grupos com bots no 45 se saem melhor: Kragmar cai um pouco mais vezes e a luta contra Durgash ficou mais curta. Ulgra e Gorbash continuam como antes.

## Desempenho

- O jogo abre direto no logo (tela de abertura) e chega ao carregamento dos dados em cerca de 4 s.
- Ferramentas de desenvolvimento só carregam quando são usadas, o que tira mais meio segundo da abertura.
- Os bots agora nascem em cerca de 1 s no começo do jogo (antes ~17 s), com o mesmo mundo de antes.
- Do clique em Jogar até o mundo, cerca de 7,5 s (medição aproximada). Voltar ao menu e entrar de novo deve ser igual ou mais rápido.

## Correções

- Apertar Enter duas vezes rápido no menu não inicia mais o jogo duas vezes.
- Excluir o último personagem leva à criação de personagem, em vez de deixar 5 espaços vazios.
- Pequenas correções de memória quando o carregamento falha.
- O escudo inicial não flutua mais longe do braço.
- Armas e patas de lobo/urso não furam mais o chão em ataques e dashes.
- Excluir um personagem remove também o retrato; slots nunca ficam "presos".
- Texto de combate e nomes de chefes mais limpos (sem texto fantasma em "Esquiva!").
- O mapa de Kharzun e a Cidadela tiveram falhas visuais corrigidas (ver Visual).

## Problemas conhecidos

- O nome do chefe Ulgra aparece baixo demais sobre o modelo.
- Linhas de chefe ainda podem mostrar um número de multidão no texto.
- No fim do dash, a mão fica um pouco deslocada da arma.
- Cerca de 10 escudos grandes (de 1,3 a 1,6 m, com espinhos ou asas), como Relicário, Veredito, Asa Negra e Suspiros, ainda ficam mais afastados do braço do que os outros.
- Alguns escudos tocam elmos de conjunto em guarda.
- Monstros com escudo ainda seguram o escudo longe do braço.

Como reportar: uma nota por problema, com onde, passos, esperado x visto e print. Obrigado por testar!
