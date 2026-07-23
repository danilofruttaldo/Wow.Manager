# Genera public/og-image.png (1200x630), l'anteprima social linkata da Base.astro
# (og:image / twitter:image). Tipografico e sobrio: fondo scuro come il favicon, barra
# oro, titolo + dominio + tagline. Rilancialo per rigenerarlo dopo un cambio di brand.
#
# ASCII-only di proposito: niente accenti/middot nel sorgente (PS 5.1 legge i .ps1 senza
# BOM come ANSI e li corromperebbe). Le separazioni della tagline usano " - ".

Add-Type -AssemblyName System.Drawing

$W = 1200
$H = 630
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

# Sfondo scuro (stesso del favicon) + barra oro a sinistra.
$g.Clear([System.Drawing.Color]::FromArgb(23, 21, 15))
$gold = [System.Drawing.Color]::FromArgb(224, 178, 76)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $gold), 0, 0, 16, $H)

# Titolo, dominio, tagline.
$fTitle = New-Object System.Drawing.Font('Segoe UI', 82, [System.Drawing.FontStyle]::Bold)
$fDomain = New-Object System.Drawing.Font('Segoe UI', 34, [System.Drawing.FontStyle]::Regular)
$fTag = New-Object System.Drawing.Font('Segoe UI', 27, [System.Drawing.FontStyle]::Regular)

$bWhite = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 246, 247))
$bGold = New-Object System.Drawing.SolidBrush $gold
$bMuted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 156, 166))

$g.DrawString('WoW Manager', $fTitle, $bWhite, 78, 196)
$g.DrawString('wow.danilofruttaldo.com', $fDomain, $bGold, 86, 336)
$g.DrawString('Addon - Macro - Professioni - PG - Transmog - UI', $fTag, $bMuted, 86, 416)

$out = Join-Path (Get-Location).Path 'public\og-image.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Output "Scritto $out"
