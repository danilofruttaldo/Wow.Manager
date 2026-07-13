# CLAUDE.md — guida operativa (manutenzione ed estensione)

Come lavorare a questo repo con Claude Code **da qualsiasi postazione**, per aggiungere/modificare/rimuovere contenuti. Panoramica dei dati: [README.md](README.md).

## Cos'è

Due nature nello stesso repo:

1. **Dati** = fonte di verità: [addons/](addons/), [macros/](macros/), [professions/](professions/), [roster.md](roster.md), [ui-profiles/](ui-profiles/), [fonts/](fonts/), [scripts/](scripts/). Manifest JSON + markdown, mantenuti a mano.
2. **Sito statico** ([src/](src/), Astro) che presenta i dati su <https://wow.danilofruttaldo.com>. Il sito legge i dati in **sola lettura**: non li modifica mai. Ogni pagina si allinea da sola quando cambi il dato corrispondente.

Pagine del sito: **Home** (6 card), **Addon**, **Macro**, **Professioni**, **Roster**, **UI** (screenshot), **Extra** (script/link/note).

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
Oggetto `addons` con chiave = slug addon. Campi: `name, desc, version, interface, source, url, installed, folders[], notes`.
- **`desc` = testo mostrato sul sito**: una riga breve, "cosa fa l'addon". Concisa, niente storia/update.
- **`notes` = memoria interna di manutenzione, NON mostrata sul sito**: storia update, `DA RI-APPLICARE`, URL/id download, patch locali, caveat. La pagina `/addons` non la legge.
- La pagina `/addons` è una **griglia di card con ricerca live** (masonry, come `/macros`): icona + nome (link a `source`/`url`), badge versione, `desc`, n. cartelle, data `installed`. La ricerca filtra su nome/desc/versione/source/cartelle.
- **Icone**: avatar CurseForge in [public/icons/addon/](public/icons/addon/) come `<chiave>.<ext>` (png/jpg/jpeg, la **chiave** dell'oggetto `addons`, case-sensitive). Risolte a build-time in [content.ts](src/lib/content.ts) (`addonIcon`), niente campo nel manifest; se il file manca la card mostra un monogramma con l'iniziale. **Nuovo addon** → scarica l'`og:image` dalla pagina CurseForge (`https://media.forgecdn.net/avatars/...`) e salvalo con la chiave esatta.
- **Aggiungi/rimuovi**: aggiungi/togli la voce nell'oggetto `addons`.
- **Modifica**: cambia i campi (es. `version`, `desc`, `notes`). La pagina si aggiorna da sola.

### Macro → [macros/manifest.json](macros/manifest.json)
Oggetto `macros` con chiave = slug. Campi: `name, desc, scope, class, spec, character, slot, icon, body_file, body, notes`.
- **`desc` = testo mostrato sul sito**: una riga breve, "cosa fa il bottone" (es. «Mouseover su alleato → Remove Curse; sul nemico → Spellsteal»). Tienila concisa: niente date, storia o razionale.
- **`notes` = memoria interna di manutenzione, NON mostrata sul sito**: qui vanno date, `VERIFICATO`, riclassificazioni, richieste utente, caveat tecnici. È il "perché" delle scelte, per te che manutieni — la pagina `/macros` non lo legge più.
- La pagina `/macros` è una **griglia di card filtrabile per classe** (chip con icona) e, scelta una classe, **per spec** (le card `spec: null` restano visibili come cross-spec in ogni filtro spec). Ogni card mostra icona classe/spec, nome, `desc` e il **corpo reale** della macro (letto da `body_file`, con bottone "Copia").
- L'icona classe deriva da `class` (es. `warrior`, `death-knight` → `deathknight.jpg`); `class: null` → nessuna icona, la card finisce nel gruppo **Shared**. L'icona spec (se `spec` valorizzato) da `public/icons/spec/<classe-senza-trattino>-<spec>.jpg`.
- `body` nel JSON è quasi sempre `null`: il corpo vero sta nel file `body_file` (in [macros/](macros/), convenzione `<classe>/[<spec>/]<slug>.txt`, root classe per `spec: null`). Il sito legge il `.txt`.

### Professioni → [professions/manifest.json](professions/manifest.json)
Array `professions`. Ogni voce: `key, name, type` (`crafting`|`gathering`|`secondary`), `first`, `second`, `notes`.
`first`/`second` = `{ "spec": "...", "branch": "..." }` (spec da prendere + ramo da massimizzare, **nomi in inglese** come il client). Secondarie (Cooking/Fishing) → `first`/`second` = `null`.
- **Fonte dati reali**: build consigliate su <https://www.wow-professions.com/midnight/<prof>-specialization-guide-and-builds>. Aggiorna spec/branch quando cambiano con le patch.
- `key` deve combaciare col file icona in [public/icons/prof/](public/icons/prof/) (`<key>.jpg`).

### Roster: personaggi → [roster.md](roster.md)
Due tabelle markdown: `## Orda (...)` e `## Alleanza (...)`. Colonne = classi (War, Pal, …, Evo), righe = razze.
- **Aggiungi un PG**: scrivi il nome nella cella `razza × classe` del blocco giusto (Orda o Alleanza). Più nomi nella stessa cella → separali con `<br>`.
- **Combinazione non creabile**: `X` (resa come casella scura tratteggiata).
- **PG pianificato (TODO), non ancora creato**: prefisso `*` sul nome (es. `*Backstabbath`). Sul sito è reso in stile «da creare» (nome smorzato in corsivo + sottolineatura punteggiata, tooltip esplicativo) e **non entra nel conteggio** PG. Quando lo crei davvero, togli il `*`.
- **Suffisso realm** opzionale `·N`/`·P` accanto al nome: viene rimosso in visualizzazione, tienilo pure per i tuoi appunti.
- **Poi assegna la spec** del PG in `char-specs.ts` (sotto), altrimenti compare senza la lettera fra parentesi.
- **Sezioni nascoste**: `## Note sulle X` e i titoli/legende non compaiono sul sito (restano nel file). Le **razze condivise** (Pandaren, Dracthyr, Earthen, Haranir) vanno **solo** nel blocco Orda: se sono anche in Alleanza vengono saltate.

### Roster: spec dei PG → [src/lib/char-specs.ts](src/lib/char-specs.ts)
- `CHAR_SPEC`: chiave = **nome PG minuscolo** → nome spec. Il sito mostra la **prima lettera** fra parentesi (es. `stantu: 'fury'` → `Stantu (F)`).
- **PG omonimi** (stesso nome, PG diversi): usa `CHAR_SPEC_BY_RACE`, chiave `nome|razza` minuscolo (ha precedenza). Es. `furricane|vulpera: 'brewmaster'` e `furricane|worgen: 'frost'`.
- PG "in sospeso" (da recuperare): non metterli in `char-specs.ts` → restano senza lettera.

### Extra → [scripts/manifest.json](scripts/manifest.json)
Sezione contenitore libero: script di manutenzione, link, appunti tecnici. Oggetto `extra` con chiave = slug. Ogni voce ha `kind`:
- **`script`**: `name, desc, lang, when, warn, body_file, notes`. Il **corpo reale** vive in un file dentro [scripts/](scripts/) (es. `sync-game-settings.ps1`) e viene letto a build-time (glob `*.{sh,txt,lua,ps1,bat,py}`); la card mostra `desc`, `when` (quando eseguirlo), `warn` (avvertenza, con icona `warn.jpg`) e il corpo con bottone "Copia".
- **Windows/WoW → script in PowerShell** (`.ps1`): il gioco gira su Windows, quindi gli script di manutenzione si scrivono in PowerShell, non bash.
- **`link`**: `name, desc, url` → card con link esterno.
- **`note`**: `name, desc` → solo testo.
- **`desc` = testo mostrato sul sito** (riga breve). **`notes` = memoria interna, NON mostrata** (allowlist, caveat, storia).
- La pagina `/extra` è una **griglia di card compatte** (3 col, responsive). La card mostra icona, nome, `lang`, `desc`, `when`/`warn` e un hint "Apri · N righe"; **al click apre una modale** (pattern lightbox della pagina UI, overlay + `×`) col corpo completo e bottone "Copia". Le card `link` sono invece un `<a>` esterno (nessuna modale). Icona card: `section/extra.jpg` per gli script, `ui/shared.jpg` per link/note.
- **Aggiungi uno script**: metti il file in `scripts/` + voce in `extra` con `kind: "script"` e `body_file`. La card compare da sola.

### UI / screenshot → [public/screenshots/](public/screenshots/)
- **Aggiungi**: metti un file `<classe>-<spec>-<nome>.jpg` (es. `warrior-fury-stantu.jpg`). La pagina `/ui` lo raggruppa **per classe** leggendo classe/spec dal **nome file**.
- Alias classe nel filename: `deathknight`→Death Knight, `demonhunter`→Demon Hunter.
- **Rimuovi**: cancella il file. Aggiorna il conteggio "7" hardcoded in [src/pages/index.astro](src/pages/index.astro) (card UI) se cambia il numero.

### Icone (classe / razza / professione) → [public/icons/](public/icons/)
Immagini WoW dal CDN Wowhead: `https://wow.zamimg.com/images/wow/icons/large/<slug>.jpg`.
- Classi: `classicon_<slug>.jpg`. Razze: `race_<slug>_male.jpg`. Professioni: icone trade skill (es. `trade_alchemy`, `trade_blacksmithing`).
- Salvale in `public/icons/{class,race,prof}/` e mappa lo slug in [src/lib/content.ts](src/lib/content.ts): `CLASS_ABBR`, `RACE_ICON` (razza→file), o per le prof il file `<key>.jpg`.
- ⚠️ Alcuni slug interni differiscono dal nome: Undead→`scourge`, Haranir→scaricata da `race_harronir_male` ma salvata `haranir.jpg`, Earthen→`earthendwarf`, Lightforged Draenei→`lightforgeddraenei`.
- **Icone di stato / categoria** in [public/icons/ui/](public/icons/ui/): `ok.jpg` (aggiornato), `warn.jpg` (da aggiornare), `crafting.jpg`, `gathering.jpg` (chip Professioni), `shared.jpg` (macro cross-classe). Sono icone WoW rinominate in modo semantico (sorgenti: `inv_misc_gem_emerald_01`, `inv_misc_pocketwatch_01`, `inv_hammer_20`, `inv_misc_flower_02`, `inv_misc_note_02`).
- **Regola ferma: sul sito solo icone WoW.** Niente glifi Unicode (✓/⚠) o SVG disegnati come icone: se serve un simbolo, scarica l'icona WoW dal CDN e mettila in `public/icons/…`. Fanno eccezione i soli controlli del lightbox UI (× ‹ ›), che non sono icone di contenuto.

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
