// Retail o WoW Forever: quale dei due giochi la pagina sta mostrando.
//
// ⚠️ NON e' un secondo sito e non sono rotte `/forever/...`: le pagine che hanno contenuto
// diverso fra i due giochi (oggi /addons, /pg, /ui) li emettono ENTRAMBI nell'HTML, e la
// scelta si legge da un attributo su <html>, `data-gioco`. Le parti che valgono per un
// gioco solo portano `data-solo="retail|forever"` e le nasconde il CSS (global.css), cosi'
// non serve JS per mostrarle; le pagine con filtri propri (le card degli addon, gli
// screenshot) ascoltano invece l'evento `wm:gioco` e rifiltrano.
//
// Lo stato e' UNO per tutto il sito, non per pagina: chi guarda Forever su /addons e passa
// a /pg vuole vedere ancora Forever. Lo si legge, in ordine:
//   1. `?gioco=forever` nell'URL — il link diretto, che vince e si salva;
//   2. la scelta salvata nel browser (localStorage, come i filtri di pagina);
//   3. retail.
// ⚠️ Lo stesso ordine sta anche nello script inline di Base.astro, che imposta l'attributo
// PRIMA del primo disegno (altrimenti la pagina nascerebbe retail e scatterebbe su
// Forever un attimo dopo). Se cambi la lettura qui, cambiala anche la'.
import { loadFilters, saveFilters } from './filter-state';

export type Gioco = 'retail' | 'forever';
export const GIOCHI: { key: Gioco; label: string }[] = [
  { key: 'retail', label: 'Retail' },
  { key: 'forever', label: 'Forever' },
];
export const EVENTO_GIOCO = 'wm:gioco';

const valido = (v: unknown): v is Gioco => v === 'retail' || v === 'forever';

export function leggiGioco(): Gioco {
  try {
    const q = new URLSearchParams(location.search).get('gioco');
    if (valido(q)) return q;
  } catch { /* niente URL (SSR): si scende al salvato */ }
  const s = loadFilters('gioco', { g: 'retail' }).g;
  return valido(s) ? s : 'retail';
}

/** Imposta il gioco: attributo su <html>, scelta salvata, URL e bottoni allineati, evento. */
export function impostaGioco(g: Gioco): void {
  document.documentElement.dataset.gioco = g;
  saveFilters('gioco', { g });
  // L'URL segue la scelta, cosi' il link copiato dalla barra porta dove si e'. Retail e' il
  // default e non si scrive: `?gioco=retail` sarebbe solo rumore.
  try {
    const u = new URL(location.href);
    if (g === 'retail') u.searchParams.delete('gioco'); else u.searchParams.set('gioco', g);
    history.replaceState(history.state, '', u);
  } catch { /* history non disponibile: l'URL resta com'e' */ }
  // Il bottone acceso lo disegna il CSS da `html[data-gioco]`; qui resta lo stato per gli
  // screen reader, che dal colore non lo leggono.
  for (const b of document.querySelectorAll<HTMLButtonElement>('[data-gioco-btn]')) {
    b.setAttribute('aria-pressed', b.dataset.giocoBtn === g ? 'true' : 'false');
  }
  document.dispatchEvent(new CustomEvent(EVENTO_GIOCO, { detail: g }));
}

/** Aggancia l'interruttore della pagina (se c'e') e applica il gioco corrente. */
export function initGioco(): Gioco {
  const g = leggiGioco();
  for (const b of document.querySelectorAll<HTMLButtonElement>('[data-gioco-btn]')) {
    b.addEventListener('click', () => {
      const v = b.dataset.giocoBtn;
      if (valido(v)) impostaGioco(v);
    });
  }
  impostaGioco(g);
  return g;
}
