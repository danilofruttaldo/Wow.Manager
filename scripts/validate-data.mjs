// Verifica di COERENZA fra i dati del repo. Non guarda il sito: guarda se i file si
// tengono fra loro.
//
//   node scripts/validate-data.mjs        stampa il quadro, esce 1 se trova un errore
//   node scripts/validate-data.mjs --tutto  stampa anche i conteggi passati in silenzio
//
// ⚠️ PERCHE' ESISTE. Le guardie forti del repo (il campo `sospetto` dei dump, la soglia
// sulla perdita di icone, `mismatches`) vivono dentro gli script di sync, quindi coprono
// il solo dato macchina-generato. Tutto cio' che si tocca a mano — pg.md, char-specs.ts,
// builds.json, i manifest — non aveva nessuna rete: un riferimento rotto restava li'
// finche' non lo notava qualcuno. E' successo davvero, e per giorni: i 19 PG pianificati
// tolti da pg.md il 2026-08-04 hanno lasciato le loro spec in char-specs.ts senza che
// nulla lo segnalasse.
//
// ⚠️ E' un controllo di INTEGRITA' REFERENZIALE, non di merito: dice «questo nome non
// esiste da nessuna parte», mai «questa scelta e' sbagliata». Le scelte redazionali (quale
// spec dare a un PG, quale ordine consigliare in una professione) non sono affar suo.
//
// Niente dipendenze: solo `node:fs`. Gira in CI (.github/workflows/verifica.yml) e a mano.

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const verboso = process.argv.includes('--tutto');

const errori = [];
const avvisi = [];
const note = [];
const err = (dove, testo) => errori.push(`${dove}: ${testo}`);
const avviso = (dove, testo) => avvisi.push(`${dove}: ${testo}`);
const nota = (testo) => note.push(testo);

const leggi = (rel) => readFileSync(join(root, rel), 'utf8');
const json = (rel) => JSON.parse(leggi(rel));
const ci_sta = (rel) => existsSync(join(root, rel));
const elenco = (rel) => (ci_sta(rel) ? readdirSync(join(root, rel), { withFileTypes: true }).filter((d) => d.isFile()).map((d) => d.name) : []);

// Spec valide per classe (slug con trattino, come le chiavi di `collected` e il campo
// `class` delle macro). Il file icona invece toglie il trattino: `death-knight` ->
// `deathknight-blood.jpg`.
const SPEC = {
  'warrior': ['arms', 'fury', 'protection'],
  'paladin': ['holy', 'protection', 'retribution'],
  'hunter': ['beastmastery', 'marksmanship', 'survival'],
  'rogue': ['assassination', 'outlaw', 'subtlety'],
  'priest': ['discipline', 'holy', 'shadow'],
  'death-knight': ['blood', 'frost', 'unholy'],
  'shaman': ['elemental', 'enhancement', 'restoration'],
  'mage': ['arcane', 'fire', 'frost'],
  'warlock': ['affliction', 'demonology', 'destruction'],
  'monk': ['brewmaster', 'mistweaver', 'windwalker'],
  'druid': ['balance', 'feral', 'guardian', 'restoration'],
  'demon-hunter': ['havoc', 'vengeance', 'devourer'],
  'evoker': ['devastation', 'preservation', 'augmentation'],
};
const senzaTrattino = (s) => s.replace(/-/g, '');
// Abbreviazione di colonna in pg.md -> slug icona (senza trattino), come CLASS_ABBR.
const ABBR = {
  War: 'warrior', Pal: 'paladin', Hun: 'hunter', Rog: 'rogue', Pri: 'priest',
  DK: 'deathknight', Sha: 'shaman', Mag: 'mage', Loc: 'warlock', Mon: 'monk',
  Dru: 'druid', DH: 'demonhunter', Evo: 'evoker',
};
// slug icona -> slug con trattino, per rientrare in SPEC.
const CON_TRATTINO = { deathknight: 'death-knight', demonhunter: 'demon-hunter' };
const specDi = (slugIcona) => SPEC[CON_TRATTINO[slugIcona] ?? slugIcona];

// ── Professioni ────────────────────────────────────────────────────────────────
const prof = json('professions/manifest.json');
const trees = json('professions/trees.json');
const leveling = json('professions/leveling.json');
const builds = json('professions/builds.json');
const specsProf = json('professions/specs.json');
const chiaviProf = prof.professions.map((p) => p.key);

