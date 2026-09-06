// Controller della MODALE DI DETTAGLIO, condiviso da /mount e /addons.
//
// Il guscio visivo (`.dlg*`) sta in global.css; qui c'e' la macchina che lo muove:
// apertura/chiusura, `inert` sulla pagina dietro, ritorno del focus, Esc, frecce ‹ ›
// circolari sulle card VISIBILI (cioe' rispettando il filtro attivo) e trappola del Tab.
// Le pagine forniscono solo `fill(card)`, che e' l'unica cosa davvero loro.
//
// ⚠️ Nasceva copiato riga per riga fra le due pagine: ~80 righe identiche salvo il
// prefisso degli id. E' lo stesso motivo per cui il CSS e' stato unificato — due copie
// divergono alla prima correzione di una sola, e su questo codice le correzioni sono
// state parecchie (il focus che scappava dal dialog, il focus strappato dalle frecce).
//
// ⚠️ I nodi si risolvono a OGNI chiamata e mai una volta sola: con ClientRouter la pagina
// viene sostituita ma questo modulo sopravvive, quindi un riferimento preso all'inizio
// sarebbe quello della pagina precedente — e la terrebbe anche in memoria.

export interface DialogOpts {
  /** id del contenitore `.dlg` */
  id: string;
  /** id del contenitore di pagina da rendere `inert` mentre la modale e' aperta */
  mainId: string;
  /** griglia che contiene le card: il click e' delegato qui, non una card per volta */
  grid: HTMLElement;
  /** selettore della card cliccabile dentro la griglia */
  cardSel: string;
  /** card attualmente visibili, nell'ordine della griglia: le frecce scorrono queste */
  visible: () => HTMLElement[];
  /** riempie la modale coi dati della card. Chiamata anche dalle frecce, senza riaprire */
  fill: (card: HTMLElement) => void;
}

export interface Dialog {
  /** apre sulla card indicata */
  open: (card: HTMLElement) => void;
  /** scorre di `dir` posizioni fra le card visibili, con giro circolare */
  step: (dir: number) => void;
}

// Stato che deve sopravvivere alla singola pagina, perche' il listener da tastiera sta su
// `document` e si aggancia una volta sola per sessione (vedi initKeys).
// ⚠️ `vivo` serve SOLO alle frecce, che hanno bisogno della closure della pagina. Aprire e
// chiudere non ci passano: vedi `chiudi`.
let lastFocus: HTMLElement | null = null;
let vivo: { id: string; step: (dir: number) => void } | null = null;

/** La modale aperta, letta dal DOM. Non c'e' registro che tenga: o ha la classe o no. */
const aperta = () => document.querySelector<HTMLElement>('.dlg.open');

// ⚠️ LA CHIUSURA NON PASSA DA `vivo`, ED E' IL PUNTO. Prima cominciava con `if (!vivo)
// return`, e quando quel registro si sporcava la modale si apriva ma non si chiudeva piu':
// ne' la ×, ne' il click sullo sfondo, ne' Esc — con la pagina dietro `inert` e lo scroll
// bloccato, cioe' bisognava ricaricare. E' successo davvero (vedi `releaseDialog`).
// La lezione non e' «quel registro andava tenuto meglio»: e' che la via d'USCITA non deve
// dipendere da bookkeeping. Un errore di stato, cosi', al massimo fa sbagliare una freccia.
function chiudi() {
  const lb = aperta();
  if (!lb) return;
  lb.classList.remove('open');
  document.body.style.overflow = '';
  // Griglia e filtri tornano navigabili: erano inerti dietro l'overlay. Quale sia il
  // contenitore da riabilitare sta scritto sulla modale stessa (`data-main`, lo mette
  // initDialog) e non in memoria — per la stessa ragione. NON si tocca l'elemento che
  // contiene la modale, solo il contenitore dei contenuti.
  const main = lb.dataset.main;
  if (main) document.getElementById(main)?.removeAttribute('inert');
  lastFocus?.focus();
  lastFocus = null;
}

