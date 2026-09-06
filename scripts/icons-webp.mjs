// Converte in webp le icone delle cavalcature in public/icons/mount/.
//
//   node scripts/icons-webp.mjs
//
// ⚠️ Perche' serve uno script e non una conversione fatta una volta e finita: le icone le
// scarica `mount-sync.ps1` dal CDN di Wowhead, che le pubblica in **JPEG**, e PowerShell
// il webp non lo sa scrivere — e' la stessa ragione per cui mount-images.mjs,
// addon-images.mjs e make-thumbs.mjs sono in JS. Quindi ogni sync che trova cavalcature
// nuove lascia dei `.jpg` dietro di se', e questo script li smaltisce dalla postazione con
// Node. Il conto lo tiene `node-pending.ps1` insieme agli altri lavori arretrati.
//
// ⚠️ Nel frattempo i `.jpg` NON sono rotti: `content.ts` risolve l'estensione provando
// prima `.webp` e poi `.jpg`, esattamente come `addonIcon` fa per gli avatar. Un'icona
// appena scaricata si vede subito; questo script la rimpicciolisce e basta.
//
// ⚠️ Il guadagno qui e' modesto e va saputo: sono 56x56, e a quella misura il webp rende
// il ~19% (misurato su tutte e 1215: 2274 -> 1843 KB). Non e' il caso degli avatar addon,
// dove erano PNG e si e' passati da 364 a 47 KB. Se un giorno si rimette in discussione,
// il numero da guardare e' quello, non una stima su un campione.

import { readdirSync, readFileSync, writeFileSync, unlinkSync, existsSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import sharp from 'sharp';

// La radice viene dal PERCORSO DELLO SCRIPT, non da process.cwd(): come negli altri .mjs,
// cosi' lanciarlo da una cartella qualsiasi non lavora sul posto sbagliato.
const root = dirname(dirname(fileURLToPath(import.meta.url)));
const dir = join(root, 'public', 'icons', 'mount');

if (!existsSync(dir)) {
  console.log('Nessuna cartella public/icons/mount: niente da fare.');
  process.exit(0);
}

const files = readdirSync(dir).filter((f) => /\.(jpg|jpeg|png)$/i.test(f)).sort();
if (!files.length) {
  console.log('Icone mount: tutte gia in webp, niente da convertire.');
  process.exit(0);
}

let prima = 0;
let dopo = 0;
let fatte = 0;
const tenute = [];

for (const f of files) {
  const src = join(dir, f);
  const dest = join(dir, f.replace(/\.(jpg|jpeg|png)$/i, '.webp'));
  const orig = readFileSync(src);
  const web = await sharp(orig).webp({ quality: 82 }).toBuffer();

  prima += orig.length;
  // ⚠️ Se il webp non e' piu' piccolo, l'originale resta: su icone gia' minuscole la
  // ricodifica puo' peggiorare, e un file piu' grande e' una perdita secca. Il resolver
  // accetta comunque entrambe le estensioni, quindi restare in jpg non rompe niente.
  if (web.length >= orig.length) {
    tenute.push(f);
    dopo += orig.length;
    continue;
  }
  writeFileSync(dest, web);
  unlinkSync(src);
  dopo += web.length;
  fatte++;
}

const kb = (n) => (n / 1024).toFixed(0) + ' KB';
console.log(`icone mount: ${fatte} convertite in webp su ${files.length}`);
console.log(`${kb(prima)} -> ${kb(dopo)} (${Math.round((1 - dopo / prima) * 100)}% in meno)`);
if (tenute.length) console.log(`lasciate in jpg perche' il webp era piu grande: ${tenute.length}`);
const restano = readdirSync(dir).filter((f) => /\.(jpg|jpeg|png)$/i.test(f)).length;
const totale = readdirSync(dir).filter((f) => /\.(jpg|jpeg|png|webp)$/i.test(f)).length;
console.log(`sul disco: ${totale - restano} webp, ${restano} jpg, ${kb(readdirSync(dir).reduce((s, f) => s + statSync(join(dir, f)).size, 0))} in tutto`);
