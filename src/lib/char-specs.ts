// Personaggio -> spec. Chiave = nome PG in minuscolo.
// Nella tabella PG mostriamo la PRIMA LETTERA della spec fra parentesi accanto al nome.
// Fonte iniziale: i 7 screenshot (filename classe-spec-nome). Il resto lo compila l'utente.
export const CHAR_SPEC: Record<string, string> = {
  stantu: '*', // wildcard NUDA: gioca tutte le spec Warrior, nessuna preferita -> sola icona wildcard
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
  blinkette: 'fire',          // gnomo = esplosivi/tinker → Fire; evita doppione con spellstill (arcane)
  hadruidken: 'balance',      // "hadouken" → colpo a distanza
  totemizer: 'enhancement',   // spec attiva in gioco
  periodrage: 'fury',         // "rage" → ira
  demonstrate: 'havoc',       // tema demoniaco, DPS melee
  proctolodin: 'holy',        // Nano Pal recuperato — proctologo → medico/cura

  // ── PARCHEGGIATE: nomi che oggi NON sono in pg.md ────────────────────────────────
  // Le 18 righe qui sotto sono PG pianificati e mai creati, tolti dalla tabella il
  // 2026-08-04 («PG: rimossi i 19 pianificati») insieme alla decisione — scritta in quel
  // commit — di tenere la convenzione `*nome` in legenda **per reintrodurli**. Le spec
  // restano quindi apposta: sono scelte già fatte, e riscrivendo un `*Nome` in pg.md la
  // sua icona ricompare senza doverle ripensare.
  //
  // ⚠️ Non sono un residuo da ripulire, ma non sono nemmeno «da fare»: erano etichettate
  // TODO e questa parola le faceva sembrare righe vive della tabella. A runtime sono
  // inerti — `annotateSpec` cerca solo i nomi che pg.md contiene davvero — quindi l'unico
  // costo era il malinteso.
  //
  // Il criterio con cui furono scelte, per chi le riprende in mano: riempivano le classi a
  // scelta di razza limitata (Pal/Sha/Dru) bilanciando le spec in minoranza — Pal
  // holy3/prot2/ret3, Sha enh5/ele5/resto5, Dru balance2/feral2/guardian2/resto2 — più le
  // spec allora scoperte fra tutti i PG (Monk/Evoker).
  backstabbath: 'subtlety',    // Haranir Rog — razza poco usata; completava il trio rogue Orda
  hammertime: 'retribution',   // Human Pal — "Hammertime" (Hammer of Wrath, ret)
  holytoledo: 'holy',          // Draenei Pal — "Holy Toledo!" (holy)
  verdictorian: 'retribution', // Lightforged Pal — valedictorian → Templar's Verdict (ret)
  voodoochild: 'restoration',  // Troll Sha — voodoo/witch-doctor troll, guaritore (resto)
  voltron: 'elemental',        // Goblin Sha — volt = fulmini (ele)
  stormsaurus: 'enhancement',  // Zandalari Sha — dino + Stormstrike (enh)
  rainmaker: 'restoration',    // Highmountain Sha — Healing Rain (resto)
  stonestrike: 'enhancement',  // Earthen Sha — Stormstrike + pietra=Earthen (enh)
  chlorophil: 'restoration',   // Haranir Sha — natura/foglie (resto)
  naaruto: 'restoration',      // Draenei Sha — Naaru = esseri di Luce; portava gli sciamani a 5/5/5
  lavalamp: 'elemental',       // Dark Iron Sha — Lava Burst + Dark Iron (ele)
  bloomanjaro: 'restoration',  // Troll Dru — Kilimanjaro → Lifebloom (resto)
  furocious: 'feral',          // Worgen Dru — ferocious/fur = feral
  bearnacle: 'guardian',       // Kul Tiran Dru — bear=guardian + barnacle=mare
  mistfits: 'mistweaver',      // Mechagnome Mon — Misfits → mistweaver; razza in minoranza
  preservative: 'preservation',// Dracthyr Evo — "preservative" contiene preservation
  augmentin: 'augmentation',   // Dracthyr Evo — brand → augmentation
};

// Disambiguazione per PG omonimi: chiave `nome|razza` (minuscolo). Ha precedenza su CHAR_SPEC.
export const CHAR_SPEC_BY_RACE: Record<string, string> = {
  'furricane|vulpera': 'brewmaster', // Orda — Monk
  'furricane|worgen': 'frost',       // Alleanza — Death Knight
};
