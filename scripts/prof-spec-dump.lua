-- WowManagerProfDump - addon locale, NON pubblico. Gemello di WowManagerTierDump
-- (scripts/transmog-tier-dump.lua), ma per gli ALBERI DI SPECIALIZZAZIONE delle
-- professioni: C_ProfSpecs / C_Traits. Estrae, per ogni professione leggibile dal
-- PG loggato, il nome esatto di ogni nodo, la descrizione, il RANK MASSIMO (i punti
-- che entrano nel nodo), il rank gia' speso e i figli di ogni nodo.
--
-- Perche' in gioco e non dal web: il rank massimo -- il numero che serve a dire
-- "quanti punti mettere" -- nessuna pagina lo pubblica. Il client si'. E la struttura
-- padre-figlio viene dal gioco (visibleEdges), non dedotta dagli ID.
--
-- ⚠️ PER PERSONAGGIO. Gli alberi COMPLETI (nodi + cap) escono solo per le professioni
-- che il PG ha imparato; per le altre si ottiene il solo nome delle spec di primo
-- livello. Per coprirle tutte, lancia su piu' PG e unisci i dump.
--
-- ⚠️ Ogni professione ha un albero PER ESPANSIONE (Dragonflight, TWW, Midnight...):
-- per questo ogni tree porta `professionInfo` con `expansionName`. Al momento di
-- scrivere il manifest si tiene la sola riga Midnight.
--
-- Installazione (addon NUOVO -> RIAVVIO del client la prima volta; dopo basta /reload):
--   _retail_/Interface/AddOns/WowManagerProfDump/WowManagerProfDump.lua  (questo file)
--   _retail_/Interface/AddOns/WowManagerProfDump/WowManagerProfDump.toc
--
-- ⚠️ E' un addon `LoadOnDemand`: lo carica il lanciatore WowManagerDump (vedi
-- scripts/dump-launcher.lua) quando dai /wmprof, oppure al login SE le professioni
-- del PG sono cambiate rispetto all'ultimo dump. Prima girava a ogni PLAYER_LOGIN --
-- che scatta anche a ogni /reload -- e quindi ripercorreva gli alberi per riscrivere
-- quasi sempre lo stesso file: la firma che decide sta nel lanciatore perche' va
-- calcolata senza caricare nulla.
--
-- Uso: /wmprof poi /reload (o logout) -> scrive
--   WTF/Account/<ACC>/SavedVariables/WowManagerProfDump.lua
--   Da li' si legge il campo `json`, gia' pulito e ordinato.
--   /wmprof tutto  percorre ANCHE gli alberi senza configID e riscrive i campi
--   diagnostici (`trees` grezzo, `api`) -- vedi il perche' in fondo a Dump.

-- ── Utility ────────────────────────────────────────

local function ApiNames(...)
    local out = {}
    for _, ns in ipairs({ ... }) do
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

-- JSON minimale con chiavi ordinate: due dump si confrontano con un diff pulito.
local ESC = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
local function esc(s)
    return (tostring(s):gsub('[%z\1-\31\\"]', function(c)
        return ESC[c] or string.format('\\u%04x', c:byte())
    end))
