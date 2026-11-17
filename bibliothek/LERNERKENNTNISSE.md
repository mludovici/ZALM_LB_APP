# Lernerkenntnisse & Architektur-Spickzettel (`ZALM_LB_APP`)

Dieses Dokument dient als fortlaufendes Nachschlagewerk für praxisnahe Erkenntnisse, Architektur-Entscheidungen und typische SAP/RAP-Stolpersteine, die während der Entwicklung des Projekts auftreten. Neue Erkenntnisse werden hier thematisch angehängt.

---

## 1. Datenbanktabellen (`define table`) & DDIC

### 1.1 Mandantenfeld `MANDT`: Wann hinschreiben, wann weglassen?
* **In der Datenbanktabelle (`define table` / `TABL`):**
  * **MUSS** als erstes Schlüsselfeld stehen: `key mandt : mandt not null;`.
  * Fehlt das Feld, wird die Tabelle **mandantenunabhängig** (cross-client / systemweit). In 99 % aller Anwendungsfälle (speziell RAP-Geschäftsobjekte) ist das ein schwerer Design- und Sicherheitsfehler, da Daten mandantenübergreifend vermischt/überschrieben würden.
* **In CDS View Entities (`define [root] view entity`):**
  * **DARF NICHT** in der Feldliste vorkommen!
  * CDS View Entities besitzen implizites Client-Handling (*Implicit Client Handling*). Das Hinzufügen von `mandt` führt zu einem Compilerfehler (`A client field is not allowed in a CDS view entity`).
* **In ABAP SQL (`SELECT ... FROM`):**
  * Wird automatisch auf `sy-mandt` gefiltert, muss nicht manuell im `WHERE` angegeben werden.

---

### 1.2 Währungs- und Mengenfelder: Warum `@Semantics.amount.currencyCode` schon in `define table`?
* **Die technische DDIC-Pflicht:**
  * Im SAP Dictionary darf kein Betragsfeld (`CURR` / `abap.curr`) ohne zugehörigen Währungsschlüssel (`CUKY` / `abap.cuky`) existieren, da das Speicherformat von der Währung abhängt (z. B. JPY = 0 Dezimalstellen, EUR = 2, KWD = 3).
  * In der klassischen `SE11` war das der Reiter *„Währ./Mengenfelder“*. Im codebasierten DDL-Editor für Tabellen (`define table`) wird diese Pflichtbindung über die Annotation `@Semantics.amount.currencyCode : 'zalm_lb_book.currency_code'` deklariert.
  * **Ohne diese Annotation lässt sich die Tabelle in ADT nicht aktivieren.**
* **Abgrenzung zum CDS View (`I_` / `C_`):**
  * Im Interface-View schreibt man `@Semantics.amount.currencyCode: 'CurrencyCode'` erneut.
  * **Zweck dort:** Signal an das **RAP- & OData-Framework**, damit Fiori Elements den Betrag in der UI korrekt mit Währungssymbol formatiert darstellt (z. B. `19,99 €`).

---

### 1.3 Datentypen in `define table` vs. CDS Simple Types (`DRTY`)
* **In `define table`:**
  * Auf SAP NetWeaver / ABAP 7.58 akzeptiert der Tabellencompiler **keine** CDS Simple Types (`DRTY`).
  * In Tabellen verwendet man ausschließlich **Built-in-Typen** (`abap.char(...)`, `abap.int2`, `abap.dats`, `abap.curr(...)`, `abap.cuky`, `abap.sstring(500)`, `abap.rawstring(0)`) oder Standard-Datenelemente für technische Zwecke (`sysuuid_x16`, `abap_boolean`, `abp_creation_tstmpl`, ...).
  * **Boolesche Felder:** Das korrekte Standard-Datenelement heißt `abap_boolean` (Paket `SABP_COMMON`). Ein `abp_boolean` existiert im System nicht.
  * **Spaltenbezeichner in SE11 / DB-Viewer:** Bei reinen Built-in-Typen hat das Feld im DDIC keine Feldbezeichner (Kurz/Mittel/Lang), sondern nur den technischen Namen. Das ist im modernen CDS-Ansatz beabsichtigt: Alle Texte kommen aus den Simple Types (`DRTY`) oder CDS-Annotationen (`@EndUserText.label`).
* **Im CDS Interface View (`I_`):**
  * Hier erfolgt das semantische Upgrade per `cast( db_feld as ZALM_LB_T_... preserving type ) as FeldName`. Erst hier greifen Texte, Tooltips und Großschreibungsregeln (`@ObjectModel.upperCase`).

---

### 1.4 RAP-Adminfelder: Warum Einzelfelder statt Struktur-Include?
* **Auf der aktiven Tabelle (`ZALM_LB_BOOK` etc.):**
  * Werden die 5 Felder (`created_by`, `created_at`, `local_last_changed_by`, `local_last_changed_at`, `last_changed_at`) **explizit als Einzelfelder** definiert.
  * **Grund 1 (Unterschied Root vs. Child):** Das Root-Objekt benötigt alle 5 Felder für Lifecycle & Gesamt-ETag. Kind-Objekte (`Loan`, `Review`) benötigen jedoch in der Regel **nur ein einziges Feld**: `local_last_changed_at` (für den lokalen ETag des Kindes). Ein pauschales Struktur-Include würde auf Kind-Tabellen unnötige redundante Spalten erzwingen.
  * **Grund 2 (BDEF-Mapping):** In der Behavior Definition (`BDEF`) und im CDS View werden die Felder explizit per `mapping for` zugeordnet (z. B. `CreatedAt = created_at;`). Eindeutige, standardisierte Spaltennamen ohne Include-Präfixe sind hier der sauberste SAP-Best-Practice.
* **Auf der Draft-Tabelle (`ZALM_LB_D_*`):**
  * Hier gibt es tatsächlich einen Standard-Include: `include sych_bdl_draft_admin_inc;` (bzw. `%admin;`).
  * Dieser Include wird vom ADT-Quickfix (*"Add draft table"*) automatisch eingefügt und verwaltet die technischen Draft-Zustände (`draftentitycreationdatetime`, `draftadministrativestatus`, etc.).

---

## 2. RAP-Datenmodell & Transaktionsverwaltung

### 2.1 Persistente vs. rein berechnete Felder (am Beispiel `avail_copies`)
* **Warum ist `avail_copies` ein Feld in der DB-Tabelle, obwohl es berechnet wird?**
  1. **Performance & OData V4 Filter:** Fiori-List-Reports können in der Datenbank direkt per SQL filtern (`WHERE avail_copies > 0`), sortieren und aggregieren.
  2. **Einfache Selektion:** Externe Reports und Interfaces können den aktuellen Bestand direkt aus der Tabelle lesen, ohne komplexe Subqueries ausführen zu müssen.
* **Gegenüberstellung: Virtuelle Felder (Virtual Elements):**
  * Felder, die rein im CDS View über Berechnungen oder ABAP-Klassen (`@ObjectModel.virtualElementCalculator`) ermittelt werden, sparen zwar redundanten Speicherplatz, können in OData V4 aber **nicht nativ über die DB gefiltert oder sortiert** werden.
* **RAP-Muster:** Die Konsistenz von persistenten Rechenfeldern wird über **Cross-Entity-Determinations** (`on save` / `on modify`) sichergestellt (z. B. Leihe geändert → Buch-Bestand neu berechnen).

---

### 2.2 Statusverwaltung: Lookup-Tabelle vs. Domänenfestwerte / CDS Enum
* **Warum eine eigene Tabelle `ZALM_LB_LSTATUS` statt Domänen-Festwerten?**
  1. **Fachliche Logikfelder:** Neben Code und Text enthält die Tabelle Steuerungsattribute wie `is_active_loan` (steuert Bestandsminderung) und `criticality` (liefert `1/2/3` für die Fiori-Ampelfarbe). Mit Festwerten müsste dies im ABAP-Code redundant hartcodiert werden.
  2. **Status auf Release 7.58:** CDS Enums (`define type ... enum`) existieren zwar auf 7.58, werden von RAP/OData auf diesem Release aber noch nicht als Dropdown/Wertehilfe unterstützt.
  3. **Standard-Muster:** Eine schlanke Lookup-Tabelle mit Interface-View (`@ObjectModel.resultSet.sizeCategory: #XS`) ist der empfohlene Weg für Dropdown-Listen in Fiori Elements V4.

---

### 2.3 ETags, Concurrency & Schutz vor Race Conditions ("Lost Updates")
* **Das Problem ohne ETag:**  
  Benutzer A und B öffnen denselben Datensatz. Beide ändern unterschiedliche Felder und speichern nacheinander. Der letzte Speicherbefehl überschreibt blind die Änderungen des ersten (*Lost Update*).
* **Wie ETags Race Conditions verhindern (HTTP `If-Match` & Optimistic Concurrency Control):**
  1. Beim Lesen (GET) sendet das SAP-System den ETag (den exakten Zeitstempel `LocalLastChangedAt`) im HTTP-Header `ETag: W/"..."` an den Browser.
  2. Beim Speichern (PUT/PATCH) sendet der Browser diesen Zeitstempel im Header `If-Match` mit.
  3. Das Backend prüft per SQL, ob der Zeitstempel auf der DB noch identisch ist:
     * **Identisch:** Änderung wird geschrieben, Zeitstempel aktualisiert.
     * **Abgewichen:** Abbruch mit **HTTP 412 (Precondition Failed)** $\rightarrow$ Fiori meldet: *„Daten wurden zwischenzeitlich von einem anderen Benutzer geändert.“*
* **Unterschied `LocalLastChangedAt` vs. `LastChangedAt` (Total ETag):**
  * **`LocalLastChangedAt` (Lokaler ETag):** Schützt die **einzelne Zeile/Instanz** (z. B. wenn zwei Bibliothekare gleichzeitig dieselbe Ausleihe bearbeiten).
  * **`LastChangedAt` (Total ETag auf dem Root-Objekt):** Schützt das **gesamte Aggregat** (Root + alle Kinder) im **Draft-Modus**.
    * Ein Draft merkt sich den aktiven Total ETag bei Erstellung.
    * Wird im Produktivzustand ein Kind geändert (z. B. Ausleihe zurückgegeben), zieht das RAP-Framework automatisch per SQL-Update den `LastChangedAt` am Root-Buch nach.
    * Beim späteren Aktivieren eines alten Drafts schlägt die Prüfung fehl, da sich der Total ETag auf der DB verändert hat.

---

