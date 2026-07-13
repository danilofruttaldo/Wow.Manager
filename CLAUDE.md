# CLAUDE.md — guida per manutenere ed estendere il progetto

Istruzioni operative per lavorare a questo repo con Claude Code, **anche da una postazione nuova**.
Vedi [README.md](README.md) per la panoramica dei domini dati.

## Cos'è

Un repo con due nature:

1. **Dati** (fonte di verità): [addons/](addons/), [macros/](macros/), [ui-profiles/](ui-profiles/), [fonts/](fonts/), [roster.md](roster.md). Sono manifest JSON + markdown.
2. **Sito statico** (in `src/`, Astro) che presenta quei dati su <https://wow.danilofruttaldo.com>. Il sito legge i dati in **sola lettura**: non li modifica mai.

## Setup su una postazione nuova

```bash
git clone <repo> Wow.Manager && cd Wow.Manager
npm install            # richiede Node >= 22.12
npm run dev            # dev server; oppure F5 in VS Code -> "Sito locale (dev)"
```

`node_modules/`, `dist/`, `.astro/` sono generati e git-ignored: **non committarli**. Dopo un `npm run build` di verifica, ripulisci con `rm -rf .astro dist`.

## Architettura del sito

- **Layout**: [src/layouts/Base.astro](src/layouts/Base.astro) — header/nav/footer, tema chiaro unico (niente toggle), font Inter.
- **Stili**: [src/styles/global.css](src/styles/global.css) — token neutri + componenti densi (tabelle, tiles). Palette "tool", non fantasy.
- **Accesso ai dati**: [src/lib/content.ts](src/lib/content.ts) — legge i manifest/markdown *fuori da `src/`* via import JSON e `import.meta.glob(..., '?raw')`. Espone `getAddons`, `getMacros`, `getRosterHtml`, ecc.
- **Pagine**: [src/pages/](src/pages/) — `index`, `addons`, `macros`, `roster`, `ui`, `404`.
- **Asset**: [public/icons/](public/icons/) (classe + razza), [public/screenshots/](public/screenshots/) (UI dei PG).

## Convenzioni e trappole (importante)

### Roster ([src/lib/content.ts](src/lib/content.ts) + [src/pages/roster.astro](src/pages/roster.astro))
- La tabella è **costruita in HTML** da `getRosterHtml()` a partire dalle due tabelle markdown di `roster.md` (`## Orda` e `## Alleanza`), non renderizzata direttamente da marked.
- Sezione `## Note sulle X` di `roster.md`: **nascosta** dal sito (resta nel file).
- **Razze condivise** (Pandaren, Dracthyr, Earthen, Haranir): stanno solo nel blocco Orda; nel blocco Alleanza vengono saltate se già presenti in Orda.
- **Colori fazione**: Orda tende al rosso, Alleanza al blu (classi CSS `fac-horde`/`fac-alliance`, bande `rsep--horde`/`rsep--alliance`).
- **Combo non ottenibili** (`X` nel markdown): rese come casella **scura tratteggiata** (`.na` + CSS), nessun testo.
- **Suffisso realm** (`·N`/`·P` in `roster.md`): rimosso in visualizzazione (`stripRealm`).

### Spec dei personaggi ([src/lib/char-specs.ts](src/lib/char-specs.ts))
- `roster.md` contiene solo i **nomi** dei PG. La spec (mostrata come prima lettera fra parentesi, es. `Stantu (F)`) sta in `CHAR_SPEC`, chiave = nome PG minuscolo.
- **PG omonimi**: usa `CHAR_SPEC_BY_RACE`, chiave `nome|razza` (ha precedenza). Es. Furricane è Vulpera Monk (Brewmaster) nell'Orda e Worgen DK (Frost) in Alleanza.
- Per aggiungere una spec: aggiungi la riga in `char-specs.ts` (o in `char-specs.ts` `CHAR_SPEC_BY_RACE` se collide).

### Icone
- Fonte: CDN Wowhead `https://wow.zamimg.com/images/wow/icons/large/` (classi `classicon_<slug>.jpg`, razze `race_<slug>_male.jpg`).
- Scaricate in locale (`public/icons/`) per restare self-contained. Slug razza mappati in `RACE_ICON` (attenzione: alcuni slug interni differiscono dal nome, es. Undead→`scourge`, Haranir→file `haranir.jpg` scaricato da `race_harronir_male`).
- Per una **nuova razza/classe**: scarica l'icona in `public/icons/{race,class}/`, poi aggiorna la mappa in `content.ts`.

### Aggiungere contenuti
- **Nuovo PG nel roster**: edita `roster.md` (metti il nome nella cella razza×classe giusta, blocco Orda o Alleanza) e la sua spec in `char-specs.ts`.
- **Nuovo screenshot UI**: aggiungi `public/screenshots/<classe>-<spec>-<nome>.jpg` (la pagina `/ui` lo raggruppa per classe leggendo classe/spec dal filename; alias `deathknight`→`death-knight`, `demonhunter`→`demon-hunter`).
- **Addon/macro**: aggiorna i rispettivi `manifest.json` (fonte di verità); il sito si aggiorna da solo.

## Verifica prima di committare

```bash
npm run build                 # deve completare senza errori
# opzionale: screenshot headless per controllo visivo
npx astro dev stop; (npm run dev -- --port 4321 &) ; sleep 5
# Edge headless: msedge --headless=new --screenshot=out.png http://localhost:<porta>/roster
rm -rf .astro dist            # pulizia artefatti generati
```

## Deploy

Push su `main` → GitHub Actions ([.github/workflows/deploy.yml](.github/workflows/deploy.yml)) builda e pubblica su GitHub Pages.
Settings → Pages → **Source: GitHub Actions** e **Custom domain: `wow.danilofruttaldo.com`** (se il 404 torna, ricontrolla che il Custom domain non si sia svuotato).

## Vincoli git del repo (hook attivi)

- **Niente** trailer `Co-Authored-By` nei messaggi di commit (l'hook lo blocca).
- **Titolo del commit ≤ 72 caratteri** (l'hook lo blocca).
- Si lavora **direttamente su `main`** (nessuna PR nella storia); il deploy parte da `main`.
- `.gitignore`: usa `.vscode/*` (non `.vscode/`) così `launch.json` resta versionabile.