end
local function toJson(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        return (v == math.floor(v)) and string.format("%d", v) or tostring(v)
    elseif t == "boolean" then return v and "true" or "false"
    elseif t == "string" then return '"' .. esc(v) .. '"'
    elseif t == "table" then
        local n, isArr = 0, true
        for k in pairs(v) do n = n + 1; if type(k) ~= "number" then isArr = false end end
        if n == 0 then return "{}" end
        local ni = indent .. "  "
        if isArr then
            local parts = {}
            for i = 1, #v do parts[i] = ni .. toJson(v[i], ni) end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts + 1] = ni .. '"' .. esc(k) .. '": ' .. toJson(v[k], ni)
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    end
    return '"<' .. t .. '>"'
end

-- ── Nodo: nome, descrizione, cap, figli ────────────

-- Il nome/descrizione di un nodo stanno sulla ENTRY -> DEFINITION -> spell; il cap
-- (maxRanks) sta sulla entry. Un nodo ha PIU' entry: quella di progressione (il cap
-- vero, es. 50) e il perk di sblocco (maxRanks 1). Si tiene il nome condiviso e il
-- maxRanks PIU' ALTO -- il perk a 1 e' rumore per l'infografica.
local function ResolveNode(configID, node)
    local name, desc, maxRanks, spellID
    for _, eid in ipairs(node.entryIDs or {}) do
        local ok, entry = pcall(C_Traits.GetEntryInfo, configID, eid)
        if ok and type(entry) == "table" then
            if entry.maxRanks and (not maxRanks or entry.maxRanks > maxRanks) then
                maxRanks = entry.maxRanks
            end
            local defID = entry.definitionID
            if defID then
                local ok2, def = pcall(C_Traits.GetDefinitionInfo, defID)
                if ok2 and type(def) == "table" then
                    if not name or name == "" then
                        name = def.overrideName
                        if (not name or name == "") and def.spellID and C_Spell then
                            local okS, si = pcall(C_Spell.GetSpellInfo, def.spellID)
                            if okS and type(si) == "table" then name = si.name end
                            spellID = def.spellID
                        end
                    end
                    if (not desc or desc == "") then
                        desc = def.overrideDescription
                        if (not desc or desc == "") and def.spellID and C_Spell
                            and C_Spell.GetSpellDescription then
                            local okD, d = pcall(C_Spell.GetSpellDescription, def.spellID)
                            if okD and d and d ~= "" then desc = d end
                        end
                    end
                end
            end
        end
    end
    return name, desc, maxRanks, spellID
end

