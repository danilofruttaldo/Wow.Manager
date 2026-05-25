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
  "scope": "account | character",
  "class": "warrior",
  "spec": "fury",
  "character": "Stantu-PozzoDellEternita",
  "slot": 1,
  "icon": "INV_Misc_QuestionMark",
  "body_file": "warrior/fury/charge-pummel.txt",
  "body": null,
  "notes": "..."
}
```

- `scope=account` → max 120 slot, valida per tutti i char (slot account 1-120).
- `scope=character` → slot 121-138, char-specific.
- `class=null` per macro shared/ (mount, marker, generiche).
- Preferire `body_file` a `body` inline — più leggibile in diff e riusabile.
