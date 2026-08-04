# Sincronizza la collezione transmog: aspetta il dump, aggiorna il manifest, committa.
#
#   .\scripts\transmog-sync.ps1
#   -> "fai /reload in gioco", aspetta, e da li' in poi fa tutto da solo
#
#   -Subito   usa il dump gia' sul disco invece di aspettarne uno nuovo
#   -NoGit    aggiorna il manifest e si ferma li'
#
# In gioco basta UN /reload: l'addon rigenera il dump su PLAYER_LOGOUT, che scatta
# anche col reload. Il /wmtier serve solo se lo vuoi vedere subito in chat.
# Se l'addon installato e' indietro rispetto al repo lo script lo aggiorna da se'
# (vedi §0) e allora i reload diventano due: te lo chiede lui, uno alla volta.
#
# Tocca SOLO i blocchi `collected` e `pieceList`. Il resto del manifest (tiers,
# names, versions, fonte, colonna, spans) e' redazionale e non si tocca.

param(
    [switch]$Subito,
    [switch]$NoGit,
    [int]$AttesaMax = 300,
    # Ancorati alla posizione dello script, non alla cwd: lanciato da scripts\ il
    # path relativo non risolveva e le chiamate a git finivano sul repo della cwd.
    [string]$Manifest = (Join-Path (Split-Path $PSScriptRoot -Parent) "transmog\manifest.json"),
    [string]$Wow      = "C:\Program Files (x86)\World of Warcraft"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent

function Errore($msg) {
    Write-Host "STOP: $msg" -ForegroundColor Red
    exit 1
}

function TrovaDump {
    # Cercato, non scritto a mano: il percorso contiene il nome dell'account.
    return Get-ChildItem -Path (Join-Path $Wow "_retail_\WTF\Account") -Recurse `
           -Filter "WowManagerTierDump.lua" -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -like "*SavedVariables*" } |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function PezziCollezionati($manifestPath) {
    $m = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
    $n = 0
    foreach ($cls in $m.collected.PSObject.Properties) {
        foreach ($tier in $cls.Value.PSObject.Properties) {
            foreach ($ver in $tier.Value.PSObject.Properties) { $n += $ver.Value[0] }
        }
    }
    return $n
}

# --- 0. l'addon nella cartella di gioco -----------------------------------------
# Il gioco legge la copia in Interface/AddOns, NON il .lua del repo: finche' non la
# si sovrascrive il dump esce col codice vecchio e il sync reincolla i dati vecchi
# senza che nulla lo segnali. E' successo davvero due volte -- col set Challenge Mode
# tolto dal repo e reincollato dal sync, e col dump mount il 2026-08-04. Percio' la
# copia la fa lo script, non la memoria di chi lo lancia.
$AddonDir = Join-Path $Wow "_retail_\Interface\AddOns\WowManagerTierDump"
$Reload = 1
if (Test-Path $AddonDir) {
    $copiati = @()
    foreach ($f in @(@{ src = "transmog-tier-dump.lua"; dst = "WowManagerTierDump.lua" },
                     @{ src = "WowManagerTierDump.toc"; dst = "WowManagerTierDump.toc" })) {
        $src = Join-Path $PSScriptRoot $f.src
        $dst = Join-Path $AddonDir $f.dst
        if (-not (Test-Path $src)) { continue }
        if ((Test-Path $dst) -and (Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash) { continue }
        Copy-Item $src $dst -Force
        $copiati += $f.dst
    }
    if ($copiati.Count -gt 0) {
        Write-Host ("addon aggiornato nella cartella di gioco: {0}" -f ($copiati -join ", ")) -ForegroundColor Yellow
        # Si puo' sovrascrivere a gioco aperto, ma il PLAYER_LOGOUT del primo /reload
        # scrive ancora col codice GIA' CARICATO: il dump buono e' quello del secondo.
        $Reload = 2
    }
} else {
    Write-Host "addon non installato in $AddonDir : uso il dump che trovo." -ForegroundColor Yellow
}

# --- 1. il dump ----------------------------------------------------------------
$dump = TrovaDump
if (-not $dump) { Errore "WowManagerTierDump.lua non trovato sotto $Wow. L'addon e' installato?" }

# -Subito prende il dump gia' sul disco, che pero' e' stato scritto PRIMA della copia
# qui sopra: sarebbe esattamente il caso che questo blocco esiste per evitare.
if ($Subito -and $Reload -gt 1) {
    Errore "l'addon era indietro e l'ho appena aggiornato: il dump sul disco e' ancora del codice vecchio. Rilancia senza -Subito."
}

if (-not $Subito) {
    for ($giro = 1; $giro -le $Reload; $giro++) {
        $prima = $dump.LastWriteTime
        Write-Host ""
        if ($Reload -gt 1) {
            Write-Host ("  In gioco: /reload  ({0} di {1})" -f $giro, $Reload) -ForegroundColor Cyan
        } else {
            Write-Host "  In gioco: /reload" -ForegroundColor Cyan
        }
        Write-Host ("  (aspetto un dump nuovo, max {0}s - Ctrl+C per annullare)" -f $AttesaMax)
        $scaduto = (Get-Date).AddSeconds($AttesaMax)
        while ((Get-Date) -lt $scaduto) {
            Start-Sleep -Seconds 2
            $dump = TrovaDump
            if ($dump.LastWriteTime -gt $prima) { break }
        }
        if ($dump.LastWriteTime -le $prima) {
            Errore "nessun dump nuovo entro $AttesaMax secondi. Rilancia, oppure usa -Subito per prendere quello vecchio."
        }
        if ($giro -lt $Reload) {
            Write-Host "  dump di scarto (codice vecchio), ne aspetto un altro." -ForegroundColor DarkGray
        } else {
            Write-Host "  dump ricevuto." -ForegroundColor Green
        }
    }
}

$lua = Get-Content -Raw -Encoding UTF8 $dump.FullName
Write-Host ("dump: {0}" -f $dump.LastWriteTime)

# --- 2. guardie ----------------------------------------------------------------
# Un dump preso mentre il client non ha caricato la collezione e' internamente
# COERENTE: ogni set a zero pezzi ma con il totale giusto, quindi mismatches resta
# vuoto e nulla lo distingue da uno buono. Incollarlo azzererebbe la collezione.
if ($lua -match '\["sospetto"\]\s*=\s*"([^"]+)"') { Errore "il dump si e' auto-segnalato: $($matches[1])" }
foreach ($campo in @("mismatches", "errors")) {
    if ($lua -match ('\["' + $campo + '"\]\s*=\s*\{\s*"')) {
        Errore "il campo $campo del dump non e' vuoto: elenco pezzi non fidato"
    }
}
$presi = 0
if ($lua -match '\["presi"\]\s*=\s*(\d+)') { $presi = [int]$matches[1] }
if ($presi -le 0) { Errore "il dump dice $presi pezzi collezionati: collezione non caricata" }

# --- 3. estrarre e sostituire ---------------------------------------------------
function Blocco($nome) {
    $re = '\["' + $nome + '"\]\s*=\s*"((?:[^"\\]|\\.)*)"'
    if ($lua -notmatch $re) { Errore "campo $nome assente dal dump" }
    # Un passaggio solo, non tre Replace in cascata: con '\\' trattato per ultimo un
    # backslash escapato seguito da n diventava un a capo invece di \ + n.
    return [regex]::Replace($matches[1], '\\(.)', {
        param($m)
        switch ($m.Groups[1].Value) {
            'n'     { "`n" }
            't'     { "`t" }
            'r'     { "`r" }
            default { $m.Groups[1].Value }
        }
    })
}
$blocchi = @{ "collected" = (Blocco "collectedJson"); "pieceList" = (Blocco "piecesJson") }

