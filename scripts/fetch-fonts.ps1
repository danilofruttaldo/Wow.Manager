#Requires -Version 5.1
# Riscarica i font self-hostati del sito in public/fonts/ e rigenera fonts.css.
#
#   .\scripts\fetch-fonts.ps1
#
# Serve solo quando cambi i font o i pesi usati: i file gia' scaricati stanno nel
# repo e non vanno riscaricati a ogni build.
#
# Se cambi i font, aggiorna anche public/fonts/OFL.txt: la SIL OFL 1.1 vuole che
# la licenza (con gli header di copyright) sia spedita insieme ai woff2.
#
# Perche' self-hostati: caricarli da fonts.googleapis.com manda a Google l'IP di
# ogni visitatore, ed e' l'unico host esterno del sito. In locale sparisce anche
# la dipendenza di rendering da un terzo.
#
# Inter e JetBrains Mono sono font VARIABILI: lo stesso woff2 copre tutti i pesi,
# quindi i 12 blocchi @font-face puntano a 4 file soli. Deduplicati per hash.
$ErrorActionPreference = 'Stop'

$Dest = Join-Path (Split-Path $PSScriptRoot -Parent) 'public\fonts'
$Url  = 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap'

# Con uno User-Agent moderno Google serve woff2; con quello di PowerShell darebbe ttf.
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
$css = (Invoke-WebRequest -Uri $Url -UserAgent $UA -UseBasicParsing).Content

# I blocchi sono preceduti dal commento col nome del subset. Servono solo i latini.
$blocchi = [regex]::Matches($css, '/\* ([a-z-]+) \*/\s*(@font-face \{.*?\})', 'Singleline')
$tenuti = @($blocchi | Where-Object { $_.Groups[1].Value -in @('latin', 'latin-ext') })
if ($tenuti.Count -eq 0) { throw "nessun blocco latin nel CSS: Google ha cambiato formato?" }

New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Get-ChildItem -Path $Dest -Filter '*.woff2' -ErrorAction SilentlyContinue | Remove-Item -Force

$perHash = @{}   # hash del contenuto -> nome file
$perUrl  = @{}   # url -> hash, per non riscaricare due volte lo stesso
$righe = New-Object System.Collections.ArrayList
[void]$righe.Add("/* Inter e JetBrains Mono self-hostati: nessuna richiesta a Google, quindi")
[void]$righe.Add("   nessun IP di visitatore inviato a terzi e un host esterno in meno.")
[void]$righe.Add("   Solo i subset latin e latin-ext, gli unici che servono all'italiano.")
[void]$righe.Add("   Sono font VARIABILI: un file solo copre tutti i pesi, per questo i")
[void]$righe.Add("   blocchi per peso puntano allo stesso woff2.")
[void]$righe.Add("   Rigenerato da scripts/fetch-fonts.ps1. */")
[void]$righe.Add("")

foreach ($m in $tenuti) {
    $subset = $m.Groups[1].Value
    $blocco = $m.Groups[2].Value
    $url = [regex]::Match($blocco, 'url\((https://[^)]+\.woff2)\)').Groups[1].Value
    $fam = [regex]::Match($blocco, "font-family: '([^']+)'").Groups[1].Value

    if (-not $perUrl.ContainsKey($url)) {
        $tmp = [System.IO.Path]::GetTempFileName()
        Invoke-WebRequest -Uri $url -UserAgent $UA -OutFile $tmp -UseBasicParsing
        $h = (Get-FileHash -Path $tmp -Algorithm MD5).Hash
        $perUrl[$url] = $h
        if (-not $perHash.ContainsKey($h)) {
            $nome = ($fam -replace ' ', '') + "-$subset.woff2"
            $perHash[$h] = $nome
            Move-Item -LiteralPath $tmp -Destination (Join-Path $Dest $nome) -Force
        } else {
            Remove-Item -LiteralPath $tmp -Force
        }
    }
    $nome = $perHash[$perUrl[$url]]
    [void]$righe.Add(($blocco -replace [regex]::Escape($url), "/fonts/$nome"))
    [void]$righe.Add("")
}

$testo = ($righe -join "`n")
[System.IO.File]::WriteAllText(
    (Join-Path $Dest 'fonts.css'), $testo, (New-Object System.Text.UTF8Encoding($false)))

$tot = (Get-ChildItem -Path $Dest -Filter '*.woff2' | Measure-Object -Property Length -Sum).Sum
Write-Host ("{0} file, {1:N1} KB, {2} blocchi @font-face" -f $perHash.Count, ($tot / 1KB), $tenuti.Count) -ForegroundColor Green
