// Vincoli d'uso delle cavalcature: riempie i campi `class` e `race` di
// mounts/manifest.json.
// Lo lancia mount-sync.ps1 dopo aver riscritto il manifest, oppure a mano:
//
//   node scripts/mount-classes.mjs           risolve solo le mount senza campo `class`
//   node scripts/mount-classes.mjs --rifai   ricontrolla tutte (una richiesta per mount)
//
// ⚠️ IL CLIENT NON LO SA, ed e' gia' stato verificato due volte: il tooltip di gioco non
// ha righe "Requires <classe>" (misurato su tutte le 1532 mount: zero) e la provenienza
// cita una classe in 23 casi su 1532. Quindi la fonte e' Wowhead, con TRE segnali
// diversi -- nessuno dei quali da solo copre l'insieme:
//
//  1. `wowhead-tooltip-requirements` ("Requires Paladin") nel tooltip JSON. Copre le
//     cavalcature di classe classiche (Charger, Felsteed, Acherus Deathcharger...): 19.
//  2. La FRASE nella descrizione della spell -- "This mount is only available to
//     Hunters." -- che sta nello stesso tooltip JSON. Copre le 11 versioni Felscorned
//     di Legion Remix, e nient'altro: e' un modo di dire recente, le mount di Legion
//     non ce l'hanno.
//  3. La QUEST da cui viene la mount: le quest della campagna di classe hanno una
//     maschera `reqclass` nei dati di Wowhead. E' l'unico appiglio macchina per le 11
//     cavalcature di classe di Legion (Archmage's Prismatic Disc & co.), il cui vincolo
//     non e' sulla spell ma su come la si ottiene. Si legge dalla pagina della spell,
//     agganciando la quest PER NOME (quello che il gioco scrive in `srcText`): la
//     pagina cita anche le quest delle altre classi, quindi prendere "l'unica maschera
//     presente" darebbe Guerriero a una mount da mago.
//
// Resta fuori un solo gruppo, i RICOLORI di Legion, che non si prendono da una quest ma
// dal quartiermastro della propria sede di classe: per quelli si guarda dove il gioco
// stesso dice che si comprano (vedi SEDI piu' sotto). E' l'unica parte non macchina, ed
// e' ancorata a un dato che sta gia' nel manifest.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const file = join(root, 'mounts', 'manifest.json');
const rifai = process.argv.includes('--rifai');
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WowManagerMountSync/1.0';
const PARALLELE = 6;

const CLASSI = ['Warrior', 'Paladin', 'Hunter', 'Rogue', 'Priest', 'Death Knight', 'Shaman', 'Mage', 'Warlock', 'Monk', 'Druid', 'Demon Hunter', 'Evoker'];
// Ordine dei bit della maschera reqclass di Wowhead: 1 Warrior, 2 Paladin, 4 Hunter...
const MASCHERA = Object.fromEntries(CLASSI.map((c, i) => [1 << i, c]));

// Le SEDI DI CLASSE di Legion, dove si comprano i ricolori del proprio mount di classe.
// ⚠️ Si guarda la sede, non il nome della mount: per nome si sbaglia due volte subito --
// «Archmage's Great Raven» e' un mount del negozio aperto a tutti, e i «Grandmaster's
// Board» del Trading Post non c'entrano nulla con Ban-Lu del monaco.
// ⚠️ Dove la zona non basta si guarda l'NPC: il quartiermastro dei ladri sta sotto
// Dalaran, e il gioco scrive «Zone: Dalaran», che di classe non ha niente.
// Le quest che consegnano la cavalcatura di classe di Legion, con la classe letta dalla
// maschera `reqclass` di Wowhead (una volta, dalla pagina di una qualsiasi di quelle
// mount: le citano tutte). Serve per DUE sole mount -- Ban-Lu e Slayer's Felbroken
// Shrieker -- le cui pagine Wowhead non portano il blocco dati della loro quest, quindi
// la ricerca per nome li' non trova nulla.
// ⚠️ Non e' un dato inventato: si ricontrolla aprendo `wowhead.com/quest=<id>` e
// cercando `reqclass` (512 = Monk, 2048 = Demon Hunter, ...).
const QUEST_DI_CLASSE = {
  'The Trial of Rage': ['Warrior', 46207],
  'Stirring in the Shadows': ['Paladin', 45770],
  'Night of the Wilds': ['Hunter', 46337],
  'Hiding In Plain Sight': ['Rogue', 46178],
  'The Sunken Vault': ['Priest', 45789],
  'The Lost Glacier': ['Death Knight', 46813],
  'Gathering of the Storms': ['Shaman', 46792],
  'Dispersion of the Discs': ['Mage', 45354],
  'The Wrathsteed of Xoroth': ['Warlock', 46243],
  'The Trial of Ban-Lu': ['Monk', 46350],
  "You Can't Take the Sky from Me": ['Druid', 46319],
  'To Fel and Back': ['Demon Hunter', 46334],
};

