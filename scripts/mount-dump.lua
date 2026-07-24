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

-- NIENTE mappa mountTypeID -> categoria scritta a mano. Ce n'era una, dedotta dai
-- nomi e da una wiki, e sbagliava: dava 424 = skyriding, cioe' 708 volanti normali
-- nella chip sbagliata. Ora la mappa si IMPARA dal gioco (vedi ImparaTipi): il
-- diario classifica le mount che vede, e da quelle si ricava che categoria ha ogni
-- mountTypeID. Cio' che resta senza categoria resta "?", non si tira a indovinare.

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

-- ⚠️ REQUISITI DI CLASSE: NON provare a leggerli dal client, e' gia' stato fatto.
-- L'idea era il tooltip della spell (C_TooltipInfo.GetSpellByID + SurfaceArgs),
-- cercando le righe "Requires ...". MISURATO su tutte le 1532 mount: zero requisiti
-- trovati E zero righe "Requires" non riconosciute, cioe' quelle righe nel tooltip
-- di gioco non esistono proprio. La provenienza non aiuta: cita una classe in 23
-- casi su 1532. Il requisito lo da' Wowhead, e lo legge mount-sync.ps1 dallo stesso
-- endpoint da cui prende l'icona (blocco `wowhead-tooltip-requirements`).
-- La RAZZA non la sa nessuna delle due fonti: per le cavalcature razziali dei
-- paladini Wowhead dichiara solo "Requires Paladin".

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

