// Immagine di anteprima per la modale di /addons: una per addon, in
// public/addon-img/<chiave>.webp. Si lancia a mano quando aggiungi o cambi un addon:
//
//   node scripts/addon-images.mjs            scarica le mancanti e toglie le orfane
//   node scripts/addon-images.mjs --rifai    riscarica anche quelle che ci sono gia'
//
// ⚠️ E' in JS e non in PowerShell per la stessa ragione di mount-images.mjs: l'immagine
// arriva in PNG/JPEG e va convertita in webp, e l'unico convertitore che il repo ha e'
// `sharp`. PowerShell non ha nulla per scrivere un webp.
//
// DUE FONTI, in ordine:
//
//  1. **`preview` nel manifest** — l'URL SCELTO A MANO, di norma uno screenshot preso
//     dalla galleria del progetto su CurseForge. E' la fonte buona: la galleria mostra
//     l'addon in gioco, che e' quello che serve vedere.
//     ⚠️ **La galleria NON si puo' leggere in automatico**, verificato il 2026-08-04 su
//     quattro strade: la pagina del progetto risponde 403 (Cloudflare); l'API ufficiale
//     `api.curseforge.com/v1/mods/<id>` — l'unica che espone `screenshots[]` — risponde
//     403 senza chiave; la vecchia API aperta `addons-ecs.forgesvc.net` ha il DNS morto,
//     e' stata dismessa; l'API interna del sito risponde 403 (e la richiesta il backend
//     lo raggiunge, visto che una rotta inesistente da' un 404 applicativo, quindi e'
//     autorizzazione e non firewall). Il proxy pubblico cfwidget risponde ma **non ha
//     alcun campo galleria**. Percio' l'URL lo si incolla nel manifest: e' un dato
//     redazionale come `desc`, e il manifest degli addon e' gia' tenuto a mano.
//
//  2. **Ripiego automatico**: il logo ufficiale del progetto, dal campo `thumbnail` di
//     **api.cfwidget.com** (proxy pubblico dei dati CurseForge, senza chiave). Serve
//     perche' un addon appena aggiunto non resti senza immagine finche' non gli si
//     sceglie uno screenshot. Non e' uno screenshot: identifica l'addon e basta.
//     `thumbnail` arriva come miniatura 256x256; togliendo dal percorso il segmento
//     `thumbnails/<w>/<h>` si ottiene l'ORIGINALE, fra 298x190 e 1200x1200.
//
// ⚠️ Il file su disco NON basta come cache, perche' la fonte puo' cambiare senza che il
// nome del file cambi: se cambi il `preview` nel manifest, il .webp vecchio resterebbe li'
// in silenzio. Per questo c'e' `addons/img-fonti.json`, che ricorda da quale URL viene
// ognuna: se non combacia, l'immagine si rifa' da sola.