const SEDI = [
  [/Sanctum of Light/i, 'Paladin'],
  [/Trueshot Lodge/i, 'Hunter'],
  [/Dreadscar Rift/i, 'Warlock'],
  [/Netherlight Temple/i, 'Priest'],
  [/Acherus/i, 'Death Knight'],
  [/Skyhold|Valarjar Strongbox/i, 'Warrior'],
  [/Dreamgrove/i, 'Druid'],
  [/Hall of the Guardian/i, 'Mage'],
  [/Peak of Serenity|Wandering Isle/i, 'Monk'],
  [/Heart of Azeroth|The Maelstrom/i, 'Shaman'],
  [/Fel Hammer/i, 'Demon Hunter'],
  [/Hall of Shadows|Zan Shivsproket/i, 'Rogue'],
  [/Hel'Nurath/i, 'Warlock'],
];

// ── RAZZA ────────────────────────────────────────────────────────────────────────
// ⚠️ Fino a ieri qui c'era scritto che la razza «non la sa nessuna delle due fonti».
// Era sbagliato: non la sa il TOOLTIP, ma i dati della spell su Wowhead hanno due
// campi -- `races` (elenco gia' risolto) e `reqrace` (maschera di bit) -- e li' i
// cavalli razziali dei paladini ci sono tutti.
//
// Si usa l'INTERSEZIONE dei due, non uno solo, perche' sbagliano in modi opposti:
//  · `races` e' largo -- per il Sunwalker Kodo dice [Tauren, Dracthyr], e il Dracthyr
//    non c'entra nulla con un cavallo razziale dei tauren;
//  · `reqrace` e' preciso ma ha bit che Wowhead stessa non risolve: sul Charger accende
//    anche un terzo bit che, letto come id di razza, darebbe «Fel Orc».
// L'intersezione tiene le razze su cui i due concordano, che sono quelle giuste.
const RAZZE = {
  1: 'Human', 2: 'Orc', 3: 'Dwarf', 4: 'Night Elf', 5: 'Undead', 6: 'Tauren', 7: 'Gnome',
  8: 'Troll', 9: 'Goblin', 10: 'Blood Elf', 11: 'Draenei', 22: 'Worgen', 24: 'Pandaren',
  25: 'Pandaren', 26: 'Pandaren', 27: 'Nightborne', 28: 'Highmountain Tauren', 29: 'Void Elf',
  30: 'Lightforged Draenei', 31: 'Zandalari Troll', 32: 'Kul Tiran', 34: 'Dark Iron Dwarf',
  35: 'Vulpera', 36: "Mag'har Orc", 37: 'Mechagnome', 52: 'Dracthyr', 70: 'Dracthyr',
  84: 'Earthen', 85: 'Earthen', 86: 'Haranir', 91: 'Haranir',
};

// Le due mount dove `races` non c'e' e la maschera non si sa leggere. Non sono
// indovinate: la maschera dice comunque QUANTE razze sono (il Ramolith ne accende due
// adiacenti, e l'Earthen e' due razze, una per fazione) e il paio Dawnforge/Darkforge
// e' il classico nano/nano scuro, con Dawnforge che su Wowhead risulta `races:[3]`.
const RAZZE_A_MANO = {
  270562: 'Dark Iron Dwarf',      // Darkforge Ram -- il gemello del Dawnforge Ram (nano)
  453785: 'Earthen',              // Earthen Ordinant's Ramolith
};

// Piu' di tre razze non e' un vincolo razziale ma l'elenco delle razze che possono
// avere quella CLASSE (l'Acherus Deathcharger ne elenca 23) o una fazione intera
// (Mechano-Hog e Chopper, 12-13): quello lo dicono gia' il bollino classe e il bollino
// fazione, e ripeterlo con dodici icone di razza non aiuterebbe nessuno.
const MAX_RAZZE = 3;

function razzeDaDati(o) {
  if (!o) return null;
  const arr = (o.match(/"races":\[([0-9,]*)\]/) || [, ''])[1];
  const mask = +(o.match(/"reqrace":(\d+)/) || [, 0])[1];
  if (!arr) return null;
  const ids = arr.split(',').map(Number).filter(Boolean);
  // bit = id - 1, valido fino a 32 (oltre la maschera non ci arriva).
  const daMask = ids.filter((id) => id <= 32 && (mask & (2 ** (id - 1))));
  const scelti = daMask.length ? daMask : ids;
  if (!scelti.length || scelti.length > MAX_RAZZE) return null;
  const nomi = [...new Set(scelti.map((id) => RAZZE[id]).filter(Boolean))];
  return nomi.length ? nomi.join(' / ') : null;
}

const singolare = (s) => {
  const n = s.trim().replace(/s$/, '');
  return CLASSI.includes(n) ? n : null;
};

async function testo(url) {
  const r = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!r.ok) return null;
  return r.text();
}

