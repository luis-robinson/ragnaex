# Buffs no boneco

Todo buff ativo aparece no próprio personagem enquanto dura (não só um anel no pé no início).
Antes, só formas/furtividade (o corpo muda) e auras ligadas (anel no chão) tinham visual que durasse; o resto
ganhava um anel fino no pé que ninguém via de cima ("usei Armadura de Gelo e nada mudou").

**Total: 50 buffs** que o jogo pode pôr (skills, evoluções, mods de forma, talentos de classe, itens e sistemas).
**Antes: 6 com visual persistente no boneco. Agora: 50.**

## Como funciona

- `game/fx/buff_looks.gd` (`BuffLooks.LOOKS`): id do buff -> `[família, tema]`. Tema = paleta de `SkillFx.PALETTE`.
  `BuffLooks.sources()` lista todo buff que o jogo pode pôr; o teste `_check_buff_visuals` falha se algum não tiver linha.
- `game/fx/buff_aura.gd` (`BuffAura`, uma por `EntityView`, criada no primeiro buff): lê `SimEntity.buffs` 10x/s
  (4x/s para quem não é o jogador) e mostra:
  - **borda/padrão na pele**: uniform `buff_rim`/`buff_style` do `toon.gdshader` (gelo = placas de cristal,
    pedra/osso = manchas, chama = tremor, casca = veios, sagrado = faixa dourada subindo, sombra = escuro subindo).
    Sem malha nem draw call a mais (usa os materiais do boneco, como o `status`).
  - **casca** (`shaders/buff_shell.gdshader`, um material para todos, cor/força por `instance uniform`):
    bolha de escudo (some com o `shield_hp` restante), cristal facetado (gelo) ou chama (buffs de ataque).
  - **auréola** (`shaders/buff_glow.gdshader`) para bênçãos.
  - **até 2 emissores** `GPUParticles3D` reaproveitados (materiais de processo/malhas compartilhados por preset+tema).
  - Buff de talento permanente (`ct`) e aura recebida do grupo (`aura_from`): só a borda, fraca.
  - Entrada: estouro (borda/casca/auréola crescem) + estouro de partículas e anel do `FxManager._on_buff`. Saída: esmaece nos últimos 0,6 s.
  - Escondido na furtividade, na forma fantasma e morto.
- Debuffs (`EntityView._update_status`): atordoado (estrelas), queimando (brasas + laranja), lento/preso (anel de gelo + azul),
  **novos**: envenenado (bolhas verdes + verde), amaldiçoado/definhando/penitência (fiapos roxos sobre a cabeça + roxo).

## Revisar

- `.\tools\godot.ps1 --path . -- --autostart=<c> --buff_shot=<pasta> [--only=<id>,...] [--close]`: cada buff num boneco
  da classe dona ao lado de um sem buff, câmera do jogo; `<id>.png`, `<id>_pop.png` e `folha.png` (ordem no log).
  Inclui `shield@<classe>`, `<buff>@ally` (aura recebida) e `dbf_*` (debuffs).
- No jogo: `-- --autostart=elementalist --buff_cast=ele_frost_armor --buff_hold --screenshot=<png>`.
- Auditoria: `--headless --path . tools/tests/buff_audit.tscn` imprime a tabela abaixo.
- Custo: `-- --perf` contra `-- --perf --no_buff_fx`.

## Tabela