for (const [nome, file] of [['trees', trees], ['leveling', leveling], ['builds', builds], ['specs', specsProf]]) {
  const suo = Object.keys(file.professions ?? {});
  for (const k of chiaviProf) if (!suo.includes(k)) err('professioni', `${k} manca in ${nome}.json`);
  for (const k of suo) if (!chiaviProf.includes(k)) err('professioni', `${nome}.json ha ${k}, che non e' nel manifest`);
}
for (const k of chiaviProf) {
  if (!ci_sta(`public/icons/prof/${k}.jpg`)) err('professioni', `icona mancante public/icons/prof/${k}.jpg`);
}

// Nomi-nodo dell'albero del client, per professione (uniti su tutte le espansioni).
const nodiDi = {};
for (const [k, perEsp] of Object.entries(trees.professions ?? {})) {
  const set = new Set();
  const cammina = (n) => {
    if (n?.name != null) set.add(n.name);
    for (const c of n?.children ?? []) cammina(c);
  };
  for (const albero of Object.values(perEsp)) for (const s of albero.specs ?? []) cammina(s);
  nodiDi[k] = set;
}

// Uno step di builds.json puo' essere COMPOSTO: `spec` e `alt` sono allora etichette da
// leggere («Sculpted / Large Plate / Articulating Armor») e i nomi veri stanno in `nodes`.
// ⚠️ Quindi il controllo cambia con la forma: con `nodes` si verificano quelli e non
// l'etichetta; senza, `spec` e `alt` devono essere nomi di nodo veri.
const passiDi = (v) => (Array.isArray(v) ? v : [...(v.steps ?? []), ...(v.variants ?? []).flatMap((x) => x.steps ?? [])]);
for (const [k, perEsp] of Object.entries(builds.professions ?? {})) {
  const noti = nodiDi[k];
  if (!noti) { err('builds.json', `${k} non ha un albero in trees.json`); continue; }
  for (const [esp, v] of Object.entries(perEsp)) {
    for (const st of passiDi(v)) {
      const daControllare = st.nodes?.length ? st.nodes : [st.spec, st.alt].filter(Boolean);
      for (const n of daControllare) {
        if (!noti.has(n)) err('builds.json', `${k}/${esp}: «${n}» non e' un nodo di trees.json`);
      }
    }
  }
}

let nodiTot = 0, desc = 0;
for (const [k, noti] of Object.entries(nodiDi)) {
  nodiTot += noti.size;
  for (const n of Object.keys(specsProf.professions?.[k] ?? {})) {
    if (noti.has(n)) desc++;
    else err('specs.json', `${k}: descrizione per «${n}», che non e' un nodo di trees.json`);
  }
}
nota(`professioni: ${chiaviProf.length} · nodi ${nodiTot} · descrizioni ${desc}/${nodiTot}`);

// ── Macro ──────────────────────────────────────────────────────────────────────
const macros = json('macros/manifest.json').macros ?? {};
const usati = new Set();
for (const [k, m] of Object.entries(macros)) {
  if (!m.body_file && !m.body) { err('macro', `${k} non ha ne' body_file ne' body`); continue; }
  if (m.body_file) {
    usati.add(m.body_file);
    if (!ci_sta(`macros/${m.body_file}`)) err('macro', `${k}: manca macros/${m.body_file}`);
  }
  if (m.class && !SPEC[m.class]) { err('macro', `${k}: classe sconosciuta «${m.class}»`); continue; }
  if (m.spec && !m.class) err('macro', `${k}: spec «${m.spec}» senza classe`);
  if (m.spec && m.class && !SPEC[m.class].includes(m.spec)) err('macro', `${k}: «${m.spec}» non e' una spec di ${m.class}`);
  if (m.spec && m.class && !ci_sta(`public/icons/spec/${senzaTrattino(m.class)}-${m.spec}.jpg`)) {
    err('macro', `${k}: manca public/icons/spec/${senzaTrattino(m.class)}-${m.spec}.jpg`);
  }
  // Il repertorio si traccia per classe/spec, mai per personaggio.
  if (m.character) avviso('macro', `${k}: il campo character e' valorizzato (${m.character})`);
}
// .txt sul disco che nessuna macro dichiara.
const camminaTxt = (rel) => {
  for (const d of readdirSync(join(root, rel), { withFileTypes: true })) {
    if (d.isDirectory()) camminaTxt(`${rel}/${d.name}`);
    else if (d.name.endsWith('.txt')) {
      const relativo = `${rel}/${d.name}`.slice('macros/'.length);
      if (!usati.has(relativo)) err('macro', `macros/${relativo} non e' dichiarato da nessuna macro`);
    }
  }
};
camminaTxt('macros');
nota(`macro: ${Object.keys(macros).length}`);

