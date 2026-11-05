# fonts/

Override del font dell'interfaccia base di WoW. Fonte di verità: [manifest.json](manifest.json).

WoW, se trova dei `.ttf` con nomi precisi in `Fonts/` (di `_retail_` e di `_forever_`), li usa al posto dei font di default per tutta la UI Blizzard. Mettendo **lo stesso .ttf sotto tutti i nomi-override** si ottiene un font unico ovunque.

## Nomi-override

| File | Usato per |
|---|---|
| `FRIZQT__.TTF` | font principale (action bar, tooltip, unit frame, menu) |
| `ARIALN.TTF` | chat e numeri |
| `MORPHEUS.TTF` | titoli quest, posta |
| `skurri.TTF` | combat text |
| `2002.TTF` / `2002B.TTF` | numeri secondari |

## Ricostruire

Dalla cartella del repo: `.\scripts\apply-fonts.ps1` (`-Revert` per toglierli). Copia `source_file` sotto ognuno dei `files` in ogni cartella di `wow_fonts_dirs`.

> Font scelto: **Avant Garde** (`Avant Garde Naowh.ttf`, incluso in EllesmereUI), lo stesso che EllesmereUI applica al testo di gioco: con l'override vale anche dove l'addon non arriva (login, schermata personaggi, combat text, fumetti). Fino al 2026-11-05 era Segoe UI Semibold.

Il binario `.ttf` **non è versionato** (sta dentro l'addon). I `.slug` interni Blizzard non si toccano.

## Note

- Si carica all'**avvio** del client (non basta `/reload`).
- **Revert:** `apply-fonts.ps1 -Revert`, oppure cancellare i 6 `.TTF` da `Fonts/`.
- Gli addon con font proprio (Details, BigWigs, MRT) hanno il loro selettore interno: non seguono questo override.
