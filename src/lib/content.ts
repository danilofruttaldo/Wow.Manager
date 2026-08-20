// Accesso ai dati della repo Wow.Manager (manifest JSON + markdown).
// I file vivono fuori da src/: sono la fonte di verità, il sito li legge in sola lettura.
import { execSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { join } from 'node:path';

import { CHAR_SPEC, CHAR_SPEC_BY_RACE } from './char-specs';

import addonsManifest from '../../addons/manifest.json';
import macrosManifest from '../../macros/manifest.json';
import professionsManifest from '../../professions/manifest.json';
import extraManifest from '../../scripts/manifest.json';
import transmogManifest from '../../transmog/manifest.json';
import mountsManifest from '../../mounts/manifest.json';
import profTreesManifest from '../../professions/trees.json';
import profLevelingManifest from '../../professions/leveling.json';
import profBuildsManifest from '../../professions/builds.json';
import profSpecsManifest from '../../professions/specs.json';
import charactersManifest from '../../professions/characters.json';
import hardwareManifest from '../../hardware/manifest.json';

// ── Tipi ──────────────────────────────────────────
export interface Addon {
  key: string;
  name: string;
  icon?: string;          // path icona addon (avatar CurseForge in public/icons/addon/)
  img?: string;           // anteprima per la modale (public/addon-img/<key>.webp), se scaricata
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

// Voce dell'ELENCO professioni (manifest.json): la pagina la usa per i chip + la nota
// editoriale. L'albero vero e il leveling stanno in ProfTree/LevelGuide (trees.json /
// leveling.json). Il vecchio modello a 3 tappe (first/second/third/ProfStep) e' stato
// rimosso: era dati morti, non piu' renderizzato da quando la pagina mostra l'albero.
export interface Profession {
  key: string;
  name: string;
  type: 'crafting' | 'gathering';
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

// Pezzo della postazione di gioco (hardware/manifest.json).
export interface HwComponent {
  key: string;
  label: string;          // etichetta di riga: CPU, Scheda video, Monitor...
  name: string;
  detail?: string;        // seconda riga tecnica (frequenze, sigla del kit, driver)
  desc?: string;          // riga mostrata sul sito: perche' quel pezzo conta per WoW
  notes?: string;         // memoria interna di manutenzione: NON mostrata sul sito
}

// Impostazione che decide come gira il gioco. `where` = chiave di `places`, cioe' DOVE si
// tocca: le impostazioni che contano sono sparse fra quattro posti diversi (OSD del
// monitor, driver, gioco, BIOS) e raggrupparle per luogo e' il senso della pagina.
export interface HwSetting {
  key: string;
  name: string;
  where: string;
  value?: string;
  state: 'ok' | 'todo' | 'warn';
  desc?: string;
  notes?: string;         // memoria interna di manutenzione: NON mostrata sul sito
}

// Un gruppo di impostazioni = un posto dove metterci le mani.
export interface HwGroup {
  key: string;
  label: string;
  items: HwSetting[];
}

// ── Meta build + data aggiornamento (git) ─────────
export const wowBuild: string = (addonsManifest as any)._meta?.wow_build ?? '';
// Data dell'ultimo commit che ha toccato il file/cartella sorgente (YYYY-MM-DD).
// Memoizzata per relPath: il layout la chiama una volta per pagina (~9 spawn git a
// build), e lo stesso path da' sempre lo stesso risultato entro un build.
const _dateCache = new Map<string, string>();
export function sourceDate(relPath = '.'): string {
  const cached = _dateCache.get(relPath);
  if (cached !== undefined) return cached;
  let out = '';
  try {
    out = execSync(`git log -1 --format=%cs -- "${relPath}"`, { encoding: 'utf8' }).trim();
  } catch {
    out = '';
  }
  _dateCache.set(relPath, out);
  return out;
}

// ── Esistenza dei file in public/ ─────────────────
// Le pagine chiedono di continuo «questo file c'è?» per non mostrare un'immagine rotta:
// icone addon, anteprime addon, icone mount, render mount, screenshot UI.
//
// ⚠️ NON si usa `import.meta.glob('/public/…')`, che pure sarebbe la via ovvia: di quei
// glob si usano solo le CHIAVI, mai i moduli, ma il solo fatto di dichiararli fa passare
// i file nella pipeline asset di Vite, che ne emette una **seconda copia hashata** in
// `dist/_astro` che nessuno referenzia — le pagine puntano ai file serviti da `public/`.
// Misurato: `dist` pesava 86 MB, di cui **40 MB di duplicati** (1521 webp + 1212 jpg)
// contro 107 KB di codice vero. `eager: false` non cambia nulla: emette lo stesso.
//
// ⚠️ La cache SCADE dopo un secondo, e non è un dettaglio: senza cache la pagina mount
// farebbe 1525 letture di una directory da 1508 file (secondi), ma una cache eterna
// toglierebbe l'hot-reload — aggiungi uno screenshot in dev e non compare finché non
// riavvii. Con la scadenza breve il build rilegge una manciata di volte in 17 secondi
// (niente) e in dev basta ricaricare la pagina.
// ⚠️ La radice è `process.cwd()`, NON un path ricavato da `import.meta.url`: in build il
// modulo è già impacchettato, quindi `import.meta.url` punta al chunk e non al sorgente —
// provato, e le icone di /addons e /mount sparivano tutte in silenzio. `cwd` è la radice
// del progetto sia in build sia in dev, ed è la stessa assunzione su cui `sourceDate` fa
// girare `git log` da sempre.
const publicDir = join(process.cwd(), 'public');
const _ls = new Map<string, { t: number; f: Set<string> }>();
const TTL = 1000;
function filesIn(rel: string): Set<string> {
  const hit = _ls.get(rel);
  const ora = Date.now();
  if (hit && ora - hit.t < TTL) return hit.f;
  let f: Set<string>;
  try {
    f = new Set(readdirSync(join(publicDir, rel)));
  } catch {
    f = new Set();   // cartella assente: nessun file, non un errore di build
  }
  _ls.set(rel, { t: ora, f });
  return f;
}

// ── Addon ─────────────────────────────────────────
export const addonsMeta = (addonsManifest as any)._meta;
// Icona addon (avatar CurseForge scaricato in public/icons/addon/<key>.<ext>).
// Estensioni miste (png/jpg/jpeg), quindi si prova una per una.
function addonIcon(key: string): string | undefined {
  const files = filesIn('icons/addon');
  for (const ext of ['png', 'jpg', 'jpeg']) {
    if (files.has(`${key}.${ext}`)) return `/icons/addon/${key}.${ext}`;
  }
  return undefined;
}
// Immagine di anteprima per la modale (public/addon-img/<key>.webp, la scarica
// scripts/addon-images.mjs): se il file non c'e' il campo resta undefined e la modale non
// mostra la fascia.
const addonImage = (key: string): string | undefined =>
  filesIn('addon-img').has(`${key}.webp`) ? `/addon-img/${key}.webp` : undefined;
let _addons: Addon[] | null = null;
export function getAddons(): Addon[] {
  if (_addons) return _addons;
  const raw = (addonsManifest as any).addons ?? {};
  return (_addons = Object.entries(raw)
    .map(([key, v]: [string, any]) => ({ key, folders: [], ...v, icon: v.icon ?? addonIcon(key), img: addonImage(key) }))
    .sort((a, b) => (a.name ?? '').localeCompare(b.name ?? '')));
}

// ── Macro ─────────────────────────────────────────// Corpi reali delle macro: file .txt fuori da src/, letti a build-time (sola lettura).
// Chiave glob = path assoluto tipo '/.../macros/warrior/charge-intervene.txt';
// li mappo su `body_file` (es. 'warrior/charge-intervene.txt') per suffisso.
const macroBodies = import.meta.glob('../../macros/**/*.txt', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;
function macroBody(bodyFile?: string | null): string | undefined {
  if (!bodyFile) return undefined;
  const hit = Object.entries(macroBodies).find(([p]) => p.endsWith('/' + bodyFile));
  return hit ? hit[1].trim() : undefined;
}
let _macros: Macro[] | null = null;
export function getMacros(): Macro[] {
  if (_macros) return _macros;
  const raw = (macrosManifest as any).macros ?? {};
  return (_macros = Object.entries(raw)
    .map(([key, v]: [string, any]) => ({ key, ...v, body: v.body ?? macroBody(v.body_file) }))
    .sort((a, b) => (a.name ?? '').localeCompare(b.name ?? '')));
}

// ── Professioni ───────────────────────────────────
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
  // Unione ordinata trees.json + leveling.json: un'espansione con la sola guida di leveling
  // (o il solo albero) resta visibile nella tendina. trees.json in testa (guida defaultExp),
  // le sole-leveling in coda -- il default non cambia e la pagina le rende gia' con grazia.
  const t = ((profTreesManifest as any).expansions ?? []) as string[];
  const l = ((profLevelingManifest as any).expansions ?? []) as string[];
  return [...t, ...l.filter((e) => !t.includes(e))];
}
export function getProfessionTrees(): Record<string, Record<string, ProfTree>> {
  return ((profTreesManifest as any).professions ?? {}) as Record<string, Record<string, ProfTree>>;
}

// Descrizioni brevi (IT) dei nodi degli alberi di specializzazione (professions/specs.json):
// professione -> nome-nodo del client (come in trees.json) -> descrizione. Alimentano la riga
// descrittiva di ogni card della sezione 1 di /professioni. Le spec di primo livello vengono
// dal client, i sotto-nodi da ricerca verificata sulle guide. File suo per non mischiarlo col
// dump di trees.json (macchina-generato, rigenerabile).
export function getProfessionSpecDescs(): Record<string, Record<string, string>> {
  return ((profSpecsManifest as any).professions ?? {}) as Record<string, Record<string, string>>;
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

// ORDINE CONSIGLIATO delle specializzazioni (professions/builds.json): quali spec prendere
// e in che ordine, con punti e alternative. Editoriale (derivato dalle `notes` di
// manifest.json, non piu' mostrate) ma VERIFICATO -- ogni `spec` combacia con un nodo del
// client in trees.json. E' cio' che la pagina rende in cima alla sezione 1, sopra l'albero
// completo. File suo, come leveling.json, per non mischiarlo col dump macchina-generato.
export interface ProfBuildStep {
  spec: string;      // nodo/spec dove mettere i punti (nome del client, come in trees.json)
  alt?: string;      // alternativa "oppure ...": ramo o build in alternativa
  tag?: string;      // pastiglia breve: "base", "10 pt", "uno solo", "alternativa"...
  note?: string;     // razionale reader-facing (italiano)
  nodes?: string[];  // nomi-nodo ESPLICITI per il badge d'ordine nell'albero (fallback: spec+alt)
}
// Ordine alternativo per una classe/situazione specifica (es. Druido per Herbalism: ha la
// raccolta a cavallo da Travel Form e inverte l'ordine). La pagina mostra un interruttore
// con `label` che scambia i passi visualizzati.
export interface ProfBuildVariant {
  key: string;     // slug tecnico, es. 'druid'
  label: string;   // etichetta dell'interruttore, es. 'Druido'
  steps: ProfBuildStep[];
}
export interface ProfBuild {
  steps: ProfBuildStep[];
  variants?: ProfBuildVariant[];
}
// In builds.json una professione e' un semplice array di step (caso comune) OPPURE un
// oggetto { steps, variants } quando ha ordini alternativi. Normalizziamo qui al secondo
// caso, cosi' la pagina legge sempre `.steps` (+ `.variants` opzionali).
function normalizeBuild(raw: ProfBuildStep[] | ProfBuild): ProfBuild {
  return Array.isArray(raw) ? { steps: raw } : (raw ?? { steps: [] });
}
export function getProfessionBuilds(): Record<string, Record<string, ProfBuild>> {
  const raw = ((profBuildsManifest as any).professions ?? {}) as Record<string, Record<string, ProfBuildStep[] | ProfBuild>>;
  const out: Record<string, Record<string, ProfBuild>> = {};
  for (const [key, byExp] of Object.entries(raw)) {
    out[key] = {};
    for (const [exp, v] of Object.entries(byExp)) out[key][exp] = normalizeBuild(v);
  }
  return out;
}

// ── Extra (script / link / appunti) ───────────────// Corpi degli script (file eseguibili fuori da src/, letti a build-time in sola lettura).
const extraBodies = import.meta.glob('../../scripts/**/*.{sh,txt,lua,ps1,bat,py,mjs}', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;
function extraBody(bodyFile?: string | null): string | undefined {
  if (!bodyFile) return undefined;
  const hit = Object.entries(extraBodies).find(([p]) => p.endsWith('/' + bodyFile));
  return hit ? hit[1].replace(/\s+$/, '') : undefined;
}
let _extra: Extra[] | null = null;
export function getExtra(): Extra[] {
  if (_extra) return _extra;
  const raw = (extraManifest as any).extra ?? {};
  return (_extra = Object.entries(raw)
    .map(([key, v]: [string, any]) => ({ key, ...v, body: v.body ?? extraBody(v.body_file) }))
    .sort((a, b) => (a.name ?? '').localeCompare(b.name ?? '')));
}

// ── Hardware (postazione di gioco) ────────────────
// hardware/manifest.json e' REDAZIONALE, non macchina-generato: i valori sono stati
// rilevati (WMI/CIM per i componenti, EDID del monitor dal registro, Config.wtf riletto
// in byte per i CVar), ma il file si aggiorna a mano quando cambia un pezzo. Come
// altrove nel repo, `desc` si mostra e `notes` no.
let _hw: { components: HwComponent[]; settings: HwSetting[]; places: Record<string, string> } | null = null;
function hardware() {
  if (_hw) return _hw;
  const m = hardwareManifest as any;
  return (_hw = {
    components: (m.components ?? []) as HwComponent[],
    settings: (m.settings ?? []) as HwSetting[],
    places: (m.places ?? {}) as Record<string, string>,
  });
}

export function getHwComponents(): HwComponent[] {
  return hardware().components;
}

// Impostazioni raggruppate per luogo, nell'ordine in cui `places` le dichiara nel
// manifest (monitor -> driver -> gioco -> BIOS): l'ordine e' un dato redazionale, non
// alfabetico. I gruppi vuoti non si emettono.
export function getHwGroups(): HwGroup[] {
  const { settings, places } = hardware();
  return Object.entries(places)
    .map(([key, label]) => ({ key, label, items: settings.filter(s => s.where === key) }))
    .filter(g => g.items.length > 0);
}

// Quante impostazioni restano da mettere a posto: alimenta il contatore in pagina.
export function getHwTodo(): number {
  return hardware().settings.filter(s => s.state !== 'ok').length;
}

// ── Mount (collezione cavalcature) ────────────────
// mounts/manifest.json e' INTERAMENTE macchina-generato (scripts/mount-dump.lua +
// scripts/mount-sync.ps1): elenca tutte le mount che il gioco conosce, prese e
// mancanti, come le vede il diario. Niente di redazionale qui dentro: si riscrive per
// intero a ogni sync, quindi non aggiungere campi a mano -- andrebbero persi.
export interface Mount {
  id: number;
  spell: number;
  display: number;         // creatureDisplayInfoID = il MODELLO -> public/mounts/<display>.webp (600x600)
  name: string;
  src: number;             // indice sourceType del client (chiave di `sources`)
  srcText?: string;        // provenienza per esteso, multiriga come la scrive il gioco
  desc?: string;           // testo di colore del gioco, diverso dalla provenienza
  type: number;            // mountTypeID grezzo, tenuto per diagnostica
  // Categorie COME LE DA' IL DIARIO (i suoi filtri Type), non dedotte: una mount puo'
  // starne in piu' d'una -- una volante che porta passeggeri e' in `volo` e in
  // `passeggero`. Vuoto = il diario non l'ha classificata (in pagina: «Altro»).
  cats: string[];
  // Vincoli d'uso, risolti da scripts/mount-classes.mjs sui dati di Wowhead: il client
  // non li espone (nel suo tooltip non c'e' nessuna riga "Requires") e la provenienza
  // cita una classe in 23 casi su 1527 e la razza mai. Oggi 52 mount hanno un vincolo
  // di classe e 13 uno di razza -- i cavalli razziali dei paladini piu' l'hawkstrider
  // dei Blood Elf. `race` puo' elencarne piu' d'una, separate da " / " (il Great
  // Exarch's Elekk vale per Draenei e Draenei Forgiati dalla Luce).
  faction: 'horde' | 'alliance' | null;
  class: string | null;
  race: string | null;
  got: 0 | 1;
  icon?: string;           // nome icona Wowhead -> public/icons/mount/<icon>.jpg
  img?: string;            // path dell'immagine del modello, se scaricata
}

// Vincoli di una mount resi come ICONE di gioco col nome nel tooltip, non come
// testo: le icone di classe e razza esistono gia' (le usa la tabella PG) e sono il
// linguaggio visivo del sito. ⚠️ Non contraddice la regola "niente tooltip
// decorativi": qui il tooltip espande un'icona che E' il contenuto, esattamente come
// l'<abbr> sulle sigle dei raid in /transmog. Senza icona (razza non mappata) la
// voce resta, come pastiglia di testo: meglio scritta che persa.
export interface MountBadge {
  icon?: string;
  label: string;
}
export function mountBadges(m: Mount): MountBadge[] {
  const out: MountBadge[] = [];
  if (m.faction) {
    out.push({
      icon: `/icons/faction/${m.faction}.jpg`,
      label: m.faction === 'horde' ? 'Orda' : 'Alleanza',
    });
  }
  if (m.class) {
    out.push({ icon: `/icons/class/${m.class.toLowerCase().replace(/[^a-z]/g, '')}.jpg`, label: m.class });
  }
  for (const r of (m.race ?? '').split('/').map((s) => s.trim()).filter(Boolean)) {
    const slug = RACE_ICON[r];
    out.push({ icon: slug ? `/icons/race/${slug}.jpg` : undefined, label: r });
  }
  return out;
}

// Immagini del modello: non esistono per tutte, quindi si guarda il file. Sono i
// render UFFICIALI di Blizzard (600x600 su fondo scuro), scaricati e convertiti in
// webp da scripts/mount-images.mjs; dove il render non c'e' (7 su 1516) resta la
// vecchia miniatura del model viewer di Wowhead, 300x300 su fondo trasparente.
function mountImg(display: number | undefined): string | undefined {
  return display && filesIn('mounts').has(`${display}.webp`) ? `/mounts/${display}.webp` : undefined;
}
let _mounts: Mount[] | null = null;
export function getMounts(): Mount[] {
  if (_mounts) return _mounts;
  const raw = ((mountsManifest as any).mounts ?? []) as Mount[];
  // Icona dichiarata ma file assente (download fallito) -> si scarta qui, cosi' la card
  // ripiega sul monogramma invece di mostrare un'immagine rotta.
  return (_mounts = raw.map((m) => ({
    ...m,
    icon: m.icon && filesIn('icons/mount').has(`${m.icon}.jpg`) ? m.icon : undefined,
    img: mountImg(m.display),
  })));
}

// sourceType -> etichetta, presa dal client (BATTLE_PET_SOURCE_n): non e' trascritta,
// quindi non puo' divergere dal gioco.
export function getMountSources(): Record<string, string> {
  return ((mountsManifest as any).sources ?? {}) as Record<string, string>;
}

export function getMountStats(): { got: number; total: number; pct: number } {
  const all = getMounts();
  const got = all.filter((m) => m.got === 1).length;
  return { got, total: all.length, pct: all.length ? Math.round((got / all.length) * 100) : 0 };
}

// Le categorie del menu "Type" del diario: la pagina rispecchia i filtri di gioco
// invece di inventarsi una tassonomia sua. '?' = il diario non l'ha classificata, e
// si dice «Altro» invece di indovinare.
//
// ⚠️ I TIPI DEL GIOCO SONO QUATTRO: Ground, Flying, Aquatic, Ride Along. Sono quelli
// che possono essere una CHIP di filtro, e non se ne aggiungono altri.
// ⚠️ «Passeggeri» (Ride Along) oggi non compare: il filtro corrispondente si dichiara
// non valido e non restituisce nulla. La voce resta qui perche' la chip nasce solo se
// ha almeno una mount -- se un giorno il gioco risponde, appare da se'.
//
// «Skyriding» NON e' un quinto tipo e per questo ha `chip: false`, cioe' compare solo
// come pastiglia nella modale. Dal rifacimento del volo lo skyriding vale su
// praticamente tutte le volanti, salvo eccezioni: il filtro 5 del diario non elenca
// «le mount che skyridano» ma le 23 cavalcature PERSONALIZZABILI (Renewed
// Proto-Drake, Highland Drake, i Delver's...). Come chip diceva la cosa sbagliata --
// 23 su 712 volanti -- e tutte e 23 sono comunque gia' in `volo`, quindi togliendola
// dal filtro non si perde nulla.
export const MOUNT_CATS: { key: string; label: string; icon: string; chip?: boolean }[] = [
  { key: 'terra', label: 'Terra', icon: '/icons/mountcat/terra.jpg' },
  { key: 'volo', label: 'Volo', icon: '/icons/mountcat/volo.jpg' },
  { key: 'acqua', label: 'Acqua', icon: '/icons/mountcat/acqua.jpg' },
  { key: 'passeggero', label: 'Passeggeri', icon: '/icons/mountcat/passeggero.jpg' },
  { key: '?', label: 'Altro', icon: '/icons/mountcat/altro.jpg' },
  { key: 'skyriding', label: 'Personalizzabile', icon: '/icons/mountcat/skyriding.jpg', chip: false },
];

// Le categorie di una mount, gia' pronte per l'attributo del filtro: vuoto -> '?',
// cosi' la chip «Altro» ha qualcosa da agganciare.
export function mountCats(m: Mount): string[] {
  return m.cats && m.cats.length ? m.cats : ['?'];
}

// ── Transmog (tier set per classe) ────────────────
// Matrice tier × versione, una per classe. Le 4 colonne sono SLOT di versione, non
// difficoltà letterali: prima di Cataclysm gli assi erano altri (10/25 uomini, fazione,
// Sanctified), quindi ogni tier dichiara l'etichetta reale degli slot che usa e gli slot
// non dichiarati diventano celle "non applicabile" (stesso pattern delle combo della tabella PG).
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
function formatMissing(raw: string, raids: [string, string][]): string {
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

// Memoizzata: e' una funzione PURA di import statici, ma viene chiamata ~16 volte per
// build (home, /transmog, e l'endpoint JSON una volta per classe -> 13). Nessun chiamante
// muta il risultato, quindi una sola istanza condivisa e' sicura e byte-identica.
let _tmog: TmogClass[] | null = null;
export function getTransmog(): TmogClass[] {
  return (_tmog ??= computeTransmog());
}
function computeTransmog(): TmogClass[] {
  const m = transmogManifest as any;
  const cols = m.columns as { key: string; label: string }[];
  const tiers = (m.tiers ?? []) as any[];
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

    const groups: TmogGroup[] = ((m.expansions ?? []) as any[]).map((exp) => {
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
          const gotN = Number((Array.isArray(cell) ? cell[0] : cell) ?? 0);
          const totalN = Number((Array.isArray(cell) ? cell[1] : undefined) ?? t.pieces);
          // Guardia anti-NaN: un valore malformato in `collected` (typo di editing manuale)
          // non deve propagarsi in classGot/rowTotal/pct e nella % della home.
          const got = Number.isFinite(gotN) ? gotN : 0;
          const total = Number.isFinite(totalN) ? totalN : 0;
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
const pgFile = import.meta.glob('/pg.md', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;

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

// Abbreviazione classe (header tabella PG) -> [slug icona, nome esteso]
const CLASS_ABBR: Record<string, [string, string]> = {
  War: ['warrior', 'Warrior'], Pal: ['paladin', 'Paladin'], Hun: ['hunter', 'Hunter'],
  Rog: ['rogue', 'Rogue'], Pri: ['priest', 'Priest'], DK: ['deathknight', 'Death Knight'],
  Sha: ['shaman', 'Shaman'], Mag: ['mage', 'Mage'], Loc: ['warlock', 'Warlock'],
  Mon: ['monk', 'Monk'], Dru: ['druid', 'Druid'], DH: ['demonhunter', 'Demon Hunter'],
  Evo: ['evoker', 'Evoker'],
};
// Nome razza (prima colonna tabella PG) -> slug icona (null = nessuna icona ufficiale)
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

// Nome professione come lo scrive il tracker (inglese, dal client) -> chiave del manifest,
// che e' anche il nome del file icona (public/icons/prof/<key>.jpg). Derivata dal manifest
// invece che scritta a mano: una professione nuova prende l'icona senza toccare questo file.
const PROF_KEY: Record<string, string> = Object.fromEntries(
  getProfessions().map((p) => [p.name.toLowerCase(), p.key]),
);

// Info per-PG dal tracker (professions/characters.json): realm + professioni, raccolte
// durante il grind degli alberi. Si uniscono per nome (minuscolo) nel tooltip.
const CHAR_INFO: Record<string, { realm?: string; professions?: string[]; class?: string; level?: number }> =
  Object.fromEntries(
    Object.entries(((charactersManifest as any).characters ?? {}) as Record<string, any>)
      .map(([n, v]) => [n.toLowerCase(), v]),
  );
// Suffisso realm nella tabella PG -> nome esteso. Devono esserci TUTTI i codici della
// legenda di pg.md (N/P/R/S): se ne manca uno, per quei PG realmCandidate resta la lettera
// grezza, la guardia realm-match scatta a vuoto e il tooltip perde le professioni.
const REALM_ABBR: Record<string, string> = {
  N: 'Nemesis', P: "Pozzo dell'Eternità", R: 'Ravencrest', S: 'Silvermoon',
};
// Escape per il contenuto di un attributo HTML (title). Gli a-capo diventano &#10;,
// che il tooltip nativo rende su piu' righe.
const escAttr = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/\n/g, '&#10;');
// Escape per il TESTO di un elemento (il nome PG visibile): & < >. Il title passa gia'
// da escAttr; il nome mostrato va escapato a parte, per coerenza col resto del rendering.
const escHtml = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// Sotto ogni nome PG mette la fila di ICONE: prima la spec (se nota) o "?" se da confermare,
// poi le professioni primarie del tracker. Nome sopra, icone a capo.
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
    // lo rendiamo in stile "da creare" e NON lo contiamo (vedi getPgCount).
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
      // Suffisso "*" = wildcard: gioca tutte le spec. Il "*" NUDO (valore `'*'`, senza spec
      // davanti) e' il caso "nessuna spec preferita": mostra la sola icona wildcard. Con una
      // spec davanti (`'arms*'`) restano tutte e due, l'icona della spec base piu' la wildcard.
      const wild = raw2.endsWith('*');
      const spec = wild ? raw2.slice(0, -1) : raw2;
      const star = wild ? '<img class="ico ico-wild" src="/icons/ui/wildcard.jpg" alt="wildcard — tutte le spec" title="wildcard — tutte le spec" width="16" height="16">' : '';
      if (spec === '?') return `<span class="spec-q" title="spec da confermare">?</span>${star}`;
      if (SPEC_ICON[classSlug]?.includes(spec)) {
        const label = titleCase(spec);
        const title = wild ? `${label} · wildcard (gioca tutte le spec)` : label;
        return `<img class="ico ico-spec" src="/icons/spec/${classSlug}-${spec}.jpg" alt="${title}" title="${title}" width="16" height="16">${star}`;
      }
      // Ripiego se l'icona della spec manca. Con spec vuota resta la sola wildcard: niente
      // `spec[0]` su stringa vuota, che farebbe crashare il build.
      return spec ? `<span class="spec-l">(${spec[0].toUpperCase()})</span>${star}` : star;
    }).join('');
    // "nome sopra, icone sotto" = inline-flex in colonna (vedi .pg in pg.astro).
    // Tooltip nativo (abbozzo): realm e livello. Ne' la spec ne' le professioni ci vanno --
    // sono gia' icone sotto il nome, col proprio title, e ripeterle sarebbe ridondante. Il
    // livello e' GREZZO, dai prefissi della tabella PG (0 se non creato, "in leveling" per "_",
    // 90 al cap): i numeri reali vivono in AllTheThings.lua (chiave `lvl`) e si agganciano
    // a parte, gestendo gli omonimi per realm.
    const realmCandidate = realmCode ? (REALM_ABBR[realmCode] ?? realmCode) : undefined;
    // Omonimi (Furricane vulpera·P vs worgen·N): la chiave "nome|realm" vince sul nome nudo,
    // come CHAR_SPEC_BY_RACE fa per la spec. Difesa extra: le professioni valgono solo se il
    // realm combacia, cosi' un omonimo senza chiave dedicata non eredita quelle dell'altro.
    const info0 = (realmCandidate ? CHAR_INFO[`${name}|${realmCandidate}`.toLowerCase()] : undefined)
      ?? CHAR_INFO[name.toLowerCase()];
    const realmName = realmCandidate ?? info0?.realm;
    const info = (realmCandidate && info0?.realm && info0.realm !== realmCandidate) ? undefined : info0;
    // Livello REALE da AllTheThings (nel tracker) se noto; altrimenti fallback grezzo
    // dai prefissi della tabella PG (0 se non creato, in leveling, 90 al cap).
    const level = info?.level != null
      ? String(info.level)
      : (todo ? '0 · non creato' : wip ? 'in leveling (<90)' : '90');
    const tipLines = [name];
    if (realmName) tipLines.push(`Realm: ${realmName}`);
    tipLines.push(`Livello: ${level}`);
    const nameAttr = ` title="${escAttr(tipLines.join('\n'))}"`;
    // Professioni PRIMARIE dal tracker characters.json (popolato durante il grind, quindi
    // ancora parziale). Le secondarie sono escluse gia' nel dump. Nome della professione nel
    // title dell'icona, come per la spec.
    const profs = (info?.professions ?? []).filter(Boolean);
    const profTail = profs.length === 0
      // PG non ancora passato dal dump: due "?" al posto delle due professioni primarie.
      // Meglio del vuoto — dice «dato che non ho» invece di far sembrare che il PG non ne
      // abbia, e tiene la fila di icone lunga uguale a quella dei PG tracciati.
      ? '<span class="prof-q" title="professioni ignote (PG non ancora passato dal dump)">?</span>'.repeat(2)
      : profs.map((p) => {
          const key = PROF_KEY[p.toLowerCase()];
          const label = escAttr(p);
          // Ripiego coerente con quello della spec: iniziale fra parentesi se manca la chiave
          // (professione fuori dal manifest), cosi' il dato non sparisce in silenzio.
          return key
            ? `<img class="ico ico-prof" src="/icons/prof/${key}.jpg" alt="${label}" title="${label}" width="16" height="16">`
            : `<span class="spec-l" title="${label}">(${p[0].toUpperCase()})</span>`;
        }).join('');
    // Due GRUPPI dentro la fila, non icone tutte in fila: spec (+ wildcard) e professioni.
    // Serve a spaziarli in modo diverso — largo fra i due gruppi, stretto dentro — e a farli
    // andare a capo interi invece di spezzare le professioni. Il gruppo vuoto non si emette,
    // altrimenti il suo gap resterebbe come un buco.
    const grp = (inner: string) => (inner ? `<span class="ig">${inner}</span>` : '');
    const icons = grp(tail) + grp(profTail);
    const pgClass = todo ? ' pg--todo' : wip ? ' pg--wip' : '';
    // La fila icone si emette SEMPRE, anche vuota: le riserva l'altezza il CSS (min-height),
    // cosi' le icone di tutti i PG di una riga stanno sulla stessa linea. Emettendola solo
    // quando c'e' qualcosa, un PG senza spec ne' professioni restava piu' corto dei vicini
    // e la fila di icone della cella accanto si disallineava.
    return `<span class="pg${pgClass}"><span class="pg-name"${nameAttr}>${escHtml(name)}</span><span class="pg-icons">${icons}</span></span>`;
  });
  // Piu' PG nella stessa cella: NON piu' separati da <br> (che li impilava e basta, senza far
  // vedere dove finiva l'uno e cominciava l'altro) ma avvolti in `.pg-multi`, che il CSS
  // divide con un filetto orizzontale da bordo a bordo della casella. Con un solo PG resta
  // esattamente il markup di prima: niente contenitore in piu' su 50 celle su 52.
  const parts = out.filter((s) => s.trim());
  if (parts.length > 1) return `<span class="pg-multi">${parts.join('')}</span>`;
  return parts.join('');
}

const stripRealm = (cell: string): string => cell.replace(/·[A-Z]/g, '');

// PG reali in una cella: stessa regola del contatore totale (getPgCount).
// Esclude i pianificati "*" (non ancora creati), include i "_" in leveling; X/vuoto = 0.
function cellCount(cell: string): number {
  const t = stripRealm(cell).trim();
  if (!t || t === 'X') return 0;
  return t.split(/<br\s*\/?>/i).map((s) => s.trim()).filter((s) => s && !s.startsWith('*')).length;
}

// Estrae le righe (array di celle) della tabella markdown sotto "## <section>".
function extractPgTable(raw: string, section: string): string[][] | null {
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
function pgBodyRows(rows: string[][], rowClass: string, header: string[]): { html: string; races: Set<string>; colCounts: number[] } {
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

// Righe di CORPO della matrice PG (Orda + Alleanza), deduplicate ESATTAMENTE come le
// rende getPgHtml: le razze condivise (Pandaren/Dracthyr/Earthen/Haranir), che il
// renderer tiene solo nel blocco Orda, non si ricontano in Alleanza. Fonte unica per
// getPgCount e getClassStats, cosi' i totali non possono divergere da cio' che la
// tabella mostra davvero (prima li contavano entrambi senza dedup → sovracount latente).
let _pgTables: { header: string[]; rows: string[][] } | null | undefined;
function pgTables(): { header: string[]; rows: string[][] } | null {
  if (_pgTables !== undefined) return _pgTables;
  const raw = Object.values(pgFile)[0] ?? '';
  const orda = extractPgTable(raw, 'Orda');
  if (!orda) return (_pgTables = null);
  const header = orda[0];
  const hordeRows = orda.slice(1);
  const races = new Set(hordeRows.map((c) => stripRealm(c[0] ?? '').trim()));
  const ally = extractPgTable(raw, 'Alleanza');
  const allyRows = ally
    ? ally.slice(1).filter((c) => !races.has(stripRealm(c[0] ?? '').trim()))
    : [];
  return (_pgTables = { header, rows: [...hordeRows, ...allyRows] });
}

// Conta i PG presenti nella tabella (Orda + Alleanza), inclusi i nomi multipli per cella.
let _pgCount: number | null = null;
export function getPgCount(): number {
  if (_pgCount !== null) return _pgCount;
  const t = pgTables();
  let count = 0;
  if (t)
    for (const cells of t.rows)
      // Stessa regola per cella di `cellCount` (X/vuoto = 0, "*" pianificati esclusi):
      // una sola fonte, cosi' il totale e i per-cella non possono divergere.
      for (let i = 1; i < cells.length; i++) count += cellCount(cells[i] ?? '');
  return (_pgCount = count);
}

// ── Screenshot UI ─────────────────────────────────
// Quanti screenshot ha la pagina /ui. Serve alla card della home, che fino al
// 2026-07-20 portava il numero scritto a mano e andava ritoccato a ogni file
// aggiunto o tolto.
// ⚠️ Il filtro `.webp` fa anche il lavoro che nel glob faceva lo slash: `readdirSync`
// elenca anche la sottocartella `thumb/`, che pero' `.webp` non e' — quindi le miniature
// restano fuori dal conto, come prima. Se un giorno si mettessero miniature in radice,
// il numero raddoppierebbe.
const screenshots = (): string[] => [...filesIn('screenshots')].filter((f) => f.endsWith('.webp'));
export function getScreenshotCount(): number {
  return screenshots().length;
}

// ── Stats per classe (matrice della home) ─────────
// Aggrega in una riga per classe le metriche per-classe che il repo gia' conosce:
// quante macro, quanti PG, quanti screenshot, e il completamento transmog.
// Tutte e 13 le classi sempre presenti, anche a zero, cosi' la matrice e' completa e
// stabile. Le fonti sono le stesse delle rispettive pagine: nessun conteggio nuovo da
// mantenere a mano, si allinea da se' quando cambi il dato sottostante.
export interface ClassStat {
  slug: string;                 // dashed (death-knight), come le chiavi di `collected`
  label: string;
  icon: string;
  macros: number;
  pg: number;
  shots: number;
  tmogGot: number;
  tmogTotal: number;
  tmogPct: number;              // 0..100
}

// icona-slug senza trattino (CLASS_ABBR, prefisso dei filename screenshot) -> slug dashed
const toDashedSlug = (s: string): string =>
  ({ deathknight: 'death-knight', demonhunter: 'demon-hunter' } as Record<string, string>)[s] ?? s;

export function getClassStats(): ClassStat[] {
  const slugs = Object.keys(CLASS_LABELS); // 13 classi canoniche

  // Macro: il campo `class` del manifest e' gia' lo slug dashed.
  const macroBy: Record<string, number> = {};
  for (const m of getMacros()) if (m.class) macroBy[m.class] = (macroBy[m.class] ?? 0) + 1;

  // PG: somma per colonna-classe su Orda + Alleanza. L'header porta le abbreviazioni
  // (War, Pal, ...) -> slug via CLASS_ABBR, con la stessa `cellCount` del totale PG,
  // cosi' i per-classe non possono divergere dal conteggio complessivo.
  const pgBy: Record<string, number> = {};
  const pgt = pgTables();
  if (pgt) {
    for (const cells of pgt.rows) {
      for (let j = 1; j < pgt.header.length; j++) {
        const iconSlug = CLASS_ABBR[(pgt.header[j] ?? '').trim()]?.[0];
        if (!iconSlug) continue;
        const slug = toDashedSlug(iconSlug);
        pgBy[slug] = (pgBy[slug] ?? 0) + cellCount(cells[j] ?? '');
      }
    }
  }

  // Screenshot: la classe e' il prefisso del filename (<classe>-<spec>-<nome>.jpg).
  const shotsBy: Record<string, number> = {};
  for (const nome of screenshots()) {
    const prefix = nome.split('-')[0];
    const slug = toDashedSlug(prefix);
    if (slug in CLASS_LABELS) shotsBy[slug] = (shotsBy[slug] ?? 0) + 1;
  }

  // Transmog: got/total per classe gia' calcolati da getTransmog (chiavi dashed).
  const tmogBy: Record<string, { got: number; total: number }> = {};
  for (const c of getTransmog()) tmogBy[c.slug] = { got: c.got, total: c.total };

  return slugs
    .map((slug): ClassStat => {
      const t = tmogBy[slug] ?? { got: 0, total: 0 };
      return {
        slug,
        label: classLabel(slug),
        icon: `/icons/class/${slug.replace(/-/g, '')}.jpg`,
        macros: macroBy[slug] ?? 0,
        pg: pgBy[slug] ?? 0,
        shots: shotsBy[slug] ?? 0,
        tmogGot: t.got,
        tmogTotal: t.total,
        tmogPct: t.total ? Math.round((t.got / t.total) * 100) : 0,
      };
    })
    .sort((a, b) => a.label.localeCompare(b.label, 'it'));
}

export function getPgHtml(): string {
  const raw = Object.values(pgFile)[0] ?? '';
  const orda = extractPgTable(raw, 'Orda');
  if (!orda) return '<p>Tabella PG non trovata.</p>';
  const header = orda[0];
  const ncols = header.length;

  const band = (text: string, cls: string) => `<tr class="rsep ${cls}"><td colspan="${ncols}">${text}</td></tr>`;
  const horde = pgBodyRows(orda.slice(1), 'fac-horde', header);

  // Totali per classe (colonna): partono dall'Orda, poi sommo l'Alleanza.
  const colTotals = horde.colCounts.slice();

  let allyHtml = '';
  const ally = extractPgTable(raw, 'Alleanza');
  if (ally) {
    // Razze condivise (già nel blocco Orda) restano solo lì: qui le saltiamo.
    const allyRows = ally.slice(1).filter((cells) => !horde.races.has(stripRealm(cells[0]).trim()));
    if (allyRows.length) {
      const allyBody = pgBodyRows(allyRows, 'fac-alliance', header);
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

  const caption = '<caption class="sr-only">Matrice razza × classe — PG per combinazione (Orda e Alleanza)</caption>';
  return `<div class="table-scroll"><table>${caption}${thead}<tbody>${body}</tbody></table></div>`;
}
