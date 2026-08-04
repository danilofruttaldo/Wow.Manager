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
# Se l'addon installato e' indietro rispetto al repo lo script lo aggiorna da se'
# (vedi §0) e allora i reload diventano due: te lo chiede lui, uno alla volta.
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
    # ⚠️ UNICA manopola redazionale di questo script, da aggiornare a ogni espansione:
    # serve a capire quale stagione gladiator e' ancora in corso (vedi il taglio delle
    # non piu' ottenibili). Il numero della stagione NON si scrive qui, si ricava dai
    # dati: basta il nome dell'espansione.
    [string]$EspansioneCorrente = "Midnight",
    [int]$AttesaMax = 300,
    # Ancorati alla posizione dello script, non alla cwd: lanciato da scripts\ il
    # path relativo non risolverebbe e git finirebbe sul repo della cwd.
    [string]$Manifest = (Join-Path (Split-Path $PSScriptRoot -Parent) "mounts\manifest.json"),
    [string]$Wow      = "C:\Program Files (x86)\World of Warcraft"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$IconDir  = Join-Path $RepoRoot "public\icons\mount"
# Le immagini del modello le SCRIVE scripts/mount-images.mjs (vedi §5a); qui la
# cartella serve solo a contare quelle che mancano, quando Node non c'e'.
$ImgDir   = Join-Path $RepoRoot "public\mounts"
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

