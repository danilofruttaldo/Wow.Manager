# weakauras/

Registro WeakAuras importate, con export string archiviata.

**Vincolo:** mai editare `WeakAuras.lua` (cache) direttamente. Workflow: import via export string in-game → salva la string in `imports/<slug>.txt` → registra in `manifest.json`.

> Quando possibile, **preferire un addon dedicato a una WA** per behavior changes (vedi feedback memory `feedback-wow-addon-over-weakaura`).

## File

- `manifest.json` — lista WA installate con source, scope, riferimento al file di import.
- `imports/<slug>.txt` — export string raw copiata dal box "Import string" di WeakAuras.

## Schema entry

```json
"<wa-id-slug>": {
  "name": "Fury Cooldowns",
  "source": "wago.io | manual | guide",
  "url": "https://wago.io/...",
  "version": "v3 | latest",
  "scope": "account | character | spec",
  "character": "Stantu",
  "spec": "Fury",
  "import_file": "imports/stantu-fury-cooldowns.txt",
  "installed": "YYYY-MM-DD",
  "notes": "..."
}
```
