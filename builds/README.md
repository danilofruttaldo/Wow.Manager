# builds/

Talent/gear/stat build per classe/spec/contenuto. Un file `.md` per build.

## Struttura

```
builds/
  <class>/<spec>/<contenuto>.md      ← es. warrior/fury/stantu-mplus.md
```

Classi scaffoldate: death-knight, demon-hunter, druid, evoker, hunter, mage, monk, paladin, priest, rogue, shaman, warlock, warrior.

## Naming file

`<char>-<contenuto>.md` dentro la cartella spec.

- `warrior/fury/stantu-mplus.md`
- `warrior/fury/stantu-raid.md`
- `warrior/arms/stantu-pvp.md`

Se la build è generica (non char-specific), omettere il prefisso char: `mplus.md`, `raid.md`.

## Template build

```markdown
# Stantu — Warrior Fury — M+

- **Patch:** 12.0.5
- **Source:** Icy Veins / Wowhead / Method (link)
- **Updated:** YYYY-MM-DD
- **Hero talent:** Slayer | Mountain Thane

## Talent import string

\`\`\`
<copia/incolla dalla schermata talent>
\`\`\`

## Stat priority

1. Mastery
2. Haste
3. ...

## Trinket / tier set notes

- ...

## Rotation notes

- ...
```
