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
    ["1|Black Temple"] = "t6", ["1|Sunwell Plateau"] = "t6",
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
}
-- Ordine dei tier nel manifest (serve solo a rendere l'output ordinato).
local TIER_ORDER = { "t0", "t05", "t1", "t2", "t25", "t3", "t4", "t5", "t6", "t7", "t8",
    "t9", "t10", "t11", "t12", "t13", "t14", "t15", "t16", "t17", "t18", "t19", "t20",
    "t21", "t28", "t29", "t30", "t31", "t32", "t33", "t34", "t35" }

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

-- Boss e raid del token di uno slot, se quel tier ne ha. Nil = il gioco resta l'autorita'.
local function TokenBossFor(tier, slot)
    local t = tier and TOKEN_BOSS[tier]
    local v = t and t[slot]
    if not v then return nil end
    if type(v) == "table" then return v[1], v[2] end
    return v, t.raid
end

-- Diagnostica: quale API risponde e con che forma. Finisce nel DB.
local probe = {}

-- Statistiche del recupero boss (finiscono nel DB, servono a validare il dump).
local stats = { viaVariante = 0, daToken = 0 }

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
local function PiecesIn(setID, have, total, tier)
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
        local boss, instance = TokenBossFor(tier, slot)
        if boss then stats.daToken = stats.daToken + 1 end
        if not boss and sourceID then boss, instance = BossFor(sourceID) end
        -- Nessun drop sulla primaria: si provano le altre source dello stesso
        -- visual (stesso aspetto, difficolta' diversa), dove il boss c'e'.
        if not boss and info and info.visualID then
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
    local seen = {}
    -- Dump() gira piu' volte per sessione (login, /wmtier, logout): senza azzerare,
    -- i contatori si sommano fra una passata e l'altra e sembrano il triplo.
    stats.viaVariante, stats.daToken = 0, 0

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

        local tier = TIER[(info.expansionID or -1) .. "|" .. (info.label or "")]
        if not tier then return end
        if IGNORE[info.description] then
            dropped[#dropped + 1] = tier .. ": " .. tostring(info.description)
            return
        end
        -- I set di raid non specifici di classe (classMask con piu' bit) non sono tier set.
        local class = CLASSES[select(2, math.frexp(info.classMask or 0))]
        if not class or bit.band(info.classMask, info.classMask - 1) ~= 0 then
            dropped[#dropped + 1] = tier .. ": multiclasse"
            return
        end
        local slot = (tier == "t9") and FACTION_SLOT[info.requiredFaction] or SLOT[info.description]
        if not slot then
            dropped[#dropped + 1] = tier .. ": slot ignoto " .. tostring(info.description)
            return
        end
        data[class] = data[class] or {}
        data[class][tier] = data[class][tier] or {}
        data[class][tier][slot] = { have, total }
        -- Anche i set completi: il tooltip li mostra tutti verdi, non vuoti.
        -- Sotto pcall: un errore qui deve degradare il solo elenco dei pezzi,
        -- non far saltare tutto il dump (e con esso `collected`).
        local ok, list = pcall(PiecesIn, info.setID, have, total, tier)
        if not ok then
            errors[#errors + 1] = tier .. "/" .. class .. ": " .. tostring(list)
        else
            pieces[class] = pieces[class] or {}
            pieces[class][tier] = pieces[class][tier] or {}
            pieces[class][tier][slot] = list
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

    WowManagerTierDumpDB = {
        generated = date("%Y-%m-%d %H:%M:%S"),
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
