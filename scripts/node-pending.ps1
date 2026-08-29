#Requires -Version 5.1
# Smaltisce TUTTO il lavoro che richiede Node, dalla postazione che ce l'ha.
#
#   .\scripts\node-pending.ps1
#   -> git pull, i quattro passi in JS, commit, push
#
#   -NoGit    fa i passi e si ferma li' (niente pull, niente commit)
#   -NoPull   non tocca git in entrata, ma committa e pusha il risultato
#
# Perche' esiste uno script apposta. Il repo si lavora da due macchine con capacita'
# DISGIUNTE: su quella con WoW ci sono i dump e i sync, ma non c'e' Node; su questa
# c'e' Node per il dev server, ma WoW non e' installato e un sync non partirebbe
# nemmeno. Tutto cio' che ha bisogno di `sharp` o di una ricerca sul web resta quindi
# indietro sull'altra macchina, e si smaltisce di qua.
#
# ⚠️ NON e' solo roba di mount, anche se sono le mount a segnalarlo. I lavori sono
# quattro, e per tre di essi nessuno stampa niente quando restano indietro:
#   1. vincoli di classe/razza delle mount   mount-classes.mjs   (lo dice mount-sync)
#   2. immagini dei modelli delle mount      mount-images.mjs    (lo dice mount-sync)
#   3. anteprime degli addon                 addon-images.mjs    (non lo dice nessuno)
#   4. miniature degli screenshot UI         make-thumbs.mjs     (lo dice npm run validate)
# Questo script li conta tutti e quattro e lancia solo quelli che servono: se non c'e'
# niente da fare dice "niente in sospeso" ed esce senza toccare nulla.

