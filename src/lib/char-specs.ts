// Personaggio -> spec. Chiave = nome PG in minuscolo.
// Nella tabella PG mostriamo la PRIMA LETTERA della spec fra parentesi accanto al nome.
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
  foxlust: 'elemental',   // Vulpera: flavor volpe/fuoco; evita il 3° enhancement Orda
  tearsforfear: 'destruction', // Goblin: esplosivi/caos; completa la varietà stregoni Orda
  backstabbath: 'subtlety',    // TODO (Haranir, da creare): razza poco usata; completa il trio rogue Orda
  // Alleanza (nuovi PG). Spec note; il resto è '?' finché non confermate.
  spellstill: 'arcane',
  gnomorrage: 'assassination',
  dwarfnought: 'arms',        // "dreadnought" → arma pesante a 2 mani
  ipelf: 'windwalker',
  discoteque: 'discipline',
  holytude: 'holy',           // "holy" nel nome
  shockolat: 'elemental',     // "shock" → shock elementali
  dotnetcore: 'affliction',   // "dot" → DoT
  vanillidan: 'devourer',     // Void Elf → spec Void (Midnight); niente doppione havoc
  tinytank: 'protection',     // "tank"
  plateatico: 'protection',   // "plate" → tank in piastra
  shottini: 'beastmastery',
  dayandknight: 'unholy',     // "knight" notturno/oscuro; evita doppione con furricane (frost)
  dwarfenstein: 'blood',      // spec attiva nei dati di gioco (250=blood); completa il trio DK Alleanza
  demongear: 'vengeance',     // "demon…gear" → tank demoniaco
  proctolodin: 'holy',        // proctologo → medico/cura
  blinkette: 'fire',          // gnomo = esplosivi/tinker → Fire; evita doppione con spellstill (arcane)
  hadruidken: 'balance',      // "hadouken" → colpo a distanza
  totemizer: 'restoration',   // "totem" → totem di cura
  periodrage: 'fury',         // "rage" → ira
  demonstrate: 'havoc',       // tema demoniaco, DPS melee
  // TODO — PG pianificati (da creare) per riempire le classi a scelta di razza limitata
  // (Pal/Sha/Dru). Spec scelte per bilanciare le minoranze: Pal holy3/prot2/ret3,
  // Sha enh5/ele5/resto5, Dru balance2/feral2/guardian2/resto2.
  hammertime: 'retribution',   // TODO Human Pal — "Hammertime" (Hammer of Wrath, ret)
  holytoledo: 'holy',          // TODO Draenei Pal — "Holy Toledo!" (holy)
  verdictorian: 'retribution', // TODO Lightforged Pal — valedictorian → Templar's Verdict (ret)
  voodoochild: 'restoration',  // TODO Troll Sha — voodoo/witch-doctor troll, guaritore (resto)
  voltron: 'elemental',        // TODO Goblin Sha — volt = fulmini (ele)
  stormsaurus: 'enhancement',  // TODO Zandalari Sha — dino + Stormstrike (enh)
  rainmaker: 'restoration',    // TODO Highmountain Sha — Healing Rain (resto)
  stonestrike: 'enhancement',  // TODO Earthen Sha — Stormstrike + pietra=Earthen (enh)
  chlorophil: 'restoration',   // TODO Haranir Sha — natura/foglie (resto)
  naaruto: 'enhancement',      // TODO Draenei Sha — Naruto→Naaru, mischia (enh)
  lavalamp: 'elemental',       // TODO Dark Iron Sha — Lava Burst + Dark Iron (ele)
  bloomanjaro: 'restoration',  // TODO Troll Dru — Kilimanjaro → Lifebloom (resto)
  furocious: 'feral',          // TODO Worgen Dru — ferocious/fur = feral
  bearnacle: 'guardian',       // TODO Kul Tiran Dru — bear=guardian + barnacle=mare
  // TODO — spec ancora scoperte tra tutti i PG (Monk/Evoker non erano tra le classi limitate).
  mistfits: 'mistweaver',      // TODO Mechagnome Mon — Misfits → mistweaver; razza in minoranza
  preservative: 'preservation',// TODO Dracthyr Evo — "preservative" contiene preservation
  augmentin: 'augmentation',   // TODO Dracthyr Evo — brand → augmentation
};

// Disambiguazione per PG omonimi: chiave `nome|razza` (minuscolo). Ha precedenza su CHAR_SPEC.
export const CHAR_SPEC_BY_RACE: Record<string, string> = {
  'furricane|vulpera': 'brewmaster', // Orda — Monk
  'furricane|worgen': 'frost',       // Alleanza — Death Knight
};
