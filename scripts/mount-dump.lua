-- WowManagerMountDump - addon locale, NON un addon pubblico.
-- Legge il diario delle cavalcature (C_MountJournal) e scrive in SavedVariables
-- l'elenco COMPLETO delle mount che il gioco conosce -- prese e mancanti -- gia'
-- serializzato in JSON, pronto per mounts/manifest.json.
--
-- Installazione: crea _retail_/Interface/AddOns/WowManagerMountDump/ e copiaci
--   questo file, rinominato   -> WowManagerMountDump.lua
--   scripts/WowManagerMountDump.toc -> WowManagerMountDump.toc  (invariato)
-- Un addon NUOVO richiede il RIAVVIO del client (il /reload non lo vede).
--
-- Uso: /wmmount (o aspetta il login), poi /reload o logout per scrivere
--   WTF/Account/<ACC>/SavedVariables/WowManagerMountDump.lua
-- Da li' ci pensa scripts/mount-sync.ps1: il campo che serve e' uno solo,
--   ["mountsJson"] -> il blocco `mounts` del manifest.
--
-- ⚠️ La collezione mount e' ACCOUNT-WIDE (Warband), come le apparenze transmog:
-- i numeri valgono per l'account, non per il PG loggato.

-- mountTypeID -> categoria mostrata sul sito. Il client NON espone
-- "terrestre/volante": c'e' solo questo numero, e le mappe che girano sulle wiki
-- sono incomplete. Qui stanno SOLO i valori di cui si e' certi; ogni ID sconosciuto
-- finisce in `tipiIgnoti` con dei nomi d'esempio, cosi' si classifica guardando i
-- dati veri invece di indovinare. Finche' non e' classificato, cat = "?" (la pagina
-- lo mostra come "Altro", che e' onesto: non sappiamo).
--
-- ⚠️ Classificati sui NOMI che il dump stesso ha tirato fuori (campo `tipiIgnoti`),
-- non su una mappa presa da una wiki: la prima stesura dava 424 = skyriding e ci
-- finivano 708 mount su 1626, cioe' tutte le volanti normali.
local CAT = {
    [230] = "terra",   -- il grosso delle terrestri (823)
    [231] = "acqua",   -- tartarughe: terra + nuoto
    [232] = "acqua",   -- ippocampo di Vashj'ir, solo sott'acqua
    [241] = "terra",   -- carri del Tempio di Ahn'Qiraj (solo dentro AQ40)
    [242] = "volo",    -- grifoni spettrali (le cavalcature da fantasma)
    [248] = "volo",    -- volanti "classiche": in Midnight non le usa piu' nessuna
    [254] = "acqua",   -- Subdued Seahorse e parenti
    [269] = "terra",   -- cavalcature che camminano sull'acqua
    [284] = "terra",   -- Chauffeured Chopper
    [402] = "drago",   -- draghi da skyriding (Algarian Stormrider, Anu'relos...)
    [407] = "terra",   -- Otterworldly Ottuk Carrier: della famiglia degli ottuk
    [412] = "terra",   -- ottuk (Otto, War/Scouting/Trader's Ottuk)
    [424] = "volo",    -- IL grosso delle volanti (708): volano e fanno skyriding
    [426] = "drago",   -- i 7 draghi personalizzabili (Renewed Proto-Drake, Highland...)
    [436] = "acqua",   -- creature d'abisso (Aurelid, Deepstalker, Old God Fish)
    [442] = "drago",   -- Soar, il razziale dell'evocatore
}

-- sourceType e' un indice, non un testo: il diario delle cavalcature riusa le
-- stringhe BATTLE_PET_SOURCE_n del diario delle mascotte. Si leggono dal client
-- invece di trascriverle, cosi' non si sbaglia ne' l'ordine ne' le voci nuove.
-- Esce gia' in JSON: lo script di sync non deve leggere tabelle Lua.
local function SorgentiJson()
    local parti = {}
    for i = 1, 40 do
        local s = _G["BATTLE_PET_SOURCE_" .. i]
        if s and s ~= "" then parti[#parti + 1] = ('"%d": "%s"'):format(i, s) end
    end
    return "{ " .. table.concat(parti, ", ") .. " }"
end

-- Escape JSON: virgolette, backslash e i caratteri di controllo. Gli a capo del
-- testo di provenienza si tengono come \n -- il sito li usa per separare la riga
-- "Drop: <boss>" dalla zona -- il resto dei controlli si butta.
local function esc(s)
    return (tostring(s):gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == '\\' then return '\\\\' end
        if c == '\n' then return '\\n' end
        return ''
    end))
end

-- Il testo di provenienza e' pieno del markup del client, non solo dei colori:
--   |cFFFFD200Drop:|r      colore
--   |n                     a capo -- NON e' \n, e senza tradurlo le righe si fondono
--   |TInterface\ICONS\...|t   icona inline (la si trova nel costo dei vendor)
--   |Hcurrency:3303|h...|h    link (il testo visibile e' dentro)
-- Va tolto tutto: il sito mostra questa riga cosi' com'e', e un dump grezzo ci
-- portava dentro pezzi di path di texture.
local residui = {}
local function pulisci(s)
    if not s or s == "" then return nil end
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", "")   -- icone inline e atlas
    s = s:gsub("|H.-|h(.-)|h", "%1")              -- link: resta il solo testo visibile
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|n", "\n")
    -- Riga per riga: spazi doppi via (il gioco scrive "Drop:  Boss"), righe vuote via.
    local out = {}
    for riga in (s .. "\n"):gmatch("(.-)\n") do
        riga = riga:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
        if riga ~= "" then out[#out + 1] = riga end
    end
    s = table.concat(out, "\n")
    -- Diagnostica: se resta una barra verticale c'e' un markup che non conosco.
    -- Meglio saperlo dal dump che scoprirlo in pagina.
    if s:find("|", 1, true) and #residui < 8 then residui[#residui + 1] = s end
    return s ~= "" and s or nil
end

-- Segnaposto di Blizzard rimasti nel diario: non sono cavalcature, sono voci di
-- lavorazione ("(PH)" = placeholder, "[DND]" = do not distribute). Si scartano
-- perche' sul sito sarebbero righe finte, e si contano per non farlo in silenzio.
local function segnaposto(name)
    return name:find("^%(PH%)") ~= nil or name:find("^%[DND%]") ~= nil
end

-- Quali funzioni C_MountJournal esistono davvero: se un giorno il client esponesse
-- un filtro per tipo, la categoria si leggerebbe da li' invece di dedurla dal
-- mountTypeID. Serve a saperlo senza tirare a indovinare i nomi delle API.
local function ApiNames()
    local out = {}
    for k, v in pairs(C_MountJournal) do
        if type(v) == "function" then out[#out + 1] = k end
    end
    table.sort(out)
    return out
end

local function Dump()
    local voci, presi = {}, 0
    local tipi, tipiIgnoti, scartate = {}, {}, {}
    residui = {}

    for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
        local name, spellID, _, _, _, sourceType, _, isFactionSpecific, faction,
              _, isCollected, mountID = C_MountJournal.GetMountInfoByID(id)
        -- creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, ...
        local _, _, source, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(id)
        if name and segnaposto(name) then
            scartate[#scartate + 1] = name
        elseif name then
            local cat = CAT[mountTypeID or 0]
            tipi[mountTypeID or 0] = (tipi[mountTypeID or 0] or 0) + 1
            if not cat then
                local ex = tipiIgnoti[tostring(mountTypeID)] or {}
                if #ex < 4 then ex[#ex + 1] = name end
                tipiIgnoti[tostring(mountTypeID)] = ex
            end
            local fz = "null"
            if isFactionSpecific then fz = (faction == 0) and '"horde"' or '"alliance"' end
            if isCollected then presi = presi + 1 end
            voci[#voci + 1] = {
                name = name,
                json = ('{"id":%d,"spell":%d,"name":"%s","src":%d,"srcText":"%s","type":%d,"cat":"%s","faction":%s,"got":%d}')
                    :format(mountID or id, spellID or 0, esc(name), sourceType or 0,
                        esc(pulisci(source) or ""), mountTypeID or 0, cat or "?",
                        fz, isCollected and 1 or 0),
            }
        end
    end

    -- Ordine alfabetico: il file finisce in git, e un ordine stabile fa si' che il
    -- diff mostri le mount nuove invece di un rimescolamento completo.
    table.sort(voci, function(a, b) return a.name < b.name end)

    -- ⚠️ GUARDIA, come nel dump transmog: se il client non ha ancora caricato la
    -- collezione, l'elenco esce completo ma con TUTTE le mount a zero. E' un dump
    -- internamente coerente -- nulla lo distingue da uno buono -- e incollarlo
    -- azzererebbe la collezione. Se c'e' gia' un dump buono NON lo si sovrascrive.
    if #voci > 0 and presi == 0 then
        local avviso = "collezione non ancora caricata"
        if WowManagerMountDumpDB and (WowManagerMountDumpDB.presi or 0) > 0 then
            print(("|cffff2020WowManagerMountDump: %s -- tengo il dump di %s (%d mount). Rilancia fra un minuto.|r")
                :format(avviso, tostring(WowManagerMountDumpDB.generated), WowManagerMountDumpDB.presi))
            return
        end
        print("|cffff2020WowManagerMountDump: " .. avviso .. ". NON sincronizzare.|r")
        WowManagerMountDumpDB = {
            generated = date("%Y-%m-%d %H:%M:%S"),
            sospetto = avviso .. ": nessuna mount risulta collezionata. NON sincronizzare.",
            presi = presi, totale = #voci,
        }
        return
    end

    local parti = {}
    for i, v in ipairs(voci) do parti[i] = "    " .. v.json end

    WowManagerMountDumpDB = {
        generated = date("%Y-%m-%d %H:%M:%S"),
        sospetto = nil,          -- nil = dump buono. Se valorizzato, NON sincronizzare.
        presi = presi, totale = #voci,
        build = GetBuildInfo(),
        mountsJson = "[\n" .. table.concat(parti, ",\n") .. "\n  ]",
        sorgentiJson = SorgentiJson(),  -- indice sourceType -> etichetta, presa dal client
        tipi = tipi,             -- mountTypeID -> quante mount, per vedere cosa esiste
        tipiIgnoti = tipiIgnoti, -- mountTypeID non in CAT -> nomi d'esempio da classificare
        scartate = scartate,     -- segnaposto di Blizzard tolti dall'elenco
        residui = residui,       -- provenienze con markup non riconosciuto (dovrebbe essere vuoto)
        api = ApiNames(),        -- funzioni C_MountJournal davvero esposte
    }

    print(("|cff33ff99WowManagerMountDump|r: %d mount lette, %d collezionate, %d segnaposto scartati. /reload per scrivere il file.")
        :format(#voci, presi, #scartate))
end

SLASH_WMMOUNT1 = "/wmmount"
SlashCmdList["WMMOUNT"] = Dump

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
