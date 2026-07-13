// Accesso ai dati della repo Wow.Manager (manifest JSON + markdown).
// I file vivono fuori da src/: sono la fonte di verità, il sito li legge in sola lettura.
import { execSync } from 'node:child_process';
import { marked } from 'marked';

import { CHAR_SPEC, CHAR_SPEC_BY_RACE } from './char-specs';

import addonsManifest from '../../addons/manifest.json';
import macrosManifest from '../../macros/manifest.json';
import fontsManifest from '../../fonts/manifest.json';
import professionsManifest from '../../professions/manifest.json';

marked.setOptions({ gfm: true, breaks: false });

// ── Tipi ──────────────────────────────────────────
export interface Addon {
  key: string;
  name: string;
  version: string;
  interface: string;
  source: string;
  url?: string;
  installed?: string;
  folders: string[];
  notes?: string;
}

export interface Macro {
  key: string;
  name: string;
  scope: string;
  class: string | null;
  spec: string | null;
  character: string | null;
  slot: string | null;
  icon: string | null;
  notes?: string;
}

export interface ProfStep {
  spec: string;   // specializzazione da prendere
  branch: string; // ramo da maxare dentro quella spec
}
export interface Profession {
  key: string;
  name: string;
  type: 'crafting' | 'gathering' | 'secondary';
  first: ProfStep | null;  // 1ª spec + 1º ramo
  second: ProfStep | null; // 2ª spec + 2º ramo
  notes?: string;
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
export function getAddons(): Addon[] {
  const raw = (addonsManifest as any).addons ?? {};
  return Object.entries(raw)
    .map(([key, v]: [string, any]) => ({ key, folders: [], ...v }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

// ── Macro ─────────────────────────────────────────
export const macrosMeta = (macrosManifest as any)._meta;
export function getMacros(): Macro[] {
  const raw = (macrosManifest as any).macros ?? {};
  return Object.entries(raw)
    .map(([key, v]: [string, any]) => ({ key, ...v }))
    .sort((a, b) => (a.class ?? '').localeCompare(b.class ?? '') || a.name.localeCompare(b.name));
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

// Accanto a ogni nome PG mette la prima lettera della spec fra parentesi, se nota.
// Disambigua i PG omonimi via `nome|razza` (CHAR_SPEC_BY_RACE), altrimenti CHAR_SPEC.
// Una cella può contenere più nomi separati da <br>.
function annotateSpec(cell: string, race: string): string {
  const out = cell.split(/<br\s*\/?>/i).map((seg) => {
    const name = seg.trim();
    if (!name) return seg;
    const spec = CHAR_SPEC_BY_RACE[`${name}|${race}`.toLowerCase()] ?? CHAR_SPEC[name.toLowerCase()];
    return spec ? `${name} (${spec[0].toUpperCase()})` : name;
  });
  return ` ${out.join('<br>')} `;
}

const stripRealm = (cell: string): string => cell.replace(/·[A-Z]/g, '');

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

// Costruisce le <tr> del corpo: icona razza in prima colonna, casella scura per X, spec fra parentesi.
function rosterBodyRows(rows: string[][], rowClass: string): { html: string; races: Set<string> } {
  const races = new Set<string>();
  const html = rows.map((cells) => {
    const race = stripRealm(cells[0] ?? '').trim();
    const tds = cells.map((cell, i) => {
      const t = stripRealm(cell).trim();
      if (i === 0) {
        races.add(t);
        return `<td class="rhead">${t in RACE_ICON ? raceIcon(t) : t}</td>`;
      }
      if (t === 'X') return '<td><span class="na" title="Combinazione non creabile in gioco"></span></td>';
      if (t === '') return '<td></td>';
      return `<td>${annotateSpec(stripRealm(cell), race)}</td>`;
    }).join('');
    return `<tr class="${rowClass}">${tds}</tr>`;
  }).join('');
  return { html, races };
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
        count += t.split(/<br\s*\/?>/i).map((s) => s.trim()).filter(Boolean).length;
      }
    }
  }
  return count;
}

export function getRosterHtml(): string {
  const raw = Object.values(rosterFile)[0] ?? '';
  const orda = extractRosterTable(raw, 'Orda');
  if (!orda) return '<p>Roster non trovato.</p>';
  const header = orda[0];
  const ncols = header.length;

  const thead = '<thead><tr>' + header.map((c, i) =>
    i === 0 ? '<th></th>' : `<th>${CLASS_ABBR[c.trim()] ? classIcon(c.trim()) : c.trim()}</th>`,
  ).join('') + '</tr></thead>';

  const band = (text: string, cls: string) => `<tr class="rsep ${cls}"><td colspan="${ncols}">${text}</td></tr>`;
  const horde = rosterBodyRows(orda.slice(1), 'fac-horde');
  let body = band('Orda', 'rsep--horde') + horde.html;

  const ally = extractRosterTable(raw, 'Alleanza');
  if (ally) {
    // Razze condivise (già nel blocco Orda) restano solo lì: qui le saltiamo.
    const allyRows = ally.slice(1).filter((cells) => !horde.races.has(stripRealm(cells[0]).trim()));
    if (allyRows.length) body += band('Alleanza', 'rsep--alliance') + rosterBodyRows(allyRows, 'fac-alliance').html;
  }

  return `<div class="table-scroll"><table>${thead}<tbody>${body}</tbody></table></div>`;
}
