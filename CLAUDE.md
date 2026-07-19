# CLAUDE.md — guida operativa (manutenzione ed estensione)

Come lavorare a questo repo con Claude Code **da qualsiasi postazione**, per aggiungere/modificare/rimuovere contenuti. Panoramica dei dati: [README.md](README.md).

## Cos'è

Due nature nello stesso repo:

1. **Dati** = fonte di verità: [addons/](addons/), [macros/](macros/), [professions/](professions/), [roster.md](roster.md), [transmog/](transmog/), [ui-profiles/](ui-profiles/), [fonts/](fonts/), [scripts/](scripts/). Manifest JSON + markdown, mantenuti a mano.
2. **Sito statico** ([src/](src/), Astro) che presenta i dati su <https://wow.danilofruttaldo.com>. Il sito legge i dati in **sola lettura**: non li modifica mai. Ogni pagina si allinea da sola quando cambi il dato corrispondente.

Pagine del sito: **Home** (7 card), **Addon**, **Macro**, **Professioni**, **Roster**, **Transmog** (tier set), **UI** (screenshot), **Extra** (script/link/note).

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
Array `professions`. Ogni voce: `key, name, type` (`crafting`|`gathering`), `first`, `second`, `third`, `notes`.
`first`/`second`/`third` = `{ "spec": "...", "branch": "..." }` (spec da prendere + ramo da massimizzare, **nomi in inglese** come il client): sono le **tre tappe in ordine** rese sulla card come classifica ①→②→③. Una tappa a `null` esce come "—".
- **Solo professioni primarie**: le secondarie (Cooking/Fishing) non hanno albero di specializzazione e stanno fuori dal manifest — la pagina è tutta costruita sulle tre tappe, una card con tre trattini non direbbe nulla.
- **Fonte dati reali**: build consigliate su <https://www.wow-professions.com/midnight/<prof>-specialization-guide-and-builds>. Aggiorna spec/branch quando cambiano con le patch. ⚠️ **Skinning è l'eccezione**: quell'URL 404, la guida sta su `/guides/wow-skinning-leveling-guide`. Le pagine **non sono datate** (solo footer `© anno`): non si può stabilire da lì per quale patch valgano.
- `branch` deve essere il **nome di un nodo reale** dell'albero, non una descrizione: se non lo conosci, verifica sulla guida invece di inventare un'etichetta (`Root node` è accettabile per il tronco). Se devii apposta dalla guida, scrivi il perché in `notes`.
- `key` deve combaciare col file icona in [public/icons/prof/](public/icons/prof/) (`<key>.jpg`).

### Roster: personaggi → [roster.md](roster.md)
Due tabelle markdown: `## Orda (...)` e `## Alleanza (...)`. Colonne = classi (War, Pal, …, Evo), righe = razze.
- **Aggiungi un PG**: scrivi il nome nella cella `razza × classe` del blocco giusto (Orda o Alleanza). Più nomi nella stessa cella → separali con `<br>`.
- **Combinazione non creabile**: `X` (resa come casella scura tratteggiata).
- **PG pianificato (TODO), non ancora creato**: prefisso `*` sul nome (es. `*Backstabbath`). Sul sito è reso in stile «da creare» (nome smorzato in corsivo + sottolineatura punteggiata, tooltip esplicativo) e **non entra nel conteggio** PG. Quando lo crei davvero, togli il `*`.
- **PG esistente ma non ancora al level cap** (in leveling): prefisso `_` sul nome (es. `_Orconauta·P`). Sul sito il nome è reso in **corsivo** (classe `pg--wip`, tooltip) e **conta** come PG normale. Quando arriva al cap (90), togli il `_`. Fonte livelli: `SavedVariables/AllTheThings.lua` (chiave `lvl` per PG loggati con ATT); i PG non tracciati da ATT o omonimi non risolvibili restano senza prefisso.
- **Suffisso realm** opzionale `·N`/`·P` accanto al nome: viene rimosso in visualizzazione, tienilo pure per i tuoi appunti.
- **Poi assegna la spec** del PG in `char-specs.ts` (sotto), altrimenti compare senza la lettera fra parentesi.
- **Sezioni nascoste**: `## Note sulle X` e i titoli/legende non compaiono sul sito (restano nel file). Le **razze condivise** (Pandaren, Dracthyr, Earthen, Haranir) vanno **solo** nel blocco Orda: se sono anche in Alleanza vengono saltate.