// ── Addon ──────────────────────────────────────────────────────────────────────
const addons = json('addons/manifest.json').addons ?? {};
for (const [k, a] of Object.entries(addons)) {
  for (const campo of ['name', 'desc', 'version', 'interface', 'source', 'folders']) {
    if (a[campo] == null || (Array.isArray(a[campo]) && !a[campo].length)) err('addon', `${k}: campo ${campo} mancante o vuoto`);
  }
  if (!['png', 'jpg', 'jpeg'].some((e) => ci_sta(`public/icons/addon/${k}.${e}`))) {
    err('addon', `${k}: nessuna icona in public/icons/addon/`);
  }
}
// File senza padrone nelle due cartelle di immagini degli addon.
for (const [cartella, estensione] of [['public/icons/addon', null], ['public/addon-img', '.webp']]) {
  for (const f of elenco(cartella)) {
    if (estensione && !f.endsWith(estensione)) continue;
    const chiave = f.replace(/\.[^.]+$/, '');
    if (!(chiave in addons)) err('addon', `${cartella}/${f} non appartiene a nessun addon`);
  }
}
nota(`addon: ${Object.keys(addons).length}`);

// ── Extra (script / link / note) ───────────────────────────────────────────────
const extra = json('scripts/manifest.json').extra ?? {};
const dichiarati = new Set();
for (const [k, e] of Object.entries(extra)) {
  if (e.kind === 'script') {
    if (!e.body_file) { err('extra', `${k}: kind script senza body_file`); continue; }
    dichiarati.add(e.body_file);
    if (!ci_sta(`scripts/${e.body_file}`)) err('extra', `${k}: manca scripts/${e.body_file}`);
  }
  if (e.kind === 'link' && !e.url) err('extra', `${k}: kind link senza url`);
}
// Ogni script nella cartella deve avere la sua card: e' cosi' che compare su /extra.
const ESEGUIBILI = /\.(ps1|sh|lua|py|bat|txt|mjs)$/;
for (const f of elenco('scripts')) {
  if (ESEGUIBILI.test(f) && !dichiarati.has(f)) err('extra', `scripts/${f} non e' dichiarato in scripts/manifest.json`);
}
nota(`extra: ${Object.keys(extra).length} voci`);

// ── PG: pg.md vs char-specs.ts ─────────────────────────────────────────────────
// Tabelle markdown sotto «## Orda» e «## Alleanza», stessa lettura di content.ts.
const pgRaw = leggi('pg.md');
const tabella = (sezione) => {
  const righe = pgRaw.split('\n');
  let i = righe.findIndex((l) => new RegExp(`^##\\s+${sezione}`, 'i').test(l));
  if (i < 0) return null;
  const out = [];
  for (i++; i < righe.length; i++) {
    const l = righe[i];
    if (l.trim().startsWith('|')) {
      const celle = l.trim().split('|').slice(1, -1);
      if (celle.every((c) => /^\s*:?-{2,}:?\s*$/.test(c))) continue;
      out.push(celle);
    } else if (out.length) break;
  }
  return out.length ? out : null;
};
const pg = [];   // { nome, razza, slugIcona }
for (const sez of ['Orda', 'Alleanza']) {
  const t = tabella(sez);
  if (!t) { err('pg.md', `sezione «${sez}» non trovata`); continue; }
  const testata = t[0].map((c) => c.trim());
  for (const riga of t.slice(1)) {
    if (riga.length !== testata.length) {
      err('pg.md', `${sez}: riga «${riga[0]?.trim()}» ha ${riga.length} celle invece di ${testata.length}`);
      continue;
    }
    const razza = riga[0].replace(/·[A-Z]/g, '').trim();
    for (let j = 1; j < riga.length; j++) {
      const cella = riga[j].trim();
      if (!cella || cella === 'X') continue;
      const slug = ABBR[testata[j]];
      if (!slug) { err('pg.md', `${sez}: colonna «${testata[j]}» sconosciuta`); continue; }
      for (const pezzo of cella.split(/<br\s*\/?>/i)) {
        let nome = pezzo.trim().replace(/·[A-Z]$/, '').trim();
        if (!nome) continue;
        const pianificato = nome.startsWith('*');
        nome = nome.replace(/^[*_]/, '').trim();
        if (!pianificato) pg.push({ nome, razza, slug });
      }
    }
  }
}
// char-specs.ts: i due blocchi si leggono a regex — e' un file di dati con una forma sola.
const csRaw = leggi('src/lib/char-specs.ts');
const blocco = (nomeVar) => {
  const m = csRaw.match(new RegExp(`${nomeVar}:\\s*Record<string, string>\\s*=\\s*\\{([\\s\\S]*?)\\n\\};`));
  if (!m) { err('char-specs.ts', `blocco ${nomeVar} non riconosciuto (la forma del file e' cambiata?)`); return {}; }
  const out = {};
  for (const riga of m[1].split('\n')) {
    const t = riga.trim();
    if (!t || t.startsWith('//')) continue;
    const v = t.match(/^'?([^':]+?)'?\s*:\s*'([^']*)'/);
    if (v) out[v[1].toLowerCase()] = v[2];
  }
  return out;
};
const CHAR_SPEC = blocco('CHAR_SPEC');
const CHAR_SPEC_BY_RACE = blocco('CHAR_SPEC_BY_RACE');
if (!Object.keys(CHAR_SPEC).length) err('char-specs.ts', 'CHAR_SPEC risulta vuota: la lettura non ha agganciato nulla');

