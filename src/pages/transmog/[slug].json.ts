import type { APIRoute } from 'astro';
import { getTransmog } from '../../lib/content';

// Un asset JSON per classe con l'elenco pezzi di ogni cella, emesso a build-time.
// Prima questo stesso testo (534 KB, l'87% del manifest) stava inline nei `data-tip`
// di TUTTE e 13 le classi, anche i 12 pannelli nascosti: ~1.15 MB di HTML. Ora la
// pagina carica solo il JSON della classe che apri, e solo quello.
//
// Chiave = (tier, versione), la stessa con cui content.ts indicizza pieceList.
// Il testo e' gia' formattato da getTransmog (formatMissing/fonte, ordinato per
// slot): qui si riusa, non si riformatta. Prefisso + = preso, - = mancante, come
// leggeva il vecchio data-tip.

export function getStaticPaths() {
  return getTransmog().map((c) => ({ params: { slug: c.slug } }));
}

export const GET: APIRoute = ({ params }) => {
  const cls = getTransmog().find((c) => c.slug === params.slug);
  const out: Record<string, Record<string, string[]>> = {};
  if (cls) {
    for (const g of cls.groups) {
      for (const r of g.rows) {
        for (const cell of r.cells) {
          if (!cell.pieces?.length) continue;
          (out[r.key] ??= {})[cell.slot] = cell.pieces.map(
            (p) => (p.preso ? '+' : '-') + p.testo,
          );
        }
      }
    }
  }
  return new Response(JSON.stringify(out), {
    headers: { 'content-type': 'application/json' },
  });
};
