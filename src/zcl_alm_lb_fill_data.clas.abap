CLASS zcl_alm_lb_fill_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_alm_lb_fill_data IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA: lt_books   TYPE STANDARD TABLE OF zalm_lb_book,
          lt_loans   TYPE STANDARD TABLE OF zalm_lb_loan,
          lt_reviews TYPE STANDARD TABLE OF zalm_lb_review,
          lt_members TYPE STANDARD TABLE OF zalm_lb_member,
          lt_status  TYPE STANDARD TABLE OF zalm_lb_lstatus.

    DATA: ts TYPE timestampl.
    GET TIME STAMP FIELD ts.

    DATA(today) = cl_abap_context_info=>get_system_date( ).
    DATA(user)  = cl_abap_context_info=>get_user_technical_name( ).

    " -------------------------------------------------------------
    " 1. Tabellen leeren
    " -------------------------------------------------------------
    DELETE FROM zalm_lb_loan.
    DELETE FROM zalm_lb_review.
    DELETE FROM zalm_lb_book.
    DELETE FROM zalm_lb_member.
    DELETE FROM zalm_lb_lstatus.

    out->write( |1. Bestehende Daten in allen 5 Tabellen geloescht.| ).

    " -------------------------------------------------------------
    " 2. Lookup-Tabelle ZALM_LB_LSTATUS
    " -------------------------------------------------------------
    lt_status = VALUE #(
      ( status_id = 'AC' status_text = 'Ausgeliehen'   is_active_loan = abap_true  is_final = abap_false criticality = 2 )
      ( status_id = 'EX' status_text = 'Verlaengert'    is_active_loan = abap_true  is_final = abap_false criticality = 2 )
      ( status_id = 'OV' status_text = 'Ueberfaellig'   is_active_loan = abap_true  is_final = abap_false criticality = 1 )
      ( status_id = 'RT' status_text = 'Zurueckgegeben' is_active_loan = abap_false is_final = abap_true  criticality = 3 )
      ( status_id = 'LO' status_text = 'Verloren'       is_active_loan = abap_true  is_final = abap_true  criticality = 1 )
    ).
    INSERT zalm_lb_lstatus FROM TABLE @lt_status.
    out->write( |2. Status-Lookup: { lines( lt_status ) } Eintraege eingefuegt.| ).

    " -------------------------------------------------------------
    " 3. Mitglieder ZALM_LB_MEMBER
    " -------------------------------------------------------------
    lt_members = VALUE #(
      ( member_id  = 'MEM-0001'
        first_name = 'Max'
        last_name  = 'Mustermann'
        department = 'IT Architecture'
        email      = 'max.mustermann@zalm.de'
        phone      = '+49 6227 11111'
        building   = 'Gebaeude A'
        city       = 'Walldorf'
        country    = 'DE'
        avatar_url = 'https://i.pravatar.cc/150?img=11'
        max_loans  = 5
        is_blocked = abap_false )

      ( member_id  = 'MEM-0002'
        first_name = 'Anna'
        last_name  = 'Schmidt'
        department = 'Human Resources'
        email      = 'anna.schmidt@zalm.de'
        phone      = '+49 6227 22222'
        building   = 'Gebaeude B'
        city       = 'Heidelberg'
        country    = 'DE'
        avatar_url = 'https://i.pravatar.cc/150?img=5'
        max_loans  = 3
        is_blocked = abap_false )

      ( member_id  = 'MEM-0003'
        first_name = 'Lukas'
        last_name  = 'Weber'
        department = 'Business Consulting'
        email      = 'lukas.weber@zalm.de'
        phone      = '+49 6227 33333'
        building   = 'Gebaeude A'
        city       = 'Mannheim'
        country    = 'DE'
        avatar_url = 'https://i.pravatar.cc/150?img=12'
        max_loans  = 4
        is_blocked = abap_false )

      ( member_id  = 'MEM-0004'
        first_name = 'Sarah'
        last_name  = 'Meier'
        department = 'Sales & Operations'
        email      = 'sarah.meier@zalm.de'
        phone      = '+49 6227 44444'
        building   = 'Gebaeude C'
        city       = 'Karlsruhe'
        country    = 'DE'
        avatar_url = 'https://i.pravatar.cc/150?img=9'
        max_loans  = 2
        is_blocked = abap_true )  " Testfall 3 & 4: Gesperrtes Mitglied!

      ( member_id  = 'MEM-0005'
        first_name = 'Felix'
        last_name  = 'Bauer'
        department = 'Core Development'
        email      = 'felix.bauer@zalm.de'
        phone      = '+49 6227 55555'
        building   = 'Gebaeude A'
        city       = 'Walldorf'
        country    = 'DE'
        avatar_url = 'https://i.pravatar.cc/150?img=60'
        max_loans  = 5
        is_blocked = abap_false )
    ).
    INSERT zalm_lb_member FROM TABLE @lt_members.
    out->write( |3. Mitglieder: { lines( lt_members ) } Eintraege eingefuegt.| ).

    " -------------------------------------------------------------
    " 4. Buecher, Ausleihen und Rezensionen (inkl. 5 Testfaelle)
    " -------------------------------------------------------------
    TRY.
        " --- BUCH 1: Ausgebuchter Klassiker (MED-0001) ---
        " Testfall 1: total_copies = 2, 2 aktive Ausleihen (AC + OV) -> avail_copies = 0
        DATA(lv_b1_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        APPEND VALUE #(
          book_uuid             = lv_b1_uuid
          book_id               = 'MED-0001'
          isbn                  = '9780132350884'
          title                 = 'Clean Code: A Handbook of Agile Software Craftsmanship'
          author                = 'Robert C. Martin'
          category              = 'ARCH'
          publish_year          = '2008'
          page_count            = 464
          price                 = '37.95'
          currency_code         = 'EUR'
          total_copies          = 2
          avail_copies          = 0
          avg_rating            = '4.50'
          cover_url             = 'https://covers.openlibrary.org/b/isbn/9780132350884-M.jpg'
          is_archived           = abap_false
          created_by            = user
          created_at            = ts
          local_last_changed_by = user
          local_last_changed_at = ts
          last_changed_at       = ts
        ) TO lt_books.

        APPEND VALUE #(
          loan_uuid             = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b1_uuid
          loan_no               = 'LN-00001'
          member_id             = 'MEM-0001'
          loan_date             = today - 10
          due_date              = today + 18
          status_id             = 'AC'
          extension_count       = 0
          note                  = 'Standard-Ausleihe fuer Architektur-Gilde'
          local_last_changed_at = ts
        ) TO lt_loans.

        APPEND VALUE #(
          loan_uuid             = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b1_uuid
          loan_no               = 'LN-00002'
          member_id             = 'MEM-0003'
          loan_date             = today - 35
          due_date              = today - 7
          status_id             = 'OV'
          extension_count       = 1
          note                  = '1. Mahnung per Mail versendet'
          local_last_changed_at = ts
        ) TO lt_loans.

        APPEND VALUE #(
          review_uuid           = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b1_uuid
          member_id             = 'MEM-0001'
          rating                = '4.50'
          headline              = 'Pflichtlektuere fuer jeden Entwickler'
          comment_text          = 'Klassiker der Softwareentwicklung. Die Prinzipien zu Namensgebung und kleinen Funktionen bleiben zeitlos relevant.'
          review_date           = today - 5
          local_last_changed_at = ts
        ) TO lt_reviews.

        " --- BUCH 2: Ueberfaellige Ausleihe mit max. Verlaengerungen (MED-0002) ---
        " Testfall 2: due_date in Vergangenheit & extension_count = 2 -> keine 3. Verlaengerung erlaubt
        DATA(lv_b2_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        APPEND VALUE #(
          book_uuid             = lv_b2_uuid
          book_id               = 'MED-0002'
          isbn                  = '9781493221295'
          title                 = 'ABAP to the Future (4th Edition)'
          author                = 'Paul Hardy'
          category              = 'ABAP'
          publish_year          = '2021'
          page_count            = 844
          price                 = '79.95'
          currency_code         = 'EUR'
          total_copies          = 3
          avail_copies          = 2
          avg_rating            = '4.80'
          cover_url             = 'https://covers.openlibrary.org/b/isbn/9781493221295-M.jpg'
          is_archived           = abap_false
          created_by            = user
          created_at            = ts
          local_last_changed_by = user
          local_last_changed_at = ts
          last_changed_at       = ts
        ) TO lt_books.

        APPEND VALUE #(
          loan_uuid             = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b2_uuid
          loan_no               = 'LN-00003'
          member_id             = 'MEM-0005'
          loan_date             = today - 60
          due_date              = today - 4
          status_id             = 'OV'
          extension_count       = 2
          note                  = 'Bereits 2x verlaengert - keine weitere Verlaengerung moeglich'
          local_last_changed_at = ts
        ) TO lt_loans.

        APPEND VALUE #(
          review_uuid           = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b2_uuid
          member_id             = 'MEM-0005'
          rating                = '4.80'
          headline              = 'Umfassendes Nachschlagewerk'
          comment_text          = 'Sehr humorvoll und tiefgruendig geschrieben. Pflicht fuer den modernen ABAP-Entwickler.'
          review_date           = today - 12
          local_last_changed_at = ts
        ) TO lt_reviews.

        " --- BUCH 3: Abweichender Durchschnitt fuer Determination (MED-0003) ---
        " Testfall 4: avg_rating initial 0.00, obwohl 2 Reviews (5.00 und 3.00) existieren
        DATA(lv_b3_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        APPEND VALUE #(
          book_uuid             = lv_b3_uuid
          book_id               = 'MED-0003'
          isbn                  = '9780201633610'
          title                 = 'Design Patterns: Elements of Reusable Object-Oriented Software'
          author                = 'Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides'
          category              = 'ARCH'
          publish_year          = '1994'
          page_count            = 395
          price                 = '54.99'
          currency_code         = 'EUR'
          total_copies          = 4
          avail_copies          = 4
          avg_rating            = '0.00'  " Bewusst 0.00 zum Testen der spateren Determination!
          cover_url             = 'https://covers.openlibrary.org/b/isbn/9780201633610-M.jpg'
          is_archived           = abap_false
          created_by            = user
          created_at            = ts
          local_last_changed_by = user
          local_last_changed_at = ts
          last_changed_at       = ts
        ) TO lt_books.

        APPEND VALUE #(
          review_uuid           = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b3_uuid
          member_id             = 'MEM-0001'
          rating                = '5.00'
          headline              = 'Absolutes Meisterwerk'
          comment_text          = 'Die Ur-Bibel der Softwaremuster. Auch 30 Jahre spaeter ein unverzichtbares Fundament.'
          review_date           = today - 20
          local_last_changed_at = ts
        ) TO lt_reviews.

        APPEND VALUE #(
          review_uuid           = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b3_uuid
          member_id             = 'MEM-0002'
          rating                = '3.00'
          headline              = 'Gute Theorie, aber teils C++-gepraegt'
          comment_text          = 'Wertvolle Muster, aber Code-Beispiele wirken aus heutiger Sicht etwas angestaubt.'
          review_date           = today - 15
          local_last_changed_at = ts
        ) TO lt_reviews.

        " --- BUCH 4: Gesperrtes Mitglied besitzt Buch (MED-0004) ---
        " Testfall 3: MEM-0004 ist gesperrt und besitzt ueberfaellige Ausleihe
        DATA(lv_b4_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        APPEND VALUE #(
          book_uuid             = lv_b4_uuid
          book_id               = 'MED-0004'
          isbn                  = '9781493220458'
          title                 = 'SAP Fiori Elements: Development and Extensibility'
          author                = 'Rene Glavanovits'
          category              = 'FIORI'
          publish_year          = '2021'
          page_count            = 520
          price                 = '74.90'
          currency_code         = 'EUR'
          total_copies          = 3
          avail_copies          = 2
          avg_rating            = '4.00'
          cover_url             = 'https://covers.openlibrary.org/b/isbn/9781493220458-M.jpg'
          is_archived           = abap_false
          created_by            = user
          created_at            = ts
          local_last_changed_by = user
          local_last_changed_at = ts
          last_changed_at       = ts
        ) TO lt_books.

        APPEND VALUE #(
          loan_uuid             = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b4_uuid
          loan_no               = 'LN-00004'
          member_id             = 'MEM-0004'
          loan_date             = today - 45
          due_date              = today - 15
          status_id             = 'OV'
          extension_count       = 1
          note                  = 'Entleiher ist gesperrt wegen Saeumnis'
          local_last_changed_at = ts
        ) TO lt_loans.

        APPEND VALUE #(
          review_uuid           = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b4_uuid
          member_id             = 'MEM-0003'
          rating                = '4.00'
          headline              = 'Sehr praxisorientiert'
          comment_text          = 'Gibt einen tollen Ueberblick ueber OData V4 Annotationen und flexible Erweiterbarkeit.'
          review_date           = today - 8
          local_last_changed_at = ts
        ) TO lt_reviews.

        " --- BUCH 5: Archiviertes Buch (MED-0005) ---
        " Testfall 5: is_archived = 'X' -> darf spaeter nicht editiert oder verliehen werden
        DATA(lv_b5_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        APPEND VALUE #(
          book_uuid             = lv_b5_uuid
          book_id               = 'MED-0005'
          isbn                  = '9783836210002'
          title                 = 'SAP NetWeaver 7.0 - ABAP Grundlagen'
          author                = 'Horst Keller'
          category              = 'ABAP'
          publish_year          = '2007'
          page_count            = 800
          price                 = '49.90'
          currency_code         = 'EUR'
          total_copies          = 1
          avail_copies          = 1
          avg_rating            = '0.00'
          cover_url             = 'https://covers.openlibrary.org/b/isbn/9783836210002-M.jpg'
          is_archived           = abap_true
          created_by            = user
          created_at            = ts
          local_last_changed_by = user
          local_last_changed_at = ts
          last_changed_at       = ts
        ) TO lt_books.

        " --- BUCH 6: Modernes KI-Buch mit Bestand (MED-0006) ---
        DATA(lv_b6_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
        APPEND VALUE #(
          book_uuid             = lv_b6_uuid
          book_id               = 'MED-0006'
          isbn                  = '9781493225286'
          title                 = 'Generative AI and Machine Learning on SAP BTP'
          author                = 'Vijay Vijayasankar'
          category              = 'AI'
          publish_year          = '2024'
          page_count            = 430
          price                 = '89.95'
          currency_code         = 'EUR'
          total_copies          = 5
          avail_copies          = 5
          avg_rating            = '5.00'
          cover_url             = 'https://covers.openlibrary.org/b/isbn/9781493225286-M.jpg'
          is_archived           = abap_false
          created_by            = user
          created_at            = ts
          local_last_changed_by = user
          local_last_changed_at = ts
          last_changed_at       = ts
        ) TO lt_books.

        APPEND VALUE #(
          review_uuid           = cl_system_uuid=>create_uuid_x16_static( )
          book_uuid             = lv_b6_uuid
          member_id             = 'MEM-0005'
          rating                = '5.00'
          headline              = 'State-of-the-Art auf SAP BTP'
          comment_text          = 'Genau zur richtigen Zeit erschienen. Ausfuehrliche Szenarien zum SAP GenAI Hub.'
          review_date           = today - 2
          local_last_changed_at = ts
        ) TO lt_reviews.

      CATCH cx_uuid_error.
        out->write( |Fehler bei der UUID-Generierung!| ).
        RETURN.
    ENDTRY.

    INSERT zalm_lb_book FROM TABLE @lt_books.
    out->write( |4. Buecher: { lines( lt_books ) } Eintraege eingefuegt.| ).

    INSERT zalm_lb_loan FROM TABLE @lt_loans.
    out->write( |5. Ausleihen: { lines( lt_loans ) } Eintraege eingefuegt.| ).

    INSERT zalm_lb_review FROM TABLE @lt_reviews.
    out->write( |6. Rezensionen: { lines( lt_reviews ) } Eintraege eingefuegt.| ).

    out->write( |--- BEFUELLUNG ERFOLGREICH ABGESCHLOSSEN ---| ).
  ENDMETHOD.

ENDCLASS.

