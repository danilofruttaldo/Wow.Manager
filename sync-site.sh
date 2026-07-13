#!/usr/bin/env bash
# Rigenera i dati del sito GitHub Pages (docs/) dalle fonti di verità del repo
# + copia gli screenshot dal client WoW. I file in docs/data/ sono GENERATI:
# non editarli a mano, si rifanno da qui.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DOCS="$ROOT/docs"
WOW_SHOTS="/c/Program Files (x86)/World of Warcraft/_retail_/Screenshots"

mkdir -p "$DOCS/data" "$DOCS/screenshots"

# --- manifest (fonte di verità) -> docs/data (copie servite da Pages) ---
cp "$ROOT/macros/manifest.json"  "$DOCS/data/macros.json"
cp "$ROOT/addons/manifest.json"  "$DOCS/data/addons.json"
echo "  data/macros.json  <- macros/manifest.json"
echo "  data/addons.json  <- addons/manifest.json"

# --- screenshot dal client (nomi: classe-spec-personaggio.jpg) ---
if [ -d "$WOW_SHOTS" ]; then
  cp "$WOW_SHOTS"/*.jpg "$DOCS/screenshots/" 2>/dev/null || true
  echo "  screenshots/      <- $WOW_SHOTS"
else
  echo "  (cartella screenshot WoW non trovata: $WOW_SHOTS — salto)"
fi

# --- elenco screenshot presenti -> docs/data/screenshots.json ---
{
  printf '['
  first=1
  for f in "$DOCS"/screenshots/*.jpg; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    if [ "$first" -eq 1 ]; then first=0; else printf ','; fi
    printf '"%s"' "$b"
  done
  printf ']\n'
} > "$DOCS/data/screenshots.json"
echo "  data/screenshots.json (elenco file)"

echo "Sito aggiornato."
