#Requires -Version 5.1
# Allinea i personaggi di WoW Forever (_classic_beta_) alle impostazioni di retail:
#   1. CVar: lancia sync-game-settings.ps1 -Gioco _classic_beta_ (stesso preset di retail);
#   2. layout della Modalita' Modifica: assegna il layout per NOME (default 'Stantu') a tutte
#      le spec di ogni PG.
# ATTENZIONE: La CHAT non la tocca, ed e' una scelta misurata (2026-10-15): i colori di Stantu sono
# quelli di fabbrica (uguali su quasi tutti i PG di retail), e il poco che la sua chat ha in
# piu' - canali nelle singole finestre, filtro COMBAT_HONOR_GAIN - Forever lo scarta alla
# prima sessione (visto su Marcio, a cui era stata copiata). Copiarla non lasciava niente.
# Le finestre di chat di ACCOUNT (chat-frontend-cache.txt) sono state copiate una volta.
# Serve a ogni PG nuovo: il client gli crea la cartella al primo login, quindi si logga il
# PG una volta, si chiude il gioco e si lancia questo.
# IMPORTANTE: Forever deve essere CHIUSO (all'uscita riscrive questi file).  -Prova = dice
# cosa cambierebbe senza scrivere.
param([switch]$Prova, [string]$Layout = 'Stantu')
$ErrorActionPreference = 'Stop'

$W = 'C:\Program Files (x86)\World of Warcraft'
function CartellaAccount([string]$gioco) {
  # Cercata, non scritta: il nome e' l'account Battle.net, che non va pubblicato (lo
  # script e' reso per intero sulla pagina Extra).
  $d = Get-ChildItem -LiteralPath "$W\$gioco\WTF\Account" -Directory |
    Where-Object { $_.Name -ne 'SavedVariables' } | Select-Object -First 1
  if (-not $d) { throw "Nessuna cartella account in $gioco" }
  return $d.FullName
}
$F = CartellaAccount '_classic_beta_'

if (-not $Prova) {
  $dir = "$W\_classic_beta_\"
  $aperto = Get-Process -Name 'Wow*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith($dir, [System.StringComparison]::OrdinalIgnoreCase) }
  if ($aperto) { throw "Forever e' aperto: chiudilo, oppure lancia con -Prova." }
}

# Cartelle dei personaggi: <account>\<realm>\<PG>.
$pgDirs = Get-ChildItem -LiteralPath $F -Directory | Where-Object { $_.Name -ne 'SavedVariables' } |
  ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory } | Sort-Object FullName

# -- 1. CVar --------------------------------------------------------------------
Write-Host '== CVar (sync-game-settings.ps1)' -ForegroundColor Cyan
& (Join-Path $PSScriptRoot 'sync-game-settings.ps1') -Gioco '_classic_beta_' -Prova:$Prova

# -- 2. Layout della Modalita' Modifica -----------------------------------------
# Nel file di account i layout stanno in ordine, ognuno preceduto dalla LUNGHEZZA del suo
# nome e seguito da tipo, numero di elementi e dal primo elemento ("0 0 ..."): e' quel
# contorno a distinguere un nome vero da un "8 UIParent" dentro i dati. Nel file per PG
# l'indice conta prima i 2 layout di fabbrica (Modern, Classic), quindi = 2 + posizione.
# ATTENZIONE: Verificato sul formato 5 di Forever: retail scrive il 2, con indici diversi.
Write-Host "`n== Layout '$Layout'" -ForegroundColor Cyan
$acc = [System.IO.File]::ReadAllText("$F\edit-mode-cache-account.txt")
if (-not $acc.StartsWith('5 ')) { throw "edit-mode-cache-account.txt non e' nel formato 5: non tocco niente." }
$nomi = @()
foreach ($m in [regex]::Matches($acc, '(?<=\s)(\d{1,2}) ')) {
  $n = [int]$m.Groups[1].Value
  $ini = $m.Index + $m.Length
  if ($n -lt 1 -or $ini + $n -gt $acc.Length) { continue }
  $nome = $acc.Substring($ini, $n)
  # ATTENZIONE: Il nome deve contenere una lettera: l'intestazione del file e' una fila di 0 e 1
  # ("5 38 0 100 1 0 1 1 ...") dove "1 0" seguito da "1 1 0 0" passa il controllo del
  # contorno. Senza questo filtro uscivano tre layout fantasma ("0", "1", "0") e l'indice
  # di Stantu risultava 7 invece di 4 - preso dalla prova a vuoto, prima di scrivere.
  if ($nome -match '[A-Za-z]' -and $acc.Substring($ini + $n) -match '^ [01] \d+ 0 0 ') { $nomi += $nome }
}
$pos = [array]::IndexOf($nomi, $Layout)
if ($pos -lt 0) { throw "Layout '$Layout' non trovato su Forever (ci sono: $($nomi -join ', ')). Importalo prima in gioco." }
$idx = [string](2 + $pos + 1)
Write-Host ("  layout dell'account: {0} -> '{1}' = indice {2}" -f ($nomi -join ', '), $Layout, $idx)
foreach ($pg in $pgDirs) {
  $p = Join-Path $pg.FullName 'edit-mode-cache-character.txt'
  if (-not (Test-Path -LiteralPath $p)) { Write-Host "  $($pg.Name): nessun file (PG mai entrato in Modalita' Modifica?), saltato"; continue }
  $tok = ([System.IO.File]::ReadAllText($p).TrimEnd([char]0)) -split ' '
  if ($tok[0] -ne '5' -or $tok.Count -ne 11) { Write-Host "  $($pg.Name): formato inatteso ($($tok -join ' ')), saltato"; continue }
  $prima = $tok -join ' '
  for ($i = 1; $i -le 5; $i++) { $tok[$i] = $idx }
  $dopo = $tok -join ' '
  if ($dopo -eq $prima) { Write-Host "  $($pg.Name): gia' a posto"; continue }
  # Fine file = un byte 0, niente a capo: come lo scrive il client.
  if (-not $Prova) { [System.IO.File]::WriteAllBytes($p, [System.Text.Encoding]::ASCII.GetBytes($dopo) + [byte]0) }
  Write-Host "  $($pg.Name): [$prima] -> [$dopo]"
}

if ($Prova) { Write-Host "`nPROVA: nessun file scritto." -ForegroundColor Yellow }
