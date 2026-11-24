# Act III, Part 1 (45-50) — Voice Sheet

> Owner: narrative-director · 2026-11-23 · Status: **Provisional** (working names; see `act3-names-proposal.md`)
> Applies to: `quests_catalog.gd act3_lumeria()`, Act III bosses in `monsters_catalog.gd`, Act III NPCs/villagers/road
> events in `maps_catalog.gd`, `bots_catalog.gd` (`lumeria`, `lumeria_town`), `hud.gd ACT_END_TEXT[3]`.

## Tone rules (all characters)

- **Beautiful on top, tired underneath.** The joke lands first, then the sadness. Never horror-shouting.
- **Motifs** (use, don't explain): sleep / waking, doors and furniture-barricades, names remembered or forgotten,
  the clock stuck at midnight, masks with one painted tear, ribbons, the taste of plain things (bread, water, bitter grapes).
- **Forty years** of feast is the shared fact. Say it at most once per quest chain; prefer showing it (stuck clock, grown children).
- **No exposition dumps.** One fact per line. Lines ≤ 120 chars where possible; boss `say` ≤ 70.
- **Excess is never lewd.** Desire = hunger, thirst, applause, being looked at. The demons want you to *stay*, not to *suffer*.
- **The goddess** (working name Sylvaré) never speaks and never appears in part 1. Only bosses of the Rift and the Eco may say
  "ela" or her name. Part 2-3 foreshadow: the Garden goes on past the Pavilion; the crown is empty; "she is still thirsty".
- **Mechanical tips** stay in `dialog_progress`, said in the character's voice, but the verb and the counter stay exact.
- pt-BR, "você" (never "tu"), no regional slang beyond light colloquialism; bots use MMO chat style (lowercase, "kkk").

## Allies

| Character (id) | Role | Voice | Sample |
|---|---|---|---|
| **Irmã Celeste** (`sister_celeste`) | Leader of the Lúcidos, Aurora sister | Calm, dry, tired humor. Short practical sentences: water, doors, sleep. Never preaches. Calls the revelers "eles", never "monstros". | "Eles não são maus. Só esqueceram como se para." |
| **Comandante Isolda Brasa** (`kharzun_commander`) | Act II commander, hands off | Military, brisk, imperative. | "Vá ver quem ainda dorme por lá." |
| **Vinhateiro Bento** (`perfume_vintner`) | Vintner, keeper of the cellar key | Earthy, slow, grief for the vines. Speaks of "minhas uvas", grandfather, harvest. | "Meu avô plantou aquelas. Doeu cortar." |
| **Capitão Afonso** (`parade_post_captain`) | Lúcido captain of the Parade post | Clipped soldier, counts things, refuses to forget the Converts were people. | "Dez. E não olhe a máscara: olhe as mãos." |
| **Duque Aurelião** (`duke_lumeria`) | Gave the first party; freed in L3 | Eloquent, self-accusing, longer sentences, courtly words. The only one who says "eu" too much. | "Eu dei a primeira festa. Esta é a última que eu dou." |
| **Relojoeiro Otaviano** (`clockmaker`) | Clockmaker | Precise, time metaphors, quiet pride. | "Quarenta anos de meia-noite. Quero ouvir um minuto passar." |
| **Destiladora Amália** (`perfume_distiller`) | Distiller | Curious, clinical, a little proud. Lists ingredients. | "Rosa, cravo e uma coisa que não tem nome." |
| **Tanoeiro Rufino** (`perfume_cooper`) | Cooper | Stubborn craftsman; the empty barrel is his manifesto. | "Vai ser o primeiro barril vazio desta quinta." |
| **Ancião Bartolomeu** (`fugitive_elder`) | Fugitives' elder | Gentle, worried, remembers everybody's name. | "O Tobias rezava lá todo dia." |
| **Ponto Ermelindo** (`parade_prompter`) | Theater prompter | Stage jargon (deixa, coxia, compasso, pano). Speaks low, precise about timing. | "A deixa é minha, a porta é sua." |
| **Costureira Benedita** (`parade_seamstress`) | Costume maker | Sharp-tongued, funny, offended by bad taste. | "Espelho não veste!" |
| **Altar da Máscara Partida** (`broken_mask_altar`) | Board | Chalk graffiti, quoted, terse, anonymous. | 'Sem máscara, ninguém dança.' |
| **Tenente Selene / Capitã Aurélia** (Aurora) | Hold the Veil / the Rift post | Disciplined, few words. Aurélia is ominous about the Garden, never panicked. | "Lá dentro, o jardim escolhe quem volta." |
| Lúcidos, vinhateiros, varredores | Villagers | Small concrete things; relief that comes out as jokes. | "Existe seis da manhã de novo." |

## Enemies (boss lines)

| Boss | Voice | Rule |
|---|---|---|
| **Dona Vindima** | Maternal glutton; "mamãe", offers drink, pities the thirsty. Stage directions in parentheses. | Hunger as care. |
| **Varo Taça-Cheia** | Jovial host, toasts, table manners, never angry until the napkin falls. | Every line is an invitation. |
| **A Prima-Donna** | Diva; plateia, compasso, bis. Contempt for the off-beat. | Wants to be watched. |
| **Mestra Ressoa** | Strict conductor; musical terms (afinem, tempo, fermata). Terse. | Wants obedience to the beat. |
| **A Condessa Refletida** | Cold, speaks as "nós" (double mask), about gaze and choosing a face. | Wants to be the one you see. |
| **Vessaline** | Gentle hostess, sad, welcoming. Never threatens; asks guests to stay. Can name "ela". | Wants nobody to leave. |
| **O Eco** | Not a person: fragments, the five senses, perfume that speaks. | Wants to be tasted. |

## Bots

MMO chat: lowercase, short, "kkk", practical tips, mild complaints about music/confetti. Never lore dumps.
