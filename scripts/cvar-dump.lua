-- WowManagerCVarDump -- fotografa TUTTE le impostazioni (CVar) del client.
--
-- In gioco:
--   /wmcvar              riscrive il dump e dice quante sono fuori dal default
--   /wmcvar <parola>     cerca in chat fra nome, categoria e testo d'aiuto
--
-- Il dump si rigenera anche su PLAYER_LOGOUT, quindi basta UN /reload; il
-- /wmcvar serve solo per vederlo subito. Due reload dopo aver modificato questo
-- file: il primo scrive ancora col codice vecchio.
-- SavedVariables: WTF/Account/<ACC>/SavedVariables/WowManagerCVarDump.lua
--
-- Valore e default arrivano da DUE chiamate a un solo ritorno (GetCVar e
-- GetCVarDefault) invece che dai sette ritorni di GetCVarInfo: cosi' la coppia
-- valore/default non dipende dall'ordine dei ritorni, che e' facile sbagliare.
-- Dall'ordine dipendono i soli flag di scope, che sono informativi.
--
-- Ogni riga e' testo con separatore " ~|~ ". Nei campi le virgolette diventano
-- apostrofi, i ritorni a capo spazi e i backslash barre: cosi' il file NON ha
-- escape da sciogliere a valle (il doppio-escape che gli altri dump del repo si
-- portano dietro). Il prezzo e' che l'aiuto non e' verbatim al carattere.

local SEP = " ~|~ "

local function Pulisci(s)
  if s == nil then return "" end
  s = tostring(s)
  s = s:gsub("[\r\n\t]", " ")
  s = s:gsub('"', "'")
  s = s:gsub("\\", "/")
  s = s:gsub("~|~", "/")
  return s
end

-- Un comando della console e' un CVar se GetCVar risponde: non ci si fida di
-- commandType, il cui enum non e' garantito fra le patch.
local function Raccogli()
  local righe, tot, diversi = {}, 0, 0
  local cmds = ConsoleGetAllCommands and ConsoleGetAllCommands() or {}
  for _, c in ipairs(cmds) do
    local nome = c.command
    if nome and nome ~= "" then
      local okv, v = pcall(C_CVar.GetCVar, nome)
      if okv and v ~= nil then
        tot = tot + 1
        local okd, def = pcall(C_CVar.GetCVarDefault, nome)
        local d = (okd and def ~= nil) and tostring(def) or ""
        local val = tostring(v)
        local diverso = (val ~= d) and 1 or 0
        if diverso == 1 then diversi = diversi + 1 end
        local srvA, srvC, ro = "", "", ""
        local oki, _, _, a, ch, _, _, r = pcall(C_CVar.GetCVarInfo, nome)
        if oki then
          srvA = a and 1 or 0
          srvC = ch and 1 or 0
          ro = r and 1 or 0
        end
        righe[#righe + 1] = table.concat({
          Pulisci(nome), Pulisci(val), Pulisci(d), diverso,
          srvA, srvC, ro, Pulisci(c.category), Pulisci(c.help),
        }, SEP)
      end
    end
  end
  table.sort(righe)
  return righe, tot, diversi
end

local function Scrivi(zitto)
  local righe, tot, diversi = Raccogli()

  -- Stessa guardia degli altri dump: una lettura a vuoto e' internamente
  -- coerente e a valle nessuno la distingue da una buona, quindi non si
  -- sovrascrive un dump valido con zero righe.
  if tot == 0 then
    if type(WowManagerCVarDump) == "table" and (WowManagerCVarDump.totali or 0) > 0 then
      print("|cffff5555WowManagerCVarDump: zero CVar letti, dump buono NON sovrascritto.|r")
      return
    end
  end

  WowManagerCVarDump = {
    data = date("%Y-%m-%d %H:%M:%S"),
    build = select(2, GetBuildInfo()),
    pg = (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?"),
    totali = tot,
    diversi = diversi,
    campi = table.concat({ "nome", "valore", "default", "diverso",
      "srvAccount", "srvChar", "soloLettura", "categoria", "aiuto" }, SEP),
    righe = righe,
  }

  if not zitto then
    print(("|cff88ff88WowManagerCVarDump|r: %d CVar, %d fuori dal default. Dump scritto al logout/reload.")
      :format(tot, diversi))
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function() Scrivi(true) end)

SLASH_WMCVAR1 = "/wmcvar"
SlashCmdList["WMCVAR"] = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" then
    Scrivi(false)
    return
  end
  local q = msg:lower()
  local righe = Raccogli()
  local n = 0
  for _, r in ipairs(righe) do
    if r:lower():find(q, 1, true) then
      n = n + 1
      if n <= 25 then
        local nome, val, def = r:match("^(.-) ~|~ (.-) ~|~ (.-) ~|~")
        print(("|cff88ff88%s|r = %s   (default %s)"):format(nome, val, def == "" and "?" or def))
      end
    end
  end
  print(("WowManagerCVarDump: %d risultati per '%s'%s"):format(n, msg, n > 25 and " (mostrati i primi 25)" or ""))
end