### Roster: spec dei PG → [src/lib/char-specs.ts](src/lib/char-specs.ts)
- `CHAR_SPEC`: chiave = **nome PG minuscolo** → nome spec. Il sito mostra la **prima lettera** fra parentesi (es. `stantu: 'fury'` → `Stantu (F)`).
- **PG omonimi** (stesso nome, PG diversi): usa `CHAR_SPEC_BY_RACE`, chiave `nome|razza` minuscolo (ha precedenza). Es. `furricane|vulpera: 'brewmaster'` e `furricane|worgen: 'frost'`.
- PG "in sospeso" (da recuperare): non metterli in `char-specs.ts` → restano senza lettera.

### Transmog (set dei raid) → [transmog/manifest.json](transmog/manifest.json)
Collezione dei set dei raid, **per classe**. La pagina `/transmog` è a **tab per classe** (chip con icona, selezione singola): scelta la classe vedi la sua matrice **righe = raid** (in ordine cronologico, raggruppati per espansione) × **colonne = versione**.
- **`tiers`**: definizione delle righe, una volta sola per tutte le classi. Campi: `key, tier` (numero tier dove esiste, altrimenti la patch: `8.2`), `name` (raid), `exp`, `pieces` (pezzi per versione), `versions`, `names`, `raids`, `note`, `warn`.
- **`names`** = nome vero del set **per classe** (`{ "warrior": "Battlegear of Might", … }`): è quello che la riga mostra in grassetto, quindi cambia col tab. Manca la classe → la riga ripiega sul `name` del raid. **`raids`** = `[["BWL","Blackwing Lair"], …]`, rese come sigle accanto al nome (oggi solo la sigla: il nome completo è lì per quando servirà).
- ⚠️ **La pagina non ha NESSUN tooltip: è una scelta esplicita, non una dimenticanza.** Niente `title=`, niente `<abbr>`, niente icone che esistono solo per essere sorvolate. `note` e `warn` restano nel manifest come **memoria interna** (come `notes` altrove nel repo): non vengono più mostrati. Se un'informazione serve al lettore, va scritta in chiaro nella pagina.
- **Una riga = un set da collezionare**, non un raid. I raid senza set proprio non hanno una riga: o spariscono, o finiscono nel `name` della riga del set a cui contribuiscono (es. il T19 si chiama «The Emerald Nightmare · Trial of Valor · The Nighthold» perché il set viene dal Nighthold ma gli altri due appartengono allo stesso ciclo). Ogni riga ha almeno una versione: le righe «vuote» non esistono più, e il codice che le reggeva è stato tolto.
- **Set di classe vs set per tipo di armatura**: da BfA in poi (più Zul'Aman, Sunwell e i set LFR di WoD) i set non sono di classe ma per tipo di armatura, quindi identici per tutte le classi che portano quel tipo. **Il sito non lo segnala**: scelta voluta, quello che conta è il completamento. Non reintrodurre badge o icone per distinguerli.
- **Le 4 colonne sono SLOT di versione, non difficoltà letterali.** Prima di Cataclysm gli assi erano altri (10/25 uomini, fazione nel T9, Sanctified nel T10): ogni riga dichiara in `versions` l'**etichetta reale** di ogni slot che usa, mostrata nel tooltip della cella. Gli slot non dichiarati diventano casella tratteggiata (`.na`, stesso pattern delle combo non creabili del roster).
- **Sfondo della riga = completamento**: 0 pezzi neutro, <50% rosso, 50–99% giallo, 100% verde (token `--ok`/`--warn`/`--bad`).
- **`classStart`**: prima riga in cui una classe esiste — DK `t7`, Monk `t14`, DH `ohall`, Evoker `t29`. È l'esistenza della **classe**, non del suo primo tier set (il DH esiste dall'inizio di Legion anche se il primo tier è il T19). Le righe precedenti **non vengono mostrate affatto** in quel tab: l'Evoker parte da Vault of the Incarnates.
- **`armorType: true`** (BfA, Nathria/Sanctum, set LFR di WoD) = set per tipo di armatura. Serve a **una cosa sola**: esentare la riga dal taglio di `classStart`, perché quei set non sono vincolati alla classe e un Evoker può portare il maglia di Uldir benché in BfA non esistesse. Sul sito non si vede nulla.
- **`missing`** (blocco separato, come `collected`): `missing[classe][set][slot]` = elenco dei pezzi non ancora presi, es. `"Shoulder (Ragnaros, Firelands)"` (slot in inglese come il client, boss e raid quando il gioco li espone). Alimenta il tooltip del contatore. **Va aggiornato insieme a `collected`**: li genera lo stesso dump ([scripts/transmog-tier-dump.lua](scripts/transmog-tier-dump.lua)) in due campi, `collectedJson` e `missingJson`. Se ne copi uno solo, il tooltip elenca pezzi già presi.
- **`collected`**: chiave = slug classe → `{ raid: { slot: pezzi_posseduti } }`. Slot mancante = 0. Insieme a `missing` è **l'unica parte da aggiornare** man mano che si collezionano i pezzi; `tiers` cambia solo quando esce un raid nuovo.
- **Boss nel tooltip: copertura parziale (54%).** Per espansione: WoD/Legion/MoP 90-96%, WotLK/Cata ~60%, Midnight 43%, TWW 38%, DF 33%, SL 45%, TBC 27%, Classic 11%. Senza boss noto la voce resta il solo slot: **non inventarlo**.
- **Come si recupera il boss** (`MissingIn` nel dump): `GetAppearanceSourceDrops` sulla source **primaria** tace quasi sempre dal T28 in poi, perché lì dal boss cade il *token* e il pezzo nasce dalla conversione. Ma un'apparenza ha **più source** (le difficoltà, e dal T28 il Catalyst): interrogandole tutte finché una risponde si recuperano 2614 boss. Non toccare questo giro di fallback pensando sia ridondante.
- **Alcune voci indicano un luogo fuori dal raid del tier** (world boss, Baradin Hold, trash di Karazhan): è corretto, non un errore di parsing. Stessa apparenza, provenienza diversa — e siccome le apparenze sono condivise per `visualID`, collezionarla lì vale ugualmente.
- ⚠️ **Il formato `"Slot (Boss, Raid)"` non è separabile sulla virgola**: ne contengono sia i boss (`Baleroc, the Gatekeeper`) sia i raid (`Antorus, the Burning Throne`). `formatMissing` in [content.ts](src/lib/content.ts) prova ogni virgola da destra e tiene la prima la cui coda è un raid noto del tier.
- ⚠️ **API transmog verificate sul client 12.0.7** (annotate anche nel dump): `GetSetSources` non esiste più; il campo `appearanceID` di `GetSetPrimaryAppearances` contiene in realtà una **sourceID** (usala diretta, non "risolverla"); `invType` di `GetSourceInfo` è spostato di +1 rispetto alla numerazione classica (Testa = 2). Il dump verifica da sé che l'elenco combaci con la frazione e riporta le discrepanze in `mismatches`: se quel campo non è vuoto, **non incollare** il risultato.
- ⚠️ La collezione appearance è **account-wide** (Warband): i numeri valgono per l'account, non per singolo PG.
- **Casi da non "correggere" per sbaglio**: in BfA e in Nathria/Sanctum i set sono per tipo armatura (8 pezzi), non di classe; il T19 è **solo Nighthold**; in tutta WoD **non esiste tier in LFR** (al suo posto set per tipo armatura da 6 pezzi); Mogu'shan Vaults non dà token tier; il T35 copre da solo i tre raid di lancio di Midnight. **Esclusi di proposito, non rimetterli**: i dungeon set T0 e T0.5 (non sono raid); il set Zandalar di Zul'Gurub e il set Cenarion di Ruins of Ahn'Qiraj (sbloccati con la reputazione, e quello di AQ20 non ha nemmeno slot di armatura); i set per tipo di armatura di Zul'Aman e Sunwell Plateau (in gioco non esistono nemmeno come set con un nome).

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
- [src/pages/](src/pages/) — `index` (card), `addons`, `macros`, `professioni`, `roster`, `transmog`, `ui`, `404`. Le pagine **non hanno titoli/sottotitoli** (scelta voluta): partono col contenuto.

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