// (1) e (2): un tooltip solo, due segnali.
async function daTooltip(spell) {
  const t = await testo(`https://nether.wowhead.com/tooltip/spell/${spell}`);
  if (!t) return null;
  let j;
  try { j = JSON.parse(t); } catch { return null; }
  const html = (j.tooltip || '') + ' ' + (j.buff || '');
  const req = html.match(/wowhead-tooltip-requirements[^>]*>Requires ([^<]+)</);
  if (req) return singolare(req[1]);
  const frase = html.replace(/<[^>]*>/g, ' ').match(/only available to\s+([A-Za-z ']+?)[.,]/i);
  return frase ? singolare(frase[1]) : null;
}

// (3): la quest nominata dal gioco, cercata per nome nei dati della pagina.
async function daQuest(spell, nomeQuest) {
  const h = await testo(`https://www.wowhead.com/spell=${spell}`);
  if (!h) return null;
  const esc = nomeQuest.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const voci = h.match(new RegExp(`"name_enus":"${esc}"[^}]*`, 'g'));
  if (!voci) return null;
  const maschere = [...new Set(voci.map((v) => +(v.match(/"reqclass":(\d+)/) || [0, 0])[1]).filter(Boolean))];
  // Una maschera sola e con un bit solo: se la quest e' aperta a piu' classi non e' un
  // vincolo di classe, e se le maschere discordano il nome ha agganciato due quest.
  if (maschere.length !== 1) return null;
  return MASCHERA[maschere[0]] || null;
}

// L'elenco mount di Wowhead in una richiesta sola: porta `races`/`reqrace` per 1507
// spell su 1532. Le 25 che mancano sono proprio quelle che interessano -- i cavalli dei
// paladini sono ABILITA' di classe, non stanno nel database delle mount -- e si chiedono
// una per una piu' sotto.
async function elencoMount() {
  const h = await testo('https://www.wowhead.com/spells/mounts');
  const out = new Map();
  if (!h) return out;
  for (const o of h.match(/\{"cat":-5.*?\}(?=,\{|\])/g) || []) {
    const id = +(o.match(/"id":(\d+)/) || [])[1];
    if (id) out.set(id, o);
  }
  return out;
}

// Il blocco dati della spell dentro la sua pagina, per chi non e' nell'elenco.
async function datiDiPagina(spell) {
  const h = await testo(`https://www.wowhead.com/spell=${spell}`);
  if (!h) return null;
  return (h.match(new RegExp(`\\{[^{}]*"id":${spell}[^{}]*\\}`)) || [])[0] || null;
}

const raw = readFileSync(file, 'utf8');
const manifest = JSON.parse(raw);
// Argomenti numerici = ricontrolla solo quelle spell (utile dopo aver toccato le regole,
// per non rifare un giro da 1532 richieste).
const solo = process.argv.slice(2).filter((a) => /^\d+$/.test(a)).map(Number);
const daFare = manifest.mounts.filter((m) =>
  solo.length ? solo.includes(m.spell) : rifai || m.class === undefined || m.class === null);
console.log(`mount da controllare: ${daFare.length} / ${manifest.mounts.length}`);

const elenco = daFare.length ? await elencoMount() : new Map();
const esiti = new Map();
let i = 0;
const coda = [...daFare];
await Promise.all(Array.from({ length: PARALLELE }, async () => {
  for (let m = coda.shift(); m; m = coda.shift()) {
    let cls = null, razza = null;
    try {
      cls = await daTooltip(m.spell);
      if (!cls) {
        const q = (m.srcText || '').match(/(?:^|\n)Quest: (.+)/);
        if (q) cls = (await daQuest(m.spell, q[1].trim())) || (QUEST_DI_CLASSE[q[1].trim()] || [])[0] || null;
      }
      razza = razzeDaDati(elenco.get(m.spell) || (await datiDiPagina(m.spell)));
    } catch { /* una mount che va storta non ferma il giro */ }
    if (!cls) {
      const sede = SEDI.find(([re]) => re.test(m.srcText || ''));
      if (sede) cls = sede[1];
    }
    esiti.set(m.spell, { class: cls || '', race: razza || RAZZE_A_MANO[m.spell] || '' });
    if (++i % 100 === 0) console.log(`  ...${i}/${daFare.length}`);
  }
}));

// Riscrittura riga per riga: il manifest lo genera mount-sync.ps1 con una mount per
// riga, e rigenerarlo con JSON.stringify ne stravolgerebbe la forma (e il diff).
const righe = raw.split('\n');
const cambi = [];
// ⚠️ Il `\r?` in coda non e' pedanteria: il manifest lo scrive PowerShell, quindi ha
// fine riga CRLF. Senza, l'aggiunta di un campo nuovo non aggancia mai la graffa finale
// e fallisce in silenzio -- il campo `class`, che sulla riga c'era gia', veniva
// sostituito benissimo, e `race`, che era nuovo, non si scriveva affatto.
const scrivi = (riga, campo, valore) => (
  new RegExp(`"${campo}":(?:null|"[^"]*")`).test(riga)
    ? riga.replace(new RegExp(`"${campo}":(?:null|"[^"]*")`), `"${campo}":"${valore}"`)
    : riga.replace(/\}(,?)(\r?)$/, `,"${campo}":"${valore}"}$1$2`)
);
for (let n = 0; n < righe.length; n++) {
  const sp = righe[n].match(/"spell":(\d+)/);
  if (!sp || !esiti.has(+sp[1])) continue;
  const nuovo = esiti.get(+sp[1]);
  const nome = (righe[n].match(/"name":"([^"]*)"/) || [, '?'])[1];
  for (const campo of ['class', 'race']) {
    const vecchio = (righe[n].match(new RegExp(`"${campo}":"([^"]*)"`)) || [, null])[1];
    if (vecchio === nuovo[campo]) continue;
    righe[n] = scrivi(righe[n], campo, nuovo[campo]);
    // Il campo che non c'era e resta vuoto non e' un cambiamento da raccontare: e' il
    // segno "cercato, nessun vincolo", e sono il 96% delle mount.
    if (!vecchio && !nuovo[campo]) continue;
    cambi.push(`${campo.padEnd(5)} ${(vecchio || '-').padEnd(16)} -> ${(nuovo[campo] || '-').padEnd(22)} ${nome}`);
  }
}
const testoNuovo = righe.join('\n');
JSON.parse(testoNuovo);   // non si scrive un manifest rotto
writeFileSync(file, testoNuovo);

console.log(`vincoli: ${[...esiti.values()].filter((e) => e.class).length} di classe, ${[...esiti.values()].filter((e) => e.race).length} di razza, su ${esiti.size} controllate`);
if (cambi.length) {
  console.log(`cambiati ${cambi.length}:`);
  for (const c of cambi.sort()) console.log('  ' + c);
} else {
  console.log('niente da cambiare.');
}
