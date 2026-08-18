#Requires -Version 5.1
# Report delle impostazioni del client, per decidere cosa mettere nel preset di
# sync-game-settings.ps1.
#
#   .\scripts\settings-report.ps1            aspetta un dump nuovo (/reload in gioco)
#   .\scripts\settings-report.ps1 -Subito    usa il dump gia' sul disco
#   .\scripts\settings-report.ps1 -Md <path> scrive il report altrove
#
# Incrocia tre cose:
#   1. il dump dell'addon WowManagerCVarDump (/wmcvar): ogni CVar del client col
#      suo valore, il DEFAULT, la categoria e il testo d'aiuto che scrive il gioco.
#      L'addon e' LoadOnDemand: il comando lo registra il lanciatore WowManagerDump,
#      che lo carica al volo. Questo script non installa nulla -- gli addon li
#      allineano i due sync (mount e transmog, §0);
#   2. il preset di sync-game-settings.ps1, letto dal file (non duplicato qui);
#   3. i 53 config-cache.wtf per-PG, per dire su quanti PG una chiave e' presente
#      e con quanti valori diversi.
#
# Quello che serve leggere e' la sezione 2: le impostazioni che hai cambiato in
# gioco e che il preset NON propaga ancora.
param(
  [switch]$Subito,
  [int]$AttesaMax = 300,
  [string]$Md = (Join-Path $env:TEMP 'wow-impostazioni.md'),
  [string]$Wow = 'C:\Program Files (x86)\World of Warcraft'
)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$SEP = ' ~|~ '

function Errore($msg) { Write-Host "STOP: $msg" -ForegroundColor Red; exit 1 }

