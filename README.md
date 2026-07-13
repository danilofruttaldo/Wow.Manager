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
| [fonts/](fonts/) | Override font UI Blizzard (nomi-override in `Fonts/`) | `fonts/manifest.json` |
| [builds/](builds/) | Talent/gear build per char/spec/contenuto | un `.md` per build |
| [roster.md](roster.md) | Tracker PG Horde per razza × classe (copertura combo) | `SavedVariables/Syndicator.lua` |
| [docs/](docs/) | Sito GitHub Pages (macro, roster, addon, screenshot) | dati generati in `docs/data/` |

## Regole operative

1. **Mai editare cache files** (`edit-mode-cache`, `macros-cache`) direttamente. Usare flow in-game ed export string.
2. **Macro/WA/profili UI**: lavorare in sola lettura/backup dei file in `WTF/` o tramite export string dall'utente in-game.
3. **Addon**: verificare TOC `Interface` vs build retail prima di installare. Aggiornare il manifest dopo ogni operazione.
4. **Preferire addon dedicato a WeakAura** per behavior changes, salvo casi particolari.

## Workflow tipici

- **Install addon**: verifica compat → estrai in `_retail_/Interface/AddOns/` → entry in `addons/manifest.json` → log in `addons/installs.log`.
- **Backup macro**: copia testo macro in-game → file in `macros/exports/<char>-<slot>.txt` → entry in `macros/manifest.json`.
- **Sync/audit**: confronta manifest vs filesystem reale per detect drift.

## Sito (GitHub Pages)

Sito statico in [`docs/`](docs/) con 4 pagine — **Macro**, **Roster**, **Addon**, **Screenshot** — più la home. Le pagine leggono i dati via `fetch` da `docs/data/` (nessun dato duplicato a mano nell'HTML). Tema scuro unico, colori-classe Blizzard, tipografia serif+mono.

- **Dati generati** (`docs/data/*.json`): NON editare a mano. Rigenerali con [`sync-site.sh`](sync-site.sh):
  - `macros.json` / `addons.json` ← copie dei manifest (fonte di verità)
  - `roster.json` ← matrice razza×classe + **spec** dei PG (fonte roster del sito; allineare con `roster.md`)
  - `screenshots.json` ← elenco dei file in `docs/screenshots/` (nomi `classe-spec-personaggio.jpg`)
- **Screenshot**: copiati a piena risoluzione da `_retail_/Screenshots/` da `sync-site.sh`.
- **Aggiornare il sito**: `./sync-site.sh` poi commit. Per un nuovo screenshot basta salvarlo in gioco come `classe-spec-personaggio.jpg` e rilanciare lo script.

### Abilitare Pages
Su GitHub: **Settings → Pages → Build and deployment → Source: Deploy from a branch**, branch `main` (o quello scelto), cartella **`/docs`**. L'URL sarà `https://danilofruttaldo.github.io/Wow.Manager/`.

> Nota: le pagine su Pages sono **pubbliche** anche se il repo è privato.
