# Sincronizza transmog/manifest.json con l'ultimo dump del gioco.
#
# Prima, in gioco:  /reload  ->  /wmtier  ->  /reload
# Poi da qui:       .\scripts\transmog-sync.ps1
# Infine:           git add -A ; git commit ; git push
#
# Sostituisce SOLO i blocchi `collected` e `pieceList`. Tutto il resto del manifest
# (tiers, names, versions, fonte, colonna, spans) e' redazionale e non si tocca.
#
# Si ferma da sola se il dump non e' affidabile: e' il punto del mestiere, perche' un
# dump preso mentre il client non ha ancora caricato la collezione e' internamente
# COERENTE -- ogni set a zero pezzi ma con il totale giusto -- e incollarlo azzera la
# collezione senza che nessun controllo se ne accorga.

param(
    [string]$Manifest = "transmog\manifest.json",
    [string]$Wow      = "C:\Program Files (x86)\World of Warcraft"
)

$ErrorActionPreference = "Stop"

function Errore($msg) {
    Write-Host "STOP: $msg" -ForegroundColor Red
    exit 1
}

# --- 1. trovare il dump -------------------------------------------------------
# Cercato, non scritto a mano: il percorso contiene il nome dell'account, che cambia.
$dump = Get-ChildItem -Path (Join-Path $Wow "_retail_\WTF\Account") -Recurse `
        -Filter "WowManagerTierDump.lua" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -like "*SavedVariables*" } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $dump) { Errore "WowManagerTierDump.lua non trovato sotto $Wow. L'addon e' installato e hai lanciato /wmtier?" }

$lua = Get-Content -Raw -Encoding UTF8 $dump.FullName
$eta = [int]((Get-Date) - $dump.LastWriteTime).TotalMinutes
Write-Host ("dump: {0}  ({1} minuti fa)" -f $dump.LastWriteTime, $eta)

# --- 2. guardie ---------------------------------------------------------------
if ($lua -match '\["sospetto"\]\s*=\s*"([^"]+)"') {
    Errore "il dump si e' auto-segnalato: $($matches[1])"
}
foreach ($campo in @("mismatches", "errors")) {
    if ($lua -match ('\["' + $campo + '"\]\s*=\s*\{\s*"')) {
        Errore "il campo $campo del dump non e' vuoto: elenco pezzi non fidato, non incollo"
    }
}
$presi = 0
if ($lua -match '\["presi"\]\s*=\s*(\d+)') { $presi = [int]$matches[1] }
if ($presi -le 0) { Errore "il dump dice $presi pezzi collezionati: collezione non caricata" }

# --- 3. estrarre i due blocchi ------------------------------------------------
function Blocco($nome) {
    $re = '\["' + $nome + '"\]\s*=\s*"((?:[^"\\]|\\.)*)"'
    if ($lua -notmatch $re) { Errore "campo $nome assente dal dump" }
    $t = $matches[1]
    $t = $t.Replace('\n', "`n").Replace('\"', '"').Replace('\\', '\')
    return $t
}
$blocchi = @{ "collected" = (Blocco "collectedJson"); "pieceList" = (Blocco "piecesJson") }

# --- 4. sostituire nel manifest ------------------------------------------------
if (-not (Test-Path $Manifest)) { Errore "manifest non trovato: $Manifest" }
$righe = [System.Collections.ArrayList]@((Get-Content -Encoding UTF8 $Manifest))

foreach ($chiave in @("collected", "pieceList")) {
    $inizio = -1
    for ($i = 0; $i -lt $righe.Count; $i++) {
        if ($righe[$i] -eq ('  "' + $chiave + '": {')) { $inizio = $i; break }
    }
    if ($inizio -lt 0) { Errore "blocco $chiave non trovato nel manifest" }
    $fine = -1
    for ($i = $inizio + 1; $i -lt $righe.Count; $i++) {
        if ($righe[$i] -eq "  }" -or $righe[$i] -eq "  },") { $fine = $i; break }
    }
    if ($fine -lt 0) { Errore "fine del blocco $chiave non trovata" }

    $coda = ""
    if ($righe[$fine].EndsWith(",")) { $coda = "," }
    $nuove = $blocchi[$chiave] -split "`n"
    $nuove[$nuove.Count - 1] = $nuove[$nuove.Count - 1] + $coda

    $righe.RemoveRange($inizio, $fine - $inizio + 1)
    $righe.InsertRange($inizio, [string[]]$nuove)
    Write-Host ("  {0,-10} {1} righe" -f $chiave, $nuove.Count)
}

# --- 5. validare PRIMA di scrivere ---------------------------------------------
$testo = ($righe -join "`n")
try { $null = $testo | ConvertFrom-Json } catch { Errore "il risultato non e' JSON valido: $_" }

[System.IO.File]::WriteAllText(
    (Resolve-Path $Manifest), $testo, (New-Object System.Text.UTF8Encoding($false)))

# --- 6. riepilogo --------------------------------------------------------------
$m = Get-Content -Raw -Encoding UTF8 $Manifest | ConvertFrom-Json
$voci = 0; $conBoss = 0
foreach ($cls in $m.pieceList.PSObject.Properties) {
    foreach ($tier in $cls.Value.PSObject.Properties) {
        foreach ($ver in $tier.Value.PSObject.Properties) {
            foreach ($p in $ver.Value) {
                $voci++
                if ($p[0] -like "* (*") { $conBoss++ }
            }
        }
    }
}
Write-Host ""
Write-Host ("manifest aggiornato: {0} voci, {1} col boss ({2:N0}%), {3} pezzi collezionati" -f `
    $voci, $conBoss, (100 * $conBoss / $voci), $presi) -ForegroundColor Green
Write-Host "ora: git add -A ; git commit ; git push"
