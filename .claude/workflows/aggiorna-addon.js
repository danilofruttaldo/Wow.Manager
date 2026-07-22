export const meta = {
  name: 'aggiorna-addon',
  description: 'Audit CurseForge/GitHub di tutti gli addon WoW (versioni lette dal manifest) e installa gli aggiornamenti stabili',
  phases: [
    { title: 'Bootstrap', detail: 'legge addons/manifest.json: lista addon, versioni correnti, build' },
    { title: 'Audit', detail: 'latest vs current per ogni addon (cfwidget + GitHub fallback)' },
    { title: 'Update', detail: 'scarica/estrai/backup/installa gli out-of-date' },
  ],
}

const REPO = "c:/src/Wow.Manager"
const MANIFEST = `${REPO}/addons/manifest.json`
const ADDONS_PATH = "/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns"

// ---- Bootstrap: leggi il manifest (la fonte di verita') ----
phase('Bootstrap')
const BOOT_SCHEMA = {
  type: 'object',
  required: ['build', 'addons'],
  properties: {
    build: { type: 'string' }, // es "12.0.7.68235"
    addons: {
      type: 'array',
      items: {
        type: 'object',
        required: ['name', 'slug', 'current', 'source'],
        properties: {
          name: { type: 'string' },     // chiave nel manifest (es "BigWigs", "Leatrix_Plus")
          slug: { type: 'string' },      // ultimo segmento dell'url curseforge (es "big-wigs")
          current: { type: 'string' },   // campo version
          source: { type: 'string' },    // "cfwidget" oppure "github"
          repo: { type: 'string' },      // se github: owner/repo
        },
        additionalProperties: true,
      },
    },
  },
  additionalProperties: true,
}
const boot = await agent(
`Leggi il file JSON ${MANIFEST}. Restituisci dati strutturati:
- build = il valore _meta.wow_build (stringa intera, es "12.0.7.68235").
- addons = un elemento per ogni chiave dentro "addons". Per ciascuno:
  - name = la CHIAVE dell'oggetto nel manifest (es "BigWigs", "Leatrix_Plus", "MythicDungeonTools").
  - slug = l'ULTIMO segmento del path del campo "url" (es url ".../addons/big-wigs" -> "big-wigs"; ".../teleport-me-nu" -> "teleport-me-nu").
  - current = il campo "version".
  - source/repo: DEFAULT source="cfwidget". ECCEZIONI (cfwidget rotto, usa GitHub releases): se name=="BigWigs" -> source="github", repo="BigWigsMods/BigWigs"; se name=="MythicDungeonTools" -> source="github", repo="Nnoggie/MythicDungeonTools".
Non inventare addon: includi esattamente quelli presenti nel manifest.`,
  { label: 'bootstrap:manifest', phase: 'Bootstrap', schema: BOOT_SCHEMA }
)
if (!boot || !boot.addons || !boot.addons.length) {
  log('Bootstrap fallito: impossibile leggere il manifest. Stop.')
  return { error: 'bootstrap_failed' }
}
const ADDONS = boot.addons
// flavor token retail, es "12.0.7.68235" -> BUILD "12.0.7" e token "120007"
const p = boot.build.split('.')
const BUILD = `${p[0]}.${p[1]}.${p[2]}`
const TOKEN = `${p[0]}${String(p[1]).padStart(2, '0')}${String(p[2]).padStart(2, '0')}`
log(`Manifest: ${ADDONS.length} addon, build ${boot.build} (flavor ${TOKEN}).`)

// ---- Audit ----
const AUDIT_SCHEMA = {
  type: 'object',
  required: ['name', 'current', 'latest', 'needsUpdate', 'source'],
  properties: {
    name: { type: 'string' }, current: { type: 'string' }, latest: { type: 'string' },
    needsUpdate: { type: 'boolean' }, source: { type: 'string' },
    downloadUrl: { type: 'string' }, fileName: { type: 'string' }, notes: { type: 'string' },
  },
  additionalProperties: true,
}

