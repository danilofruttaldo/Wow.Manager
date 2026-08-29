// Immagini del modello per la pagina /mount: una per creatureDisplayInfoID, in
// public/mounts/<display>.webp. Lo lancia mount-sync.ps1 dopo aver riscritto il
// manifest, oppure a mano:
//
//   node scripts/mount-images.mjs            scarica le mancanti e toglie le orfane
//   node scripts/mount-images.mjs --rifai    riscarica anche quelle che ci sono gia'
//
// ⚠️ E' in JS e non in PowerShell -- controcorrente rispetto al resto di scripts/ --
// per una ragione sola: il render arriva in JPEG e va convertito, e l'unico
// convertitore che il repo ha gia' e' `sharp` (dipendenza di Astro, dichiarata anche
// in package.json perche' qui la si usa direttamente). PowerShell non ha nulla per
// scrivere un webp.
//
// DUE FONTI, in ordine:
//  1. RENDER UFFICIALE Blizzard, 600x600 su fondo scuro:
//     https://render.worldofwarcraft.com/us/npcs/zoom/creature-display-<id>.jpg
//     Nessuna chiave, nessun token. Copre 1509 modelli su 1516.
//  2. Miniatura del model viewer di Wowhead, 300x300 su fondo trasparente:
//     https://wow.zamimg.com/modelviewer/live/webthumbs/npc/<id % 256>/<id>.webp
//     Era la fonte unica: meta' risoluzione e inquadratura piu' stretta. Resta come
//     ripiego per i 7 modelli che Blizzard non pubblica (403, non 404: e' una
//     risposta stabile, non un intoppo di rete -- riprovarli non serve).
//
// Il file su disco E' la cache: un'interruzione non fa perdere lavoro, si riprende da
// dove era rimasto. Per rifare un'immagine basta cancellarla.

import { readFileSync, existsSync, writeFileSync, unlinkSync, mkdirSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import sharp from 'sharp';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const dir = join(root, 'public', 'mounts');
const rifai = process.argv.includes('--rifai');
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WowManagerMountSync/1.0';
// Concorrenza bassa e deliberata: a 8 richieste in parallelo il CDN di Blizzard
// risponde 403 a qualcuna, e un 403 da rate limit e' indistinguibile da un 403 da
// "render non pubblicato".
const PARALLELE = 4;

const manifest = JSON.parse(readFileSync(join(root, 'mounts', 'manifest.json'), 'utf8'));
// ⚠️ Non basta il `display` del manifest, che e' quello dell'ultimo dump: qualche mount
// CAMBIA modello da se' (Ash'adar e' solare o lunare secondo l'ora, altre seguono la
// personalizzazione attiva). Tenendo conto del solo display corrente questo script
// cancellerebbe il render dell'altra forma come orfano e lo riscaricherebbe al
// ribaltamento successivo, all'infinito. mounts/display-noti.json elenca i display gia'
// visti per ogni mount: quelli valgono quanto il corrente, sia per scaricare sia per
// decidere cosa e' davvero orfano. Lo tiene aggiornato mount-sync.ps1.
const vivi = new Set(manifest.mounts.map((m) => String(m.id)));
const notiPath = join(root, 'mounts', 'display-noti.json');
const noti = existsSync(notiPath) ? JSON.parse(readFileSync(notiPath, 'utf8')) : {};
const displays = [...new Set([
  ...manifest.mounts.map((m) => m.display).filter(Boolean),
  // Una mount uscita dal manifest (esclusa, o sparita dal diario) porta via anche le
  // sue forme alternative: i suoi file tornano orfani veri e vanno cancellati.
  ...Object.entries(noti).filter(([id]) => vivi.has(String(id))).flatMap(([, d]) => d),
])];
mkdirSync(dir, { recursive: true });

async function scarica(url) {
  const r = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!r.ok) return null;
  return Buffer.from(await r.arrayBuffer());
}