// I listener su `document` si agganciano UNA volta sola: `astro:page-load` rispara a ogni
// navigazione e ne accumulerebbe una copia per visita.
function initKeys() {
  if ((window as any).__dlgKeys) return;
  (window as any).__dlgKeys = true;
  document.addEventListener('keydown', (e) => {
    // Anche qui si parte dal DOM: Esc e la trappola del Tab devono funzionare comunque,
    // pure se `vivo` fosse sbagliato. Solo le frecce ne hanno davvero bisogno, perche'
    // scorrono le card della pagina e quella closure sta li'.
    const lb = aperta();
    if (!lb) return;
    if (e.key === 'Escape') { chiudi(); return; }
    if (e.key === 'ArrowLeft') { e.preventDefault(); vivo?.step(-1); return; }
    if (e.key === 'ArrowRight') { e.preventDefault(); vivo?.step(1); return; }
    if (e.key !== 'Tab') return;
    // Trappola del focus: dentro un dialog il Tab non deve uscire sulla pagina.
    // ⚠️ `:not([disabled])` conta: con una sola card visibile le frecce sono disabilitate,
    // e prenderle comunque manderebbe il focus su un elemento non focalizzabile — cioe'
    // fuori dalla trappola, che e' esattamente quello che deve impedire.
    // ⚠️ `[tabindex="0"]` prende il corpo scorrevole (`.dlg-body`): senza, il giro si
    // chiudeva sui soli comandi della testata e il contenuto lungo non si scorreva da
    // tastiera. Stesso selettore della modale di /extra.
    const f = Array.from(lb.querySelectorAll<HTMLElement>('button:not([disabled]), a[href], [tabindex="0"]'));
    if (!f.length) return;
    const first = f[0], last = f[f.length - 1], cur = document.activeElement;
    // ⚠️ Il pannello e' il punto di partenza (ci va il focus all'apertura) e non e' un
    // controllo: in avanti il browser scende da solo sul primo bottone, ma all'indietro
    // uscirebbe dal dialog — la pagina dietro e' `inert`, quindi il focus finirebbe sulla
    // barra del browser. Si chiude il giro a mano.
    const panel = lb.querySelector('.dlg-panel');
    if (e.shiftKey && cur === panel) { e.preventDefault(); last.focus(); return; }
    if (e.shiftKey && (cur === first || !lb.contains(cur))) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && (cur === last || !lb.contains(cur))) { e.preventDefault(); first.focus(); }
  });
}

/**
 * Stacca il ponte verso la pagina precedente. Da chiamare a OGNI `astro:page-load`, per
 * PRIMA cosa e comunque — anche quando la pagina non ha una modale — passando l'id della
 * PROPRIA modale.
 *
 * Serve perche' `initDialog` non basta: le pagine escono prima («la mia griglia non c'e',
 * non e' la mia pagina») e quel ritorno anticipato scavalcherebbe il rilascio, lasciando
 * viva la closure su `visible`/`current`/`fill` — su /mount sono 1525 card staccate dal DOM.
 *
 * ⚠️ **L'`id` non e' un ornamento: senza, questa funzione ROMPE la modale.** `vivo` e' uno
 * solo per tutta la sessione, ma la chiamano tutte le pagine, e i listener di
 * `astro:page-load` scattano nell'ordine in cui i moduli sono stati caricati — non in
 * quello che serve. Dopo il giro /mount → /addons → /mount l'ordine e' [initMounts,
 * initAddons]: al ritorno su /mount, `initMounts` imposta `vivo` e subito dopo `initAddons`
 * — che su quella pagina non ha nulla da fare — lo azzerava. Da li' le frecce smettevano di
 * scorrere, e quando anche `chiudi` dipendeva da `vivo` la modale si apriva e non si
 * chiudeva piu'. Rilasciando solo la PROPRIA, una pagina non puo' piu' sabotare l'altra.
 */