param(
    [switch]$NoGit,
    [switch]$NoPull
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent

function Errore($msg) {
    Write-Host "STOP: $msg" -ForegroundColor Red
    exit 1
}

function Percorso($rel) { return (Join-Path $RepoRoot $rel) }

# ── Quanto manca, lavoro per lavoro ───────────────────────────────────────────
# Le mount: gli stessi due conteggi che stampa mount-sync.ps1 al §5a, cioe' le voci
# che il campo `class` non ce l'hanno ancora (stringa vuota = "cercata, nessun
# vincolo", quindi NON conta) e i displayID senza il .webp sul disco.
function PendentiMount {
    $classe = 0
    $img = 0
    $manifest = Percorso "mounts\manifest.json"
    $imgDir = Percorso "public\mounts"
    if (-not (Test-Path $manifest)) { return @{ classe = 0; img = 0 } }
    $correnti = @{}
    foreach ($l in (Get-Content -Encoding UTF8 $manifest)) {
        if ($l -match '"spell":(\d+)' -and $l -notmatch '"class":') { $classe++ }
        if ($l -match '"display":(\d+)') {
            $correnti[$matches[1]] = $true
            if (-not (Test-Path (Join-Path $imgDir ($matches[1] + ".webp")))) { $img++ }
        }
    }
    # Le forme alternative contano quanto il display corrente: mount-images.mjs le
    # scarica e non le considera orfane, quindi contando i soli correnti si direbbe
    # "niente in sospeso" mentre un render manca davvero. Vedi mounts/display-noti.json.
    $noti = Percorso "mounts\display-noti.json"
    if (Test-Path $noti) {
        $j = Get-Content -Raw -Encoding UTF8 $noti | ConvertFrom-Json
        foreach ($p in $j.PSObject.Properties) {
            foreach ($d in $p.Value) {
                if ($correnti.ContainsKey([string]$d)) { continue }
                if (-not (Test-Path (Join-Path $imgDir ("$d.webp")))) { $img++ }
            }
        }
    }
    return @{ classe = $classe; img = $img }
}

# Le anteprime degli addon: manca il file, OPPURE il `preview` nel manifest non e'
# piu' quello da cui l'immagine e' stata fatta. Il secondo caso e' il motivo per cui
# esiste addons/img-fonti.json: il file si chiama con la chiave dell'addon, quindi
# cambiando l'URL il .webp vecchio resterebbe li' in silenzio.
function PendentiAddon {
    $manifest = Percorso "addons\manifest.json"
    if (-not (Test-Path $manifest)) { return 0 }
    $addons = (Get-Content -Raw -Encoding UTF8 $manifest | ConvertFrom-Json).addons
    $fonti = $null
    $fFonti = Percorso "addons\img-fonti.json"
    if (Test-Path $fFonti) { $fonti = Get-Content -Raw -Encoding UTF8 $fFonti | ConvertFrom-Json }
    $n = 0
    foreach ($p in $addons.PSObject.Properties) {
        $webp = Percorso ("public\addon-img\" + $p.Name + ".webp")
        if (-not (Test-Path $webp)) { $n++; continue }
        $preview = $p.Value.preview
        if ($preview -and $fonti) {
            $usata = $fonti.PSObject.Properties | Where-Object { $_.Name -eq $p.Name }
            if ($usata -and $usata.Value -ne $preview) { $n++ }
        }
    }
    return $n
}

# Le miniature degli screenshot: e' l'unico dei quattro che `npm run validate` gia'
# controlla, quindi qui si arriva di solito con zero.
function PendentiMiniature {
    $dir = Percorso "public\screenshots"
    if (-not (Test-Path $dir)) { return 0 }
    $thumb = Join-Path $dir "thumb"
    $n = 0
    foreach ($f in Get-ChildItem $dir -Filter *.webp -File) {
        if (-not (Test-Path (Join-Path $thumb $f.Name))) { $n++ }
    }
    return $n
}

# ⚠️ NON chiamarla `Node`: in PowerShell le funzioni hanno la precedenza sugli
# eseguibili, quindi `& node` dentro una funzione chiamata Node richiama se stessa
# all'infinito ("call depth overflow"). Preso al primo giro di prova.
function Lancia($script) {
    & node (Join-Path $PSScriptRoot $script)
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("  ({0} ha segnalato un errore: quella parte resta com'era)" -f $script) -ForegroundColor Yellow
    }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Errore ("node non e' installato qui. Questo script va lanciato dalla postazione col dev server: " +
            "su quella con WoW ci sono i dump e i sync, non Node.")
}

Push-Location $RepoRoot
try {

# --- 1. allinearsi ---------------------------------------------------------------
# I manifest li scrive l'altra postazione: senza pull si lavorerebbe su dati vecchi e
# il commit finirebbe in conflitto. Con la copia di lavoro sporca non si tira, per non
# trascinare dentro un rebase il lavoro di qualcun altro.
if (-not $NoGit -and -not $NoPull) {
    $sporchi = @(git status --porcelain | ForEach-Object { $_.Substring(3) })
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
$mount = PendentiMount
$addon = PendentiAddon
$mini  = PendentiMiniature
$totale = $mount.classe + $mount.img + $addon + $mini
if ($totale -eq 0) {
    Write-Host "niente in sospeso: nessun lavoro da fare qui." -ForegroundColor Green
    exit 0
}
Write-Host "in sospeso:" -ForegroundColor Cyan
if ($mount.classe -gt 0) { Write-Host ("   {0,4} mount da controllare (vincolo di classe/razza)" -f $mount.classe) }
if ($mount.img -gt 0)    { Write-Host ("   {0,4} immagini di modelli da scaricare" -f $mount.img) }
if ($addon -gt 0)        { Write-Host ("   {0,4} anteprime di addon da rifare" -f $addon) }
if ($mini -gt 0)         { Write-Host ("   {0,4} miniature di screenshot da generare" -f $mini) }

# --- 3. i quattro passi, solo quelli che servono ---------------------------------
# Ognuno tiene la propria cache sul disco (il campo `class` nel manifest, il file
# col nome del displayID, img-fonti.json, la cartella thumb), quindi rilanciarli non
# rifa' lavoro gia' fatto e un'interruzione non fa perdere niente.
if ($mount.classe -gt 0) { Write-Host "vincoli di classe e razza..."; Lancia "mount-classes.mjs" }
if ($mount.img -gt 0)    { Write-Host "immagini dei modelli...";      Lancia "mount-images.mjs" }
if ($addon -gt 0)        { Write-Host "anteprime degli addon...";     Lancia "addon-images.mjs" }
if ($mini -gt 0)         { Write-Host "miniature degli screenshot..."; Lancia "make-thumbs.mjs" }

# --- 4. cosa resta ---------------------------------------------------------------
# ⚠️ Restare indietro su una parte e' NORMALE e non e' un errore: 7 modelli Blizzard
# non li pubblica (403 stabile, non un intoppo di rete) e il 98% delle mount un
# vincolo di classe non ce l'ha -- per quelle il campo resta stringa vuota, che vuol
# dire "cercata, nessun vincolo", e infatti al giro dopo non si ricercano.
$mountDopo = PendentiMount
$addonDopo = PendentiAddon
$miniDopo  = PendentiMiniature
Write-Host ("fatto: vincoli {0} -> {1}, immagini {2} -> {3}, anteprime {4} -> {5}, miniature {6} -> {7}" -f
    $mount.classe, $mountDopo.classe, $mount.img, $mountDopo.img,
    $addon, $addonDopo, $mini, $miniDopo) -ForegroundColor Green

# --- 5. git ----------------------------------------------------------------------
if ($NoGit) {
    Write-Host "-NoGit: mi fermo qui. Committa a mano quando vuoi."
    exit 0
}

$miei = @("mounts/manifest.json", "public/mounts", "public/addon-img",
          "addons/img-fonti.json", "public/screenshots/thumb")
git add -- $miei
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "niente di nuovo da committare." -ForegroundColor Yellow
    exit 0
}

# Non si committa il lavoro altrui: se ci sono altri file modificati ci si ferma,
# come fanno i due sync.
$altri = @(git status --porcelain | ForEach-Object { $_.Substring(3) } | Where-Object {
    $f = $_
    -not ($miei | Where-Object { $f -eq $_ -or $f -like ($_ + "/*") })
})
if ($altri.Count -gt 0) {
    Write-Host "altri file modificati, non committo da solo:" -ForegroundColor Yellow
    $altri | ForEach-Object { Write-Host "   $_" }
    Write-Host "il lavoro e' fatto lo stesso: committa tu."
    exit 0
}

$pezzi = @()
if (($mount.classe - $mountDopo.classe) -gt 0) { $pezzi += ("{0} vincoli mount" -f ($mount.classe - $mountDopo.classe)) }
if (($mount.img - $mountDopo.img) -gt 0)       { $pezzi += ("{0} immagini mount" -f ($mount.img - $mountDopo.img)) }
if (($addon - $addonDopo) -gt 0)               { $pezzi += ("{0} anteprime addon" -f ($addon - $addonDopo)) }
if (($mini - $miniDopo) -gt 0)                 { $pezzi += ("{0} miniature" -f ($mini - $miniDopo)) }
$titolo = "Node: " + $(if ($pezzi.Count -gt 0) { $pezzi -join ", " } else { "pendente smaltito" })
# L'hook commit-msg rifiuta i titoli oltre i 72 caratteri.
if ($titolo.Length -gt 72) { $titolo = $titolo.Substring(0, 69) + "..." }
git commit -q -m $titolo
# L'esito del push si GUARDA: e' il push a far ripartire GitHub Actions, quindi un
# commit rimasto in locale vuol dire sito fermo con la data "sync" vecchia.
git push -q
if ($LASTEXITCODE -ne 0) {
    Write-Host "committato, ma il PUSH E' FALLITO (git ha risposto $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "  il commit e' in locale: rilancia 'git push' quando la rete torna." -ForegroundColor Yellow
    exit 1
}
Write-Host ("committato e pushato: " + $titolo) -ForegroundColor Green

} finally { Pop-Location }
