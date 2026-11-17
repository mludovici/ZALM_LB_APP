# Aufgaben — TechLibrary & Media Hub (`ZALM_LB_APP`)

> **Auftraggeber:** Interne Wissens- & Fachmedienverwaltung der ZALM Consulting GmbH
> **System:** S4P Mandant 300 · Paket `ZALM_LB_APP` · OData V4 · `managed; strict ( 2 ); with draft;`
> **Architektur & Datenmodell:** siehe [README.md](README.md)

Die Aufgaben sind bewusst wie echte Anforderungen geschnitten: Fachlicher Wunsch zuerst, dann die konkreten **Akzeptanzkriterien** und die benötigten **RAP-/CDS-Bausteine inkl. Stolpersteinen** – ohne dir den Code vorzukauen.

Aktuell sind **Stufe A (Fundament)**, **Stufe B (Determinations, Validations & Side Effects)**, **Stufe C (Actions, Parameter, Defaulting & Feature Control)** und **Stufe D (OpenLibrary HTTP-Integration per Custom Entity)** abgeschlossen. Jetzt folgt **Stufe E (Fiori Elements V4 Showcase & lokale App)**.

---

## Stufe A — Fundament (From Scratch bis zur lauffähigen Draft-App)

### LB-01 · Paket & CDS Simple Types (`DRTY`) statt Datenelementen

> „Bevor wir die erste Tabelle anlegen: Wir wollen im neuen Projekt keine klassischen SE11-Domänen und Datenelemente mehr pflegen. Unsere fachlichen Grundtypen wie Mediennummer, ISBN, Kategorie oder Sterne-Bewertung sollen einheitliche deutsche Beschriftungen und Tooltips direkt in CDS mitbringen."

**Anforderungen**

1. Lege in ADT das Paket `ZALM_LB_APP` an (Softwarekomponente `HOME`, Transportschicht `ZS4P`, Mastersprache Deutsch) sowie einen Transportauftrag.
2. Erstelle unter *Core Data Services → Types* mindestens **sechs CDS Simple Types** (`define type`):
   - `ZALM_LB_T_BookId` (`abap.char(10)`) — nur Großbuchstaben (`MED-0001`)
   - `ZALM_LB_T_LoanNo` (`abap.char(10)`) — nur Großbuchstaben (`LN-00001`)
   - `ZALM_LB_T_Isbn` (`abap.char(17)`) — nur Großbuchstaben
   - `ZALM_LB_T_Category` (`abap.char(15)`) — nur Großbuchstaben (`ABAP`, `FIORI`, …)
   - `ZALM_LB_T_Rating` (`abap.dec(3,2)`) — Bewertung von `0.00` bis `5.00`
   - `ZALM_LB_T_Title` (`abap.char(120)`) — Groß- **und** Kleinschreibung erlaubt!
   - `ZALM_LB_T_Url` (`abap.char(255)`) — Groß- und Kleinschreibung erlaubt (für Buchcover & Avatare)
3. Probiere zusätzlich bei mindestens einem Typ die **Typ-Vererbung (Type Stacking)** aus – z. B. einen Basis-Typ `ZALM_LB_T_Code10 : abap.char(10)` mit `@ObjectModel.upperCase: true`, von dem `ZALM_LB_T_BookId` und `ZALM_LB_T_LoanNo` erben und jeweils nur ihre eigenen `@EndUserText.*`-Texte überschreiben.

**Akzeptanzkriterien**

- Alle Simple Types lassen sich fehlerfrei aktivieren.
- Jeder Simple Type besitzt `@EndUserText.label`, `@EndUserText.heading` und `@EndUserText.quickInfo`.
- Code-Typen erzwingen Großbuchstaben; `ZALM_LB_T_Title` und `ZALM_LB_T_Url` lassen gemischte Schreibweise zu.

**CDS-Baustein & Stolpersteine**

- ADT: *New → Other ABAP Repository Object → Core Data Services → Type* (`DRTY`).
- Annotation für Großschreibung: `@ObjectModel.upperCase: true` (Default bei Nichtangabe ist `false` – das löst das klassische `CHAR`-Großbuchstaben-Problem aus dem DDIC!).
- Metadata Extensions (`DDLX`) sind auf Simple Types nicht erlaubt; `@EndUserText.*` gehört direkt vor `define type`.

---

### LB-02 · Die 5 Datenbanktabellen & wiederholbare Demodaten per `F9`

> „Bisher führen wir unsere Fachbücher und Ausleihen in einer geteilten Excel-Liste. Wir brauchen jetzt saubere Tabellen für Bücher, Ausleihen, Rezensionen, Mitglieder und die Ausleihstatus – plus einen Knopfdruck, der uns jederzeit realistische Testdaten zum Ausprobieren einspielt."

**Anforderungen**

