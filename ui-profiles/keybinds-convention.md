# Convenzione keybind cross-class

Layout tasti **account-wide** (Bartender): i tasti sono legati allo **slot** della barra, non
all'abilità o alla spec. Tutti i personaggi condividono la stessa griglia di tasti → per
allineare basta mettere lo stesso *ruolo* nello stesso slot su ogni classe.

Questo file è la **fonte di verità del layout** (slot → tasto) e delle convenzioni di ruolo
cross-class. I dettagli per classe/spec stanno in `keybinds-<classe>.md`.

## Griglia tasti (confermata dagli screenshot, identica su tutti i pg)

Due barre sovrapposte, 12 colonne. Colonna N = Bar1 slotN (sopra) + Bar2 slotN (sotto).

| Col | Bar 1 (sopra) | Bar 2 (sotto) |
|---|---|---|
| 1 | `1` | `T` |
| 2 | `2` | `Shift+T` |
| 3 | `3` | `G` |
| 4 | `4` | `Shift+G` |
| 5 | `Q` | `Shift+Q` |
| 6 | `E` | `Shift+E` |
| 7 | `R` | `Shift+R` |
| 8 | `F` | `Shift+F` |
| 9 | `\` | `Alt+\` |
| 10 | `X` | `Shift+X` |
| 11 | Tasto laterale mouse 1 | Shift + tasto laterale mouse 1 |
| 12 | Tasto laterale mouse 2 | Shift + tasto laterale mouse 2 |

Le colonne 11–12 (gli ultimi due slot a destra) sono mappate sui **tasti laterali del mouse**:
riga sopra = tasto laterale, riga sotto = Shift + tasto laterale. (La label "Mi…"/"M…" troncata
negli screenshot era "Mouse…".)

> **Nota Bartender:** sui pulsanti macro è attivo "mostra nome macro" → il testo piccolo in
> basso negli slot è il **nome della macro** (es. `HL`, `CT`, `AMZ`, `DaD`). Utile per mappare
> gli slot alle macro di `macros/manifest.json`.

## Legenda tipo (riusata nei file per classe)

- **=** identico cross-spec/cross-class → tasto non cambia mai significato.
- **~** macro auto-adattiva (`known:`) → stesso slot, si adatta da solo a spec/loadout.
- **≠** stesso slot/ruolo, abilità diversa per spec/classe (resta la muscle-memory del *ruolo*).
- **?** identità abilità **da confermare** (indovinata dall'icona).

## Ancore cross-class (stesso tasto = stesso ruolo su ogni classe)

Queste sono le convenzioni che vogliamo tenere identiche tra le classi. ✔ = verificato dagli
screenshot; ❓ = proposto, da confermare.

| Tasto | Ruolo | Stato |
|---|---|---|
| `G` | Healthstone / consumabile cura (icona erbe verdi, stack visibile su tutti) | ✔ tutti i pg |
| `Alt+\` | **Dispel** di classe (dps) **/ Taunt** (tank) — secondo ruolo | ✔ regola utente |
| `\` | **Interrupt** (Pummel/Mind Freeze/Wind Shear/Counterspell/Rebuke/Skull Bash) | ✔ regola utente |
| `X` | **Stun / rallentamento** (CC di controllo) | ✔ regola utente |
| `F` | **Difensivo / mitigation** | ✔ regola utente |
| `Shift+F` | **Difensivo / mitigation** (secondo) | ✔ regola utente |
| `Shift+G` | **Self-heal** / cura personale (se la classe ce l'ha) | ✔ regola utente |
| `Shift+R` | **Difensivo / vita** personale (se la classe ce l'ha) | ✔ regola utente |
| `Shift+B` | **Pozione di cura** (healing potion) | ✔ regola utente |
| `Shift+C` | **Pozione di mana** (per healer) | ✔ regola utente |

> **Cluster difensivi:** `F`, `Shift+F` e `Shift+R` sono tutti slot difensivi/mitigation
> (più `Shift+G` self-heal). Se una classe ha pochi difensivi, alcuni di questi slot restano
> vuoti senza essere "buchi".

> **Ancore decise (regola utente):**
> - `\` = **interrupt** su ogni classe (Pummel/Mind Freeze/Wind Shear/Counterspell/Rebuke/Skull Bash).
> - `Alt+\` = **dispel** sui dps, **taunt/grip** sui tank (es. Hand of Reckoning, Death Grip).
> - `X` = **stun / rallentamento** (CC di controllo) su ogni classe.
> - `Shift+G` = **self-heal** personale (se la classe ce l'ha).
> - `F`, `Shift+F`, `Shift+R` = **difensivi / mitigation** (cluster); `Shift+G` = self-heal.
>
> Se uno slot è vuoto, la classe **non ha** quell'abilità — oppure è un buco da riempire.
> - `Shift+B` = **pozione di cura**, `Shift+C` = **pozione di mana** (per healer).

## Tasti funzione (utility cross-class, regola utente)

Fuori dalle due barre principali, sui tasti F:

| Tasto | Ruolo |
|---|---|
| `F1`, `F2` | **Buff di classe** (Arcane Intellect, Battle Shout, Mark of the Wild, ecc.) |
| `F4` | **Invisibilità / stealth** o simile, se la classe ce l'ha |
| `F8` | **Res / Combat Res** (battle res o res normale) |
| `F12` | **Bloodlust / Heroism / Time Warp / Drums / ecc.** |

## Personaggi tracciati

| Personaggio | Classe | Spec | File | Screenshot M+/raid |
|---|---|---|---|---|
| Stantu | Warrior | Fury / Arms / (Prot) | `keybinds-warrior.md` | solo 1 (main) |
| Blessismore | Paladin | Protection | `keybinds-paladin.md` | M+ + raid |
| Furricane | Death Knight | Frost | `keybinds-deathknight.md` | M+ + raid |
| Totemtanz | Shaman | Elemental | `keybinds-shaman.md` | M+ + raid |
| Mustaina | Druid | Feral | `keybinds-druid.md` | M+ + raid |
| Snowwipe | Mage | Arcane | `keybinds-mage.md` ⚠️ | M+ + raid |

> Gli alt sono mono-spec ma scambiano qualche pulsante tra M+ e raid → i file per classe
> segnano la colonna M+ vs raid dove serve.

> **Come si giocano gli alt (importante per l'allineamento):** slot `1` = **one-button**
> (rotazione automatica), poi solo qualche **binding strategico** per stun, interrupt e utility.
> → Per gli alt l'allineamento riguarda **solo i tasti strategici/ancore** (`\`, `X`, `Alt+\`,
> `G`, `Shift+G`, `Shift+R`, pozione), **non** i filler rotazionali. Le ipotesi `?` sui filler di
> Bar 1 sono quindi secondarie: non serve sistemarle.