for (const p of pg) {
  const perRazza = CHAR_SPEC_BY_RACE[`${p.nome}|${p.razza}`.toLowerCase()];
  const valore = perRazza ?? CHAR_SPEC[p.nome.toLowerCase()];
  if (valore == null) { err('pg', `${p.nome} (${p.razza} ${p.slug}) non ha una spec in char-specs.ts`); continue; }
  const valide = specDi(p.slug) ?? [];
  for (const pezzo of String(valore).split(',')) {
    const s = pezzo.trim().replace(/\*$/, '');
    if (!s || s === '?') continue;
    if (!valide.includes(s)) { err('pg', `${p.nome}: «${s}» non e' una spec di ${p.slug}`); continue; }
    if (!ci_sta(`public/icons/spec/${p.slug}-${s}.jpg`)) err('pg', `manca public/icons/spec/${p.slug}-${s}.jpg (per ${p.nome})`);
  }
}
// Omonimi: senza una chiave `nome|razza` per ciascuno, il secondo eredita la spec del primo.
const perNome = {};
for (const p of pg) (perNome[p.nome.toLowerCase()] ??= []).push(p);
for (const [nome, gruppo] of Object.entries(perNome)) {
  if (gruppo.length < 2) continue;
  const scoperti = gruppo.filter((p) => !(`${p.nome}|${p.razza}`.toLowerCase() in CHAR_SPEC_BY_RACE));
  if (scoperti.length) err('pg', `omonimi «${nome}» senza chiave nome|razza in CHAR_SPEC_BY_RACE: ${scoperti.map((p) => p.razza).join(', ')}`);
}
// ⚠️ Le chiavi di CHAR_SPEC che non compaiono in pg.md NON sono un errore: sono i PG
// pianificati e mai creati, tenuti apposta per quando li si reintroduce con `*Nome`
// (vedi il blocco «PARCHEGGIATE» in char-specs.ts). Si contano e basta.
const nomiVivi = new Set(pg.map((p) => p.nome.toLowerCase()));
const parcheggiate = Object.keys(CHAR_SPEC).filter((k) => !nomiVivi.has(k));
nota(`pg: ${pg.length} in tabella · ${Object.keys(CHAR_SPEC).length} spec di cui ${parcheggiate.length} parcheggiate`);

// Tracker delle professioni per PG: i nomi devono mappare sul manifest, o l'icona non esce.
const chars = json('professions/characters.json').characters ?? {};
const nomiProf = new Set(prof.professions.map((p) => p.name.toLowerCase()));
for (const [chi, v] of Object.entries(chars)) {
  for (const p of v.professions ?? []) {
    if (p && !nomiProf.has(p.toLowerCase())) err('characters.json', `${chi}: professione «${p}» fuori dal manifest`);
  }
}

