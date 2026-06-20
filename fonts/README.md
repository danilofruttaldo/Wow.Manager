# fonts/

Override del font dell'interfaccia base di WoW. Fonte di verità: [manifest.json](manifest.json).

WoW, se trova dei `.ttf` con nomi precisi in `_retail_/Fonts/`, li usa al posto dei font di default per tutta la UI Blizzard. Mettendo **lo stesso .ttf sotto tutti i nomi-override** si ottiene un font unico ovunque.

## Nomi-override

| File | Usato per |
|---|---|
| `FRIZQT__.TTF` | font principale (action bar, tooltip, unit frame, menu) |
| `ARIALN.TTF` | chat e numeri |
| `MORPHEUS.TTF` | titoli quest, posta |
| `skurri.TTF` | combat text |
| `2002.TTF` / `2002B.TTF` | numeri secondari |

## Ricostruire

Copiare `source_file` (dal manifest) sotto ognuno dei `files` nella cartella `wow_fonts_dir`. Esempio:

```bash
for n in FRIZQT__.TTF ARIALN.TTF MORPHEUS.TTF skurri.TTF 2002.TTF 2002B.TTF; do
  cp -f "C:/Windows/Fonts/seguisb.ttf" "C:/Program Files (x86)/World of Warcraft/_retail_/Fonts/$n"
done
```

> Font scelto: **Segoe UI Semibold** (`seguisb.ttf`) — peso più marcato di Regular per leggibilità su numeri/combat/nameplate.

Il binario `.ttf` **non è versionato** (font di sistema, ricostruibile). I `.slug` interni Blizzard non si toccano.

## Note

- Si carica all'**avvio** del client (non basta `/reload`).
- **Revert:** cancellare i 6 `.TTF` da `Fonts/`.
- Gli addon con font proprio (Details, BigWigs, MRT) hanno il loro selettore interno: non seguono questo override.
