# macros/

Backup e gestione macro WoW.

**Vincolo:** mai editare `macros-cache.txt` direttamente. Workflow: macro creata/modificata in-game → export del testo → salva in `<classe>/<spec>/<slug>.txt` (o `shared/` se account-wide non class-specific) → registra in `manifest.json`.

## Struttura

```
macros/
  manifest.json              ← unico, fonte di verità per tutte le macro
  shared/                    ← macro account-wide cross-class (mount, /target, /tt, generiche)
  <class>/<spec>/<slug>.txt  ← export body, una macro per file (es. warrior/fury/burst-all-in.txt)
```

Classi scaffoldate: death-knight, demon-hunter, druid, evoker, hunter, mage, monk, paladin, priest, rogue, shaman, warlock, warrior.

Le cartelle servono solo a organizzare i file di export. Lo **stato** vive nel manifest unico (campo `class` e `spec` discriminano).

## Schema entry manifest

```json
"<macro-id-slug>": {
  "name": "Charge+Pummel",
  "scope": "account",
  "class": "warrior",
  "spec": "fury",
  "character": null,
  "slot": 1,
  "icon": "INV_Misc_QuestionMark",
  "body_file": "warrior/fury/charge-pummel.txt",
  "body": null,
  "notes": "..."
}
```

- **Tutte le macro stanno nel tab account-wide (General Macros).** Il discriminante è la **classe** (`class`), non il personaggio: una macro warrior è account-wide ma utile solo su warrior. `scope` è sempre `account`; `character` è sempre `null` (il tab character-specific non viene usato).
- `spec` (`fury`/`arms`/`protection`/`null`) indica per quale spec/loadout la macro è pensata; `null` = cross-spec.
- `class=null` per macro shared/ (mount, marker, generiche cross-class).
- Preferire `body_file` a `body` inline — più leggibile in diff e riusabile.