// ── Mount ──────────────────────────────────────────────────────────────────────
const mm = json('mounts/manifest.json');
const mounts = mm.mounts ?? [];
const presi = mounts.filter((m) => m.got === 1).length;
if (mounts.length !== mm._meta?.total) err('mount', `_meta.total = ${mm._meta?.total} ma le voci sono ${mounts.length}`);
if (presi !== mm._meta?.collected) err('mount', `_meta.collected = ${mm._meta?.collected} ma le prese sono ${presi}`);
const sorgenti = new Set(Object.keys(mm.sources ?? {}));
const iconeMount = new Set(elenco('public/icons/mount').filter((f) => f.endsWith('.jpg')).map((f) => f.slice(0, -4)));
const renderMount = new Set(elenco('public/mounts').filter((f) => f.endsWith('.webp')).map((f) => f.slice(0, -5)));
const idVisti = new Set(), iconeUsate = new Set(), renderUsati = new Set();
const displayDi = new Map();
let senzaSpell = 0;
for (const m of mounts) {
  if (idVisti.has(m.id)) err('mount', `id ${m.id} duplicato (e' la chiave di /mount/dettagli.json)`);
  idVisti.add(m.id);
  if (!m.spell) senzaSpell++;
  // I segnaposto di lavorazione di Blizzard non devono arrivare in pagina: il marchio puo'
  // stare in testa O IN CODA, e le quadre contano quanto le tonde.
  if (/[[(](PH|DND)[\])]/i.test(m.name)) err('mount', `segnaposto in elenco: ${m.name}`);
  if (!sorgenti.has(String(m.src)) && m.src !== 0) avviso('mount', `src ${m.src} non e' in sources (${m.name})`);
  if (m.icon) {
    iconeUsate.add(m.icon);
    if (!iconeMount.has(m.icon)) err('mount', `${m.name}: icona dichiarata «${m.icon}» ma il file non c'e'`);
  }
  if (m.display) { renderUsati.add(String(m.display)); displayDi.set(m.id, String(m.display)); }
}
// ⚠️ Il `display` del manifest e' quello dell'ULTIMO dump, e per qualche mount cambia da
// se': Ash'adar ha una forma solare e una lunare (dipende dall'ora in cui gira il dump),
// altre seguono la personalizzazione attiva. Il render dell'altra forma resterebbe senza
// padrone e verrebbe segnalato qui a ogni ribaltamento -- rosso in CI e un viaggio sulla
// postazione con Node per ricancellarlo e riscaricare l'altro, in circolo. display-noti.json
// e' l'elenco durevole dei display gia' visti per ogni mount: i loro file sono legittimi.
const displayNoti = ci_sta('mounts/display-noti.json') ? json('mounts/display-noti.json') : {};
let altriRender = 0;
for (const [id, visti] of Object.entries(displayNoti)) {
  if (!idVisti.has(Number(id))) { err('mount', `display-noti.json: la mount ${id} non e' nel manifest`); continue; }
  const ora = displayDi.get(Number(id));
  // Se il sync ha scritto il manifest ma non ha unito la storia, il file corrente
  // manca dall'elenco: e' il solo modo in cui questi due file possono divergere.
  if (ora && !visti.map(String).includes(ora)) err('mount', `display-noti.json: la mount ${id} ha display ${ora} nel manifest ma non nell'elenco`);
  for (const d of visti) { if (!renderUsati.has(String(d))) altriRender++; renderUsati.add(String(d)); }
}
for (const f of iconeMount) if (!iconeUsate.has(f)) err('mount', `public/icons/mount/${f}.jpg non appartiene a nessuna mount`);
for (const f of renderMount) if (!renderUsati.has(f)) err('mount', `public/mounts/${f}.webp non appartiene a nessuna mount`);
if (senzaSpell > mounts.length * 0.05) err('mount', `${senzaSpell} voci senza spellID: dump sospetto`);
nota(`mount: ${mounts.length} · prese ${presi} · icone ${iconeMount.size} · render ${renderMount.size} (di cui ${altriRender} di forme alternative)`);

