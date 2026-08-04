import type { APIRoute } from 'astro';
import { getMounts, mountBadges } from '../../lib/content';

// Un asset JSON con TUTTO quello che serve alla sola modale di /mount: provenienza per
// esteso, testo di colore, vincoli d'uso gia' risolti in icona+etichetta, render del
// modello e spellID per il link a Wowhead.
//
// ⚠️ Prima stava negli attributi `data-*` delle card, cioe' nell'HTML di chiunque aprisse
// la pagina: misurati **272 KB** su 1525 elementi (`data-desc` 175 KB, `data-full` 74 KB,
// `data-badges` ~29 KB) per un dato che si legge solo quando si apre una card — e la
// maggior parte delle visite non ne apre nessuna. Nella griglia restano i soli attributi
// che servono al FILTRO (`data-search`, `data-got`, `data-cats`, `data-src`) piu'
// `data-id`, che e' la chiave di questa mappa.
//
// E' lo stesso schema del popover di /transmog, che prende i pezzi da
// /transmog/<classe>.json invece di tenerli inline.
//
// Chiave = `id` (mountID del diario), verificato univoco sulle 1525 voci: la `spell` lo
// sarebbe pure, ma l'id e' il nome che il gioco da' alla riga ed e' gia' nel manifest.
// I campi assenti NON si emettono: su questo volume le chiavi vuote pesano davvero.

export const GET: APIRoute = () => {
  const out: Record<string, Record<string, unknown>> = {};
  for (const m of getMounts()) {
    const v: Record<string, unknown> = {};
    if (m.srcText) v.src = m.srcText;
    if (m.desc) v.desc = m.desc;
    if (m.img) v.img = m.img;
    if (m.spell) v.spell = m.spell;
    const b = mountBadges(m);
    if (b.length) v.badges = b;
    out[m.id] = v;
  }
  return new Response(JSON.stringify(out), {
    headers: { 'content-type': 'application/json' },
  });
};
