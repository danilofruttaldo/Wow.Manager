// Persistenza dei filtri di pagina, lato client, in localStorage.
//
// NON e' un cookie: il dato non lascia mai il browser, non viene inviato ad alcun
// server (il sito e' statico), non c'e' tracciamento ne' terze parti. Serve solo a
// ricordare l'ultima scelta di tab/chip/ricerca dell'utente cosi' che non debba
// rimetterla a ogni visita -- storage "funzionale/preferenza", esente dal banner.
//
// Best-effort: se localStorage e' pieno, disabilitato o non disponibile (SSR, modalita'
// privata restrittiva) le funzioni degradano senza rompere la pagina.

const PREFIX = 'wm.filters.';

/** Legge lo stato salvato di una pagina, fondendolo sul fallback (chiavi mancanti o
 *  JSON corrotto -> si usa il fallback). Il fallback definisce anche la forma attesa. */
export function loadFilters<T extends Record<string, unknown>>(page: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(PREFIX + page);
    if (!raw) return fallback;
    const parsed = JSON.parse(raw) as Partial<T>;
    return { ...fallback, ...parsed };
  } catch {
    return fallback;
  }
}

/** Salva lo stato dei filtri di una pagina. Silenzioso in caso di errore. */
export function saveFilters(page: string, state: Record<string, unknown>): void {
  try {
    localStorage.setItem(PREFIX + page, JSON.stringify(state));
  } catch {
    /* storage pieno/disabilitato: la persistenza e' un extra, non un requisito */
  }
}