if (-not (Test-Path $Manifest)) { Errore "manifest non trovato: $Manifest" }
$primaPezzi = PezziCollezionati $Manifest
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
}

# --- 4. validare PRIMA di scrivere ----------------------------------------------
$testo = ($righe -join "`n")
try { $null = $testo | ConvertFrom-Json } catch { Errore "il risultato non e' JSON valido: $_" }
[System.IO.File]::WriteAllText(
    (Resolve-Path $Manifest), $testo, (New-Object System.Text.UTF8Encoding($false)))

$dopoPezzi = PezziCollezionati $Manifest
$delta = $dopoPezzi - $primaPezzi
Write-Host ("manifest: {0} pezzi collezionati ({1:+#;-#;0} rispetto a prima)" -f $dopoPezzi, $delta) -ForegroundColor Green

# --- 5. git ---------------------------------------------------------------------
if ($NoGit) {
    Write-Host "-NoGit: mi fermo qui. Committa a mano quando vuoi."
    exit 0
}

Push-Location $RepoRoot
try {

# Il conteggio dei pezzi NON basta a dire se c'e' qualcosa da salvare: pieceList
# cambia anche a parita' di pezzi (boss appena attribuiti, copertura fonte migliore
# dopo una modifica al dump). Prima si guardava solo $delta e un `git checkout`
# buttava via quelle modifiche in silenzio. Ora decide git: se il file non e'
# cambiato davvero, non c'e' niente da fare e non serve nemmeno ripristinarlo.
git diff --quiet -- $Manifest
$immutato = ($LASTEXITCODE -eq 0)
if ($immutato) {
    Write-Host "manifest identico a quello committato: niente da fare." -ForegroundColor Yellow
    exit 0
}

# Non si committa il lavoro altrui: se ci sono altri file modificati ci si ferma.
# A mano, non con GetRelativePath: quello e' .NET Core, PS 5.1 gira su Framework.
$pieno = (Resolve-Path $Manifest).Path
$radice = (Resolve-Path $RepoRoot).Path.TrimEnd('\') + '\'
$relManifest = $pieno.Substring($radice.Length) -replace '\\', '/'
$sporchi = @(git status --porcelain | ForEach-Object { $_.Substring(3) } |
             Where-Object { $_ -ne $relManifest })
if ($sporchi.Count -gt 0) {
    Write-Host "altri file modificati, non committo da solo:" -ForegroundColor Yellow
    $sporchi | ForEach-Object { Write-Host "   $_" }
    Write-Host "manifest aggiornato lo stesso: committa tu."
    exit 0
}

git add -- $Manifest
if ($delta -eq 0) {
    # Il file e' cambiato ma i pezzi no: e' pieceList, cioe' provenienze migliorate.
    git commit -q -m "Transmog: provenienze dei pezzi aggiornate"
} else {
    git commit -q -m ("Transmog: collezione aggiornata, +{0} pezzi" -f $delta)
}
git push -q
Write-Host "committato e pushato." -ForegroundColor Green

} finally { Pop-Location }
