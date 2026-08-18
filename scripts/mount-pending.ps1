#Requires -Version 5.1
# Smaltisce il lavoro sulle mount che richiede Node, dalla postazione che ce l'ha.
#
#   .\scripts\mount-pending.ps1
#   -> git pull, vincoli di classe/razza, immagini del modello, commit, push
#
#   -NoGit    fa i due passi e si ferma li' (niente pull, niente commit)
#   -NoPull   non tocca git in entrata, ma committa e pusha il risultato
#
# Perche' esiste uno script apposta. Il repo si lavora da due macchine con capacita'
# DISGIUNTE: su quella con WoW ci sono i dump e i sync, ma non c'e' Node; su questa
# c'e' Node per il dev server, ma WoW non e' installato e un sync non partirebbe
# nemmeno. Quindi mount-sync.ps1 lascia indietro i suoi due passi in JS e li segnala,
# e il pendente si smaltisce di qua. Erano tre comandi piu' un commit da ricordare a
# mano: adesso e' uno.
#
# I due .mjs NON hanno bisogno del gioco -- leggono solo mounts/manifest.json e il
# web -- e servono solo quando compaiono cavalcature nuove: a collezione invariata
# questo script dice "niente in sospeso" e non fa nulla.

param(
    [switch]$NoGit,
    [switch]$NoPull,
    [string]$Manifest = (Join-Path (Split-Path $PSScriptRoot -Parent) "mounts\manifest.json")
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ImgDir   = Join-Path $RepoRoot "public\mounts"

function Errore($msg) {
    Write-Host "STOP: $msg" -ForegroundColor Red
    exit 1
}

# Conta cosa manca: mount senza il campo `class` (mai cercato) e display senza il
# .webp sul disco. Sono gli stessi due numeri che stampa mount-sync.ps1 al §5a.
function Pendenti($manifestPath) {
    $classe = 0
    $img = 0
    foreach ($l in (Get-Content -Encoding UTF8 $manifestPath)) {
        if ($l -match '"spell":(\d+)' -and $l -notmatch '"class":') { $classe++ }
        if ($l -match '"display":(\d+)' -and -not (Test-Path (Join-Path $ImgDir ($matches[1] + ".webp")))) { $img++ }
    }
    return @{ classe = $classe; img = $img }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Errore ("node non e' installato qui. Questo script va lanciato dalla postazione col dev server: " +
            "su quella con WoW ci sono i dump e i sync, non Node.")
}
if (-not (Test-Path $Manifest)) { Errore "manifest non trovato: $Manifest" }

Push-Location $RepoRoot
try {

# --- 1. allinearsi ---------------------------------------------------------------
# Il manifest lo scrive l'altra postazione: senza pull si lavorerebbe su dati vecchi
# e il commit finirebbe in conflitto. Con la copia di lavoro sporca non si tira, per
# non trascinare dentro un rebase il lavoro di qualcun altro.
$sporchi = @(git status --porcelain | ForEach-Object { $_.Substring(3) })
if (-not $NoGit -and -not $NoPull) {
    if ($sporchi.Count -gt 0) {
        Write-Host "copia di lavoro sporca: salto il pull." -ForegroundColor Yellow
        $sporchi | ForEach-Object { Write-Host "   $_" }
    } else {
        git pull --rebase -q
        if ($LASTEXITCODE -ne 0) { Errore "git pull fallito: allinea a mano e rilancia." }
        Write-Host "aggiornato da origin." -ForegroundColor Green
    }
}

# --- 2. cosa c'e' da fare --------------------------------------------------------
$prima = Pendenti $Manifest
if ($prima.classe -eq 0 -and $prima.img -eq 0) {
    Write-Host "niente in sospeso: nessuna mount nuova da controllare." -ForegroundColor Green
    exit 0
}
Write-Host ("in sospeso: {0} mount da controllare, {1} immagini da scaricare." -f $prima.classe, $prima.img) -ForegroundColor Cyan

# --- 3. vincolo di classe e razza ------------------------------------------------
# Tocca solo le mount che il campo `class` non ce l'hanno ancora: le altre sono
# cache. Una richiesta per mount, quindi il tempo lo fa il numero di novita'.
if ($prima.classe -gt 0) {
    Write-Host "vincoli di classe e razza..."
    & node (Join-Path $PSScriptRoot "mount-classes.mjs")
    if ($LASTEXITCODE -ne 0) { Write-Host "  (mount-classes ha segnalato un errore: i vincoli restano quelli di prima)" -ForegroundColor Yellow }
}

# --- 4. immagini del modello -----------------------------------------------------
# Il file su disco E' la cache (si chiama col displayID), quindi scarica solo le
# novita' e un'interruzione non fa perdere lavoro. Toglie anche le orfane.
if ($prima.img -gt 0) {
    Write-Host "immagini del modello..."
    & node (Join-Path $PSScriptRoot "mount-images.mjs")
    if ($LASTEXITCODE -ne 0) { Write-Host "  (mount-images ha segnalato un errore: le immagini restano quelle di prima)" -ForegroundColor Yellow }
}

# --- 5. cosa resta ---------------------------------------------------------------
# Restare indietro e' NORMALE su una parte: 7 modelli Blizzard non li pubblica (403
# stabile, non un intoppo di rete) e qualche mount un vincolo di classe non ce l'ha.
# Il numero si stampa lo stesso, cosi' un salto grosso si nota.
$dopo = Pendenti $Manifest
Write-Host ("fatto: mount da controllare {0} -> {1}, immagini mancanti {2} -> {3}" -f
    $prima.classe, $dopo.classe, $prima.img, $dopo.img) -ForegroundColor Green

# --- 6. git ----------------------------------------------------------------------
if ($NoGit) {
    Write-Host "-NoGit: mi fermo qui. Committa a mano quando vuoi."
    exit 0
}

git add -- "mounts/manifest.json" "public/mounts"
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "niente di nuovo da committare." -ForegroundColor Yellow
    exit 0
}

# Non si committa il lavoro altrui: se ci sono altri file modificati ci si ferma,
# come fa mount-sync.ps1.
$altri = @(git status --porcelain | ForEach-Object { $_.Substring(3) } |
           Where-Object { $_ -ne "mounts/manifest.json" -and $_ -notlike "public/mounts/*" })
if ($altri.Count -gt 0) {
    Write-Host "altri file modificati, non committo da solo:" -ForegroundColor Yellow
    $altri | ForEach-Object { Write-Host "   $_" }
    Write-Host "il lavoro e' fatto lo stesso: committa tu."
    exit 0
}

$fatteClasse = $prima.classe - $dopo.classe
$fatteImg = $prima.img - $dopo.img
git commit -q -m ("Mount: {0} vincoli e {1} immagini in piu'" -f $fatteClasse, $fatteImg)
# L'esito del push si GUARDA: e' il push a far ripartire GitHub Actions, quindi un
# commit rimasto in locale vuol dire sito fermo con la data "sync" vecchia.
git push -q
if ($LASTEXITCODE -ne 0) {
    Write-Host "committato, ma il PUSH E' FALLITO (git ha risposto $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "  il commit e' in locale: rilancia 'git push' quando la rete torna." -ForegroundColor Yellow
    exit 1
}
Write-Host "committato e pushato." -ForegroundColor Green

} finally { Pop-Location }
