<#
.SYNOPSIS
  Genera le miniature degli screenshot UI in public/screenshots/thumb/.

.DESCRIPTION
  Gli screenshot originali sono a piena risoluzione (2560x1440, ~600 KB l'uno):
  vanno bene per il lightbox, che li mostra a schermo intero, ma la griglia della
  pagina /ui li rende a ~300px e scaricarli interi e' spreco puro.
  Questo script produce una copia ridotta a 640px di larghezza (il doppio della
  card, cosi' resta nitida sui display retina) dentro public/screenshots/thumb/,
  con lo stesso nome file. Gli originali non vengono mai toccati.

  Niente ImageMagick e niente Node: usa System.Drawing di .NET, presente in
  Windows PowerShell 5.1. Ogni oggetto grafico viene chiuso con Dispose(),
  altrimenti il file resta lockato e le esecuzioni successive falliscono.

.PARAMETER Larghezza
  Larghezza in pixel della miniatura (default 640). L'altezza e' proporzionale.

.PARAMETER Qualita
  Qualita' JPEG 1-100 (default 82).

.PARAMETER Forza
  Rigenera anche le miniature gia' aggiornate.

.EXAMPLE
  .\scripts\make-thumbs.ps1
  .\scripts\make-thumbs.ps1 -Forza
#>
[CmdletBinding()]
param(
  [int]$Larghezza = 640,
  [int]$Qualita = 82,
  [switch]$Forza
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

# Radice del repo = cartella padre di scripts/, cosi' lo script funziona da
# qualsiasi working directory.
$Radice  = Split-Path -Parent $PSScriptRoot
$Sorgente = Join-Path $Radice 'public\screenshots'
$Dest     = Join-Path $Sorgente 'thumb'

if (-not (Test-Path -LiteralPath $Sorgente)) {
  throw "Cartella screenshot non trovata: $Sorgente"
}
if (-not (Test-Path -LiteralPath $Dest)) {
  New-Item -ItemType Directory -Path $Dest | Out-Null
}

# Codec JPEG + parametro di qualita': senza questo Save() userebbe il default
# (75) e non sarebbe regolabile.
$CodecJpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
if ($null -eq $CodecJpeg) { throw 'Codec JPEG non disponibile.' }

$ParamQualita = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ParamQualita.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, [int64]$Qualita)

# Solo i file nella radice di screenshots/: la sottocartella thumb/ va esclusa,
# o alla seconda esecuzione lo script rimpicciolirebbe le proprie miniature.
$Immagini = Get-ChildItem -LiteralPath $Sorgente -Filter *.jpg -File | Sort-Object Name

if ($Immagini.Count -eq 0) {
  Write-Host 'Nessuno screenshot da elaborare.' -ForegroundColor Yellow
  return
}

$PesoPrima = 0L
$PesoDopo  = 0L
$Fatte     = 0
$Saltate   = 0

foreach ($File in $Immagini) {
  $Uscita = Join-Path $Dest $File.Name
  $PesoPrima += $File.Length

  # Salta se la miniatura esiste ed e' piu' recente dell'originale.
  if (-not $Forza -and (Test-Path -LiteralPath $Uscita)) {
    $Esistente = Get-Item -LiteralPath $Uscita
    if ($Esistente.LastWriteTimeUtc -ge $File.LastWriteTimeUtc) {
      $PesoDopo += $Esistente.Length
      $Saltate++
      Write-Host ("  = {0} (gia' aggiornata)" -f $File.Name) -ForegroundColor DarkGray
      continue
    }
  }

  $Img = $null; $Bmp = $null; $Gfx = $null
  try {
    $Img = [System.Drawing.Image]::FromFile($File.FullName)

    # Se l'originale e' gia' piu' stretto della soglia non lo si ingrandisce.
    $LarghezzaFinale = [Math]::Min($Larghezza, $Img.Width)
    $AltezzaFinale   = [int][Math]::Round($Img.Height * ($LarghezzaFinale / $Img.Width))

    $Bmp = New-Object System.Drawing.Bitmap($LarghezzaFinale, $AltezzaFinale)
    $Gfx = [System.Drawing.Graphics]::FromImage($Bmp)
    $Gfx.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $Gfx.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $Gfx.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $Gfx.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $Gfx.DrawImage($Img, 0, 0, $LarghezzaFinale, $AltezzaFinale)

    $Bmp.Save($Uscita, $CodecJpeg, $ParamQualita)
  }
  finally {
    # Dispose in ordine inverso alla creazione: senza questo il .jpg resta
    # lockato dal processo e la riesecuzione fallisce.
    if ($null -ne $Gfx) { $Gfx.Dispose() }
    if ($null -ne $Bmp) { $Bmp.Dispose() }
    if ($null -ne $Img) { $Img.Dispose() }
  }

  $Nuova = Get-Item -LiteralPath $Uscita
  $PesoDopo += $Nuova.Length
  $Fatte++
  Write-Host ("  + {0}  {1} KB -> {2} KB  ({3}x{4})" -f `
    $File.Name,
    [int]($File.Length / 1KB),
    [int]($Nuova.Length / 1KB),
    $LarghezzaFinale, $AltezzaFinale) -ForegroundColor Green
}

$ParamQualita.Dispose()

$Risparmio = if ($PesoPrima -gt 0) { 100 - [int](100 * $PesoDopo / $PesoPrima) } else { 0 }
Write-Host ''
Write-Host ("Miniature: {0} generate, {1} saltate, {2} totali in {3}" -f `
  $Fatte, $Saltate, $Immagini.Count, $Dest)
Write-Host ("Peso: {0:N2} MB -> {1:N2} MB  (-{2}%)" -f `
  ($PesoPrima / 1MB), ($PesoDopo / 1MB), $Risparmio) -ForegroundColor Cyan
