# e-invoicing-for-WHMCS
e-invoicing for WHMCS (work in progress)

**Struttura MySQL**
Tabella	Funzione
mod_einvoice_sequences	Numerazione autonoma delle fatture fiscali
mod_einvoice_invoices	Testata, dati fiscali e importi
mod_einvoice_sources	Associazione con le proforma WHMCS
mod_einvoice_lines	Righe delle fatture
mod_einvoice_tax_subtotals	Riepiloghi IVA
mod_einvoice_documents	XML nel database, riferimenti PDF
mod_einvoice_deliveries	Invii email e futuri invii Peppol
mod_einvoice_events	Registro delle operazioni
mod_einvoice_runs	Esecuzioni cron e fatturazione mensile

Scelte implementate
- XML UBL 2.1: conservato in un campo MEDIUMBLOB, preservando esattamente i byte del documento.
- PDF: conservato su filesystem privato, con percorso e hash SHA-256 nel database.
- Numerazione fiscale: separata da WHMCS, con serie e anno fiscale.
- Fatturazione riepilogativa: supporto all'associazione di più proforma a un'unica fattura.
- Custom field: Monthly Consolidated Invoicing rimane in WHMCS e verrà letto direttamente dal modulo.
- Note di credito: già previste nella struttura.
- Audit: registrazione degli eventi e dei tentativi di invio.
- Integrità: foreign key tra le tabelle del modulo e vincoli per prevenire associazioni duplicate delle proforma.
