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
--   ["missingJson"]   -> blocco `missing`    (quali pezzi mancano e chi li droppa)

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

-- invType (INVTYPE_*) -> nome slot in italiano, per l'elenco dei pezzi mancanti.
local SLOT_NAME = {
    INVTYPE_HEAD = "Testa", INVTYPE_SHOULDER = "Spalle", INVTYPE_CHEST = "Petto",
    INVTYPE_ROBE = "Petto", INVTYPE_WAIST = "Cintura", INVTYPE_LEGS = "Gambe",
    INVTYPE_FEET = "Piedi", INVTYPE_WRIST = "Polsi", INVTYPE_HAND = "Mani",
    INVTYPE_CLOAK = "Schiena", INVTYPE_NECK = "Collo", INVTYPE_FINGER = "Anello",
    INVTYPE_TRINKET = "Monile",
}

-- Pezzi NON collezionati di un set, con il boss che li droppa quando il gioco lo sa.
-- Restituisce una lista di stringhe tipo "Spalle (Ragnaros)".
local function MissingIn(setID)
    local out = {}
    local sources = C_TransmogSets.GetSetSources(setID)
    if not sources then return out end
    for sourceID, collected in pairs(sources) do
        if not collected then
            local info = C_TransmogCollection.GetSourceInfo(sourceID)
            local slot = info and (SLOT_NAME[info.invType] or info.invType) or "?"
            -- Il primo drop basta: le voci extra sono le altre difficolta' dello stesso boss.
            local drops = C_TransmogCollection.GetAppearanceSourceDrops(sourceID)
            local boss = drops and drops[1] and drops[1].encounter
            out[#out + 1] = boss and (slot .. " (" .. boss .. ")") or slot
        end
    end
    table.sort(out)
    return out
end

local function Dump()
    local raw, data, dropped, missing = {}, {}, {}, {}
    local seen = {}

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
        if have < total then
            missing[class] = missing[class] or {}
            missing[class][tier] = missing[class][tier] or {}
            missing[class][tier][slot] = MissingIn(info.setID)
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

    -- Blocco `missing`: solo i set incompleti, con l'elenco dei pezzi che mancano.
    local function esc(s) return (tostring(s):gsub('[\\"]', '\\%0')) end
    local mo = { '  "missing": {' }
    local classLines = {}
    for _, class in ipairs(CLASS_ORDER) do
        if missing[class] then
            local tiers = {}
            for _, tier in ipairs(TIER_ORDER) do
                local slots = missing[class][tier]
                if slots then
                    local parts = {}
                    for _, slot in ipairs(SLOT_ORDER) do
                        local list = slots[slot]
                        if list and #list > 0 then
                            local items = {}
                            for i, v in ipairs(list) do items[i] = '"' .. esc(v) .. '"' end
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

    WowManagerTierDumpDB = {
        generated = date("%Y-%m-%d %H:%M:%S"),
        build = GetBuildInfo(),
        collectedJson = table.concat(out, "\n"),
        missingJson = table.concat(mo, "\n"),
        dropped = dropped,
        sets = raw,   -- dump grezzo: serve solo se cambia la mappa TIER/SLOT
    }

    print(("|cff33ff99WowManagerTierDump|r: %d set letti, %d scartati. /reload per scrivere il file.")
        :format(#raw, #dropped))
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