-- I figli di un nodo: il gioco li da' in visibleEdges[].targetNode. Struttura vera,
-- non dedotta dalla contiguita' degli ID come nei tentativi via Wowhead.
local function Children(node)
    local out = {}
    for _, e in ipairs(node.visibleEdges or {}) do
        if e.targetNode then out[#out + 1] = e.targetNode end
    end
    return out
end

local function WalkNode(configID, nodeID, seen, out)
    if not nodeID or seen[nodeID] then return end
    seen[nodeID] = true
    local ok, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
    if ok and type(node) == "table" then
        local name, desc, maxRanks, spellID = ResolveNode(configID, node)
        local kids = Children(node)
        out[#out + 1] = {
            nodeID = nodeID,
            name = name,
            desc = desc,
            maxRanks = maxRanks,
            spentRanks = node.activeRank or node.ranksPurchased or 0,
            spellID = spellID,
            children = kids,
        }
        for _, kid in ipairs(kids) do WalkNode(configID, kid, seen, out) end
        -- Backup: alcuni figli possono non essere in visibleEdges.
        local okc, extra = pcall(C_ProfSpecs.GetChildrenForPath, nodeID)
        if okc and type(extra) == "table" then
            for _, kid in ipairs(extra) do WalkNode(configID, kid, seen, out) end
        end
    else
        -- Albero senza configID (professione non del PG): niente rank, ma il nodo e
        -- la sua discendenza restano utili per la struttura.
        out[#out + 1] = { nodeID = nodeID, noConfig = true }
        local okc, extra = pcall(C_ProfSpecs.GetChildrenForPath, nodeID)
        if okc and type(extra) == "table" then
            for _, kid in ipairs(extra) do WalkNode(configID, kid, seen, out) end
        end
    end
end

-- ── Dump ───────────────────────────────────────────

local function Dump(tutto)
    local t0 = debugprofilestop()
    local db = {
        generated = date("%Y-%m-%d %H:%M:%S"),
        build = GetBuildInfo(),
        character = (UnitName("player")) .. "-" .. (GetRealmName() or "?"),
        knownProfessions = {},
        trees = {},
        notes = {},
    }
    -- L'elenco delle funzioni esposte serve quando un'API sparisce o cambia nome, cioe'
    -- a diagnosi, non a ogni dump: pesa 10 KB dentro `json`, e `json` e' il campo che
    -- si legge a mano.
    if tutto then
        db.api = {
            ProfSpecs = ApiNames("C_ProfSpecs"),
            Traits = ApiNames("C_Traits"),
            TradeSkillUI = ApiNames("C_TradeSkillUI"),
        }
    end

    -- GetProfessions() ritorna nil negli slot vuoti: `ipairs` si fermerebbe al primo nil
    -- saltando le professioni negli slot successivi. Si scandisce per indice con select.
    for i = 1, select('#', GetProfessions()) do
        local idx = select(i, GetProfessions())
        if idx then
            local name, _, _, _, _, _, skillLine = GetProfessionInfo(idx)
            if skillLine then
                db.knownProfessions[#db.knownProfessions + 1] = { name = name, skillLine = skillLine }
            end
        end
    end

    local candidateLines, seenLine = {}, {}
    local function addLine(l)
        if l and not seenLine[l] then seenLine[l] = true; candidateLines[#candidateLines + 1] = l end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines then
        local ok, all = pcall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
        if ok and type(all) == "table" then for _, l in ipairs(all) do addLine(l) end end
    end
    for _, p in ipairs(db.knownProfessions) do addLine(p.skillLine) end

    if not C_ProfSpecs then
        db.notes[#db.notes + 1] = "C_ProfSpecs assente: API rinominata? Vedi `api`."
    end

    for _, line in ipairs(candidateLines) do
        local tabs
        if C_ProfSpecs and C_ProfSpecs.GetSpecTabIDsForSkillLine then
            local ok, res = pcall(C_ProfSpecs.GetSpecTabIDsForSkillLine, line)
            if ok then tabs = res end
        end
        if type(tabs) == "table" and #tabs > 0 then
            local configID
            if C_ProfSpecs.GetConfigIDForSkillLine then
                local okc, cfg = pcall(C_ProfSpecs.GetConfigIDForSkillLine, line)
                if okc then configID = cfg end
            end
            -- professione + espansione: serve a tenere la sola riga Midnight fra le
            -- varie espansioni della stessa professione.
            local profInfo
            if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
                local okp, pi = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, line)
                if okp then profInfo = pi end
            end
            local tree = {
                skillLine = line,
                configID = configID,
                profession = profInfo and profInfo.professionName,
                expansion = profInfo and profInfo.expansionName,
                tabs = {},
            }
            for _, tabID in ipairs(tabs) do
                local tabInfo
                if C_ProfSpecs.GetTabInfo then
                    local okt, ti = pcall(C_ProfSpecs.GetTabInfo, tabID)
                    if okt then tabInfo = ti end
                end
                local tab = {
                    tabID = tabID,
                    name = tabInfo and tabInfo.name,
                    desc = tabInfo and tabInfo.description,
                    rootNodeID = tabInfo and tabInfo.rootNodeID,
                    nodes = {},
                }
                -- ⚠️ L'albero si percorre SOLO se la professione e' speccata su questa
                -- skill line (configID valido). Senza configID GetNodeInfo non risponde
                -- e ogni nodo esce come { nodeID, noConfig = true }: nessun nome,
                -- nessuna descrizione, nessun maxRanks -- cioe' proprio i tre dati per
                -- cui questo dump esiste. Misurato sul dump di ieri: 576 nodi vuoti
                -- contro 151 pieni, meta' abbondante del file e la gran parte del
                -- lavoro, per zero informazione. Il nome delle spec di primo livello
                -- resta comunque, perche' viene da `tab.name`, non dai nodi.
                -- Con `/wmprof tutto` si torna a percorrerli, se un giorno servisse.
                local usabile = configID and configID ~= 0
                if tabInfo and tabInfo.rootNodeID and (usabile or tutto) then
                    WalkNode(usabile and configID or nil, tabInfo.rootNodeID, {}, tab.nodes)
                end
                tree.tabs[#tree.tabs + 1] = tab
            end
            db.trees[#db.trees + 1] = tree
        end
    end

    if #db.trees == 0 then
        db.notes[#db.notes + 1] =
            "Nessun albero. O il PG non ha professioni con spec, o le API non combaciano: rifai con /wmprof tutto e guarda `api`."
    end

    -- ⚠️ Guardia anti-dump-vuoto (come il dump transmog). Se GetProfessions non ha
    -- risposto (knownProfessions vuoto), i dati del PG non erano ancora caricati --
    -- succede se si slogga/reloada troppo presto dopo il login: ogni config esce 0 e il
    -- dump sembra valido-ma-vuoto. Non si sovrascrive un dump buono precedente, e si urla.
    if #db.knownProfessions == 0 then
        db.sospetto = "letto a vuoto: knownProfessions vuoto, dati non ancora caricati. NON incollare, rifai /wmprof."
        if WowManagerProfDumpDB and WowManagerProfDumpDB.knownProfessions
            and #WowManagerProfDumpDB.knownProfessions > 0 then
            print(("|cffff2020WowManagerProfDump: letto a vuoto -- tengo il dump di %s (%d prof). Aspetta che i dati carichino e rifai /wmprof.|r")
                :format(tostring(WowManagerProfDumpDB.character), #WowManagerProfDumpDB.knownProfessions))
            return
        end
        WowManagerProfDumpDB = db
        WowManagerProfDumpDB.json = toJson(db, "")
        print("|cffff2020WowManagerProfDump: letto a vuoto (dati non caricati). Aspetta qualche secondo e rifai /wmprof prima del /reload.|r")
        return
    end

    -- ⚠️ `trees` NON si tiene come tabella: e' lo stesso dato che sta gia' dentro
    -- `json`, che e' il campo da cui si legge. Erano 100 KB di doppione su 271, riletti
    -- a ogni caricamento dell'addon e riscritti a ogni /reload. Con `/wmprof tutto`
    -- torna, per quando si vuole guardare la struttura senza sciogliere gli escape.
    local json = toJson(db, "")
    WowManagerProfDumpDB = {
        generated = db.generated,
        build = db.build,
        character = db.character,
        knownProfessions = db.knownProfessions,  -- lo legge la guardia qui sopra
        notes = db.notes,
        json = json,
    }
    if tutto then
        WowManagerProfDumpDB.trees = db.trees
        WowManagerProfDumpDB.api = db.api
    end

    local nNodes, nCap = 0, 0
    for _, tree in ipairs(db.trees) do
        for _, tab in ipairs(tree.tabs) do
            for _, node in ipairs(tab.nodes) do
                nNodes = nNodes + 1
                if node.maxRanks then nCap = nCap + 1 end
            end
        end
    end
    print(("|cff33ff99WowManagerProfDump|r: %s -- %d prof note, %d alberi, %d nodi (%d con cap) in %d ms%s. /reload per scrivere.")
        :format(db.character, #db.knownProfessions, #db.trees, nNodes, nCap,
            math.floor(debugprofilestop() - t0), tutto and " (tutto)" or ""))
end

-- Il punto d'ingresso per il lanciatore WowManagerDump.
function WowManagerProfDump_Run(msg)
    Dump(type(msg) == "string" and msg:lower():find("tutto", 1, true) ~= nil)
end

-- ⚠️ Il comando lo registra il lanciatore: qui si registra SOLO se non c'e'.
local Caricato = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
if not Caricato("WowManagerDump") then
    SLASH_WMPROF1 = "/wmprof"
    SlashCmdList["WMPROF"] = WowManagerProfDump_Run
end

-- ⚠️ NIENTE dump su PLAYER_LOGOUT: quell'evento scatta anche alla chiusura vera del
-- gioco, dove il client si sta gia' smontando, e da li' escono dump che sembrano
-- buoni ma hanno campi a nil (nel dump mount ci sono costate 1184 icone). Qui il
-- rischio e' lo stesso: `knownProfessions` vuoto lo intercetta la guardia qui sopra,
-- ma i `maxRanks` dei nodi -- i punti, cioe' il motivo per cui questo dump esiste --
-- potrebbero mancare mentre tutto il resto arriva, e nessuna guardia se ne
-- accorgerebbe.
--
-- ⚠️ Il dump al LOGIN invece resta, e non e' un'incoerenza con gli addon mount e
-- transmog, dove l'ho tolto. Li' fotografava la collezione all'ingresso e si perdeva
-- quel che prendevi durante la sessione; qui le professioni note e l'albero speccato
-- non cambiano mentre giochi, quindi lo scatto al login E' il dato. Ed e' anche il
-- modo in cui un alt entra nel tracker professioni: basta loggarlo, senza doversi
-- ricordare /wmprof su ognuno. Se cambi una spec a meta' sessione, /wmprof.
--
-- ⚠️ Ma l'evento non lo aggancia piu' questo file: un addon LoadOnDemand non e'
-- caricato quando PLAYER_LOGIN scatta, quindi un listener scritto qui non partirebbe
-- mai. Sta nel lanciatore (scripts/dump-launcher.lua), che al login calcola una FIRMA
-- delle professioni -- poche chiamate, senza caricare questo modulo -- e lo carica
-- solo se e' cambiata. Prima invece si ripercorrevano tutti gli alberi a ogni login E
-- a ogni /reload per riscrivere quasi sempre lo stesso identico dump.