// ── Transmog ───────────────────────────────────────────────────────────────────
const tm = json('transmog/manifest.json');
const colonne = (tm.columns ?? []).map((c) => c.key);
const espansioni = new Set((tm.expansions ?? []).map((e) => e.key));
const tiers = tm.tiers ?? [];
const chiaviTier = tiers.map((t) => t.key);
const classi = Object.keys(tm.collected ?? {});
for (const t of tiers) {
  if (!espansioni.has(t.exp)) err('transmog', `${t.key}: espansione «${t.exp}» inesistente`);
  for (const k of Object.keys(t.versions ?? {})) if (!colonne.includes(k)) err('transmog', `${t.key}: versions.${k} non e' una colonna`);
  for (const [da, a] of Object.entries(t.colonna ?? {})) {
    if (!colonne.includes(da)) err('transmog', `${t.key}: colonna.${da} non e' una colonna`);
    if (!colonne.includes(a)) err('transmog', `${t.key}: colonna.${da} punta a «${a}», che non e' una colonna`);
  }
  for (const k of Object.keys(t.spans ?? {})) if (!colonne.includes(k)) err('transmog', `${t.key}: spans.${k} non e' una colonna`);
  // ⚠️ Il testo di `fonte` non deve contenere virgole: formatMissing taglia li' per
  // separare boss e raid, e una virgola farebbe comparire una sigla inventata.
  const virgole = (dove, v) => { if (typeof v === 'string' && v.includes(',')) err('transmog', `${t.key}/${dove}: «${v}» contiene una virgola`); };
  if (typeof t.fonte === 'string') virgole('fonte', t.fonte);
  else for (const [slot, v] of Object.entries(t.fonte ?? {})) {
    if (typeof v === 'string') virgole(slot, v);
    else for (const [ver, testo] of Object.entries(v ?? {})) {
      virgole(`${slot}/${ver}`, testo);
      if (!colonne.includes(ver)) err('transmog', `${t.key}/fonte/${slot}: versione «${ver}» sconosciuta`);
    }
  }
}
for (const [slug, tier] of Object.entries(tm.classStart ?? {})) {
  if (!classi.includes(slug)) err('transmog', `classStart: classe «${slug}» sconosciuta`);
  if (!chiaviTier.includes(tier)) err('transmog', `classStart.${slug}: tier «${tier}» inesistente`);
}
// ⚠️ `versions` deve combaciare con le colonne che il dump produce davvero: una colonna
// dichiarata e senza dati mostra un contatore fantasma, una con dati e non dichiarata
// SPARISCE dalla pagina.
let celle = 0, pezziPresi = 0, pezziTot = 0;
for (const t of tiers) {
  const dichiarate = Object.keys(t.versions ?? {});
  const iTier = chiaviTier.indexOf(t.key);
  for (const slug of classi) {
    const iStart = chiaviTier.indexOf(tm.classStart?.[slug] ?? '');
    if (!t.armorType && iStart >= 0 && iTier < iStart) continue;   // riga non mostrata per questa classe
    const dati = tm.collected[slug]?.[t.key] ?? {};
    for (const k of dichiarate) {
      if (!(k in dati)) err('transmog', `${t.key}/${slug}: colonna «${k}» dichiarata in versions ma senza dati in collected`);
    }
    for (const k of Object.keys(dati)) {
      if (!dichiarate.includes(k)) err('transmog', `${t.key}/${slug}: colonna «${k}» ha dati ma non e' dichiarata in versions`);
    }
  }
}
// collected e pieceList li scrive lo stesso dump in due campi: se se ne copia uno solo, il
// popover contraddice la frazione della cella.
for (const [slug, perTier] of Object.entries(tm.collected ?? {})) {
  for (const [tk, perVer] of Object.entries(perTier)) {
    for (const [ver, v] of Object.entries(perVer)) {
      celle++;
      const got = Array.isArray(v) ? Number(v[0]) : Number(v);
      const tot = Array.isArray(v) ? Number(v[1]) : NaN;
      pezziPresi += got || 0;
      if (Number.isFinite(tot)) pezziTot += tot;
      const lista = tm.pieceList?.[slug]?.[tk]?.[ver];
      if (!lista) { err('transmog', `${slug}/${tk}/${ver}: c'e' in collected ma non in pieceList`); continue; }
      if (Number.isFinite(tot) && lista.length !== tot) err('transmog', `${slug}/${tk}/${ver}: collected dice ${tot} pezzi, pieceList ne elenca ${lista.length}`);
      const marcati = lista.filter((p) => Number(p[1]) === 1).length;
      if (marcati !== got) err('transmog', `${slug}/${tk}/${ver}: collected dice ${got} presi, pieceList ne marca ${marcati}`);
    }
  }
}
nota(`transmog: ${classi.length} classi · ${tiers.length} tier · ${celle} celle · ${pezziPresi}/${pezziTot} pezzi`);

