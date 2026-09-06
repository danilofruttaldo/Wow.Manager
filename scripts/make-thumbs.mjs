// Miniature degli screenshot UI: una per ogni file in public/screenshots/, dentro
// public/screenshots/thumb/ con lo STESSO nome.
//
//   node scripts/make-thumbs.mjs             rigenera solo le miniature piu' vecchie
//   node scripts/make-thumbs.mjs --forza     le rifa' tutte
//   node scripts/make-thumbs.mjs --larghezza 800
//
// Gli originali sono 2560x1440: vanno bene per il lightbox, che li mostra a schermo
// intero, ma la griglia della pagina /ui li rende a ~300px e scaricarli interi e' spreco
// puro. La miniatura e' larga 640 = il doppio della card, cosi' resta nitida sugli
// schermi a densita' doppia. Gli originali non si toccano mai.
//
// ⚠️ Era `make-thumbs.ps1` e usava System.Drawing di .NET, per non dipendere da Node su
// questa macchina. Non e' piu' possibile: dal 2026-08-04 gli screenshot sono **webp**
// (meta' del peso a parita' di resa, misurato: 15.7 MB -> 7.9 MB su 52 file) e
// System.Drawing il webp non lo legge ne' lo scrive. E' lo stesso motivo per cui
// mount-images.mjs e addon-images.mjs sono in JS: serve `sharp`, e PowerShell non ha
// nulla per scrivere un webp. La regola «gli script di manutenzione in PowerShell» vale
// ancora — questa ne e' l'eccezione gia' prevista, non uno strappo.
//
// ⚠️ Legge SOLO la radice di screenshots/: se leggesse anche thumb/ alla seconda
// esecuzione rimpicciolirebbe le proprie miniature.

import { readdirSync, existsSync, statSync, mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import sharp from 'sharp';

// ⚠️ La radice viene dal PERCORSO DELLO SCRIPT, non da `process.cwd()`: come in
// mount-images.mjs e addon-images.mjs. Con la cwd, lanciarlo da una cartella diversa dal
// repo non falliva — creava `./public/screenshots/thumb` li' dov'era, vuoto, e stampava
// «Nessuno screenshot da elaborare» come se fosse tutto a posto.
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const src = join(root, 'public', 'screenshots');
const dest = join(src, 'thumb');
const forza = process.argv.includes('--forza');
const iw = process.argv.indexOf('--larghezza');
const LARGHEZZA = iw >= 0 ? Number(process.argv[iw + 1]) : 640;
const QUALITA = 82;

// ⚠️ Prima si guarda, poi si crea. Il `mkdirSync` stava QUI SOPRA, prima del controllo, e
// con `recursive: true` creava anche `public/screenshots/` oltre a `thumb/`: lanciato ad
// archivio vuoto lasciava due cartelle vuote sul disco e stampava comunque «Nessuno
// screenshot da elaborare», cioe' senza dire che aveva scritto qualcosa. E' successo il
// 2026-09-06, appena svuotato l'archivio. Git non traccia le cartelle vuote, quindi non
// se ne accorgeva nessuno: restavano solo sulla macchina che aveva lanciato lo script.
// E' la stessa famiglia dell'inciampo gia' annotato piu' sopra (la cwd sbagliata che
// creava `./public/screenshots/thumb` altrove), quindi vale la stessa cura.
//
// ⚠️ Quel `mkdirSync` era pero' anche cio' che teneva in piedi `readdirSync(src)` quando
// la cartella non c'era: spostandolo dopo, la lettura va protetta o solleva ENOENT.
const files = existsSync(src)
  ? readdirSync(src).filter((f) => f.endsWith('.webp')).sort()
  : [];
if (!files.length) {
  console.log('Nessuno screenshot da elaborare.');
  process.exit(0);
}
mkdirSync(dest, { recursive: true });

let prima = 0, dopo = 0, fatte = 0, saltate = 0;
for (const f of files) {
  const orig = join(src, f);
  const out = join(dest, f);
  const st = statSync(orig);
  prima += st.size;
  // Si salta se la miniatura c'e' ed e' piu' recente dell'originale.
  if (!forza && existsSync(out) && statSync(out).mtimeMs >= st.mtimeMs) {
    dopo += statSync(out).size;
    saltate++;
    continue;
  }
  const buf = await sharp(orig)
    .resize(LARGHEZZA, null, { withoutEnlargement: true, kernel: 'lanczos3' })
    .webp({ quality: QUALITA, effort: 5 })
    .toBuffer();
  writeFileSync(out, buf);
  dopo += buf.length;
  fatte++;
  console.log(`  + ${f} (${(buf.length / 1024) | 0} KB)`);
}
const mb = (n) => (n / 1024 / 1024).toFixed(2) + ' MB';
console.log(`miniature: ${fatte} generate, ${saltate} gia' aggiornate`);
console.log(`originali ${mb(prima)} → miniature ${mb(dopo)} (-${(100 - (dopo / prima) * 100) | 0}%)`);