| buff | fontes | família | tema | antes | agora |
|---|---|---|---|---|---|
| `angel` | skill bis_angel (Asas Angelicais) | holy | holy | não (só anel no pé no início) | auréola + brilho dourado; partículas `motes` |
| `avenging_wrath` | skill pal_avenging_wrath (Ira Vingadora) | holy | holy | não (só anel no pé no início) | auréola + brilho dourado; partículas `motes` |
| `bark` | skill dru_bark (Pele de Casca) | armor | nature | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `leaves` |
| `bastion` | RaidSystem (sentinela: reunir) | armor | holy | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `motes` |
| `bastion_aura` | skill pal_bastion_aura (Aura do Bastião) | aura | holy | anel no chão (aura ligada) | anel no chão + borda (grupo: borda fraca) |
| `battle_hymn` | skill bis_battle_hymn (Hino de Batalha) | power | holy | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `bellow` | skill dru_bellow (Urro da Mata) | armor | nature | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `leaves` |
| `blessed_armor` | skill pal_blessed_armor (Armadura Abençoada) | armor | holy | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `motes` |
| `blessing` | skill bis_blessing (Bênção) | holy | holy | não (só anel no pé no início) | auréola + brilho dourado; partículas `motes` |
| `bloodlust` | skill ber_bloodlust (Sede de Sangue) | power | blood | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `bone_armor` | skill nec_bone_armor (Armadura de Ossos) | armor | bone | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `bone` |
| `bonewall` | skill nec_bone_wall (Muralha de Ossos) | armor | bone | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `bone` |
| `bulwark` | skill pal_taunt (Provocar) | armor | holy | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `motes` |
| `crystal_ward` | skill mob_crystal_ward (Escudo de Cristal) | armor | ice | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `snow`; casca `cristal` |
| `dark_pact` | skill nec_dark_pact (Pacto Sombrio) | dark | shadow | não (só anel no pé no início) | sombra subindo pelo corpo + fumaça roxa; partículas `shadow` |
| `deadeye` | skill ran_deadeye (Olho de Águia) | power | physical | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `sparks`; casca `chama` |
| `duel_focus` | skill ass_focus (Foco do Duelista) | power | physical | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `sparks`; casca `chama` |
| `duel_guard` | skill ass_guard (Guarda do Duelista) | armor | physical | não (só anel no pé no início) | borda + padrão na pele do tema |
| `elixir` | item elixir_might | power | fire | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `fervor` | skill bis_zealot (Fervor) | power | holy | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `focus` | skill ass_backstab (Apunhalar) | power | physical | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `sparks`; casca `chama` |
| `form_bear` | skill dru_bear_form (Forma de Urso) | form | nature | sim (corpo muda) | o boneco muda (forma/transparência) |
| `form_demon` | skill nec_demon_form (Forma Demoníaca) | form | fire | sim (corpo muda) | o boneco muda (forma/transparência) |
| `form_phantom` | skill nec_phantom (Forma Fantasma) | form | lunar | sim (corpo muda) | o boneco muda (forma/transparência) |
| `form_wolf` | skill dru_wolf_form (Forma de Lobo) | form | nature | sim (corpo muda) | o boneco muda (forma/transparência) |
| `frenzy` | skill dru_frenzy (Frenesi) | power | blood | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `frost_armor` | skill ele_frost_armor (Armadura de Gelo) | armor | ice | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `snow`; casca `cristal` |
| `fury` | skill ber_fury (Fúria) | power | blood | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `grove` | skill dru_grove (Bênção do Bosque) | holy | nature | não (só anel no pé no início) | auréola + brilho dourado; partículas `motes` |
| `juramento` | ShieldSystem (Juramento ao bloquear) | armor | holy | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `motes` |
| `legend_frenzy` | LegendEffects (arma lendária: frenesi) | power | blood | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `mark` | skill ran_mark (Marca do Caçador) | power | physical | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `sparks`; casca `chama` |
| `oak_skin` | skill dru_oak_skin (Pele de Carvalho) | armor | nature | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `leaves` |
| `overload` | skill ele_overload (Sobrecarga) | power | lightning | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `sparks`; casca `chama` |
| `pack` | skill ran_pack (Instinto da Matilha) | power | nature | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `plague_blade` | skill ass_plague_blade (Lâmina Pestilenta) | poison | poison | não (só anel no pé no início) | gotas verdes da arma + borda verde; partículas `drip` |
| `reflexes` | skill ass_reflexes (Reflexos) | speed | wind | não (só anel no pé no início) | rastros de vento nos pés; partículas `streaks` |
| `shield` | skill pal_divine_shield (Escudo Divino), skill nec_bone_wall (Muralha de Ossos), skill bis_martyr (Mártir) +5 | shield | holy | não (só anel no pé no início) | bolha translúcida (some com o escudo); casca `bolha` |
| `shield_wall` | skill pal_shield_wall (Muralha de Escudo) | armor | holy | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `motes` |
| `smoke` | skill ass_smoke (Cortina de Fumaça) | smoke | shadow | não (só anel no pé no início) | fumaça nos pés; partículas `smoke` |
| `stealth` | skill dru_prowl (Espreitar), skill ass_vanish (Sumir) | form | shadow | sim (corpo muda) | o boneco muda (forma/transparência) |
| `stoneskin` | item elixir_stone | armor | earth | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `dust` |
| `swift` | skill ran_disengage (Recuar) | speed | wind | não (só anel no pé no início) | rastros de vento nos pés; partículas `streaks` |
| `titan_grip` | skill ber_titan_grip (Pegada de Titã) | power | blood | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `tumble` | skill ran_tumble (Salto Ligeiro) | speed | wind | não (só anel no pé no início) | rastros de vento nos pés; partículas `streaks` |
| `valor` | skill pal_valor (Valor) | power | holy | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `warcry` | skill ber_warcry (Grito de Guerra) | power | blood | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
| `ward` | skill bis_ward (Égide Divina) | armor | holy | não (só anel no pé no início) | borda + padrão na pele do tema; partículas `motes` |
| `wild_run` | evolução dru_t_stampede_step | speed | nature | não (só anel no pé no início) | rastros de vento nos pés; partículas `streaks` |
| `zeal` | skill pal_zeal (Zelo) | power | holy | não (só anel no pé no início) | chama do tema em volta + borda tremendo; partículas `embers`; casca `chama` |
