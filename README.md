# Wow.Manager

Stato esterno alla cartella di gioco per il setup WoW Retail di [Stantu](addons/manifest.json).
La cartella di WoW è considerata **output ricostruibile** da questo repo.

WoW install: `c:\Program Files (x86)\World of Warcraft\_retail_`
WTF root:    `c:\Program Files (x86)\World of Warcraft\_retail_\WTF`

## Domini

| Cartella | Cosa contiene | Fonte di verità |
|---|---|---|
| [addons/](addons/) | Addon installati, versioni, source, folder list | `addons/manifest.json` |
| [macros/](macros/) | Macro per classe/spec con body, slot, icon | `macros/manifest.json` |
| [professions/](professions/) | Alberi di specializzazione (dal client) + leveling 1→max (web) per professione | `professions/` (`trees.json`, `leveling.json`, `manifest.json`) |
| [transmog/](transmog/) | Set dei raid per classe: righe tier, versioni, pezzi collezionati | `transmog/manifest.json` |
| [ui-profiles/](ui-profiles/) | Profili addon (Plater, Details, ecc.) | `ui-profiles/manifest.json` |
| [fonts/](fonts/) | Override font UI Blizzard (nomi-override in `Fonts/`) | `fonts/manifest.json` |
| [roster.md](roster.md) | Tracker PG per razza × classe, Orda + Alleanza (copertura combo) | `roster.md` |
| [scripts/](scripts/) | Sezione "Extra": script di manutenzione, link e appunti tecnici | `scripts/manifest.json` |

## Regole operative

1. **Mai editare cache files** (`edit-mode-cache`, `macros-cache`) direttamente. Usare flow in-game ed export string.
2. **Macro/WA/profili UI**: lavorare in sola lettura/backup dei file in `WTF/` o tramite export string dall'utente in-game.
3. **Addon**: verificare TOC `Interface` vs build retail prima di installare. Aggiornare il manifest dopo ogni operazione.
4. **Preferire addon dedicato a WeakAura** per behavior changes, salvo casi particolari.

## Workflow tipici

- **Install addon**: verifica compat → estrai in `_retail_/Interface/AddOns/` → entry in `addons/manifest.json` → log in `addons/installs.log`.
- **Backup macro**: copia testo macro in-game → file in `macros/<classe>/[<spec>/]<slug>.txt` → entry in `macros/manifest.json` con `body_file` che punta a quel file.
- **Sync/audit**: confronta manifest vs filesystem reale per detect drift.

## Sito

Il repo pubblica anche un sito statico che presenta i dati (addon, macro, professioni, roster, transmog, UI, extra):

- **URL**: <https://wow.danilofruttaldo.com>
- **Stack**: [Astro](https://astro.build) (statico), sorgente in `src/`, dati letti dai manifest/markdown del repo.
- **Sviluppo locale**: `npm install` una volta, poi `npm run dev` (o **F5** in VS Code → "Sito locale (dev)"). Richiede **Node ≥ 22.12**.
- **Deploy**: automatico su **GitHub Pages** via GitHub Actions ([.github/workflows/deploy.yml](.github/workflows/deploy.yml)) a ogni push su `main`. Dominio in [public/CNAME](public/CNAME).

Il sito **non** modifica i dati: li legge in sola lettura. La fonte di verità resta nei manifest/`roster.md`.
Per manutenerlo/estenderlo (anche da un'altra postazione) vedi **[CLAUDE.md](CLAUDE.md)**.

## Licenza

La [MIT](LICENSE) copre **solo** il lavoro originale di questo repo: il codice del sito (`src/`), gli script di manutenzione (`scripts/`) e i file di dati redazionali (manifest e markdown scritti qui). **Non** copre — né potrebbe — il materiale di terzi che il repo trasporta, elencato in **[NOTICE](NOTICE)** e di proprietà dei rispettivi titolari:

- **World of Warcraft**, i suoi nomi, le icone (`public/icons/`) e gli screenshot di gioco (`public/screenshots/`) sono © e marchi di **Blizzard Entertainment, Inc.**; le icone sono reperite tramite [Wowhead](https://www.wowhead.com). Questo è un progetto **fan non ufficiale e non commerciale**, non affiliato né approvato da Blizzard, pubblicato in linea con i [termini legali Blizzard](https://www.blizzard.com/en-us/legal) per i contenuti dei fan.
- Gli **avatar degli addon** (`public/icons/addon/`) appartengono ai rispettivi autori, reperiti tramite [CurseForge](https://www.curseforge.com).
- I **font web** Inter e JetBrains Mono (`public/fonts/`) sono sotto **SIL Open Font License 1.1** — testo in [public/fonts/OFL.txt](public/fonts/OFL.txt).
