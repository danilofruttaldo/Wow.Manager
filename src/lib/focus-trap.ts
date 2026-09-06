// Trappola del focus per una finestra modale: dentro un dialog il Tab non deve uscire
// sulla pagina, che dietro l'overlay e' `inert` — se il focus scappa finisce sulla barra
// del browser e l'utente non ha piu' modo di tornare dentro se non ricaricando.
//
// ⚠️ Esisteva in TRE copie — `lib/dialog.ts` (/mount e /addons), `pages/extra.astro`,
// `pages/ui.astro` — con la riga dello Shift+Tab identica byte per byte in tutte e tre.
// Non era teoria: il 2026-09-06 la stessa correzione al selettore e' stata applicata a
// mano in due punti, e la terza copia e' rimasta indietro (era corretta solo per
// combinazione, nel lightbox di /ui ci sono solo bottoni). Da qui in poi si tocca qui.

/** Elementi che possono davvero ricevere il focus dentro la modale, in ordine di DOM.
 *
 *  ⚠️ Ogni pezzo del selettore viene da un difetto vero, non da prudenza generica:
 *  - `:not([disabled])` — con una sola card visibile le frecce di /mount sono disabilitate,
 *    e passare il focus a un elemento non focalizzabile lo fa uscire dalla trappola, cioe'
 *    esattamente cio' che deve impedire.
 *  - `a[href]` e non `a` — un'ancora nascosta va spenta togliendole ANCHE l'`href`
 *    (`.extlink[hidden]` e' `display: none`, quindi `focus()` non fa nulla). Con il solo
 *    `a` resterebbe in lista come ultimo elemento e il giro si spezzerebbe.
 *  - `[tabindex="0"]` — il corpo che scorre (`.dlg-body`, il `<pre>` di /extra) e'
 *    focalizzabile apposta: senza, da tastiera un contenuto lungo non si scorre.
 */
const SELETTORE = 'button:not([disabled]), a[href], [tabindex="0"]';

/**
 * Da chiamare sul `keydown` quando il tasto e' Tab e la modale e' aperta. Restituisce
 * `true` se ha gestito l'evento (e chiamato `preventDefault`), `false` se non c'era nulla
 * da fare e il browser puo' proseguire da se'.
 *
 * @param contenitore la radice della modale (l'overlay), dentro cui il focus resta
 * @param partenza    elemento che riceve il focus all'apertura ma NON e' un controllo
 *                    (il pannello di /mount e /addons, `tabindex="-1"`): in avanti il
 *                    browser scende da solo sul primo comando, all'indietro uscirebbe,
 *                    quindi il giro va chiuso a mano. Omesso dove non esiste.
 */
export function trappolaFocus(e: KeyboardEvent, contenitore: HTMLElement, partenza?: Element | null): boolean {
  const f = Array.from(contenitore.querySelectorAll<HTMLElement>(SELETTORE));
  if (!f.length) return false;
  const primo = f[0];
  const ultimo = f[f.length - 1];
  const corrente = document.activeElement;

  if (e.shiftKey && partenza && corrente === partenza) { e.preventDefault(); ultimo.focus(); return true; }
  if (e.shiftKey && (corrente === primo || !contenitore.contains(corrente))) { e.preventDefault(); ultimo.focus(); return true; }
  if (!e.shiftKey && (corrente === ultimo || !contenitore.contains(corrente))) { e.preventDefault(); primo.focus(); return true; }
  return false;
}