// ── Screenshot UI ──────────────────────────────────────────────────────────────
const shots = elenco('public/screenshots').filter((f) => f.endsWith('.webp'));
const thumbs = new Set(elenco('public/screenshots/thumb').filter((f) => f.endsWith('.webp')));
for (const f of shots) {
  if (!thumbs.has(f)) err('ui', `public/screenshots/${f} non ha la miniatura in thumb/`);
  // Il nome del file E' il dato: /ui ne ricava classe e spec.
  const parti = f.replace(/\.webp$/, '').split('-');
  const valide = specDi(parti[0]);
  if (!valide) { err('ui', `${f}: «${parti[0]}» non e' una classe`); continue; }
  if (parti.length < 3) { err('ui', `${f}: il nome non e' <classe>-<spec>-<nome>.webp`); continue; }
  if (!valide.includes(parti[1])) err('ui', `${f}: «${parti[1]}» non e' una spec di ${parti[0]}`);
}
for (const f of thumbs) if (!shots.includes(f)) err('ui', `miniatura orfana: public/screenshots/thumb/${f}`);
nota(`ui: ${shots.length} screenshot`);

// ── Hardware (postazione di gioco) ────────────────────────────────────
// Manifest interamente redazionale: nessuno script lo rigenera, quindi non c'e' un dump
// da confrontare. Qui si controlla solo che si tenga insieme — che ogni impostazione
// finisca dentro un componente che esiste, e che ogni disegno esista davvero.
const hw = json('hardware/manifest.json');
const componenti = hw.components ?? [];
const opzioni = hw.settings ?? [];
// I disegni sono SVG in linea in UN file solo, quindi l'elenco dei nomi validi si legge
// da li': e' la stessa idea del confronto fra `spec` di builds.json e i nodi del client.
// ⚠️ Se questo grep smette di trovare nulla vuol dire che HwArt.astro ha cambiato forma
// (non piu' art === '...'), non che i disegni siano spariti: si segnala invece di
// dichiarare inesistenti tutti i nomi.
const ARTI = new Set([...leggi('src/components/HwArt.astro').matchAll(/art === '([a-z-]+)'/g)].map((m) => m[1]));
if (!ARTI.size) err('hardware', 'src/components/HwArt.astro: nessun disegno riconosciuto, il confronto dei nomi non funziona');
const artUsate = new Set();
const linkStrano = (u) => typeof u === 'string' && !/^https:\/\//.test(u);

const chiaviHw = new Set();
for (const c of componenti) {
  const dove = `componente ${c.key ?? '(senza key)'}`;
  for (const campo of ['key', 'label', 'name']) {
    if (!c[campo]) err('hardware', `${dove}: manca ${campo}`);
  }
  if (chiaviHw.has(c.key)) err('hardware', `${dove}: chiave doppia`);
  chiaviHw.add(c.key);
  if (c.art) { artUsate.add(c.art); if (ARTI.size && !ARTI.has(c.art)) err('hardware', `${dove}: disegno «${c.art}» non esiste in HwArt.astro`); }
  else avviso('hardware', `${dove}: nessun campo art, il blocco resta senza disegno`);
  if (linkStrano(c.url)) err('hardware', `${dove}: il campo url non e un indirizzo https`);
}

// ⚠️ `where` NON e' piu' un «posto» a se': e' la chiave del componente che ospita
// l'impostazione (il FreeSync nel monitor, l'XMP nel BIOS). Se non combacia, la pagina
// non mostra l'impostazione da nessuna parte e non se ne accorge nessuno.
const chiaviOpz = new Set();
for (const s of opzioni) {
  const dove = `impostazione ${s.key ?? '(senza key)'}`;
  for (const campo of ['key', 'name', 'where']) if (!s[campo]) err('hardware', `${dove}: manca ${campo}`);
  if (chiaviOpz.has(s.key)) err('hardware', `${dove}: chiave doppia`);
  chiaviOpz.add(s.key);
  if (s.where && !chiaviHw.has(s.where)) err('hardware', `${dove}: il componente «${s.where}» non esiste, l impostazione sparirebbe dalla pagina`);
  // ⚠️ La pagina elenca la configurazione APPLICATA, non le cose da fare: il campo
  // `state` (ok/todo/warn) e il contatore «N da sistemare» erano la deriva per cui il
  // setup era stato tolto una prima volta. Nessuno lo legge piu': se torna e' dato morto.
  if (linkStrano(s.url)) err('hardware', `${dove}: il campo url non e un indirizzo https`);
  if (s.state) avviso('hardware', `${dove}: il campo state non e letto da nessuno, la pagina non ha piu' stati`);
}
// Dati che nessuno legge piu': `places` era l'asse del pannello «Setup» separato, `groups`
// le intestazioni per tipo tolte in favore del mosaico. Se tornano, sono dati morti.
if (hw.places) avviso('hardware', 'manifest.places non e letto da nessuno: le impostazioni stanno dentro il componente (settings[].where)');
if (hw.groups || componenti.some((c) => c.group)) avviso('hardware', 'groups/group non sono letti da nessuno: i blocchi stanno in un mosaico unico, senza intestazioni');

