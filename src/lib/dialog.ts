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
let lastFocus: HTMLElement | null = null;
let vivo: { id: string; mainId: string; step: (dir: number) => void } | null = null;

function chiudi() {
  if (!vivo) return;
  const lb = document.getElementById(vivo.id);
  if (!lb) return;
  lb.classList.remove('open');
  document.body.style.overflow = '';
  // Griglia e filtri tornano navigabili: erano inerti dietro l'overlay. NON si tocca
  // l'elemento che contiene la modale stessa, solo il contenitore dei contenuti.
  document.getElementById(vivo.mainId)?.removeAttribute('inert');
  lastFocus?.focus();
  lastFocus = null;
}

// I listener su `document` si agganciano UNA volta sola: `astro:page-load` rispara a ogni
// navigazione e ne accumulerebbe una copia per visita.
function initKeys() {
  if ((window as any).__dlgKeys) return;
  (window as any).__dlgKeys = true;
  document.addEventListener('keydown', (e) => {
    if (!vivo) return;
    const lb = document.getElementById(vivo.id);
    if (!lb || !lb.classList.contains('open')) return;
    if (e.key === 'Escape') { chiudi(); return; }
    if (e.key === 'ArrowLeft') { e.preventDefault(); vivo.step(-1); return; }
    if (e.key === 'ArrowRight') { e.preventDefault(); vivo.step(1); return; }
    if (e.key !== 'Tab') return;
    // Trappola del focus: dentro un dialog il Tab non deve uscire sulla pagina.
    // ⚠️ `:not([disabled])` conta: con una sola card visibile le frecce sono disabilitate,
    // e prenderle comunque manderebbe il focus su un elemento non focalizzabile — cioe'
    // fuori dalla trappola, che e' esattamente quello che deve impedire.
    const f = Array.from(lb.querySelectorAll<HTMLElement>('button:not([disabled]), a[href]'));
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
 * PRIMA cosa e comunque — anche quando la pagina non ha una modale.
 *
 * ⚠️ Non basta farlo dentro `initDialog`: le pagine escono prima («la mia griglia non c'e',
 * non e' la mia pagina») e quel ritorno anticipato scavalcherebbe il rilascio. E' esattamente
 * il bug che c'era: `vivo` restava a puntare la modale di /mount, e con lei la closure su
 * `visible`/`current`/`fill` — cioe' 1525 card staccate dal DOM piu' il loro indice, vive
 * fino al primo reload vero. Prima del guscio condiviso il reset stava nella pagina, sopra
 * l'uscita anticipata; portandolo qui dentro ha smesso di essere raggiunto.
 */
export function releaseDialog() {
  vivo = null;
}

/**
 * Aggancia la modale alla griglia. Da chiamare a ogni `astro:page-load`: rimpiazza il
 * riferimento alla pagina precedente, cosi' una closure viva non trattiene la griglia di
 * prima (su /mount sono 1525 card).
 */
export function initDialog(o: DialogOpts): Dialog | null {
  const lb = document.getElementById(o.id);
  releaseDialog();
  if (!lb) return null;

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

  vivo = { id: o.id, mainId: o.mainId, step };

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
