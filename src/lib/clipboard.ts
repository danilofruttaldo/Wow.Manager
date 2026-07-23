// Copia testo negli appunti, best-effort e con fallback. Condivisa da /macros e /extra
// (prima duplicavano lo stesso `navigator.clipboard.writeText` con `catch` SILENZIOSO:
// su http non-sicuro o browser senza Clipboard API il tasto non faceva nulla e non
// avvisava). Prova la Clipboard API in contesto sicuro, poi ripiega su un <textarea>
// temporaneo + execCommand('copy'). Ritorna true se una delle due ha funzionato, cosi'
// il chiamante puo' mostrare "Copiato" oppure uno stato d'errore.
export async function copyText(text: string): Promise<boolean> {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    /* Clipboard API rifiutata (permessi/contesto): si prova il metodo legacy sotto. */
  }
  try {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.position = 'fixed';
    ta.style.top = '-1000px';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand('copy');
    document.body.removeChild(ta);
    return ok;
  } catch {
    return false;
  }
}
