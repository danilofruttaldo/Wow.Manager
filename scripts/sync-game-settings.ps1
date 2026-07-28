#Requires -Version 5.1
# Applica il PRESET delle "impostazioni di gioco" a TUTTI i personaggi, Stantu incluso.
# Il preset sta qui sotto ed e' lui la fonte di verita': prima i valori si copiavano dal
# config-cache.wtf di Stantu, con due effetti indesiderati -- un ritocco qualsiasi fatto
# in gioco su Stantu si propagava a tutti, e una chiave che Stantu non aveva veniva
# saltata in silenzio (sembrava sincronizzata e non lo era).
# Scrive SOLO le chiavi dichiarate: tutto il resto dello stato per-PG resta intatto.
# Due blocchi, perche' il client salva i CVar in due posti: $CharValues (per-PG, in ogni
# cartella di personaggio) e $AccountValues (account-wide, nel file di account).
# IMPORTANTE: eseguire con WoW COMPLETAMENTE CHIUSO.  -Prova = dice cosa cambierebbe.
param([switch]$Prova)
$ErrorActionPreference = 'Stop'

# --- PRESET per-PG: valore voluto, applicato a ogni personaggio ------------------------
$CharValues = [ordered]@{
  # Gameplay
  enableMouseoverCast              = '1'
  autoLootDefault                  = '1'
  AutoPushSpellToActionBar         = '0'
  enableMultiActionBars            = '15'
  SoftTargetEnemy                  = '2'                  # Action Targeting da tastiera
  assistedCombatHighlight          = '1'
  cooldownViewerEnabled            = '1'
  damageMeterEnabled               = '1'
  damageMeterResetOnNewInstance    = '1'
  # Riquadri gruppo / raid
  raidFramesDisplayClassColor      = '1'
  raidFramesDisplayPowerBars       = '1'
  # Nameplate. I due valori strani (MinAlpha, MinAlphaDistance) non sono refusi: sono
  # quelli che scrive il client muovendo gli slider, e li teniamo come sono.
  nameplateSelectedScale           = '1.15'
  nameplateSelectedAlpha           = '1'
  nameplateMaxDistance             = '60'
  nameplateMinScale                = '1'
  nameplateMaxScale                = '1'
  nameplateMinScaleDistance        = '0'
  nameplateMaxScaleDistance        = '40'
  nameplateMinAlpha                = '0.90135484'
  nameplateMaxAlpha                = '1'
  nameplateMinAlphaDistance        = '-158489.31924611'
  nameplateTargetBehindMaxDistance = '30'
  nameplateShowDebuffsOnFriendly   = '0'
  # Camera. ATTENZIONE: queste quattro il client le riscrive da se' a ogni sessione
  # (zoom, inclinazione), quindi divergono per conto loro e ogni giro le riporta qui.
  cameraSavedDistance              = '39.000000'
  cameraSavedPitch                 = '19.726063'
  cameraSavedVehicleDistance       = '50.000000'
  cameraSavedPetBattleDistance     = '14.999997'
  # Interfaccia varia
  calendarShowBattlegrounds        = '0'
  characterNeedsTurnStrafeDialog   = '0'
  miniDressUpFrame                 = '1'
  showTokenFrame                   = '1'
  showTamers                       = '0'
}

# --- PRESET account-wide: CVar che nei file per-PG non esistono proprio ----------------
# Scriverli per-PG non farebbe nulla: stanno solo in Account/<ACC>/config-cache.wtf.
$AccountValues = [ordered]@{
  # Social > New Whispers = Both. Valori del client: inline | popout | popout_and_inline
  whisperMode = 'popout_and_inline'
}

# NON sincronizzabile: il blocco degli inviti in gilda. Verificato sul client 12.0.7
# enumerando le stringhe di Wow.exe: 'blockTrades' e 'blockChannelInvites' esistono,
# un 'blockGuildInvites' NO -- quel flag e' server-side per personaggio
# (C_GuildInfo.SetAutoDeclineGuildInvites) e non passa da nessun file WTF. Si toglie
# solo in gioco, su ogni PG:
#   /run (C_GuildInfo and C_GuildInfo.SetAutoDeclineGuildInvites or SetAutoDeclineGuildInvites)(false)

