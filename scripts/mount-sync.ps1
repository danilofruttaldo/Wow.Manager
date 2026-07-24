# Sincronizza la collezione cavalcature: aspetta il dump, rigenera mounts/manifest.json,
# scarica le icone mancanti, committa.
#
#   .\scripts\mount-sync.ps1
#   -> "fai /reload in gioco", aspetta, e da li' in poi fa tutto da solo
#
#   -Subito       usa il dump gia' sul disco invece di aspettarne uno nuovo
#   -NoGit        aggiorna il manifest e si ferma li'
#   -NoIcone      salta la risoluzione/scaricamento delle icone (solo dati)
#   -MaxIcone N   ne risolve al massimo N e rimanda il resto al giro dopo
#
# In gioco basta UN /reload: l'addon rigenera il dump su PLAYER_LOGOUT, che scatta
# anche col reload. Il /wmmount serve solo se lo vuoi vedere subito in chat.
# Due reload servono solo dopo aver modificato mount-dump.lua: il primo scrive
# ancora col codice vecchio, il secondo col nuovo.
#
# A differenza del transmog qui il manifest e' INTERAMENTE generato: non contiene
# nulla di redazionale, quindi si riscrive per intero a ogni giro. L'unico dato che
# non viene dal gioco e' il nome dell'icona di ogni mount (il client espone solo un
# fileID numerico, che sul web non si puo' usare): si risolve una volta su Wowhead e
# si conserva nel manifest, cosi' i giri successivi non ripetono la ricerca.

