# addons/

Inventario degli addon installati in `_retail_/Interface/AddOns/`.

## File

- `manifest.json` — fonte di verità: lista addon con `desc` (riga mostrata sul sito, "cosa fa l'addon"), `version`, `interface` (TOC), `source`, `url`, `folders`, `installed`, `notes` (memoria interna di manutenzione, **non** mostrata sul sito).
- `installs.log` — append-only di operazioni (INIT/INSTALL/UPDATE/REMOVE con timestamp).

## Schema entry

```json
"<AddonKey>": {
  "name": "Display Name",
  "desc": "riga breve: cosa fa l'addon (mostrata sul sito)",
  "version": "x.y.z | unknown",
  "interface": "120005, 120007",
  "source": "curseforge | github | wago | archon | manual",
  "url": "https://...",
  "installed": "YYYY-MM-DD | pre-existing",
  "folders": ["FolderName1", "FolderName2"],
  "notes": "..."
}
```

## Operazioni

| Op | Steps |
|---|---|
| INSTALL | check TOC vs build → estrai in AddOns → add entry → append log |
| UPDATE  | confronta version → scarica → sostituisci folder → bump entry → append log |
| REMOVE  | rimuovi folder → drop entry → append log |
| SYNC    | scan AddOns dir → diff con manifest → riporta drift |