for (const a of ARTI) if (!artUsate.has(a)) avviso('hardware', `disegno «${a}» in HwArt.astro non e usato da nessun componente`);
if (!ci_sta('public/icons/section/hardware.jpg')) err('hardware', "manca public/icons/section/hardware.jpg (icona della sezione in nav)");
nota(`hardware: ${componenti.length} blocchi, ${opzioni.length} impostazioni, ${ARTI.size} disegni`);

// ── Font e profili UI: i due domini che il SITO non mostra ─────────────────────
//
// ⚠️ Sono gli unici due domini del README che nessuna pagina legge, e fino al 2026-09-06
// non li guardava nemmeno questo validatore: se marcivano, non se ne accorgeva nessuno.
// Non sono pero' la stessa cosa, e la differenza conta:
//   fonts/       e' DATO VIVO — lo consuma scripts/apply-fonts.ps1, che dichiara di non
//                avere elenchi hardcoded e di seguire il manifest. Rompere `override.files`
//                rompe quello script, non una pagina.
//   ui-profiles/ e' un SEGNAPOSTO: `profiles` e' vuoto dal 27/05 e non lo legge nessuno.
//                Resta valido averlo dichiarato; qui si controlla solo che la forma regga
//                per il giorno in cui si riempie.
// ⚠️ Non si controlla che i percorsi Windows dentro `fonts` esistano: questo gira anche in
// CI su Linux, dove `C:\Windows\Fonts\...` non c'e' e un errore sarebbe rumore fisso.
for (const [dove, rel, chiave] of [['fonts', 'fonts/manifest.json', 'override'], ['ui-profiles', 'ui-profiles/manifest.json', 'profiles']]) {
  if (!ci_sta(rel)) { err(dove, `manca ${rel}, ma il README lo dichiara fonte di verita'`); continue; }
  let m;
  try { m = json(rel); } catch (e) { err(dove, `${rel} non e JSON valido: ${e.message}`); continue; }
  if (!m._meta?.schema_version) err(dove, `${rel}: manca _meta.schema_version`);
  if (m[chiave] === undefined) err(dove, `${rel}: manca il blocco «${chiave}»`);
}
const fontOv = json('fonts/manifest.json').override ?? {};
if (!fontOv.source_file) err('fonts', 'override.source_file non e dichiarato: apply-fonts.ps1 non saprebbe cosa copiare');
if (!Array.isArray(fontOv.files) || !fontOv.files.length) err('fonts', 'override.files e vuoto: apply-fonts.ps1 non avrebbe nessun nome da scrivere');
else {
  // I nomi-override sono quelli che il client carica: devono restare nomi di file .TTF,
  // non percorsi, perche' lo script li accoda alla cartella Fonts del gioco.
  for (const f of fontOv.files) {
    if (!/^[\w.\-]+\.ttf$/i.test(f)) err('fonts', `override.files: «${f}» non e un nome di file .ttf`);
  }
  const doppi = fontOv.files.filter((f, i) => fontOv.files.indexOf(f) !== i);
  if (doppi.length) err('fonts', `override.files ha nomi ripetuti: ${[...new Set(doppi)].join(', ')}`);
}
const nProfili = Object.keys(json('ui-profiles/manifest.json').profiles ?? {}).length;
nota(`fonts: ${(fontOv.files ?? []).length} nomi-override · ui-profiles: ${nProfili} profili`);

// ── Esito ──────────────────────────────────────────────────────────────────────
if (verboso || !errori.length) for (const t of note) console.log(`  ${t}`);
for (const t of avvisi) console.log(`AVVISO  ${t}`);
if (!errori.length) {
  console.log(`\nDati coerenti${avvisi.length ? ` (${avvisi.length} avvisi, non bloccanti)` : ''}.`);
  process.exit(0);
}
console.error(`\n${errori.length} incoerenze:`);
for (const t of errori) console.error(`  ERRORE  ${t}`);
process.exit(1);