param(
    [switch]$Subito,
    [switch]$NoGit,
    [switch]$NoIcone,
    # Tetto di icone da risolvere in un giro. Serve al PRIMO popolamento, dove ce ne
    # sono un migliaio: la ricerca su Wowhead e' una richiesta per mount, e un'unica
    # sessione lunghissima che si interrompe a meta' butterebbe via tutto il lavoro,
    # perche' i nomi si salvano solo scrivendo il manifest. Con un tetto lo script si
    # rilancia finche' non ne restano: ogni giro scrive quello che ha risolto.
    [int]$MaxIcone = 0,
    [int]$AttesaMax = 300,
    # Ancorati alla posizione dello script, non alla cwd: lanciato da scripts\ il
    # path relativo non risolverebbe e git finirebbe sul repo della cwd.
    [string]$Manifest = (Join-Path (Split-Path $PSScriptRoot -Parent) "mounts\manifest.json"),
    [string]$Wow      = "C:\Program Files (x86)\World of Warcraft"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$IconDir  = Join-Path $RepoRoot "public\icons\mount"
# PS 5.1: senza TLS 1.2 esplicito le chiamate https falliscono, e la barra di
# avanzamento di Invoke-WebRequest rallenta ogni download di ordini di grandezza.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) WowManagerMountSync/1.0"

function Errore($msg) {
    Write-Host "STOP: $msg" -ForegroundColor Red
    exit 1
}

function TrovaDump {
    # Cercato, non scritto a mano: il percorso contiene il nome dell'account.
    return Get-ChildItem -Path (Join-Path $Wow "_retail_\WTF\Account") -Recurse `
           -Filter "WowManagerMountDump.lua" -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -like "*SavedVariables*" } |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# --- 1. il dump ----------------------------------------------------------------
$dump = TrovaDump
if (-not $dump) { Errore "WowManagerMountDump.lua non trovato sotto $Wow. L'addon e' installato e il client riavviato?" }

if (-not $Subito) {
    $prima = $dump.LastWriteTime
    Write-Host ""
    Write-Host "  In gioco: /reload" -ForegroundColor Cyan
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
    Write-Host "  dump ricevuto." -ForegroundColor Green
}

$lua = Get-Content -Raw -Encoding UTF8 $dump.FullName
Write-Host ("dump: {0}" -f $dump.LastWriteTime)

# --- 2. guardie ----------------------------------------------------------------
# Un dump preso prima che il client abbia caricato la collezione elenca tutte le
# mount ma con nessuna presa: e' internamente coerente, quindi solo il campo
# `sospetto` (che scrive l'addon) lo distingue da uno buono.
if ($lua -match '\["sospetto"\]\s*=\s*"([^"]+)"') { Errore "il dump si e' auto-segnalato: $($matches[1])" }
$presi = 0
$totale = 0
if ($lua -match '\["presi"\]\s*=\s*(\d+)')  { $presi  = [int]$matches[1] }
if ($lua -match '\["totale"\]\s*=\s*(\d+)') { $totale = [int]$matches[1] }
if ($presi -le 0)  { Errore "il dump dice $presi mount collezionate: collezione non caricata" }
if ($totale -le 0) { Errore "il dump non elenca nessuna mount" }

# --- 3. estrarre i campi --------------------------------------------------------
function Blocco($nome) {
    $re = '\["' + $nome + '"\]\s*=\s*"((?:[^"\\]|\\.)*)"'
    if ($lua -notmatch $re) { Errore "campo $nome assente dal dump" }
    # Un passaggio solo, non tre Replace in cascata: con '\\' trattato per ultimo un
    # backslash escapato seguito da n diventerebbe un a capo invece di \ + n.
    #
    # ⚠️ Qui convivono DUE livelli di \n e vanno distinti: quelli STRUTTURALI del JSON
    # (uno per mount, messi dal dump) devono tornare a capo veri, mentre quelli DENTRO
    # srcText -- il testo di provenienza e' multiriga -- nel file sono \\n e devono
    # restare l'escape \n del JSON. Se ne occupa l'ordine: '\\' viene consumato per
    # primo come coppia, quindi la n che segue resta lettera.
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
$mounts   = Blocco "mountsJson"
$sorgenti = Blocco "sorgentiJson"
$build    = ""
if ($lua -match '\["build"\]\s*=\s*"([^"]*)"') { $build = $matches[1] }

# --- 4. icone -------------------------------------------------------------------
# Nome icona gia' noto dal manifest precedente: si riusa, cosi' ogni mount si cerca
# una volta sola nella vita del repo e i giri successivi toccano solo le novita'.
$noti = @{}
if (Test-Path $Manifest) {
    $vecchio = Get-Content -Raw -Encoding UTF8 $Manifest | ConvertFrom-Json
    foreach ($m in $vecchio.mounts) {
        if ($m.icon) { $noti[[string]$m.spell] = [string]$m.icon }
    }
}

function IconaDiSpell($spellID) {
    # Via principale: l'endpoint tooltip di Wowhead, che risponde JSON con il nome
    # dell'icona. Ripiego: la pagina della spell, dove il nome sta nell'og:image --
    # lo stesso trucco usato per gli avatar degli addon.
    try {
        $r = Invoke-RestMethod -Uri "https://nether.wowhead.com/tooltip/spell/$spellID" `
                               -Headers @{ "User-Agent" = $UA } -TimeoutSec 20
        if ($r.icon) { return [string]$r.icon }
    } catch { }
    try {
        $h = Invoke-WebRequest -Uri "https://www.wowhead.com/spell=$spellID" `
                               -Headers @{ "User-Agent" = $UA } -TimeoutSec 20 -UseBasicParsing
        if ($h.Content -match 'icons/large/([a-z0-9_]+)\.jpg') { return $matches[1] }
    } catch { }
    return $null
}

function ScaricaIcona($nome) {
    $file = Join-Path $IconDir "$nome.jpg"
    if (Test-Path $file) { return $true }
    try {
        Invoke-WebRequest -Uri "https://wow.zamimg.com/images/wow/icons/large/$nome.jpg" `
                          -Headers @{ "User-Agent" = $UA } -OutFile $file -TimeoutSec 30 -UseBasicParsing
        return $true
    } catch {
        if (Test-Path $file) { Remove-Item $file -Force }
        return $false
    }
}

if (-not (Test-Path $IconDir)) { New-Item -ItemType Directory -Force -Path $IconDir | Out-Null }

$righe = $mounts -split "`n"
$nuoveIcone = 0
$senzaIcona = 0
$daCercare = 0
if (-not $NoIcone) {
    foreach ($l in $righe) { if ($l -match '"spell":(\d+)' -and -not $noti[$matches[1]]) { $daCercare++ } }
    if ($daCercare -gt 0) { Write-Host ("icone da risolvere: {0}" -f $daCercare) }
}

