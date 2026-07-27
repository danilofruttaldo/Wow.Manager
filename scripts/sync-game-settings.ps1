#Requires -Version 5.1
# Allinea le "impostazioni di gioco" di tutti i personaggi a quelle di Stantu.
# Copia SOLO le chiavi nell'allowlist; lo stato per-personaggio resta intatto.
# Due allowlist, perche' il client salva i CVar in due posti: $Keys (per-PG, copiate da
# Stantu) e $AccountValues (account-wide, fissate al valore voluto nel file di account).
# IMPORTANTE: eseguire con WoW COMPLETAMENTE CHIUSO.
$ErrorActionPreference = 'Stop'

# Cercata, non scritta a mano: la cartella porta il nome dell'account Battle.net,
# che non va pubblicato (questo script e' reso per intero sulla pagina Extra).
$AccRoot = 'C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account'
$Acc = (Get-ChildItem -LiteralPath $AccRoot -Directory |
  Where-Object { $_.Name -ne 'SavedVariables' } |
  Select-Object -First 1).FullName
if (-not $Acc) { throw "Nessuna cartella account sotto: $AccRoot" }

# Il realm sorgente ha una lettera accentata (Pozzo dell'Eternita'): scritta qui
# verrebbe corrotta da Windows PowerShell 5.1, che legge come ANSI gli .ps1 senza
# BOM. Cerchiamo la cartella del PG, cosi' il path non dipende dall'encoding.
$SrcChar = 'Stantu'
$Src = (Get-ChildItem -LiteralPath $Acc -Recurse -File -Filter 'config-cache.wtf' |
  Where-Object { $_.Directory.Name -eq $SrcChar -and $_.FullName -notmatch '\\_backup-' } |
  Select-Object -First 1).FullName

# Chiavi PER-PG = vere opzioni di gioco da copiare da Stantu a tutti gli altri
$Keys = @(
  'enableMouseoverCast', 'autoLootDefault', 'AutoPushSpellToActionBar', 'enableMultiActionBars', 'SoftTargetEnemy',
  'assistedCombatHighlight', 'cooldownViewerEnabled', 'damageMeterEnabled', 'damageMeterResetOnNewInstance',
  'raidFramesDisplayClassColor', 'raidFramesDisplayPowerBars',
  'nameplateSelectedScale', 'nameplateSelectedAlpha', 'nameplateMaxDistance',
  'nameplateMinScale', 'nameplateMaxScale', 'nameplateMinScaleDistance', 'nameplateMaxScaleDistance',
  'nameplateMinAlpha', 'nameplateMaxAlpha', 'nameplateMinAlphaDistance',
  'nameplateTargetBehindMaxDistance', 'nameplateShowDebuffsOnFriendly',
  'cameraSavedDistance', 'cameraSavedPitch', 'cameraSavedVehicleDistance', 'cameraSavedPetBattleDistance',
  'calendarShowBattlegrounds', 'characterNeedsTurnStrafeDialog',
  'miniDressUpFrame', 'showTokenFrame', 'showTamers', 'dragonRidingRacesFilter'
)

# Chiavi ACCOUNT-WIDE = opzioni che il client NON scrive nei file per-PG ma nel
# config-cache.wtf di account: copiarle da Stantu non ha senso (li' non ci sono) e
# scriverle per-PG non serve a niente. Si fissano qui al valore voluto, una volta sola.
$AccountValues = [ordered]@{
  # Social > New Whispers = Both. Valori del client: inline | popout | popout_and_inline
  whisperMode = 'popout_and_inline'
}

if (-not $Src) { throw "Sorgente ($SrcChar) non trovata sotto: $Acc" }

# Estrai i valori di Stantu in una hashtable
$srcLines = @(Get-Content -LiteralPath $Src)
$val = @{}
foreach ($k in $Keys) {
  $rx = '^SET ' + [regex]::Escape($k) + ' "(.*)"\s*$'
  $line = $srcLines | Where-Object { $_ -match $rx } | Select-Object -First 1
  if ($line) { $val[$k] = $matches[1] }
}

Write-Host "Valori sorgente (Stantu):"
foreach ($k in $Keys) { if ($val.ContainsKey($k)) { Write-Host ("  {0,-32} = {1}" -f $k, $val[$k]) } }
Write-Host ""

# Applica a ogni config-cache.wtf tranne Stantu, i backup e il file account-level.
# Quello di account contiene solo CVar account-wide: il gioco scarta le chiavi per-PG.
$accCache = Join-Path $Acc 'config-cache.wtf'
$targets = Get-ChildItem -LiteralPath $Acc -Recurse -File -Filter 'config-cache.wtf' |
  Where-Object { $_.FullName -ne $Src -and $_.FullName -ne $accCache -and $_.FullName -notmatch '\\_backup-' }

foreach ($f in $targets) {
  $lines = @(Get-Content -LiteralPath $f.FullName)
  $changed = $false
  foreach ($k in $Keys) {
    if (-not $val.ContainsKey($k)) { continue }
    $new = 'SET ' + $k + ' "' + $val[$k] + '"'
    $rx = '^SET ' + [regex]::Escape($k) + ' ".*"\s*$'
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $rx) { $idx = $i; break } }
    if ($idx -ge 0) {
      if ($lines[$idx] -ne $new) { $lines[$idx] = $new; $changed = $true }   # sostituisci riga esistente
    }
    else {
      $lines += $new; $changed = $true                                       # aggiungi in coda
    }
  }
  if ($changed) {
    # Riscrivi con CRLF e senza BOM (il client vuole testo semplice).
    $text = ($lines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($f.FullName, $text, [System.Text.UTF8Encoding]::new($false))
  }
  Write-Host ("Aggiornato: " + $f.FullName.Substring($Acc.Length + 1))
}

# Account-wide: un file solo, e il valore e' quello dichiarato sopra (non viene da Stantu).
if ($AccountValues.Count -gt 0 -and (Test-Path -LiteralPath $accCache)) {
  Write-Host ""
  Write-Host "Chiavi account-wide (config-cache.wtf di account):"
  $lines = @(Get-Content -LiteralPath $accCache)
  $changed = $false
  foreach ($k in $AccountValues.Keys) {
    $new = 'SET ' + $k + ' "' + $AccountValues[$k] + '"'
    $rx = '^SET ' + [regex]::Escape($k) + ' ".*"\s*$'
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $rx) { $idx = $i; break } }
    if ($idx -ge 0) {
      if ($lines[$idx] -ne $new) { $lines[$idx] = $new; $changed = $true }
    }
    else {
      $lines += $new; $changed = $true
    }
    Write-Host ("  {0,-32} = {1}" -f $k, $AccountValues[$k])
  }
  if ($changed) {
    $text = ($lines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($accCache, $text, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Aggiornato: config-cache.wtf (account)"
  }
}

Write-Host ""
Write-Host "Fatto."
