// Personaggio -> spec. Chiave = nome PG in minuscolo.
// Nel roster mostriamo la PRIMA LETTERA della spec fra parentesi accanto al nome.
// Fonte iniziale: i 7 screenshot (filename classe-spec-nome). Il resto lo compila l'utente.
export const CHAR_SPEC: Record<string, string> = {
  stantu: 'arms*', // wildcard: gioca tutte le spec Warrior
  furricane: 'brewmaster', // fallback; vedi CHAR_SPEC_BY_RACE per la disambiguazione
  snowwipe: 'frost',
  mustaina: 'feral',
  blessismore: 'protection',
  totemtanz: 'elemental',
  dotandroll: 'affliction',
  dragoncelloh: 'devastation',
  ecoterrorist: 'guardian',
  menagerie: 'demonology',
  cereanor: 'assassination',
  undeadpool: 'outlaw',
  axetomouth: 'fury',
  cowadin: 'holy',
  divinetroll: 'retribution',
  arconauta: 'beastmastery',
  pandacoil: 'restoration',
  repository: 'fire',
  spelling: 'arcane',
  illidanielle: 'devourer',
  rotandroll: 'unholy',
  trollminator: 'blood',
  moneystrike: 'frost',
  orconauta: 'survival',
  rockbiter: 'marksmanship',
  pretaporter: 'shadow',
  nightform: 'holy',
  shockandroll: 'enhancement',
  blondelust: 'enhancement',
  windwasher: 'windwalker',
  catatonic: 'balance',
  shiftzord: 'restoration',
  demoversion: 'vengeance',
  // Alleanza (nuovi PG). Spec note; il resto è '?' finché non confermate.
  spellstill: 'arcane',
  gnomorrage: 'assassination',
  dwarfnought: 'protection',
  ipelf: 'windwalker',
  discoteque: 'discipline',
  holytude: '?',
  shockolat: '?',
  dotnetcore: '?',
  vanillidan: '?',
  tinytank: '?',
  plateatico: '?',
  shottini: '?',
  dayandknight: '?',
  demongear: '?',
  proctolodin: '?',
  blinkette: '?',
  hadruidken: '?',
  totemizer: '?',
  periodrage: '?',
  demonstrate: '?',
};

// Disambiguazione per PG omonimi: chiave `nome|razza` (minuscolo). Ha precedenza su CHAR_SPEC.
export const CHAR_SPEC_BY_RACE: Record<string, string> = {
  'furricane|vulpera': 'brewmaster', // Orda — Monk
  'furricane|worgen': 'frost',       // Alleanza — Death Knight
};