function TrovaDump {
  # Cercato, non scritto a mano: il percorso contiene il nome dell'account.
  return Get-ChildItem -Path (Join-Path $Wow '_retail_\WTF\Account') -Recurse `
    -Filter 'WowManagerCVarDump.lua' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -like '*SavedVariables*' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# ⚠️ La data del FILE non dice se il dump e' fresco: WoW riscrive il SavedVariables a
# ogni /reload e a ogni uscita, quindi senza /wmcvar riscrive gli stessi dati con una
# data di modifica nuova. Il campo `data` invece lo mette l'addon quando calcola.
function CalcolatoIl($file) {
  try {
    $t = Get-Content -Raw -Encoding UTF8 $file -ErrorAction Stop
    if ($t -match '\["?data"?\]\s*=\s*"([^"]+)"') { return $Matches[1] }
  } catch { }   # letto mentre il gioco lo stava scrivendo: si riprova al giro dopo
  return $null
}

# --- 1. il dump ------------------------------------------------------------------
$dump = TrovaDump
if (-not $dump) {
  Errore ("WowManagerCVarDump.lua non trovato. L'addon e' installato in " +
    "Interface\AddOns\WowManagerCVarDump? Un addon NUOVO non lo vede il /reload: " +
    "la prima volta serve riavviare il client.")
}
if (-not $Subito) {
  $prima = CalcolatoIl $dump.FullName
  Write-Host ''
  # Il comando PRIMA del /reload: /wmcvar calcola, il /reload scrive. L'addon non
  # rigenera piu' da solo (scattava su PLAYER_LOGOUT, che vale anche per la chiusura
  # del gioco), quindi un /reload da solo riscriverebbe gli stessi dati.
  Write-Host '  In gioco: /wmcvar poi /reload' -ForegroundColor Cyan
  Write-Host ("  (aspetto un dump nuovo, max {0}s - Ctrl+C per annullare)" -f $AttesaMax)
  $scaduto = (Get-Date).AddSeconds($AttesaMax)
  $ora = $prima
  while ((Get-Date) -lt $scaduto) {
    Start-Sleep -Seconds 2
    $dump = TrovaDump
    $ora = CalcolatoIl $dump.FullName
    if ($ora -and $ora -ne $prima) { break }
  }
  if (-not $ora -or $ora -eq $prima) {
    Errore ("nessun dump RICALCOLATO entro $AttesaMax secondi (data ferma a '{0}'). " -f $prima) +
      "Il /reload da solo riscrive gli stessi dati: serve /wmcvar prima. Oppure -Subito per usare quello che c'e'."
  }
  Write-Host '  dump ricevuto.' -ForegroundColor Green
}

$testo = Get-Content -LiteralPath $dump.FullName -Raw -Encoding UTF8
$meta = @{}
foreach ($k in @('data', 'pg', 'build')) {
  if ($testo -match ('\["' + $k + '"\]\s*=\s*"([^"]*)"')) { $meta[$k] = $matches[1] }
}
$totali = 0; $diversi = 0
if ($testo -match '\["totali"\]\s*=\s*(\d+)') { $totali = [int]$matches[1] }
if ($testo -match '\["diversi"\]\s*=\s*(\d+)') { $diversi = [int]$matches[1] }
if ($totali -le 0) { Errore "il dump dice $totali CVar: lettura a vuoto, rifai /reload" }

# Righe di testo, separatore " ~|~ ". Il dump ha gia' tolto virgolette e
# backslash dai campi, quindi non c'e' nessun escape da sciogliere.
$cvar = [ordered]@{}
foreach ($riga in ($testo -split "`r?`n")) {
  if ($riga -notmatch '"(.+)"\s*,?\s*$') { continue }
  $c = $matches[1]
  if ($c -notlike "*$SEP*") { continue }
  $f = $c -split ([regex]::Escape($SEP))
  if ($f.Count -lt 9) { continue }
  if ($f[0] -eq 'nome' -and $f[1] -eq 'valore') { continue }   # riga d'intestazione
  $cvar[$f[0]] = [pscustomobject]@{
    nome = $f[0]; valore = $f[1]; default = $f[2]; diverso = ($f[3] -eq '1')
    srvAccount = ($f[4] -eq '1'); srvChar = ($f[5] -eq '1'); soloLettura = ($f[6] -eq '1')
    categoria = $f[7]; aiuto = $f[8]
  }
}
if ($cvar.Count -eq 0) { Errore 'nessuna riga di CVar letta dal dump: formato inatteso' }

# --- 2. il preset, letto da sync-game-settings.ps1 --------------------------------
function LeggiBlocco($file, $nomeVar) {
  $val = [ordered]@{}
  $dentro = $false
  foreach ($l in (Get-Content -LiteralPath $file)) {
    if (-not $dentro) {
      if ($l -match ('^\s*\$' + $nomeVar + '\s*=\s*\[ordered\]@\{')) { $dentro = $true }
      continue
    }
    if ($l -match '^\s*\}\s*$') { break }
    if ($l -match "^\s*([A-Za-z0-9_]+)\s*=\s*'([^']*)'") { $val[$matches[1]] = $matches[2] }
  }
  return $val
}
$syncPs1 = Join-Path $PSScriptRoot 'sync-game-settings.ps1'
$preset = LeggiBlocco $syncPs1 'CharValues'
$presetAcc = LeggiBlocco $syncPs1 'AccountValues'
if ($preset.Count -eq 0) { Errore "preset non letto da $syncPs1 (il blocco CharValues e' cambiato di forma?)" }

# --- 3. i file per-PG -------------------------------------------------------------
$AccRoot = Join-Path $Wow '_retail_\WTF\Account'
$Acc = (Get-ChildItem -LiteralPath $AccRoot -Directory |
  Where-Object { $_.Name -ne 'SavedVariables' } | Select-Object -First 1).FullName
$accCache = Join-Path $Acc 'config-cache.wtf'
$files = Get-ChildItem -LiteralPath $Acc -Recurse -File -Filter 'config-cache.wtf' |
  Where-Object { $_.FullName -ne $accCache -and $_.FullName -notmatch '\\_backup-' }
$suiPg = @{}
foreach ($f in $files) {
  foreach ($l in (Get-Content -LiteralPath $f.FullName)) {
    if ($l -match '^SET (\S+) "(.*)"\s*$') {
      $k = $matches[1]
      if (-not $suiPg.ContainsKey($k)) { $suiPg[$k] = @{} }
      $suiPg[$k][$f.Directory.Name] = $matches[2]
    }
  }
}
function Copertura($nome) {
  if (-not $suiPg.ContainsKey($nome)) { return "-" }
  $v = $suiPg[$nome].Values
  $n = @($v).Count
  $d = @($v | Sort-Object -Unique).Count
  if ($d -gt 1) { return "$n PG / $d valori" }
  return "$n PG"
}

# --- 4. il report -----------------------------------------------------------------
$rep = New-Object System.Collections.Generic.List[string]
$rep.Add("# Impostazioni del client")
$rep.Add('')
$rep.Add("PG del dump: **$($meta['pg'])** - build $($meta['build']) - dump del $($meta['data'])")
$rep.Add('')
$rep.Add("CVar totali: **$totali**, fuori dal default: **$diversi**. Preset: **$($preset.Count)** chiavi per-PG + $($presetAcc.Count) account-wide.")
$rep.Add('')
$rep.Add('> Il valore mostrato e'' quello del PG del dump. La colonna *nei file* dice su quanti')
$rep.Add('> dei ' + $files.Count + ' config-cache.wtf la chiave compare e con quanti valori distinti:')
$rep.Add('> piu'' di un valore = i PG oggi divergono.')
$rep.Add('')

# Sezione 1: il preset
$rep.Add('## 1. Chiavi del preset')
$rep.Add('')
$rep.Add('| chiave | preset | sul PG | default | stato |')
$rep.Add('|---|---|---|---|---|')
foreach ($k in $preset.Keys) {
  $c = $cvar[$k]
  if (-not $c) { $rep.Add("| ``$k`` | $($preset[$k]) | ? | ? | il client non conosce questa chiave |"); continue }
  $stato = if ($preset[$k] -ne $c.valore) { 'diverso dal PG' }
  elseif ($preset[$k] -eq $c.default) { 'uguale al default: il preset non serve' }
  else { 'ok' }
  $rep.Add("| ``$k`` | $($preset[$k]) | $($c.valore) | $($c.default) | $stato |")
}
$rep.Add('')

# Sezione 2: i candidati -- la parte da leggere
$cand = @($cvar.Values | Where-Object { $_.diverso -and -not $preset.Contains($_.nome) -and
    -not $presetAcc.Contains($_.nome) -and -not $_.soloLettura })
$rep.Add("## 2. Fuori dal default e non nel preset ($($cand.Count))")
$rep.Add('')
$rep.Add('Le impostazioni che hai cambiato e che il preset non propaga. Dimmi quali vuoi ovunque.')
$rep.Add('')
$rep.Add('| chiave | valore | default | nei file | scope | categoria | aiuto |')
$rep.Add('|---|---|---|---|---|---|---|')
foreach ($c in ($cand | Sort-Object categoria, nome)) {
  $scope = if ($c.srvAccount) { 'server/account' } elseif ($c.srvChar) { 'server/PG' } else { 'file' }
  $rep.Add("| ``$($c.nome)`` | $($c.valore) | $($c.default) | $(Copertura $c.nome) | $scope | $($c.categoria) | $($c.aiuto) |")
}
$rep.Add('')

# Sezione 3: quelle che i file non possono propagare
$srv = @($cvar.Values | Where-Object { $_.diverso -and ($_.srvAccount -or $_.srvChar) })
$rep.Add("## 3. Salvate sul server: i file WTF non le propagano ($($srv.Count))")
$rep.Add('')
$rep.Add('Stessa natura del flag che blocca gli inviti in gilda: scriverle nei config-cache non fa niente.')
$rep.Add('')
$rep.Add('| chiave | valore | default | dove | categoria |')
$rep.Add('|---|---|---|---|---|')
foreach ($c in ($srv | Sort-Object nome)) {
  $dove = if ($c.srvAccount) { 'account' } else { 'personaggio' }
  $rep.Add("| ``$($c.nome)`` | $($c.valore) | $($c.default) | $dove | $($c.categoria) |")
}
$rep.Add('')

# Sezione 4: dove i PG divergono nei file, fuori preset
$div = @()
foreach ($k in $suiPg.Keys) {
  if ($preset.Contains($k)) { continue }
  $vals = @($suiPg[$k].Values | Sort-Object -Unique)
  $mancanti = $files.Count - @($suiPg[$k].Keys).Count
  if ($vals.Count -gt 1 -or $mancanti -gt 0) {
    $g = $suiPg[$k].Values | Group-Object | Sort-Object Count -Descending
    $div += [pscustomobject]@{
      nome = $k; valori = $vals.Count; mancanti = $mancanti
      dominante = ("{0} ({1} PG)" -f $g[0].Name, $g[0].Count)
      noto = $cvar.Contains($k)
    }
  }
}
$rep.Add("## 4. Divergenze nei file, fuori preset ($($div.Count))")
$rep.Add('')
$rep.Add('Quasi tutto qui e'' STATO, non impostazioni (tutorial visti, header chiusi, filtri del')
$rep.Add('Dungeon Journal): serve per capire cosa NON vale la pena di mettere nel preset.')
$rep.Add('')
$rep.Add('| chiave | valori distinti | assente su | valore piu'' comune |')
$rep.Add('|---|---|---|---|')
foreach ($d in ($div | Sort-Object -Property @{E = 'valori'; Descending = $true }, nome)) {
  $rep.Add("| ``$($d.nome)`` | $($d.valori) | $($d.mancanti) PG | $($d.dominante) |")
}
$rep.Add('')

[System.IO.File]::WriteAllLines($Md, $rep, [System.Text.UTF8Encoding]::new($false))

# --- 5. a schermo: il riassunto e le due verifiche che contano ---------------------
Write-Host ''
Write-Host ("PG del dump : {0}  (build {1}, {2})" -f $meta['pg'], $meta['build'], $meta['data'])
Write-Host ("CVar        : {0} totali, {1} fuori dal default" -f $totali, $diversi)
Write-Host ("Preset      : {0} chiavi per-PG, {1} account-wide" -f $preset.Count, $presetAcc.Count)
Write-Host ''
$fuori = @($preset.Keys | Where-Object { $cvar[$_] -and $preset[$_] -ne $cvar[$_].valore })
$inutili = @($preset.Keys | Where-Object { $cvar[$_] -and $preset[$_] -eq $cvar[$_].default })
$ignote = @($preset.Keys | Where-Object { -not $cvar.Contains($_) })
Write-Host ("Preset diverso dal PG del dump : {0}{1}" -f $fuori.Count, $(if ($fuori) { '  -> ' + ($fuori -join ', ') } else { '' }))
Write-Host ("Preset uguale al default       : {0}{1}" -f $inutili.Count, $(if ($inutili) { '  -> ' + ($inutili -join ', ') } else { '' }))
Write-Host ("Preset che il client non ha    : {0}{1}" -f $ignote.Count, $(if ($ignote) { '  -> ' + ($ignote -join ', ') } else { '' }))
Write-Host ("Candidati (fuori default)      : {0}" -f $cand.Count)
Write-Host ("Salvate sul server             : {0}" -f $srv.Count)
Write-Host ''
Write-Host "Report: $Md" -ForegroundColor Green