# Cercata, non scritta a mano: la cartella porta il nome dell'account Battle.net,
# che non va pubblicato (questo script e' reso per intero sulla pagina Extra).
$AccRoot = 'C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account'
$Acc = (Get-ChildItem -LiteralPath $AccRoot -Directory |
  Where-Object { $_.Name -ne 'SavedVariables' } |
  Select-Object -First 1).FullName
if (-not $Acc) { throw "Nessuna cartella account sotto: $AccRoot" }

# A gioco aperto e' lavoro buttato: al logout il client riscrive i config-cache col suo
# stato in memoria e le chiavi appena messe qui tornano come prima.
if (-not $Prova) {
  if (Get-Process -Name 'Wow' -ErrorAction SilentlyContinue) {
    throw "WoW e' aperto: chiudilo prima, oppure lancia con -Prova per vedere solo cosa cambierebbe."
  }
}

# Porta le chiavi dichiarate al valore del preset in un file WTF; ritorna quante ne ha cambiate.
function Set-WtfKeys {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Values,
    [switch]$DryRun
  )
  $lines = @(Get-Content -LiteralPath $Path)
  $changed = 0
  foreach ($k in @($Values.Keys)) {
    $new = 'SET ' + $k + ' "' + $Values[$k] + '"'
    $rx = '^SET ' + [regex]::Escape($k) + ' ".*"\s*$'
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $rx) { $idx = $i; break } }
    if ($idx -ge 0) {
      if ($lines[$idx] -ne $new) { $lines[$idx] = $new; $changed++ }   # sostituisci riga esistente
    }
    else {
      $lines += $new; $changed++                                       # aggiungi in coda
    }
  }
  if ($changed -gt 0 -and -not $DryRun) {
    # Riscrivi con CRLF e senza BOM (il client vuole testo semplice).
    $text = ($lines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false))
  }
  return $changed
}

if ($Prova) { Write-Host "PROVA: nessun file verra' scritto." -ForegroundColor Yellow; Write-Host "" }

Write-Host ("Preset per-PG ({0} chiavi):" -f $CharValues.Count)
foreach ($k in $CharValues.Keys) { Write-Host ("  {0,-32} = {1}" -f $k, $CharValues[$k]) }
Write-Host ""

# Ogni cartella di personaggio. Fuori il file account-level (contiene solo CVar
# account-wide: le chiavi per-PG li' il gioco le scarta) e le cartelle _backup-*.
$accCache = Join-Path $Acc 'config-cache.wtf'
$targets = Get-ChildItem -LiteralPath $Acc -Recurse -File -Filter 'config-cache.wtf' |
  Where-Object { $_.FullName -ne $accCache -and $_.FullName -notmatch '\\_backup-' } |
  Sort-Object FullName

$files = 0
$keys = 0
foreach ($f in $targets) {
  $n = Set-WtfKeys -Path $f.FullName -Values $CharValues -DryRun:$Prova
  $pg = $f.Directory.FullName.Substring($Acc.Length + 1)
  if ($n -gt 0) {
    $files++; $keys += $n
    Write-Host ("  {0,-44} {1} chiavi" -f $pg, $n)
  }
  else {
    Write-Host ("  {0,-44} -" -f $pg)
  }
}

# Account-wide: un file solo.
if ($AccountValues.Count -gt 0 -and (Test-Path -LiteralPath $accCache)) {
  Write-Host ""
  Write-Host "Preset account-wide (config-cache.wtf di account):"
  foreach ($k in $AccountValues.Keys) { Write-Host ("  {0,-32} = {1}" -f $k, $AccountValues[$k]) }
  $n = Set-WtfKeys -Path $accCache -Values $AccountValues -DryRun:$Prova
  if ($n -gt 0) { $files++; $keys += $n; Write-Host ("  -> aggiornate {0} chiavi" -f $n) }
  else { Write-Host "  -> gia' a posto" }
}

Write-Host ""
if ($Prova) {
  Write-Host ("Da aggiornare: {0} file su {1}, {2} chiavi. Niente scritto." -f $files, ($targets.Count + 1), $keys)
}
else {
  Write-Host ("Fatto: {0} file aggiornati su {1}, {2} chiavi scritte." -f $files, ($targets.Count + 1), $keys)
}
