#Requires -Version 5.1
# Applica l'override del font base di WoW: copia un unico .ttf sotto i nomi-override
# che il client carica da _retail_/Fonts/, così tutta la UI Blizzard usa quel font.
# Nomi/percorsi presi da fonts/manifest.json (nessun elenco hardcoded: segue il manifest).
# Si carica all'AVVIO del client, non basta /reload.  Usa -Revert per rimuoverli.
[CmdletBinding()]
param([switch]$Revert)
$ErrorActionPreference = 'Stop'

# Trova fonts/manifest.json: relativo allo script (repo) o alla cartella corrente.
$candidates = @()
if ($PSScriptRoot) { $candidates += (Join-Path (Split-Path $PSScriptRoot -Parent) 'fonts\manifest.json') }
$candidates += (Join-Path (Get-Location).Path 'fonts\manifest.json')
$manifestPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $manifestPath) { throw "fonts/manifest.json non trovato: esegui dalla cartella del repo." }

$m        = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$fontsDir = $m._meta.wow_fonts_dir
$source   = $m.override.source_file
$files    = $m.override.files

if ($Revert) {
  $n = 0
  foreach ($name in $files) {
    $dest = Join-Path $fontsDir $name
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force; Write-Host "Rimosso: $name"; $n++ }
  }
  Write-Host ""
  Write-Host "Revert completato ($n file). RIAVVIA il client per tornare al font di default."
  return
}

if (-not (Test-Path -LiteralPath $source)) { throw "Font sorgente non trovato: $source" }
if (-not (Test-Path -LiteralPath $fontsDir)) { New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null }

foreach ($name in $files) {
  Copy-Item -LiteralPath $source -Destination (Join-Path $fontsDir $name) -Force
  Write-Host "Copiato: $($m.override.source_font) -> $name"
}
Write-Host ""
Write-Host "Fatto ($($files.Count) file). RIAVVIA il client (non basta /reload)."
