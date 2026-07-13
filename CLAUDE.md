# CLAUDE.md — guida operativa (manutenzione ed estensione)

Come lavorare a questo repo con Claude Code **da qualsiasi postazione**, per aggiungere/modificare/rimuovere contenuti. Panoramica dei dati: [README.md](README.md).

## Cos'è

Due nature nello stesso repo:

1. **Dati** = fonte di verità: [addons/](addons/), [macros/](macros/), [professions/](professions/), [roster.md](roster.md), [ui-profiles/](ui-profiles/), [fonts/](fonts/). Manifest JSON + markdown, mantenuti a mano.
2. **Sito statico** ([src/](src/), Astro) che presenta i dati su <https://wow.danilofruttaldo.com>. Il sito legge i dati in **sola lettura**: non li modifica mai. Ogni pagina si allinea da sola quando cambi il dato corrispondente.

Pagine del sito: **Home** (5 card), **Addon**, **Macro**, **Professioni**, **Roster**, **UI** (screenshot).

## Setup su una postazione nuova

```bash
git clone <repo> Wow.Manager && cd Wow.Manager
npm install            # richiede Node >= 22.12
npm run dev            # dev server; oppure F5 in VS Code -> "Sito locale (dev)"
```

`node_modules/`, `dist/`, `.astro/` sono generati e git-ignored: **mai committarli**.

---

## Operazioni sui contenuti (aggiungi / modifica / rimuovi)

Dopo ogni modifica: `npm run build` per verificare, poi **commit + push** (il push pubblica e aggiorna anche la data "sync" — vedi sotto).

### Addon → [addons/manifest.json](addons/manifest.json)
Oggetto `addons` con chiave = slug addon. Campi: `name, version, interface, source, url, installed, folders[], notes`.
- **Aggiungi/rimuovi**: aggiungi/togli la voce nell'oggetto `addons`.
- **Modifica**: cambia i campi (es. `version`, `notes`). La tabella `/addons` si aggiorna da sola.

### Macro → [macros/manifest.json](macros/manifest.json)
Oggetto `macros` con chiave = slug. Campi: `name, scope, class, spec, character, slot, icon, notes`.
- L'icona classe nella tabella `/macros` deriva da `class` (es. `warrior`, `death-knight` → `deathknight.jpg`). `class: null` → nessuna icona.

### Professioni → [professions/manifest.json](professions/manifest.json)
Array `professions`. Ogni voce: `key, name, type` (`crafting`|`gathering`|`secondary`), `first`, `second`, `notes`.
`first`/`second` = `{ "spec": "...", "branch": "..." }` (spec da prendere + ramo da massimizzare, **nomi in inglese** come il client). Secondarie (Cooking/Fishing) → `first`/`second` = `null`.
- **Fonte dati reali**: build consigliate su <https://www.wow-professions.com/midnight/<prof>-specialization-guide-and-builds>. Aggiorna spec/branch quando cambiano con le patch.
- `key` deve combaciare col file icona in [public/icons/prof/](public/icons/prof/) (`<key>.jpg`).

### Roster: personaggi → [roster.md](roster.md)
Due tabelle markdown: `## Orda (...)` e `## Alleanza (...)`. Colonne = classi (War, Pal, …, Evo), righe = razze.
- **Aggiungi un PG**: scrivi il nome nella cella `razza × classe` del blocco giusto (Orda o Alleanza). Più nomi nella stessa cella → separali con `<br>`.
- **Combinazione non creabile**: `X` (resa come casella scura tratteggiata).
- **Suffisso realm** opzionale `·N`/`·P` accanto al nome: viene rimosso in visualizzazione, tienilo pure per i tuoi appunti.
- **Poi assegna la spec** del PG in `char-specs.ts` (sotto), altrimenti compare senza la lettera fra parentesi.
- **Sezioni nascoste**: `## Note sulle X` e i titoli/legende non compaiono sul sito (restano nel file). Le **razze condivise** (Pandaren, Dracthyr, Earthen, Haranir) vanno **solo** nel blocco Orda: se sono anche in Alleanza vengono saltate.

### Roster: spec dei PG → [src/lib/char-specs.ts](src/lib/char-specs.ts)
- `CHAR_SPEC`: chiave = **nome PG minuscolo** → nome spec. Il sito mostra la **prima lettera** fra parentesi (es. `stantu: 'fury'` → `Stantu (F)`).
- **PG omonimi** (stesso nome, PG diversi): usa `CHAR_SPEC_BY_RACE`, chiave `nome|razza` minuscolo (ha precedenza). Es. `furricane|vulpera: 'brewmaster'` e `furricane|worgen: 'frost'`.
- PG "in sospeso" (da recuperare): non metterli in `char-specs.ts` → restano senza lettera.

