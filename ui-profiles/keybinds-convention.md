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
| 11 | `Mi…` ⚠️ | `Shift+…` ⚠️ |
| 12 | `M…` ⚠️ | `M…` ⚠️ |

⚠️ = label troncata/illeggibile dallo screenshot (slot 11–12, probabilmente tasti mouse o
macro). Da confermare in-game (Game Menu → Keybindings).

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
| `Alt+\` | Macro dispel di classe (Decurse, Cleanse Spirit, ecc.) | ❓ da confermare per classe |
| `?` | **Interrupt** (Pummel/Mind Freeze/Wind Shear/Counterspell/Rebuke/Skull Bash) | ❓ da decidere tasto comune |
| `?` | **Difensivo personale** maggiore | ❓ da decidere tasto comune |
| `?` | **Pozione** (combat potion) | ❓ da confermare |

> **Da fare con l'utente:** scegliere _un_ tasto fisso per Interrupt e _uno_ per il difensivo
> personale, e verificare che su ogni classe l'abilità giusta sia in quello slot. È il cuore
> dell'allineamento "ruoli equivalenti tra classi".

## Personaggi tracciati

| Personaggio | Classe | Spec | File | Screenshot M+/raid |
|---|---|---|---|---|
| Stantu | Warrior | Fury / Arms / (Prot) | `keybinds-warrior.md` | solo 1 (main) |
| Blessismore | Paladin | Protection | `keybinds-paladin.md` | M+ + raid |
| Furricane | Death Knight | Frost | `keybinds-deathknight.md` | M+ + raid |
| Totemtanz | Shaman | Elemental | `keybinds-shaman.md` | M+ + raid |
| Mustaina | Druid | Feral | `keybinds-druid.md` | M+ + raid |
| Snowwipe | Mage | Frost | `keybinds-mage.md` | M+ + raid |

> Gli alt sono mono-spec ma scambiano qualche pulsante tra M+ e raid → i file per classe
> segnano la colonna M+ vs raid dove serve.
