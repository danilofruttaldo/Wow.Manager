-- WowManagerDump - il SOLO addon del repo che resta sempre caricato, e non calcola
-- niente: registra i comandi e carica il modulo giusto quando glielo chiedi.
--
-- Installazione: _retail_/Interface/AddOns/WowManagerDump/ con questo file
--   rinominato -> WowManagerDump.lua  +  scripts/WowManagerDump.toc (invariato).
-- ⚠️ E' un addon NUOVO: la prima volta serve il RIAVVIO del client, il /reload non lo
-- vede. Da li' in poi lo tengono aggiornato mount-sync.ps1 e transmog-sync.ps1 (§0).
--
-- ── Perche' esiste ────────────────────────────────────────────────────────────
-- I dump (tier, mount, cvar -- e prof finche' c'e' stato) sono attrezzi da
-- manutenzione: servono
-- quando sincronizzo il sito, cioe' qualche volta al mese. Restando addon normali
-- pero' li pagavo a OGNI sessione, senza usarli:
--   * 95 KB di Lua compilati a ogni login;
--   * 2,6 MB di SavedVariables letti al login e tenuti in memoria per tutta la
--     sessione (misurato: tier 1561 KB, mount 596, prof 271, cvar 193);
--   * e gli stessi 2,6 MB riscritti su disco a OGNI /reload e a ogni uscita, anche
--     quando il dump non era stato ricalcolato -- WoW versa quel che sta in memoria.
--
-- Dichiarandoli `LoadOnDemand` nel .toc quel conto sparisce: un addon non caricato
-- non compila codice, non gli si legge il SavedVariables e non glielo si riscrive.
-- ⚠️ Ma un addon LoD non puo' registrare un comando che non ha ancora caricato:
-- serve qualcuno di sempre presente che lo faccia al posto suo, ed e' questo file.
-- Costa il suo caricamento (pochi KB) e un SavedVariables di poche righe.
--
-- ⚠️ I comandi restano gli stessi (/wmtier /wmmount /wmcvar): gli script di
-- sync li chiedono per nome, e non devono accorgersi di nulla. Ogni modulo continua
-- a registrarsi il proprio comando SE questo lanciatore non c'e' (vedi in fondo ai
-- moduli), cosi' un modulo caricato a mano resta utilizzabile da solo.

local MODULI = {
    tier  = { addon = "WowManagerTierDump",  run = "WowManagerTierDump_Run" },
    mount = { addon = "WowManagerMountDump", run = "WowManagerMountDump_Run" },
    cvar  = { addon = "WowManagerCVarDump",  run = "WowManagerCVarDump_Run" },
}

-- Le globali LoadAddOn/IsAddOnLoaded sono state spostate in C_AddOns: si prende
-- quella che c'e' invece di dare per buona una delle due.
local Carica   = (C_AddOns and C_AddOns.LoadAddOn)     or LoadAddOn
local Caricato = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

-- ⚠️ LoadAddOn e' SINCRONA e il SavedVariables del modulo e' gia' popolato quando
-- ritorna: le guardie dei dump ("c'e' gia' un dump buono, non lo sovrascrivo")
-- leggono la loro DB e la trovano. Percio' il runner si puo' chiamare subito dopo.
local function Esegui(chiave, msg)
    local m = MODULI[chiave]
    if not Caricato(m.addon) then
        -- LoadAddOn non solleva errore per un addon disabilitato: risponde nil piu'
        -- il motivo. Servono tutti e due i controlli.
        local ok, caricato, motivo = pcall(Carica, m.addon)
        if not ok or not caricato then
            print(("|cffff2020WowManagerDump|r: %s non si carica (%s). E' abilitato nella lista addon?")
                :format(m.addon, tostring(ok and motivo or caricato)))
            return
        end
    end
    local f = _G[m.run]
    if type(f) ~= "function" then
        print(("|cffff2020WowManagerDump|r: %s caricato ma %s non esiste. Copia del modulo indietro rispetto al repo?")
            :format(m.addon, m.run))
        return
    end
    return f(msg)
end

SLASH_WMTIER1  = "/wmtier"
SlashCmdList["WMTIER"]  = function(msg) Esegui("tier", msg) end
SLASH_WMMOUNT1 = "/wmmount"
SlashCmdList["WMMOUNT"] = function(msg) Esegui("mount", msg) end
SLASH_WMCVAR1  = "/wmcvar"
SlashCmdList["WMCVAR"]  = function(msg) Esegui("cvar", msg) end

-- ── Mount: la collezione che cambia davvero ───────────────────────────────────
-- ⚠️ L'unico innesco automatico dei dump di collezione, e resta qui invece che nel
-- modulo perche' il modulo non e' caricato: se l'evento lo aspettasse lui non
-- scatterebbe mai. NEW_MOUNT_ADDED capita qualche volta al mese -- il gemello
-- transmog un innesco l'ha avuto e gli e' stato tolto, perche' li' gli eventi
-- scattano a ogni apparenza e il ricalcolo gira su 11403 pezzi.
--
-- ⚠️ Il ritardo non e' un dettaglio: imparare una cavalcatura fa scattare l'evento
-- piu' volte. Si programma UN ricalcolo dopo la raffica, non uno per evento. E se il
-- diario delle collezioni e' APERTO si rimanda: quel dump accende e spegne i filtri
-- per tipo e azzera la ricerca testuale, cioe' ti cambierebbe sotto gli occhi la
-- finestra che stai usando.
local ATTESA = 30
local programmato = false
local function ProgrammaMount()
    if programmato then return end
    programmato = true
    C_Timer.After(ATTESA, function()
        programmato = false
        if CollectionsJournal and CollectionsJournal:IsShown() then
            ProgrammaMount()
            return
        end
        Esegui("mount")
    end)
end

-- ── Professioni per personaggio ───────────────────────────────────────────────
-- ⚠️ Questa riga NON e' piu' una cache: e' il DATO. Il modulo che leggeva gli alberi
-- (WowManagerProfDump, /wmprof) e' stato rimosso il 2026-09-05 -- era servito a
-- popolare professions/trees.json, che e' completo (11 alberi su 11) -- ma la firma
-- che decideva se lanciarlo resta, perche' contiene i NOMI delle professioni di ogni
-- PG ed e' da qui che professions/characters.json prende le icone professione della
-- tabella PG. Toglierla congelerebbe quel dato per ogni personaggio nuovo.
--
-- Costa solo chiamate trascurabili (le professioni note e il configID di ogni skill
-- line) e si scrive solo quando cambia. ⚠️ Il configID resta dentro perche' dice
-- "questa professione e' speccata": e' l'informazione che alimenta `midnightSpecs`,
-- ed e' l'unica traccia rimasta di quali alberi si potrebbero rigenerare -- il
-- modulo si ripesca dalla storia git.
local function FirmaProf()
    local pezzi = {}
    for i = 1, select("#", GetProfessions()) do
        local idx = select(i, GetProfessions())
        if idx then
            local nome, _, _, _, _, _, linea = GetProfessionInfo(idx)
            if linea then pezzi[#pezzi + 1] = ("p%s:%d"):format(tostring(nome), linea) end
        end
    end
    -- ⚠️ Nessuna professione letta = firma VUOTA, e si esce subito: le skill line
    -- speccate qui sotto da sole basterebbero a farla sembrare piena, e una firma
    -- piena e' una firma che si registra. Se i dati del PG non sono ancora arrivati,
    -- registrarla vorrebbe dire archiviare una lettura a vuoto come "gia' fatto".
    if #pezzi == 0 then return "" end
    if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_ProfSpecs
        and C_ProfSpecs.GetConfigIDForSkillLine then
        local ok, tutte = pcall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
        if ok and type(tutte) == "table" then
            for _, linea in ipairs(tutte) do
                local okc, cfg = pcall(C_ProfSpecs.GetConfigIDForSkillLine, linea)
                if okc and type(cfg) == "number" and cfg ~= 0 then
                    pezzi[#pezzi + 1] = ("s%d"):format(linea)
                end
            end
        end
    end
    table.sort(pezzi)
    return table.concat(pezzi, "|")
end

-- ⚠️ Firma vuota = dati del PG non ancora arrivati (oppure un PG senza professioni):
-- in entrambi i casi NON si registra nulla, altrimenti una lettura a vuoto si
-- fisserebbe come "gia' fatto". Un solo riprova dopo 20s, poi si tace -- quindi un PG
-- entra nel registro solo restando loggato una trentina di secondi.
local function ControllaProf(riprova)
    local firma = FirmaProf()
    if firma == "" then
        if riprova then C_Timer.After(20, function() ControllaProf(false) end) end
        return
    end
    local pg = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    WowManagerDumpDB = WowManagerDumpDB or {}
    WowManagerDumpDB.firmaProf = WowManagerDumpDB.firmaProf or {}
    if WowManagerDumpDB.firmaProf[pg] == firma then return end
    WowManagerDumpDB.firmaProf[pg] = firma
end

-- ⚠️ RegisterEvent su un nome che il client non conosce solleva errore, e un errore
-- qui vorrebbe dire lanciatore non caricato, cioe' nessun comando affatto -- molto
-- peggio del problema che l'automatismo risolve.
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, evento)
    if evento == "NEW_MOUNT_ADDED" then
        ProgrammaMount()
    elseif evento == "PLAYER_LOGIN" then
        C_Timer.After(5, function() ControllaProf(true) end)
    end
end)
f:RegisterEvent("PLAYER_LOGIN")
if not pcall(f.RegisterEvent, f, "NEW_MOUNT_ADDED") then
    print("|cffffcc00WowManagerDump|r: NEW_MOUNT_ADDED non riconosciuto, resta /wmmount.")
end
