# Act III, Part 1 — Names Proposal (for approval, NOT applied)

> Owner: narrative-director · 2026-11-23 · Status: **Partly approved 2026-11-24** — APPLIED: Sylvaré → Amarante, Demônias da Sede → as Veladas (Matriarca Velada, signature Brinde Dividido; mob skills Véu Baixado, Laço de Fita, Reflexos do Brinde). Still undecided: Irmã Celeste, Cantora do Véu, §5 duplicates, Roseiral.
> If you approve a rename, it becomes a separate changeset: display strings in the catalogs, GDD, roteiro and tests that quote
> the names (`run_tests.gd`). Ids such as `sister_celeste`, `vessaline` and `boss_sylvare_echo` stay as they are.
> Pronunciation: pt-BR syllables, stressed syllable in CAPS.

## 0. Summary

| Working name | Recommendation | Why |
|---|---|---|
| Sylvaré | **REPLACE** | It clashes with **Capitã Sylvara** (Act I elf captain, `elf_captain_hunter`, also quoted in bot chat). Its epithet "a Sede Perfeita" sounds too much like "She Who Thirsts" (the Eldar name for Slaanesh). |
| Irmã Celeste | **REPLACE** (soft) | It clashes with **Dona Celeste** (Aldara villager) and the bishop's **Conjunto Coro Celeste**. |
| Demônias da Sede (+ Matriarca da Sede) | **REPLACE** | Same "Sede" problem as above. A family named after thirst, serving a thirsting goddess, is the clearest echo of Slaanesh in the whole act. |
| Cantora do Véu | **REPLACE** (soft) | Four names already end in "do Véu". "Carpideira" (hired mourner) fits her *Lamento* and the painted tear. |
| Everything else | **KEEP** | Each one is original and pronounceable, and none echoes Warhammer (see §3). |

## 1. Characters

