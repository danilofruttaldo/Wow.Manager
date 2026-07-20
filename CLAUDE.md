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
- **I nomi si controllano contro il client**, che li scrive nel campo `name` di ogni set dentro `sets` (il dump grezzo). Le uniche differenze ammesse sono **tre convenzioni volute**, tutto il resto è un errore: (a) **prefisso di difficoltà tolto** — il client dice `Heroes' / Valorous / Conqueror's / Sanctified Darkruned Plate`, il manifest scrive `Darkruned Plate`; (b) **fazioni unite** sul T9, dove l'asse sono Alleanza e Orda: `Thassarian's / Koltira's Battlegear` invece di due voci; (c) **abbreviazioni** sulle righe di Pandaria (`White Tiger` per `White Tiger Battlegear`). ⚠️ Il suffisso va lasciato **come lo scrive il client** e cambia per classe: `Plate` per DK e paladino, `Regalia` per prete e sciamano, `Vestments` per druido. Scrivere `Battlegear` per tutti è l'errore che c'era su 29 voci.
- ⚠️ **Niente tooltip decorativi: è una scelta esplicita, non una dimenticanza.** `note` e `warn` restano nel manifest come **memoria interna** (come `notes` altrove nel repo): non vengono mostrati. Se un'informazione serve al lettore, va scritta in chiaro nella pagina, non nascosta dietro un hover. Le **due** eccezioni, che sono contenuto vero e non decorazione: il popover dei pezzi sulle celle (sotto) e l'`<abbr title>` sulle sigle dei raid, che espande la sigla.
- **Popover dei pezzi** (cella con `has-tip`): elenca **tutti** i pezzi di quel blocco, in **ordine di slot d'equipaggiamento** (`SLOT_ORDER` in [content.ts](src/lib/content.ts), non l'alfabetico che arriva dal dump), **rosso = mancante, verde = sbloccato** — barretta di stato a sinistra e velo di sfondo, senza etichette di testo né glifi. ⚠️ Le voci le crea il JS a runtime, quindi **non** hanno l'attributo `[data-astro-cid-…]` con cui Astro scopa gli stili: le loro regole CSS **devono** stare in `:global()`, altrimenti non le colpiscono e il tooltip resta grigio (stesso motivo per cui `roster.astro` usa `:global`).
- **Una riga = un set da collezionare**, non un raid. I raid senza set proprio non hanno una riga: o spariscono, o finiscono nel `name` della riga del set a cui contribuiscono (es. il T19 si chiama «The Emerald Nightmare · Trial of Valor · The Nighthold» perché il set viene dal Nighthold ma gli altri due appartengono allo stesso ciclo). Ogni riga ha almeno una versione: le righe «vuote» non esistono più, e il codice che le reggeva è stato tolto.
- **Set di classe vs set per tipo di armatura**: da BfA in poi (più Zul'Aman, Sunwell e l'LFR di Hellfire Citadel) i set non sono di classe ma per tipo di armatura, quindi identici per tutte le classi che portano quel tipo. **Il sito non lo segnala**: scelta voluta, quello che conta è il completamento. Non reintrodurre badge o icone per distinguerli.
- **Come il dump li riconosce**: hanno il `classMask` con **più bit accesi** — 400 stoffa, 3592 cuoio, 4164 maglia, 35 piastre — e il dump li scrive **sotto ogni classe** che porta quel tipo (`ClassiIn` espande la maschera). Prima venivano scartati come `multiclasse` e quelle righe erano vuote per tutti. Vivono in `TIER_ARMOR`, mappa **separata** da `TIER` perché Hellfire Citadel sta in entrambe: le difficoltà normali danno il tier di classe (`t18`), il solo Raid Finder il set condiviso (`hfc-lfr`). L'elenco pezzi si calcola una volta e si riusa per tutte le classi del gruppo.
- ⚠️ **I totali di questi set variano col tipo di armatura** (Uldir: 9 pezzi in stoffa/cuoio/maglia, 8 in piastre), e il `pieces` della riga non può dirlo. Non serve: `total` viene dai dati veri di `collected`, e `pieces` resta solo il fallback per le celle senza dato.
- **Il set LFR di WoD è solo quello di Hellfire Citadel**, non ce n'è uno per Blackrock Foundry: la riga `brf-lfr` è stata rimossa. Verificato sul dump grezzo cercando *tutti* i set di WoD con maschera multi-classe, non solo quelli col nome del raid: escono Hellfire Citadel, i Timewalking (`Draenor Crafter's Work`), le fazioni di Draenor e il Trading Post. Blackrock Foundry compare col solo tier di classe in Normal/Heroic/Mythic.
- **Righe senza asse di difficoltà** (`ohall` Order Hall di Legion, `challenge` Challenge Mode di Pandaria): un set solo per classe, e il gioco **non gli dà `description`**. Lo slot non si può dedurre da lì, quindi è dichiarato in `SLOT_UNICO` nel dump — senza quello finiscono in `dropped` come «slot ignoto nil» e la riga resta vuota. Non sono set da boss (quartermaster l'uno, tempo d'oro nei dungeon l'altro): ci stanno perché la regola è tenere **tutti i set PvE** del journal, non solo quelli da raid.
- **Il T6 ha due colonne, non una**: `normal` = Black Temple, `heroic` = Sunwell Plateau, che è un recolour completo dello stesso set («Absolution Regalia» contro «Vestments of Absolution»). Il manifest dichiarava «Versione unica» e nascondeva la seconda a 9 classi. La mappa `SLOT` del dump aveva già la voce `["Sunwell"] = "heroic"` apposta: era la riga del manifest a non essere stata aggiornata.
- ⚠️ **Quello che conta è l'ASPETTO del set, non la difficoltà del raid.** Il journal elenca un set per aspetto distinto, e le colonne sono slot: dove l'etichetta di `versions` dice qualcosa di diverso dall'intestazione, la pagina la **scrive dentro la cella** (`.vlab`). Tace dove non aggiungerebbe nulla — «Raid Finder» è LFR detto con altre parole, «Versione unica» dice solo che la riga ha una colonna sola — quindi resta scritta sulle sole 6 righe che ne hanno bisogno: T6 (Black Temple/Sunwell), T7 e T8 (10/25 uomini), T9 (Alleanza/Orda), T10 (i tre item level) e T16. Due conseguenze da non "correggere": **SoO non ha un set Heroic** (Normal e Heroic sono lo stesso aspetto) e **ICC ha una colonna sotto l'intestazione Mythic** benché in WotLK il Mythic non esistesse.
- **`stack: true`**: le versioni diventano **sotto-righe** invece che colonne, ognuna larga tutta la tabella, col nome del set a sinistra in `rowspan`. Serve dove le colonne della difficoltà non vogliono dire niente, e sono due casi: (a) **nessun asse**, cioè una versione sola — T1, T2, T25, T3, T4, T5, `challenge`, `ohall` — dove altrimenti restavano tre tratteggi vuoti su quattro colonne; (b) **asse che non è la difficoltà**, cioè T6 (Black Temple contro Sunwell, due raid diversi) e T9, dove Alleanza e Orda sono due set distinti — nomi diversi, e su warrior, shaman e warlock anche conteggi e **totali** diversi (7 pezzi contro 8). Metterli sotto «Normal» e «Heroic» suggeriva che l'Orda fosse la versione più difficile. ⚠️ **Non impilare le righe dove il tratteggio dice il vero**: su T11 e T12 significa «il Mythic in Cataclysm non c'era», su T7/T8/T10 «l'LFR non esisteva» — e 10 contro 25 uomini *era* l'asse di difficoltà dell'epoca, quindi lì le colonne vanno rispettate. Idem `hfc-lfr`, che esiste solo in Raid Finder e i tre tratteggi lo dicono. ⚠️ Non confonderlo con `spans`: lì un aspetto **solo** copre più difficoltà (T16), qui sono **due aspetti** che di difficoltà non ne hanno nessuna.
- **`spans`**: quando un aspetto vale per **più difficoltà**, la cella si allarga invece di lasciare accanto un buco tratteggiato. Oggi solo il T16 (`"spans": { "normal": 2 }`), dove Normal e Heroic sono lo stesso set. ⚠️ Va **dichiarato**, mai dedotto dal buco fra le colonne: nel T9 mancano LFR e Mythic perché quelle difficoltà non esistevano, e lì il tratteggio è la risposta giusta.
- **Le 4 colonne sono SLOT di versione, non difficoltà letterali.** Prima di Cataclysm gli assi erano altri (10/25 uomini, fazione nel T9, Sanctified nel T10): ogni riga dichiara in `versions` l'**etichetta reale** di ogni slot che usa, mostrata nel tooltip della cella. Gli slot non dichiarati diventano casella tratteggiata (`.na`, stesso pattern delle combo non creabili del roster).
- ⚠️ **`versions` deve combaciare con le colonne che il dump produce davvero**, altrimenti si sbaglia in due modi insieme: la colonna dichiarata e senza dati mostra un contatore fantasma (`0/`+`pieces`) e quella con dati ma non dichiarata **sparisce**. Successo con il T16: dichiarava `heroic`, ma per Siege of Orgrimmar il client espone `Raid Finder / Normal / **Mythic**` — è il rimappaggio di WoD, dove le vecchie LFR/Flex/Normal/Heroic di Pandaria sono diventate LFR/Normal/Heroic/Mythic. Heart of Fear e Throne of Thunder hanno invece `Heroic` per davvero. Per controllare: confronta le chiavi di `versions` con quelle di `collected` per quella riga.
- ⚠️ **`pieces` è solo un fallback e non può essere giusto**: il totale vero **varia per classe e versione dentro lo stesso tier** (il T25 ha righe da 5, 6, 7 e 8 pezzi). `total` viene sempre da `collected` quando il dato c'è, e con le colonne dichiarate bene quel fallback non scatta mai. Non "correggere" quel numero pensando di sistemare qualcosa: se vedi un contatore che finisce con `/5` su un tier moderno, il problema è una colonna dichiarata male, non `pieces`.
- **Colore = completamento, su una rampa continua** rosso → giallo → verde (token `--bad`/`--warn`/`--ok`): 0 pezzi = **rosso pieno**, set completo = **verde pieno**, tutte le sfumature in mezzo. Niente più soglie discrete e niente stato "neutro": un set a zero deve saltare all'occhio quanto uno completo. Due livelli, stessa rampa: la **riga** si colora sull'avanzamento complessivo di tutti i blocchi di versione (`pct`), la **singola cella** sui pezzi sbloccati di quel blocco. Implementata in CSS puro: `--pct` (0–100, unitless) inline su `<tr>`/`<td class="cell">` + due `color-mix` in cascata con `clamp` in [transmog.astro](src/pages/transmog.astro). Per cambiare i colori tocca i token, non la rampa.
- **`classStart`**: prima riga in cui una classe esiste — DK `t7`, Monk `t14`, DH `ohall`, Evoker `t29`. È l'esistenza della **classe**, non del suo primo tier set (il DH esiste dall'inizio di Legion anche se il primo tier è il T19). Le righe precedenti **non vengono mostrate affatto** in quel tab: l'Evoker parte da Vault of the Incarnates.
- **`armorType: true`** (BfA, Nathria/Sanctum, Trial of Valor, LFR di Hellfire Citadel) = set per tipo di armatura. Serve a **una cosa sola**: esentare la riga dal taglio di `classStart`, perché quei set non sono vincolati alla classe e un Evoker può portare il maglia di Uldir benché in BfA non esistesse. Sul sito non si vede nulla.
- **`pieceList`** (blocco separato, come `collected`): `pieceList[classe][set][slot]` = **tutti** i pezzi di quella versione, come coppie `["Shoulder (Ragnaros, Firelands)", 1]` dove `1` = già collezionato (slot in inglese come il client, boss e raid quando il gioco li espone). Alimenta il tooltip del contatore, che li elenca **tutti**: verdi i presi, rossi i mancanti, mancanti per primi. ⚠️ Da non confondere con **`pieces` dentro ogni tier**, che è il solo *numero* di pezzi. **Va aggiornato insieme a `collected`**: li genera lo stesso dump ([scripts/transmog-tier-dump.lua](scripts/transmog-tier-dump.lua)) in due campi, `collectedJson` e `piecesJson`. Se ne copi uno solo, il tooltip contraddice la frazione della cella.
- **`collected`**: chiave = slug classe → `{ raid: { slot: pezzi_posseduti } }`. Slot mancante = 0. Insieme a `pieceList` è **l'unica parte da aggiornare** man mano che si collezionano i pezzi; `tiers` cambia solo quando esce un raid nuovo.
- Il dump si autoverifica: per ogni cella controlla che i pezzi elencati siano `total` e che quelli marcati presi siano `have`, e riporta le discrepanze in `mismatches`. Se quel campo non è vuoto, **non incollare**.
- ⚠️ **Ma `mismatches` vuoto NON basta.** Se il client non ha ancora caricato la collezione, ogni set esce con `have = 0` e il `total` giusto: il dump è **internamente coerente**, quindi `mismatches` ed `errors` restano vuoti e nulla lo distingue da un dump buono. Incollarlo azzera la collezione. È successo davvero: 4610 pezzi a 0 su tutte e 13 le classi. Per questo il dump ora conta i pezzi presi e, se sono zero mentre i pezzi esistono, riempie il campo **`sospetto`** e stampa un avviso rosso. **`sospetto` valorizzato → non incollare, rilancia `/wmtier`.** Controlla anche `presi`/`pezzi`: sono il totale su tutte le classi, e un crollo improvviso è il sintomo.
- **Boss nel tooltip: copertura parziale (80%),** cioè quante voci di `pieceList` hanno un boss fra parentesi (9186 su 11491). Per espansione: BfA/WoD 99%, SL 94%, MoP 87%, TWW 78%, Midnight 77%, DF 75%, Cata 72%, Legion 67%, WotLK 59%, Classic 52%, TBC 34%. Senza boss noto la voce resta il solo slot: **non inventarlo**.
- ⚠️ **La copertura non è una metrica da massimizzare.** WotLK è scesa dal 71% al 43% e Cata dal 70% al 65% *apposta*: quelle voci avevano un boss inventato dal fallback e ora sono vuote perché il pezzo si comprava dal vendor. Una copertura che risale su quei tier è il sintomo di una regressione, non un miglioramento.
- **Come si recupera il boss** (`MissingIn` nel dump): `GetAppearanceSourceDrops` sulla source **primaria** tace quasi sempre dal T28 in poi, perché lì dal boss cade il *token* e il pezzo nasce dalla conversione. Ma un'apparenza ha **più source** (le difficoltà, e dal T28 il Catalyst): interrogandole tutte finché una risponde si recuperano 2614 boss. Non toccare questo giro di fallback pensando sia ridondante.
- ⚠️ **Ma sui 5 slot da token dei tier T28–T35 quel fallback risponde SBAGLIATO, e per quelli vale `TOKEN_BOSS`** (tabella in [transmog-tier-dump.lua](scripts/transmog-tier-dump.lua)). Il giro per `visualID` trova quasi sempre *una* source, solo che è un'altra della stessa famiglia visuale: misurato su Manaforge Omega, delle 84 voci con un boss, 64 indicavano un altro boss dello stesso raid e 4 un world boss di un'altra zona. Perciò l'override va **prima** di `BossFor`, non come fallback dopo. La struttura vera è che un boss droppa il token di **uno slot per tutte le classi** (i quattro tipi Dreadful/Mystic/Venerated/Zenith cadono insieme): 5 righe per raid. Gli **altri** slot del set (Back, Feet, Waist, Wrist) non sono token, il gioco li sa: non estendere l'override a tutto il set.
- **T14–T16 (Pandaria): verificati, erano rumore.** Il sospetto che la dispersione fosse legittima — token per *gruppo di classi* — è stato **smentito**: aprendo le pagine dei singoli token, le tre varianti Conqueror/Protector/Vanquisher dello stesso slot nominano lo **stesso** boss. Il gruppo cambia quale *item* cade, non quale boss lo droppa. Stanno in `TOKEN_BOSS` come i moderni. T17–T21 erano già uniformi e corretti: non toccarli.
- **T9–T12 (WotLK/Cata): lì il boss spesso NON esiste,** e le voci vuote sono la risposta giusta. Il set si comprava: T9 e T10 interamente (Emblemi), T11 e T12 per petto/mani/gambe in normal (Valor Point). Stanno in `TOKEN_SENZA_FONTE`. ⚠️ Attenzione a **tre casi diversi che sembrano lo stesso**: (a) token dal boss convertito dal vendor — Pandaria, il boss **si tiene**; (b) acquisto puro con valuta, nessun boss; (c) token dal boss ma **generico**, valido per uno slot qualsiasi (`Trophy of the Crusade` da ogni boss del Trial, `Mark of Sanctification` da cinque boss di ICC): un boss c'è, ma non si può dire quale slot dia, quindi si sopprime lo stesso. Il (c) è quello che sembra un errore e non lo è.
- **I boss dei raid PvP da un boss solo ci sono** (Koralon e Toravon a Vault of Archavon, Argaloth e Occu'thar a Baradin Hold): droppano guanti e gambali di T9–T12, e per T9/T10 sono l'unica fonte da boss esistente, visto che il resto del set era da vendor. Sono boss «generici» — danno i pezzi di tutte le classi — ma **la regola è stare aderenti al journal**, e il journal li conosce. Nei dati toccano solo `Hands` e `Legs`: se compaiono su altri slot, quello è un errore vero.
- **Alcune voci indicano un luogo fuori dal raid del tier** (world boss, Baradin Hold, trash di Karazhan): è corretto, non un errore di parsing. Stessa apparenza, provenienza diversa — e siccome le apparenze sono condivise per `visualID`, collezionarla lì vale ugualmente.
- ⚠️ **Il formato `"Slot (Boss, Raid)"` non è separabile sulla virgola**: ne contengono sia i boss (`Baleroc, the Gatekeeper`) sia i raid (`Antorus, the Burning Throne`). `formatMissing` in [content.ts](src/lib/content.ts) prova ogni virgola da destra e tiene la prima la cui coda è un raid noto del tier.
- ⚠️ **API transmog verificate sul client 12.0.7** (annotate anche nel dump): `GetSetSources` non esiste più; il campo `appearanceID` di `GetSetPrimaryAppearances` contiene in realtà una **sourceID** (usala diretta, non "risolverla"); `invType` di `GetSourceInfo` è spostato di +1 rispetto alla numerazione classica (Testa = 2). Il dump verifica da sé che l'elenco combaci con la frazione e riporta le discrepanze in `mismatches`: se quel campo non è vuoto, **non incollare** il risultato.
- ⚠️ La collezione appearance è **account-wide** (Warband): i numeri valgono per l'account, non per singolo PG.
- **Casi da non "correggere" per sbaglio**: in BfA e in Nathria/Sanctum i set sono per tipo armatura, non di classe, e i pezzi variano col tipo (Uldir: 9 in stoffa/cuoio/maglia, 8 in piastre); il T19 è **solo Nighthold** (Trial of Valor ha una riga sua, `tov`, perché i suoi set sono per tipo di armatura); in tutta WoD **non esiste tier in LFR** (al suo posto un set per tipo di armatura, da 8 pezzi, e solo a Hellfire Citadel); Mogu'shan Vaults non dà token tier; il T35 copre da solo i tre raid di lancio di Midnight. **Esclusi di proposito, non rimetterli**: i dungeon set T0 e T0.5 (non sono raid); il set Zandalar di Zul'Gurub e il set Cenarion di Ruins of Ahn'Qiraj (sbloccati con la reputazione, e quello di AQ20 non ha nemmeno slot di armatura); i set per tipo di armatura di Zul'Aman e Sunwell Plateau (in gioco non esistono nemmeno come set con un nome).

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