### 2.4 Berechnete & gejointe Felder in Managed RAP (`field ( readonly )` & BDEF-Mapping)
* **Die Frage:** Wenn ich im CDS-View berechnete Felder (`concat(...) as FullName`) oder Pfadausdrücke (`_Status.status_text as StatusText`) habe, reicht es dann, sie im `mapping for` einfach wegzulassen, damit sie nicht in die DB geschrieben werden?
* **Die Antwort: NEIN, Weglassen allein führt zu einem Compilerfehler!**
  * In RAP ist jedes Element einer Entität standardmäßig **änderbar (`create / update`)**.
  * Fehlt ein änderbares Feld im `mapping for`, wirft der BDEF-Compiler einen Fehler (*„Element X is not mapped to a persistent field"* / ATC W303), weil Managed RAP nicht weiß, in welche Tabellenspalte eine eventuelle UI-Änderung geschrieben werden soll.
* **Die goldene Managed-RAP-Regel:**
  * Jedes Feld im CDS-View, das **keine physische Entsprechung in der DB-Tabelle hat**, **MUSS zwingend als `field ( readonly )` deklariert werden!**
  * Erst durch die Kombination aus `field ( readonly ) MyField;` und dem Weglassen im `mapping for` weiß die Persistenz-Engine:
    1. Der Client/Fiori darf das Feld nicht manipulieren.
    2. Beim Speichern (`INSERT`/`UPDATE`) wird das Feld vollständig ignoriert.
* **Warum `corresponding { }` bei Unterstrichen versagt:**
  * `mapping for ... corresponding` ordnet nur Felder mit identischer Schreibweise zu (ignoriert Groß-/Kleinschreibung).
  * Es ignoriert jedoch **keine Unterstriche**: `book_id` in der DB und `BookId` im CDS gelten als völlig unterschiedlich. Ohne explizites Mapping (`BookId = book_id;`) bleiben diese Spalten beim Speichern auf der Datenbank leer.

---

## 3. CDS View Entities & VDM-Architektur

### 3.1 Das CDS VDM-Schichtenmodell: `R_` vs. `I_` vs. `C_` Views & BDEF-Verortung
* **Rollenverteilung im 3-Stufen-Modell (SAP S/4HANA Standard & ABAP Cloud):**
  * **`R_` (Restricted / Base Entity):** Private Werkstatt des BO-Entwicklers. Liegt direkt auf der DB-Tabelle, enthält alle Felder (auch interne Steuerfelder) und die vollständige Logik. Hier liegt die **Basis-BDEF** (`managed implementation ... with draft`).
  * **`I_` (Transactional Interface):** **Das offizielle, stabile API nach außen** (`as projection on R_...`). Exponiert nur freigegebene Felder/Assoziationen für Fremdmodule/EML. Hier liegt die **Interface-BDEF** (`interface; define behavior for ... use action;`). Schützt Aufrufer vor internen Refactorings an der DB-Tabelle.
  * **`C_` (Consumption / Projection Entity):** Spezialisiert für eine konkrete UI/App (`as projection on R_...` oder `I_...`). Hier liegt die **Projektions-BDEF** (`projection; use draft;`).
* **Warum reicht im Projekt `bibliothek` das 2-Stufen-Modell (`I_` $\rightarrow$ `C_`)?**
  * Für in sich geschlossene Fiori-Apps ohne externe EML-Aufrufer oder `C1`-Freigabeverträge spart man sich die zusätzliche Zwischenschicht.
  * Die **Basis-BDEF** liegt direkt auf `ZALM_LB_I_Book`, die **Projektions-BDEF** auf `ZALM_LB_C_Book`.

---

### 3.2 CDS Simple Types Cast & `preserving type`
* **Zweck:** In der DB-Tabelle stehen nackte Typen (`abap.char(10)`). Im Interface-View erfolgt das semantische Upgrade:
  ```abap
  cast( book_id as ZALM_LB_T_BookId preserving type ) as BookId,
  ```
* **Was bringt das?**
  * Automatisches Erben aller Bezeichner, Tooltips (`@EndUserText.*`) und Großschreibungsregeln (`@ObjectModel.upperCase`) in Fiori, ohne Redundanz.
* **Was bedeutet `preserving type`?**
  * Signal an den Compiler: Das physische DB-Format ist identisch.
  * Die HANA-Datenbank führt **keine** SQL-Konvertierungsfunktion aus $\rightarrow$ **0 % Performance-Overhead**, reine Metadaten-Veredelung.

---

### 3.3 Wort-Kardinalitätssyntax ab Release 7.58 (`of ... to ...`)
* **Hintergrund:** In der alten Klammerschreibweise `[0..1]` fehlte die Angabe über die Quell-Kardinalität.
* **Der HANA-Optimizer-Vorteil:** Kennt die Datenbank die genaue Beziehung (z. B. `many to exact one` auf Lookups), kann sie **Join Pruning** durchführen: Wird kein Feld aus der Zieltabelle gelesen, fliegt der JOIN zur Laufzeit komplett aus dem SQL-Statement.
* **Wortschatz:** `one` (0..1), `exact one` (1..1, Pflicht), `many` (0..n).
* **Muster-Übersicht:**
  * Root $\rightarrow$ Child: `composition of exact one to many ZALM_LB_I_Loan as _Loan`
  * Child $\rightarrow$ Parent: `association to parent ZALM_LB_I_Book as _Book` (ohne Kardinalität)
  * Child $\rightarrow$ Lookup (Pflicht): `association of many to exact one ZALM_LB_I_LoanStatus as _Status`
  * Child $\rightarrow$ Stammdaten (optional): `association of many to one ZALM_LB_I_Member as _Member`

---

### 3.4 Annotations-Scopes: Was gehört in `I_`, was in `C_`, was in `DDLX`?
* **Die goldene Trennung:**
  * **`I_View` (Datenmodell & Framework-Steuerung):**  
    `@Semantics.*` (Währung, ETag/Admin-Felder, Mime-Types, Bild-URLs), `@AccessControl.*`. Gilt global für jeden Konsumenten. **Keine `@UI.*`-Annotationen hier!**
  * **`C_View` (Konsumenten-Verhalten):**  
    `@Consumption.valueHelpDefinition` (Wertehilfen für Fiori), `@ObjectModel.text.element` (Text-Zuordnungen für Dropdowns), Filtervorgaben.
  * **`DDLX` (Metadata Extension zur C-View):**  
    Reine Pixel und Bildschirmanordnung: `@UI.lineItem`, `@UI.facet`, `@UI.selectionField`, `@UI.fieldGroup`, `@UI.hidden`.

---

### 3.5 Lookups als Dropdown rendern mit `@ObjectModel.resultSet.sizeCategory: #XS`
* Am Lookup-View (`ZALM_LB_I_LoanStatus`) platziert.
* **Wirkung in Fiori Elements:**  
  Signalisiert dem Framework, dass die Ergebnismenge winzig ist (< 10–20 Zeilen). Fiori verzichtet auf das große Value-Help-Popup (Modal mit Suche/Paginierung) und rendert direkt eine schlanke **Dropdown-Liste (`sap.m.ComboBox`)**.

---

### 3.6 Large Objects (`@Semantics.largeObject`): PDF- & Datei-Uploads
* **Das Spalten-Trio in der Tabelle:**
  1. `sample_pdf : abap.rawstring(0);` (Binärdaten / Stream)
  2. `sample_mime : abap.char(128);` (MIME-Type, z. B. `application/pdf`)
  3. `sample_filename : abap.char(128);` (Dateiname, z. B. `leseprobe.pdf`)
* **Im Interface-View:**
  ```abap
  @Semantics.largeObject: {
    mimeType: 'SampleMime',
    fileName: 'SampleFilename',
    contentDispositionPreference: #INLINE,
    acceptableMimeTypes: [ 'application/pdf' ]
  }
  sample_pdf as SamplePdf,

  @Semantics.mimeType: true
  sample_mime as SampleMime,

  sample_filename as SampleFilename,
  ```
* **Funktionsweise in Fiori & OData V4:**
  * OData überträgt keine riesigen Base64-Strings im Standard-JSON, sondern exponiert ein `Edm.Stream` mit eigener Download-URL (`.../SamplePdf/$value`).
  * Der Browser entscheidet anhand des empfangenen HTTP-Headers `Content-Type: application/pdf`, wie er die Datei anzeigt (integrierter PDF-Viewer vs. Bild vs. Download).
  * **Automatisierung:** Der Benutzer muss weder Dateinamen noch MIME-Type eingeben. Der Browser liest beides beim Auswählen der Datei aus und sendet es im HTTP-Header mit. Im UI werden MIME-Type und Dateiname meist per `@UI.hidden: true` versteckt.
  * **Sicherheit:** `@Semantics.largeObject.acceptableMimeTypes` schränkt den Dateiauswahldialog im Frontend ein. Für absolute Sicherheit gehört zusätzlich eine RAP-Validation (`checkFileType on save`) ins Backend.

---

## 4. Projection-Views (`C_`), Fiori-Projektion & Wertehilfen

### 4.1 Transaktionale Grenze: Wer bekommt einen `C_`-View und wer nicht?
* **Die Faustregel:** Einen `C_`-View (und eine Projektions-BDEF) bekommen **nur die Entitäten, die zum transaktionalen Business Object (BO) gehören** – also Daten, die in dieser App angelegt, bearbeitet, gelöscht oder als Entwurf (Draft) gehalten werden (`Book`, `Loan`, `Review`).
* **Lookup- & Stammdaten-Provider (`Member`, `LoanStatus`):**
  * Werden in dieser App **nur lesend** als Wertehilfe oder Dropdown verwendet (wir pflegen in der Bibliotheks-App keine Mitarbeiterstammdaten).
  * Sie benötigen **weder einen `C_`-View noch eine BDEF**! Der Interface-View `ZALM_LB_I_MEMBER` reicht als Ziel für die Wertehilfe vollständig aus.

---

### 4.2 Zirkelbezug beim Anlegen von Projektions-Views (Aktivierungs-Blockade)
* **Das Problem:**  
  `C_Book` zeigt per Komposition auf `C_Loan` und `C_Review`. Gleichzeitig zeigen die Kinder per `_Book : redirected to parent C_Book` zurück. Kein View kann einzeln aktiviert werden, weil das jeweils referenzierte Objekt noch inaktiv ist.
* **Lösung 1 (Massenaktivierung):** In ADT `Strg + Umschalt + F3` drücken (*Activate Inactive ABAP Development Objects*), alle drei C-Views anhaken und gemeinsam aktivieren. Der DDIC-Compiler löst die Abhängigkeit in einem Durchlauf auf.
* **Lösung 2 (2-Schritt-Entkopplung):** In `C_Loan` und `C_Review` die Zeile `// _Book : redirected to parent...` kurz auskommentieren, Kinder aktivieren, Root aktivieren, Kommentar entfernen und Kinder erneut aktivieren.

---

### 4.3 `provider contract transactional_query`: Warum nur am Root-View?
* **Bedeutung:** Teilt dem Compiler und der RAP-Runtime mit: *„Diese Projektionsschicht ist die offizielle Schnittstelle für eine transaktionale Anwendung (Fiori Elements OData V4). Schalte alle RAP-Projektionsprüfungen (Draft, ETags, EML-Prüfungen) scharf.“*
* **Warum nur am Root?** Ein Business Object besitzt immer **genau einen Einstiegspunkt (den Root-Knoten)**. Der Vertrag gilt automatisch für den gesamten darunterliegenden Baum. An Kind-Projektionen ist der Zusatz verboten und führt zu einem Compilerfehler.

---

### 4.4 Währungsbindung in `C_Book` trotz `I_`-View: Die Auswirkung von `ignorePropagatedAnnotations`
* **Ursache:** Steht im Header des Views `@Metadata.ignorePropagatedAnnotations: true`, schaltet der CDS-Compiler die automatische Vererbung von Annotationen aus darunterliegenden Schichten (`I_Book`) **vollständig ab**.
* **Folge:** Das Betragsfeld `Price` verliert seine Währungsreferenz. Deshalb müssen `@Semantics.amount.currencyCode: 'CurrencyCode'` und `@Semantics.currencyCode: true` auf der Projektion erneut explizit deklariert werden.
* **OData V4 Serialisierung:** Der V4-Metadaten-Generator verlangt diese Bindung, um die Eigenschaft als `Edm.Decimal` mit dem Merkmal `@Org.OData.Measures.V1.ISOCurrency` im `$metadata`-XML für die UI5-Betragsformatierung bereitzustellen.

---

### 4.5 Wertehilfen (`@Consumption.valueHelpDefinition`) im Detail

#### A) Das Missverständnis mit `element:` (Rückgabewert vs. Anzeigetext)
* **`element:` bestimmt den Rückgabewert in die Datenbankspalte!**
  * Schreibt man an `MemberId` versehentlich `element: 'FullName'`, versucht Fiori den Text `Max Mustermann` in die 8-stellige ID-Spalte zu speichern $\rightarrow$ Datenverlust / Kürzung auf `Max Must` und Fremdschlüsselfehler.
  * **Richtige Trennung:**
    * **In DB speichern:** `element: 'MemberId'` $\rightarrow$ speichert den Fremdschlüssel `MEM-0001`.
    * **Auf UI anzeigen:** `@ObjectModel.text.element: ['MemberName']` $\rightarrow$ Fiori zeigt dem Anwender automatisch *„Max Mustermann (MEM-0001)“* an.

#### B) Warum Quell- und Zielfeld nicht immer gleich heißen
* In der Realität heißen Felder oft unterschiedlich:
  1. **Rollen auf derselben Entität:** Ein Beleg hat `BorrowerId` (Entleiher) und `ApprovedBy` (Genehmiger). Beide zeigen auf `ZALM_LB_I_MEMBER`. In `I_Member` gibt es aber nur `MemberId`. Ohne `element: 'MemberId'` wüsste das System nicht, welche Spalte aus `I_Member` gemeint ist.
  2. **SAP-Standards:** Dein Feld heißt `SupplierId`, in der Standard-Wertehilfe `I_Supplier` heißt das Feld jedoch `Supplier`.

#### C) Mehrere Felder mit einem Klick füllen (`additionalBinding`)
Eine Wertehilfe kann neben dem Primärschlüssel automatisch weitere abhängige Felder in das lokale Formular übernehmen:
```abap
@Consumption.valueHelpDefinition: [{ 
  entity: { name: 'ZALM_LB_I_MEMBER', element: 'MemberId' },
  additionalBinding: [
    { localElement: 'MemberEmail', element: 'Email' },
    { localElement: 'Department',  element: 'Department' }
  ]
}]
MemberId,
```
* `element: 'Email'` = Spalte in der Wertehilfe (`ZALM_LB_I_MEMBER`).
* `localElement: 'MemberEmail'` = Zielfeld in deinem aktuellen lokalen View.
* **Ergebnis:** Wählt der Benutzer ein Mitglied, füllt Fiori ID, Mail und Abteilung auf einen Schlag aus.

#### D) Automatische Validierung mit `useForValidation: true`
* Tippt der Benutzer einen Status (z. B. `XX`) manuell mit der Tastatur ein, statt das Dropdown zu öffnen, validiert das RAP-Framework den Wert beim Speichern automatisch gegen die Lookup-Tabelle.
* Existiert `XX` nicht, bricht RAP mit einer Fehlermeldung ab – **ohne eine einzige Zeile eigenen ABAP-Validierungscode**!

#### E) Suchannotationen (`@Search.*`) gehören an den Wertehilfe-Interface-View
* Da die Wertehilfe direkt auf `ZALM_LB_I_MEMBER` zeigt, müssen `@Search.searchable: true`, `@Search.defaultSearchElement: true` und `@Search.fuzzinessThreshold: 0.8` direkt an `ZALM_LB_I_MEMBER` stehen.
* Dadurch greift die Volltextsuche im Fiori-Wertehilfe-Popup sofort, und jede andere App, die `I_MEMBER` als Suchhilfe nutzt, profitiert automatisch davon.

---

## 5. UI Metadata Extensions (`DDLX`) & Fiori Elements Mentales Modell

### 5.1 Das 3-Ebenen-Mentale-Modell

Metadata Extensions wirken auf den ersten Blick überwältigend. 95 % aller Annotationen ordnen sich jedoch in drei klare, hierarchische Schichten ein:

```
┌────────────────────────────────────────────────────────┐
│ 1. Header (Kopf-Ebene)                                 │
│    @UI.headerInfo         → Titel, Untertitel, Bild    │
│    @UI.presentationVariant→ Standardsortierung         │
├────────────────────────────────────────────────────────┤
│ 2. Facetten (Das Inhaltsverzeichnis der Object Page!)  │
│    @UI.facet [                                         │
│      #IDENTIFICATION_REFERENCE → Standard-Formular     │
│      #FIELDGROUP_REFERENCE     → Flexible Feldgruppen  │
│      #LINEITEM_REFERENCE       → Kind-Tabellen         │
│      #COLLECTION               → Reiter / Abschnitte   │
│    ]                                                   │
├────────────────────────────────────────────────────────┤
│ 3. Felder (Wo taucht das einzelne Feld auf?)           │
│    @UI.selectionField → Oben im Such-/Filterbalken     │
│    @UI.lineItem       → Als Spalte in der Tabelle      │
│    @UI.identification → Im Standard-Formularblock      │
│    @UI.fieldGroup     → In einer benannten Gruppe      │
│    @UI.hidden: true   → Technisches Feld (UUID, ETag)  │
└────────────────────────────────────────────────────────┘
```

---

### 5.2 `@UI.headerInfo`: Die 3 visuellen Slots im Kopfbereich

In `@UI.headerInfo` ist `description` **kein** Beschreibungstext, sondern der technische Name für den **Untertitel-Slot** im Fiori-Header:

```
 ┌─────────┐  Buch                              <-- typeName (kleine Typbezeichnung)
 │         │  Clean Code                        <-- title (große Hauptüberschrift)
 │  BILD   │  Robert C. Martin                  <-- description (Untertitel-Zeile darunter!)
 └─────────┘
  imageUrl
```

* `title: { value: 'Title' }`: Große Hauptüberschrift (z. B. Buchtitel).
* `description: { value: 'Author' }`: Zweite Zeile direkt darunter (ideal für Autor, Kunde oder Kurzinfo).
* `imageUrl: 'CoverUrl'`: Quadratisches Bild / Avatar links neben den Texten.

---

### 5.3 `@UI.facet`: Die Bilderrahmen der Object Page

Eine Facette ist wie ein **leerer Bilderrahmen** auf der Object Page. Sie enthält selbst keine Daten, sondern steuert Darstellungsart (`type`) und Zielverknüpfung:

```
@UI.facet (auf Entity-Ebene)
┌────────────────────────────────────────────────────────────────────────┐
│ id: 'BasicData'                                                        │
│ type: #IDENTIFICATION_REFERENCE  ────────┐                             │
└──────────────────────────────────────────│─────────────────────────────┘
                                           │  Automatischer Suchlauf nach:
                                           ▼  @UI.identification
                                    ┌────────────────────────┐
                                    │ BookId;                │
                                    │ Title;                 │
                                    │ Author;                │
                                    └────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│ id: 'SampleData'                                                       │
│ type: #FIELDGROUP_REFERENCE              │                             │
│ targetQualifier: 'SampleGroup' ──────────┼──────────────────┐          │
└──────────────────────────────────────────│──────────────────│──────────┘
                                                              │  Sucht nach:
                                                              ▼  qualifier: 'SampleGroup'
                                                       ┌────────────────────────┐
                                                       │ SamplePdf;             │
                                                       └────────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│ id: 'LoanTable'                                                        │
│ type: #LINEITEM_REFERENCE                                              │
│ targetElement: '_Loan' ─────────────────────────────────────┐          │
└─────────────────────────────────────────────────────────────│──────────┘
                                                              │  Springt über Assoziation
                                                              ▼  zu C_LOAN und liest:
                                                       ┌────────────────────────┐
                                                       │ @UI.lineItem in LOAN!  │
                                                       │ (LoanNo, MemberId...)  │
                                                       └────────────────────────┘
```

#### Die 4 wichtigsten Facetten-Typen (`type:`):
1. **`#IDENTIFICATION_REFERENCE`**: Rendert ein klassisches Formular (Label links, Wert rechts) aus allen Feldern, die `@UI.identification: [{ position: ... }]` besitzen. Jede Entität hat genau einen solchen Standard-Topf.
2. **`#FIELDGROUP_REFERENCE`**: Rendert ein Formular aus einer frei benannten Gruppe. Über `targetQualifier: 'GruppenName'` verknüpft die Facette sich mit allen Feldern, die `@UI.fieldGroup: [{ qualifier: 'GruppenName' }]` deklarieren. Perfekt, um Upload-Felder (wie PDF) oder Finanzdaten in eigene Kästen auszulagern.
3. **`#LINEITEM_REFERENCE`**: Rendert eine voll interaktive Tabelle für eine Kind-Entität. Über `targetElement: '_Loan'` springt Fiori zur Kind-Metadata-Extension und liest dort `@UI.lineItem`.
4. **`#COLLECTION`**: Reiner Sammelordner ohne eigene Felder. Fasst über `parentId` mehrere Unter-Facetten zu einer optischen Einheit (Reiter/Tabs oder Sektion) zusammen.

---

### 5.4 Zuordnungsattribute im Detail (`id`, `parentId`, `targetElement`, `targetQualifier`)

* **`id` (Freier technischer Name):** Eindeutige Kennung des Rahmens (z. B. `'GeneralInfo'`, `'Loans'`).
* **`parentId` (Zuordnung zum Eltern-Container):** Ordnet eine Facette einem übergeordneten `#COLLECTION`-Container zu.
* **`targetElement` (Ziel-Assoziation):** Wird **nur bei `#LINEITEM_REFERENCE`** benötigt. Gibt den Namen der CDS-Assoziation an (z. B. `targetElement: '_Loan'`).
* **`targetQualifier` (Ziel-Feldgruppe):** Wird **nur bei `#FIELDGROUP_REFERENCE`** benötigt. Stimmt mit dem `qualifier`-String an den Zielfeldern überein.

---

### 5.5 Mehrstufige Object Pages (Root vs. Sub-Object Page)

In Fiori Elements besitzt jede Entität ihre **eigene Seite**:
* **Root Object Page (Level 1):** Das Buch (`ZALM_LB_C_Book`).
* **Sub-Object Page (Level 2):** Die Ausleihe (`ZALM_LB_C_Loan`) oder Rezension (`ZALM_LB_C_Review`).

Wird in der Ausleihen-Tabelle auf eine Zeile oder *"Hinzufügen"* geklickt, öffnet sich die Sub-Object Page:
* `@UI.headerInfo` in `ZALM_LB_C_Loan` steuert den Header **dieser Sub-Detailseite** (z. B. *"Ausleihe LN-00001"*).
* Sie erscheint **nicht** im Header des Buchs! Jede Entität steuert ausschließlich ihre eigene Bildschirmmaske.

---

### 5.6 Das Zusammenspiel bei Status-Feldern (`StatusId`)

Für professionelle Status-Spalten mit farbigen Badges, Text und automatischer Prüfung arbeiten mehrere Schichten zusammen:

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. Text-Verknüpfung (DDLS C_View)                                      │
│    @ObjectModel.text.element: ['StatusText']                           │
│    → Zeigt automatisch den Langtext ("Ausgeliehen") statt nur "AC".   │
├────────────────────────────────────────────────────────────────────────┤
│ 2. Fiori Ampelfarbe & Icon (DDLX Metadata Extension)                   │
│    @UI.lineItem: [{                                                    │
│      criticality: 'StatusCriticality',                                 │
│      criticalityRepresentation: #WITH_ICON                             │
│    }]                                                                  │
│    → 1 = Rot (Überfällig), 2 = Gelb (Aktiv/Verlängert), 3 = Grün       │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Text-Anordnung (DDLX Metadata Extension)                            │
│    @UI.textArrangement: #TEXT_FIRST                                    │
│    → Blendet den lesbaren Text prominent ein ("Ausgeliehen").          │
├────────────────────────────────────────────────────────────────────────┤
│ 4. Dropdown & Sofortprüfung (DDLS C_View)                              │
│    @Consumption.valueHelpDefinition: [{                                │
│      entity: { name: 'ZALM_LB_I_LoanStatus', element: 'StatusId' },    │
│      useForValidation: true                                            │
│    }]                                                                  │
│    → Öffnet Dropdown; manuelle Fehleingaben werden sofort abgewiesen.  │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 5.7 Visuelles Gesamtergebnis der Bibliotheks-App

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ [Cover]  Clean Code                                                             │
│          Robert C. Martin                                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│ [ Sektion: Buchdetails ]  (id: 'GeneralInfo' / type: #COLLECTION)               │
│                                                                                 │
│   ┌─ Formular: Stammdaten & Bestand ────┐  ┌─ Formular: Leseprobe (PDF) ─────┐ │
│   │  Book ID:      MED-0001             │  │  PDF-Leseprobe: [ Upload / PDF ]│ │
│   │  Titel:        Clean Code           │  │                                 │ │
│   │  Autor:        Robert C. Martin     │  └─────────────────────────────────┘ │
│   │  Kategorie:    SOFTWARE             │   (#FIELDGROUP_REFERENCE)            │
│   │  Preis:        39,99 EUR            │                                      │
│   │  Verfügbar:    4                    │                                      │
│   └─────────────────────────────────────┘                                      │
│    (#IDENTIFICATION_REFERENCE)                                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│ [ Sektion: Ausleihen ]  (id: 'Loans' / type: #LINEITEM_REFERENCE / _Loan)       │
│ ┌─────────────────────────────────────────────────────────────────────────────┐ │
│ │ Leih-Nr.   │ Entleiher       │ Leihdatum   │ Fällig am   │ Status           │ │
│ ├────────────┼─────────────────┼─────────────┼─────────────┼──────────────────┤ │
│ │ LN-00001   │ Lena Bergmann   │ 01.10.2026  │ 15.10.2026  │ [● Ausgeliehen]  │ │
│ └─────────────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────────┤
│ [ Sektion: Rezensionen ]  (id: 'Reviews' / type: #LINEITEM_REFERENCE / _Review) │
│ ┌─────────────────────────────────────────────────────────────────────────────┐ │
│ │ Mitglied        │ Bewertung │ Überschrift       │ Datum                     │ │
│ ├─────────────────┼───────────┼───────────────────┼───────────────────────────┤ │
│ │ Max Mustermann  │ 5 Sterne  │ Pflichtlektüre!   │ 05.10.2026                │ │
│ └─────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Exception- & Nachrichten-Architektur in RAP (`ZCM_...` & `T100`)

### 6.1 Die Exception-Hierarchie: `cx_static_check` vs. `cx_dynamic_check` vs. `cx_no_check`

Alle ABAP-Ausnahmeklassen erben von `cx_root`. Die Wahl der Superklasse bestimmt, wie streng der Compiler die Fehlerbehandlung erzwingt:

```
                  ┌────────────┐
                  │  CX_ROOT   │
                  └─────┬──────┘
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
  CX_STATIC_CHECK CX_DYNAMIC_CHECK CX_NO_CHECK
  (Compilerpflicht) (Laufzeit-      (Schwere Systemfehler/
                     überwachung)    Programmierfehler)
```

* **`cx_static_check` (Pflicht für RAP Messages):**
  * Fachliche Fehler (Business Exceptions).
  * Wird die Exception per `RAISE EXCEPTION` ausgelöst, **zwingt der Compiler** den Entwickler via Syntaxprüfung dazu, sie entweder per `TRY ... CATCH` zu behandeln oder im Methodenkopf mit `RAISING` weiterzureichen.
* **`cx_dynamic_check`:**
  * Fehler, die potenziell überall auftreten können (z. B. Division durch Null `CX_SY_ZERODIVIDE`).
  * Keine Deklarationspflicht im `RAISING`. Fehlt zur Laufzeit ein Handler, bricht das System mit `CX_SY_NO_HANDLER` ab.
* **`cx_no_check`:**
  * Ungeprüfte schwere Programmierfehler (z. B. Nullpointer `CX_SY_REF_IS_INITIAL`). Dürfen weder deklariert werden noch sollten sie fachlich abgefangen werden (führen meist zum Dump).

---

### 6.2 Die 3 Interfaces einer RAP-Nachrichtenklasse

Eine RAP-Message-Klasse (z. B. `ZCM_ALM_LB`) ist technisch eine Exception-Klasse, die drei Interfaces bündelt:

1. **`if_t100_message` (Die T100-Brücke):**
   * Definiert das Attribut `t100key TYPE scx_t100key`.
   * Bringt die Methode `get_text()` mit, um den Text aus der Datenbanktabelle `T100` zu lesen.
2. **`if_t100_dyn_msg` (Kernel-Systemfelder):**
   * Erweitert `if_t100_message` um die Systemattribute `msgv1` bis `msgv4` und `msgty` (`E`, `W`, `I`, `S`).
   * Erlaubt das direkte Übernehmen von Systemmeldungen aus klassischen BAPIs oder Funktionsbausteinen (`sy-msgid` / `sy-msgno`).
3. **`if_abap_behv_message` (Das exklusive RAP-Ticket):**
   * Typisiert das Feld `%msg` in den RAP-Strukturen `reported-<entity>`.
   * Steuert die visuelle Schwere (`m_severity`: `error` = Rot, `warning` = Gelb, `information` = Blau, `success` = Grün) im Fiori-UI.
   * **Ohne dieses Interface bricht `reported-%msg = NEW zcm_...` mit einem Typkonflikt-Syntaxfehler ab.**

---

### 6.3 Die Struktur `SCX_T100KEY` & 1:1 Struktur-Zuweisung

Die Konstanten in der Message-Klasse sind **Strukturen mit exakt 6 Komponenten**:
```abap
CONSTANTS:
  BEGIN OF dates_invalid,
    msgid TYPE symsgid      VALUE 'ZALM_LB_MSG', " 1. Nachrichtenklasse
    msgno TYPE symsgno      VALUE '001',         " 2. Meldungsnummer
    attr1 TYPE scx_attrname VALUE 'MV_ATTR1',    " 3. Variablenname für &1
    attr2 TYPE scx_attrname VALUE 'MV_ATTR2',    " 4. Variablenname für &2
    attr3 TYPE scx_attrname VALUE '',            " 5. Variablenname für &3
    attr4 TYPE scx_attrname VALUE '',            " 6. Variablenname für &4
  END OF dates_invalid.
```

Im Konstruktor führt die Zeile:
```abap
if_t100_message~t100key = textid.
```
eine **vollständige 1:1 Struktur-Kopie** durch: Alle 6 Felder werden auf einen Schlag in das Attribut `t100key` übertragen.

Der vorangestellte `IF textid IS INITIAL`-Block dient als **Sicherheitsnetz**: Wurde beim Instanziieren versehentlich keine `textid` übergeben, wird auf `if_t100_message=>default_textid` zurückgegriffen, damit das Framework nicht mit einem Nullpointer abstürzt.

---

### 6.4 Lazy Evaluation: Wie `get_text()` den Text zusammensetzt

Im Konstruktor existiert noch **kein fertiger String**! Das Objekt merkt sich lediglich die „Koordinaten“. Die eigentliche Textauflösung erfolgt **verzögert (Lazy Evaluation)**, sobald RAP die Nachricht für das Fiori-UI serialisiert:

```
                        cl_message_helper / cx_root
                                    │
                                    │ 1. Liest t100key aus:
                                    │    msgid = 'ZALM_LB_MSG', msgno = '001'
                                    ▼
                         ┌────────────────────┐
                         │  DB-Tabelle T100   │
                         └─────────┬──────────┘
                                   │
                                   │ 2. Holt Rohtext:
                                   │    "Rückgabedatum &1 darf nicht vor &2 liegen"
                                   ▼
                         ┌────────────────────┐
                         │    Klassen-Objekt  │
                         └─────────┬──────────┘
                                   │ 3. Liest attr1 ('MV_ATTR1') und attr2 ('MV_ATTR2')
                                   │    -> holt me->mv_attr1 ("01.10.2026")
                                   │    -> holt me->mv_attr2 ("15.10.2026")
                                   ▼
          Ergebnis: "Rückgabedatum 01.10.2026 darf nicht vor 15.10.2026 liegen"
```

1. **DB-Read:** `get_text()` liest aus Tabelle `T100` anhand von `msgid` und `msgno` den Rohtext.
2. **Reflection:** Die Laufzeit liest den Namen in `attr1` (`'MV_ATTR1'`), sucht das gleichnamige Attribut `me->mv_attr1` auf der Klasseninstanz und ersetzt damit den Platzhalter `&1`.
3. Kein manueller String-Zusammenbau oder `REPLACE`-Code nötig!

---

### 6.5 Warum maximal 4 Attribute?

Das SAP T100-Meldungsformat basiert im ABAP-Kernel fest auf den vier Systemfeldern **`sy-msgv1` bis `sy-msgv4`**.
* Daher unterstützt das T100-System ausschließlich die Platzhalter `&1`, `&2`, `&3` und `&4`.
* Auch `SCX_T100KEY` besitzt exakt `attr1` bis `attr4`.
* Müssen mehr Informationen übermittelt werden, fasst man zusammengehörige Werte vor der Übergabe per String-Template zusammen (z. B. `attr1 = |{ book_id } ({ title })|`).




---

## 7. Determinations, EML-Kochbuch & ABAP Cloud Utilities

### 7.1 Determinations: Ausführungszeitpunkte (`on modify` vs. `on save`) & Trigger-Sensoren

Determinations sind automatisierte Geschäftsregeln, die Felder berechnen oder Standardwerte setzen. Sie werden in der BDEF über zwei Dimensionen gesteuert: **WANN** sie ausgeführt werden (`on modify` vs. `on save`) und **BEI WELCHEM EREIGNIS** sie aufwachen (`{ create; delete; field ...; }`).

#### 7.1.1 Der Ausführungszeitpunkt: `on modify` vs. `on save`

| Eigenschaft | `on modify` (Interaktive Phase) | `on save` (Sicherungsphase) |
|---|---|---|
| **Wann feuert es?** | **Sofort** während der Benutzerinteraktion (nach Eingabe im UI oder nach jedem EML-`MODIFY`). | **Erst beim Klick auf „Sichern“** (Save Sequence / *Finalize Phase*), kurz vor dem DB-Commit. |
| **Sichtbarkeit im UI** | Das Ergebnis erscheint **sofort live auf dem Bildschirm** (im Draft-Modus). | Das Ergebnis wird erst nach dem Speichern sichtbar. |
| **Typischer Zweck** | Standardwerte/Defaults (`LoanDate = heute`), Nummernvergabe (`MED-0001`), Live-Berechnungen in der Maske. | Aufwändige Aggregationen & Durchschnitte über viele Datensätze (z. B. 50 Rezensionen neu aggregieren). |
| **Performance-Gedanke** | Muss blitzschnell sein, weil der Benutzer im UI auf die Maskenantwort wartet. | Kann rechenintensiver sein, da es nur einmal am Ende der Arbeit läuft. |

#### 7.1.2 Der Draft-Aha-Moment: Wann passiert in Fiori ein `create`?
In einer RAP-App mit Draft (`with draft;`) passiert das Anlegen **nicht erst beim Klick auf Speichern**, sondern in der ersten Sekunde beim Klick auf den Button **`+ Hinzufügen` (Create)**:
* **`on modify { create; }` (So wie in LB-08):**  
  User klickt auf `+` $\rightarrow$ RAP erzeugt sofort die Draft-Zeile $\rightarrow$ Determination feuert augenblicklich $\rightarrow$ **Ergebnis:** Die Maske öffnet sich und Felder wie Leihdatum (`heute`), Frist (`+14 Tage`), Status (`AC`) und Buch-ID (`MED-0007`) sind **sofort vorausgefüllt sichtbar**!
* **Was passieren würde bei `on save { create; }`:**  
  User klickt auf `+` $\rightarrow$ Maske öffnet sich komplett **schneeweiß und leer**. Der User sieht keine Vorgabewerte. Erst Minuten später, beim Klick auf *„Sichern“*, würde RAP die Felder im Hintergrund kurz vor dem DB-Commit setzen. Der Benutzer hätte während der gesamten Eingabe nichts davon gesehen.

#### 7.1.3 Die Syntax: Das WANN und das WAS
In der BDEF trennt die Syntax strikt zwischen Zeitpunkt und Auslöser:
```abap
determination meineLogik  ON <WANN>  { <BEI WELCHEM EREIGNIS>; }
```
* **Nach dem `ON` (Zeitpunkt):** `on modify` (sofort live) oder `on save` (beim Speichern).
* **In den geschweiften Klammern `{ ... }` (Sensoren):** `{ create; }`, `{ delete; }` oder `{ field MeinFeld; }`. Es gibt **kein** `{ save; }` in den Klammern!

#### 7.1.4 Die Trigger-Sensoren `{ create; delete; field ...; }`
Die geschweiften Klammern sind **keine Befehle**, sondern **Event-Listener / Sensoren** — und das Semikolon `;` zwischen mehreren Einträgen wirkt als **ODER-Verknüpfung** (keine UND-Bedingung!):
* **Mehrere Trigger kombiniert (`{ field StatusId; create; delete; }`):**  
  Die Determination feuert, sobald **mindestens eines** der Ereignisse eintritt — also **entweder** beim Anlegen (`create`, z. B. auch über `CREATE BY \_Loan` in `lendBook`, ganz unabhängig davon, ob `StatusId` explizit übergeben wird), **oder** beim Löschen (`delete`), **oder** sobald sich bei einer bestehenden Zeile das Feld `StatusId` ändert.
* **`{ field Rating; }` (Feld-Filter):**  
  Ohne `field` würde die Determination bei jeder beliebigen Änderung an der Zeile feuern (selbst bei einem Tippfehler im Kommentar). Mit `field Rating;` schlägt der Sensor bei Änderungen **nur dann an, wenn wirklich das Feld `Rating` angefasst wurde**. Das spart massiv Performance und verhindert Endlosschleifen.
* **`{ delete; }` — Warum Löschen ein Auslöser ist:**  
  `{ delete; }` heißt nicht *„Lösche die Zeile!“*, sondern *„WENN eine Zeile gelöscht WURDE, führe diesen Code aus!“*.
  * **Praxisbeispiel:** Ein Buch hat 3 Rezensionen (5, 4, 3 Sterne $\rightarrow$ Schnitt 4,0). Der Anwender löscht die 3-Sterne-Rezension.
  * Beim Speichern löscht RAP die Rezension. Durch den Sensor `on save { delete; }` springt die Schnitt-Berechnung an und korrigiert den Buch-Schnitt sofort auf **4,5 Sterne**. Ohne `delete;` bliebe der alte Schnitt von 4,0 für immer falsch auf dem Buch stehen!
* **Wann macht `on modify { delete; }` Sinn?**  
  Für **Live-Summen in Kind-Tabellen**, die sich sofort im Browser auf den Parent auswirken sollen:
  * Beispiel: Ein Einkaufswagen hat Gesamtsumme `150 €` und drei Positionen à `50 €`.
  * Klickt der Benutzer bei Position 3 auf *„Löschen“*, feuert `on modify { delete; }` **sofort**.
  * Die Gesamtsumme im Kopf springt **augenblicklich live von 150 € auf 100 €** um, noch während der User editiert! (Bei `on save` stünde dort verwirrenderweise bis zum Klick auf Speichern weiterhin 150 €).

#### 7.1.5 Unmögliche & verbotene Kombinationen (Compilerprüfungen)
* **`determination ... on modify { field ReadOnlyFeld; }`:** Verboten! Schreibgeschützte Felder (`readonly`) können im UI nie vom Benutzer editiert werden. Der Trigger würde niemals anschlagen.
* **`determination ... on save { delete; }` auf der Root-Entität (`Book`) für eigene Felder:** Verboten! Wenn das Buch gelöscht wird, wird die ganze DB-Zeile vernichtet. Es macht keinen Sinn, darauf noch Felder zu berechnen. (Bei Kind-Entitäten wie `Review` oder `Loan` ist es erlaubt und essenziell, weil man den *Parent* aktualisiert!).
* **`field ...` bei `delete`:** Ein gelöschter Datensatz besitzt keine geänderten Einzelfelder mehr $\rightarrow$ nicht kombinierbar.

---

### 7.2 Das EML-Kochbuch: Mentales Modell & Die 4 Standard-Rezepte

| Feld / Präfix | Bedeutung | Wann nutzen? |
|---|---|---|
| **`%tky`** (*Transactional Key*) | Bündelt Primärschlüssel **+** `%is_draft` | **Standard in 95 % aller Fälle** (Determinations, Validations, Actions in Draft-BOs). |
| **`%pky`** (*Persistent Key*) | Primärschlüssel der **aktiven Datenbankzeile** (ohne `%is_draft`) | Wenn man gezielt die echte DB-Zeile ansprechen will, unbeeinflusst vom Entwurf. |
| **`%key`** (*Primary Key*) | Die nackten Primärschlüsselfelder der Entität | In BOs **ohne Draft** oder beim Mappen reiner Schlüsselwerte. |
| **`%data`** (*Business Data*) | Unterstruktur aller **fachlichen Felder** (ohne technische Steuerung) | Perfekt zum Duplizieren/Kopieren per `CORRESPONDING #( orig-%data )`. |
| **`%cid`** (*Content ID*) | Temporäre Kennung für nagelneue Zeilen | Bei `CREATE`, bevor ein echter Schlüssel existiert. |
| **`%control`** | Bitmaske: Welche Felder wurden im Request überhaupt übergeben? | In unmanaged RAP oder generischen Handlern, um leere Felder von unberührten Feldern zu unterscheiden. |

#### Warum wirkt EML so umständlich?
1. **Massenverarbeitung (Set-based):** EML operiert immer auf Tabellen, nie auf Einzelsätzen (kein `UPDATE SINGLE`).
2. **Draft-Fähigkeit (`%tky`):** EML muss wissen, ob ein aktiver Datensatz oder ein temporärer Entwurf gemeint ist.
3. **Schutz & lokale Ausführung (`IN LOCAL MODE`):** In internen BO-Handlern schaltet man mit `IN LOCAL MODE` Berechtigungsprüfungen und Feature-Controls ab.

```
                   SQL                          EML (Entity Manipulation Language)
Ziel:              Physische DB-Tabelle         RAP Business Object (Aggregate)
Befehle:           SELECT, UPDATE, INSERT       READ ENTITIES, MODIFY ENTITIES
Logik:             Ignoriert RAP-Logik           Triggert Determinations, Validations & Drafts
Schlüssel:         Primärschlüssel (UUID/ID)    %tky (Key + %is_draft)
```

#### Rezept 1: Felder lesen (`READ ENTITIES`)
Liest gezielt ausgewählte Felder aus einer oder mehreren Instanzen:
```abap
READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
  ENTITY Book
    FIELDS ( BookId Title )
    WITH CORRESPONDING #( keys )
  RESULT DATA(lt_books).
```

#### Rezept 2: Felder ändern (`MODIFY ENTITIES UPDATE`)
* **Klassischer Weg mit Hilfstabelle (`TYPE TABLE FOR UPDATE`):**
```abap
DATA lt_update TYPE TABLE FOR UPDATE zalm_lb_i_book.

LOOP AT lt_books ASSIGNING FIELD-SYMBOL(<book>).
  APPEND VALUE #( %tky   = <book>-%tky
                  BookId = 'MED-0001' ) TO lt_update.
ENDLOOP.

MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
  ENTITY Book
    UPDATE FIELDS ( BookId )
    WITH lt_update
  REPORTED DATA(lt_reported).
```

* **Eleganter moderner Weg (Inline mit `VALUE #( FOR ... )`):**
Keine Zwischentabelle nötig – spart Deklaration und Schleifen-Boilerplate:
```abap
MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
  ENTITY Book
    UPDATE FIELDS ( BookId )
    WITH VALUE #( FOR book IN lt_books (
                    %tky   = book-%tky
                    BookId = 'MED-0001' ) )
  REPORTED DATA(lt_reported).
```

#### Rezept 3: Root-Instanz neu anlegen (`MODIFY ENTITIES CREATE`)
Bei Neuanlagen existiert noch kein `%tky`. Man vergibt eine temporäre Content-ID (`%cid`):
```abap
MODIFY ENTITIES OF zalm_lb_i_book
  ENTITY Book
    CREATE FIELDS ( Title Author Category )
    WITH VALUE #( ( %cid     = 'NEW_BOOK_1'
                    Title    = 'Clean ABAP'
                    Author   = 'Stefan Roth'
                    Category = 'ABAP' ) )
  MAPPED DATA(mapped)
  FAILED DATA(failed)
  REPORTED DATA(reported).
```

#### Rezept 4: Kind-Instanz über Komposition anlegen (`CREATE BY \_Assoc`)
Legt ein Kind unter einem bestehenden Parent an. Der Parent wird über `%tky` adressiert, die Kinder stehen in der Tabelle `%target`:
```abap
MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
  ENTITY Book
    CREATE BY \_Loan
    FIELDS ( MemberId LoanDate StatusId )
    WITH VALUE #( ( %tky    = ls_book-%tky
                    %target = VALUE #( ( %cid      = 'NEW_LOAN_1'
                                         MemberId  = 'MEM-0001'
                                         LoanDate  = cl_abap_context_info=>get_system_date( )
                                         StatusId  = 'AC' ) ) ) )
  REPORTED DATA(lt_reported).
```

---

### 7.3 Deep Dive: Was steckt in `%control`, `%msg`, `%element` und `%state_area`?

#### 1. `%control` — Die Lösung des ABAP-„Null vs. Initial“-Dilemmas
* **Das Problem:** In JSON/OData gibt es einen Unterschied zwischen:
  1. `{ "Title": "" }` $\rightarrow$ Der Anwender hat den Titel bewusst **gelöscht** (leer gemacht).
  2. `{ }` $\rightarrow$ Der Anwender hat den Titel gar **nicht angefasst** (Feld wurde im PATCH nicht mitgeschickt).
  * In ABAP sind beide Werte aber schlicht ein initialer String `''`! Woher weiß RAP, ob es die Tabellenspalte auf der DB leeren oder ihren alten Wert behalten soll?
* **Die Lösung `%control`:**  
  `%control` ist eine Struktur, die für jedes Feld der Entität ein Flag besitzt (`if_abap_behv=>mk-on` = `'01'`, `if_abap_behv=>mk-off` = `'00'`).
  * `mk-on`: *„Dieses Feld wurde im Request explizit mitgeschickt / geändert.“* (selbst wenn es leer ist!).
  * `mk-off`: *„Dieses Feld wurde nicht berührt. Alten Wert beibehalten!“*
* **Wann muss man `%control` selbst anfassen?**
  * Wenn du die Syntax `UPDATE FIELDS ( Title ) WITH ...` nutzt, setzt das Framework `%control-Title = mk-on` **automatisch** für dich.
  * Schreibst du jedoch generischen Code oder unmanaged RAP mit `UPDATE FROM ...`, musst du `%control` manuell befüllen, damit RAP weiß, welche Spalten aktualisiert werden sollen.

#### 2. `%msg` — Das typisierte Nachrichten-Objekt
* **Typ:** Referenz auf `if_abap_behv_message` (kombiniert mit `if_t100_message`).
* **Was steckt drin?**
  * `m_severity`: Fehlerschwere (`if_abap_behv_message=>severity-error`, `-warning`, `-information`, `-success`).
  * `t100key`: Koordinaten der Nachricht (`msgid`, `msgno`, `attr1`..`attr4`).
  * Textplatzhalter (`mv_attr1` .. `mv_attr4`).
* **Instanziierung:**
  * Mit unserer Exception-Klasse: `NEW zcm_alm_lb( severity = ... textid = ... attr1 = ... )`.
  * Oder per BDEF-Framework-Methode: `new_message( id = 'ZALM_LB_MSG' number = '001' severity = ... v1 = ... )`.

#### 3. `%element-<Feld>` — Die visuelle Feldhervorhebung im Fiori-UI
* Wenn eine Meldung an `reported` übergeben wird, weiß Fiori zwar, *dass* ein Fehler vorliegt, aber noch nicht, *an welchem Eingabefeld* der Cursor stehen und welcher Rahmen rot aufleuchten soll.
* Über `%element-DueDate = if_abap_behv=>mk-on` verknüpft man die Nachricht mit dem konkreten UI-Element. Das UI markiert das Feld rot und platziert die Meldung im Value-State des Felds.

#### 4. `%state_area` — State Messages vs. Transition Messages
* **Transition Messages (flüchtig):** Erscheinen z. B. nach Klick auf einen Action-Button als Toast („Buch erfolgreich verliehen“). Verschwinden beim nächsten Request.
* **State Messages (Zustandsmeldungen im Draft):** Fehler bei Validierungen (z. B. „Rückgabedatum ungültig“).
  * Müssen so lange am Entwurf kleben bleiben, bis der Benutzer das Datum korrigiert hat.
  * Beim erneuten Validieren muss RAP zuerst die alten Fehler **löschen**.
  * Dafür vergibt man eine `%state_area` (z. B. `'VALIDATE_DATES'`). Beim Start der Validierung leert man den Bereich, prüft neu, und hängt neue Fehler wieder an denselben Bereich an.

---

### 7.4 ABAP Cloud Utilities & Hilfsklassen in der Praxis

In ABAP Cloud (und modernem ABAP 7.58) sind klassische Systemfelder (`sy-datum`, `sy-uname`) und obsolete Funktionsbausteine gesperrt oder deprecated. Hier sind die wichtigsten freigegebenen Klassen mit konkreten Praxisbeispielen:

#### 1. `cl_abap_context_info` (System- & Benutzerkontext)
```abap
" Systemdatum & Uhrzeit (Ersatz für sy-datum & sy-uzeit)
DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
DATA(lv_now)   = cl_abap_context_info=>get_system_time( ).

" Benutzername technisch (Ersatz für sy-uname) & formatiert
DATA(lv_user)      = cl_abap_context_info=>get_user_technical_name( ). " z. B. 'LUDOVICI-M'
DATA(lv_user_name) = cl_abap_context_info=>get_user_formatted_name( ). " z. B. 'Max Mustermann'

" Sprache & Zeitzone
DATA(lv_lang_abap) = cl_abap_context_info=>get_user_language_abap_format( ). " 'D'
DATA(lv_lang_iso)  = cl_abap_context_info=>get_user_language_iso_format( ).  " 'de'
DATA(lv_tz)        = cl_abap_context_info=>get_user_time_zone( ).            " 'CET'
```

#### 2. `cl_system_uuid` (UUID-Erzeugung)
```abap
" 16-Byte RAW UUID (Standard in RAP DB-Tabellen & sysuuid_x16)
DATA(lv_uuid_raw) = cl_system_uuid=>create_uuid_x16_static( ).

" 32-Zeichen Hex-String (z. B. für externe APIs oder Logging)
DATA(lv_uuid_c32) = cl_system_uuid=>create_uuid_c32_static( ).
```

#### 3. `cl_numberrange_runtime` (Nummernkreise ziehen)
Im echten Late Numbering oder Unmanaged RAP:
```abap
TRY.
    cl_numberrange_runtime=>number_get(
      EXPORTING
        nr_range_nr = '01'
        object      = 'ZALM_BOOK'
      IMPORTING
        number      = DATA(lv_next_raw)
    ).
    DATA(lv_next_id) = |MED-{ CONV i( lv_next_raw ) WIDTH = 4 PAD = '0' ALIGN = RIGHT }|.
  CATCH cx_number_ranges INTO DATA(lx_nr).
    " Fehlerbehandlung...
ENDTRY.
```

#### 4. Die XCO-Bibliothek (`xco_cp_*` — Das moderne Schweizer Taschenmesser)
Bietet mächtige Fluent APIs für Strings, JSON, Zeit und Regex:
```abap
" String-Operationen (Slicing, Splitten, Groß-/Kleinschreibung)
DATA(lv_clean) = xco_cp=>string( '  Clean ABAP  ' )->strip( )->value.
DATA(lt_parts) = xco_cp=>string( 'ABAP;FIORI;CLOUD' )->split( ';' )->value.

" Datumsrechnungen & Zeitstempel
DATA(lv_future_date) = xco_cp_time=>date( cl_abap_context_info=>get_system_date( )
                         )->add( iv_day = 14 )->as( xco_cp_time=>format->abap )->value.
```

#### 5. `cl_web_http_client_manager` (REST / HTTP-Clients)
Für den Aufruf externer Web-APIs (z. B. OpenLibrary in **LB-12**):
```abap
DATA(lo_dest)   = cl_http_destination_provider=>create_by_url( 'https://openlibrary.org/search.json?q=abap' ).
DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
DATA(lo_res)    = lo_client->execute( if_web_http_client=>get ).
DATA(lv_json)   = lo_res->get_text( ).
```

---

## 8. RAP Side Effects (`side effects`): Live-Aktualisierung im Fiori-UI

### 8.1 Warum `on modify` allein im Browser noch nichts aktualisiert

Eine `determination ... on modify` berechnet Werte zwar sofort bei der Eingabe im Draft-Modus — sie schreibt das Ergebnis aber zunächst **nur im Backend in den RAP-Transaktionspuffer bzw. die Draft-Tabelle**.

Das Fiori-Elements-Frontend hat nur einen `PATCH` für das editierte Feld abgeschickt und weiß nichts von solchen indirekten Nebenwirkungen im Backend. Ohne weitere Angabe bleibt der veraltete Wert im Browser stehen, bis der Benutzer die Seite neu lädt (`F5`) oder auf **Speichern** (*Save*) klickt.

**Die Lösung sind `side effects` in der Behavior Definition (ab ABAP 7.58):**
* **Reine UI-Metadaten, keine ABAP-Implementierung:** `side effects` erzeugt **keinen** Code im Behavior Pool, sondern übersetzt sich automatisch in OData-V4-Annotationen (`@Common.SideEffects`).
* **Kein Effekt bei reinem ABAP-EML:** Ruft man das BO programmatisch per EML auf (z. B. in einem Report oder Unit-Test), haben `side effects` keinerlei Auswirkung — dort muss man geänderte Felder selbst per `READ ENTITIES` nachlesen.

### 8.2 Zusammenspiel `on modify` + `side effects` im Zeitablauf

```
1. UI: Benutzer ändert z. B. `Rating` und verlässt das Feld (Tab)
       ──► OData PATCH an die Draft-Entität `Review`
2. Backend: `determination ... on modify` feuert automatisch
       ──► Berechnet neuen Schnitt & schreibt `AvgRating` in den Draft von `Book`
3. Frontend (dank `@Common.SideEffects`): Merkt „Rating hat sich geändert!“
       ──► Schickt sofort automatisch einen gezielten OData GET auf das Ziel
4. UI: Zeigt das neue `AvgRating` live am Buch an — ohne Save und ohne Seiten-Reload
```

### 8.3 Granularität hinter `affects`: Wird die ganze Seite neu geladen?

**Nein!** Genau dafür sind Side Effects optimiert: Fiori Elements lädt gezielt nur die hinter **`affects`** definierten Ziele per Teil-Request nach (z. B. `$select=AvgRating`). Scroll-Position, Cursor-Fokus und der Rest der Object Page bleiben unberührt.

| Trigger (links von `affects`) | Bedeutung |
|---|---|
| `field MeinFeld` | Feuert, wenn genau dieses Feld auf der UI geändert wurde. |
| `$self` | Feuert bei jeder Create-, Update- oder Delete-Operation auf der aktuellen Entität. |
| `action MeineAction` | Feuert nach Ausführung der angegebenen Action. |
| `determine action MeinPrep executed on ...` | Ruft zuerst eine `determine action` (z. B. `Prepare`) auf den angegebenen Quellen auf und lädt danach die Ziele nach (wichtig, um z. B. State-Meldungen von Validations im UI sichtbar zu machen). |
| `event MeinEvent` | Event-gesteuerte Side Effects (bei asynchronen Events). |

| Ziel hinter `affects` | Was Fiori Elements konkret neu lädt |
|---|---|
| `field Feld1, field Feld2` | Nur diese einzelnen Felder (bei Kind $\rightarrow$ Vater per Pfad: `field _Book.AvgRating`). |
| `entity _Assoc` | Eine komplette verknüpfte Entität / Kind-Tabelle (z. B. `entity _Review`). |
| `$self` | Die gesamte aktuelle Entität (inkl. aller Felder). |
| `messages` | Die `reported`-Meldungen (`SAP__Messages`) für Validierungsfehler. |
| `action MeineAction` | Dynamische Berechtigungen / Feature Control einer Action (Button aktiv/inaktiv) neu laden. |

> [!NOTE]
> Pro Entität in der BDEF darf es nur **einen** `side effects { ... }`-Block geben; mehrere Regeln innerhalb dieses Blocks werden per Semikolon `;` getrennt. Bei `$self affects ...` dürfen keine eigenen Felder von `$self` als Ziel stehen — Felder des Elternobjekts über eine Assoziation (z. B. `field _Book.AvgRating`) sind dagegen explizit erlaubt.

### 8.4 Praxisbeispiel für die Bibliotheks-App (`on modify` vs. `on save`)

In **LB-09** haben wir `calculateAvgRating` und `calculateAvailCopies` bewusst mit **`on save`** umgesetzt, damit teure Aggregationen erst beim finalen Speichern laufen. Möchte man stattdessen eine **Live-Anzeige schon während der Draft-Bearbeitung**, sind drei Stellen anzupassen:

1. **Basis-BDEF `ZALM_LB_I_Book` — Trigger auf `on modify` + `side effects`:**
   ```abap
   define behavior for ZALM_LB_I_Book alias Book
   ...
   {
     determination calculateAvailCopies on modify { field TotalCopies; }

     side effects
     {
       field TotalCopies affects field AvailCopies;
     }
   }

   define behavior for ZALM_LB_I_REVIEW alias Review
   ...
   {
     determination calculateAvgRating on modify { field Rating; create; delete; }

     side effects
     {
       field Rating affects field _Book.AvgRating;
       $self        affects field _Book.AvgRating;
     }
   }
   ```
2. **Behavior Pool `ZBP_ALM_LB_I_BOOK`:** Methodendeklaration auf `FOR DETERMINE ON MODIFY` umstellen.
3. **Projection-BDEF `ZALM_LB_C_Book` (Pflicht!):** Ohne **`use side effects;`** im Header der Projektion werden die Side Effects nicht in den OData-Service durchgereicht:
   ```abap
   projection;
   strict ( 2 );
   use draft;
   use side effects;
   ```

> [!TIP]
> Auch bei **`on save`-Validations** sind Side Effects hilfreich: Über `determine action Prepare executed on field ... affects messages;` (oder `$self`) stellt man sicher, dass Fiori Elements neu erzeugte State Messages (`SAP__Messages`) zuverlässig nachlädt und am Eingabefeld anzeigt.

---

## 9. Kind-Validierungen, `LINK` & typische Rechen-/Lese-Stolpersteine (LB-09 / LB-10)

### 9.1 Warum `keys` auch im Fiori-Einzelklick immer eine Tabelle ist

Selbst wenn man im Fiori UI gefühlt „immer nur eine Ausleihe auf einmal anlegt und dann auf Sichern klickt“, bekommt jede Determination und Validation **`keys` als interne Tabelle**:

- **Mehrere Draft-Änderungen in einem Speicherlauf:** Im Fiori Draft-Modus kannst du auf der Buch-Objektseite nacheinander mehrere Ausleihen (`Loan`) oder Bewertungen (`Review`) anlegen bzw. ändern und erst danach einmal auf **Sichern / Aktivieren** klicken. Dann kommen alle geänderten Kind-Sätze gesammelt in `keys` an.
- **Einheitliche RAP-Schnittstelle für alle Aufrufer:** Derselbe Handler bedient auch EML-Batch-Aufrufe (`MODIFY ENTITIES ... CREATE BY \_Loan`), Datenimporte oder ABAP-Unit-Tests mit vielen Sätzen gleichzeitig.
- **Konsequenz:** Immer sauber per `LOOP AT keys INTO DATA(ls_key).` iterieren statt auf `keys[ 1 ]` zu vertrauen.

---

### 9.2 Kind validiert Elternteil (`validateAvailability`): `LINK`, `KEY id COMPONENTS` und `%path`

In `LB-10` soll `Loan~validateAvailability` beim Anlegen einer Ausleihe prüfen, ob das zugehörige Eltern-Buch (`Book`) noch genügend `TotalCopies` hat — den Fehler aber **auf der Kind-Entität `Loan`** melden (mit rotem Hinweis an der Ausleihe statt nur oben am Buch).

Dazu liest man von `Loan` über die Assoziation `\_Book` nach oben:

```abap
READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
  ENTITY Loan BY \_Book
    FIELDS ( BookUuid TotalCopies )
    WITH CORRESPONDING #( keys )
  RESULT DATA(lt_books)
  LINK DATA(lt_loan_book_links).
```

Warum braucht es hier **`RESULT` UND `LINK`**?

1. **`RESULT DATA(lt_books)`** enthält die gelesenen **Eltern-Datensätze (`Book`-Zeilen)**. In diesen Buch-Zeilen steht aber **nicht**, welcher `Loan`-Key aus `keys` sie angefordert hat (insbesondere bei neu angelegten Draft-Sätzen oder wenn mehrere neue Ausleihen auf dasselbe Buch zeigen).
2. **`LINK DATA(lt_loan_book_links)`** ist die reine Zuordnungstabelle zwischen beiden Entitäten. Jede Zeile besitzt zwei Schlüssel-Strukturen:
   - **`source-%tky`**: Schlüssel der Ausgangs-Entität (**hier: der `Loan` aus `keys`**).
   - **`target-%tky`**: Schlüssel der Ziel-Entität (**hier: das zugehörige `Book` in `lt_books`**).

Anschließend übersetzt man innerhalb des `LOOP AT keys INTO DATA(ls_key)` den aktuellen `Loan` über die Link-Tabelle auf sein `Book`:

```abap
DATA(ls_link) = VALUE #( lt_loan_book_links[ KEY id COMPONENTS source-%tky = ls_key-%tky ] OPTIONAL ).
DATA(ls_book) = VALUE #( lt_books[ KEY id COMPONENTS %tky = ls_link-target-%tky ] OPTIONAL ).
```

Was diese beiden Zeilen im Detail machen (Übersetzung in klassisches `READ TABLE`):

- **`lt_...[ KEY id COMPONENTS ... ]`**: Eine Table Expression, funktional gleichbedeutend mit `READ TABLE ... WITH KEY id COMPONENTS ...`. Das `KEY id` nutzt den von RAP auf `RESULT`- und `LINK`-Tabellen bereitgestellten Primär-/Identitätsschlüssel.
- **`VALUE #( ... OPTIONAL )`**: Wenn kein passender Eintrag existiert, stürzt das Programm **nicht** mit `CX_SY_ITAB_LINE_NOT_FOUND` ab, sondern liefert einfach eine leere Struktur zurück (Danach unbedingt `IF ls_book IS INITIAL. CONTINUE. ENDIF.` prüfen!).
- **Schritt 1:** Finde in `lt_loan_book_links` die Brücke für meinen aktuellen Ausleih-Schlüssel (`source-%tky = ls_key-%tky`).
- **Schritt 2:** Nimm aus dieser Brücke `ls_link-target-%tky` (die Adresse des Eltern-Buchs) und hole damit die konkrete Buch-Zeile aus `lt_books`.

#### `%path` und `%state_area` bei Kind-Validations

Beim Schreiben der Meldung in `reported-loan` bzw. `reported-review` gilt für Kind-Entitäten (z. B. `Loan`, `Review` unter `Book`):

- **`%tky = ls_key-%tky`** adressiert die betroffene Kind-Zeile (`Loan` oder `Review`).
- **Warum `%path` (`%path-book-%tky = ls_link-target-%tky`) zwingend nötig ist:**
  - Im Draft-UI öffnest und speicherst du meistens die **Root-Object-Page (`Book`)** mit eingebetteten Kind-Tabellen (`_Loan`, `_Review`). Klickst du unten rechts auf **Save / Aktivieren**, ruft Fiori Elements V4 `Book~Prepare` bzw. `Activate` **auf der Root-Entität `Book`** auf — diese stößt dann die eingehängten Kind-Validierungen an.
  - Ohne `%path` weiß OData V4 / Fiori Elements auf dem Rückweg **nicht**, zu welcher Eltern-/Root-Instanz und Untertabelle eine Meldung in `reported-loan` oder `reported-review` gehört.
  - **Typisches Symptom bei fehlendem `%path`:** `failed-review` / `failed-loan` blockiert das Speichern zwar korrekt, aber Fiori Elements verwirft die nicht zuordenbare Detail-Meldung (samt roter Feldmarkierung `%element-*`) und zeigt im Popover nur die generische Standardmeldung **`„Resolve data inconsistencies to save changes.“`**!
  - **Technik dahinter:** `%path` enthält für jeden Vorfahren entlang der Kompositionshierarchie eine Schlüssel-Struktur (Name = BDEF-Alias, hier `book-%tky`; bei 3-stufigen Bäumen zusätzlich Zwischen-Parent + Root). Über `READ ... BY \_Book ... LINK DATA(...)` erhältst du `ls_link-target-%tky` direkt inklusive passendem `%is_draft`-Flag, statt es manuell aus `BookUuid` zusammenzubauen.
- **`%state_area` + `%path` paarweise nutzen:**
  - `%state_area` ist ein frei wählbarer, pro Entität konsistenter String-Identifier für **State Messages** (z. B. `'VALIDATE_RATING'` oder `'VALIDATE_AVAILABILITY'`).
  - Zu Beginn der Validation schickt man pro Satz eine Aufräum-Zeile (`%tky`, `%state_area`, und bei Child-Entitäten ebenfalls `%path`) an `reported`, damit alte rote Meldungen derselben Prüfung nach einer Korrektur sauber verschwinden — andere Prüfungen mit anderem `%state_area` bleiben erhalten. Erst danach folgt im Fehlerfall die eigentliche Meldung mit `%tky`, `%state_area`, `%path`, `%element-<Feld>` und `%msg`.

---

### 9.3 `READ ENTITIES ... FIELDS (...)`: Was implizit mitkommt — und was nicht

Ein subtiler Bug in `LB-09` hat gezeigt, welche Felder `READ ENTITIES ... FIELDS (...)` automatisch ergänzt:

```abap
READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
  ENTITY Book BY \_Loan
    FIELDS ( StatusId )
    WITH CORRESPONDING #( keys )
  RESULT DATA(lt_all_loans).

LOOP AT lt_all_loans INTO DATA(ls_loan) WHERE BookUuid = ls_book-BookUuid.
```

- **Implizit immer enthalten:** Der **eigene Primary Key (`%tky` / z. B. `LoanUuid` und `%is_draft`)** der gelesenen Entität (`Loan`) wird vom Framework automatisch mitgefüllt.
- **NICHT implizit enthalten:** **Fremdschlüssel** wie `BookUuid` auf `Loan` oder `Review` sind für `Loan` nur normale Daten-/Elternverweis-Felder, **kein** Teil des eigenen Primary Keys (`LoanUuid`)! Steht `BookUuid` nicht in `FIELDS ( ... )`, bleibt `ls_loan-BookUuid` initial (`0000...`), der `LOOP ... WHERE BookUuid = ls_book-BookUuid` liefert **0 Treffer**, und der Bestand fällt immer fälschlich auf `TotalCopies` zurück.
- **Regel:** Jedes Feld, nach dem du später filterst (`WHERE`), vergleichst oder rechnest — inklusive Fremdschlüssel auf Kind-Entitäten — **explizit** in `FIELDS ( BookUuid StatusId )` aufnehmen (oder `ALL FIELDS WITH ...` verwenden).

---

### 9.4 Save-Sequence-Reihenfolge: `Determinations on save` laufen *vor* `Validations on save`

Im RAP-Speicherzyklus gilt für `on save` eine feste Reihenfolge:

```text
1. Determinations on save   (z. B. Loan~calculateAvailCopies rechnet AvailCopies neu)
2. Validations on save      (z. B. Loan~validateAvailability prüft den Bestand)
```

- **Die Falle:** Wenn `validateAvailability` einfach prüfen würde `IF ls_book-AvailCopies <= 0.`, hat `calculateAvailCopies` zu diesem Zeitpunkt die **neue Ausleihe bereits von `AvailCopies` abgezogen** (und bei `TotalCopies = 1` auf `0` gesetzt). Damit würde die Prüfung selbst die **letzte eigentlich erlaubte Ausleihe** fälschlich blockieren!
- **Die saubere Lösung:** Entweder zählt `validateAvailability` alle aktiven Ausleihen des Buches (inklusive der aktuellen Draft-Ausleihen) direkt gegen **`TotalCopies`** (`lv_active_loans > ls_book-TotalCopies OR ls_book-TotalCopies <= 0`), sodass die Prüfung völlig unabhängig von der bereits neu berechneten Ableitung `AvailCopies` arbeitet.
- **UI-Komfort vs. Server-Validierung:** Dass ein Nutzer im Fiori UI bei `AvailCopies = 0` gar nicht erst „Ausleihen“ klicken kann (Button ausgegraut), ist Aufgabe von **Instance Feature Control** (`get_instance_features`, folgt in **Stufe C**). Die `on save`-Validation bleibt trotzdem unverzichtbar, weil auch parallele API-/EML-Aufrufe oder manuelles Anlegen im Draft abgesichert sein müssen.

---

### 9.5 Rechentyp-Falle in `calculateAvgRating` (`abap.dec(3,2)` vs. `decfloat34` / `TYPE p`)

In `LB-09` führte `REDUCE` über mehrere `Rating`-Werte zu einem Laufzeit-Dump (`CX_SY_ARITHMETIC_OVERFLOW`), weil als Akkumulator ein Typ mit `abap.dec(3,2)` (wie `AvgRating` / `ZALM_LB_T_RATING`) verwendet wurde:

- **`abap.dec(3,2)`** bedeutet **insgesamt 3 Stellen**, davon 2 Nachkommastellen → größtmöglicher Wert ist **`9.99`**. Schon zwei 5-Sterne-Bewertungen (`5 + 5 = 10`) sprengen den Bereich!
- **Warum `DATA(lv_sum) TYPE p.` in ABAP doppelt falsch wäre:**
  1. `DATA(...)` ist eine Inline-Deklaration — dort darf kein `TYPE ...` dahinter stehen (Syntaxfehler).
  2. Eine klassische Deklaration `DATA lv_sum TYPE p.` ohne Zusätze verwendet in ABAP per Default **0 Nachkommastellen** (`DECIMALS 0`) und würde Nachkommastellen still abschneiden.
- **Korrekte Typisierung für Zwischensummen:**
  ```abap
  " Entweder mit hohem Wertebereich in REDUCE:
  DATA(lv_sum) = REDUCE decfloat34(
    INIT sum = CONV decfloat34( 0 )
    FOR ls_rev IN lt_reviews WHERE ( BookUuid = ls_book-BookUuid )
    NEXT sum = sum + ls_rev-Rating ).

  " Oder klassisch mit expliziter Länge und Dezimalstellen:
  DATA lv_sum TYPE p LENGTH 8 DECIMALS 2.
  ```
  Erst bei der finalen Division `lv_sum / lv_count` wird in das Zieldatenfeld `AvgRating` (`dec(3,2)`, `0.00` bis `5.00`) gerundet/zugewiesen.

---

## 10. Actions & Rückgabewerte (`result [<Kardinalität>] <Typ>`)

### 10.1 Bedeutung von `[1]` und Varianten bei `result`

Bei Actions und Functions beschreibt `result [<Kardinalität>] <Typ>` in der BDEF den Rückgabewert pro verarbeiteter Eingabe-Instanz (bzw. insgesamt bei `static`-Operationen):

#### A) Mögliche Kardinalitäten
| Kardinalität | Bedeutung | Typischer Einsatz |
|---|---|---|
| **`[1]`** | **genau 1** Ergebnis pro Input | Standard bei `result [1] $self` (z. B. aktualisiertes Buch/Ausleihe) oder `getLibraryKpis` |
| **`[0..1]`** | **0 oder 1** Ergebnis | Wenn ein Ergebnis optional ist und auch leer bleiben darf |
| **`[0..*]`** / **`[*]`** | **0 bis beliebig viele** | Wenn pro Input eine Liste von Treffern zurückgegeben wird |
| **`[1..*]`** | **mindestens 1 bis beliebig viele** | Wenn garantiert mindestens eine Ergebniszeile entsteht |

* **Ohne `result`:** Actions müssen keinen Rückgabewert deklarieren (OData liefert dann HTTP `204 No Content`).
* **Sonderfall `factory action`:** Eine Factory Action darf **kein** `result` tragen (die neuen Schlüssel gehen über `mapped`); die Kardinalität (z. B. `[1]`) steht dort direkt hinter dem Action-Namen.

#### B) Mögliche Rückgabetypen hinter der Kardinalität
1. **`$self`:** Derselbe Entitätstyp, auf dem die Action definiert ist (`Book` bei `lendBook`, `Loan` bei `returnBook`).
2. **`entity <AndereEntity>`:** Eine andere CDS-Entität (z. B. `result [1] entity ZALM_LB_I_LOAN`, wenn eine Buch-Action direkt die neu angelegte Ausleihe zurückgeben soll).
3. **`<AbstractEntity>` (ohne `entity` davor):** Eine freie Ergebnisstruktur (z. B. `result [1] ZALM_LB_A_LibraryKpis` für Kennzahlen).
4. **Optionale Zusätze:** `result selective [1] ...` (Aufrufer darf im EML gezielt Felder anfordern) sowie `deep result` für hierarchische Abstract BDEFs.

> [!NOTE]
> Deklariert eine Action `result ...`, füllt RAP die Tabelle im Handler **nicht** selbst — am Ende nach `MODIFY ENTITIES` ist immer ein `READ ENTITIES ...` nötig, um `result` mit `%tky` und `%param` zu befüllen. Verknüpfte Entitäten außerhalb von `$self` (z. B. `_Loan` bei `lendBook` oder `_Book` bei `returnBook`) lädt Fiori Elements V4 trotzdem erst über `side effects` aktiv per `GET` nach.

---

## 11. Managed vs. Unmanaged RAP (BDEF-Implementierungsarten)

### 11.1 Wann nutzt man `managed` und wann `unmanaged`?

Im RAP-Alltag ist **`managed` der Regelfall** (Standard für neue, eigene Datenbanktabellen). **`unmanaged`** ist die gezielte Ausnahme, wenn RAP **nicht** direkt über Standard-SQL auf einer eigenen DB-Tabelle arbeiten kann oder darf:

* **Wann `managed` (Regelfall)?**
  * Greenfield-Entwicklungen mit eigenen persistenten DB-Tabellen (`persistent table ...`).
  * Das Framework übernimmt automatisch Transaktionspuffer, CRUD (`create`, `update`, `delete`, `read`), Sperren (`lock`), ETag-Prüfung, Draft-Handling (`with draft`) und Standard-Datenbankpersistenz.
* **Wann `unmanaged` (Ausnahme)?**
  1. **Custom Entities / externe Datenquellen (wie `LB-18` auf `ZALM_LB_CE_OpenLibBook`):** Keine DB-Tabelle vorhanden; Daten kommen aus HTTP/REST, RFC o. ä.
  2. **Kapselung bestehender Legacy-Logik (BAPIs / Funktionsbausteine):** Wenn vorhandene Standard- oder Altsystem-Logik mit eigener Pufferung und Update-Task-Verarbeitung wiederverwendet werden muss und man nicht direkt auf DB-Tabellen schreiben darf.
  3. **Abweichende Speicher-/Pufferlogik:** Wenn Daten nicht 1:1 in flache DB-Tabellen geschrieben werden, sondern z. B. über verteilte Systeme oder spezielle APIs laufen.
* **Mittelweg `managed with unmanaged save` / `with additional save`:**
  * Wenn RAP die normale Interaction Phase (Puffer, CRUD, Draft, Lock) übernehmen soll, aber beim Speichern zusätzliche oder eigene Persistenzlogik (z. B. Änderungsbelege oder BAPI-Aufruf im Save) benötigt wird.

---

### 11.2 Lifecycle & Implementierungsumfang bei `unmanaged`

* **Der Framework-Lifecycle bleibt gleich:** Auch bei `unmanaged` steuert RAP weiterhin die Phasenfolge aus **Interaction Phase** (`read`, `create`, `update`, `delete`, Actions, `lock`) und **Save Sequence** (`finalize`, `check_before_save`, `adjust_numbers`, `save`, `cleanup`).
* **Du implementierst nur, was die BDEF deklariert:**
  * **Volles CRUD (`create; update; delete;`):** Alles muss selbst gebaut werden — inklusive eigenem In-Memory-Transaktionspuffer während der Interaction Phase, `read` (auch aus dem Puffer), `lock` (z. B. `ENQUEUE_*`), endgültigem Schreiben in `save` und Aufräumen in `cleanup`.
  * **Minimalfall Action-only (wie `LB-18`):** Deklariert die BDEF nur eine Action (z. B. `importFromOpenLib`) und kein `create/update/delete`, braucht es **keinen** eigenen CRUD-Puffer. Wenn die Action per EML in ein anderes `managed`-BO (`zalm_lb_i_book`) schreibt, übernimmt dieses `managed`-BO innerhalb derselben RAP-LUW die DB-Persistenz.

---

### 11.3 Unterschiede & Einschränkungen im direkten Vergleich

| Bereich | `managed` | `unmanaged` |
|---|---|---|
| **DB-Tabellen-Bindung** | Zwingend (`persistent table ...`) | Optional / meist keine (z. B. Custom Entity oder Legacy-API) |
| **Transaktionspuffer** | Vom Framework bereitgestellt | Selbst zu bauen (z. B. lokale/globale Pufferklasse) |
| **CRUD (`create`, `update`, `delete`, `read`)** | Out-of-the-box fertig | Alles selbst implementieren (inkl. `read` & Assoziations-Reads) |
| **Sperren (`lock`)** | Automatisch über Framework / DB-Lock | Selbst implementieren (z. B. `ENQUEUE`-Bausteine oder leer bei Action-only) |
| **ETag / Optimistic Lock** | Automatisch über `etag master` | Selbst prüfen bzw. im `read` mitliefern |
| **Nummernvergabe (Numbering)** | `early numbering` / `numbering:managed` (UUID) | Immer selbst programmieren (Early oder Late Numbering in `adjust_numbers`) |
| **Draft-Handling (`with draft`)** | Out-of-the-box per Schlüsselwort + Draft-Tabelle | Deutlich aufwändiger bzw. bei Custom Entities i. d. R. nicht sinnvoll |
| **Validations & Determinations** | Laufen automatisch zu definierten Zeitpunkten | Grundsätzlich nutzbar, aber Logik & Pufferkonsistenz liegen in eigener Hand |
| **Fiori Elements / OData V4** | Identisch | Identisch (für das UI verhalten sich beide gleich) |

---

## 12. RAP-Meldungen & Externe APIs (`LB-16` – `LB-18`)

### 12.1 50-Zeichen-Grenze bei `new_message_with_text` (vs. `new_message` mit `T100`)

* **Das Symptom:** Beim Aufruf von `new_message_with_text( severity = ... text = |Buch "{ ls_ol-Title }" wurde in die Bibliothek übernommen.| )` wird der Text im Fiori-UI hart nach exakt **50 Zeichen** abgeschnitten (z. B. `Buch "ABAP RESTful Programming Model" wurde in die`).
* **Die Ursache:** `new_message_with_text` mappt den übergebenen String intern auf ein einzelnes `T100`-Nachrichtenplatzhalter-Feld (`SYMSGV` / `&1`). In SAP hat jedes `T100`-Platzhalterfeld (`MSGV1`–`MSGV4`) maximal **50 Zeichen**.
* **Die saubere Lösung:** Für längere Meldungen eine eigene Nachricht in der Nachrichtenklasse (z. B. `ZALM_LB_MSG`) anlegen:
  ```abap
  " T100-Text in ZALM_LB_MSG (z. B. 010): Buch "&1" wurde in die Bibliothek übernommen.
  %msg = new_message( id       = 'ZALM_LB_MSG'
                      number   = '010'
                      severity = if_abap_behv_message=>severity-success
                      v1       = ls_ol-Title )
  ```
  So hat allein der Buchtitel volle 50 Zeichen in `&1`, während der restliche Satz ungekürzt aus der `T100`-Nachricht kommt.

### 12.2 OpenLibrary Search API: `isbn` fehlt ohne `&fields=...`

* **Das Symptom:** `https://openlibrary.org/search.json?q=...` liefert zwar Titel, Autor und Cover, aber `isbn` bleibt im geparsten Ergebnis immer leer.
* **Die Ursache:** OpenLibrary hat die Standardfelder von `/search.json` reduziert und liefert `isbn` nur noch zurück, wenn es explizit über den Query-Parameter `fields` angefordert wird:
  ```abap
  lv_url = |https://openlibrary.org/search.json?q={ lv_encoded_q }&fields=key,title,author_name,first_publish_year,isbn,cover_i&limit=20|.
  ```

---

## 13. Berechtigungen (`Auth`) in RAP & SAP

### 13.1 Überblick: Wo prüft RAP welche Berechtigung?

In RAP greifen Berechtigungen auf zwei unterschiedlichen Ebenen:

| Ebene | Mechanismus | Zuständig für |
|---|---|---|
| **Lesen (Queries & `READ`)** | **CDS Access Control (`DCL` / `define role`)** | Filtert Datensätze schon beim `SELECT` (z. B. `aspect pfcg_auth( ... )`) — verhindert, dass unberechtigte Zeilen überhaupt geladen werden. |
| **Schreiben & Actions (`CUD` / `action`)** | **Behavior Definition (`authorization master`)** + **`get_global_authorizations` / `get_instance_authorizations`** | Prüft global (darf der User die Operation/Action grundsätzlich?) oder instanzbezogen (darf der User *genau diesen* Datensatz bearbeiten/löschen?). |

* **`global` vs. `instance`:**
  * `authorization master ( global )`: Hängt nur vom Benutzer/Rolle ab (z. B. *„Darf der User überhaupt Bücher aus OpenLibrary importieren?“*).
  * `authorization master ( instance )` (oder `global, instance`): Hängt zusätzlich von Feldern des konkreten Datensatzes ab (z. B. *„Nur eigene Ausleihen stornieren“*).

---

### 13.2 Praxisbeispiel: Action-Berechtigung über `SU21`, `AUTHORITY-CHECK` & `PFCG` (On-Premise)

Auf einem On-Premise-S/4HANA-System (`abapLanguageVersion = standard`) läuft die klassische Berechtigungsprüfung in drei Schritten:

1. **Berechtigungsobjekt anlegen (`SU21`):**
   * In SAP GUI Transaktion `SU21` Objektklasse (z. B. `ZALM`) und Berechtigungsobjekt (z. B. `ZALM_LB_OL`) mit Feld `ACTVT` (z. B. `01` = Anlegen/Hinzufügen) definieren.
2. **Im Behavior Pool prüfen (`get_global_authorizations`):**
   ```abap
   METHOD get_global_authorizations.
     IF requested_authorizations-%action-importFromOpenLib = if_abap_behv=>mk-on.
       AUTHORITY-CHECK OBJECT 'ZALM_LB_OL'
         ID 'ACTVT' FIELD '01'.

       result-%action-importFromOpenLib = COND #(
         WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
         ELSE                   if_abap_behv=>auth-unauthorized ).
     ENDIF.
   ENDMETHOD.
   ```
   * **UI-Effekt:** Fiori Elements wertet das Ergebnis direkt aus — bei `auth-unauthorized` wird der Action-Button im UI automatisch deaktiviert/ausgeblendet und jeder EML-Aufruf blockiert.
3. **Rolle bauen & zuweisen (`PFCG`):**
   * Rolle (z. B. `Z_ALM_LB_LIBRARIAN`) in `PFCG` anlegen → Reiter *Berechtigungen* → Berechtigungsobjekt `ZALM_LB_OL` manuell hinzufügen (`ACTVT = '01'`) → **Generieren** (`Shift+F5`) → Reiter *Benutzer* → User eintragen + **Benutzerabgleich**.

> [!NOTE]
> **Typische Test-Falle (`SAP_ALL`):** Hat der eigene Entwickleruser im Testsystem das Profil `SAP_ALL`, liefert `AUTHORITY-CHECK` immer `sy-subrc = 0` — egal, ob die Rolle zugewiesen ist oder nicht. Für echte Negativ-Tests braucht man einen Testuser ohne `SAP_ALL` (oder prüft das Verhalten im Debugger). *(Hinweis: Auf BTP ABAP Environment / ABAP Cloud wird statt `SU21`/`PFCG` das IAM-Modell mit Authorization Objects in ADT + Business Catalog / Business Role verwendet.)*