| Working name | Keep? | Alt 1 | Alt 2 | Rationale | Pronunciation |
|---|---|---|---|---|---|
| **Sylvaré** (goddess, never seen in part 1) | Replace → **Amarante, a Que Nunca Murcha** | **Vesperina, a Noite Sem Lua** (pays off the "noite sem lua" line of `hx_ec_vision`; if picked, rename Vessaline so two names don't both start with "Ves") | **Ambrósia, o Último Brinde** | The amaranth was the classical "unfading" flower. A feast that never wilts is exactly the horror, and the name has no IP echo. | a-ma-RAN-te · ves-pe-RI-na · am-BRÓ-zia |
| **Lumeria** (the festival city) | Keep | Candelária (a city of candles and lanterns) | Velária | It sounds like "luz" and "lúmen" and fits the lanterns that never go out. A search found no commercial game city of this name (only a hobby World Anvil setting). It is close to "Lemuria" (a public-domain myth), which is acceptable. | lu-ME-ria |
| **Vessaline, a Anfitriã do Véu** | Keep | Celimena, a Anfitriã (after Molière's coquette, public domain) | Rosalvina, a Anfitriã | It is soft and sad and sounds like "vessel" (the one who pours). No known IP match. | ve-ssa-LI-ne |
| **Varo Taça-Cheia, o Anfitrião** | Keep | Baltasar Taça-Cheia (Belshazzar's feast) | Varo Mesa-Farta | It is short and reads like a nickname. "Taça-Cheia" tells you he is a glutton host. | VA-ro TA-ça CHEI-a |
| **A Condessa Refletida** | Keep | A Condessa de Dois Rostos | A Condessa do Espelho | It is descriptive and fits her double mask. Generic title, no IP. | con-DE-ssa re-fle-TI-da |
| **A Prima-Donna do Palco** | Keep | A Diva Engaiolada (her birdcage dress) | Dona Ária | "Prima-donna" is a common opera word, and the cage-dress gives her a look no other boss has. | PRI-ma DO-na |
| **Mestra Ressoa, a Regente** | Keep | Maestrina Fermata | Mestra Cadência | It works as a verb and as a name ("ela ressoa"), and her last line pays it off. | MES-tra re-SSO-a |
| **Dona Vindima, a Vinha que Bebe** | Keep | Mãe Cepa | Dona Lagarina | It is a folksy pt-BR word for the grape harvest, and "Dona" makes her maternal. | DO-na vin-DI-ma |
| **Irmã Celeste** (Lúcidos leader) | Replace → **Irmã Clara** | Irmã Matinas (matins, the dawn prayer, which echoes "Manhã em Lumeria") | Irmã Serena | "Clara" means clear-headed, which fits the Lúcidos and the item *Vinho Claro*, and it does not repeat Dona Celeste or Coro Celeste. Check that no other NPC is named Clara before applying. | IR-mã CLA-ra · ma-TI-nas |
| **os Lúcidos** (survivors) | Keep | os Sóbrios | os Despertos | It is clear in pt-BR, and "they who stayed lucid" is the whole point. | LÚ-ci-dos |

## 2. Places

| Working name | Keep? | Alt 1 | Alt 2 | Rationale | Pronunciation |
|---|---|---|---|---|---|
| **Vinhas do Perfume** | Keep | Quintas Roxas | Vinhedos do Sono Doce | It sets the scent and sleep theme in three words. | VI-nhas do per-FU-me |
| **Avenida do Cortejo** | Keep | Passarela das Fitas | Avenida do Desfile Eterno | "Cortejo" means both a parade and a funeral procession, and that double meaning is the tone of the act. | a-ve-NI-da do cor-TE-jo |
| **o Jardim Sem Fim** | Keep (low risk) | o Roseiral Sem Fim | a Estufa do Véu | "Garden" + demon realm brushes against Warhammer's *Garden of Nurgle* (a different god, about rot). Ours is manicured and endless, the opposite look. If you want zero brush, take Alt 1. | jar-DIM sem FIM |
| **o Véu Rasgado** | Keep | o Pano Rasgado (the stage curtain of the Palco Grande) | a Cortina Rasgada | "Véu" ties to the veils of the demons. The torn veil is a public-domain image. | VÉU ras-GA-do |

## 3. Demon and enemy families

| Working name | Keep? | Alt 1 | Alt 2 | Rationale | Pronunciation |
|---|---|---|---|---|---|
| **Demônias da Sede** (family) | Replace → **as Veladas** | Damas do Brinde | as Convidadas | Their visual identity is veils (no wings). "Velar" also means keeping vigil over the dead, which fits the sad tone, and it drops the "Sede" echo. | ve-LA-das |
| Sedutora | Keep | Encantadora | Convidada | It is generic and readable. Keep it unless the family gets renamed to "Convidadas". | se-du-TO-ra |
| Açoitadora | Keep | Fiandeira (spins her ribbon-whip) | Chicoteira | The pt-BR name has no echo. **The internal id `flayer` echoes Warhammer's "Hellflayer"**, but players never see it, so leave it. | a-çoi-ta-DO-ra |
| Cantora do Véu | Replace → **Carpideira** | Pranteadora | Cantora do Véu (keep) | A carpideira is a hired mourner. That fits her *Lamento*, the tear on the mask, and the sad-under-the-party tone. It also cuts one "do Véu". | car-pi-DEI-ra |
| Matriarca da Sede | Replace → **Matriarca Velada** | Madrinha do Baile | Grã-Velada | This follows the family rename. | ma-tri-AR-ca ve-LA-da |
| Foliões (Folião Mascarado, Convertido, Mestre de Cerimônias) | Keep | Mascarados | Festeiros | These are plain pt-BR festival words. | fo-li-ÕES |
| Bailarinos do Véu (Primeiro Bailarino) | Keep | Dançarinos de Leque | Bailarinos de Porcelana | The "eternal dancer" is a broad archetype. The fan-blade silhouette is ours. | bai-la-RI-nos |
| Galgos de Seda (Galgo Alfa do Cortejo) | Keep | Lebréus de Seda | Galgos de Guizo | This is a real dog breed, and the bells, silk and eyeless mask make it original. Not a Slaanesh "Seeker" (no rider, no tongue). | GAL-gos de SE-da |
| Coro Ferido (Corista, Maestro do Coro) | Keep | Coro Costurado | Coro Mudo | The sewn mouth plus a chest of organ pipes is ours. | CO-ro fe-RI-do |
| Reflexos (Reflexo Vaidoso) | Keep | Vaidades | Espelhados | Generic. | re-FLE-xos |
| Incensários (Incensário Vivo) | Keep | Turíbulos | — | Generic church object. | in-cen-SÁ-rios |
| Vinhas (Vinha Sedenta) | Keep | Vinha Bebedora | Cepa Sedenta | "Sedenta" on a plant reads as an ordinary adjective. Keep it even if the "Sede" family is renamed. | VI-nha se-DEN-ta |

## 4. IP echo check (Warhammer / Slaanesh and other)

Checked from knowledge plus two web searches ("Lumeria" game city; "Vessaline"/"Sylvaré"). Neither found a commercial match.

| Risk | Where | Verdict |
|---|---|---|
| "She Who Thirsts" (Eldar name of Slaanesh) | Sylvaré "a Sede Perfeita", Demônias/Matriarca **da Sede**, the Eco signature **Sede Dividida** | **HIGH**: rename (§1, §3). For the signature, suggest **Brinde Dividido**. The ordinary word "sede" inside dialogue is fine. |
| "Prince / Lord of Excess" | Faction concept "o Excesso" | **LOW**: "excess" is a generic word. Rule: never write "Príncipe do Excesso" or "Senhor do Excesso", never use "Príncipe Sombrio", never use the number 6 as a motif. |
| Daemonettes, Keeper of Secrets, Fiends, Seekers, Hellflayer, Masque | Demon roster | **LOW**: no name matches. Only the internal id `flayer` brushes "Hellflayer". Designs avoid crab claws, curved horns, four arms and long tongues (GDD §3). |
| Garden of Nurgle | "o Jardim Sem Fim" | **LOW-MED**: different god, different look. Optional Alt 1 "Roseiral". |
| Capitã Sylvara (our own Act I) | Sylvaré | **HIGH, internal clash**: rename. |
| Celeste (ours, three times) | Irmã Celeste | **MED, internal**: rename. |

## 5. Minor internal name clashes found (also need your call; not applied)

| Clash | Suggestion |
|---|---|
| **Costureira Benedita** (Avenida) vs **Varredora Benedita** (L4 sweeper, `lum_sweeper_a`) | Rename the sweeper to **Varredora Firmina**. |
| **Varredor Anselmo** (`lum_sweeper_b`) vs **Mordomo Anselmo** (the Duke's butler, quoted in `hx3_duke_mirrors`) | Rename the sweeper to **Varredor Otílio**. |
| **Intendente Bráulio** (Rift) vs **Capataz Liberto Bráulio** (Act II) | Rename the quartermaster to **Intendente Gaspar**. |
| **Lúcido Tadeu** vs **Mestre Tadeu, o Mineiro** (Act I) | Rename to **Lúcido Fausto**. |
| **Duque Aurelião** vs **Capitã Aurélia** vs **Aurora** | Rename the Duke to **Duque Leopoldo de Lumeria**. Players will mix up "Aurelião" and "Aurélia" in the quest log. |
| **Mestre de Cerimônias** (elite) vs **Mestre de Skills / Arauto dos Mestres** | Fine. Different context. |

## 6. Approval checklist

Mark each row Approve / Alt 1 / Alt 2 / Keep. Once approved, the narrative-director (or writer) applies the renames in one
changeset: catalog display names, quest text, NPC lines, GDD, roteiro, run_tests strings and `loading_art.py` ZONES names
if a map name changes.
