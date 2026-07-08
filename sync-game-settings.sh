#!/usr/bin/env bash
# Allinea le "impostazioni di gioco" di tutti i personaggi a quelle di Stantu.
# Copia SOLO le chiavi nell'allowlist; lo stato per-personaggio resta intatto.
# IMPORTANTE: eseguire con WoW COMPLETAMENTE CHIUSO.
set -euo pipefail

ACC="c:/Program Files (x86)/World of Warcraft/_retail_/WTF/Account/STANTUFFO"
SRC="$ACC/Pozzo dell'Eternità/Stantu/config-cache.wtf"

# Chiavi = vere opzioni di gioco da sincronizzare
KEYS=(
  enableMouseoverCast autoLootDefault AutoPushSpellToActionBar enableMultiActionBars SoftTargetEnemy
  assistedCombatHighlight cooldownViewerEnabled damageMeterEnabled damageMeterResetOnNewInstance
  raidFramesDisplayClassColor raidFramesDisplayPowerBars
  nameplateSelectedScale nameplateSelectedAlpha nameplateMaxDistance
  nameplateMinScale nameplateMaxScale nameplateMinScaleDistance nameplateMaxScaleDistance
  nameplateMinAlpha nameplateMaxAlpha nameplateMinAlphaDistance
  nameplateTargetBehindMaxDistance nameplateShowDebuffsOnFriendly
  cameraSavedDistance cameraSavedPitch cameraSavedVehicleDistance cameraSavedPetBattleDistance
  calendarShowBattlegrounds characterNeedsTurnStrafeDialog
  miniDressUpFrame showTokenFrame showTamers dragonRidingRacesFilter
)

# Estrai i valori di Stantu in un array associativo
declare -A VAL
for k in "${KEYS[@]}"; do
  line=$(grep -P "^SET ${k} " "$SRC" || true)
  if [[ -n "$line" ]]; then
    VAL[$k]=$(sed -E "s/^SET ${k} \"(.*)\"\r?$/\1/" <<<"$line")
  fi
done

echo "Valori sorgente (Stantu):"
for k in "${KEYS[@]}"; do [[ -v VAL[$k] ]] && printf '  %-32s = %s\n' "$k" "${VAL[$k]}"; done
echo

# Applica a ogni config-cache.wtf tranne Stantu e backup
find "$ACC" -path '*/_backup-*' -prune -o -name config-cache.wtf -print | while read -r f; do
  [[ "$f" == "$SRC" ]] && continue
  for k in "${KEYS[@]}"; do
    [[ -v VAL[$k] ]] || continue
    v="${VAL[$k]}"
    if grep -qP "^SET ${k} " "$f"; then
      # Sostituisci la riga esistente (escape & e / per sed)
      esc=$(sed -e 's/[&/\]/\\&/g' <<<"$v")
      sed -i -E "s/^SET ${k} \".*\"\r?\$/SET ${k} \"${esc}\"/" "$f"
    else
      # Aggiungi in coda (mantieni CRLF coerente col file)
      printf 'SET %s "%s"\r\n' "$k" "$v" >> "$f"
    fi
  done
  echo "Aggiornato: ${f#$ACC/}"
done
echo
echo "Fatto."