-- Indice del filtro "Type" del diario -> chiave usata dal sito.
--
-- ⚠️ Gli indici NON si indovinano dall'ordine del menu: e' gia' costato due errori.
-- Il 5 sembrava "Ride Along" perche' il menu mostra quella voce per quarta, ma le 14
-- mount che contiene sono i draghi personalizzabili (Renewed Proto-Drake, Highland
-- Drake, i Delver's...): e' SKYRIDING. Si guarda cosa c'e' dentro, non come si
-- chiama la voce -- per questo il dump riporta in `filtriEsempi` i primi nomi di
-- ogni indice.
--
-- Si prova ogni indice anche quando IsValidTypeFilter dice di no (l'indice 4 lo
-- dichiara, ma costa nulla chiederglielo lo stesso): se un giorno risponde, la
-- categoria arriva gratis invece di restare "Altro".
local TIPO_FILTRO = {
    [1] = "terra", [2] = "volo", [3] = "acqua",
    [4] = "passeggero",   -- Ride Along: oggi si dichiara non valido e non risponde
    [5] = "skyriding",    -- i draghi personalizzabili, 14 in Midnight
}

-- Categorie che dipendono dal TIPO della cavalcatura, e che quindi il dizionario
-- imparato puo' estendere alle mount nascoste al personaggio loggato.
-- ⚠️ "passeggero" resta fuori: e' una proprieta' della singola mount (un mammut da
-- carico ha lo stesso mountTypeID di uno normale), quindi estenderla per tipo
-- marcherebbe come passeggero tutte le mount di quel tipo.
local CAT_DA_TIPO = { terra = true, volo = true, acqua = true, skyriding = true }

-- LE CATEGORIE LE DA' IL GIOCO, non si deducono.
-- Il diario ha i suoi filtri per tipo, gli stessi quattro che si vedono nel menu, e
-- l'API per pilotarli: si accende un tipo alla volta e si legge chi resta in elenco.
-- E' l'unica strada autorevole -- il mountTypeID e' un numero senza documentazione, e
-- dedurlo aveva gia' portato a mettere 708 volanti sotto "skyriding".
--
-- ⚠️ Si toccano i filtri del giocatore, quindi si salva e si rimette tutto: per tipi,
-- sorgenti e stato "collezionate" esistono i getter (IsTypeChecked, IsSourceChecked,
-- GetCollectedFilterSetting). L'unico senza getter e' la ricerca testuale, che va
-- azzerata per forza (una ricerca attiva nasconderebbe mount e falserebbe tutto): se
-- avevi del testo scritto nel diario, lo ritrovi da riscrivere.
--
-- Una mount puo' stare in PIU' categorie (una volante che porta passeggeri e' in
-- "volo" e in "passeggero"), quindi il risultato e' una lista, non un valore solo.
local function CategorieDalDiario()
    local J = C_MountJournal
    if not (J.SetTypeFilter and J.IsTypeChecked and J.GetNumDisplayedMounts and J.GetDisplayedMountID) then
        return nil, {}, "API dei filtri assente"
    end

    -- Si prova OGNI indice noto, valido o no: IsValidTypeFilter serve solo a sapere
    -- se lo stato attuale va salvato, non a decidere se interrogarlo.
    local salvaTipi, salvaSorg, salvaColl, tipi = {}, {}, {}, {}
    for i = 1, 8 do
        tipi[#tipi + 1] = i
        local ok, valido = pcall(J.IsValidTypeFilter, i)
        if ok and valido then
            local ok2, stato = pcall(J.IsTypeChecked, i)
            if ok2 then salvaTipi[i] = stato end
        end
    end
    for i = 1, 24 do
        local ok, valido = pcall(J.IsValidSourceFilter, i)
        if ok and valido then salvaSorg[i] = J.IsSourceChecked(i) end
    end
    for i = 1, 3 do
        local ok, v = pcall(J.GetCollectedFilterSetting, i)
        if ok then salvaColl[i] = v end
    end

    -- Tutto visibile: non collezionate e "non utilizzabili" comprese, altrimenti
    -- restano fuori dall'elenco e non vengono classificate.
    for i, _ in pairs(salvaColl) do J.SetCollectedFilterSetting(i, true) end
    J.SetAllSourceFilters(true)
    pcall(J.SetSearch, "")

    local perMount, conta, esempi = {}, {}, {}
    for _, t in ipairs(tipi) do
        J.SetAllTypeFilters(false)
        if pcall(J.SetTypeFilter, t, true) then
            local n = J.GetNumDisplayedMounts() or 0
            conta[t] = n
            for j = 1, n do
                local id = J.GetDisplayedMountID(j)
                if id then
                    perMount[id] = perMount[id] or {}
                    perMount[id][#perMount[id] + 1] = TIPO_FILTRO[t] or ("tipo" .. t)
                    -- Tre nomi per indice: e' cosi' che si controlla l'accoppiamento
                    -- indice/categoria, invece di fidarsi dell'ordine del menu.
                    local ex = esempi[t] or {}
                    if #ex < 3 then
                        ex[#ex + 1] = (C_MountJournal.GetMountInfoByID(id))
                        esempi[t] = ex
                    end
                end
            end
        end
    end

    -- Rimettere le cose com'erano, nell'ordine inverso.
    J.SetAllTypeFilters(false)
    for i, v in pairs(salvaTipi) do J.SetTypeFilter(i, v) end
    for i, v in pairs(salvaSorg) do J.SetSourceFilter(i, v) end
    for i, v in pairs(salvaColl) do J.SetCollectedFilterSetting(i, v) end

    return perMount, conta, nil, esempi
end

-- Le stringhe del menu filtri, cosi' com'e' scritto in gioco: servono a confermare
-- che l'indice 4 sia davvero "Ride Along" e non qualcos'altro.
local function EtichetteFiltri()
    local out = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" and k:find("^MOUNT_JOURNAL") then
            out[k] = v
        end
    end
    return out
end

-- Quali funzioni C_MountJournal esistono davvero: e' cosi' che si e' scoperto che i
-- filtri per tipo sono pilotabili (SetTypeFilter/GetDisplayedMountID) invece di
-- dover dedurre la categoria dal mountTypeID. Serve a saperlo senza indovinare.
local function ApiNames()
    local out = {}
    for k, v in pairs(C_MountJournal) do
        if type(v) == "function" then out[#out + 1] = k end
    end
    table.sort(out)
    return out
end

-- ⚠️ Il diario elenca solo le cavalcature VISIBILI al personaggio loggato: quelle
-- di un'altra fazione o di un'altra classe non compaiono, filtri o non filtri
-- (misurato: 1223 classificate su 1624). Quindi la classificazione diretta da sola
-- lascerebbe fuori centinaia di mount.
--
-- La toppa non e' una mappa scritta a mano -- gia' provata, gia' sbagliata -- ma
-- IMPARARLA: le mount che il diario classifica dicono che categoria ha ogni
-- mountTypeID, e quel dizionario copre anche le nascoste. Ogni voce viene comunque
-- dal gioco, nessuna deduzione da wiki.
--
-- Solo per le categorie di CAT_DA_TIPO: "passeggero" non dipende dal tipo (il mammut
-- da carico ha lo stesso tipo di uno normale), quindi non si estende per tipo e
-- resta noto per le sole mount che il diario mostra.
local function ImparaTipi(raccolta, ambigui)
    local conteggi = {}
    for _, r in ipairs(raccolta) do
        if r.cats and #r.cats > 0 then
            local base = {}
            for _, c in ipairs(r.cats) do
                if CAT_DA_TIPO[c] then base[#base + 1] = c end
            end
            if #base > 0 then
                table.sort(base)
                local chiave = table.concat(base, "+")
                conteggi[r.type] = conteggi[r.type] or {}
                conteggi[r.type][chiave] = (conteggi[r.type][chiave] or 0) + 1
            end
        end
    end

    local out = {}
    for tipo, combo in pairs(conteggi) do
        local migliore, quante, distinte = nil, -1, 0
        for chiave, n in pairs(combo) do
            distinte = distinte + 1
            if n > quante then migliore, quante = chiave, n end
        end
        -- Un tipo che classifica in due modi diversi e' sospetto: si sceglie il piu'
        -- frequente ma lo si dichiara, invece di nasconderlo.
        if distinte > 1 then
            local dett = {}
            for chiave, n in pairs(combo) do dett[#dett + 1] = chiave .. "=" .. n end
            table.sort(dett)
            ambigui[#ambigui + 1] = ("tipo %d: %s -> scelgo %s")
                :format(tipo, table.concat(dett, ", "), migliore)
        end
        local lista = {}
        for c in migliore:gmatch("[^+]+") do lista[#lista + 1] = c end
        out[tipo] = lista
    end
    return out
end

local function Dump()
    local voci, presi = {}, 0
    local tipi, scartate = {}, {}
    local senzaCat, tipiAmbigui = {}, {}
    local cop = { diario = 0, perTipo = 0, perNome = 0, niente = 0, nascosteScoperte = 0 }
    residui = {}

    local daDiario, contaFiltri, erroreFiltri, esempiFiltri = CategorieDalDiario()

    -- Passata 1: si raccoglie tutto, categorie comprese dove il diario le da'.
    local raccolta = {}
    for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
        local name, spellID, _, _, _, sourceType, _, isFactionSpecific, faction,
              shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(id)
        -- creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, ...
        -- `description` e' il testo di colore ("These beasts of burden are known
        -- to..."), diverso da `source` che e' la provenienza. Lo mostra la modale.
        -- `creatureDisplayInfoID` identifica il MODELLO: e' la chiave con cui si
        -- ritrova l'immagine della cavalcatura, che l'icona da sola non da'.
        local displayID, descrizione, source, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(id)
        if name and segnaposto(name) then
            scartate[#scartate + 1] = name
        elseif name then
            mountID = mountID or id
            tipi[mountTypeID or 0] = (tipi[mountTypeID or 0] or 0) + 1
            if isCollected then presi = presi + 1 end
            raccolta[#raccolta + 1] = {
                id = mountID, spell = spellID or 0, name = name,
                src = sourceType or 0, srcText = pulisci(source) or "",
                desc = pulisci(descrizione) or "",
                display = displayID or 0,
                type = mountTypeID or 0,
                nascosta = shouldHideOnChar and true or false,
                faction = isFactionSpecific and ((faction == 0) and "horde" or "alliance") or nil,
                got = isCollected and 1 or 0,
                cats = daDiario and daDiario[mountID] or nil,
            }
        end
    end

    -- Si impara il dizionario tipo -> categorie, poi lo si applica a chi e' rimasto
    -- fuori dall'elenco del diario.
    local perTipo = ImparaTipi(raccolta, tipiAmbigui)
    for _, r in ipairs(raccolta) do
        if r.cats and #r.cats > 0 then
            cop.diario = cop.diario + 1
        else
            local dal = perTipo[r.type]
            if dal and #dal > 0 then
                r.cats = dal
                cop.perTipo = cop.perTipo + 1
                if r.nascosta then cop.nascosteScoperte = cop.nascosteScoperte + 1 end
            end
        end
    end

    -- Ultimo anello: eredita da un OMONIMO gia' classificato.
    -- Il diario tiene piu' record per la stessa cavalcatura: `Cliffside Wylderdrake`
    -- esiste come mountID 1591 (tipo 402, classificato volo+skyriding) e come 1788
    -- (tipo 426, invisibile e senza categoria), con la stessa identica provenienza.
    -- Senza questo passaggio lo stesso drago compare sia in Skyriding sia in «Altro».
    -- ⚠️ NON e' una deduplicazione: i doppioni restano due voci -- e devono, perche'
    -- altri omonimi sono mount davvero diverse (il `Black War Bear` di For The
    -- Alliance! e quello di For The Horde!). Si copia la sola categoria.
    local perNome = {}
    for _, r in ipairs(raccolta) do
        if r.cats and #r.cats > 0 and not perNome[r.name] then perNome[r.name] = r.cats end
    end
    for _, r in ipairs(raccolta) do
        if not r.cats or #r.cats == 0 then
            local dal = perNome[r.name]
            if dal then
                r.cats = dal
                cop.perNome = cop.perNome + 1
            else
                r.cats = {}
                cop.niente = cop.niente + 1
                if #senzaCat < 20 then
                    senzaCat[#senzaCat + 1] = ("%s (tipo %d)"):format(r.name, r.type)
                end
            end
        end
    end

    -- Passata 2: serializzazione.
    for _, r in ipairs(raccolta) do
        local catsJson = {}
        for i, c in ipairs(r.cats) do catsJson[i] = '"' .. c .. '"' end
        voci[#voci + 1] = {
            name = r.name,
            -- `class` non c'e': non e' un dato del client. Lo aggiunge mount-sync.ps1
            -- leggendolo da Wowhead, insieme al nome dell'icona.
            json = ('{"id":%d,"spell":%d,"display":%d,"name":"%s","src":%d,"srcText":"%s","desc":"%s","type":%d,"cats":[%s],"faction":%s,"got":%d}')
                :format(r.id, r.spell, r.display, esc(r.name), r.src, esc(r.srcText), esc(r.desc), r.type,
                    table.concat(catsJson, ","),
                    r.faction and ('"' .. r.faction .. '"') or "null", r.got),
        }
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
        scartate = scartate,     -- segnaposto di Blizzard tolti dall'elenco
        residui = residui,       -- provenienze con markup non riconosciuto (dovrebbe essere vuoto)
        api = ApiNames(),        -- funzioni C_MountJournal davvero esposte
        filtri = contaFiltri,    -- indice del filtro Type -> quante mount ci stanno
        filtriEsempi = esempiFiltri,  -- e i primi nomi: e' cosi' che si verifica l'accoppiamento
        filtriErrore = erroreFiltri,   -- valorizzato = il diario non ha classificato nulla
        filtriEtichette = EtichetteFiltri(),  -- le stringhe del menu, per confermare gli indici
        copertura = cop,         -- quante dal diario, quante dal tipo imparato, quante niente
        tipiImparati = perTipo,  -- il dizionario ricavato: mountTypeID -> categorie
        tipiAmbigui = tipiAmbigui,  -- tipi che classificano in piu' modi (dovrebbe essere vuoto)
        senzaCat = senzaCat,     -- mount rimaste senza nessuna categoria
    }

    print(("|cff33ff99WowManagerMountDump|r: %d mount, %d collezionate. Categorie: %d dal diario, %d dal tipo, %d da omonimo, %d senza. /reload per scrivere.")
        :format(#voci, presi, cop.diario, cop.perTipo, cop.perNome, cop.niente))
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