# --- 0. l'addon nella cartella di gioco -----------------------------------------
# Il gioco legge la copia in Interface/AddOns, NON il .lua del repo: finche' non la
# si sovrascrive il dump esce col codice vecchio e il sync reincolla i dati vecchi
# senza che nulla lo segnali -- i dati restano coerenti, quindi nessuna guardia a
# valle se ne accorge. E' successo il 2026-08-04: l'addon installato era fermo alla
# versione che filtrava il solo "(PH)" e cinque cavalcature finte sono tornate in
# pagina. Percio' la copia la fa lo script, non la memoria di chi lo lancia.
$AddonDir = Join-Path $Wow "_retail_\Interface\AddOns\WowManagerMountDump"
$Reload = 1
if (Test-Path $AddonDir) {
    $copiati = @()
    foreach ($f in @(@{ src = "mount-dump.lua"; dst = "WowManagerMountDump.lua" },
                     @{ src = "WowManagerMountDump.toc"; dst = "WowManagerMountDump.toc" })) {
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
if (-not $dump) { Errore "WowManagerMountDump.lua non trovato sotto $Wow. L'addon e' installato e il client riavviato?" }

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

# Terza guardia, e non e' teorica: il 2026-08-04 un dump e' uscito con `spell` a ZERO
# su tutte e 1617 le voci -- nomi, provenienze e collezionate giuste, `presi` a 699,
# `sospetto` vuoto. Cioe' ha passato tutte le guardie di sopra. Ma la spell e' la
# chiave con cui si ritrova l'icona nel manifest precedente: a zero, la cache non
# aggancia niente, tutte le mount risultano "senza icona", e al §5c quelle 1184 icone
# diventano orfane e vengono CANCELLATE. Un dump buono ne ha zero, quindi la soglia
# puo' essere stretta.
$conSpell  = ([regex]::Matches($mounts, '"spell":')).Count
$spellZero = ([regex]::Matches($mounts, '"spell":0[,}]')).Count
if ($conSpell -gt 0 -and $spellZero -gt [Math]::Max(20, $conSpell * 0.05)) {
    Errore "$spellZero mount su $conSpell hanno spell 0: il client non ha dato gli spellID. Rifai /reload e rilancia."
}

# --- 4bis. nomi degli oggetti usati come prezzo ----------------------------------
# Il dump lascia un segnaposto {item:ID} dove il vendor vuole un OGGETTO invece di
# una valuta (Mark of Honor, Drowned Mana, Essence of the Storm...). Il nome non si
# chiede al client -- GetItemInfo tace finche' l'oggetto non e' in cache, e per roba
# mai vista non ci arriva mai: misurato, 31 nomi su 32 mancanti anche dopo aver
# chiesto il caricamento. Qui si risolve su Wowhead una volta sola e si conserva nel
# manifest (blocco `items`), che e' anche la cache dei giri successivi.
# Il manifest precedente si legge QUI e non piu' avanti: e' la cache sia dei nomi
# degli oggetti sia delle icone, e questo blocco viene prima di quello delle icone.
$vecchio = $null
if (Test-Path $Manifest) { $vecchio = Get-Content -Raw -Encoding UTF8 $Manifest | ConvertFrom-Json }
$itemNomi = @{}
if ($vecchio -and $vecchio.items) {
    foreach ($p in $vecchio.items.PSObject.Properties) { $itemNomi[$p.Name] = [string]$p.Value }
}
# La risoluzione vera sta piu' sotto (4c), dopo che $righe esiste ed e' stata
# filtrata: qui si carica solo la cache.

# --- 4. icone -------------------------------------------------------------------
# Nome icona gia' noto dal manifest precedente: si riusa, cosi' ogni mount si cerca
# una volta sola nella vita del repo e i giri successivi toccano solo le novita'.
$noti = @{}
# Vincoli di classe e razza gia' cercati: la stringa vuota vale "cercato, nessun
# requisito" ed e' diversa da "mai cercato" (assente), altrimenti le mount senza vincoli
# si ricercherebbero a ogni giro -- che sono il 96%.
# ⚠️ Qui non si RISOLVONO (lo fa mount-classes.mjs al §5b): si riportano avanti, perche'
# il dump non li conosce e il manifest precedente e' la loro unica cache.
$notiClasse = @{}
$notiRazza = @{}
if ($vecchio) {
    foreach ($m in $vecchio.mounts) {
        if ($m.icon) { $noti[[string]$m.spell] = [string]$m.icon }
        if ($null -ne $m.class) { $notiClasse[[string]$m.spell] = [string]$m.class }
        if ($null -ne $m.race)  { $notiRazza[[string]$m.spell]  = [string]$m.race }
    }
}

# Il nome dell'icona, che il client non da' (espone solo un fileID numerico).
#
# ⚠️ IL VINCOLO DI CLASSE NON SI RISOLVE PIU' QUI. Lo faceva, con la sola riga
# "Requires <classe>" del blocco `wowhead-tooltip-requirements`, e prendeva 19 mount su
# 52: restavano fuori TUTTE le cavalcature di classe di Legion, il cui vincolo non sta
# sulla spell ma sulla quest che le consegna. Ci vogliono tre segnali diversi, uno dei
# quali e' una seconda pagina da spogliare: sta tutto in scripts/mount-classes.mjs,
# chiamato al §5b. Qui la classe si porta avanti e basta (la cache e' il manifest).
#
# Ripiego per l'icona: la pagina della spell, dove il nome sta nell'og:image -- lo
# stesso trucco usato per gli avatar degli addon.
function DatiDiSpell($spellID) {
    $icona = $null
    try {
        $r = Invoke-RestMethod -Uri "https://nether.wowhead.com/tooltip/spell/$spellID" `
                               -Headers @{ "User-Agent" = $UA } -TimeoutSec 20
        if ($r.icon) { $icona = [string]$r.icon }
    } catch { }
    if (-not $icona) {
        try {
            $h = Invoke-WebRequest -Uri "https://www.wowhead.com/spell=$spellID" `
                                   -Headers @{ "User-Agent" = $UA } -TimeoutSec 20 -UseBasicParsing
            if ($h.Content -match 'icons/large/([a-z0-9_]+)\.jpg') { $icona = $matches[1] }
        } catch { }
    }
    return $icona
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

# --- 4b. via le cavalcature non piu' ottenibili ---------------------------------
# Tre regole, in ordine di autorevolezza. Solo la prima viene dal gioco.
#
# 1. "Legacy": il client stesso, al posto della provenienza, scrive quella riga
#    (Amani War Bear, i Qiraji Battle Tank dell'evento, i nether drake dei gladiator
#    piu' vecchi). E' l'unica fonte macchina che esista: Wowhead segnala gli stessi
#    casi e nulla di piu'.
# 2. Gladiator di stagione passata: il client NON li marca, quindi il criterio e'
#    nostro. Non si tolgono per nome -- cancellerebbe anche la stagione in corso,
#    che si prende ancora -- ma si tiene la sola stagione PIU' RECENTE
#    dell'espansione corrente, ricavata dai dati stessi: quando esce la stagione
#    nuova la vecchia decade da se', senza toccare lo script.
# 3. Challenge mode: una sola mount (Challenger's War Yeti).
#    ⚠️ La regola e' ancorata a "Achievement: Challenge ", NON alla parola
#    "Challenge": "Challenger's Cache" compare nella provenienza di 7 mount da
#    mitica+ che si prendono benissimo, e una regola larga le cancellerebbe.
#
# Il Trading Card Game resta DENTRO per scelta: le carte si comprano ancora
# sull'usato, quindi non sono "non piu' ottenibili" ma solo scomode.
#
# Si filtra QUI e non nel dump di proposito: il dump resta lo specchio fedele del
# diario, e siccome il taglio viene prima della risoluzione delle icone, le escluse
# non vengono nemmeno cercate su Wowhead.

# Stagione piu' recente dell'espansione corrente, letta dai dati.
$stagioneMax = 0
foreach ($l in $righe) {
    if ($l -match ('Gladiator: ' + [regex]::Escape($EspansioneCorrente) + ' Season (\d+)')) {
        if ([int]$matches[1] -gt $stagioneMax) { $stagioneMax = [int]$matches[1] }
    }
}

function MotivoEsclusione($parti) {
    if ($parti -contains 'Legacy') { return 'Legacy (lo dice il client)' }
    foreach ($p in $parti) {
        if ($p -match '^Achievement: Challenge ') { return 'challenge mode' }
        if ($p -match 'Gladiator: (.+?) Season (\d+)$') {
            $exp = $matches[1]
            $st = [int]$matches[2]
            if (-not ($exp -eq $EspansioneCorrente -and $st -eq $stagioneMax)) {
                return 'gladiator, stagione passata'
            }
        }
    }
    return $null
}

$tolte = @()
$motivi = @{}
$tenute = New-Object System.Collections.ArrayList
foreach ($l in $righe) {
    $motivo = $null
    if ($l -match '"srcText":"((?:[^"\\]|\\.)*)"') {
        # srcText porta gli a capo come \n letterali: si spezza su quelli e si
        # ragiona per RIGA, non per sottostringa.
        $motivo = MotivoEsclusione ($matches[1] -split '\\n')
    }
    if ($motivo) {
        if ($l -match '"name":"((?:[^"\\]|\\.)*)"') { $tolte += $matches[1] }
        $motivi[$motivo] = ($motivi[$motivo] + 1)
    } else {
        [void]$tenute.Add($l)
    }
}
$righe = $tenute.ToArray()
# L'ultima riga rimasta non deve portare la virgola: se le tolte erano in fondo,
# il JSON finirebbe con una virgola pendente.
for ($i = $righe.Count - 1; $i -ge 0; $i--) {
    if ($righe[$i].TrimEnd().EndsWith("},")) {
        $righe[$i] = $righe[$i].TrimEnd().TrimEnd(",")
        break
    }
    if ($righe[$i].TrimEnd().EndsWith("}")) { break }
}
if ($tolte.Count -gt 0) {
    Write-Host ("non piu' ottenibili, escluse: {0}" -f $tolte.Count)
    foreach ($k in ($motivi.Keys | Sort-Object)) { Write-Host ("   {0,-28} {1}" -f $k, $motivi[$k]) }
}

# --- 4c. i nomi degli oggetti-prezzo --------------------------------------------
# ⚠️ Deve stare QUI, non prima: $righe nasce poche righe sopra. Al primo tentativo
# questo blocco era sopra la sua creazione, girava a vuoto senza dire niente e 66
# mount finivano nel manifest col segnaposto grezzo dentro.
$daRisolvere = New-Object System.Collections.ArrayList
foreach ($l in $righe) {
    foreach ($mm in [regex]::Matches($l, '\{item:(\d+)\}')) {
        $id = $mm.Groups[1].Value
        if (-not $itemNomi.ContainsKey($id) -and -not $daRisolvere.Contains($id)) { [void]$daRisolvere.Add($id) }
    }
}
if ($daRisolvere.Count -gt 0 -and -not $NoIcone) {
    Write-Host ("oggetti-prezzo da risolvere: {0}" -f $daRisolvere.Count)
    foreach ($id in $daRisolvere) {
        $nome = ""
        try {
            $r = Invoke-RestMethod -Uri "https://nether.wowhead.com/tooltip/item/$id" `
                                   -Headers @{ "User-Agent" = $UA } -TimeoutSec 20
            if ($r.name) { $nome = [string]$r.name }
        } catch { }
        $itemNomi[$id] = $nome
        Start-Sleep -Milliseconds 60
    }
}
# Sostituzione: senza nome resta il solo numero, come prima.
for ($i = 0; $i -lt $righe.Count; $i++) {
    if ($righe[$i] -notmatch '\{item:') { continue }
    $righe[$i] = [regex]::Replace($righe[$i], '\{item:(\d+)\}', {
        param($m)
        $n = $itemNomi[$m.Groups[1].Value]
        if ($n) { ($n -replace '\\', '\\\\') -replace '"', '\"' } else { "" }
    })
}
$nuoveIcone = 0
$senzaIcona = 0
$conClasse = 0
$daCercare = 0
if (-not $NoIcone) {
    foreach ($l in $righe) {
        if ($l -match '"spell":(\d+)' -and -not $noti[$matches[1]]) { $daCercare++ }
    }
    if ($daCercare -gt 0) { Write-Host ("icone da cercare su Wowhead: {0}" -f $daCercare) }
}

$fatte = 0
$rimandate = 0
for ($i = 0; $i -lt $righe.Count; $i++) {
    $l = $righe[$i].TrimEnd()
    if ($l -notmatch '"spell":(\d+)') { continue }
    $spell = $matches[1]
    $icona = $noti[$spell]
    # Classe e razza: solo cache, a risolverle e' mount-classes.mjs (§5b).
    $classe = $notiClasse[$spell]
    $razza  = $notiRazza[$spell]
    if (-not $icona -and -not $NoIcone -and $spell -ne "0") {
        if ($MaxIcone -gt 0 -and $fatte -ge $MaxIcone) {
            # ⚠️ Oltre il tetto si SALTA LA RICERCA, non la riga: con un `continue`
            # qui la mount perdeva anche l'icona che gia' si conosceva, e siccome la
            # cache delle icone e' il manifest stesso, il giro dopo se le ritrovava
            # tutte da ricercare. Si scrive quel che si sa e si rimanda il resto.
            $rimandate++
        } else {
            $icona = DatiDiSpell $spell
            $fatte++
            if ($fatte % 25 -eq 0) { Write-Host ("  ...{0}/{1}" -f $fatte, $daCercare) }
            Start-Sleep -Milliseconds 60   # gentile con Wowhead
        }
    }
    if ($classe) { $conClasse++ }
    if ($icona) {
        if (-not $NoIcone) {
            if (ScaricaIcona $icona) {
                if (-not $noti[$spell]) { $nuoveIcone++ }
            } else {
                $icona = $null
            }
        }
    }
    if (-not $icona) { $senzaIcona++ }

    # Classe e razza note si riportano sulla riga nuova: il dump non le sa (emette
    # `class` a null e `race` per niente) e il manifest precedente e' la loro unica
    # cache -- senza questo passaggio ogni sync le butterebbe via e mount-classes.mjs
    # dovrebbe rifare 1527 richieste.
    $coda = ""
    if ($l.EndsWith(",")) { $coda = ","; $l = $l.Substring(0, $l.Length - 1) }
    $l = $l -replace ',"class":(?:null|"[^"]*")', ''
    $l = $l -replace ',"race":(?:null|"[^"]*")', ''
    $agg = ""
    if ($icona) { $agg += ',"icon":"{0}"' -f $icona }
    if ($null -ne $classe) { $agg += ',"class":{0}' -f $(if ($classe) { '"' + $classe + '"' } else { '""' }) }
    if ($null -ne $razza)  { $agg += ',"race":{0}'  -f $(if ($razza)  { '"' + $razza  + '"' } else { '""' }) }
    $righe[$i] = $l.Substring(0, $l.Length - 1) + $agg + "}" + $coda
}

# --- 5. scrivere il manifest ----------------------------------------------------
# I conteggi si RICALCOLANO sulle righe rimaste, non si prendono dal dump: quelli del
# dump contano anche le non piu' ottenibili, e il totale in pagina non tornerebbe.
$presi, $totale = 0, 0
foreach ($l in $righe) {
    if ($l -match '"got":(\d)') { $totale++; if ($matches[1] -eq "1") { $presi++ } }
}
$oggi = Get-Date -Format "yyyy-MM-dd"
$testo = @(
    "{",
    '  "_meta": {',
    ('    "generated": "{0}",' -f $oggi),
    ('    "build": "{0}",' -f $build),
    ('    "collected": {0},' -f $presi),
    ('    "total": {0},' -f $totale),
    ('    "excluded": {0}' -f $tolte.Count),
    "  },",
    ('  "sources": {0},' -f $sorgenti),
    # Nomi degli oggetti usati come prezzo: gia' sostituiti dentro `srcText`, ma
    # tenuti anche qui perche' sono la CACHE -- senza, ogni sync li ricercherebbe.
    ('  "items": {{ {0} }},' -f (($itemNomi.Keys | Sort-Object { [int]$_ } | ForEach-Object {
        '"{0}": "{1}"' -f $_, ((($itemNomi[$_] -replace '\\', '\\') -replace '"', '\"'))
     }) -join ", ")),
    ('  "mounts": {0}' -f ($righe -join "`n")),
    "}"
) -join "`n"

try { $null = $testo | ConvertFrom-Json } catch { Errore "il risultato non e' JSON valido: $_" }

# Guardia generale, complementare a quella sugli spell: il manifest E' la cache delle
# icone (e di classe/razza), quindi un giro non deve MAI perderne in massa. Vale
# qualunque sia la causa, anche una che oggi non sappiamo prevedere -- la si prende
# guardando il risultato invece del sintomo. Sotto la soglia si ferma PRIMA di
# scrivere, cosi' non c'e' niente da ripristinare: senza questo controllo il §5c
# avrebbe poi cancellato dal disco anche i file delle icone rimaste orfane.
$iconeVecchie = 0
if ($vecchio) { $iconeVecchie = @($vecchio.mounts | Where-Object { $_.icon }).Count }
$iconeNuove = ([regex]::Matches($testo, '"icon":"')).Count
if ($iconeVecchie -gt 50 -and $iconeNuove -lt ($iconeVecchie - 10)) {
    Errore "il manifest passerebbe da $iconeVecchie icone a $iconeNuove : non scrivo. Dump sospetto, rifai /reload e rilancia."
}

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
if ($conClasse -gt 0) { Write-Host ("mount con vincolo di classe (dal manifest precedente): {0}" -f $conClasse) }
if ($rimandate -gt 0) {
    Write-Host ("icone rimandate al prossimo giro: {0} (tetto -MaxIcone {1})" -f $rimandate, $MaxIcone) -ForegroundColor Cyan
    Write-Host "  rilancia con -Subito per continuare da dove e' rimasto."
} elseif ($senzaIcona -gt 0) {
    Write-Host ("senza icona: {0} (la card mostra l'iniziale)" -f $senzaIcona) -ForegroundColor Yellow
}

# --- 5ab. i due passi che vogliono Node -----------------------------------------
# ATTENZIONE: su QUESTA postazione Node non c'e', ed e' la norma, non un intoppo. Il
# repo si lavora da due macchine con capacita' disgiunte: qui c'e' WoW (quindi i dump
# e i sync dei dati) e non c'e' Node; sull'altra c'e' Node per il dev server ma non
# c'e' WoW, quindi un sync non potrebbe nemmeno partire.
#
# Senza questa guardia lo script MORIVA qui: `& node` su un comando inesistente alza
# una CommandNotFoundException che, con $ErrorActionPreference = "Stop", porta via
# anche il §6 -- cioe' il manifest restava aggiornato ma non committato, in silenzio.
#
# I due .mjs non hanno bisogno del gioco: leggono solo mounts/manifest.json e il web.
# Quindi il pendente si smaltisce dall'altra postazione, dopo un git pull.
$HaNode = [bool](Get-Command node -ErrorAction SilentlyContinue)

# --- 5b. vincolo di classe ------------------------------------------------------
# Lo risolve scripts/mount-classes.mjs sul manifest appena scritto, e tocca solo le
# mount che il campo `class` non ce l'hanno ancora (le altre sono cache). Tre segnali
# diversi su Wowhead piu' le sedi di classe di Legion: vedi il commento in testa allo
# script. `--rifai` le ricontrolla tutte, ed e' una richiesta per mount.
if (-not $NoIcone -and $HaNode) {
    & node (Join-Path $PSScriptRoot "mount-classes.mjs")
    if ($LASTEXITCODE -ne 0) { Write-Host "  (lo script delle classi ha segnalato un errore: i vincoli restano quelli di prima)" -ForegroundColor Yellow }
}

# --- 5a. immagini del modello ---------------------------------------------------
# Le fa scripts/mount-images.mjs, che legge il manifest appena scritto: render
# ufficiale Blizzard (600x600) con ripiego sulla miniatura di Wowhead, conversione in
# webp e pulizia delle orfane. E' in JS perche' il render arriva in JPEG e serve un
# convertitore: `sharp`, che il repo ha gia'. Il file su disco e' la cache, quindi
# scarica solo le novita' e un'interruzione non fa perdere lavoro.
if (-not $NoIcone -and $HaNode) {
    Write-Host "immagini del modello..."
    & node (Join-Path $PSScriptRoot "mount-images.mjs")
    if ($LASTEXITCODE -ne 0) { Write-Host "  (lo script immagini ha segnalato un errore: le immagini restano quelle di prima)" -ForegroundColor Yellow }
}

# Senza Node si dice COSA resta indietro, non un generico "saltato": quasi sempre e'
# zero (le due cose cambiano solo quando una patch aggiunge cavalcature), e allora la
# trasferta sull'altra macchina non serve affatto.
if (-not $NoIcone -and -not $HaNode) {
    $classeDaFare = 0
    $imgDaFare = 0
    foreach ($l in $righe) {
        if ($l -match '"spell":(\d+)' -and $l -notmatch '"class":') { $classeDaFare++ }
        if ($l -match '"display":(\d+)' -and -not (Test-Path (Join-Path $ImgDir ($matches[1] + ".webp")))) { $imgDaFare++ }
    }
    Write-Host "node non installato qui: vincoli di classe e immagini del modello non toccati." -ForegroundColor Yellow
    if ($classeDaFare -gt 0 -or $imgDaFare -gt 0) {
        Write-Host ("  in sospeso: {0} mount da controllare, {1} immagini da scaricare." -f $classeDaFare, $imgDaFare) -ForegroundColor Yellow
        Write-Host "  dalla postazione col dev server: git pull, poi"
        Write-Host "     node scripts/mount-classes.mjs"
        Write-Host "     node scripts/mount-images.mjs"
    } else {
        Write-Host "  niente in sospeso: nessuna mount nuova da controllare." -ForegroundColor Green
    }
}

# --- 5c. icone rimaste senza padrone ----------------------------------
# Una mount esclusa (o sparita dal diario) lascia il suo file icona nel repo. Si
# cancella solo dopo un giro COMPLETO di icone: con -NoIcone o col tetto -MaxIcone
# ci sono mount che non hanno ancora il campo icon, e il loro file sembrerebbe
# orfano pur non essendolo. Chi condivide l'icona con una mount rimasta si salva da
# se': il confronto e' sui nomi ancora referenziati.
# ATTENZIONE: le icone stanno in public/icons/mount, che appartiene al REPO e non al
# manifest -- quindi con -Manifest puntato altrove (una copia di prova) questa pulizia
# cancellerebbe lo stesso i file veri, confrontandoli con un manifest che non e' il
# loro. E' successo davvero durante un test: 18 icone tolte dal repo. Se il manifest
# non e' quello del repo, la pulizia non ha senso e si salta.
$ManifestRepo = [IO.Path]::GetFullPath((Join-Path $RepoRoot "mounts\manifest.json"))
$suoManifest = ([IO.Path]::GetFullPath($Manifest) -eq $ManifestRepo)
$orfane = 0
if (-not $NoIcone -and $rimandate -eq 0 -and $suoManifest) {
    $usate = @{}
    foreach ($l in $righe) { if ($l -match '"icon":"([^"]+)"') { $usate[$matches[1]] = $true } }
    foreach ($f in Get-ChildItem $IconDir -Filter *.jpg -ErrorAction SilentlyContinue) {
        if (-not $usate[$f.BaseName]) { Remove-Item $f.FullName -Force; $orfane++ }
    }
    if ($orfane -gt 0) { Write-Host ("icone orfane rimosse: {0}" -f $orfane) }
    # Le immagini orfane le toglie mount-images.mjs, che gia' conosce l'elenco dei
    # displayID vivi: qui resterebbe la stessa logica scritta due volte.
}

# --- 6. git ---------------------------------------------------------------------
if ($NoGit) {
    Write-Host "-NoGit: mi fermo qui. Committa a mano quando vuoi."
    exit 0
}

Push-Location $RepoRoot
try {

git add -- "mounts/manifest.json" "public/icons/mount" "public/mounts"
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "niente di nuovo da committare." -ForegroundColor Yellow
    exit 0
}

# Non si committa il lavoro altrui: se ci sono altri file modificati ci si ferma.
$sporchi = @(git status --porcelain | ForEach-Object { $_.Substring(3) } |
             Where-Object { $_ -ne "mounts/manifest.json" -and $_ -notlike "public/icons/mount/*" -and $_ -notlike "public/mounts/*" })
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
# ⚠️ L'esito del push si GUARDA. Prima si stampava «committato e pushato» comunque, quindi
# una rete giu' o un token scaduto passavano inosservati: il commit restava locale, e
# siccome e' il push a far ripartire GitHub Actions, il sito continuava a mostrare i dati
# vecchi con la data «sync» ferma. Il commit e' fatto e resta buono: si dice solo la verita'
# su cosa manca.
git push -q
if ($LASTEXITCODE -ne 0) {
    Write-Host "committato, ma il PUSH E' FALLITO (git ha risposto $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "  il commit e' in locale: rilancia 'git push' quando la rete torna." -ForegroundColor Yellow
    exit 1
}
Write-Host "committato e pushato." -ForegroundColor Green

} finally { Pop-Location }
