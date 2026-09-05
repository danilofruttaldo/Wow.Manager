// Personaggio -> spec. Chiave = nome PG in minuscolo.
// Nella tabella PG mostriamo la PRIMA LETTERA della spec fra parentesi accanto al nome.
// Fonte iniziale: i 7 screenshot (filename classe-spec-nome). Il resto lo compila l'utente.
export const CHAR_SPEC: Record<string, string> = {
  stantu: '*', // wildcard NUDA: gioca tutte le spec Warrior, nessuna preferita -> sola icona wildcard
  furricane: 'brewmaster', // fallback; vedi CHAR_SPEC_BY_RACE per la disambiguazione
  snowwipe: 'arcane',      // era 'frost' fino al 2026-09-01: cambio confermato dall'utente.
                           // Il buco che lasciava (mage-frost muta) l'ha chiuso spelling il
                           // 2026-09-05: ora i mage sono arcane2 (con spellstill), fire2
                           // (repository, blinkette), frost1 (spelling).
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
  spelling: 'frost',           // era 'arcane' fino al 2026-09-05: copre la casella mage-frost,
                               // muta da quando snowwipe e' passata ad arcane
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
  dayandknight: 'unholy',     // evita doppione con furricane (frost). Da Night Elf a Lightforged
                              // Draenei il 2026-09-05: "day and knight" e' ora la Luce (draenei
                              // forgiato) e la non-morte nello stesso PG
  dwarfenstein: 'blood',      // spec attiva nei dati di gioco (250=blood); completa il trio DK Alleanza
  demongear: 'vengeance',     // "demon…gear" → tank demoniaco
  blinkette: 'fire',          // gnomo = esplosivi/tinker → Fire (con repository)
  hadruidken: 'balance',      // "hadouken" → colpo a distanza
  totemizer: 'enhancement',   // spec attiva in gioco
  periodrage: 'fury',         // "rage" → ira
  demonstrate: 'havoc',       // tema demoniaco, DPS melee
  proctolodin: 'holy',        // Nano Pal recuperato — proctologo → medico/cura
  totemptation: 'restoration',// ex Foxlust (Vulpera ele), cambio fazione+razza il 2026-09-05.
                              // Resto era l'unica spec sciamano in minoranza (1 su 7 con pandacoil):
                              // ora ele2/enh3/resto2, e l'Alleanza ha un trio ele/enh/resto completo
                              // (shockolat, totemizer, questo). Il nome vecchio era un pun su
                              // Bloodlust, che sull'Alleanza si chiama Heroism.

  // ── PARCHEGGIATE: nomi che oggi NON sono in pg.md ────────────────────────────────
  // ⚠️ Una parcheggiata vale finche' la sua casella e' libera: `naaruto` (Draenei Sha
  // resto) e' stata tolta il 2026-09-05 perche' Totemptation ha preso quella casella con
  // quella stessa spec, quindi non era piu' riproponibile. Non e' la regola generale:
  // `preservative` e `augmentin` mirano a Dracthyr Evo, dove Dragoncelloh c'e' gia' ma
  // con un'altra spec — e una cella regge piu' PG (`<br>`), quindi restano valide.
  // Le 17 righe qui sotto sono PG pianificati e mai creati, tolti dalla tabella il
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
