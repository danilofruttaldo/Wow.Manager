// Un JSON emesso a build-time, chiesto solo quando serve davvero e poi tenuto.
//
// Il repo ha tre posti che fanno la stessa cosa: i pezzi per classe di /transmog, i
// dettagli delle mount, e chiunque venga dopo. Erano tre copie della stessa manciata di
// righe — cache, richiesta in volo da non duplicare, errore di rete da non propagare — ed
// e' lo stesso motivo per cui la modale e' finita in `dialog.ts`: due copie divergono alla
// prima correzione di una sola.
//
// ⚠️ La cache sta a livello di MODULO, non di pagina: con ClientRouter il modulo sopravvive
// alla navigazione, quindi tornando su una pagina gia' vista non si riscarica nulla. E'
// anche il motivo per cui la chiave e' l'URL e non un identificatore di pagina.
//
// ⚠️ Un errore di rete NON rilancia: restituisce l'oggetto vuoto. Chi chiama disegna
// comunque quel che sa gia' dal DOM (in /mount la testata della modale, in /transmog la
// cella col suo contatore) e resta senza il di piu'. Una pagina che si rompe perche' un
// dettaglio non e' arrivato sarebbe peggio del dettaglio mancante.

const fatti = new Map<string, any>();
const in_volo = new Map<string, Promise<any>>();

/** Il JSON se e' gia' arrivato, altrimenti `null`. Serve a disegnare subito quel che c'e'
 *  senza aspettare: non fa partire nessuna richiesta. */
export function jsonSeCe<T = any>(url: string): T | null {
  return fatti.has(url) ? (fatti.get(url) as T) : null;
}

/** Chiede il JSON una volta sola. Chiamate concorrenti condividono la stessa richiesta. */
export function jsonLazy<T = any>(url: string): Promise<T> {
  if (fatti.has(url)) return Promise.resolve(fatti.get(url) as T);
  const gia = in_volo.get(url);
  if (gia) return gia;
  const p = fetch(url)
    .then((r) => (r.ok ? r.json() : {}))
    .catch(() => ({}))
    // ⚠️ Si assegna e si restituisce in due passi: `(x) => (v = x)` varrebbe il TIPO DELLA
    // VARIABILE, e la catena non combacerebbe piu' con quel che la funzione promette.
    .then((d: any) => {
      fatti.set(url, d);
      in_volo.delete(url);
      return d as T;
    });
  in_volo.set(url, p);
  return p;
}