phase('Audit')
const audits = await parallel(ADDONS.map(a => () => {
  const common = `Sei un auditor di versioni addon WoW. Build retail corrente: ${BUILD} (flavor token ${TOKEN}). Considera SOLO release stabili (NO alpha/beta). Addon: ${a.name}, versione installata: "${a.current}". Restituisci dati strutturati, niente prosa.`
  let prompt
  if (a.source === 'github') {
    prompt = `${common}
Esegui: curl -s --max-time 30 "https://api.github.com/repos/${a.repo}/releases/latest"
tag_name = versione latest. Tra gli assets prendi l'asset .zip (NON release.json): usa il suo browser_download_url come downloadUrl e il suo name come fileName.
needsUpdate = true se tag_name diverso da "${a.current}". source="github".`
  } else {
    prompt = `${common}
Esegui: curl -s --max-time 30 "https://api.cfwidget.com/wow/addons/${a.slug}"
Nel JSON "files" e' ordinato dal piu recente. Trova il PRIMO file con type=="release" il cui array "versions" contiene "${BUILD}".
ATTENZIONE multi-flavor (es. Leatrix_Plus): scarta filename con -classic/-bcc/-wrath/-cata/-mists/-titan e file le cui versions NON includono ${BUILD}. Prendi solo il release retail.
latest = numero versione ricavato dal filename (es "Baganator-807.zip"->"807", "CursorRing-v1.5.3.zip"->"v1.5.3", "TomTom-v4.3.5-release.zip"->"v4.3.5-release"); mantieni prefisso 'v' se presente nel filename. fileName = nome esatto del file.
Costruisci downloadUrl forgecdn da file id: https://mediafilez.forgecdn.net/files/AAAA/BBB/<fileName> dove AAAA = prime 4 cifre del file id, BBB = cifre rimanenti SENZA zero iniziale (es 8261983 -> 8261/983 ; 8262012 -> 8262/12 ; 8231037 -> 8231/37).
VERIFICA: curl -sI --max-time 30 "<downloadUrl>" deve dare HTTP 200 e content-type zip/octet-stream. Se ricevi text/html o xml, il subbucket e' sbagliato: ricontrolla AAAA/BBB.
needsUpdate = true se latest diverso da "${a.current}". source="cfwidget".
Se cfwidget e' vuoto/errore: needsUpdate=false, latest="?", notes con l'errore.`
  }
  return agent(prompt, { label: `audit:${a.name}`, phase: 'Audit', schema: AUDIT_SCHEMA })
}))

const valid = audits.filter(Boolean)
const updates = valid.filter(x => x.needsUpdate && x.downloadUrl)
log(`Audit: ${valid.length}/${ADDONS.length} ok. Update: ${updates.length ? updates.map(u => u.name + ' ' + u.current + '->' + u.latest).join(', ') : 'NESSUNO'}`)

// ---- Update ----
const INSTALL_SCHEMA = {
  type: 'object', required: ['name', 'ok'],
  properties: {
    name: { type: 'string' }, newVer: { type: 'string' }, folders: { type: 'array', items: { type: 'string' } },
    ok: { type: 'boolean' }, tocInterface: { type: 'string' }, notes: { type: 'string' },
  },
  additionalProperties: true,
}

phase('Update')
const installed = await parallel(updates.map(u => () => agent(
`Installa l'update dell'addon WoW ${u.name} (${u.current} -> ${u.latest}). Sovrascrivi i file: le modifiche vengono lette al prossimo /reload o riavvio, non serve che WoW sia chiuso.
Passi (bash):
1. mkdir -p /tmp/wow-upd/wf/bak && cd /tmp/wow-upd/wf
2. curl -sL --max-time 180 -o "${u.fileName}" "${u.downloadUrl}"
3. file "${u.fileName}"  -> DEVE contenere "Zip archive". Se e' HTML/XML/ASCII, ferma e restituisci ok=false con notes.
4. rm -rf "ext_${u.name}" && mkdir "ext_${u.name}" && unzip -q "${u.fileName}" -d "ext_${u.name}"
5. ls -1 "ext_${u.name}"  -> sono le cartelle addon top-level da installare.
6. Per OGNI cartella X estratta: cp -r "${ADDONS_PATH}/X" "/tmp/wow-upd/wf/bak/X" 2>/dev/null ; rm -rf "${ADDONS_PATH}/X" ; cp -r "ext_${u.name}/X" "${ADDONS_PATH}/X"
7. Leggi la riga '## Version' e '## Interface' del .toc principale installato (quello che matcha il nome cartella primaria) per confermare.
Restituisci: name, newVer (dal toc), folders (array cartelle installate), tocInterface (riga ## Interface), ok=true se versione installata == "${u.latest}", notes.`,
  { label: `install:${u.name}`, phase: 'Update', schema: INSTALL_SCHEMA }
)))

return {
  build: boot.build,
  flavor: TOKEN,
  auditedCount: valid.length,
  failedAudit: ADDONS.filter(a => !valid.find(v => v.name === a.name)).map(a => a.name),
  upToDate: valid.filter(v => !v.needsUpdate).map(v => `${v.name} ${v.current}`),
  updates: updates.map(u => ({ name: u.name, from: u.current, to: u.latest, downloadUrl: u.downloadUrl, fileName: u.fileName })),
  installed: installed.filter(Boolean),
  // PROMEMORIA post-run (manuale): aggiornare addons/manifest.json + installs.log con le versioni nuove;
  // ri-applicare le PATCH LOCALI se aggiornati: BigWigs (translation nag itIT off in Loader.lua),
  // TeleportMenu (Lightveil Recall Beacon 276371 spostato in Data/Items.lua ItemTeleports).
}