// ⚠️ L'INQUADRATURA DEI RENDER NON E' UNIFORME, e senza correggerla il guadagno di
// risoluzione si perde: la camera di Blizzard non si adatta al modello, quindi un
// cavallo riempie il quadrato mentre l'Abyss Worm ci sta dentro alto 200 pixel su 600
// -- in pagina diventava un francobollo in mezzo a una fascia scura vuota, peggio
// della vecchia miniatura di Wowhead.
// Si normalizza: si ritaglia il fondo piatto (#181818, misurato: e' identico su tutta
// l'immagine), si porta il lato lungo del modello a 470 di 600 e lo si ricentra. Il
// tetto di 2.2x evita di gonfiare un modello davvero minuscolo fino a spappolarlo.
const BG = { r: 0x18, g: 0x18, b: 0x18 };
const LATO = 600;      // il quadrato dei render, e quello che si riscrive
const CONTENUTO = 470; // quanto ne deve occupare il modello: il resto e' margine

async function normalizza(jpg) {
  const t = await sharp(jpg).trim({ background: BG, threshold: 14 }).toBuffer({ resolveWithObject: true });
  const scala = Math.min(CONTENUTO / Math.max(t.info.width, t.info.height), 2.2);
  const w = Math.max(1, Math.round(t.info.width * scala));
  const h = Math.max(1, Math.round(t.info.height * scala));
  const sx = Math.floor((LATO - w) / 2);
  const sy = Math.floor((LATO - h) / 2);
  return sharp(t.data)
    .resize(w, h, { kernel: 'lanczos3' })
    .extend({ left: sx, right: LATO - w - sx, top: sy, bottom: LATO - h - sy, background: BG })
    .webp({ quality: 80, effort: 5 })
    .toBuffer();
}

// Il render e' un JPEG: si ricomprime in webp (q80) perche' a parita' di resa pesa un
// terzo -- 1509 render sono 40 MB in jpg e 13 in webp, cioe' meno dei 16 MB che
// occupavano le vecchie miniature a meta' risoluzione.
async function prendi(id) {
  const jpg = await scarica(`https://render.worldofwarcraft.com/us/npcs/zoom/creature-display-${id}.jpg`);
  if (jpg) return { buf: await normalizza(jpg), fonte: 'render' };
  const thumb = await scarica(`https://wow.zamimg.com/modelviewer/live/webthumbs/npc/${id % 256}/${id}.webp`);
  return thumb ? { buf: thumb, fonte: 'thumb' } : null;
}

// ⚠️ Su Windows la scrittura fallisce ogni tanto con un errno opaco (-4094 UNKNOWN):
// il file e' aperto da qualcun altro in quell'istante -- l'antivirus che lo scandisce
// appena creato, o il server di anteprima che lo sta servendo. Con 1500 file capita, e
// una volta ha buttato giu' l'intero giro a due terzi. Si riprova invece di morire.
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

const daFare = displays.filter((id) => rifai || !existsSync(join(dir, `${id}.webp`)));
if (daFare.length) console.log(`immagini da scaricare: ${daFare.length}`);

const conta = { render: 0, thumb: 0, niente: 0 };
let fatte = 0;
const coda = [...daFare];
await Promise.all(
  Array.from({ length: PARALLELE }, async () => {
    for (let id = coda.shift(); id !== undefined; id = coda.shift()) {
      // Un singolo modello che va storto -- rete, immagine corrotta, file occupato --
      // non deve buttare giu' il giro: si conta fra i «non disponibili» e si tira
      // avanti. (Con `--rifai` sono 1500 file: e' successo davvero, a due terzi.)
      let esito = null;
      try {
        esito = await prendi(id);
        if (esito) await scrivi(join(dir, `${id}.webp`), esito.buf);
      } catch {
        esito = null;
      }
      if (esito) {
        conta[esito.fonte]++;
      } else {
        conta.niente++;
      }
      if (++fatte % 100 === 0) console.log(`  ...${fatte}/${daFare.length}`);
    }
  }),
);
if (daFare.length) {
  console.log(`immagini: ${conta.render} render ufficiali, ${conta.thumb} miniature Wowhead, ${conta.niente} non disponibili`);
}

// Orfane: una mount esclusa (o sparita dal diario) lascerebbe il suo file nel repo.
const vive = new Set(displays.map(String));
let orfane = 0;
for (const f of readdirSync(dir)) {
  if (f.endsWith('.webp') && !vive.has(f.slice(0, -5))) {
    unlinkSync(join(dir, f));
    orfane++;
  }
}
if (orfane) console.log(`immagini orfane rimosse: ${orfane}`);
