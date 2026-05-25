# ui-profiles/

Profili esportabili di addon (Plater, Details!, ElvUI, Bartender, ecc.).

Stesso pattern di `weakauras/`: export string raw in `exports/`, metadata in `manifest.json`.

## Schema entry

```json
"<addon>-<profile-slug>": {
  "addon": "Plater | Details | ElvUI | Bartender4 | ...",
  "name": "Stantu Fury Nameplates",
  "source": "wago.io | manual",
  "url": "https://wago.io/...",
  "version": "v2",
  "scope": "account | character | spec",
  "character": "Stantu",
  "spec": "Fury",
  "export_file": "exports/plater-stantu-fury.txt",
  "installed": "YYYY-MM-DD",
  "notes": "..."
}
```