import { readFileSync, existsSync, writeFileSync, unlinkSync, mkdirSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import sharp from 'sharp';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const dir = join(root, 'public', 'addon-img');
const rifai = process.argv.includes('--rifai');
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WowManagerAddonImages/1.0';
// Lato massimo del webp: la fascia della modale mostra al piu' 180px di altezza, quindi
// 640 e' gia' la riserva per gli schermi a densita' doppia. Le sorgenti arrivano a
// 1200x1200 e a 1.9 MB l'una: tenerle intere sarebbe peso puro.
const LATO = 640;

const manifest = JSON.parse(readFileSync(join(root, 'addons', 'manifest.json'), 'utf8'));
const addons = Object.entries(manifest.addons);
mkdirSync(dir, { recursive: true });

// Slug del progetto dall'url del manifest (.../wow/addons/<slug>).
const slugDi = (url) => (url || '').replace(/\/+$/, '').split('/').pop() || '';
// .../avatars/thumbnails/174/668/256/256/<id>.png  ->  .../avatars/174/668/<id>.png
const originale = (u) => u.replace(/\/avatars\/thumbnails\/(\d+)\/(\d+)\/\d+\/\d+\//, '/avatars/$1/$2/');

async function scarica(url) {
  const r = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!r.ok) return null;
  return Buffer.from(await r.arrayBuffer());
}

// ⚠️ Alla prima richiesta per un progetto mai visto, cfwidget risponde 202 e mette in
// coda l'indicizzazione: il JSON arriva solo al giro dopo. Senza questa attesa un addon
// nuovo resterebbe senza immagine e sembrerebbe che la fonte non ce l'abbia.
async function metadati(slug) {
  for (let i = 0; i < 6; i++) {
    const r = await fetch(`https://api.cfwidget.com/wow/addons/${slug}`, { headers: { 'User-Agent': UA } });
    if (r.status === 200) return r.json();
    if (r.status !== 202) return null;
    await new Promise((s) => setTimeout(s, 3000));
  }
  return null;
}

// `fit: inside` non ritaglia e non deforma: i loghi degli addon hanno proporzioni molto
// diverse fra loro (da 298x190 a 1200x1200) e ritagliarli al quadrato taglierebbe via
// meta' del nome scritto sul logo. Ci pensa la fascia in pagina a centrarli.
// `withoutEnlargement` per non gonfiare un originale piu' piccolo del lato massimo.
const converti = (buf) =>
  sharp(buf)
    .resize(LATO, LATO, { fit: 'inside', withoutEnlargement: true, kernel: 'lanczos3' })
    .webp({ quality: 82, effort: 5 })
    .toBuffer();

// ⚠️ Su Windows la scrittura fallisce ogni tanto con un errno opaco (-4094 UNKNOWN): il
// file e' aperto da qualcun altro in quell'istante — l'antivirus che lo scandisce appena
// creato, o il server di anteprima che lo sta servendo. E' una lezione gia' imparata da
// mount-images.mjs, dove una volta ha buttato giu' un giro intero a due terzi: si riprova
// invece di morire.
async function scrivi(file, buf, tentativi = 4) {
  for (let i = 1; ; i++) {
    try {
      writeFileSync(file, buf);
      return;
    } catch (e) {
      if (i >= tentativi) throw e;
      await new Promise((r) => setTimeout(r, 150 * i));
    }
  }
}

// `addons/img-fonti.json`: chiave -> URL da cui viene il .webp. Senza, un `preview`
// cambiato nel manifest non si accorgerebbe di nulla e resterebbe l'immagine vecchia, in
// silenzio.
// ⚠️ Sta accanto al manifest e NON dentro public/: e' un file di servizio, e tutto quello
// che sta in public/ viene servito dalla radice — finirebbe pubblicato e copiato in dist.
const fonteFile = join(root, 'addons', 'img-fonti.json');
const fonti = existsSync(fonteFile) ? JSON.parse(readFileSync(fonteFile, 'utf8')) : {};

// Sequenziale e non in parallelo: sono 16 addon, e cfwidget e' un servizio gratuito — non
// vale la pena martellarlo per risparmiare qualche secondo una volta ogni tanto.
let prese = 0, saltate = 0;
const senza = [];
for (const [key, a] of addons) {
  const file = join(dir, `${key}.webp`);
  // L'URL scelto a mano vince sempre; il logo e' solo il ripiego per chi non ce l'ha.
  const scelto = (a.preview || '').trim();
  let url = scelto;
  try {
    if (!url) {
      const meta = await metadati(slugDi(a.url));
      const thumb = meta?.thumbnail || '';
      // Sul logo si prova prima l'originale e si ripiega sulla miniatura.
      url = thumb ? originale(thumb) : '';
      if (!url) { senza.push(`${key} (nessun \`preview\` nel manifest e la fonte non ha logo)`); continue; }
    }
    // Si rifa' solo se manca il file, se l'URL e' cambiato, o con --rifai. Cosi' cambiare
    // un `preview` nel manifest basta: non c'e' niente da cancellare a mano.
    if (!rifai && existsSync(file) && fonti[key] === url) { saltate++; continue; }
    const buf = (await scarica(url)) ?? (scelto ? null : await scarica((await metadati(slugDi(a.url)))?.thumbnail || ''));
    if (!buf) { senza.push(`${key} (immagine non scaricabile: ${url})`); continue; }
    await scrivi(file, await converti(buf));
    fonti[key] = url;
    prese++;
    console.log(`  ${key}: ${scelto ? 'galleria' : 'logo (ripiego)'}`);
  } catch (e) {
    // Un addon che va storto non deve buttare giu' il giro: si conta fra i mancanti.
    senza.push(`${key} (${e.message})`);
  }
}
console.log(`immagini addon: ${prese} scaricate, ${saltate} gia' a posto, ${senza.length} senza`);
for (const t of senza) console.log(`  senza immagine: ${t}`);
const curate = addons.filter(([, a]) => (a.preview || '').trim()).length;
console.log(`fonte: ${curate} dalla galleria (campo \`preview\`), ${addons.length - curate} dal logo di ripiego`);

// Orfane: un addon rimosso dal manifest lascerebbe il suo file nel repo.
const vivi = new Set(addons.map(([key]) => key));
let orfane = 0;
for (const f of readdirSync(dir)) {
  if (f.endsWith('.webp') && !vivi.has(f.slice(0, -5))) {
    unlinkSync(join(dir, f));
    orfane++;
  }
}
for (const k of Object.keys(fonti)) if (!vivi.has(k)) delete fonti[k];
if (orfane) console.log(`immagini addon orfane rimosse: ${orfane}`);
await scrivi(fonteFile, JSON.stringify(fonti, null, 2) + '\n');