export function releaseDialog(id: string) {
  if (vivo?.id === id) vivo = null;
}

/**
 * Aggancia la modale alla griglia. Da chiamare a ogni `astro:page-load`: rimpiazza il
 * riferimento alla pagina precedente, cosi' una closure viva non trattiene la griglia di
 * prima (su /mount sono 1525 card).
 */
export function initDialog(o: DialogOpts): Dialog | null {
  const lb = document.getElementById(o.id);
  releaseDialog(o.id);
  if (!lb) return null;
  // Quale contenitore rendere inerte (e poi riabilitare) sta sulla modale, non in memoria:
  // e' quel che permette a `chiudi` di lavorare senza sapere nulla della pagina.
  lb.dataset.main = o.mainId;

  // Card attualmente mostrata: e' il punto di partenza delle frecce.
  let current: HTMLElement | null = null;

  // ⚠️ Riempimento separato dall'apertura: le frecce cambiano il CONTENUTO senza riaprire
  // la modale e senza spostare il focus, che altrimenti verrebbe strappato al bottone
  // freccia a ogni passo.
  const step = (dir: number) => {
    const lista = o.visible();
    if (!current || lista.length < 2) return;
    const i = lista.indexOf(current);
    if (i < 0) return;
    current = lista[(i + dir + lista.length) % lista.length];
    o.fill(current);
    // `lastFocus` segue la card mostrata, cosi' alla chiusura il focus (e con esso lo
    // scorrimento) torna su quella che si stava guardando, non su quella d'ingresso.
    lastFocus = current;
  };

  const open = (card: HTMLElement) => {
    current = card;
    o.fill(card);
    lastFocus = card;
    lb.classList.add('open');
    document.body.style.overflow = 'hidden';
    document.getElementById(o.mainId)?.setAttribute('inert', '');
    (lb.querySelector('.dlg-panel') as HTMLElement | null)?.focus();
  };

  vivo = { id: o.id, step };

  // Un listener solo sulla griglia invece di uno per card: su /mount sono 1525, e ognuna
  // col suo handler peserebbe sulla memoria senza motivo.
  o.grid.addEventListener('click', (e) => {
    const card = (e.target as HTMLElement).closest(o.cardSel) as HTMLElement | null;
    if (card) open(card);
  });
  lb.querySelector('.dlg-close')?.addEventListener('click', chiudi);
  lb.addEventListener('click', (e) => { if (e.target === lb) chiudi(); });
  for (const [sel, dir] of [['.dlg-prev', -1], ['.dlg-next', 1]] as const) {
    lb.querySelector(sel)?.addEventListener('click', () => step(dir));
  }
  initKeys();
  return { open, step };
}

/**
 * Frecce e contatore `n / totale` in testata, comuni alle due modali: la posizione nel
 * sottoinsieme filtrato dice quanto resta da sfogliare. Con una card sola le frecce si
 * disabilitano — e il contatore sparisce, perche' «1 / 1» non informa.
 */
export function dialogPos(lb: HTMLElement, card: HTMLElement, visible: HTMLElement[]) {
  const pos = visible.indexOf(card);
  const el = lb.querySelector('.dlg-pos');
  if (el) el.textContent = pos >= 0 && visible.length > 1 ? `${pos + 1} / ${visible.length}` : '';
  const sola = visible.length < 2;
  for (const sel of ['.dlg-prev', '.dlg-next']) {
    (lb.querySelector(sel) as HTMLButtonElement | null)?.toggleAttribute('disabled', sola);
  }
}

/** Riga «etichetta: valore» della lista `.dlg-fields`. Valore vuoto = riga non emessa. */
export function dialogField(dl: HTMLElement, etichetta: string, valore: string | Node) {
  if (typeof valore === 'string' && !valore) return;
  const dt = document.createElement('dt');
  dt.textContent = etichetta;
  const dd = document.createElement('dd');
  dd.append(valore);
  dl.append(dt, dd);
}
