#Requires -Version 5.1
# Backup e ripristino di impostazioni e addon di WoW: crea uno .zip datato di
# WTF (impostazioni, keybind, macro, SavedVariables) + Interface (addon), oppure
# ripristina da uno .zip esistente. Nessuna dipendenza: usa Compress/Expand-Archive.
# Adattato dai tool community: smashedr/wow-backup, eTzmNcbkrng/Backup-WTF.
#   Backup:    .\backup-restore.ps1
#   Ripristino: .\backup-restore.ps1 -Restore -Zip "...\wow-2026-07-13_2140.zip"
[CmdletBinding()]
param(
  [switch]$Restore,
  [string]$Zip
)
$ErrorActionPreference = 'Stop'

$WowRoot   = 'C:\Program Files (x86)\World of Warcraft\_retail_'
$BackupDir = Join-Path $WowRoot 'Backups'
$Folders   = @('WTF', 'Interface')   # cosa salviamo/ripristiniamo

# Non operare col client aperto: i file sono in uso.
if (Get-Process -Name 'Wow', 'WowClassic' -ErrorAction SilentlyContinue) {
  throw "WoW è in esecuzione: chiudi il client prima di backup/ripristino."
}

if ($Restore) {
  if (-not $Zip -or -not (Test-Path -LiteralPath $Zip)) {
    throw "Ripristino: passa -Zip con il percorso di uno .zip valido."
  }
  Write-Warning "Il ripristino SOVRASCRIVE $($Folders -join ' e ') in $WowRoot."
  if ((Read-Host "Procedere? Scrivi 'si' per confermare") -ne 'si') { Write-Host "Annullato."; return }
  Expand-Archive -LiteralPath $Zip -DestinationPath $WowRoot -Force
  Write-Host "Ripristinato da: $Zip"
  return
}

# ── Backup ──
$sources = $Folders | ForEach-Object { Join-Path $WowRoot $_ } | Where-Object { Test-Path -LiteralPath $_ }
if (-not $sources) { throw "Niente da salvare: WTF/Interface non trovate in $WowRoot." }

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
$out   = Join-Path $BackupDir "wow-$stamp.zip"
Compress-Archive -Path $sources -DestinationPath $out -CompressionLevel Optimal

$mb = [math]::Round(((Get-Item -LiteralPath $out).Length / 1MB), 1)
Write-Host "Backup creato: $out ($mb MB)"
Write-Host "Ripristino: .\backup-restore.ps1 -Restore -Zip `"$out`""