1. Lege die **fünf transparenten Tabellen** gemäß ER-Diagramm in [README.md](README.md#2-das-datenmodell-5-tabellen) an:
   - `ZALM_LB_BOOK` (Root: inkl. `sample_pdf : abap.rawstring(0)` für späteren Dateiupload + alle 5 RAP-Adminfelder!)
   - `ZALM_LB_LOAN` (Kind 1: inkl. `local_last_changed_at : abp_locinst_lastchange_tstmpl`)
   - `ZALM_LB_REVIEW` (Kind 2: inkl. `comment_text : abap.sstring(500)` + `local_last_changed_at`)
   - `ZALM_LB_MEMBER` (Stammdaten der Mitarbeiter/Entleiher)
   - `ZALM_LB_LSTATUS` (Lookup für Status + `criticality`)
2. Verwende für fachliche Spalten **keine eigenen Datenelemente**, sondern Built-in-Typen (`abap.char(...)`, `abap.int2`, `abap.curr(15,2)`, `abap.cuky`, `abap.dats`, `abap.sstring(500)`, `abap.rawstring(0)`). Für UUIDs, Booleans und RAP-Zeitstempel nutzt du die Standardtypen `sysuuid_x16`, `abp_boolean`, `abp_creation_user`, `abp_creation_tstmpl`, `abp_locinst_lastchange_user`, `abp_locinst_lastchange_tstmpl`, `abp_lastchange_tstmpl`.
3. Vergiss auf `ZALM_LB_BOOK` die Währungsreferenz-Annotation `@Semantics.amount.currencyCode : 'zalm_lb_book.currency_code'` am Feld `price` nicht (DDL-Tabelleneditor verlangt sie bei `abap.curr`).
4. Erstelle eine Klasse `ZCL_ALM_LB_FILL_DATA` mit `INTERFACES if_oo_adt_classrun`, die zuerst alle 5 Tabellen per `DELETE FROM` leert und danach:
   - die 5 Status aus der README in `ZALM_LB_LSTATUS` einfügt,
   - mindestens 5 Mitglieder in `ZALM_LB_MEMBER` anlegt (inkl. Mail, Telefon, Stadt, Avatar-URL und **einem gesperrten Mitglied**),
   - mindestens 6 Fachbücher in `ZALM_LB_BOOK` anlegt (Tipp: echte ISBNs wie `9780132350884` für *Clean Code* ermöglichen direkt echte Cover-URLs wie `https://covers.openlibrary.org/b/isbn/9780132350884-M.jpg`!),
   - passende Ausleihen und Rezensionen inkl. der **5 Testfälle aus Abschnitt 3 der README** erzeugt.

**Akzeptanzkriterien**

- Alle 5 Tabellen sind aktiv (`@AbapCatalog.deliveryClass : #A`).
- `ZCL_ALM_LB_FILL_DATA` läuft per `F9` (*Run As → ABAP Application (Console)*) fehlerfrei durch, auch mehrfach hintereinander, und gibt in `out->write( ... )` die eingefügten Satzzahlen aus.

**RAP-Baustein & Stolpersteine**

- UUIDs in der Datenklasse erzeugst du sauber über `cl_system_uuid=>create_uuid_x16_static( )`.
- Setze `GET TIME STAMP FIELD DATA(ts)` in die Admin-Zeitstempelfelder der Demodaten, damit ETag-Prüfungen später nicht über initiale Zeitstempel stolpern.

---

### LB-03 · Interface-Views (`I_`) mit Simple-Type-Casts, Kompositionen & Assoziationen

> „Ein Buch lebt nicht allein: Wenn wir ein Buch lesen, wollen wir direkt zu seinen Ausleihen und Rezensionen navigieren können – und bei jeder Ausleihe wissen, welches Mitglied dahintersteckt und welche Ampelfarbe der Status hat."

**Anforderungen**

1. Lege die fünf CDS View Entities (`define [root] view entity`) an:
   - `ZALM_LB_I_LoanStatus` (auf `zalm_lb_lstatus`, mit `@ObjectModel.resultSet.sizeCategory: #XS` für Dropdown-Darstellung!)
   - `ZALM_LB_I_Member` (auf `zalm_lb_member`, plus berechnetem Feld `concat_with_space( first_name, last_name, 1 ) as FullName` und `@Semantics.*` für Mail, Telefon, Adresse und Bild-URL)
   - `ZALM_LB_I_Book` (**`define root view entity`**)
   - `ZALM_LB_I_Loan` (Kind 1 mit `association to parent ZALM_LB_I_Book as _Book`)
   - `ZALM_LB_I_Review` (Kind 2 mit `association to parent ZALM_LB_I_Book as _Book`)
2. Nutze auf `ZALM_LB_I_Book` die moderne **7.58-Kardinalitätssyntax**:
   - `composition of exact one to many ZALM_LB_I_Loan as _Loan`
   - `composition of exact one to many ZALM_LB_I_Review as _Review`
3. Wende deine **CDS Simple Types aus LB-01** über `cast( ... as ZALM_LB_T_... preserving type ) as ...` an (z. B. für `BookId`, `Isbn`, `Title`, `Category`, `AvgRating`, `CoverUrl`, `LoanNo`, `Rating`).
4. Annotiere auf `ZALM_LB_I_Book`:
   - `@Semantics.amount.currencyCode: 'CurrencyCode'` an `Price`
   - `@Semantics.imageUrl: true` an `CoverUrl`
   - `@Semantics.largeObject: { mimeType: 'SampleMime', fileName: 'SampleFilename', contentDispositionPreference: #INLINE }` an `SamplePdf` und `@Semantics.mimeType: true` an `SampleMime`
   - alle 5 `@Semantics.user.*` / `@Semantics.systemDateTime.*` Annotationen an den Adminfeldern (und `localInstanceLastChangedAt` auf `Loan` & `Review`).

**Akzeptanzkriterien**

- Alle 5 Views aktivieren ohne Warnungen (dank `preserving type`!).
- Im ADT *Data Preview* (`F8`) auf `ZALM_LB_I_Book` siehst du deine Bücher, die deutschen Spaltenüberschriften aus den Simple Types und kannst per Rechtsklick *Follow Association* zu `_Loan` und `_Review` abspringen.

**CDS-Baustein & Stolpersteine**

- **Reihenfolge beim Anlegen:** Da `Book` auf `Loan`/`Review` zeigt und `Loan`/`Review` per `to parent` auf `Book`, legst du erst `Loan` & `Review` ohne `to parent` als Rumpf an (oder aktivierst alle drei gemeinsam über *Activate All / Mass Activation* `Strg+Umschalt+F3`).
- `sample_pdf` (`RAWSTRING`) **nicht** casten – einfach als `sample_pdf as SamplePdf` durchreichen.

---

### LB-04 · Basis-Behavior Definition (`managed; strict ( 2 ); with draft;`)

> „Die Bibliothekarin fängt oft an, ein neues Buch zu erfassen, wird am Schalter unterbrochen und möchte später genau dort weitermachen. Und wenn ein Buch gelöscht wird, müssen seine Ausleihen und Rezensionen sauber mit verschwinden."

**Anforderungen**

1. Lege die Basis-BDEF `ZALM_LB_I_Book` an mit:
   - `managed implementation in class zbp_alm_lb_i_book unique;`
   - `strict ( 2 );`
   - `with draft;`
2. Konfiguriere alle drei Knoten (`Book`, `Loan`, `Review`):
   - **UUID-Schlüsselvergabe:** `field ( numbering : managed, readonly ) BookUuid;` (analog `LoanUuid`, `ReviewUuid`) sowie `field ( readonly ) BookUuid;` auf den beiden Kindern.
   - **Readonly-Felder:** Alle Adminfelder sowie vorerst `AvailCopies` und `AvgRating` (werden in Stufe B berechnet).
   - **Locking & Authorizations:** `lock master total etag LastChangedAt` und `authorization master ( global, instance )` auf `Book`; `lock dependent by _Book` und `authorization dependent by _Book` auf `Loan` & `Review`.
   - **ETags:** `etag master LocalLastChangedAt` auf allen drei Entitäten.
   - **Draft-Aktionen auf `Book`:** `Edit`, `Activate optimized`, `Discard`, `Resume` sowie `draft determine action Prepare {}`.
   - **Kompositionen:** `association _Loan { create; with draft; }` und `association _Review { create; with draft; }` auf `Book`; Rückassoziation `association _Book { with draft; }` auf beiden Kindern.
   - **Feld-Mapping:** `mapping for zalm_lb_book { ... }` (sowie für `loan` und `review`).
3. Lass dir über den ADT-Quickfix (`Strg+1`) die drei Draft-Tabellen `zalm_lb_d_book`, `zalm_lb_d_loan`, `zalm_lb_d_review` sowie die Behavior-Pool-Klasse `ZBP_ALM_LB_I_BOOK` generieren.
4. Implementiere die leeren Pflicht-Berechtigungsmethoden `get_global_authorizations` und `get_instance_authorizations` zunächst so, dass der Zugriff erlaubt ist (sonst dumpt OData später mit `CX_RAP_HANDLER_NOT_IMPLEMENTED`).

**Akzeptanzkriterien**

- Alle 3 Draft-Tabellen, die BDEF `ZALM_LB_I_Book` und der Behavior Pool `ZBP_ALM_LB_I_BOOK` sind aktiv und fehlerfrei.

**RAP-Baustein & Stolpersteine**

- **Hier begegnest du bewusst der Simple-Type-Draft-Grenze:** Schau genau hin, was der ADT-Quickfix in `zalm_lb_d_book` für Felder wie `bookid` oder `title` erzeugt, die in `ZALM_LB_I_Book` auf `ZALM_LB_T_*` gecastet wurden! Falls dort der Simple-Type-Name landet und die Tabelle meckert (*„Typ ZALM_LB_T_... ist kein Datenelement"*), tausche ihn in der Draft-Tabelle gegen den identischen Built-in-Typ (`abap.char(10)`, `abap.char(120)` etc.) aus.

---

### LB-05 · Projection-Views (`C_`), Wertehilfen & Projection-BDEF

> „In der Oberfläche wollen wir beim Ausleihen nicht `MEM-0002` tippen, sondern aus einer Liste mit Namen und Abteilung wählen – und in der Tabelle soll direkt ‚Lena Bergmann (MEM-0002)' statt nur die Nummer stehen."

**Anforderungen**

1. Erstelle die drei Projektions-Views:
   - `ZALM_LB_C_Book` (`define root view entity ... provider contract transactional_query as projection on ZALM_LB_I_Book`) mit `@Metadata.allowExtensions: true` und `@ObjectModel.semanticKey: ['BookId']`.
   - `ZALM_LB_C_Loan` (`define view entity ... as projection on ZALM_LB_I_Loan`) mit `@Metadata.allowExtensions: true`.
   - `ZALM_LB_C_Review` (`define view entity ... as projection on ZALM_LB_I_Review`) mit `@Metadata.allowExtensions: true`.
2. Biege die Kompositionen und Eltern-Assoziationen sauber um (`redirected to composition child` / `redirected to parent`).
3. Ziehe in `ZALM_LB_C_Loan` per Pfadausdruck sprechende Texte und die Ampelfarbe heran:
   - `_Member.FullName as MemberName` (verknüpft mit `MemberId` über `@ObjectModel.text.element: ['MemberName']`)
   - `_Status.StatusText as StatusText` (verknüpft mit `StatusId` über `@ObjectModel.text.element: ['StatusText']`)
   - `_Status.Criticality as StatusCriticality`
4. Ziehe analog in `ZALM_LB_C_Review` `_Member.FullName as MemberName` und `_Member.AvatarUrl as MemberAvatar` heran.
5. Hänge `@Consumption.valueHelpDefinition` an `MemberId` (Ziel: `ZALM_LB_I_Member`) und `StatusId` (Ziel: `ZALM_LB_I_LoanStatus`, mit `useForValidation: true`).
6. Aktiviere die Volltextsuche (`@Search.searchable: true` + `@Search.defaultSearchElement: true` + `@Search.fuzzinessThreshold: 0.8`) auf `ZALM_LB_C_Book` (für `Title`, `Author`, `Isbn`, `BookId`) und auf `ZALM_LB_I_Member`.
7. Erstelle die **Projection-BDEF** `ZALM_LB_C_Book` (`projection; strict ( 2 ); use draft;`) und reiche Standardoperationen, Draft-Aktionen und Assoziationen mit `use ...;` durch.

**Akzeptanzkriterien**

- Alle 3 Projection-Views und die Projection-BDEF sind ohne Warnungen aktiv.

**RAP-Baustein & Stolpersteine**

- Nur der Root `ZALM_LB_C_Book` bekommt `provider contract transactional_query` – die beiden Kind-Projektionen **nicht**!
- Denk an die Schichtregel aus eurem [CODING-GUIDE.md](../CODING-GUIDE.md): `@Consumption.valueHelpDefinition`, `@ObjectModel.text.element` und `@Semantics.*` gehören in die **Projection-View (Schicht 5)**, nicht in die Metadata Extension!

---

### LB-06 · Metadata Extensions (`DDLX`), Service & erster OData-V4-Testlauf

> „Zeigen Sie uns den ersten klickbaren Durchstich im Browser: Bücher suchen, öffnen, ein Leseproben-PDF anhängen, eine Ausleihe und eine Rezension erfassen und als Entwurf zwischenspeichern."

**Anforderungen**

1. Lege drei **Metadata Extensions** (`@Metadata.layer: #CORE`) für `ZALM_LB_C_Book`, `ZALM_LB_C_Loan` und `ZALM_LB_C_Review` an:
   - **List Report (`Book`):** `@UI.selectionField` auf `Category`, `Author`, `PublishYear`; `@UI.lineItem` mit Cover-Vorschaubild (`CoverUrl`), `BookId`, `Title`, `Author`, `Category`, `AvailCopies`, `AvgRating`, `Price`; Standardsortierung nach `BookId` über `@UI.presentationVariant`.
   - **Object Page (`Book`):** `@UI.headerInfo` (Titel `Title`, Untertitel `Author`, Bild `CoverUrl`); Facetten (`@UI.facet`) für Stammdaten/Preis, Leseprobe (`SamplePdf`), Tabelle der Ausleihen (`_Loan`) und Tabelle der Rezensionen (`_Review`).
   - **Kind-Tabellen (`Loan` & `Review`):** Übersichtliche Spalten (`@UI.lineItem`) und Detail-Feldgruppen (`@UI.identification`), bei `StatusId` direkt mit `criticality: 'StatusCriticality'` und `@UI.textArrangement: #TEXT_FIRST`. Verstecke technische UUID- und Adminfelder mit `@UI.hidden: true`.
2. Erstelle die **Service Definition** `ZALM_LB_SD_LIBRARY` und exponiere `Book`, `Loan`, `Review`, `Member` und `LoanStatus`.
3. Erstelle das **Service Binding** `ZALM_LB_UI_LIBRARY_O4` vom Typ **OData V4 - UI**, aktiviere und publiziere (`Publish`) den lokalen Service-Endpunkt.

**Akzeptanzkriterien**

- *Preview* auf `Book` im Service Binding öffnet den Fiori Elements V4 List Report mit deinen Demobüchern und Buchcovern.
- Suche nach Buchtitel/Autor sowie Filter nach Kategorie funktionieren.
- Auf der Object Page siehst du Ausleihen (mit farbigen Status-Badges und Mitgliedsnamen statt bloßen IDs) sowie Rezensionen.
- Du kannst ein Buch im **Entwurfsmodus** anlegen/bearbeiten, ein kleines PDF in `SamplePdf` hochladen, eine Ausleihe mit F4-Wertehilfe hinzufügen und den Entwurf aktivieren.

**RAP-Baustein & Stolpersteine**

- Service Definitions (`SRVD`) erlauben in manchen Releases keine `//`-Kommentare am Zeilenende – halte die Datei sauber.
- Fehlt `expose ZALM_LB_I_Member` oder `expose ZALM_LB_I_LoanStatus` in der `SRVD`, bleibt der F4-Wertehilfedialog im UI leer!

---

---

## Stufe B — Determinations, Validations & Business-Logik

### LB-07 · Nachrichtenklasse `ZALM_LB_MSG` & RAP-Exception `ZCM_ALM_LB`

> „Wenn ein Benutzer ein ungültiges Datum oder ein gesperrtes Mitglied auswählt, soll die Fiori-App das nicht mit einem technischen Fehler quittieren, sondern eine freundliche, deutsche Fehlermeldung direkt am betroffenen Eingabefeld rot aufleuchten lassen."

**Anforderungen**

1. Lege die **Nachrichtenklasse** `ZALM_LB_MSG` mit folgenden Meldungen an:
   - `001`: `Rückgabedatum &1 darf nicht vor dem Ausleihdatum &2 liegen.`
   - `002`: `Das Mitglied &1 (&2) ist für neue Ausleihen gesperrt!`
   - `003`: `Keine Exemplare von Buch '&1' mehr verfügbar (aktueller Bestand: 0).`
   - `004`: `Die Bewertung &1 ist ungültig (erlaubt: 1.00 bis 5.00 Sterne).`
   - `005`: `Buch-ID &1 existiert bereits.`
   - `006`: `Die Leihfrist darf maximal 30 Tage betragen.`
2. Lege die **RAP-Nachrichtenklasse** `ZCM_ALM_LB` an:
   - Erbt von `cx_static_check`
   - Implementiert `if_t100_message`, `if_t100_dyn_msg`, `if_abap_behv_message`
   - Konstruktor mit Übergabe von `severity` (`if_abap_behv_message=>severity-error` etc.), `textid` und den 4 Textvariablen `m_v1` bis `m_v4`.

**Akzeptanzkriterien**

- Nachrichtenklasse und Exception-Klasse sind fehlerfrei aktiviert.
- `ZCM_ALM_LB` lässt sich in Test-Snippets oder Konsolenprogrammen mit einer T100-Meldung instanziieren.

**RAP-Baustein & Stolpersteine**

- In RAP-Exceptions muss `if_abap_behv_message` immer mit implementiert werden – nur so kann die Instanz später direkt an `reported-loan` / `reported-book` übergeben werden!

---

### LB-08 · Automatische Nummern & Standardwerte per Determination (`on modify`)

> „Beim Erfassen einer neuen Ausleihe soll der Bibliothekar nicht das heutige Datum und das Rückgabedatum von Hand im Kalender suchen müssen: Leihdatum ist heute, Rückgabefrist 14 Tage, Status 'Ausgeliehen'. Und wenn ein neues Buch ohne ID angelegt wird, vergeben wir automatisch die nächste Nummer `MED-0001`."

**Anforderungen**

1. Erweitere die BDEF `ZALM_LB_I_Book`:
   - Auf `Book`: `determination determineBookId on modify { create; }`
   - Auf `Loan`: `determination setInitialLoanData on modify { create; }`
   - Auf `Review`: `determination setInitialReviewData on modify { create; }`
2. Implementiere die Methoden im Behavior Pool `ZBP_ALM_LB_I_BOOK`:
   - `determineBookId`: Liest die höchste vorhandene `book_id` aus `zalm_lb_book` (und `zalm_lb_d_book`!), ermittelt die nächste Nummer und formatiert sie als `MED-nnnn`. (Nur vergeben, wenn `BookId` noch initial ist!).
   - `setInitialLoanData`: Setzt `LoanDate = cl_abap_context_info=>get_system_date( )`, `DueDate = LoanDate + 14`, `StatusId = 'AC'` und `ExtensionCount = 0`.
   - `setInitialReviewData`: Setzt `ReviewDate = cl_abap_context_info=>get_system_date( )`.

**Akzeptanzkriterien**

- Klickst du in der Fiori-Preview auf *„Buch anlegen“* und speicherst ohne ID, wird automatisch z. B. `MED-0007` generiert.
- Klickst du in der Ausleihen-Tabelle auf *„Hinzufügen“*, sind Datum (heute), Fälligkeit (+14 Tage) und Status (`AC`) sofort vorbelegt.

---

### LB-09 · Cross-Entity-Determinations: Live-Bestand & Schnitt-Bewertung

> „Wenn ein Buch verliehen oder zurückgebracht wird, muss sich die Zahl der verfügbaren Exemplare (`AvailCopies`) am Buch automatisch anpassen. Und jede neue Rezension muss sofort die durchschnittliche Sterne-Bewertung (`AvgRating`) des Buchs neu berechnen."

**Anforderungen**

1. Erweitere die BDEF `ZALM_LB_I_Book`:
   - Auf `Book`: `determination calculateAvailCopies on save { field TotalCopies; }`
   - Auf `Loan`: `determination calculateAvailCopies on save { field StatusId; create; delete; }`
   - Auf `Review`: `determination calculateAvgRating on save { field Rating; create; delete; }`
2. Implementiere `calculateAvailCopies`:
   - Ermittelt alle aktiven Ausleihen des Buchs (Status mit `is_active_loan = abap_true` aus `ZALM_LB_LSTATUS`).
   - Rechnet `avail_copies = total_copies - aktive_ausleihen` (mindestens `0`).
   - Schreibt das Ergebnis per EML `MODIFY ENTITIES OF ZALM_LB_I_Book ENTITY Book UPDATE FIELDS ( AvailCopies ) ...` zurück.
3. Implementiere `calculateAvgRating`:
   - Liest alle Rezensionen des Buchs, errechnet den arithmetischen Mittelwert aller `Rating`-Werte (auf 2 Nachkommastellen gerundet) und aktualisiert `AvgRating` am Buch.

**Akzeptanzkriterien**

- Ändert sich der Status einer Ausleihe von `AC` auf `RT` (Zurückgegeben), erhöht sich `AvailCopies` am Buch um 1.
- Erfasst du eine Rezension mit 4 Sternen für ein Buch mit 5 Sternen, springt `AvgRating` auf `4.50`.

**RAP-Baustein & Stolpersteine**

- **Cross-Entity-Trigger:** Da eine Änderung an `Loan` das Elternobjekt `Book` aktualisieren muss, liest du in der Loan-Determination per EML über die Elternassoziation `_Book` die `BookUuid` aus.

---

### LB-10 · Validierungen & Draft `Prepare`

> „Ein Buch ohne Bestand darf nicht verliehen werden. Eine Rückgabe darf nicht in der Vergangenheit vor dem Leihdatum liegen. Und gesperrte Mitarbeiter dürfen keine Medien mehr mitnehmen."

**Anforderungen**

1. Erweitere die BDEF `ZALM_LB_I_Book` um folgende Validierungen:
   - Auf `Loan`:
     - `validation validateDates on save { field LoanDate, DueDate, ReturnDate; create; }`
     - `validation validateMember on save { field MemberId; create; }`
     - `validation validateAvailability on save { create; }`
   - Auf `Review`:
     - `validation validateRating on save { field Rating; create; }`
2. Hänge alle vier Validierungen in die Draft Determine Action ein:
   ```abap
   draft determine action Prepare {
     validation Loan~validateDates;
     validation Loan~validateMember;
     validation Loan~validateAvailability;
     validation Review~validateRating;
   }
   ```
3. Implementiere die Prüfungen im Behavior Pool:
   - `validateDates`: `DueDate` muss `>= LoanDate` sein; `ReturnDate` (falls gefüllt) muss `>= LoanDate` sein.
   - `validateMember`: Prüft `_Member.is_blocked`. Ist das Mitglied gesperrt, Meldung `002` auslösen.
   - `validateAvailability`: Prüft, ob `AvailCopies > 0`. Falls `0`, Meldung `003` auslösen.
   - `validateRating`: Prüft, ob `Rating` zwischen `1.00` und `5.00` liegt.
4. Fülle bei Fehlern `failed` und `reported` (inkl. `element-%field` für Feldhervorhebung im Fiori-UI!).

**Akzeptanzkriterien**

- Klick auf *„Aktivieren“* (Save) prüft alle Bedingungen.
- Bei Fehlern leuchtet das fehlerhafte Eingabefeld rot auf und das Fiori-Message-Popover öffnet sich mit deiner deutschen Nachricht.

---

### LB-11 · Side Effects (OData V4 Sofort-Reaktion im Browser)

> „Wenn ich die Gesamtexemplare von 2 auf 5 erhöhe oder eine Ausleihe anlege, möchte ich sofort sehen, wie sich die verfügbaren Exemplare auf dem Bildschirm ändern – ohne erst die Seite neu laden zu müssen."

**Anforderungen**

1. Erweitere die Projection-BDEF `ZALM_LB_C_Book` (oder Interface-BDEF) um **Side Effects**:
   - Ändert sich `TotalCopies` am Buch $\rightarrow$ lade `AvailCopies` neu:
     ```abap
     side effects { field TotalCopies affects field AvailCopies; }
     ```
   - Wird an `_Loan` etwas geändert $\rightarrow$ aktualisiere die übergeordnete Entität `_Book`:
     ```abap
     side effects { field StatusId affects entity _Book; }
     ```

**Akzeptanzkriterien**

- Beim Tippen einer neuen Zahl in `TotalCopies` (und Verlassen des Felds per Tab) sendet der Browser im Netzwerk-Tab einen gezielten OData-Request und aktualisiert `AvailCopies` live auf dem Bildschirm.

---

## Stufe C — Actions, Parameter, Defaulting & Feature Control

In Stufe C wird deine Fachmedienverwaltung von reiner Datenpflege zu einer **echten prozessgeführten App**: Ausleihen werden per Knopfdruck gestartet, verlängert und zurückgegeben, unzulässige Buttons werden dynamisch ausgegraut, Bücher lassen sich klonen und Bibliothekskennzahlen per Function abrufen.

> [!IMPORTANT]
> **Voraussetzungen & Stolpersteine vor dem Start in Stufe C:**
> 1. **`LB-11` zuerst glattziehen:** Ergänze `use side effects;` in `ZALM_LB_C_Book` (`BDEF`) und stelle `Book~calculateAvailCopies` in `ZALM_LB_I_Book` auf `on modify` (inkl. `FOR DETERMINE ON MODIFY` in `lhc_Book`), damit bestehende und neue Action-Side-Effects im Fiori UI auch wirklich ankommen.
> 2. **`strict ( 2 )` + Authorization auf allen neuen Actions:** Da `ZALM_LB_I_Book` auf `Book` mit `authorization master ( global, instance )` arbeitet (und `Loan` mit `authorization dependent by _Book`), braucht jede Instance Action zwingend **`authorization : update`** (bzw. bei Factory/Static Actions `authorization : global` oder explizite Prüfung in `get_global_authorizations` / `get_instance_authorizations`). Ohne diesen Zusatz bricht der Aufruf zur Laufzeit ab.
> 3. **Statuscodes aus der Live-DB (`ZALM_LB_LSTATUS`):** Maßgeblich sind die echten Tabellencodes **`AC`** (Ausgeliehen), **`EX`** (Verlängert), **`OV`** (Überfällig), **`RT`** (Zurückgegeben, final) und **`LO`** (Verloren, aktiv + final) — auch im [`Prozessmodell.md`](Prozessmodell.md) entsprechend gepflegt.

---

### `LB-12` — Loan-Lifecycle-Actions: `returnBook` & `extendLoan` (Parameter-Dialog)

**Ziel:** Rückgabe und Verlängerung einer Ausleihe laufen über sprechende Business-Actions auf der Entity `Loan` (`ZALM_LB_I_BOOK`) statt über manuelles Ändern von `StatusId` oder `DueDate`.

**Was zu tun ist:**

1. **Action `returnBook` auf `Loan` (ohne Parameter):**
   - In `ZALM_LB_I_Book` (Behavior for `ZALM_LB_I_LOAN alias Loan`):
     ```abap
     action ( authorization : update ) returnBook result [1] $self;
     ```
   - Methode `returnBook` in `lhc_loan` (`Strg+1` in ADT) implementieren:
     - `Loan` lesen (`READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE ENTITY Loan ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_loans).`).
     - Prüfen: Nur aktive, nicht-finale Ausleihen (`StatusId = 'AC' OR StatusId = 'EX' OR StatusId = 'OV'`) dürfen zurückgegeben werden. Bei `RT` oder `LO` per `failed-loan` und `reported-loan` mit sprechender Meldung aus `ZALM_LB_MSG` ablehnen.
     - Per `MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE ENTITY Loan UPDATE FIELDS ( StatusId ReturnDate )` setzen: `StatusId = 'RT'`, `ReturnDate = cl_abap_context_info=>get_system_date( )`.
     - Aktualisierte Zeilen nachlesen und in `result` zurückgeben (`VALUE #( FOR ls_loan IN lt_updated ( %tky = ls_loan-%tky %param = ls_loan ) )`).

2. **Abstract Entity `ZALM_LB_A_ExtendParam` + Action `extendLoan` auf `Loan`:**
   - Neue Data Definition anlegen (**Abstract Entity**, nicht CDS View Entity!):
     ```abap
     @EndUserText.label: 'Parameter für Ausleihverlängerung'
     define abstract entity ZALM_LB_A_ExtendParam
     {
       @EndUserText.label: 'Begründung'
       Reason : abap.char(120);
     }
     ```
   - In `ZALM_LB_I_Book` auf `Loan`:
     ```abap
     action ( authorization : update ) extendLoan
       parameter ZALM_LB_A_ExtendParam
       result [1] $self;
     ```
   - Methode `extendLoan` in `lhc_loan`:
     - Prüfen: `StatusId` muss `AC` oder `EX` sein (`OV`, `RT` oder `LO` → Ablehnung mit Fehlermeldung in `ZALM_LB_MSG`).
     - Prüfen: `ExtensionCount < 2` (max. 2× verlängerbar gemäß `Prozessmodell.md` — ab der 3. Anfrage ablehnen).
     - Pflichtparameter prüfen: Ist `<ls_key>-%param-Reason IS INITIAL`, über `failed-loan` & `reported-loan` abweisen.
     - Update auf `Loan`: `DueDate = ls_loan-DueDate + 14`, `ExtensionCount = ls_loan-ExtensionCount + 1`, `StatusId = 'EX'`, optional `Note` um die Begründung ergänzen (Feldname in `ZALM_LB_I_LOAN`: `Note`!).
     - Aktualisierte Entitäten in `result` zurückgeben.

3. **Side Effects, Projection & UI (`ZALM_LB_C_Book`, `ZALM_LB_C_Loan` DDLX):**
   - Auf `Loan` in `ZALM_LB_I_Book` ergänzen:
     ```abap
     side effects {
       field StatusId affects entity _Book;
       action returnBook affects entity _Book, $self;
       action extendLoan affects $self;
     }
     ```
   - In `ZALM_LB_C_Book` (Behavior for `Loan`): `use action returnBook;` und `use action extendLoan;` ergänzen.
   - In der Metadata Extension `ZALM_LB_C_Loan` (`DDLX`) die Action-Buttons via `{ type: #FOR_ACTION, dataAction: 'returnBook', label: 'Zurückgeben' }` und `{ type: #FOR_ACTION, dataAction: 'extendLoan', label: 'Verlängern' }` in `@UI.lineItem` (Ausleihen-Tabelle) und `@UI.identification` (Loan Object Page) einhängen.

**Checkliste `LB-12`:**
- [x] `returnBook` setzt `StatusId = 'RT'` und `ReturnDate` auf heute und verhindert doppelte Rückgabe
- [x] `ZALM_LB_A_ExtendParam` mit `Reason` existiert; `extendLoan` erzwingt Begründung & max. 2 Verlängerungen
- [x] Nach `returnBook` aktualisiert sich `AvailCopies` auf dem Buch (nach Aktivieren / über Side Effect)

---

### `LB-13` — Ausleih-Dialog vom Buch aus: `lendBook` mit Wertehilfe & Backend-Defaulting

**Ziel:** Nutzer können direkt auf einem Buch auf **„Ausleihen“** klicken, bekommen ein Popup mit Wertehilfe für Mitglieder sowie optionalen Datumsfeldern (bei leerer Eingabe automatisch heute und +14 Tage) — und die neue Ausleihe wird per EML unter `_Loan` angelegt.

> [!TIP]
> Genau dieser Komfort-Button auf `Book` greift das Thema aus `LB-10` wieder auf: In `LB-13` entsteht der Dialog, in `LB-14` wird er automatisch ausgegraut, sobald `AvailCopies = 0` ist.

> [!NOTE]
> **Release-Hinweis für S4P (`SAP_BASIS 758 SP03` / S/4HANA 2023 FPS03):**
> Das BDL-Feature `{ default function GetDefaultsForLendBook; }` (*Operation Defaulting* zur Vorbelegung von Action-Popups im UI) steht in S/4HANA On-Premise erst ab **S/4HANA 2025 FPS00 (ABAP 8.16)** bzw. in der Cloud ab **2311 (ABAP 7.90)** zur Verfügung. Auf S4P (`7.58`) lassen wir `default function` daher weg und lösen die Standardwerte sauber im Handler `lendBook` (wenn `LoanDate`/`DueDate` im Dialog leer bleiben).
> *(Hinweis: Auf 7.58 kennt `@UI.defaultValue` in Abstract Entities nur Literale oder `#( 'ELEMENT_OF_REFERENCED_ENTITY: <Feld>' )` aus dem aufrufenden Kontext, keine dynamischen Ausdrücke wie `sy-datum`.)*

**Was zu tun ist:**

1. **Abstract Entity `ZALM_LB_A_LendParam` anlegen:**
   - Felder für den Ausleih-Dialog definieren:
     - `MemberId` mit `@Consumption.valueHelpDefinition: [{ entity: { name: 'ZALM_LB_I_MEMBER', element: 'MemberId' } }]` (genau wie in `ZALM_LB_C_Loan`)
     - `LoanDate : abap.dats;` (optional — leer = heute)
     - `DueDate : abap.dats;` (optional — leer = `LoanDate + 14`)
     - `Note : abap.char(255);` (optional)

2. **Action `lendBook` in `ZALM_LB_I_Book` definieren:**
   - In `ZALM_LB_I_Book` auf `Book` (**ohne** `{ default function ... }`):
     ```abap
     action ( authorization : update ) lendBook
       parameter ZALM_LB_A_LendParam
       result [1] $self;
     ```

3. **`lendBook` in `lhc_Book` implementieren:**
   - Datumswerte vorbelegen, falls im Dialog leer gelassen:
     - `lv_loan_date = COND #( WHEN ls_key-%param-LoanDate IS INITIAL THEN cl_abap_context_info=>get_system_date( ) ELSE ls_key-%param-LoanDate )`
     - `lv_due_date  = COND #( WHEN ls_key-%param-DueDate  IS INITIAL THEN lv_loan_date + 14 ELSE ls_key-%param-DueDate )`
   - Eingaben prüfen: `MemberId` darf nicht initial sein; in `ZALM_LB_MEMBER` prüfen, ob Mitglied existiert und `IsBlocked` initial ist; `lv_due_date >= lv_loan_date` prüfen (falls der Nutzer im Dialog beide Daten oder ein frühes `DueDate` selbst eingibt).
   - Server-seitigen Bestands-Guard auf dem `Book` (und ggf. Draft-`_Loan`-Einträgen) ausführen: Sind noch Exemplare frei (`AvailCopies > 0` bzw. aktive Loans < `TotalCopies`)? Wenn nein → `failed-book` & `reported-book` mit Fehlermeldung befüllen.
   - Neue Kind-Entität über EML anlegen (`%is_draft = ls_key-%is_draft` im `%target` mitgeben!):
     ```abap
     MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
       ENTITY Book
         CREATE BY \_Loan
         AUTO FILL CID
         FIELDS ( MemberId LoanDate DueDate StatusId Note )
         WITH VALUE #( ... ).
     ```
     *(Hinweis: `ExtensionCount` übernimmt `setInitialLoanData` auf `Loan`, `StatusId = 'AC'` explizit mitgeben.)*
   - Aktualisiertes `Book` lesen und über `result` zurückgeben.

4. **Projection, Side Effects & UI (`ZALM_LB_C_Book`):**
   - In `ZALM_LB_C_Book` (`BDEF`, Behavior for `Book`) die Action freigeben (**kein** `use function`):
     ```abap
     use action lendBook;
     ```
   - Auf `Book` in `ZALM_LB_I_Book` ergänzen:
     ```abap
     side effects {
       field TotalCopies affects field AvailCopies;
       action lendBook affects entity _Loan, field AvailCopies;
     }
     ```
   - In `ZALM_LB_C_Book` (`DDLX`) den Button **„Ausleihen“** (`type: #FOR_ACTION, dataAction: 'lendBook'`) in `@UI.lineItem` und `@UI.identification` platzieren.

**Checkliste `LB-13`:**
- [x] `MemberId` bietet im Popup die Suchhilfe auf `ZALM_LB_I_MEMBER`
- [x] Lässt du `LoanDate` und `DueDate` leer, werden automatisch heute und `+14 Tage` gespeichert; gibst du ein ungültiges `DueDate < LoanDate` ein, lehnt `lendBook` sauber ab
- [x] Nach Bestätigung erscheint die neue Ausleihe sofort unter `_Loan` und `AvailCopies` zählt herunter

---

### `LB-14` — Dynamisches Feature Control (`get_instance_features`)

**Ziel:** Ungültige Aktionen werden bereits im Fiori-UI dynamisch deaktiviert (`fc-o-disabled`), sodass Anwender z. B. voll ausgeliehene Bücher gar nicht mehr über den Button ausleihen oder abgeschlossene Ausleihen nicht mehr zurückgeben können.

**Was zu tun ist:**

1. **Feature-Control-Deklaration in `ZALM_LB_I_Book` ergänzen:**
   - Auf `Book`:
     - `lendBook`: `action ( features : instance, authorization : update ) lendBook ...`
     - Optional für Archiv-/Löschschutz: `delete ( features : instance );` (bzw. `update ( features : instance );`)
   - Auf `Loan`:
     - `action ( features : instance, authorization : update ) returnBook result [1] $self;`
     - `action ( features : instance, authorization : update ) extendLoan parameter ZALM_LB_A_ExtendParam result [1] $self;`
     - Optional: `update ( features : instance );` / `delete ( features : instance );` um finale Historie (`RT`, `LO`) gegen Bearbeiten zu sperren.

2. **Implementierung in `lhc_Book~get_instance_features` (`Strg+1` in ADT):**
   - `Book` (und optional `_Loan`) via `READ ENTITIES ... IN LOCAL MODE` lesen.
   - Für jedes Buch in `result` setzen:
     - `%action-lendBook`: `if_abap_behv=>fc-o-disabled`, wenn `AvailCopies <= 0` oder `IsArchived = abap_true`; sonst `if_abap_behv=>fc-o-enabled`.
     - *(Falls `delete ( features : instance );` aktiv)*: `%delete` auf `fc-o-disabled` setzen, wenn noch aktive Ausleihen (`AC`, `EX`, `OV`) existieren.

3. **Implementierung in `lhc_loan~get_instance_features`:**
   - `Loan` lesen (`FIELDS ( StatusId ExtensionCount )`).
   - Für jede Ausleihe in `result` setzen:
     - `%action-returnBook`: `fc-o-enabled` nur bei `StatusId = 'AC' OR StatusId = 'EX' OR StatusId = 'OV'`; bei `RT` oder `LO` → `fc-o-disabled`.
     - `%action-extendLoan`: `fc-o-enabled` nur bei `( StatusId = 'AC' OR StatusId = 'EX' ) AND ExtensionCount < 2`; bei `OV`, `RT`, `LO` oder `ExtensionCount >= 2` → `fc-o-disabled`.
     - *(Falls `update`/`delete` auf `Loan` mit `( features : instance )`)*: Finale Sätze (`RT`, `LO`) auf `fc-o-disabled` setzen.

4. **Test im Fiori Preview:**
   - Buch ohne verfügbare Exemplare (`AvailCopies = 0`): Button **„Ausleihen“** ist ausgegraut.
   - Sobald über `returnBook` ein Exemplar zurückkommt: Button **„Ausleihen“** auf `Book` wird wieder aktiv, Button **„Zurückgeben“** und **„Verlängern“** auf dieser `Loan`-Zeile werden grau.
   - Ausleihe mit `StatusId = 'OV'` oder `ExtensionCount = 2`: **„Verlängern“** ist ausgegraut, **„Zurückgeben“** bleibt aktiv.

**Checkliste `LB-14`:**
- [x] `get_instance_features` auf `Book` und `Loan` ohne Syntaxfehler aktiv
- [x] `lendBook` ist bei `AvailCopies = 0` im List Report und auf der Object Page deaktiviert
- [x] `returnBook` / `extendLoan` reagieren exakt auf `StatusId` (`AC`/`EX`/`OV`/`RT`/`LO`) und `ExtensionCount`

---

### `LB-15` — Factory Action (`duplicateBook`), Static Function (`getLibraryKpis`) & EML-Absicherung

**Ziel:** Eine neue Buch-Instanz per **Factory Action** aus einer bestehenden Vorlage erzeugen, schreibfreie Bibliothekskennzahlen per **Static Function** liefern und den gesamten Stufe-C-Prozess automatisiert per EML testen.

**Was zu tun ist:**

1. **Factory Action `duplicateBook` auf `Book`:**
   - In `ZALM_LB_I_Book` auf `Book`:
     ```abap
     factory action ( features : instance, authorization : update ) duplicateBook [1];
     ```
     *(Wichtig: Eine `factory action` darf **keinen** `result`-Zusatz tragen — die Rückgabe des neu erzeugten Schlüssels an das Framework erfolgt zwingend über `mapped-book` mit Zuordnung `%cid = <ls_key>-%cid`!)*
   - In `lhc_Book~duplicateBook` (Signatur per Quick Fix `Strg+1`):
     - Vorlagen per `READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE ENTITY Book ALL FIELDS WITH CORRESPONDING #( keys )` lesen.
     - Neue Kopie(n) per `MODIFY ENTITIES ... ENTITY Book CREATE` anlegen:
       - `%cid = ls_key-%cid`, `%is_draft = ls_key-%is_draft`
       - `BookId` **leer lassen** (damit `determineBookId` automatisch eine neue `MED-xxxx` vergibt!)
       - `Title = |{ ls_book-Title } (Kopie)|`, `Isbn` leeren (keine Dubletten-ISBN), `AvailCopies = ls_book-TotalCopies`, `AvgRating = 0`, `IsArchived = abap_false`
       - Keine Übernahme von `_Loan`, `_Review` oder `SamplePdf`
     - Die erzeugten Schlüssel aus `MAPPED DATA(ls_created)` direkt an `mapped-book` weiterreichen (und fehlgeschlagene über `failed`/`reported` melden).
   - Projection & UI: In `ZALM_LB_C_Book` `use action duplicateBook;` ergänzen und Button **„Duplizieren“** (`type: #FOR_ACTION, dataAction: 'duplicateBook'`) in `ZALM_LB_C_Book` (`DDLX`) platzieren. (Hinweis für `get_instance_features`: `duplicateBook` darf für alle Bücher aktiv bleiben — `%action-duplicateBook = if_abap_behv=>fc-o-enabled` nicht vergessen, sobald `features : instance` dranhängt!)

2. **Static Function `getLibraryKpis`:**
   - Abstract Entity `ZALM_LB_A_LibraryKpis` anlegen (z. B. `TotalBooks`, `TotalCopies`, `AvailableCopies`, `ActiveLoans`, `OverdueLoans` mit Typ `abap.int4`, sowie `AvgLibraryRating` als `ZALM_LB_T_Rating`).
   - In `ZALM_LB_I_Book` auf `Book`:
     ```abap
     static function getLibraryKpis
       result [1] ZALM_LB_A_LibraryKpis;
     ```
     *(Hinweis: Bei `static function` erlaubt die BDL-Syntax keinen Zusatz `( authorization : ... )`, da es sich um eine reine Lese-Operation handelt.)*
   - In `lhc_Book~getLibraryKpis`: Kennzahlen aus `ZALM_LB_I_BOOK` und `ZALM_LB_I_LOAN` aggregieren (`OverdueLoans` auf `StatusId = 'OV'`!) und als genau 1 Ergebniszeile in `result` zurückgeben.
   - In `ZALM_LB_C_Book`: `use function getLibraryKpis;` freigeben (im OData-V4-Service unter `$metadata` / OpenAPI / EML direkt aufrufbar).

3. **EML- / ABAP-Unit-Verifikation:**
   - Kleine lokale Testklasse (`testclasses`-Include in `ZBP_ALM_LB_I_BOOK`) oder ausführbare Konsolen-/Test-Methode anlegen, die den Prozess einmal automatisch prüft:
     1. `lendBook` auf einem Testbuch → Bestand sinkt um 1
     2. `extendLoan` 2× → `ExtensionCount = 2`, `StatusId = 'EX'`, 3. Versuch liefert Eintrag in `failed-loan`
     3. `returnBook` → `StatusId = 'RT'`, Bestand wieder oben
     4. `duplicateBook` → neue `BookUuid` & neue `BookId`, `AvailCopies = TotalCopies`
     5. `getLibraryKpis` → stimmige Summen (`TotalBooks > 0`, `OverdueLoans >= 0`)

**Checkliste `LB-15`:**
- [x] Klick auf **„Duplizieren“** im UI öffnet sofort das neu angelegte Buch mit neuer `MED-xxxx`
- [x] `getLibraryKpis` liefert plausible Zahlen inkl. `OverdueLoans` (`OV`)
- [x] Ein EML-Durchlauf (oder Unit-Test) bestätigt `lendBook` → `extendLoan` → `returnBook` → `duplicateBook` → `getLibraryKpis` ohne Laufzeitfehler

---

## Stufe D — Custom Entity, HTTP-API & 1-Klick-Import (`LB-16` bis `LB-18`)

In Stufe D bindest du eine **externe REST-API (`openlibrary.org`)** ohne eigene Datenbanktabelle über eine **RAP Custom Entity** (`IF_RAP_QUERY_PROVIDER`) an – inklusive sauberem **Offline-JSON-Fallback** und einer **Unmanaged Action**, die Treffer per EML direkt in dein bestehendes `Book`-BO übernimmt.

> [!NOTE]
> **On-Premise-Hinweis für S4P (`SAP_BASIS 758` / Standard ABAP):**
> `CL_HTTP_DESTINATION_PROVIDER` existiert nur in **ABAP Cloud / BTP**, **nicht** auf S4P On-Premise! Nutze für direkte URL-Aufrufe stattdessen **`CL_HTTP_CLIENT=>CREATE_BY_URL`** (z. B. mit `ssl_id = 'ANONYM'`) – oder `CL_OUTBOUND_PROVIDER_HTTP=>CREATE_BY_DESTINATION` + `CL_WEB_HTTP_CLIENT_MANAGER`, falls eine `SM59`-Destination gepflegt ist. Für JSON-Parsing steht auf S4P **`/UI2/CL_JSON`** bereit.

---

### `LB-16` · Custom Entity `ZALM_LB_CE_OpenLibBook` & `IF_RAP_QUERY_PROVIDER`

> „Unsere Bibliothekarin möchte neue Fachbücher nicht mehr alle abtippen: Sie sucht nach Titel, Autor oder ISBN in OpenLibrary und bekommt sofort Titel, Autor, Erscheinungsjahr, ISBN und Cover-URL angezeigt – auch dann, wenn der SAP-Server gerade keinen direkten Internetzugang hat.“

**Was zu tun ist:**

1. **Custom Entity `ZALM_LB_CE_OpenLibBook` anlegen (`define custom entity`):**
   - Annotation im Header:
     ```abap
     @EndUserText.label: 'OpenLibrary Buchsuche'
     @ObjectModel.query.implementedBy: 'ABAP:ZCL_ALM_LB_OPENLIB_QRY'
     @Metadata.allowExtensions: true
     @Search.searchable: true
     ```
   - Felder definieren (nutze direkt deine CDS Simple Types aus `LB-01`!):
     - `key OpenLibKey : abap.char(40);` (z. B. `OL7353617W` – Work-Key aus OpenLibrary)
     - `Isbn        : ZALM_LB_T_Isbn;`
     - `@Search.defaultSearchElement: true` `Title : ZALM_LB_T_Title;`
     - `@Search.defaultSearchElement: true` `Author : abap.char(80);`
     - `PublishYear : abap.numc(4);`
     - `@Semantics.imageUrl: true` `CoverUrl : ZALM_LB_T_Url;`
     - `SourceMode  : abap.char(15);` (`'LIVE'` oder `'FALLBACK'`, damit man sofort sieht, ob der Live-Call durchkam)

2. **Query-Provider-Klasse `ZCL_ALM_LB_OPENLIB_QRY` erstellen:**
   - Implementiert `INTERFACES if_rap_query_provider` (plus optional `if_oo_adt_classrun` zum schnellen Testen per `F9`!).
   - In `if_rap_query_provider~select`:
     - **Filter & Suche auslesen:**
       - `io_request->get_filter( )->get_as_ranges( )` (für Filter auf `Title`, `Author`, `Isbn`, `OpenLibKey`)
       - `io_request->get_search_expression( )` (für die globale Suchleiste)
     - **HTTP-Abruf mit Offline-Fallback kapseln (z. B. Hilfsmethode `fetch_openlib_json`):**
       - Baut eine URL gegen `https://openlibrary.org/search.json?q=<suchbegriff>&limit=20` (URL-Encoding über `cl_http_utility=>escape_url`!).
       - Ruft `cl_http_client=>create_by_url( EXPORTING url = ... ssl_id = 'ANONYM' IMPORTING client = DATA(lo_client) )`, `send( )`, `receive( )` auf und prüft HTTP-Status `200`.
       - **Wichtig:** Schlägt `create_by_url` / `send` / `receive` fehl (Firewall, fehlendes SSL-Zertifikat in `STRUST`, Timeout oder Status != 200), fängt die Methode sauber ab und liefert stattdessen ein eingebautes, realistisches **Offline-JSON** (mind. 5–6 bekannte IT-/ABAP-/Architektur-Bücher mit echten OpenLibrary-Keys, ISBNs und Cover-URLs) + setzt `SourceMode = 'FALLBACK'`.
     - **JSON-Parsing & Filterung:**
       - Mit `/ui2/cl_json=>deserialize` in passende lokale Typen einlesen (`docs`-Array mit `key`, `title`, `author_name`, `first_publish_year`, `isbn`, `cover_i`).
       - `CoverUrl` aus `cover_i` (bzw. `isbn`) bauen: `https://covers.openlibrary.org/b/id/<cover_i>-M.jpg`.
       - Im Fallback-Modus auch lokal nach Suchbegriff/Ranges filtern, damit Suche & Filter im UI genauso funktionieren!
     - **Paging & OData-Contract einhalten (Pflicht bei Custom Entities!):**
       - `DATA(lv_offset) = io_request->get_paging( )->get_offset( ).`
       - `DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).` (Achtung: `-1` bedeutet *unbegrenzt*!).
       - `IF io_request->is_total_numb_of_rec_requested( ). io_response->set_total_number_of_records( lines( lt_all ) ). ENDIF.`
       - `IF io_request->is_data_requested( ). io_response->set_data( lt_paged ). ENDIF.`

3. **In Service Definition freigeben:**
   - In `ZALM_LB_SD_LIBRARY` ergänzen: `expose ZALM_LB_CE_OpenLibBook as OpenLibBook;`

**Checkliste `LB-16`:**
- [ ] Custom Entity `ZALM_LB_CE_OpenLibBook` und Klasse `ZCL_ALM_LB_OPENLIB_QRY` sind aktiv
- [ ] Live-HTTP-Call gegen `openlibrary.org` oder automatischer `FALLBACK` liefert saubere Buchdatensätze inkl. Cover-URLs
- [ ] Paging (`offset` / `page_size`) und `set_total_number_of_records` sind korrekt umgesetzt (kein `CX_RAP_QUERY_PROVIDER`-Dump)

---

### `LB-17` · Metadata Extension (`DDLX`) & OData-V4-Preview für `OpenLibBook`

**Ziel:** `OpenLibBook` lässt sich im Service Binding `ZALM_LB_UI_LIBRARY_O4` direkt als Fiori-Elements-V4-List-Report öffnen, durchsuchen und filtern.

**Was zu tun ist:**

1. **Metadata Extension `ZALM_LB_CE_OpenLibBook` (`@Metadata.layer: #CORE`):**
   - `@UI.headerInfo`: `typeName: 'OpenLibrary-Treffer'`, `typeNamePlural: 'OpenLibrary-Treffer'`, `title.value: 'Title'`, `description.value: 'Author'`, `imageUrl: 'CoverUrl'`.
   - `@UI.selectionField` auf `Title`, `Author`, `Isbn`.
   - `@UI.lineItem` mit `CoverUrl` (Vorschaubild), `Title`, `Author`, `PublishYear`, `Isbn`, `OpenLibKey`, `SourceMode`.
2. **Test im Service Binding `ZALM_LB_UI_LIBRARY_O4`:**
   - Service Binding ggf. aktualisieren und *Preview* auf **`OpenLibBook`** starten.
   - Suche über die Suchleiste (`Clean Code`, `ABAP`) und gezielte Filter (`Author`, `Isbn`) prüfen.

**Checkliste `LB-17`:**
- [ ] *Preview* auf `OpenLibBook` zeigt Trefferliste inkl. Buchcovern und `SourceMode` (`LIVE` oder `FALLBACK`)
- [ ] Suche über Suchfeld und Filter funktioniert ohne OData-Fehler

---

### `LB-18` · 1-Klick-Import-Action `importFromOpenLib` ins eigene `Book`-BO

> „Wenn ich in der OpenLibrary-Trefferliste ein passendes Buch sehe, möchte ich auf ‚In Bibliothek übernehmen‘ klicken – und das Buch landet sofort mit automatischer `MED-xxxx` in unserem eigenen Bestand (ohne doppelte ISBNs anzulegen).“

**Was zu tun ist:**

1. **Behavior Definition auf der Custom Entity `ZALM_LB_CE_OpenLibBook` anlegen:**
   - Da `ZALM_LB_CE_OpenLibBook` keine DB-Tabelle hat, nutzt du eine **`unmanaged`** Behavior Definition (`strict ( 2 );` – **ohne** `with draft;` und **ohne** `create; update; delete;`):
     ```abap
     unmanaged implementation in class zbp_alm_lb_ce_openlib unique;
     strict ( 2 );

     define behavior for ZALM_LB_CE_OpenLibBook alias OpenLibBook
     lock master
     authorization master ( global )
     {
       field ( readonly ) OpenLibKey;
       action importFromOpenLib result [1] $self;
     }
     ```
   - *(Hinweis: Falls auf 7.58 bei `unmanaged` auf Custom Entity `etag` oder `authorization` syntaktisch angepasst werden muss, direkt mit Syntax-Check prüfen.)*

2. **Behavior Pool `ZBP_ALM_LB_CE_OPENLIB` implementieren:**
   - `get_global_authorizations`: Action `importFromOpenLib` erlauben (`%action-importFromOpenLib = if_abap_behv=>auth-allowed`).
   - `importFromOpenLib`:
     - Da Custom Entities keinen `READ ENTITIES`-Puffer besitzen, holt die Methode zu den `OpenLibKey`s aus `keys` die Buchdaten über `ZCL_ALM_LB_OPENLIB_QRY` (z. B. wiederverwendbare Methode `get_book_by_key( lv_key )`).
     - **Dubletten-Prüfung:** Prüft in `ZALM_LB_BOOK` (falls `Isbn` gefüllt), ob bereits ein Buch mit dieser `Isbn` existiert → wenn ja, sauber per `failed-openlibbook` & `reported-openlibbook` mit Meldung aus `ZALM_LB_MSG` ablehnen.
     - **EML-Anlage im eigenen BO:**
       ```abap
       MODIFY ENTITIES OF zalm_lb_i_book
         ENTITY Book
           CREATE FIELDS ( Title Author Isbn Category PublishYear CoverUrl
                           TotalCopies Price CurrencyCode IsArchived )
           WITH VALUE #( ( %cid         = |IMP_{ sy-tabix }|
                           Title        = ls_ol-Title
                           Author       = ls_ol-Author
                           Isbn         = ls_ol-Isbn
                           Category     = 'TECH'
                           PublishYear  = ls_ol-PublishYear
                           CoverUrl     = ls_ol-CoverUrl
                           TotalCopies  = 1
                           Price        = '0.00'
                           CurrencyCode = 'EUR'
                           IsArchived   = abap_false ) )
         MAPPED   DATA(lt_book_mapped)
         FAILED   DATA(lt_book_failed)
         REPORTED DATA(lt_book_reported).
       ```
       *(Hinweis: Da `importFromOpenLib` innerhalb eines fremden BO-Handlers läuft, **darf** sie kein `COMMIT ENTITIES` selbst aufrufen, wenn der OData-Request den Save übernimmt – Achtung: Bei einem `unmanaged`-BO ohne eigene Saver-Persistenz für `Book` muss die `Book`-Änderung im selben LUW-Save mitgesichert werden! Alternativ kann `ZBP_ALM_LB_CE_OPENLIB` prüfen, ob `SAVE` automatisch läuft – das testen wir direkt gemeinsam in `LB-18`!)*
     - Gibt das `OpenLibBook` in `result` zurück und meldet eine Erfolgsmeldung (`severity-success`, z. B. *„Buch '<Titel>' wurde in die Bibliothek übernommen.“*) in `reported-openlibbook`.

3. **UI-Button & Test:**
   - In `ZALM_LB_CE_OpenLibBook` (`DDLX`) den Button `{ type: #FOR_ACTION, dataAction: 'importFromOpenLib', label: 'In Bibliothek übernehmen' }` in `@UI.lineItem` platzieren.
   - Im UI-Preview testen: Treffer markieren → **„In Bibliothek übernehmen“** klicken → in `Book` prüfen, dass das neue Buch mit neuer `MED-xxxx` angelegt wurde, und zweiter Klick auf dieselbe ISBN sauber abgelehnt wird.

**Checkliste `LB-18`:**
- [x] BDEF `ZALM_LB_CE_OpenLibBook` und Behavior Pool `ZBP_ALM_LB_CE_OPENLIBBOOK` sind aktiv
- [x] Klick auf **„In Bibliothek übernehmen“** legt das Buch per EML in `ZALM_LB_BOOK` (mit neuer `MED-xxxx`) an
- [x] Doppelter Import derselben ISBN wird sauber abgefangen

---

### `LB-18b` *(Optional)* · Echte Berechtigungsprüfung für `importFromOpenLib` (`SU21` + `PFCG`)

> „Nicht jeder Nutzer soll einfach neue Bücher aus OpenLibrary in unseren Bestand importieren dürfen — das soll nur Bibliothekarinnen mit der entsprechenden Berechtigung erlaubt sein.“

**Was zu tun ist:**

1. **Berechtigungsobjekt anlegen (`SU21` in SAP GUI):**
   - Objektklasse `ZALM` (falls noch nicht vorhanden) und Berechtigungsobjekt **`ZALM_LB_OL`** mit dem Standardfeld **`ACTVT`** (erlaubte Aktivität: `01` = Hinzufügen/Anlegen) anlegen.
2. **Prüfung in `ZBP_ALM_LB_CE_OPENLIBBOOK~get_global_authorizations`:**
   - Prüfen, ob `requested_authorizations-%action-importFromOpenLib = if_abap_behv=>mk-on`, dann `AUTHORITY-CHECK OBJECT 'ZALM_LB_OL' ID 'ACTVT' FIELD '01'.` ausführen und `if_abap_behv=>auth-allowed` bzw. `auth-unauthorized` zurückgeben.
3. **Rolle pflegen & zuweisen (`PFCG`):**
   - Rolle **`Z_ALM_LB_LIBRARIAN`** anlegen, Objekt `ZALM_LB_OL` mit `ACTVT = '01'` hinzufügen, generieren und deinem User zuweisen.
   - *(Hinweis: Falls dein Entwickleruser `SAP_ALL` besitzt, greift der Negativ-Test ohne Rolle nicht — in dem Fall zum Testen mit einem Testuser ohne `SAP_ALL` prüfen oder im Debugger `sy-subrc` prüfen.)*

**Checkliste `LB-18b`:**
- [ ] Berechtigungsobjekt `ZALM_LB_OL` (`ACTVT = '01'`) ist in `SU21` angelegt
- [ ] `get_global_authorizations` prüft `AUTHORITY-CHECK OBJECT 'ZALM_LB_OL'`
- [ ] Rolle `Z_ALM_LB_LIBRARIAN` ist in `PFCG` generiert und zugewiesen; Positiv-/Negativfall getestet

---

## Stufe E — Fiori Elements V4 Showcase (Backend & lokale App)

> Ziel von **Stufe E**: Aus einem soliden RAP-Backend eine echte **Fiori Elements V4 Showcase-App** machen — erst über reine CDS/DDLX-Annotationen im Backend (`LB-19` & `LB-20`, direkt im ADT-Preview testbar), und danach als **generierte lokale Fiori-V4-App** mit Flexible Column Layout, Inline-Creation und OpenLibrary-Integration (`LB-21` bis `LB-23`).

---

### `LB-19` · Fiori Elements V4 Visuals: `#RATING`-Sterne, Header-DataPoints & `#AS_CONTACT`

> „Bewertungen sollen in der Bücherliste und auf der Object Page als echte 5-Sterne-Leiste statt als nackte Dezimalzahl erscheinen. Und bei jeder Ausleihe oder Bewertung möchte ich direkt auf den Mitgliedsnamen klicken können, um eine Kontaktkarte mit E-Mail, Abteilung und Avatar zu sehen.“

**Was zu tun ist:**

1. **5-Sterne-Bewertung (`#RATING`) in `ZALM_LB_C_Book` und `ZALM_LB_C_REVIEW` (`DDLX`):**
   - Auf `AvgRating` (in `Book`) bzw. `Rating` (in `Review`) einen `@UI.dataPoint` definieren:
     ```abap
     @UI.dataPoint: {
       qualifier: 'AvgRatingDP',
       title: 'Durchschnittsbewertung',
       targetValue: 5,
       visualization: #RATING
     }
     ```
   - In `@UI.lineItem` als `{ position: ..., type: #AS_DATAPOINT, valueQualifier: 'AvgRatingDP' }` einbinden (analog `Rating` in `ZALM_LB_C_REVIEW`).
   - Im Object-Page-Header von `Book` über `@UI.facet` (`purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'AvgRatingDP'`) prominent anzeigen.

2. **Kontaktkarte (`#AS_CONTACT`) für Mitglieder (`ZALM_LB_I_MEMBER` / `ZALM_LB_C_MEMBER`):**
   - Im Member-CDS-View (`ZALM_LB_I_MEMBER` / `ZALM_LB_C_MEMBER`) das Semantik-Mapping für VCard/Kontaktkarte ergänzen:
     - `@Semantics.name.fullName: true` auf `FullName`
     - `@Semantics.eMail.address: true` auf `Email`
     - `@Semantics.organization.name: true` (bzw. `role`) auf `Department`
     - `@Communication.Contact` (falls auf 7.58 nötig) bzw. `@ObjectModel.semanticKey` / `@Semantics.imageUrl: true` auf `AvatarUrl`.
   - In `ZALM_LB_C_LOAN` und `ZALM_LB_C_REVIEW` (`DDLX`) eine Spalte/Feldgruppe mit `{ type: #AS_CONTACT, value: '_Member', label: 'Mitglied' }` in `@UI.lineItem` und `@UI.identification` platzieren.

**Checkliste `LB-19`:**
- [ ] `AvgRating` erscheint im `Book`-List-Report, im Object-Page-Header und in `Review` als 5-Sterne-Visualisierung
- [ ] Klick auf ein Mitglied in `Loan` oder `Review` öffnet die Fiori-Kontaktkarte mit Name, E-Mail & Abteilung

---

### `LB-20` · Bestandsauslastung als Radial/Harvey Micro Chart & Multi-View-Tabs

> „Im Buch-Header und in der Liste möchte ich auf einen Blick sehen, wie viele Exemplare ausgeliehen bzw. noch verfügbar sind (Fortschritts-/Kreisdiagramm). Außerdem soll die Bücherliste oben Tabs für ‚Alle Bücher‘, ‚Sofort verfügbar‘ und ‚Archiviert‘ anbieten.“

**Was zu tun ist:**

1. **Radial/Harvey Micro Chart für Bestandsauslastung (`Book`):**
   - In `ZALM_LB_C_Book` (`DDLX`) ein `@UI.dataPoint` auf `AvailCopies` mit `targetValueElement: 'TotalCopies'` und `criticalityCalculation` (z. B. grün bei > 0, rot bei 0) definieren:
     ```abap
     @UI.chart: [{
       qualifier: 'StockChart',
       title: 'Bestandsverfügbarkeit',
       chartType: #DONUT,
       measures: ['AvailCopies'],
       measureAttributes: [{ measure: 'AvailCopies', role: #AXIS_1, asDataPoint: true }]
     }]
     ```
     *(Alternativ `@UI.dataPoint` mit `visualization: #PROGRESS` als schneller Einstieg, dann `#DONUT` / Radial-Chart über `@UI.facet: [{ purpose: #HEADER, type: #CHART_REFERENCE, targetQualifier: 'StockChart' }]`.)*
   - In `@UI.lineItem` optional zusätzlich als `{ type: #AS_CHART, valueQualifier: 'StockChart' }` testen.

2. **Multi-View-Tabs im List Report (`@UI.selectionPresentationVariant`):**
   - In `ZALM_LB_C_Book` (`DDLX` / Header-Annotationen) zwei bis drei `@UI.selectionVariant`-/`@UI.presentationVariant`-Kombinationen definieren:
     - **Tab 1 (`AllBooks`):** Alle nicht archivierten Bücher (`IsArchived = false`)
     - **Tab 2 (`AvailableBooks`):** Nur sofort verfügbare Bücher (`AvailCopies > 0` & `IsArchived = false`)
     - **Tab 3 (`ArchivedBooks`):** Archivierte Bücher (`IsArchived = true`)
   - *(Hinweis: In ABAP 7.58 werden Multi-View-Tabs im ADT-Preview teils erst in der generierten Fiori-V4-App über `manifest.json` (`views.paths`) voll sichtbar — die Backend-Annotationen bereiten die Variants sauber vor!)*

**Checkliste `LB-20`:**
- [ ] Bestandsauslastung (`AvailCopies` / `TotalCopies`) wird im Object-Page-Header als Micro Chart / Progress angezeigt
- [ ] Selection-Variants für *Alle*, *Verfügbar* und *Archiviert* sind definiert und im Service aktiv

---

### `LB-21` · Lokale Fiori-Elements-V4-App generieren & Flexible Column Layout (FCL)

> „Wir wollen unsere Bibliotheks-App nicht nur im ADT-Service-Preview testen, sondern als echte lokale SAP-Fiori-Elements-V4-App (mit Flexible Column Layout: Liste links, Buch-Detail in der Mitte, Ausleihe/Review rechts) starten.“

**Was zu tun ist:**

1. **App mit SAP Fiori Tools (VS Code) generieren:**
   - Template: **SAP Fiori Elements → List Report Page (OData V4)**
   - Datenquelle: euer Service Binding `ZALM_LB_UI_BOOK_O4`
   - Main Entity: `Book` (Navigation Entity: `_Loan` oder `_Review`)
2. **Flexible Column Layout (FCL) in `webapp/manifest.json` aktivieren:**
   - Unter `sap.ui5.routing.config`:
     ```json
     "flexibleColumnLayout": {
       "defaultTwoColumnLayoutType": "TwoColumnsMidExpanded",
       "defaultThreeColumnLayoutType": "ThreeColumnsEndExpanded"
     }
     ```
   - `fclEnabled: true` setzen und prüfen, dass das Klicken auf ein Buch die Object Page in der mittleren Spalte öffnet und Klick auf eine Ausleihe/Bewertung die dritte Spalte öffnet.
3. **Multi-View-Tabs im `manifest.json` einhängen (falls in `LB-20` als Variants angelegt):**
   - Unter `BookList` → `controlConfiguration` → `views` die `selectionPresentationVariant`-Qualifier (`AllBooks`, `AvailableBooks`, `ArchivedBooks`) eintragen.

**Checkliste `LB-21`:**
- [ ] Lokale Fiori-V4-App startet per `npm start` gegen `ZALM_LB_UI_BOOK_O4`
- [ ] Flexible Column Layout öffnet Liste, Buch-Object-Page und Kind-Object-Page mehrspaltig nebeneinander

---

### `LB-22` · Inline-Creation in Kind-Tabellen (`_Loan` / `_Review`)

> „Neue Bewertungen sollen Nutzer direkt als neue Zeile in der Review-Tabelle eintippen können, ohne dass sich jedes Mal eine eigene Sub-Object-Page öffnet.“

**Was zu tun ist:**

1. In `webapp/manifest.json` auf der `BookObjectPage` unter `controlConfiguration`:
   - Für `@com.sap.vocabularies.UI.v1.LineItem` der `_Review`-Tabelle:
     ```json
     "tableSettings": {
       "creationMode": {
         "name": "Inline"
       }
     }
     ```
2. Im UI testen: Buch in den Bearbeitungsmodus (*Edit*) schalten → in der Review-Tabelle auf *Create* klicken → Bewertung erscheint sofort als editierbare Inline-Zeile, inkl. Live-Aktualisierung von `AvgRating` beim Speichern.

**Checkliste `LB-22`:**
- [ ] Neue Reviews lassen sich direkt inline in der Tabelle erfassen und speichern
- [ ] `lendBook`-Action und manuelles Anlegen funktionieren weiterhin sauber nebeneinander

---

### `LB-23` · OpenLibrary-Suche in die Fiori-V4-App integrieren (Custom Section / List-Page)

> „Unsere Bibliothekarinnen sollen die OpenLibrary-Suche und den ‚In Bibliothek übernehmen‘-Button nicht in einem separaten Preview öffnen müssen, sondern direkt aus unserer Fiori-App heraus aufrufen können.“

**Was zu tun ist:**

1. **Einbindung in `manifest.json`:**
   - `OpenLibBook` als zusätzliche `ListReport`-Route / Seite in der App (oder als Custom Page / Custom Section mit `sap.ui.core.mvc.View` + `sap.fe.macros.Table`) registrieren.
2. **Nahtloser Rücksprung & Refresh:**
   - Nach erfolgreichem `importFromOpenLib` soll beim Wechsel zurück auf die `Book`-Liste das neu importierte Buch (`MED-xxxx`) direkt sichtbar sein.

**Checkliste `LB-23`:**
- [ ] OpenLibrary-Suche ist direkt innerhalb der generierten Fiori-V4-App erreichbar
- [ ] Import eines Buchs per `importFromOpenLib` aus der App heraus legt `MED-xxxx` an und zeigt es in der `Book`-Liste

---

## Fortschritt

| Paket | Thema | Status |
|---|---|:--:|
| `LB-01` | Paket & CDS Simple Types (`DRTY`) | ☑ |
| `LB-02` | 5 Datenbanktabellen & F9-Demodaten (`ZCL_ALM_LB_FILL_DATA`) | ☑ |
| `LB-03` | Interface-Views (`I_`) mit Simple-Type-Casts & Kompositionen | ☑ |
| `LB-04` | Basis-BDEF (`managed; strict ( 2 ); with draft;`) & Draft-Tabellen | ☑ |
| `LB-05` | Projection-Views (`C_`), Wertehilfen & Projection-BDEF | ☑ |
| `LB-06` | Metadata Extensions (`DDLX`), Service & OData-V4-Preview | ☑ |
| `LB-07` | Nachrichtenklasse `ZALM_LB_MSG` & RAP-Exception `ZCM_ALM_LB` | ☑ |
| `LB-08` | Determinations für automatische Nummern & Standardwerte | ☑ |
| `LB-09` | Cross-Entity-Determinations (Live-Bestand & Schnitt-Bewertung) | ☑ |
| `LB-10` | Validierungen & Draft `Prepare` | ☑ |
| `LB-11` | OData V4 Side Effects (Live-Aktualisierung im Browser) | ☑ |
| `LB-12` | Loan-Lifecycle-Actions: `returnBook` & `extendLoan` | ☑ |
| `LB-13` | Ausleih-Dialog vom Buch aus: `lendBook` + Backend-Defaulting (7.58) | ☑ |
| `LB-14` | Dynamisches Feature Control (`get_instance_features`) | ☑ |
| `LB-15` | Factory Action `duplicateBook`, Function `getLibraryKpis` & EML-Tests | ☑ |
| `LB-16` | Custom Entity `ZALM_LB_CE_OpenLibBook` & `IF_RAP_QUERY_PROVIDER` (HTTP + Fallback) | ☑ |
| `LB-17` | Custom Entity UI (`DDLX`) & OData-V4-Preview (`OpenLibBook`) | ☑ |
| `LB-18` | 1-Klick-Import-Action `importFromOpenLib` ins eigene `Book`-BO | ☑ |
| `LB-18b` | *(Optional)* Echte Berechtigungsprüfung für `importFromOpenLib` (`SU21` + `PFCG`) | ☐ |
| `LB-19` | Fiori Elements V4 Visuals (`#RATING`, Header-DataPoint, `#AS_CONTACT`) | ☐ |
| `LB-20` | Bestandsauslastung (Radial/Harvey Micro Chart) & Multi-View-Tabs | ☐ |
| `LB-21` | Lokale Fiori-V4-App generieren & Flexible Column Layout (FCL) | ☐ |
| `LB-22` | Inline-Creation in Kind-Tabellen (`_Review` / `_Loan`) | ☐ |
| `LB-23` | OpenLibrary-Suche direkt in der Fiori-V4-App integrieren | ☐ |


