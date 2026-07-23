# A che punto sono, su un raid, su TUTTE le classi.
#
#   .\scripts\transmog-raid.ps1 t20         # per chiave tier
#   .\scripts\transmog-raid.ps1 sargeras    # per pezzo di nome del raid
#   .\scripts\transmog-raid.ps1             # elenca i raid disponibili
#
# La metrica principale e' il set MYTHIC: completarlo sblocca da solo anche
# LFR/Normal/Heroic dello stesso tier (verificato sul dump, 30/30). Quindi il
# bersaglio vero di un raid e' il Mythic; le inferiori seguono e sono solo dettaglio.
# Sui tier vecchi senza Mythic la metrica ripiega sul totale di tutte le versioni.
#
# Sola lettura: non tocca il manifest.

param(
    [Parameter(Position = 0)]
    [string]$Raid,
    [string]$Manifest = (Join-Path (Split-Path $PSScriptRoot -Parent) "transmog\manifest.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Manifest)) { Write-Host "manifest non trovato: $Manifest" -ForegroundColor Red; exit 1 }
$m = Get-Content -Raw -Encoding UTF8 $Manifest | ConvertFrom-Json

function ElencaRaid {
    Write-Host ""
    Write-Host "Raid disponibili (chiave -> nome):" -ForegroundColor Cyan
    $m.tiers |
        Select-Object @{n='Chiave';e={$_.key}}, @{n='Tier';e={$_.tier}}, @{n='Nome';e={$_.name}}, @{n='Exp';e={$_.exp}} |
        Format-Table -AutoSize | Out-String -Width 200 | Write-Host
}

if (-not $Raid) { ElencaRaid; exit 0 }

# --- risolvi il tier: per chiave, per sigla Txx, o per pezzo di nome ------------
$q = $Raid.Trim()
# La chiave e' unica: se combacia esatta vince, cosi' 't6' non e' ambiguo con 't6-swp'.
$hit = @($m.tiers | Where-Object { $_.key -ieq $q })
if ($hit.Count -eq 0) {
    $hit = @($m.tiers | Where-Object { $_.tier -ieq $q -or $_.name -imatch [regex]::Escape($q) })
}
if ($hit.Count -eq 0) {
    Write-Host "nessun raid corrisponde a '$q'." -ForegroundColor Yellow; ElencaRaid; exit 1
}
if ($hit.Count -gt 1) {
    Write-Host "'$q' e' ambiguo, corrisponde a piu' raid:" -ForegroundColor Yellow
    $hit | ForEach-Object { Write-Host ("   {0}  {1}" -f $_.key, $_.name) }
    Write-Host "usa la chiave esatta."; exit 1
}
$tier = $hit[0]
$key  = $tier.key

# --- versioni e ordine di difficolta' ------------------------------------------
$rank = @{ lfr = 1; normal = 2; heroic = 3; mythic = 4 }
$hasMythic = [bool]($tier.versions.PSObject.Properties.Name -contains "mythic")

function OrdinaVersioni($props) {
    $props | Sort-Object @{ Expression = { if ($rank.ContainsKey($_.Name)) { $rank[$_.Name] } else { 99 } } }, Name
}

# --- raccogli per classe -------------------------------------------------------
$rows = @()
$fatti = 0; $nClass = 0
$mHave = 0; $mTot = 0     # totale sulla metrica principale
foreach ($cls in $m.collected.PSObject.Properties) {
    $t = $cls.Value.PSObject.Properties[$key]
    if (-not $t) { continue }     # classe che non esisteva a questo raid
    $nClass++

    $det = @()
    $ovH = 0; $ovT = 0
    foreach ($v in (OrdinaVersioni $t.Value.PSObject.Properties)) {
        $ovH += $v.Value[0]; $ovT += $v.Value[1]
        $det += ("{0} {1}/{2}" -f $v.Name, $v.Value[0], $v.Value[1])
    }

    if ($hasMythic -and $t.Value.PSObject.Properties["mythic"]) {
        $pH = $t.Value.mythic[0]; $pT = $t.Value.mythic[1]
    } else {
        $pH = $ovH; $pT = $ovT
    }
    $mHave += $pH; $mTot += $pT
    $done = ($pT -gt 0 -and $pH -eq $pT)
    if ($done) { $fatti++ }

    $rows += [pscustomobject]@{
        Classe    = $cls.Name
        _done     = [int]$done
        _ratio    = $(if ($pT -gt 0) { $pH / $pT } else { 1 })
        Target    = ("{0}/{1}" -f $pH, $pT)
        Fatto     = $(if ($done) { "OK" } else { "" })
        Dettaglio = ($det -join "  ")
    }
}

# --- stampa --------------------------------------------------------------------
$etichetta = $(if ($hasMythic) { "Mythic" } else { "Totale" })
Write-Host ""
Write-Host ("{0}  [{1}]  ({2})" -f $tier.name, $key, $tier.exp) -ForegroundColor Cyan
Write-Host ("Metrica principale: {0}    (le difficolta' inferiori seguono il Mythic)" -f $etichetta) -ForegroundColor DarkGray

$rows |
    Sort-Object @{ Expression = '_done'; Descending = $true }, @{ Expression = '_ratio'; Descending = $true } |
    Select-Object Classe, @{ n = $etichetta; e = { $_.Target } }, Fatto, Dettaglio |
    Format-Table -AutoSize | Out-String -Width 200 | Write-Host

Write-Host ("--- {0}: {1}/{2} classi col {3} completo; pezzi {3} {4}/{5} ---" -f `
    $tier.name, $fatti, $nClass, $etichetta, $mHave, $mTot) -ForegroundColor Cyan
Write-Host "(numeri account-wide / Warband)" -ForegroundColor DarkGray