### UI / screenshot → [public/screenshots/](public/screenshots/)
- **Aggiungi**: metti un file `<classe>-<spec>-<nome>.jpg` (es. `warrior-fury-stantu.jpg`). La pagina `/ui` lo raggruppa **per classe** leggendo classe/spec dal **nome file**.
- Alias classe nel filename: `deathknight`→Death Knight, `demonhunter`→Demon Hunter.
- **Rimuovi**: cancella il file. Aggiorna il conteggio "7" hardcoded in [src/pages/index.astro](src/pages/index.astro) (card UI) se cambia il numero.

### Icone (classe / razza / professione) → [public/icons/](public/icons/)
Immagini WoW dal CDN Wowhead: `https://wow.zamimg.com/images/wow/icons/large/<slug>.jpg`.
- Classi: `classicon_<slug>.jpg`. Razze: `race_<slug>_male.jpg`. Professioni: icone trade skill (es. `trade_alchemy`, `trade_blacksmithing`).
- Salvale in `public/icons/{class,race,prof}/` e mappa lo slug in [src/lib/content.ts](src/lib/content.ts): `CLASS_ABBR`, `RACE_ICON` (razza→file), o per le prof il file `<key>.jpg`.
- ⚠️ Alcuni slug interni differiscono dal nome: Undead→`scourge`, Haranir→scaricata da `race_harronir_male` ma salvata `haranir.jpg`, Earthen→`earthendwarf`, Lightforged Draenei→`lightforgeddraenei`.

---

## Data "sync" in topbar (automatica)

La topbar mostra `build <build> · sync <data>`. Il `build` = `_meta.wow_build` di `addons/manifest.json`. La **data sync è per-pagina** e vale l'**ultimo commit git del file sorgente** di quella pagina (mappa rotta→file in [Base.astro](src/layouts/Base.astro)). Non c'è nulla da mantenere a mano: **committa** il dato che hai cambiato e la data si aggiorna. Perché funzioni anche in produzione il workflow usa `fetch-depth: 0` (storia git completa).

## Architettura sito (dove metto le mani)

- [src/layouts/Base.astro](src/layouts/Base.astro) — header (brand + badge build/sync centrale + nav) e footer. Tema chiaro unico, font Inter.
- [src/styles/global.css](src/styles/global.css) — token palette + componenti (`.ico`, tabelle, tiles). **`.ico` ha `max-width: none`**: NON rimuoverlo, evita che le icone si schiaccino nelle tabelle auto-layout.
- [src/lib/content.ts](src/lib/content.ts) — lettura dati + `getAddons/getMacros/getProfessions/getRosterHtml/getRosterCount/sourceDate`, mappe icone, rendering roster.
- [src/lib/char-specs.ts](src/lib/char-specs.ts) — spec PG.
- [src/pages/](src/pages/) — `index` (card), `addons`, `macros`, `professioni`, `roster`, `ui`, `404`. Le pagine **non hanno titoli/sottotitoli** (scelta voluta): partono col contenuto.

## Verifica e dev

```bash
npm run build      # deve completare senza errori; poi: rm -rf .astro dist
```
Per il debug visivo usa **F5** (o `npm run dev`). ⚠️ **NON** eseguire `astro dev stop`: ferma il daemon dev **condiviso** di Astro, quindi ammazza anche il tuo server F5. Per test isolati usa una porta dedicata e chiudi solo quel processo.

## Deploy

Push su `main` → GitHub Actions ([.github/workflows/deploy.yml](.github/workflows/deploy.yml)) builda e pubblica su GitHub Pages. Custom domain `wow.danilofruttaldo.com` (Settings → Pages → Source: **GitHub Actions**; se torna 404 controlla che il Custom domain non si sia svuotato). DNS: record **CNAME** `wow` → `danilofruttaldo.github.io`.

## Vincoli git del repo (hook attivi — rispettali)

- **Niente** trailer `Co-Authored-By` nei messaggi di commit (bloccato).
- **Titolo commit ≤ 72 caratteri** (bloccato).
- Si lavora **direttamente su `main`**; il deploy parte da lì.
- `.gitignore` usa `.vscode/*` (non `.vscode/`) così `launch.json` resta versionabile.
