// Controlla l'HTML che il build EMETTE, non i dati che lo alimentano.
//
// ⚠️ Perche' serve, e cosa NON fa. Il repo aveva due reti: `npm run validate` guarda i
// DATI (nomi che devono combaciare, file che devono esistere) e `astro check` guarda i
// TIPI. In mezzo non guardava niente nessuno: una pagina poteva uscire con un `src` verso
// un file inesistente, due elementi con lo stesso `id`, un'immagine senza `alt` o un
// bottone senza nome accessibile, e passare entrambi i gate. Questo script chiude quella
// fascia — e solo quella: NON prova il comportamento a runtime, quindi i due difetti di
// accessibilita' trovati il 2026-09-06 (la trappola del Tab che saltava il corpo
// scorrevole) gli sarebbero sfuggiti. Prende la classe «riferimento rotto in pagina».
//
// Gira su `dist/`, quindi vuole un `npm run build` prima. In CI sta nel workflow Verifica
// accanto a validate, non nel deploy: un rosso qui e' un lavoro da fare, non un sito da
// tenere offline.
//
// Uso: node scripts/audit-output.mjs [--dir dist]

import fs from 'node:fs';
import path from 'node:path';

const arg = (nome, def) => {
  const i = process.argv.indexOf(nome);
  return i > -1 && process.argv[i + 1] ? process.argv[i + 1] : def;
};
const dist = arg('--dir', 'dist');

if (!fs.existsSync(dist)) {
  console.error(`audit: manca ${dist}/ — lancia prima \`npm run build\`.`);
  process.exit(1);
}

// ── Eccezioni dichiarate ────────────────────────────────────────────────────
// ⚠️ Vanno tenute CORTE e motivate: un'eccezione senza motivo e' un controllo spento.
//
// Le tre immagini delle modali non hanno `width`/`height` perche' il `src` lo mette il JS
// all'apertura e la misura non e' nota a build-time. Due delle tre hanno gia' un rimedio
// suo: /mount dichiara 600x600 (i render hanno sempre quella tela) e /addons accende la
// fascia dopo il `decode()`. Resta scoperta quella di /ui, dove oggi l'archivio
// screenshot e' vuoto e non c'e' modo di provare il rimedio.
const IMG_SENZA_MISURA = new Set(['alb-img', 'lb-img']);

const problemi = [];
const segnala = (pagina, testo) => problemi.push(`${pagina}: ${testo}`);

const pagine = [];
(function scendi(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) scendi(p);
    else if (e.name.endsWith('.html')) pagine.push(p);
  }
})(dist);

const esiste = (u) => {
  const rel = decodeURIComponent(u).replace(/^\//, '').split('#')[0].split('?')[0];
  return fs.existsSync(path.join(dist, rel)) || fs.existsSync(path.join(dist, rel.replace(/\/$/, ''), 'index.html'));
};

for (const f of pagine) {
  const s = fs.readFileSync(f, 'utf8');
  const pagina = '/' + path.relative(dist, f).split(path.sep).join('/');

  // Id duplicati: rompono `getElementById`, le etichette e gli `aria-controls`.
  const ids = [...s.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]);
  const doppi = [...new Set(ids.filter((v, i) => ids.indexOf(v) !== i))];
  if (doppi.length) segnala(pagina, `id duplicati: ${doppi.join(', ')}`);

  const imgs = [...s.matchAll(/<img\b[^>]*>/g)].map((m) => m[0]);

  // `alt` mancante (diverso da `alt=""`, che e' la dichiarazione «decorativa» ed e' valida).
  const senzaAlt = imgs.filter((t) => !/\salt=/.test(t));
  if (senzaAlt.length) segnala(pagina, `${senzaAlt.length} img senza alt, es. ${senzaAlt[0].slice(0, 90)}`);

  // `width`/`height`: riservano il riquadro ed evitano il salto di layout al caricamento.
  const senzaMisura = imgs.filter((t) => {
    if (/\swidth=/.test(t) && /\sheight=/.test(t)) return false;
    const id = (t.match(/\sid="([^"]+)"/) || [])[1];
    return !(id && IMG_SENZA_MISURA.has(id));
  });
  if (senzaMisura.length) segnala(pagina, `${senzaMisura.length} img senza width/height, es. ${senzaMisura[0].slice(0, 90)}`);

  // Riferimenti interni a file che non esistono in dist.
  const rif = [...s.matchAll(/(?:src|href)="(\/[^"]*)"/g)].map((m) => m[1]).filter((u) => !u.startsWith('//'));
  const rotti = [...new Set(rif.filter((u) => u !== '/' && !esiste(u)))];
  if (rotti.length) segnala(pagina, `${rotti.length} riferimenti rotti: ${rotti.slice(0, 6).join(' ')}`);

  // Gerarchia dei titoli: un salto (h2 -> h4) rompe la navigazione per intestazioni.
  const livelli = [...s.matchAll(/<h([1-6])[\s>]/g)].map((m) => +m[1]);
  const salti = [];
  let prec = 0;
  for (const h of livelli) {
    if (prec && h > prec + 1) salti.push(`${prec}->${h}`);
    prec = h;
  }
  if (salti.length) segnala(pagina, `salti di heading: ${[...new Set(salti)].join(', ')}`);

  // Bottoni senza nome accessibile: nessun testo dentro e nessun aria-label/title.
  const muti = [...s.matchAll(/<button\b[^>]*>([\s\S]*?)<\/button>/g)]
    .filter(([tag, dentro]) => !/aria-label=/.test(tag) && !/title=/.test(tag) && !/aria-labelledby=/.test(tag) && !dentro.replace(/<[^>]*>/g, '').trim());
  if (muti.length) segnala(pagina, `${muti.length} button senza nome, es. ${muti[0][0].slice(0, 90)}`);
}

console.log(`  pagine controllate: ${pagine.length}`);
if (problemi.length) {
  console.error(`\naudit: ${problemi.length} problemi nell'HTML emesso.\n`);
  for (const p of problemi) console.error(`  - ${p}`);
  // Annotazione GitHub: il log di un run vuole l'autenticazione anche su un repo
  // pubblico, le annotazioni no. Stesso motivo per cui le usa validate-data.mjs.
  if (process.env.GITHUB_ACTIONS) console.log(`::error title=Audit output::${problemi.length} problemi nell'HTML emesso (vedi il log)`);
  process.exit(1);
}
console.log('\nHTML emesso coerente.');
