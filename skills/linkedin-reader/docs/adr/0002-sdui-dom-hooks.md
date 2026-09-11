# 0002 - Estrazione dal DOM server-driven, non da un payload JSON

Data: 2026-09-11
Stato: accettata

## Contesto

LinkedIn ha sostituito il client web Ember con un renderer server-driven UI
(`data-component-type="LazyColumn"`, vocabolario Jetpack Compose: sul web viene
reso l'albero SDUI del mobile). Misurato sulla sessione autenticata, tutti gli
appigli su cui la skill si reggeva restituiscono 0 nello stesso momento:
`article.comments-comment-entity`, `.update-components-update-v2__commentary`,
`.update-components-text`, `.social-details-social-counts__comments`, `[data-id]`,
e `article` in qualunque forma. Le classi superstiti sono hashate (`_4a74b613`).

Non è una deriva di selettori da rattoppare: è un client diverso.

## Alternativa considerata: leggere il payload JSON

Sarebbe stata la scelta migliore - ogni campo dalla sua chiave, nessuna lettura
posizionale. Verificata e scartata perché il payload non è raggiungibile:

- nessun `<script>` della pagina contiene il testo del post o dei commenti;
- nessun tag `<code>` con modelli incorporati, come faceva la vecchia pagina Ember;
- iniettando un intercettore su `fetch` prima del caricamento e scorrendo fino in
  fondo, nessuna delle risposte catturate porta commenti: l'albero SDUI arriva già
  renderizzato in HTML.

## Decisione

Estrazione dal DOM, su due soli tipi di appiglio:

1. `data-testid` - `expandable-text-box` per il corpo del post e di ogni commento,
   `expandable-text-button` per i toggle di troncamento;
2. la forma dei blocchi - il blocco di un commento è il primo antenato del corpo
   che porta un link identità (`/in/`, `/company/`, `/school/`, `/showcase/`)
   **fuori** dal corpo, e ha esattamente 3 figli (header, corpo, barra social).
   Il post è il riquadro di testo che non è un commento.

Mai le classi, mai il testo dell'interfaccia: entrambi renderebbero la skill
dipendente dalla lingua o dal prossimo deploy.

## Conseguenze

- Autore, data e reazioni non hanno più un appiglio proprio e si leggono per
  posizione **dentro il loro blocco**. È una rinuncia rispetto a prima, quando
  ogni campo aveva il suo selettore; resta però una posizione dentro un blocco di
  tre figli, non la riga n-esima dell'`innerText` di tutta la pagina.
- Le risposte non sono più annidate nel DOM: si distinguono per rientro
  orizzontale. Marcatore geometrico, indipendente dalla lingua, ma che un cambio
  di layout farebbe decadere in silenzio - si perde il `(reply)`, non il commento.
- `hooks` nel JSON di uscita riporta `textBoxes`, `commentBlocks`, `commentary` e
  `lazyColumn`: se tornano tutti a 0, la pagina è cambiata di nuovo e si riparte
  da qui.
