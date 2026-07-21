// Accesso ai dati della repo Wow.Manager (manifest JSON + markdown).
// I file vivono fuori da src/: sono la fonte di verità, il sito li legge in sola lettura.
import { execSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { marked } from 'marked';

import { CHAR_SPEC, CHAR_SPEC_BY_RACE } from './char-specs';

import addonsManifest from '../../addons/manifest.json';
import macrosManifest from '../../macros/manifest.json';
import fontsManifest from '../../fonts/manifest.json';
import professionsManifest from '../../professions/manifest.json';
import extraManifest from '../../scripts/manifest.json';
import transmogManifest from '../../transmog/manifest.json';
import profTreesManifest from '../../professions/trees.json';
import profLevelingManifest from '../../professions/leveling.json';
import charactersManifest from '../../professions/characters.json';

marked.setOptions({ gfm: true, breaks: false });

// ── Tipi ──────────────────────────────────────────
export interface Addon {
  key: string;
  name: string;
  icon?: string;          // path icona addon (avatar CurseForge in public/icons/addon/)
  desc?: string;          // riga breve mostrata sul sito (cosa fa l'addon)
  version: string;
  interface: string;
  source: string;
  url?: string;
  installed?: string;
  folders: string[];
  notes?: string;         // memoria interna di manutenzione: NON mostrata sul sito
}

export interface Macro {
  key: string;
  name: string;
  desc?: string;          // riga breve mostrata sul sito (cosa fa il bottone)
  scope: string;
  class: string | null;
  spec: string | null;
  character: string | null;
  slot: string | null;
  icon: string | null;
  body?: string;          // corpo reale della macro, letto da body_file
  notes?: string;         // memoria interna di manutenzione: NON mostrata sul sito
}

export interface ProfStep {
  spec: string;   // specializzazione da prendere
  branch: string; // ramo da maxare dentro quella spec
}
export interface Profession {
  key: string;
  name: string;
  type: 'crafting' | 'gathering';
  first: ProfStep | null;  // 1ª spec + 1º ramo
  second: ProfStep | null; // 2ª spec + 2º ramo
  third: ProfStep | null;  // 3ª spec + 3º ramo
  notes?: string;
}

// Voce della sezione "Extra": contenitore libero (script / link / appunto).
export interface Extra {
  key: string;
  kind: 'script' | 'link' | 'note';
  name: string;
  desc?: string;          // riga breve mostrata sul sito
  lang?: string;          // solo script: linguaggio del corpo (es. 'bash')
  when?: string;          // solo script: quando eseguirlo
  warn?: string;          // solo script: avvertenza importante
  body?: string;          // solo script: corpo reale letto da body_file
  url?: string;           // solo link: destinazione
  notes?: string;         // memoria interna di manutenzione: NON mostrata sul sito
}

// ── Meta build + data aggiornamento (git) ─────────
export const wowBuild: string = (addonsManifest as any)._meta?.wow_build ?? '';
// Data dell'ultimo commit che ha toccato il file/cartella sorgente (YYYY-MM-DD).
export function sourceDate(relPath = '.'): string {
  try {
    return execSync(`git log -1 --format=%cs -- "${relPath}"`, { encoding: 'utf8' }).trim();
  } catch {
    return '';
  }
}

// ── Addon ─────────────────────────────────────────
export const addonsMeta = (addonsManifest as any)._meta;
// Icona addon (avatar CurseForge scaricato in public/icons/addon/<key>.<ext>).
// Estensioni miste (png/jpg/jpeg) → risolvo a build-time il file che esiste per quella chiave.
function addonIcon(key: string): string | undefined {
  for (const ext of ['png', 'jpg', 'jpeg']) {
    if (existsSync(`public/icons/addon/${key}.${ext}`)) return `/icons/addon/${key}.${ext}`;
  }
  return undefined;
}
export function getAddons(): Addon[] {
  const raw = (addonsManifest as any).addons ?? {};
  return Object.entries(raw)
    .map(([key, v]: [string, any]) => ({ key, folders: [], ...v, icon: v.icon ?? addonIcon(key) }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

// ── Macro ─────────────────────────────────────────
export const macrosMeta = (macrosManifest as any)._meta;
// Corpi reali delle macro: file .txt fuori da src/, letti a build-time (sola lettura).
// Chiave glob = path assoluto tipo '/.../macros/warrior/charge-intervene.txt';
// li mappo su `body_file` (es. 'warrior/charge-intervene.txt') per suffisso.
const macroBodies = import.meta.glob('../../macros/**/*.txt', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;
function macroBody(bodyFile?: string | null): string | undefined {
  if (!bodyFile) return undefined;
  const hit = Object.entries(macroBodies).find(([p]) => p.endsWith('/' + bodyFile));
  return hit ? hit[1].trim() : undefined;
}
export function getMacros(): Macro[] {
  const raw = (macrosManifest as any).macros ?? {};
  return Object.entries(raw)
    .map(([key, v]: [string, any]) => ({ key, ...v, body: v.body ?? macroBody(v.body_file) }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

// ── Fonts ─────────────────────────────────────────
export const fontsOverride = (fontsManifest as any).override;

// ── Professioni ───────────────────────────────────
export const professionsMeta = {
  expansion: (professionsManifest as any).expansion as string,
  note: (professionsManifest as any).note as string,
};
export function getProfessions(): Profession[] {
  return ((professionsManifest as any).professions ?? []) as Profession[];
}

// Alberi di specializzazione estratti dal CLIENT (scripts/prof-spec-dump.lua), non
// dalle guide web -- che sui nomi sbagliano e i rank massimi non li pubblicano.
// File separato da manifest.json apposta: e' dato macchina-generato, non redazionale.
// `cap` = rank massimo del nodo, cioe' quanti punti conoscenza vi entrano.
export interface ProfNode {
  name: string;
  cap: number;
  desc?: string;
  children?: ProfNode[];
}
export interface ProfTree {
  skillLine: number;
  specs: ProfNode[];
}
// Chiave doppia: professione -> espansione -> albero. Ogni professione ha un albero
// diverso per espansione (Midnight, TWW, Dragon Isles...); oggi il file porta solo
// Midnight, ma la struttura e la tendina in pagina sono gia' pronte per aggiungerne.
export function getProfExpansions(): string[] {
  return ((profTreesManifest as any).expansions ?? []) as string[];
}
export function getProfessionTrees(): Record<string, Record<string, ProfTree>> {
  return ((profTreesManifest as any).professions ?? {}) as Record<string, Record<string, ProfTree>>;
}

// Guida di LEVELING della skill (1 -> max): "da X a Y fai questo". A differenza degli
// alberi (dump del client), questo dato NON e' nel gioco in forma strutturata -- sono
// ricette/nodi per fascia di skill -- quindi e' web-sourced e verificato, e vive in un
// file suo (professions/leveling.json) per non essere sovrascritto dalla rigenerazione
// di trees.json. Stessa chiave doppia: professione -> espansione.
export interface LevelStep {
  from: number;
  to: number;
  action: string;   // es. "Mina Refulgent Copper" / "Craft 20x Handful of Bits"
  note?: string;
}
export interface LevelGuide {
  maxSkill?: number;
  steps: LevelStep[];
}
export function getProfessionLeveling(): Record<string, Record<string, LevelGuide>> {
  return ((profLevelingManifest as any).professions ?? {}) as Record<string, Record<string, LevelGuide>>;
}

// ── Extra (script / link / appunti) ───────────────
export const extraMeta = (extraManifest as any)._meta;
// Corpi degli script (file eseguibili fuori da src/, letti a build-time in sola lettura).
const extraBodies = import.meta.glob('../../scripts/**/*.{sh,txt,lua,ps1,bat,py}', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;
function extraBody(bodyFile?: string | null): string | undefined {
  if (!bodyFile) return undefined;
  const hit = Object.entries(extraBodies).find(([p]) => p.endsWith('/' + bodyFile));
  return hit ? hit[1].replace(/\s+$/, '') : undefined;
}
export function getExtra(): Extra[] {
  const raw = (extraManifest as any).extra ?? {};
  return Object.entries(raw)
    .map(([key, v]: [string, any]) => ({ key, ...v, body: v.body ?? extraBody(v.body_file) }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

// ── Transmog (tier set per classe) ────────────────
// Matrice tier × versione, una per classe. Le 4 colonne sono SLOT di versione, non
// difficoltà letterali: prima di Cataclysm gli assi erano altri (10/25 uomini, fazione,
// Sanctified), quindi ogni tier dichiara l'etichetta reale degli slot che usa e gli slot
// non dichiarati diventano celle "non applicabile" (stesso pattern delle combo del roster).
// Un pezzo del set nel tooltip: testo gia' formattato + se e' gia' stato preso.
export interface TmogPiece {
  testo: string;                                  // es. "Shoulder — Ragnaros (FL)"
  preso: boolean;
}
export interface TmogCell {
  slot: string;
  label: string;                                  // etichetta REALE della versione per quel tier
  got: number;
  total: number;
  state: 'na' | 'none' | 'partial' | 'full';      // na = versione inesistente per questo tier
  span: number;                                   // colonne occupate: >1 se un aspetto ne copre più d'una
  colonna: string;                                // colonna in cui mostrarla: puo' non essere la sua chiave
  setName?: string;                               // nome del set di QUESTA versione (righe a piu' aspetti)
  pieces: TmogPiece[];                            // TUTTI i pezzi, presi e non
}
export interface TmogRow {
  key: string;
  tier: string;
  name: string;
  note?: string;
  warn?: string;
  setName?: string;                               // nome del set per QUESTA classe (varia col tab)
  raids: [string, string][];                      // [sigla, nome completo] dei raid dove droppa
  got: number;
  total: number;
  pct: number;                                    // guida la rampa di colore rosso -> verde della riga
  cells: TmogCell[];
}
export interface TmogGroup {
  key: string;
  name: string;
  note?: string;
  rows: TmogRow[];
}
export interface TmogClass {
  slug: string;
  label: string;
  icon: string;
  groups: TmogGroup[];
  got: number;
  total: number;
}

export const transmogMeta = (transmogManifest as any)._meta;
export const transmogColumns = (transmogManifest as any).columns as { key: string; label: string }[];

// Ordine dei tier: serve a stabilire da quale tier una classe "nuova" esiste (classStart).
const tmogTierIndex: Record<string, number> = {};
((transmogManifest as any).tiers ?? []).forEach((t: any, i: number) => { tmogTierIndex[t.key] = i; });

// Nomi di raid confrontabili: il gioco e il manifest non li scrivono uguali
// ("Naxxramas" vs "Naxxramas (livello 80)", articolo iniziale incluso o meno).
const normRaid = (s: string) =>
  s.toLowerCase().replace(/\(.*?\)/g, '').replace(/^the /, '').replace(/[^a-z0-9]/g, '');

// Ordine degli slot come li mostra il personaggio in gioco (id di equipaggiamento),
// non l'alfabetico in cui arrivano dal dump: nel tooltip i pezzi devono scorrere
// dalla testa ai piedi come sul paper doll.
const SLOT_ORDER = ['Head', 'Shoulder', 'Back', 'Chest', 'Waist', 'Legs', 'Feet', 'Wrist', 'Hands'];
const slotRank = (testo: string) => {
  const i = SLOT_ORDER.indexOf(testo.replace(/ [—(].*/, ''));
  return i < 0 ? SLOT_ORDER.length : i;   // slot ignoto in coda, senza far saltare l'ordine
};

// Da "Head (Ragnaros, Firelands)" del dump alla forma mostrata nel tooltip,
// "Head — Ragnaros (FL)": la sigla viene dai `raids` del tier, non dal dump, che non
// conosce le abbreviazioni usate nel repo. Senza boss noto resta il solo slot.
//
// ⚠️ Dove tagliare NON e' deducibile dalla posizione della virgola: ne contengono sia
// i boss ("Baleroc, the Gatekeeper") sia i raid ("Antorus, the Burning Throne").
// Si prova quindi ogni virgola da destra e si tiene la prima la cui coda e' un raid
// noto del tier; solo se nessuna corrisponde si ripiega sull'ultima.
export function formatMissing(raw: string, raids: [string, string][]): string {
  const m = raw.match(/^(.*?) \((.*)\)$/);
  if (!m) return raw;
  const [, slot, detail] = m;

  const tagli: number[] = [];
  for (let i = detail.indexOf(', '); i >= 0; i = detail.indexOf(', ', i + 1)) tagli.push(i);
  if (!tagli.length) return `${slot} — ${detail}`;

  for (const i of tagli.reverse()) {
    const coda = detail.slice(i + 2);
    const hit = raids.find(([, full]) => normRaid(full) === normRaid(coda));
    if (hit) return `${slot} — ${detail.slice(0, i)} (${hit[0]})`;
  }
  const ultimo = tagli[0];   // reverse() l'ha messo in testa
  return `${slot} — ${detail.slice(0, ultimo)} (${detail.slice(ultimo + 2)})`;
}

export function getTransmog(): TmogClass[] {
  const m = transmogManifest as any;
  const cols = m.columns as { key: string; label: string }[];
  const tiers = m.tiers as any[];
  const classStart = (m.classStart ?? {}) as Record<string, string>;
  const collected = (m.collected ?? {}) as Record<string, any>;
  // Dal dump: TUTTI i pezzi di ogni versione come [testo, preso], con il boss che li
  // droppa dove il gioco lo sa.
  const pieceList = (m.pieceList ?? {}) as Record<string, any>;

  // Chip/pannelli in ordine alfabetico di classe, non nell'ordine del manifest.
  const slugs = Object.keys(collected).sort((a, b) => classLabel(a).localeCompare(classLabel(b), 'it'));

  return slugs.map((slug) => {
    const startIdx = tmogTierIndex[classStart[slug] ?? ''] ?? 0; // classe assente prima di questo tier
    let classGot = 0, classTotal = 0;   // per la percentuale nel chip della classe

    const groups: TmogGroup[] = (m.expansions as any[]).map((exp) => {
      // Set di classe precedenti alla classe: non li mostro affatto (il tab parte dal suo primo set).
      // I set per TIPO DI ARMATURA restano: non sono vincolati alla classe, quindi una classe
      // nata dopo puo' comunque collezionarli e indossarli (un Evoker porta il maglia di Uldir).
      const rows: TmogRow[] = tiers
        .filter((t) => t.exp === exp.key && (t.armorType || (tmogTierIndex[t.key] ?? 0) >= startIdx))
        .map((t) => {
        // Una versione puo' vivere in una colonna diversa dalla sua chiave: nel T10
        // sia "10 Heroic" sia "25 Heroic" sono heroic e vanno nella stessa casella,
        // nel T9 le due fazioni stanno entrambe a 10 Player (Normal). Le chiavi restano
        // distinte perche' sono set diversi, ma la colonna in cui si mostrano no.
        const colonnaDi = ((t as any).colonna ?? {}) as Record<string, string>;
        // `names` ha due forme. Piatta {classe: nome} quando la riga e' un set solo.
        // Annidata {versione: {classe: nome}} quando gli aspetti sono piu' d'uno e
        // hanno nomi DIVERSI: nel T6 il rogue ha "Slayer's Armor" a Black Temple e
        // "Slayer's Battlegear" a Sunwell, e un nome solo in testa alla riga ne
        // spaccerebbe uno per entrambi. Li' il titolo della riga resta il nome del
        // tier e ogni cella porta il proprio.
        // Provenienza dichiarata per i pezzi che un boss non ce l'hanno. Serve a
        // distinguere due cose che sul sito si vedono uguali — la cella vuota:
        // "so come si prende e non e' un boss" (quest, vendor, non piu' ottenibile)
        // contro "non lo so" (contenuto vecchio dove l'API tace, che resta vuoto).
        //
        // ⚠️ Il testo NON deve contenere virgole: `formatMissing` taglia li' per
        // separare boss e raid, e una virgola farebbe comparire una sigla inventata.
        // Tre forme: stringa per tutta la riga, {slot: testo}, {slot: {versione: testo}}.
        const fonteDi = (testo: string, versione: string): string | undefined => {
          const f = (t as any).fonte;
          if (!f || testo.includes(' (')) return undefined;   // il boss c'e' gia'
          if (typeof f === 'string') return f;
          const perSlot = f[testo];
          if (!perSlot) return undefined;
          return typeof perSlot === 'string' ? perSlot : perSlot[versione];
        };
        const nomi = ((t as any).names ?? {}) as Record<string, any>;
        const perVersione = Object.values(nomi).some((v) => v && typeof v === 'object');
        const cells: TmogCell[] = cols.map((c): TmogCell => {
          const label = t.versions?.[c.key];
          // Versione inesistente per questo set → cella tratteggiata.
          if (!label) return { slot: c.key, label: label ?? '', got: 0, total: 0, state: 'na', span: 1, colonna: c.key, pieces: [] };
          // Dal gioco: [pezzi posseduti, pezzi totali]. Il totale varia per classe e
          // per versione, quindi il `pieces` del tier resta solo come fallback.
          const cell = collected[slug]?.[t.key]?.[c.key];
          const got = Number((Array.isArray(cell) ? cell[0] : cell) ?? 0);
          const total = Number((Array.isArray(cell) ? cell[1] : undefined) ?? t.pieces);
          classGot += got;
          classTotal += total;
          return {
            slot: c.key, label, got, total, span: 1, colonna: colonnaDi[c.key] ?? c.key,
            setName: perVersione ? nomi[c.key]?.[slug] : undefined,
            state: got >= total ? 'full' : got > 0 ? 'partial' : 'none',
            pieces: ((pieceList[slug]?.[t.key]?.[c.key] ?? []) as [string, number][])
              .map(([testo, preso]) => {
                const fonte = fonteDi(testo, c.key);
                return {
                  testo: fonte ? `${testo} — ${fonte}` : formatMissing(testo, (t.raids ?? []) as [string, string][]),
                  preso: preso === 1,
                };
              })
              .sort((a, b) => slotRank(a.testo) - slotRank(b.testo)),
          };
        });
        // Un aspetto solo che vale per piu' difficolta': la cella si allarga invece di
        // lasciare accanto un buco tratteggiato. Il T16 e' il caso: Normal e Heroic
        // sono lo stesso set e il journal lo elenca una volta.
        //
        // ⚠️ Deve essere DICHIARATO in `spans`, non dedotto dal buco fra le colonne:
        // nel T9 mancano LFR e Mythic perche' quelle difficolta' non esistevano, e li'
        // il tratteggio e' la risposta giusta.
        const spans = ((t as any).spans ?? {}) as Record<string, number>;
        const coperte = new Set<string>();
        for (const [key, n] of Object.entries(spans)) {
          const i = cols.findIndex((c) => c.key === key);
          if (i < 0 || !(n > 1)) continue;
          cells[i].span = n;
          for (let k = 1; k < n && cols[i + k]; k++) coperte.add(cols[i + k].key);
        }
        const celle = cells.filter((c) => !coperte.has(c.slot));

        // Righe "impilate": le versioni non sono un progresso ordinato ma alternative
        // parallele, quindi non stanno nelle colonne della difficolta'. Il T9 e' il
        // caso: Alleanza e Orda sono due set distinti -- nomi diversi, e su warrior,
        // shaman e warlock anche conteggi e totali diversi -- e metterli sotto Normal
        // e Heroic suggerirebbe che l'Orda sia la versione piu' difficile.
        // Diventano una sotto-riga ciascuna, larga quanto tutta la tabella, col nome
        // del set condiviso via rowspan. Qui si tolgono le celle inesistenti: senza
        // colonne da rispettare, una casella tratteggiata non vorrebbe dire nulla.

        // Completamento della riga sulle sole versioni esistenti → tint di sfondo del tier.
        const rowGot = celle.reduce((s, c) => s + c.got, 0);
        const rowTotal = celle.reduce((s, c) => s + c.total, 0);
        const pct = rowTotal ? (rowGot / rowTotal) * 100 : 0;
        return {
          key: t.key, tier: t.tier, name: t.name,
          setName: perVersione ? undefined : t.names?.[slug], raids: (t.raids ?? []) as [string, string][],
          note: t.note, warn: t.warn,
          got: rowGot, total: rowTotal, pct, cells: celle,
        };
      });
      return { key: exp.key, name: exp.name, note: exp.note, rows };
    }).filter((g) => g.rows.length > 0);

    return {
      slug,
      label: classLabel(slug),
      icon: `/icons/class/${slug.replace(/-/g, '')}.jpg`,
      groups,
      got: classGot,
      total: classTotal,
    };
  });
}

// ── Markdown raw (fuori da src) ───────────────────
const rosterFile = import.meta.glob('/roster.md', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;

const CLASS_LABELS: Record<string, string> = {
  'death-knight': 'Death Knight', 'demon-hunter': 'Demon Hunter', 'druid': 'Druid',
  'evoker': 'Evoker', 'hunter': 'Hunter', 'mage': 'Mage', 'monk': 'Monk',
  'paladin': 'Paladin', 'priest': 'Priest', 'rogue': 'Rogue', 'shaman': 'Shaman',
  'warlock': 'Warlock', 'warrior': 'Warrior',
};
export function classLabel(slug: string): string {
  return CLASS_LABELS[slug] ?? slug;
}
export function titleCase(s: string): string {
  return s.replace(/-/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

export function renderMarkdown(md: string): string {
  const html = marked.parse(md) as string;
  // Avvolgi ogni tabella in un contenitore che scrolla in orizzontale,
  // così le tabelle larghe (roster 14 colonne) non spingono la pagina fuori bordo.
  return html.replace(/<table>/g, '<div class="table-scroll"><table>').replace(/<\/table>/g, '</table></div>');
}

// Abbreviazione classe (header roster) -> [slug icona, nome esteso]
const CLASS_ABBR: Record<string, [string, string]> = {
  War: ['warrior', 'Warrior'], Pal: ['paladin', 'Paladin'], Hun: ['hunter', 'Hunter'],
  Rog: ['rogue', 'Rogue'], Pri: ['priest', 'Priest'], DK: ['deathknight', 'Death Knight'],
  Sha: ['shaman', 'Shaman'], Mag: ['mage', 'Mage'], Loc: ['warlock', 'Warlock'],
  Mon: ['monk', 'Monk'], Dru: ['druid', 'Druid'], DH: ['demonhunter', 'Demon Hunter'],
  Evo: ['evoker', 'Evoker'],
};
// Nome razza (prima colonna roster) -> slug icona (null = nessuna icona ufficiale)
const RACE_ICON: Record<string, string | null> = {
  'Orc': 'orc', 'Undead': 'scourge', 'Tauren': 'tauren', 'Troll': 'troll', 'Goblin': 'goblin',
  'Blood Elf': 'bloodelf', 'Nightborne': 'nightborne', 'Highmountain Tauren': 'highmountaintauren',
  "Mag'har Orc": 'magharorc', 'Zandalari Troll': 'zandalaritroll', 'Vulpera': 'vulpera',
  'Pandaren': 'pandaren', 'Dracthyr': 'dracthyr', 'Earthen': 'earthendwarf', 'Haranir': 'haranir',
  // Alleanza
  'Human': 'human', 'Dwarf': 'dwarf', 'Night Elf': 'nightelf', 'Gnome': 'gnome', 'Draenei': 'draenei',
  'Worgen': 'worgen', 'Void Elf': 'voidelf', 'Lightforged Draenei': 'lightforgeddraenei',
  'Dark Iron Dwarf': 'darkirondwarf', 'Kul Tiran': 'kultiran', 'Mechagnome': 'mechagnome',
};

function classIcon(abbr: string): string {
  const e = CLASS_ABBR[abbr];
  if (!e) return abbr;
  return `<img class="ico ico-class" src="/icons/class/${e[0]}.jpg" alt="${e[1]}" title="${e[1]}" width="26" height="26">`;
}
function raceIcon(name: string): string {
  const slug = RACE_ICON[name];
  if (!slug) return `<span class="race-txt" title="${name}">${name}</span>`;
  return `<img class="ico ico-race" src="/icons/race/${slug}.jpg" alt="${name}" title="${name}" width="26" height="26">`;
}

// Specializzazioni valide per classe (slug classe -> spec). Ogni combo ha un'icona in
// public/icons/spec/<classe>-<spec>.jpg. La chiave per classe disambigua le spec omonime
// tra classi diverse (es. Mage Frost vs Death Knight Frost, Paladin Holy vs Priest Holy).
const SPEC_ICON: Record<string, string[]> = {
  warrior: ['arms', 'fury', 'protection'],
  paladin: ['holy', 'protection', 'retribution'],
  hunter: ['beastmastery', 'marksmanship', 'survival'],
  rogue: ['assassination', 'outlaw', 'subtlety'],
  priest: ['discipline', 'holy', 'shadow'],
  deathknight: ['blood', 'frost', 'unholy'],
  shaman: ['elemental', 'enhancement', 'restoration'],
  mage: ['arcane', 'fire', 'frost'],
  warlock: ['affliction', 'demonology', 'destruction'],
  monk: ['brewmaster', 'mistweaver', 'windwalker'],
  druid: ['balance', 'feral', 'guardian', 'restoration'],
  demonhunter: ['havoc', 'vengeance', 'devourer'],
  evoker: ['devastation', 'preservation', 'augmentation'],
};

// Info per-PG dal tracker (professions/characters.json): realm + professioni, raccolte
// durante il grind degli alberi. Si uniscono per nome (minuscolo) nel tooltip.
const CHAR_INFO: Record<string, { realm?: string; professions?: string[]; class?: string }> =
  Object.fromEntries(
    Object.entries(((charactersManifest as any).characters ?? {}) as Record<string, any>)
      .map(([n, v]) => [n.toLowerCase(), v]),
  );
// Suffisso realm nel roster (·N/·P) -> nome esteso. Da estendere se compaiono altri realm.
const REALM_ABBR: Record<string, string> = { N: 'Nemesis', P: "Pozzo dell'Eternità" };
// Escape per il contenuto di un attributo HTML (title). Gli a-capo diventano &#10;,
// che il tooltip nativo rende su piu' righe.
const escAttr = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/\n/g, '&#10;');

// Accanto a ogni nome PG mette l'ICONA della spec (se nota) o "?" se da confermare.
// Disambigua i PG omonimi via `nome|razza` (CHAR_SPEC_BY_RACE), altrimenti CHAR_SPEC.
// classSlug = classe della colonna: serve a scegliere l'icona giusta per le spec omonime.
// Una cella può contenere più nomi separati da <br>.
// ⚠️ Riceve la cella GREZZA (col suffisso realm ·N/·P), non strippata: il realm serve al
// tooltip, ed e' per-nome. Lo si toglie qui, dopo averlo letto.
function annotateSpec(cell: string, race: string, classSlug: string): string {
  const out = cell.split(/<br\s*\/?>/i).map((seg) => {
    let name = seg.trim();
    if (!name) return seg;
    // Suffisso realm ·N/·P in coda al nome: lo leggo per il tooltip, poi lo tolgo.
    const realmCode = name.match(/·([A-Z])$/)?.[1];
    name = name.replace(/·[A-Z]$/, '').trim();
    // Prefisso "*" = PG pianificato (TODO): non ancora creato. Lo togliamo dal nome,
    // lo rendiamo in stile "da creare" e NON lo contiamo (vedi getRosterCount).
    const todo = name.startsWith('*');
    if (todo) name = name.slice(1).trim();
    // Prefisso "_" = PG esistente ma NON ancora al level cap (in leveling). Lo togliamo
    // dal nome e lo rendiamo in corsivo. Conta come PG normale (esiste già).
    const wip = !todo && name.startsWith('_');
    if (wip) name = name.slice(1).trim();
    // Il valore spec può essere una lista separata da virgole (es. "arms,fury,protection").
    const raw = CHAR_SPEC_BY_RACE[`${name}|${race}`.toLowerCase()] ?? CHAR_SPEC[name.toLowerCase()];
    const specs = raw ? String(raw).split(',').map((s) => s.trim()).filter(Boolean) : [];
    const tail = specs.map((raw2) => {
      // Suffisso "*" = wildcard: gioca tutte le spec (mostra l'icona base + ✦).
      const wild = raw2.endsWith('*');
      const spec = wild ? raw2.slice(0, -1) : raw2;
      if (spec === '?') return '<span class="spec-q" title="spec da confermare">?</span>';
      if (SPEC_ICON[classSlug]?.includes(spec)) {
        const label = titleCase(spec);
        const title = wild ? `${label} · wildcard (gioca tutte le spec)` : label;
        const star = wild ? '<span class="wild" title="wildcard — tutte le spec">✦</span>' : '';
        return `<img class="ico ico-spec" src="/icons/spec/${classSlug}-${spec}.jpg" alt="${title}" title="${title}" width="16" height="16">${star}`;
      }
      return `<span class="spec-l">(${spec[0].toUpperCase()})</span>`; // fallback se manca l'icona
    }).join('');
    // "nome + icone" = inline-flex centrato: scritte e icone allineate verticalmente.
    // Tooltip nativo (abbozzo): realm, livello, professioni PRIMARIE. La spec di combat
    // NON va nel tooltip -- e' gia' l'icona accanto al nome, sarebbe ridondante. Il
    // livello e' GREZZO, dai prefissi del roster (0 se non creato, "in leveling" per "_",
    // 90 al cap): i numeri reali vivono in AllTheThings.lua (chiave `lvl`) e si agganciano
    // a parte, gestendo gli omonimi per realm. Le professioni vengono dal tracker
    // characters.json, popolato durante il grind (quindi ancora parziale).
    const realmCandidate = realmCode ? (REALM_ABBR[realmCode] ?? realmCode) : undefined;
    // Omonimi (Furricane vulpera·P vs worgen·N): la chiave "nome|realm" vince sul nome nudo,
    // come CHAR_SPEC_BY_RACE fa per la spec. Difesa extra: le professioni valgono solo se il
    // realm combacia, cosi' un omonimo senza chiave dedicata non eredita quelle dell'altro.
    const info0 = (realmCandidate ? CHAR_INFO[`${name}|${realmCandidate}`.toLowerCase()] : undefined)
      ?? CHAR_INFO[name.toLowerCase()];
    const realmName = realmCandidate ?? info0?.realm;
    const info = (info0 && realmName && info0.realm && info0.realm !== realmName) ? undefined : info0;
    const level = todo ? '0 · non creato' : wip ? 'in leveling (<90)' : '90';
    const tipLines = [name];
    if (realmName) tipLines.push(`Realm: ${realmName}`);
    tipLines.push(`Livello: ${level}`);
    const profs = info?.professions;
    if (profs?.length) tipLines.push(`Professioni: ${profs.join(', ')}`);
    const nameAttr = ` title="${escAttr(tipLines.join('\n'))}"`;
    const pgClass = todo ? ' pg--todo' : wip ? ' pg--wip' : '';
    return `<span class="pg${pgClass}"><span class="pg-name"${nameAttr}>${name}</span>${tail}</span>`;
  });
  return ` ${out.join('<br>')} `;
}

const stripRealm = (cell: string): string => cell.replace(/·[A-Z]/g, '');

// PG reali in una cella: stessa regola del contatore totale (getRosterCount).
// Esclude i pianificati "*" (non ancora creati), include i "_" in leveling; X/vuoto = 0.
function cellCount(cell: string): number {
  const t = stripRealm(cell).trim();
  if (!t || t === 'X') return 0;
  return t.split(/<br\s*\/?>/i).map((s) => s.trim()).filter((s) => s && !s.startsWith('*')).length;
}

// Estrae le righe (array di celle) della tabella markdown sotto "## <section>".
function extractRosterTable(raw: string, section: string): string[][] | null {
  const lines = raw.split('\n');
  let i = lines.findIndex((l) => new RegExp(`^##\\s+${section}`, 'i').test(l));
  if (i < 0) return null;
  const rows: string[][] = [];
  for (i++; i < lines.length; i++) {
    const l = lines[i];
    if (l.trim().startsWith('|')) {
      const cells = l.trim().split('|').slice(1, -1);
      if (cells.every((c) => /^\s*:?-{2,}:?\s*$/.test(c))) continue; // riga separatore markdown
      rows.push(cells);
    } else if (rows.length) {
      break; // fine tabella
    }
  }
  return rows.length ? rows : null;
}

// Costruisce le <tr> del corpo: icona razza in prima colonna, casella scura per X, icona spec.
// header = riga di intestazione (abbreviazioni classe) per ricavare la classe di ogni colonna.
function rosterBodyRows(rows: string[][], rowClass: string, header: string[]): { html: string; races: Set<string>; colCounts: number[] } {
  const races = new Set<string>();
  const colCounts: number[] = new Array(header.length).fill(0); // totale PG per classe (indice 0 inutilizzato)
  const html = rows.map((cells) => {
    const race = stripRealm(cells[0] ?? '').trim();
    // Totale PG della razza (riga): mostrato accanto all'icona nella cella-testata.
    let rowTotal = 0;
    for (let j = 1; j < cells.length; j++) {
      const n = cellCount(cells[j] ?? '');
      rowTotal += n;
      colCounts[j] += n;
    }
    const tds = cells.map((cell, i) => {
      const t = stripRealm(cell).trim();
      if (i === 0) {
        races.add(t);
        const label = t in RACE_ICON ? raceIcon(t) : t;
        const tot = `<span class="rtot" title="PG di questa razza">${rowTotal}</span>`;
        // <th scope="row">, non <td>: e' l'intestazione di riga della matrice, ed e'
        // cio' che lega ogni cella alla sua razza per chi usa uno screen reader.
        return `<th scope="row" class="rhead"><span class="rcell">${label}${tot}</span></th>`;
      }
      if (t === 'X') return '<td><span class="na" title="Combinazione non creabile in gioco"></span></td>';
      if (t === '') return '<td></td>';
      const classSlug = CLASS_ABBR[(header[i] ?? '').trim()]?.[0] ?? '';
      // Cella GREZZA (col suffisso realm): annotateSpec legge il realm e poi lo toglie.
      return `<td>${annotateSpec(cell, race, classSlug)}</td>`;
    }).join('');
    return `<tr class="${rowClass}">${tds}</tr>`;
  }).join('');
  return { html, races, colCounts };
}

// Conta i PG presenti nel roster (Orda + Alleanza), inclusi i nomi multipli per cella.
export function getRosterCount(): number {
  const raw = Object.values(rosterFile)[0] ?? '';
  let count = 0;
  for (const section of ['Orda', 'Alleanza']) {
    const rows = extractRosterTable(raw, section);
    if (!rows) continue;
    for (const cells of rows.slice(1)) {
      for (let i = 1; i < cells.length; i++) {
        const t = stripRealm(cells[i] ?? '').trim();
        if (!t || t === 'X') continue;
        // I PG pianificati (prefisso "*") non sono ancora creati: non si contano.
        count += t.split(/<br\s*\/?>/i).map((s) => s.trim()).filter((s) => s && !s.startsWith('*')).length;
      }
    }
  }
  return count;
}

// ── Screenshot UI ─────────────────────────────────
// Quanti screenshot ha la pagina /ui. Serve alla card della home, che fino al
// 2026-07-20 portava il numero scritto a mano e andava ritoccato a ogni file
// aggiunto o tolto. Stesso glob di ui.astro: `*` non attraversa lo slash, quindi
// prende solo la radice e NON le miniature in thumb/, che raddoppierebbero il conto.
// `eager` come in ui.astro: servirebbero solo le chiavi, ma quella e' la forma gia'
// in produzione qui, e una variante piu' magra non compilata in locale non vale il
// rischio su un conteggio da una riga.
const screenshotFiles = import.meta.glob('/public/screenshots/*.jpg', { eager: true });
export function getScreenshotCount(): number {
  return Object.keys(screenshotFiles).length;
}

export function getRosterHtml(): string {
  const raw = Object.values(rosterFile)[0] ?? '';
  const orda = extractRosterTable(raw, 'Orda');
  if (!orda) return '<p>Roster non trovato.</p>';
  const header = orda[0];
  const ncols = header.length;

  const band = (text: string, cls: string) => `<tr class="rsep ${cls}"><td colspan="${ncols}">${text}</td></tr>`;
  const horde = rosterBodyRows(orda.slice(1), 'fac-horde', header);

  // Totali per classe (colonna): partono dall'Orda, poi sommo l'Alleanza.
  const colTotals = horde.colCounts.slice();

  let allyHtml = '';
  const ally = extractRosterTable(raw, 'Alleanza');
  if (ally) {
    // Razze condivise (già nel blocco Orda) restano solo lì: qui le saltiamo.
    const allyRows = ally.slice(1).filter((cells) => !horde.races.has(stripRealm(cells[0]).trim()));
    if (allyRows.length) {
      const allyBody = rosterBodyRows(allyRows, 'fac-alliance', header);
      allyHtml = band('Alleanza', 'rsep--alliance') + allyBody.html;
      for (let i = 0; i < colTotals.length; i++) colTotals[i] += allyBody.colCounts[i];
    }
  }

  // Totale PG per classe: unico contatore, accanto all'icona classe in testata
  // (stesso pattern del totale-razza accanto all'icona razza).
  const thead = '<thead><tr>' + header.map((c, i) => {
    // Angolo vuoto: resta <th> (valido in una riga di testata) perche' e' `thead th`
    // a dargli lo sfondo dell'intestazione. Come <td> restava una tacca bianca.
    if (i === 0) return '<th></th>';
    const label = CLASS_ABBR[c.trim()] ? classIcon(c.trim()) : c.trim();
    const tot = `<span class="rtot" title="PG di questa classe">${colTotals[i]}</span>`;
    return `<th scope="col"><span class="rcell rcell--stack">${label}${tot}</span></th>`;
  }).join('') + '</tr></thead>';

  const body = band('Orda', 'rsep--horde') + horde.html + allyHtml;

  return `<div class="table-scroll"><table>${thead}<tbody>${body}</tbody></table></div>`;
}
