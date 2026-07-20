-- WowManagerTierDump - addon locale, NON un addon pubblico.
-- Legge dal journal transmog del gioco (C_TransmogSets) quanti pezzi di ogni
-- tier set / class set sono collezionati sull'account (Warband) e genera il
-- blocco `collected` di transmog/manifest.json, gia' pronto da incollare.
--
-- Installazione: copia questo file in
--   _retail_/Interface/AddOns/WowManagerTierDump/WowManagerTierDump.lua
-- con accanto un WowManagerTierDump.toc:
--   ## Interface: 120007
--   ## Title: WowManager Tier Dump
--   ## SavedVariables: WowManagerTierDumpDB
--   WowManagerTierDump.lua
-- Un addon nuovo richiede il RIAVVIO del client (il /reload non lo vede).
--
-- Uso: /wmtier (o aspetta il login), poi /reload o logout per scrivere
--   WTF/Account/<ACC>/SavedVariables/WowManagerTierDump.lua
-- Da li' copia DUE campi dentro il manifest:
--   ["collectedJson"] -> blocco `collected`  (pezzi posseduti / totali)
--   ["piecesJson"]    -> blocco `pieceList`  (tutti i pezzi, presi e mancanti)

local CLASSES = {
    [1] = "warrior", [2] = "paladin", [3] = "hunter", [4] = "rogue", [5] = "priest",
    [6] = "death-knight", [7] = "shaman", [8] = "mage", [9] = "warlock", [10] = "monk",
    [11] = "druid", [12] = "demon-hunter", [13] = "evoker",
}
local CLASS_ORDER = { "warrior", "paladin", "hunter", "rogue", "priest", "death-knight",
    "shaman", "mage", "warlock", "monk", "druid", "demon-hunter", "evoker" }

-- expansionID .. "|" .. label (il raid, come lo chiama il gioco) -> chiave tier del manifest
local TIER = {
    ["0|Molten Core"] = "t1", ["0|Blackwing Lair"] = "t2",
    ["0|Temple of Ahn'Qiraj"] = "t25", ["0|Naxxramas"] = "t3",
    ["1|Gruul's Lair"] = "t4", ["1|Serpentshrine Cavern"] = "t5",
    ["1|Black Temple"] = "t6", ["1|Sunwell Plateau"] = "t6-swp",
    ["2|Naxxramas"] = "t7", ["2|Ulduar"] = "t8",
    ["2|Trial of the Crusader"] = "t9", ["2|Icecrown Citadel"] = "t10",
    ["3|The Bastion of Twilight"] = "t11", ["3|Firelands"] = "t12",
    ["3|Dragon Soul"] = "t13", ["4|Heart of Fear"] = "t14",
    ["4|Throne of Thunder"] = "t15", ["4|Siege of Orgrimmar"] = "t16",
    ["5|Blackrock Foundry"] = "t17", ["5|Hellfire Citadel"] = "t18",
    ["6|The Nighthold"] = "t19", ["6|Tomb of Sargeras"] = "t20",
    ["6|Antorus, the Burning Throne"] = "t21",
    ["8|Sepulcher of the First Ones"] = "t28",
    ["9|Vault of the Incarnates"] = "t29", ["9|Aberrus, the Shadowed Crucible"] = "t30",
    ["9|Amirdrassil, the Dream's Hope"] = "t31",
    ["10|Nerub-ar Palace"] = "t32", ["10|Liberation of Undermine"] = "t33",
    ["10|Manaforge Omega"] = "t34", ["11|The Voidspire"] = "t35",
    -- Righe senza asse di difficolta': un set solo per classe.
    ["6|Legion Order Hall"] = "ohall",
    ["4|Pandaria Challenge Dungeons"] = "challenge",
}

-- Set per TIPO DI ARMATURA: uno solo per stoffa/cuoio/maglia/piastre, condiviso da
-- tutte le classi che portano quel tipo. Si riconoscono dal classMask con piu' bit
-- accesi -- 400 stoffa, 3592 cuoio, 4164 maglia, 35 piastre -- e vanno su una riga
-- loro, distinta da quella dei set di classe dello stesso raid.
--
-- ⚠️ Per questo la mappa e' separata da TIER invece di stare li' dentro: Hellfire
-- Citadel compare in tutte e due. Le difficolta' normali danno il tier di classe
-- (t18), il solo Raid Finder da' il set condiviso (hfc-lfr), perche' in WoD in LFR
-- il tier di classe non esisteva. Con una mappa sola le quattro varianti LFR
-- finivano su t18 e venivano buttate come "multiclasse".
local TIER_ARMOR = {
    ["5|Hellfire Citadel"] = "hfc-lfr", ["6|Trial of Valor"] = "tov",
    ["7|Uldir"] = "uldir", ["7|Battle of Dazar'alor"] = "bod",
    ["7|The Eternal Palace"] = "tep", ["7|Ny'alotha, the Waking City"] = "nya",
    ["8|Castle Nathria"] = "nathria", ["8|Sanctum of Domination"] = "sod",
}

-- Ordine dei tier nel manifest (serve solo a rendere l'output ordinato).
local TIER_ORDER = { "t0", "t05", "t1", "t2", "t25", "t3", "t4", "t5", "t6", "t6-swp", "t7", "t8",
    "t9", "t10", "t11", "t12", "t13", "t14", "t15", "t16", "challenge", "t17", "t18",
    "hfc-lfr", "ohall", "tov", "t19", "t20", "t21", "uldir", "bod", "tep", "nya", "nathria",
    "sod", "t28", "t29", "t30", "t31", "t32", "t33", "t34", "t35" }

-- Righe senza asse: il gioco non da' `description` (l'Order Hall e i set delle
-- Challenge Mode di Pandaria sono uno solo per classe), quindi lo slot non si puo'
-- dedurre da li' e si dichiara qui. Senza questo finivano in dropped come
-- "slot ignoto nil" e la riga restava vuota.
local SLOT_UNICO = { ohall = "normal", challenge = "normal", ["t6-swp"] = "normal" }

