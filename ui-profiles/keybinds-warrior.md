# Warrior — Layout keybind allineato (Fury + Arms)

- **Personaggio:** Stantu-PozzoDellEternita
- **Obiettivo:** switchare raid↔M+ (e Fury↔Arms) cambiando il meno possibile sotto le dita.
- **Stato tasti:** TODO — Stantu deve ancora scegliere i bind. Qui sono fissati **ruoli e slot**; la colonna `Key` si riempie dopo.

## Principi (come WoW rende possibile l'allineamento)

1. I **keybind non sono per-spec**: il tasto è legato allo *slot* della barra, non all'abilità. Stesso ruolo nello stesso slot in entrambe le spec → il tasto non cambia mai significato.
2. La **Barra 1 è per-spec** (ogni spec ricorda la sua): basta replicare lo stesso ordine di slot una volta per spec.
3. Cambiare **loadout talenti (Slayer↔Mountain Thane) NON cambia le barre**: le divergenze (Whirlwind↔Thunder Clap, Avatar opzionale) sono dietro macro `known:` → lo slot si auto-adatta, niente da rifare.

## Legenda tipo

- **=** identico cross-spec (stessa abilità/macro su Fury e Arms) → tasto NON cambia mai.
- **~** macro auto-adattiva (`known:`) → stesso slot, si adatta da solo a spec/loadout.
- **≠** spec-specifico → stesso slot/ruolo, abilità diversa per spec (la muscle-memory del *ruolo* resta).

## Griglia

### A — Filler rotazionali (≠ ability, stesso slot/tasto)

| Slot | Key | Ruolo | Fury (Slayer raid / MT M+) | Arms |
|---|---|---|---|---|
| A1 | TODO | Filler 1 | Bloodthirst | Mortal Strike |
| A2 | TODO | Filler 2 | Raging Blow | Overpower |
| A3 | TODO | Spender/Enrage | Rampage | Slam |
| A4 | TODO | Execute = | Execute | Execute |

> **Loadout:** raid = **Slayer** (NON talenta Thunder Clap → su Q la macro casta Whirlwind), M+ = **Mountain Thane** (Thunder Clap). `known:Thunder Clap` è quindi un discriminatore affidabile.

### B — Cleave / AoE setup

| Slot | Key | Ruolo | Fury | Arms | Tipo |
|---|---|---|---|---|---|
| B1 | **Q** | Cleave applier | `whirlwind-cleave` (WW↔Thunder Clap) | `sweeping-cleave` (SS+Cleave/WW) | ≠ (macro per spec, stesso slot) |
| B2 | TODO | CD cleave/maintain | Odyn's Fury | `cs-rend` (Colossus Smash+Rend) | ≠ |
| B3 | TODO | AoE channel | `ravager-bladestorm` (Bladestorm) | `ravager-bladestorm` (Ravager@cursor/BS) | ~ cross-spec |

### C — Utility / cooldown (tutti = o ~, tasto NON cambia mai)

| Slot | Key | Ruolo | Macro/Abilità | Tipo |
|---|---|---|---|---|
| C1 | TODO | Burst opener | `avatar-reck-trinket` (Fury: Reck+Avatar / Arms: Avatar) | ~ |
| C2 | TODO | Gap close | `charge-intervene` | = |
| C3 | TODO | Mobilità | `heroic-leap-cursor` (@cursor) | = |
| C4 | TODO | AoE CC | `shockwave-howl` (Shockwave/Piercing Howl) | ~ |
| C5 | TODO | Interrupt | Pummel | = |

### D — Difensivi / utility (Shift-layer consigliato)

| Slot | Key | Ruolo | Fury | Arms | Tipo |
|---|---|---|---|---|---|
| D1 | TODO | Riflessione | Spell Reflection | Spell Reflection | = |
| D2 | TODO | CD personale | Enraged Regeneration | Die by the Sword | ≠ |
| D3 | TODO | Raid CD | Rallying Cry | Rallying Cry | = |
| D4 | TODO | Self-heal | Victory Rush / Impending Victory | Victory Rush / Impending Victory | = |

### E — Protection (occasionale, parked 2026-06-06)

Spec tank usata saltuariamente. Le **=/~** della griglia sopra valgono anche qui (stesso tasto/ruolo): A4 Execute, B3 `ravager-bladestorm` (solo se talenti Ravager — vedi caveat), C1 `avatar-reck-trinket` (→ Avatar+trinket), C2 `charge-intervene`, C3 `heroic-leap-cursor`, C4 `shockwave-howl`, D1/D3 Spell Reflection/Rallying Cry. Cambiano i filler (Shield Slam, Revenge, Thunder Clap, Devastate) e si aggiunge il layer tank.

| Slot | Key | Ruolo | Macro/Abilità | Tipo |
|---|---|---|---|---|
| A1 | TODO | Filler 1 | Shield Slam | ≠ |
| A2 | TODO | Filler 2 | Revenge | ≠ |
| A3 | TODO | AoE/maintain | Thunder Clap (`whirlwind-cleave` casta TC) | ≠ |
| A4 | TODO | Execute = | Execute | = |
| P1 | TODO | Active mitigation | Shield Block + Ignore Pain (tasti raw, no macro) | Prot-only |

> **Caveat B3:** in Prot `ravager-bladestorm` funziona solo con **Ravager talentato** (→ Ravager@cursor). Confermato 2026-06-07 che **nessuna** delle due build Prot MT (M+ e raid) talenta Ravager → in Prot lo slot è **inerte** (il fallback Bladestorm non esiste in Prot). L'AoE in Prot lo fa Thunder Clap (`whirlwind-cleave`).

## Bilancio allineamento

- **Fury raid (Slayer) ↔ Fury M+ (Mountain Thane):** ~**100% identico**. Le uniche due differenze (cleave applier B1, Avatar in C1) sono macro che si adattano da sole. Nessuno slot da rifare cambiando loadout.
- **Fury ↔ Arms:** slot **= / ~** invariati (A4, B3, C1–C5, D1, D3, D4) ≈ 10 bind che non cambiano mai. Cambiano solo i 3 filler (A1–A3) e i 2 CD cleave (B1–B2) + 1 difensivo (D2), e anche lì **tasto e ruolo restano gli stessi**.

## Bind decisi finora (account-wide, bindings-cache.wtf)

- **Q** = `ACTIONBUTTON5` (Barra 1, slot 5) → metti qui la macro `whirlwind-cleave` (NON Thunder Clap raw, altrimenti il tasto muore in raid Slayer). Bar 1 è per-spec: su Fury slot5 = `whirlwind-cleave`, su Arms slot5 = `sweeping-cleave`.
- **Shift+Q** = `MULTIACTIONBAR1BUTTON5` → **liberato** (Whirlwind non serve come tasto separato; la macro su Q lo copre). Riassegnabile a un difensivo o utility.

## Setup in-game (quando hai scelto i tasti)

1. Imposta i keybind (Game Menu → Keybindings) — sono account/character-wide, una volta sola.
2. Per **ogni spec**: trascina abilità/macro negli slot della Barra 1 secondo questa griglia (le macro `known:` vanno nello stesso slot in entrambe).
3. Le macro si creano col flusso normale in-game (NON editare macros-cache a mano); per far scrivere la cache fai **Exit Game** completo, non Logout.
4. Verifica che gli slot ~ mostrino l'icona giusta cambiando loadout (es. B1 deve diventare Thunder Clap in Mountain Thane).