$fatte = 0
$rimandate = 0
for ($i = 0; $i -lt $righe.Count; $i++) {
    $l = $righe[$i].TrimEnd()
    if ($l -notmatch '"spell":(\d+)') { continue }
    $spell = $matches[1]
    $icona = $noti[$spell]
    if (-not $icona -and -not $NoIcone -and $spell -ne "0") {
        if ($MaxIcone -gt 0 -and $fatte -ge $MaxIcone) {
            $rimandate++
            continue    # niente campo icon: la cerca il giro dopo
        }
        $icona = IconaDiSpell $spell
        $fatte++
        if ($fatte % 25 -eq 0) { Write-Host ("  ...{0}/{1}" -f $fatte, $daCercare) }
        Start-Sleep -Milliseconds 60   # gentile con Wowhead
    }
    if ($icona) {
        if (-not $NoIcone) {
            if (ScaricaIcona $icona) {
                if (-not $noti[$spell]) { $nuoveIcone++ }
            } else {
                $icona = $null
            }
        }
    }
    if (-not $icona) { $senzaIcona++; continue }

    $coda = ""
    if ($l.EndsWith(",")) { $coda = ","; $l = $l.Substring(0, $l.Length - 1) }
    $righe[$i] = $l.Substring(0, $l.Length - 1) + (',"icon":"{0}"}}' -f $icona) + $coda
}

# --- 5. scrivere il manifest ----------------------------------------------------
$oggi = Get-Date -Format "yyyy-MM-dd"
$testo = @(
    "{",
    '  "_meta": {',
    ('    "generated": "{0}",' -f $oggi),
    ('    "build": "{0}",' -f $build),
    ('    "collected": {0},' -f $presi),
    ('    "total": {0}' -f $totale),
    "  },",
    ('  "sources": {0},' -f $sorgenti),
    ('  "mounts": {0}' -f ($righe -join "`n")),
    "}"
) -join "`n"

try { $null = $testo | ConvertFrom-Json } catch { Errore "il risultato non e' JSON valido: $_" }

$primaPrese = 0
if (Test-Path $Manifest) {
    $v = Get-Content -Raw -Encoding UTF8 $Manifest | ConvertFrom-Json
    $primaPrese = [int]$v._meta.collected
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path $Manifest -Parent) | Out-Null
}
[System.IO.File]::WriteAllText($Manifest, $testo, (New-Object System.Text.UTF8Encoding($false)))

$delta = $presi - $primaPrese
Write-Host ("manifest: {0}/{1} mount collezionate ({2:+#;-#;0} rispetto a prima)" -f $presi, $totale, $delta) -ForegroundColor Green
if ($nuoveIcone -gt 0) { Write-Host ("icone scaricate: {0}" -f $nuoveIcone) }
if ($rimandate -gt 0) {
    Write-Host ("icone rimandate al prossimo giro: {0} (tetto -MaxIcone {1})" -f $rimandate, $MaxIcone) -ForegroundColor Cyan
    Write-Host "  rilancia con -Subito per continuare da dove e' rimasto."
} elseif ($senzaIcona -gt 0) {
    Write-Host ("senza icona: {0} (la card mostra l'iniziale)" -f $senzaIcona) -ForegroundColor Yellow
}

# --- 6. git ---------------------------------------------------------------------
if ($NoGit) {
    Write-Host "-NoGit: mi fermo qui. Committa a mano quando vuoi."
    exit 0
}

Push-Location $RepoRoot
try {

git add -- "mounts/manifest.json" "public/icons/mount"
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "niente di nuovo da committare." -ForegroundColor Yellow
    exit 0
}

# Non si committa il lavoro altrui: se ci sono altri file modificati ci si ferma.
$sporchi = @(git status --porcelain | ForEach-Object { $_.Substring(3) } |
             Where-Object { $_ -ne "mounts/manifest.json" -and $_ -notlike "public/icons/mount/*" })
if ($sporchi.Count -gt 0) {
    Write-Host "altri file modificati, non committo da solo:" -ForegroundColor Yellow
    $sporchi | ForEach-Object { Write-Host "   $_" }
    Write-Host "manifest aggiornato lo stesso: committa tu."
    exit 0
}

if ($delta -eq 0) {
    git commit -q -m "Mount: dati della collezione aggiornati"
} else {
    git commit -q -m ("Mount: collezione aggiornata, {0:+#;-#;0} mount" -f $delta)
}
git push -q
Write-Host "committato e pushato." -ForegroundColor Green

} finally { Pop-Location }
