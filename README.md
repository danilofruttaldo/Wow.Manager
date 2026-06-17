# Wow.Manager

Stato esterno alla cartella di gioco per il setup WoW Retail di [Stantu](addons/manifest.json).
La cartella di WoW è considerata **output ricostruibile** da questo repo.

WoW install: `c:\Program Files (x86)\World of Warcraft\_retail_`
WTF root:    `c:\Program Files (x86)\World of Warcraft\_retail_\WTF`

## Domini

| Cartella | Cosa contiene | Fonte di verità |
|---|---|---|
| [addons/](addons/) | Addon installati, versioni, source, folder list | `addons/manifest.json` |
| [macros/](macros/) | Macro per account/character con body, slot, icon | `macros/manifest.json` |
| [ui-profiles/](ui-profiles/) | Profili addon (Plater, Details, ecc.) | `ui-profiles/manifest.json` |
| [builds/](builds/) | Talent/gear build per char/spec/contenuto | un `.md` per build |
| [scripts/](scripts/) | Utility (sync, audit, backup WTF) | — |

## Regole operative

1. **Mai editare cache files** (`edit-mode-cache`, `macros-cache`) direttamente. Usare flow in-game ed export string.
2. **Macro/WA/profili UI**: lavorare in sola lettura/backup dei file in `WTF/` o tramite export string dall'utente in-game.
3. **Addon**: verificare TOC `Interface` vs build retail prima di installare. Aggiornare il manifest dopo ogni operazione.
4. **Preferire addon dedicato a WeakAura** per behavior changes, salvo casi particolari.

## Workflow tipici

- **Install addon**: verifica compat → estrai in `_retail_/Interface/AddOns/` → entry in `addons/manifest.json` → log in `addons/installs.log`.
- **Backup macro**: copia testo macro in-game → file in `macros/exports/<char>-<slot>.txt` → entry in `macros/manifest.json`.
- **Sync/audit**: confronta manifest vs filesystem reale per detect drift.