-- Le classi accese in un classMask. Per un set di classe e' una sola; per un set per
-- tipo di armatura sono tutte quelle che lo portano, ed e' li' che serve: lo stesso
-- set va scritto sotto ognuna, altrimenti la riga resta vuota per tutti.
local function ClassiIn(mask)
    local out = {}
    for i = 1, 13 do
        if bit.band(mask or 0, bit.lshift(1, i - 1)) ~= 0 then out[#out + 1] = CLASSES[i] end
    end
    return out
end

-- description in-game -> slot colonna. Le 4 colonne sono SLOT, non difficolta'
-- letterali: prima di Cataclysm l'asse era 10/25 uomini o la fazione.
local SLOT = {
    ["Raid Finder"] = "lfr", ["Normal"] = "normal", ["Heroic"] = "heroic", ["Mythic"] = "mythic",
    ["10 Player (Normal)"] = "normal", ["25 Player (Normal)"] = "heroic",
    ["25 Player (Heroic)"] = "mythic", ["Sunwell"] = "heroic",
}
local FACTION_SLOT = { Alliance = "normal", Horde = "heroic" }   -- T9: l'asse e' la fazione
local IGNORE = { Timerunning = true, Timewarped = true, ["Trading Post"] = true }
local SLOT_ORDER = { "lfr", "normal", "heroic", "mythic" }

local function CountSet(setID)
    local have, total = 0, 0
    local apps = C_TransmogSets.GetSetPrimaryAppearances(setID)
    if apps then
        for _, a in ipairs(apps) do
            total = total + 1
            if a.collected then have = have + 1 end
        end
    end
    return have, total
end

-- invType -> nome dello slot, per l'elenco dei pezzi mancanti.
-- GetSourceInfo restituisce `invType` NUMERICO, mai la stringa INVTYPE_*.
-- ATTENZIONE alla numerazione: l'invType di GetSourceInfo e' spostato di +1 rispetto
-- alla numerazione classica (Testa = 2, non 1). Verificato sui dati reali: il T9
-- warrior usa {2,4,6,7,8,9,10,11}, che con questa mappa sono esattamente gli 8 slot
-- del tier; con la numerazione classica uscivano "Anello", "Collo", "Maglietta".
-- Nomi in INGLESE come li scrive il client, stessa convenzione delle professioni.
local SLOT_NAME = {
    [2] = "Head", [3] = "Neck", [4] = "Shoulder", [5] = "Shirt", [6] = "Chest",
    [7] = "Waist", [8] = "Legs", [9] = "Feet", [10] = "Wrist", [11] = "Hands",
    [12] = "Finger", [13] = "Trinket", [17] = "Back", [20] = "Tabard", [21] = "Chest",
    -- Alcuni set (soprattutto Legion in poi) includono armi.
    [14] = "Weapon", [15] = "Shield", [16] = "Ranged", [18] = "Two-Hand",
    [19] = "Bag", [22] = "Main Hand", [23] = "Off Hand", [24] = "Held In Off-hand",
    [25] = "Ammo", [26] = "Thrown", [27] = "Ranged", [28] = "Quiver", [29] = "Relic",
}

-- Dal T28 il pezzo di classe non cade: dal boss cade un TOKEN che lo crea. Le API di
-- transmog non conoscono quel legame, e il fallback per visualID (vedi PiecesIn)
-- risponde col boss di un'altra source della stessa famiglia visuale: plausibile e
-- sbagliato. Misurato su Manaforge Omega, sulle 84 voci che un boss ce l'avevano: 64
-- indicavano un altro boss dello stesso raid, 4 un world boss di un'altra zona
-- (Reshanor), e nessuna il boss che droppa davvero quel token. Le 16 buone
-- nominavano l'ultimo boss, ma per caso: droppa un omni-token valido per ogni slot.
--
-- Quindi per i 5 slot da token di questi tier il boss NON si chiede al gioco, si
-- legge da qui. La struttura reale e' semplice: un boss droppa il token di UNO slot
-- per tutte le classi -- i quattro tipi (Dreadful/Mystic/Venerated/Zenith) cadono
-- dallo stesso boss -- quindi bastano cinque righe per raid.
--
-- ⚠️ Gli altri slot del set (Back, Feet, Waist, Wrist) NON sono token: quelli cadono
-- davvero dal boss, il gioco li sa e vanno lasciati stare. Per questo l'override e'
-- limitato ai cinque slot elencati e non all'intero set.
--
-- Non e' registrato l'omni-token dell'ultimo boss (Sarkareth, Fyrakk, Gallywix,
-- Ansurek, Dimensius, Midnight Falls...), che vale per qualunque slot: la voce
-- mostra un boss solo, e quello specifico dello slot e' la risposta utile a chi
-- deve farmare. Nemmeno i primi boss di ogni raid, che token non ne droppano.
--
-- Fonti: due indipendenti e concordi per raid (icy-veins.com, warcraft.wiki.gg,
-- method.gg, maxroll.gg); per il T29 verificato a livello di item sui token
-- "Forgestone", uno per slot, con tutti e quattro i tipi nella loot table di ogni
-- boss. I nomi sono nella grafia dell'Encounter Journal: ognuno e' stato ricontrollato
-- contro i nomi che il client stesso ha gia' scritto nel dump per gli altri slot.
local TOKEN_BOSS = {
    -- WotLK e Cataclysm: qui il set si COMPRAVA (Emblemi, poi Valor Point), quindi per
    -- molti slot un boss non esiste proprio e la voce giusta e' vuota: vedi
    -- TOKEN_SENZA_FONTE. Il T9 e il T10 non compaiono affatto qui sotto -- erano
    -- interamente da vendor e restano senza boss su tutti e cinque gli slot.
    --
    -- Guanti e gambali di T9/T10/T11/T12 cadono dai raid PvP da un boss solo (Koralon
    -- e Toravon a Vault of Archavon, Argaloth e Occu'thar a Baradin Hold). Sono
    -- boss "generici" -- droppano i pezzi di tutte le classi -- ma il journal li
    -- conosce e la regola qui e' stare aderenti al journal, quindi si scrivono. Nei
    -- dati toccano solo Hands e Legs: se compaiono su altri slot, quello e' un errore.
    --
    t9 = { raid = "Vault of Archavon",
        Hands = "Koralon the Flame Watcher", Legs = "Koralon the Flame Watcher" },
    t10 = { raid = "Vault of Archavon",
        Hands = "Toravon the Ice Watcher", Legs = "Toravon the Ice Watcher" },
    -- T11 e T12 sono ibridi: elmo e spalle avevano il token da boss in entrambe le
    -- difficolta', il resto si comprava in normal e diventava token solo in heroic.
    t11 = { raid = "Blackwing Descent",
        Head = "Nefarian's End",
        Shoulder = { "Cho'gall", "The Bastion of Twilight" },
        Chest = { heroic = { "Halfus Wyrmbreaker", "The Bastion of Twilight" } },
        Hands = { normal = { "Argaloth", "Baradin Hold" }, heroic = "Magmaw" },
        Legs  = { normal = { "Argaloth", "Baradin Hold" }, heroic = "Maloriak" } },
    t12 = { raid = "Firelands",
        Head = "Ragnaros", Shoulder = "Majordomo Staghelm",
        Chest = { heroic = "Alysrazor" },
        Hands = { normal = { "Occu'thar", "Baradin Hold" }, heroic = "Baleroc, the Gatekeeper" },
        Legs  = { normal = { "Occu'thar", "Baradin Hold" }, heroic = "Shannox" } },
    -- Pandaria: stessa struttura dei moderni, un boss per slot valido per tutti e tre i
    -- gruppi (Conqueror/Protector/Vanquisher). Verificato aprendo le pagine dei singoli
    -- token: le tre varianti dello stesso slot nominano lo stesso boss.
    t14 = { raid = "Heart of Fear",
        Head = { "Sha of Fear", "Terrace of Endless Spring" },
        Shoulder = { "Lei Shi", "Terrace of Endless Spring" },
        Chest = "Grand Empress Shek'zeer", Hands = "Wind Lord Mel'jarak",
        Legs = "Amber-Shaper Un'sok" },
    -- ⚠️ Head: il client chiama quell'incontro "Twin Empyreans", le guide "Twin
    -- Consorts". Vale la grafia del client, che e' quella usata ovunque nel manifest.
    t15 = { raid = "Throne of Thunder",
        Head = "Twin Empyreans", Shoulder = "Iron Qon", Chest = "Dark Animus",
        Hands = "Council of Elders", Legs = "Ji-Kun" },
    t16 = { raid = "Siege of Orgrimmar",
        Head = "Thok the Bloodthirsty", Shoulder = "Siegecrafter Blackfuse",
        Chest = "Sha of Pride", Hands = "General Nazgrim",
        Legs = "Paragons of the Klaxxi" },
    t28 = { raid = "Sepulcher of the First Ones",
        Head = "Anduin Wrynn", Shoulder = "Lords of Dread", Chest = "Rygelon",
        Hands = "Lihuvim, Principal Architect", Legs = "Halondrus the Reclaimer" },
    t29 = { raid = "Vault of the Incarnates",
        Head = "Raszageth the Storm-Eater", Shoulder = "Broodkeeper Diurna",
        Chest = "Kurog Grimtotem", Hands = "Dathea, Ascended",
        Legs = "Sennarth, the Cold Breath" },
    t30 = { raid = "Aberrus, the Shadowed Crucible",
        Head = "Magmorax", Shoulder = "Echo of Neltharion",
        Chest = "The Vigilant Steward, Zskarn", Hands = "The Forgotten Experiments",
        Legs = "Rashok, the Elder" },
    t31 = { raid = "Amirdrassil, the Dream's Hope",
        Head = "Tindral Sageswift, Seer of the Flame", Shoulder = "Smolderon",
        Chest = "Nymue, Weaver of the Cycle", Hands = "Igira the Cruel",
        Legs = "Larodar, Keeper of the Flame" },
    t32 = { raid = "Nerub-ar Palace",
        Head = "The Silken Court", Shoulder = "Rasha'nan",
        Chest = "Broodtwister Ovi'nax", Hands = "Sikran, Captain of the Sureki",
        Legs = "Nexus-Princess Ky'veza" },
    t33 = { raid = "Liberation of Undermine",
        Head = "The One-Armed Bandit", Shoulder = "Rik Reverb",
        Chest = "Sprocketmonger Lockenstock", Hands = "Cauldron of Carnage",
        Legs = "Stix Bunkjunker" },
    t34 = { raid = "Manaforge Omega",
        Head = "Forgeweaver Araz", Shoulder = "The Soul Hunters", Chest = "Fractillus",
        Hands = "Soulbinder Naazindhri", Legs = "Loom'ithar" },
    -- Il T35 e' l'unico sparso su piu' raid: il Chest viene dal Dreamrift, non dal
    -- Voidspire. Quando il raid non e' quello di `raid`, si scrive accanto al boss.
    t35 = { raid = "The Voidspire",
        Head = "Lightblinded Vanguard", Shoulder = "Fallen-King Salhadaar",
        Chest = { "Chimaerus the Undreamt God", "The Dreamrift" },
        Hands = "Vorasius", Legs = "Vaelgor & Ezzorak" },
}

-- Boss e raid del token di uno slot, se quel tier ne ha. Nil = il gioco resta
-- l'autorita'. Il valore di uno slot puo' avere tre forme, in ordine di complessita':
--   "Boss"                        -- boss nel raid di default del tier
--   { "Boss", "Raid" }            -- boss in un altro raid (T35: il Chest sta nel Dreamrift)
--   { normal = <una delle due>, heroic = ... }   -- cambia con la versione
-- L'ultima serve dal T12, dove il set normal si comprava coi Valor Point e solo
-- l'heroic aveva i token dai boss: stesso slot, provenienza diversa per difficolta'.
local function TokenBossFor(tier, slot, versione)
    local t = tier and TOKEN_BOSS[tier]
    local v = t and t[slot]
    -- Mappa per versione: si riconosce perche' NON e' la coppia {boss, raid}, che
    -- ha una stringa in posizione 1.
    if type(v) == "table" and type(v[1]) ~= "string" then v = versione and v[versione] end
    if not v then return nil end
    if type(v) == "table" then return v[1], v[2] end
    return v, t.raid
end

-- I 5 slot che nei tier a token non cadono dal boss ma nascono dalla conversione:
-- sono i soli su cui il fallback per visualID sbaglia, e i soli che TOKEN_BOSS e
-- TOKEN_SENZA_FONTE possono toccare.
local SLOT_TOKEN = { Head = true, Shoulder = true, Chest = true, Hands = true, Legs = true }

-- Tier dove sui 5 slot da token il gioco risponde con un boss inaffidabile e la
-- ricerca NON ha trovato quello vero (o non esiste: set da vendor, token generico
-- non legato allo slot). Li' si lascia il solo slot.
--
-- Come si riconoscono: dentro una stessa cella (tier, slot, difficolta') le classi
-- devono convergere su uno stesso boss -- al massimo tre, uno per gruppo di token.
-- Dove invece se ne contano 5-13, tutti dentro il raid del tier, e' la firma del
-- fallback per visualID, la stessa misurata su Manaforge Omega.
--
-- ⚠️ NON usare come criterio "un boss che compare su molti slot": e' sbagliato e
-- cancellerebbe i dati buoni. Un boss di raid droppa legittimamente piu' pezzi
-- dello stesso set -- Forgeweaver Araz da' l'elmo come token e anche cintura,
-- stivali e polsi come loot normale, e infatti risulta su 3 slot pur essendo
-- corretto. Misurato: anche i tier sani (T17-T21) hanno 2-4 slot per boss.
-- Il valore e' `true` (tutti e 5 gli slot) oppure l'elenco dei soli slot da
-- sopprimere: serve la granularita' per slot perche' un tier puo' essere misto. Il
-- T9 e' il caso tipico -- set da vendor, quindi Head/Shoulder/Chest non li droppa
-- nessuno, ma Hands e Legs cadono davvero da Koralon a Vault of Archavon e li' il
-- gioco ha ragione (20 voci su 20 corrette).
local TOKEN_SENZA_FONTE = {
    -- ⚠️ "Vendor" da solo non basta a decidere: ci sono TRE casi diversi, e solo due
    -- vanno soppressi. Non collassarli, e' l'errore facile da fare qui.
    --   1. Token dal boss, convertito dal vendor -- tutta Pandaria (T14-T16): il
    --      vendor e' solo un banco di scambio, la fonte resta il boss. Il boss SI
    --      TIENE, infatti quei tier stanno in TOKEN_BOSS.
    --   2. Acquisto puro con valuta, nessun boss coinvolto -- T9/T10 base, e petto,
    --      guanti, gambali del T11/T12 in normal.
    --   3. Token dal boss ma GENERICO: cade davvero (Trophy of the Crusade da ogni
    --      boss del Trial, Mark of Sanctification da cinque boss di ICC) pero' vale
    --      per uno slot QUALSIASI. E' il caso che sembra un errore e non lo e': un
    --      boss c'e', ma non si puo' dire quale slot dia, quindi la mappa boss->slot
    --      non esiste lo stesso.
    -- T9 e T10 stanno nel 2 e nel 3, mai nell'1: elmo, spalle e petto non li droppa
    -- nessuno. Guanti e gambali invece cadono a Vault of Archavon e stanno in
    -- TOKEN_BOSS: il journal li conosce, quindi si riportano.
    t9  = { Head = true, Shoulder = true, Chest = true },
    t10 = { Head = true, Shoulder = true, Chest = true },
    -- T11 e T12: in normal il petto si comprava coi Valor Point e basta. Guanti e
    -- gambali no, quelli cadevano a Baradin Hold.
    t11 = { Chest = { normal = true } },
    t12 = { Chest = { normal = true } },
}

-- Il boss di questo slot va soppresso? Vale solo sui 5 slot da token. Come sopra, la
-- soppressione puo' dipendere dalla versione: `true` (sempre) o l'elenco delle sole
-- versioni in cui il pezzo non aveva una provenienza da boss.
local function BossInaffidabile(tier, slot, versione)
    local v = tier and TOKEN_SENZA_FONTE[tier]
    if not v or not SLOT_TOKEN[slot] then return false end
    if v == true then return true end
    local s = v[slot]
    if s == nil then return false end
    return s == true or (versione ~= nil and s[versione] == true)
end

-- Diagnostica: quale API risponde e con che forma. Finisce nel DB.
local probe = {}

-- Statistiche del recupero boss (finiscono nel DB, servono a validare il dump).
local stats = { viaVariante = 0, daToken = 0, soppressi = 0 }

-- ⚠️ Strada dell'Encounter Journal: PROVATA E SCARTATA, non riproporla.
-- L'idea era leggere dal journal il boss che droppa il token, visto che dal T28 e' il
-- token a cadere e non il pezzo di classe.
--
-- Misurata due volte, la seconda con una sonda che ha spazzato TUTTO il journal (73
-- raid, 493 boss, ogni difficolta', 80.899 indici di loot) contro i 1315 itemID che
-- il dump lascia senza boss: 20 agganci, l'1,5%. E nessuno dei venti viene dal raid
-- del proprio tier -- sono tutti sorgenti alternative (Vault of Archavon per il T10,
-- Baradin Hold per l'T11, Sha of Anger e Chi-Ji per T14/T16, M'uru a Sunwell per il
-- T6), cioe' i casi "luogo fuori dal raid del tier". Valgono 20 voci su 2975: 0,7%.
--
-- Il motivo e' strutturale, non un difetto di come si interroga: nelle liste di loot
-- del journal c'e' il TOKEN, il pezzo di classe non compare proprio. Tre scuse
-- plausibili gia' escluse, per non rifarle:
--   * NON e' il load-on-demand: Blizzard_EncounterJournal si carica senza problemi e
--     le EJ_* rispondono (raidSenzaLoot e' uscito vuoto, tutti i raid espongono loot);
--   * NON e' il filtro: EJ_SetLootFilter(classID, spec) e' un no-op in 12.0.7, con e
--     senza filtro escono le stesse voci nello stesso ordine;
--   * NON sono itemID falsi: GetLootInfoByIndex restituisce itemID reali e usabili
--     (una nota precedente diceva il contrario, era sbagliata). Espone solo itemID,
--     encounterID e i flag displayAs*: name e slot mancano perche' arrivano a item
--     caricato, ma per una mappa itemID -> boss non servono.
-- Se ci si torna, serve un'API nuova che leghi pezzo e token, non un giro diverso su
-- queste. Nota di metodo: enumerare i boss e chiamare EJ_SetDifficulty nello stesso
-- giro non funziona -- una difficolta' inesistente per quel raid fa perdere al
-- journal il contesto dell'istanza e l'enumerazione muore al primo raid (84 boss
-- invece di 493). Vanno tenuti in due passate separate.
--
-- Il boss si recupera invece dalle altre source della stessa apparenza, vedi PiecesIn.

-- Le API di transmog cambiano nome fra le espansioni (GetSetSources e' sparita in
-- 12.0.x): elencare cosa esiste davvero evita di indovinare al giro dopo.
local function ApiNames()
    local out = {}
    for _, ns in ipairs({ "C_TransmogSets", "C_TransmogCollection" }) do
        local tbl = _G[ns]
        if type(tbl) == "table" then
            for k, v in pairs(tbl) do
                if type(v) == "function" then out[#out + 1] = ns .. "." .. k end
            end
        end
    end
    table.sort(out)
    return out
end

-- Boss che droppa una source, se il gioco lo sa. Il nome dell'API e' cambiato negli
-- anni: proviamo i candidati noti, sotto pcall, e ricordiamo quale ha funzionato.
local DROP_FNS = {
    { "C_TransmogCollection.GetAppearanceSourceDrops", function(id) return C_TransmogCollection.GetAppearanceSourceDrops(id) end },
    { "C_TransmogCollection.GetAppearanceSourceInfo", function(id)
        -- Fallback: da qui si ricava almeno il nome dell'oggetto, non il boss.
        local _, _, _, _, _, itemLink = C_TransmogCollection.GetAppearanceSourceInfo(id)
        return itemLink and { { encounter = nil } } or nil
    end },
}

local function BossFor(sourceID)
    for _, cand in ipairs(DROP_FNS) do
        local name, fn = cand[1], cand[2]
        local ok, res = pcall(fn, sourceID)
        if not ok then
            probe[name] = probe[name] or ("errore: " .. tostring(res))
        elseif type(res) == "table" and res[1] then
            probe[name] = probe[name] or ("ok, campi: " .. table.concat((function()
                local ks = {}
                for k, v in pairs(res[1]) do ks[#ks + 1] = k .. "=" .. tostring(v) end
                table.sort(ks)
                return ks
            end)(), ", "))
            -- Il primo drop basta: le voci extra sono le altre difficolta' dello stesso boss.
            if res[1].encounter then return res[1].encounter, res[1].instance end
        else
            probe[name] = probe[name] or ("vuoto/" .. type(res))
        end
    end
    return nil
end

-- Slot non ancora mappati, per correggere SLOT_NAME senza tirare a indovinare.
local unmapped = {}
-- Set dove l'elenco dei mancanti non combacia con la frazione posseduti/totale.
local mismatches = {}
-- Pezzi NON collezionati di un set, con il boss che li droppa quando il gioco lo sa.
-- Restituisce una lista di stringhe tipo "Shoulder (Ragnaros, Firelands)".
--
-- Si itera GetSetPrimaryAppearances, la stessa lista che CountSet usa per la
-- frazione: cosi' i mancanti sono per costruzione esattamente `total - have`.
--
-- ⚠️ Il campo `appearanceID` di quelle entry contiene in realta' una **sourceID**
-- (verificato: gli id delle primarie stanno nell'intervallo delle sourceID, non dei
-- visualID), quindi si passa dritti a GetSourceInfo/GetAppearanceSourceDrops senza
-- alcun join. Le vie scartate: GetSetSources non esiste piu' in 12.0.x,
-- GetAllAppearanceSources restituiva oggetti di altri set, e GetAllSourceIDs include
-- le varianti di difficolta' (42 voci per un set da 8).
--
-- `have`/`total` arrivano da CountSet: verifica che l'elenco combaci con la frazione
-- mostrata nella cella, altrimenti il tooltip contraddirebbe il numero.
local function PiecesIn(setID, have, total, tier, versione)
    local out = {}

    -- Un'apparenza ha piu' source (le varie difficolta', e dal T28 anche il Catalyst).
    -- Su quella primaria GetAppearanceSourceDrops tace, ma la variante che cade in raid
    -- il boss ce l'ha: si raggruppano le source per visual per poterle provare tutte.
    local byVisual = {}
    for _, sid in ipairs(C_TransmogSets.GetAllSourceIDs(setID) or {}) do
        local si = C_TransmogCollection.GetSourceInfo(sid)
        if si and si.visualID then
            byVisual[si.visualID] = byVisual[si.visualID] or {}
            table.insert(byVisual[si.visualID], sid)
        end
    end

    for _, a in ipairs(C_TransmogSets.GetSetPrimaryAppearances(setID) or {}) do
        local sourceID = a.appearanceID
        local info = sourceID and C_TransmogCollection.GetSourceInfo(sourceID)
        local invType = info and info.invType
        local slot = SLOT_NAME[invType]
        if not slot then
            unmapped[tostring(invType)] = (info and info.itemID) or "?"
            slot = "Slot " .. tostring(invType)
        end
        -- Slot da token di un tier moderno: la risposta la da' TOKEN_BOSS, non il
        -- gioco. Va PRIMA di BossFor, non dopo come fallback: il giro per visualID
        -- una risposta la trova quasi sempre, solo che e' quella sbagliata.
        local boss, instance = TokenBossFor(tier, slot, versione)
        if boss then stats.daToken = stats.daToken + 1 end
        -- Niente fonte attendibile per questo slot: si sopprime invece di chiedere al
        -- gioco, che risponderebbe col boss sbagliato. Resta il solo slot.
        --
        -- ⚠️ `sopprimi` deve spegnere ENTRAMBE le vie, non solo la prima: la seconda
        -- e' il giro per visualID poco sotto, che una risposta la trova quasi sempre.
        -- Proteggendo solo BossFor la voce veniva soppressa e subito ripescata li',
        -- e il contatore diceva 310 soppressioni mentre nei dati non cambiava nulla.
        local sopprimi = not boss and BossInaffidabile(tier, slot, versione)
        if sopprimi then
            stats.soppressi = stats.soppressi + 1
        elseif not boss and sourceID then
            boss, instance = BossFor(sourceID)
        end
        -- Nessun drop sulla primaria: si provano le altre source dello stesso
        -- visual (stesso aspetto, difficolta' diversa), dove il boss c'e'.
        if not sopprimi and not boss and info and info.visualID then
            for _, alt in ipairs(byVisual[info.visualID] or {}) do
                if alt ~= sourceID then
                    boss, instance = BossFor(alt)
                    if boss then
                        stats.viaVariante = stats.viaVariante + 1
                        break
                    end
                end
            end
        end

        -- Formato: "Shoulder (Ragnaros, Firelands)". Il raid serve al sito per
        -- mostrarne la sigla; il taglio fra boss e raid NON e' sulla virgola,
        -- perche' ne contengono entrambi: ci pensa formatMissing lato sito.
        local testo
        if boss and instance then
            testo = ("%s (%s, %s)"):format(slot, boss, instance)
        elseif boss then
            testo = ("%s (%s)"):format(slot, boss)
        else
            testo = slot
        end
        -- Si emettono TUTTI i pezzi, non solo i mancanti: il tooltip li mostra tutti
        -- e colora di verde i presi. `preso` e' 1/0 perche' nel JSON pesa meno di
        -- true/false ed e' sommabile per la verifica contro la frazione.
        -- L'itemID viaggia accanto: serve a cercare altrove i drop che il client non
        -- conosce. Restano appaiati perche' l'ordinamento scombinerebbe liste parallele.
        out[#out + 1] = {
            testo = testo,
            preso = a.collected and 1 or 0,
            itemID = (not boss) and info and info.itemID or nil,
        }
    end
    -- Prima i mancanti, poi i presi; dentro ogni gruppo in ordine alfabetico: cosi'
    -- il tooltip apre con quello che resta da prendere.
    table.sort(out, function(a, b)
        if a.preso ~= b.preso then return a.preso < b.preso end
        return a.testo < b.testo
    end)

    -- Discrepanza = elenco non fidato: meglio saperlo che pubblicare numeri diversi
    -- fra cella e tooltip.
    local presi = 0
    for _, v in ipairs(out) do presi = presi + v.preso end
    if total and (#out ~= total or presi ~= have) then
        mismatches[#mismatches + 1] = ("set %d: elenco %d/%d presi, attesi %d/%d")
            :format(setID, presi, #out, have, total)
    end
    return out
end

local function Dump()
    local raw, data, dropped, pieces, errors = {}, {}, {}, {}, {}
    -- Set in cui NESSUN pezzo ottiene un boss. Una riga di raid a copertura zero e'
    -- anomala: Trial of Valor ha 468 voci e nemmeno un boss, mentre Tomb of Sargeras
    -- sta al 95% e Uldir al 100%. Qui si registra quali set sono, e per il primo di
    -- ognuno cosa rispondono davvero le API sulle sue source.
    local senzaBoss, sondaSenzaBoss = {}, {}
    local seen = {}
    -- Dump() gira piu' volte per sessione (login, /wmtier, logout): senza azzerare,
    -- i contatori si sommano fra una passata e l'altra e sembrano il triplo.
    stats.viaVariante, stats.daToken, stats.soppressi = 0, 0, 0

    local function consider(info)
        if not info or seen[info.setID] then return end
        seen[info.setID] = true
        local have, total = CountSet(info.setID)
        raw[#raw + 1] = {
            setID = info.setID, name = info.name, label = info.label,
            description = info.description, classMask = info.classMask,
            requiredFaction = info.requiredFaction, expansionID = info.expansionID,
            patchID = info.patchID, uiOrder = info.uiOrder,
            collected = have, total = total,
        }

        local chiave = (info.expansionID or -1) .. "|" .. (info.label or "")
        local mask = info.classMask or 0
        -- Piu' bit accesi = set per tipo di armatura, che ha una riga sua. Non e' piu'
        -- motivo di scarto: prima finiva in dropped come "multiclasse" e le righe di
        -- BfA, Nathria, Sanctum e l'LFR di WoD restavano vuote per tutti.
        local condiviso = bit.band(mask, mask - 1) ~= 0
        local tier = condiviso and TIER_ARMOR[chiave] or TIER[chiave]
        if not tier then return end
        if IGNORE[info.description] then
            dropped[#dropped + 1] = tier .. ": " .. tostring(info.description)
            return
        end
        local classi = ClassiIn(mask)
        if #classi == 0 then
            dropped[#dropped + 1] = tier .. ": classMask vuoto"
            return
        end
        local slot = SLOT_UNICO[tier]
            or ((tier == "t9") and FACTION_SLOT[info.requiredFaction])
            or SLOT[info.description]
        if not slot then
            dropped[#dropped + 1] = tier .. ": slot ignoto " .. tostring(info.description)
            return
        end
        -- L'elenco dei pezzi si calcola UNA volta: e' lo stesso set, e per un set
        -- condiviso rifarlo per ognuna delle classi sarebbe solo lavoro ripetuto.
        -- Sotto pcall: un errore qui deve degradare il solo elenco dei pezzi,
        -- non far saltare tutto il dump (e con esso `collected`).
        local ok, list = pcall(PiecesIn, info.setID, have, total, tier, slot)
        if not ok then
            errors[#errors + 1] = tier .. "/" .. classi[1] .. ": " .. tostring(list)
            list = nil
        end

        -- Nessun pezzo con un boss: si annota il set, e sul PRIMO che capita si
        -- guarda source per source cosa risponde l'API. Serve a distinguere "il
        -- gioco non lo sa" da "lo chiediamo male".
        if list and #list > 0 then
            local conBoss = 0
            for _, v in ipairs(list) do
                if v.testo:find(" %(") then conBoss = conBoss + 1 end
            end
            if conBoss == 0 then
                senzaBoss[#senzaBoss + 1] = ("%s | setID %d | %s | %s | %s"):format(
                    tier, info.setID, tostring(info.name), tostring(info.label),
                    tostring(info.description))
                if #sondaSenzaBoss == 0 then
                    for _, sid in ipairs(C_TransmogSets.GetAllSourceIDs(info.setID) or {}) do
                        local si = C_TransmogCollection.GetSourceInfo(sid)
                        local okd, drops = pcall(C_TransmogCollection.GetAppearanceSourceDrops, sid)
                        sondaSenzaBoss[#sondaSenzaBoss + 1] = ("src %d | item %s | visual %s | drops %s"):format(
                            sid, tostring(si and si.itemID), tostring(si and si.visualID),
                            okd and (type(drops) == "table" and #drops or tostring(drops)) or "errore")
                    end
                end
            end
        end

        for _, class in ipairs(classi) do
            data[class] = data[class] or {}
            data[class][tier] = data[class][tier] or {}
            data[class][tier][slot] = { have, total }
            -- Anche i set completi: il tooltip li mostra tutti verdi, non vuoti.
            if list then
                pieces[class] = pieces[class] or {}
                pieces[class][tier] = pieces[class][tier] or {}
                pieces[class][tier][slot] = list
            end
        end
    end

    for _, info in ipairs(C_TransmogSets.GetAllSets() or {}) do
        consider(info)
        for _, v in ipairs(C_TransmogSets.GetVariantSets(info.setID) or {}) do consider(v) end
    end

    -- Serializza il blocco `collected` con l'indentazione del manifest (2 spazi).
    local out = { '  "collected": {' }
    for ci, class in ipairs(CLASS_ORDER) do
        local tiers = {}
        for _, tier in ipairs(TIER_ORDER) do
            local slots = data[class] and data[class][tier]
            if slots then
                local parts = {}
                for _, slot in ipairs(SLOT_ORDER) do
                    local v = slots[slot]
                    if v then parts[#parts + 1] = ('"%s": [%d, %d]'):format(slot, v[1], v[2]) end
                end
                tiers[#tiers + 1] = ('      "%s": { %s }'):format(tier, table.concat(parts, ", "))
            end
        end
        out[#out + 1] = ('    "%s": {\n%s\n    }%s'):format(
            class, table.concat(tiers, ",\n"), ci < #CLASS_ORDER and "," or "")
    end
    out[#out + 1] = "  }"

    -- Blocco `pieceList`: TUTTI i pezzi di ogni set, come coppie [testo, preso], dove
    -- preso e' 1 se gia' collezionato. Il sito li mostra tutti, rossi o verdi.
    -- Stessa struttura anche per gli itemID (0 dove il boss e' noto o il pezzo e'
    -- preso): resta nello stesso ordine perche' nasce dalla stessa lista.
    local function esc(s) return (tostring(s):gsub('[\\"]', '\\%0')) end
    local function Serializza(chiave, campo)
        local mo = { ('  "%s": {'):format(chiave) }
        local classLines = {}
        for _, class in ipairs(CLASS_ORDER) do
            if pieces[class] then
                local tiers = {}
                for _, tier in ipairs(TIER_ORDER) do
                    local slots = pieces[class][tier]
                    if slots then
                        local parts = {}
                        for _, slot in ipairs(SLOT_ORDER) do
                            local list = slots[slot]
                            if list and #list > 0 then
                                local items = {}
                                for i, v in ipairs(list) do
                                    items[i] = (campo == "itemID")
                                        and tostring(v.itemID or 0)
                                        or ('["%s", %d]'):format(esc(v.testo), v.preso)
                                end
                                parts[#parts + 1] = ('"%s": [%s]'):format(slot, table.concat(items, ", "))
                            end
                        end
                        if #parts > 0 then
                            tiers[#tiers + 1] = ('      "%s": { %s }'):format(tier, table.concat(parts, ", "))
                        end
                    end
                end
                if #tiers > 0 then
                    classLines[#classLines + 1] = ('    "%s": {\n%s\n    }'):format(class, table.concat(tiers, ",\n"))
                end
            end
        end
        mo[#mo + 1] = table.concat(classLines, ",\n")
        mo[#mo + 1] = "  }"
        return table.concat(mo, "\n")
    end

    -- ⚠️ GUARDIA: se il client non ha ancora caricato la collezione transmog, ogni
    -- set risulta a zero pezzi presi ma con il totale giusto. Il dump resta
    -- internamente COERENTE -- mismatches ed errors restano vuoti -- quindi nulla
    -- lo distingue da un dump buono, e incollarlo azzera la collezione nel manifest.
    -- Successo davvero: 4610 pezzi diventati 0 su tutte e 13 le classi.
    -- L'addon parte 5 secondi dopo il login e a volte non basta: qui si conta quanto
    -- si e' collezionato e, se e' zero mentre i pezzi esistono, si urla.
    local presi, pezzi = 0, 0
    for _, tiers in pairs(data) do
        for _, slots in pairs(tiers) do
            for _, v in pairs(slots) do presi = presi + v[1]; pezzi = pezzi + v[2] end
        end
    end
    -- Lettura a vuoto: NON si sovrascrive. Se c'e' gia' un dump buono lo si lascia
    -- dov'e' e si esce -- il SavedVariables conserva quello di prima. E' il caso che
    -- capita ricaricando troppo presto dopo il login, quando la collezione non e'
    -- ancora arrivata: prima bastava quello per azzerare 4610 pezzi.
    if pezzi > 0 and presi == 0 then
        local avviso = "collezione non ancora caricata"
        if WowManagerTierDumpDB and (WowManagerTierDumpDB.presi or 0) > 0 then
            print(("|cffff2020WowManagerTierDump: %s -- tengo il dump di %s (%d pezzi). Rilancia fra un minuto.|r")
                :format(avviso, tostring(WowManagerTierDumpDB.generated), WowManagerTierDumpDB.presi))
            return
        end
        -- Nessun dump buono da difendere: si scrive, ma marcato.
        print("|cffff2020WowManagerTierDump: " .. avviso .. ". NON incollare.|r")
        WowManagerTierDumpDB = {
            generated = date("%Y-%m-%d %H:%M:%S"),
            sospetto = avviso .. ": tutti i pezzi risultano a zero. NON incollare.",
            presi = presi, pezzi = pezzi,
        }
        return
    end
    local sospetto = nil

    WowManagerTierDumpDB = {
        generated = date("%Y-%m-%d %H:%M:%S"),
        sospetto = sospetto,   -- nil = dump buono. Se valorizzato, NON incollare.
        presi = presi, pezzi = pezzi,
        build = GetBuildInfo(),
        collectedJson = table.concat(out, "\n"),
        piecesJson = Serializza("pieceList", "testo"),
        -- Non va nel manifest: e' la lista di lavoro per cercare i drop mancanti.
        missingItemIdsJson = Serializza("missingItemIds", "itemID"),
        dropped = dropped,
        errors = errors,   -- set il cui elenco pezzi e' fallito (dump comunque valido)
        probe = probe,     -- quale API ha risposto, e con che campi
        api = ApiNames(),  -- funzioni davvero esposte: serve quando un'API sparisce
        unmapped = unmapped,  -- invType senza nome in SLOT_NAME -> un itemID d'esempio
        mismatches = mismatches,  -- set con elenco incoerente col conteggio
        senzaBoss = senzaBoss,        -- set in cui nessun pezzo ha un boss
        sondaSenzaBoss = sondaSenzaBoss,  -- cosa rispondono le API sul primo di quelli
        stats = stats,            -- boss recuperati dalle varianti della stessa apparenza

        sets = raw,   -- dump grezzo: serve solo se cambia la mappa TIER/SLOT
    }

    print(("|cff33ff99WowManagerTierDump|r: %d set letti, %d scartati, %d errori. /reload per scrivere il file.")
        :format(#raw, #dropped, #errors))
end

SLASH_WMTIER1 = "/wmtier"
SlashCmdList["WMTIER"] = Dump

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGOUT" then
        Dump()      -- rigenera prima della scrittura: il file e' sempre fresco
    else
        C_Timer.After(5, Dump)
    end
end)
