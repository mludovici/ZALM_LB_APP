CLASS lhc_review DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS setInitialReviewData FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Review~setInitialReviewData.
  "! Kurzbeschreibung: Methode berechnet durchschnittl. Rating
  "! Methode Liest alle Rezensionen des Buchs, errechnet den arithmetischen Mittelwert aller Rating-Werte (auf 2 Nachkommastellen gerundet)
  "! und aktualisiert AvgRating am Buch.
    METHODS calculateAvgRating FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Review~calculateAvgRating.
    METHODS validateRating FOR VALIDATE ON SAVE
      IMPORTING keys FOR Review~validateRating.

ENDCLASS.

CLASS lhc_review IMPLEMENTATION.

  METHOD setInitialReviewData.
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
    ENTITY review FIELDS ( ReviewDate ) WITH CORRESPONDING #( keys )
    RESULT DATA(lt_reviews).


    "Mit modernem ABAP kannst man das Update inline per Tabellen-Comprehension schreiben:
    " Statt Hilfstabelle + LOOP + APPEND:
    MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Review
        UPDATE FIELDS ( ReviewDate )
        WITH VALUE #( FOR review IN lt_reviews WHERE ( ReviewDate IS INITIAL )
                        ( %tky       = review-%tky
                          ReviewDate = cl_abap_context_info=>get_system_date( ) ) )
      REPORTED DATA(lt_reported).


*    DATA lt_update TYPE TABLE FOR UPDATE zalm_lb_i_review.
*
*    LOOP AT lt_reviews ASSIGNING FIELD-SYMBOL(<review>).
*      IF <review>-ReviewDate IS INITIAL.
*        <review>-ReviewDate = cl_abap_context_info=>get_system_date( ).
*
*
*        APPEND VALUE #( %tky   = <review>-%tky
*                        ReviewDate =  <review>-ReviewDate )
*                   TO lt_update.
*      ENDIF.
*    ENDLOOP.
*
*    MODIFY ENTITIES OF zalm_lb_i_Book IN LOCAL MODE
*           ENTITY Review
*             UPDATE FIELDS ( ReviewDate )
*             WITH lt_update
*           REPORTED DATA(lt_reported).

  ENDMETHOD.


  METHOD calculateAvgRating.
    " 1. Buch-Schlüssel über Assoziation ermitteln
    " 1. Review -> Buch holen:
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Review BY \_Book
        FIELDS ( BookUuid ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_books).


    DATA lt_book_keys TYPE TABLE FOR READ IMPORT zalm_lb_i_book.
    lt_book_keys = CORRESPONDING #( lt_books MAPPING %tky = %tky ).
    SORT lt_book_keys BY %tky.

    DELETE ADJACENT DUPLICATES FROM lt_book_keys COMPARING %tky.
    " 2. Alle Rezensionen zu diesen Büchern lesen (Schlüssel ist lt_book_keys!)
    " 2. Buch -> alle Reviews holen:
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Book BY \_Review
        FIELDS ( BookUuid Rating ) WITH CORRESPONDING #( lt_book_keys )
      RESULT DATA(lt_reviews).

    DATA lt_update_books TYPE TABLE FOR UPDATE zalm_lb_i_book.
    " 3. Durchschnitt pro Buch ermitteln
    LOOP AT lt_book_keys INTO DATA(ls_book).
      DATA(lv_sum) = CONV decfloat34( 0 ).
      DATA(lv_count) = 0.
      LOOP AT lt_reviews INTO DATA(ls_review) WHERE BookUuid = ls_book-BookUuid.
        lv_sum += ls_review-Rating.
        lv_count += 1.
      ENDLOOP.
      " Division durch 0 abfangen:
      DATA(lv_avg) = COND zalm_lb_t_rating(
                       WHEN lv_count > 0 THEN lv_sum / lv_count
                       ELSE 0 ).
      APPEND VALUE #( %tky      = ls_book-%tky
                      AvgRating = lv_avg )
             TO lt_update_books.
    ENDLOOP.
    " 4. Bücher mit neuem Schnitt aktualisieren
    IF lt_update_books IS NOT INITIAL.
      MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Book
          UPDATE FIELDS ( AvgRating )
          WITH lt_update_books
        REPORTED DATA(lt_reported).
    ENDIF.
  ENDMETHOD.


  "Der elegante 16-Zeiler für calculateAvgRating:
*   METHOD calculateAvgRating.
*    " 1. Bücher der geänderten Reviews ermitteln & Duplikate entfernen
*    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
*      ENTITY Review BY \_Book
*        FIELDS ( BookUuid ) WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_books).
*    SORT lt_books BY %tky.
*    DELETE ADJACENT DUPLICATES FROM lt_books COMPARING %tky.
*    " 2. Alle Rezensionen zu diesen Büchern lesen
*    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
*      ENTITY Book BY \_Review
*        FIELDS ( Rating ) WITH CORRESPONDING #( lt_books )
*      RESULT DATA(lt_reviews).
*    " 3. Alles inline in einem Rutsch berechnen und aktualisieren!
*    MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
*      ENTITY Book
*        UPDATE FIELDS ( AvgRating )
*        WITH VALUE #( FOR book IN lt_books
*          LET count = REDUCE i( INIT n = 0
*                        FOR r IN lt_reviews WHERE ( BookUuid = book-BookUuid )
*                        NEXT n += 1 )
*              sum   = REDUCE zalm_lb_t_rating( INIT s = CONV zalm_lb_t_rating( 0 )
*                        FOR r IN lt_reviews WHERE ( BookUuid = book-BookUuid )
*                        NEXT s += r-Rating )
*          IN ( %tky      = book-%tky
*               AvgRating = COND #( WHEN count > 0 THEN sum / count ELSE 0 ) ) )
*      REPORTED DATA(lt_reported).
*  ENDMETHOD.


  METHOD validateRating.
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Review
        FIELDS ( Rating )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_reviews).

    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Review BY \_Book
        FIELDS ( BookUuid )
        WITH CORRESPONDING #( keys )
      LINK DATA(lt_review_book_links).

    LOOP AT lt_reviews ASSIGNING FIELD-SYMBOL(<ls_review>).
      DATA(ls_link) = VALUE #( lt_review_book_links[ KEY id COMPONENTS source-%tky = <ls_review>-%tky ] OPTIONAL ).

      " Alte Draft-Fehlermeldung für diese Instanz zuerst löschen
      APPEND VALUE #( %tky        = <ls_review>-%tky
                      %state_area = 'VALIDATE_RATING'
                      %path       = COND #( WHEN ls_link IS NOT INITIAL
                                            THEN VALUE #( book-%tky = ls_link-target-%tky ) ) ) TO reported-review.

      IF <ls_review>-Rating > '5.00' OR <ls_review>-Rating < '1.00'.
        APPEND VALUE #( %tky = <ls_review>-%tky ) TO failed-review.

        APPEND VALUE #(
            %tky            = <ls_review>-%tky
            %state_area     = 'VALIDATE_RATING'
            %path           = COND #( WHEN ls_link IS NOT INITIAL
                                    THEN VALUE #( book-%tky = ls_link-target-%tky ) )
            %element-Rating = if_abap_behv=>mk-on
            %msg            = new_message(
                                id       = 'ZALM_LB_MSG'
                                number   = '004'
                                severity = if_abap_behv_message=>severity-error
                                v1       = |{ <ls_review>-Rating }| )
        ) TO reported-review.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_loan DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS setInitialLoanData FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Loan~setInitialLoanData.
    METHODS calculateAvailCopies FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Loan~calculateAvailCopies.
    METHODS validateAvailability FOR VALIDATE ON SAVE
      IMPORTING keys FOR Loan~validateAvailability.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Loan~validateDates.

    METHODS validateMember FOR VALIDATE ON SAVE
      IMPORTING keys FOR Loan~validateMember.
    METHODS returnBook FOR MODIFY
      IMPORTING keys FOR ACTION Loan~returnBook RESULT result.
    METHODS extendLoan FOR MODIFY
      IMPORTING keys FOR ACTION Loan~extendLoan RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Loan RESULT result.

ENDCLASS.

CLASS lhc_loan IMPLEMENTATION.


  METHOD setInitialLoanData.

    READ ENTITIES OF ZALM_LB_I_Book IN LOCAL MODE
    ENTITY Loan FIELDS ( LoanNo LoanDate DueDate StatusId ExtensionCount ) WITH CORRESPONDING #( keys )
    RESULT DATA(lt_loans).

    DATA lt_update TYPE TABLE FOR UPDATE zalm_lb_i_loan.


    SELECT  MAX( LoanNo ) FROM zalm_lb_i_loan WHERE LoanNo IS NOT INITIAL INTO @DATA(loanNo) .

    SELECT MAX( loanno )  FROM zalm_lb_d_loan WHERE loanno IS NOT INITIAL INTO @DATA(lv_max_draft).
    DATA(lv_max_no) = COND #( WHEN lv_max_draft > loanNo
                      THEN lv_max_draft
                      ELSE loanNo ).

    DATA(loan_int_max) = COND i( WHEN lv_max_no IS NOT INITIAL THEN substring_after( val = lv_max_no sub = '-' ) ELSE 0 ).

    LOOP AT lt_loans ASSIGNING FIELD-SYMBOL(<lt_loan>).
      IF <lt_loan>-LoanDate IS INITIAL.
        <lt_loan>-LoanDate = cl_abap_context_info=>get_system_date( ).
      ENDIF.
      IF <lt_loan>-DueDate IS INITIAL.
        <lt_loan>-DueDate = <lt_loan>-LoanDate + 14.
      ENDIF.
      IF <lt_loan>-StatusId IS INITIAL.
        <lt_loan>-StatusId = 'AC'.
      ENDIF.
      IF <lt_loan>-LoanNo IS INITIAL.
        loan_int_max += 1.
        <lt_loan>-LoanNo = |LN-{ loan_int_max WIDTH = 5 PAD = '0' ALIGN = RIGHT }|.
      ENDIF.
      APPEND VALUE #( %tky   = <lt_loan>-%tky
                            LoanNo = <lt_loan>-LoanNo
                            LoanDate = <lt_loan>-LoanDate
                            DueDate =  <lt_loan>-DueDate
                            StatusId = <lt_loan>-StatusId
                            ExtensionCount = 0 )
                   TO lt_update.
    ENDLOOP.


    MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
    ENTITY Loan UPDATE FIELDS ( LoanNo LoanDate DueDate StatusId ExtensionCount  )
              WITH lt_update
            REPORTED DATA(lt_reported).
  ENDMETHOD.

  METHOD calculateAvailCopies.
    " 1. Betroffene Bücher über Eltern-Assoziation ermitteln
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Loan BY \_Book
        FIELDS ( BookUuid )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_book_links).

    DATA lt_book_keys TYPE TABLE FOR READ IMPORT zalm_lb_i_book.

    lt_book_keys = CORRESPONDING #( lt_book_links MAPPING %tky = %tky ).
    SORT lt_book_keys BY %tky.
    DELETE ADJACENT DUPLICATES FROM lt_book_keys COMPARING %tky.
    " 2. Bücher (TotalCopies) und alle zugehörigen Ausleihen lesen
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Book
        FIELDS ( TotalCopies )
        WITH CORRESPONDING #( lt_book_keys )
      RESULT DATA(lt_books).

    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Book BY \_Loan
        FIELDS ( BookUuid StatusId )
        WITH CORRESPONDING #( lt_book_keys )
      RESULT DATA(lt_all_loans).

    " 1. Alle Status holen, die laut Customizing-Tabelle als 'aktiv' gelten
    SELECT status_id
      FROM zalm_lb_lstatus
      WHERE is_active_loan = @abap_true
      INTO TABLE @DATA(lt_active_statuses).

    " 3. Aktive Ausleihen ('AC', 'EX', 'OD') zählen und Bestand berechnen
    DATA lt_update_books TYPE TABLE FOR UPDATE zalm_lb_i_book.

    LOOP AT lt_books INTO DATA(ls_book).
      DATA(lv_active_loans) = 0.
      LOOP AT lt_all_loans INTO DATA(ls_loan) WHERE BookUuid = ls_book-BookUuid.
        IF line_exists( lt_active_statuses[ status_id = ls_loan-StatusId ] ).
          lv_active_loans += 1.
        ENDIF.
      ENDLOOP.
      DATA(lv_avail) = ls_book-TotalCopies - lv_active_loans.
      IF lv_avail < 0.
        lv_avail = 0.
      ENDIF.
      APPEND VALUE #( %tky        = ls_book-%tky
                      AvailCopies = lv_avail )
             TO lt_update_books.
    ENDLOOP.
    " 4. Bücher mit neuem Bestand aktualisieren
    IF lt_update_books IS NOT INITIAL.
      MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Book
          UPDATE FIELDS ( AvailCopies )
          WITH lt_update_books
        REPORTED DATA(lt_reported).
    ENDIF.
  ENDMETHOD.

  "eleganter für calculateAvailCopies:
*    METHOD calculateAvailCopies.
*    " 1. Bücher der geänderten Ausleihen ermitteln
*    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
*      ENTITY Loan BY \_Book
*        FIELDS ( BookUuid ) WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_books).
*    SORT lt_books BY %tky.
*    DELETE ADJACENT DUPLICATES FROM lt_books COMPARING %tky.
*    " 2. Bücher (TotalCopies) und Ausleihen lesen
*    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
*      ENTITY Book FIELDS ( TotalCopies ) WITH CORRESPONDING #( lt_books )
*      RESULT DATA(lt_book_data).
*    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
*      ENTITY Book BY \_Loan FIELDS ( StatusId ) WITH CORRESPONDING #( lt_books )
*      RESULT DATA(lt_loans).
*    " Aktive Status dynamisch aus Tabelle (ohne Hardcoding)
*    SELECT status_id FROM zalm_lb_lstatus WHERE is_active_loan = @abap_true INTO TABLE @DATA(lt_active).
*    " 3. Alles inline berechnen und updaten
*    MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
*      ENTITY Book
*        UPDATE FIELDS ( AvailCopies )
*        WITH VALUE #( FOR book IN lt_book_data
*          LET active = REDUCE i( INIT n = 0
*                         FOR l IN lt_loans WHERE ( BookUuid = book-BookUuid )
*                         NEXT n += COND #( WHEN line_exists( lt_active[ status_id = l-StatusId ] ) THEN 1 ELSE 0 ) )
*              avail  = book-TotalCopies - active
*          IN ( %tky        = book-%tky
*               AvailCopies = nmax( val1 = 0 val2 = avail ) ) )
*      REPORTED DATA(lt_reported).
*  ENDMETHOD.

  METHOD validateAvailability.
    " 1. Buch über Eltern-Assoziation inkl. LINK (Loan-%tky <-> Book-%tky) lesen
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Loan BY \_Book
        FIELDS ( BookUuid Title TotalCopies )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_books)
      LINK DATA(lt_loan_book_links).

    IF lt_books IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Alle Ausleihen der betroffenen Bücher + aktive Status lesen
    DATA lt_book_keys TYPE TABLE FOR READ IMPORT zalm_lb_i_book.
    lt_book_keys = CORRESPONDING #( lt_books MAPPING %tky = %tky ).
    SORT lt_book_keys BY %tky.
    DELETE ADJACENT DUPLICATES FROM lt_book_keys COMPARING %tky.

    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Book BY \_Loan
        FIELDS ( BookUuid StatusId )
        WITH CORRESPONDING #( lt_book_keys )
      RESULT DATA(lt_all_loans).

    SELECT status_id
      FROM zalm_lb_lstatus
      WHERE is_active_loan = @abap_true
      INTO TABLE @DATA(lt_active_statuses).

    " 3. Pro übergebener Loan-Instanz prüfen & Fehler an LOAN melden
    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_link) = VALUE #( lt_loan_book_links[ KEY id COMPONENTS source-%tky = ls_key-%tky ] OPTIONAL ).
      DATA(ls_book) = VALUE #( lt_books[ KEY id COMPONENTS %tky = ls_link-target-%tky ] OPTIONAL ).

      APPEND VALUE #( %tky        = ls_key-%tky
                      %state_area = 'VALIDATE_AVAILABILITY'
                      %path       = COND #( WHEN ls_link IS NOT INITIAL
                                            THEN VALUE #( book-%tky = ls_link-target-%tky ) ) ) TO reported-loan.

      IF ls_book IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_active_loans) = 0.
      LOOP AT lt_all_loans INTO DATA(ls_loan) WHERE BookUuid = ls_book-BookUuid.
        IF line_exists( lt_active_statuses[ status_id = ls_loan-StatusId ] ).
          lv_active_loans += 1.
        ENDIF.
      ENDLOOP.

      IF lv_active_loans > ls_book-TotalCopies OR ls_book-TotalCopies <= 0.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-loan.

        APPEND VALUE #(
            %tky        = ls_key-%tky
            %state_area = 'VALIDATE_AVAILABILITY'
            %path       = VALUE #( book-%tky = ls_link-target-%tky )
            %msg        = new_message(
                            id       = 'ZALM_LB_MSG'
                            number   = '003'
                            severity = if_abap_behv_message=>severity-error
                            v1       = ls_book-Title )
        ) TO reported-loan.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    "DueDate muss >= LoanDate sein; ReturnDate (falls gefüllt) muss >= LoanDate sein.
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Loan
        FIELDS ( LoanDate DueDate ReturnDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_loans).

    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Loan BY \_Book
        FIELDS ( BookUuid )
        WITH CORRESPONDING #( keys )
      LINK DATA(lt_loan_book_links).

    LOOP AT lt_loans ASSIGNING FIELD-SYMBOL(<ls_loan>).
      DATA(ls_link) = VALUE #( lt_loan_book_links[ KEY id COMPONENTS source-%tky = <ls_loan>-%tky ] OPTIONAL ).

      APPEND VALUE #( %tky        = <ls_loan>-%tky
                      %state_area = 'VALIDATE_DATES'
                      %path       = COND #( WHEN ls_link IS NOT INITIAL
                                            THEN VALUE #( book-%tky = ls_link-target-%tky ) ) ) TO reported-loan.

      DATA(lv_has_error) = abap_false.

      IF <ls_loan>-DueDate IS NOT INITIAL AND <ls_loan>-DueDate < <ls_loan>-LoanDate.
        lv_has_error = abap_true.
        APPEND VALUE #(
            %tky             = <ls_loan>-%tky
            %state_area      = 'VALIDATE_DATES'
            %path            = COND #( WHEN ls_link IS NOT INITIAL
                                       THEN VALUE #( book-%tky = ls_link-target-%tky ) )
            %element-DueDate = if_abap_behv=>mk-on
            %msg             = new_message(
                                 id       = 'ZALM_LB_MSG'
                                 number   = '001'
                                 severity = if_abap_behv_message=>severity-error
                                 v1       = |{ <ls_loan>-DueDate DATE = USER }|
                                 v2       = |{ <ls_loan>-LoanDate DATE = USER }| )
        ) TO reported-loan.
      ENDIF.

      IF <ls_loan>-ReturnDate IS NOT INITIAL AND <ls_loan>-ReturnDate < <ls_loan>-LoanDate.
        lv_has_error = abap_true.
        APPEND VALUE #(
            %tky                = <ls_loan>-%tky
            %state_area         = 'VALIDATE_DATES'
            %path               = COND #( WHEN ls_link IS NOT INITIAL
                                          THEN VALUE #( book-%tky = ls_link-target-%tky ) )
            %element-ReturnDate = if_abap_behv=>mk-on
            %msg                = new_message(
                                    id       = 'ZALM_LB_MSG'
                                    number   = '001'
                                    severity = if_abap_behv_message=>severity-error
                                    v1       = |{ <ls_loan>-ReturnDate DATE = USER }|
                                    v2       = |{ <ls_loan>-LoanDate DATE = USER }| )
        ) TO reported-loan.
      ENDIF.

      IF lv_has_error = abap_true.
        APPEND VALUE #( %tky = <ls_loan>-%tky ) TO failed-loan.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateMember.
    "Prüft _Member.is_blocked. Ist das Mitglied gesperrt, Meldung 002 auslösen.
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Loan
        FIELDS ( MemberId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_loans).

    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Loan BY \_Book
        FIELDS ( BookUuid )
        WITH CORRESPONDING #( keys )
      LINK DATA(lt_loan_book_links).

    LOOP AT lt_loans ASSIGNING FIELD-SYMBOL(<ls_loan>).
      DATA(ls_link) = VALUE #( lt_loan_book_links[ KEY id COMPONENTS source-%tky = <ls_loan>-%tky ] OPTIONAL ).

      APPEND VALUE #( %tky        = <ls_loan>-%tky
                      %state_area = 'VALIDATE_MEMBER'
                      %path       = COND #( WHEN ls_link IS NOT INITIAL
                                            THEN VALUE #( book-%tky = ls_link-target-%tky ) ) ) TO reported-loan.

      IF <ls_loan>-MemberId IS INITIAL.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FullName, IsBlocked
        FROM zalm_lb_i_member
        WHERE MemberId = @<ls_loan>-MemberId
        INTO @DATA(ls_member).

      IF sy-subrc = 0 AND ls_member-IsBlocked = abap_true.
        APPEND VALUE #( %tky = <ls_loan>-%tky ) TO failed-loan.
        APPEND VALUE #(
            %tky              = <ls_loan>-%tky
            %state_area       = 'VALIDATE_MEMBER'
            %path             = COND #( WHEN ls_link IS NOT INITIAL
                                        THEN VALUE #( book-%tky = ls_link-target-%tky ) )
            %element-MemberId = if_abap_behv=>mk-on
            %msg              = new_message(
                                  id       = 'ZALM_LB_MSG'
                                  number   = '002'
                                  severity = if_abap_behv_message=>severity-error
                                  v1       = |{ <ls_loan>-MemberId }|
                                  v2       = |{ ls_member-FullName }| )
        ) TO reported-loan.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.



  METHOD extendloan.
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
    ENTITY loan ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_loans).

    DATA lt_update TYPE TABLE FOR UPDATE zalm_lb_i_loan.

    " 2. Über KEYS loopen (nur hier steckt %param drin!) und lt_loans dazumappen
    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_loan) = VALUE #( lt_loans[ KEY id COMPONENTS %tky = ls_key-%tky ] OPTIONAL ).
      IF ls_loan IS INITIAL.
        CONTINUE.
      ENDIF.


      " Prüfung 1: Pflichtparameter Begründung
      IF ls_key-%param-Reason IS INITIAL.
        APPEND VALUE #( %tky = ls_loan-%tky ) TO failed-loan.
        APPEND VALUE #( %tky = ls_loan-%tky
                        %msg = new_message(
                                 id       = 'ZALM_LB_MSG'
                                 number   = '009' " freie Meldung: Begründung angeben
                                 severity = if_abap_behv_message=>severity-error ) )
               TO reported-loan.
        CONTINUE.
      ENDIF.

      " Prüfung 2: Nur AC / EX dürfen verlängert werden
      IF ls_loan-StatusId <> 'AC' AND ls_loan-StatusId <> 'EX'.
        APPEND VALUE #( %tky = ls_loan-%tky ) TO failed-loan.
        APPEND VALUE #( %tky              = ls_loan-%tky
                        %element-StatusId = if_abap_behv=>mk-on
                        %msg              = new_message(
                                              id       = 'ZALM_LB_MSG'
                                              number   = '007'
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = |{ ls_loan-StatusId }| ) )
               TO reported-loan.
        CONTINUE.
      ENDIF.

      " Prüfung 3: Max. 2 Verlängerungen (ab 2 ablehnen!)
      IF ls_loan-ExtensionCount >= 2.
        APPEND VALUE #( %tky = ls_loan-%tky ) TO failed-loan.
        APPEND VALUE #( %tky                    = ls_loan-%tky
                        %element-ExtensionCount = if_abap_behv=>mk-on
                        %msg                    = new_message(
                                                    id       = 'ZALM_LB_MSG'
                                                    number   = '008'
                                                    severity = if_abap_behv_message=>severity-error
                                                    v1       = |{ ls_loan-ExtensionCount }| ) )
               TO reported-loan.
        CONTINUE.
      ENDIF.

      " 3. Neue Werte für das Update vormerken
      DATA(lv_new_count) = ls_loan-ExtensionCount + 1.
      DATA(lv_base_date) = COND d( WHEN ls_loan-DueDate IS NOT INITIAL
                                   THEN ls_loan-DueDate
                                   ELSE cl_abap_context_info=>get_system_date( ) ).
      DATA(lv_new_due)   = CONV d( lv_base_date + 14 ).
      DATA(lv_new_note)  = COND string( WHEN ls_loan-Note IS INITIAL
                                        THEN |[Verl. { lv_new_count }] { ls_key-%param-Reason }|
                                        ELSE |{ ls_loan-Note } / [Verl. { lv_new_count }] { ls_key-%param-Reason }| ).
      APPEND VALUE #( %tky           = ls_loan-%tky
                      DueDate        = lv_new_due
                      ExtensionCount = lv_new_count
                      StatusId       = 'EX'
                      Note           = lv_new_note )
             TO lt_update.
    ENDLOOP.
    " 4. Alle gültigen Zeilen gesammelt updaten, nachlesen & in result zurückgeben
    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Loan
          UPDATE FIELDS ( DueDate ExtensionCount StatusId Note )
          WITH lt_update.
      READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Loan
          ALL FIELDS WITH CORRESPONDING #( lt_update )
        RESULT DATA(lt_updated_loans).
      result = VALUE #( FOR ls_upd IN lt_updated_loans
                        ( %tky   = ls_upd-%tky
                          %param = ls_upd ) ).
    ENDIF.


*    LOOP AT lt_loans ASSIGNING FIELD-SYMBOL(<ls_loan>).
*      DATA(ls_key) = VALUE #( keys[ %tky = <ls_loan>-%tky ] OPTIONAL ).
*      " Klassisch geschrieben exakt dasselbe wie:
*      " READ TABLE keys INTO DATA(ls_key) WITH KEY %tky = <ls_loan>-%tky.
*      IF ls_key-%param-Reason IS INITIAL.
*        ...
*      ENDIF.
*      IF <ls_loan>-StatusId = 'OV' OR <ls_loan>-StatusId = 'RT' OR <ls_loan>-StatusId = 'LO'.
*        APPEND VALUE #( %tky = <ls_loan>-%tky ) TO Failed-loan.
*        APPEND VALUE #( %tky = <ls_loan>-%tky
*              %state_area       = 'ACTION_EXTENDLOAN'
*              %element-StatusId = if_abap_behv=>mk-on
*              %msg              = new_message(
*                                    id       = 'ZALM_LB_MSG'
*                                    number   = '007'
*                                    severity = if_abap_behv_message=>severity-error
*                                    v1       = |{ <ls_loan>-StatusId }| )
*              ) TO reported-loan.
*
*        "Prüfen: StatusId muss AC oder EX sein (OV, RT oder LO → Ablehnung mit Fehlermeldung in ZALM_LB_MSG).
*    "Prüfen: ExtensionCount < 2 (max. 2× verlängerbar gemäß Prozessmodell.md — ab der 3. Anfrage ablehnen).
*      ELSEIF <ls_loan>-StatusId = 'AC' OR <ls_loan>-StatusId = 'EX' AND <ls_loan>-ExtensionCount < 2.


  ENDMETHOD.

  METHOD returnBook.
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Loan ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_loans).

    DATA lt_update TYPE TABLE FOR UPDATE zalm_lb_i_loan.

    LOOP AT lt_loans ASSIGNING FIELD-SYMBOL(<ls_loan>).
      IF <ls_loan>-StatusId = 'AC' OR <ls_loan>-StatusId = 'EX' OR <ls_loan>-StatusId = 'OV'.
        APPEND VALUE #( %tky       = <ls_loan>-%tky
                        StatusId   = 'RT'
                        ReturnDate = cl_abap_context_info=>get_system_date( ) )
               TO lt_update.
      ELSE.
        APPEND VALUE #( %tky = <ls_loan>-%tky ) TO failed-loan.
        APPEND VALUE #( %tky              = <ls_loan>-%tky
                        %element-StatusId = if_abap_behv=>mk-on
                        %msg              = new_message(
                                              id       = 'ZALM_LB_MSG'
                                              number   = '007'
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = |{ <ls_loan>-StatusId }| ) )
               TO reported-loan.
      ENDIF.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Loan UPDATE FIELDS ( StatusId ReturnDate ) WITH lt_update.

      READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Loan ALL FIELDS WITH CORRESPONDING #( lt_update )
        RESULT DATA(lt_updated_loans).

      result = VALUE #( FOR ls_loan IN lt_updated_loans
                        ( %tky = ls_loan-%tky %param = ls_loan ) ).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_features.
    "%action-returnBook: fc-o-enabled nur bei StatusId = 'AC' OR StatusId = 'EX' OR StatusId = 'OV'; bei RT oder LO → fc-o-disabled.
    "%action-extendLoan: fc-o-enabled nur bei ( StatusId = 'AC' OR StatusId = 'EX' ) AND ExtensionCount < 2; bei OV, RT, LO oder ExtensionCount >= 2 → fc-o-disabled.
    "Falls update/delete auf Loan mit ( features : instance )): Finale Sätze (RT, LO) auf fc-o-disabled setzen.
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
    ENTITY loan FIELDS ( StatusId ExtensionCount ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_loans).

    LOOP AT lt_loans ASSIGNING FIELD-SYMBOL(<ls_loan>).

      DATA(is_active_loan) = xsdbool( <ls_loan>-StatusId = 'AC'
                               OR <ls_loan>-StatusId = 'EX'
                               OR <ls_loan>-StatusId = 'OV' ).
      DATA(extend_loan_possible) = xsdbool( ( <ls_loan>-StatusId = 'AC' OR <ls_loan>-StatusId = 'EX' ) AND <ls_loan>-ExtensionCount < 2 ).
      DATA(is_final) = xsdbool( <ls_loan>-StatusId = 'RT' OR <ls_loan>-StatusId = 'LO' ).

      APPEND VALUE #(
          %tky             = <ls_loan>-%tky
          %action-returnBook = COND #( WHEN is_active_loan = abap_true
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled )
          %action-extendLoan          = COND #( WHEN extend_loan_possible = abap_true
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled )
          %update          =   COND #( WHEN is_final = abap_true
                                      THEN if_abap_behv=>fc-o-disabled
                                      ELSE if_abap_behv=>fc-o-enabled )
          %delete          = COND #( WHEN is_final = abap_true
                                      THEN if_abap_behv=>fc-o-disabled
                                      ELSE if_abap_behv=>fc-o-enabled )
        ) TO result.
    ENDLOOP.


  ENDMETHOD.

ENDCLASS.

CLASS lhc_Book DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Book RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Book RESULT result.
    METHODS determineBookId FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Book~determineBookId.
    METHODS calculateAvailCopies FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Book~calculateAvailCopies.
    METHODS lendBook FOR MODIFY
      IMPORTING keys FOR ACTION Book~lendBook RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Book RESULT result.
    METHODS duplicatebook FOR MODIFY
      IMPORTING keys FOR ACTION book~duplicatebook.
    METHODS getlibrarykpis FOR READ
      IMPORTING keys FOR FUNCTION book~getlibrarykpis RESULT result.


ENDCLASS.

CLASS lhc_Book IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD determineBookId.
    " 1. Zu modifizierende Bücher lesen
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Book
        FIELDS ( BookId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_books).

    " Nur fortfahren, wenn mindestens ein Buch keine ID hat
    DELETE lt_books WHERE BookId IS NOT INITIAL.
    IF lt_books IS INITIAL.
      RETURN.
    ENDIF.

    " 2. Höchste BookId aus aktiver Tabelle und Draft-Tabelle ermitteln
    SELECT MAX( book_id ) FROM zalm_lb_book   INTO @DATA(lv_max_active).
    SELECT MAX( bookid )  FROM zalm_lb_d_book INTO @DATA(lv_max_draft).
    DATA(lv_max_id) = COND #( WHEN lv_max_draft > lv_max_active
                              THEN lv_max_draft
                              ELSE lv_max_active ).
    DATA(lv_number) = COND i( WHEN lv_max_id IS NOT INITIAL
                              THEN substring_after( val = lv_max_id sub = '-' )
                              ELSE 0 ).

    " 3. Neue IDs vergeben und gesammelt per EML aktualisieren
    DATA lt_update TYPE TABLE FOR UPDATE zalm_lb_i_book.
    LOOP AT lt_books ASSIGNING FIELD-SYMBOL(<book>).
      lv_number += 1.
      APPEND VALUE #( %tky   = <book>-%tky
                      BookId = |MED-{ lv_number WIDTH = 4 PAD = '0' ALIGN = RIGHT }| )
             TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
          ENTITY Book
            UPDATE FIELDS ( BookId )
            WITH lt_update
          REPORTED DATA(lt_reported).


  ENDMETHOD.



  METHOD calculateAvailCopies.
    "Methode TotalAvail copies neu berechnet wenn z.B Buch hinzugefügt wird
    " Hier sind wir schon auf Book! Direkt Buch und dessen Ausleihen lesen
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Book
        FIELDS ( TotalCopies )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_books).

    "Suche die Loans raus die implizit dieselbe BookUUID haben
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
      ENTITY Book BY \_Loan
        FIELDS ( BookUuid StatusId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_all_loans).

    " 1. Alle Status holen, die laut Customizing-Tabelle als 'aktiv' gelten
    SELECT status_id
      FROM zalm_lb_lstatus
      WHERE is_active_loan = @abap_true
      INTO TABLE @DATA(lt_active_statuses).

    DATA lt_update_books TYPE TABLE FOR UPDATE zalm_lb_i_book.

    LOOP AT lt_books INTO DATA(ls_book).
      DATA(lv_active_loans) = 0.
      LOOP AT lt_all_loans INTO DATA(ls_loan) WHERE BookUuid = ls_book-BookUuid.
        IF line_exists( lt_active_statuses[ status_id = ls_loan-StatusId ] ).
          lv_active_loans += 1.
        ENDIF.
      ENDLOOP.
      DATA(lv_avail) = ls_book-TotalCopies - lv_active_loans.
      IF lv_avail < 0.
        lv_avail = 0.
      ENDIF.
      APPEND VALUE #( %tky        = ls_book-%tky
                      AvailCopies = lv_avail )
             TO lt_update_books.
    ENDLOOP.
    IF lt_update_books IS NOT INITIAL.
      MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Book
          UPDATE FIELDS ( AvailCopies )
          WITH lt_update_books
        REPORTED DATA(lt_reported).
    ENDIF.
  ENDMETHOD.

  METHOD lendBook.

    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
    ENTITY Book ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_books).

    DATA lt_create_loans TYPE TABLE FOR CREATE zalm_lb_i_book\_Loan.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_book) = VALUE #( lt_books[ KEY id COMPONENTS %tky = ls_key-%tky ] OPTIONAL ).
      IF ls_book IS INITIAL.
        CONTINUE.
      ENDIF.
      "Prüfen: DueDate >= LoanDate

      IF ls_key-%param-LoanDate IS INITIAL.
        ls_key-%param-LoanDate = cl_abap_context_info=>get_system_date( ).
      ENDIF.
      IF ls_key-%param-DueDate IS INITIAL.
        ls_key-%param-DueDate = ls_key-%param-LoanDate + 14.
      ENDIF.

      IF ls_key-%param-DueDate < ls_key-%param-LoanDate.
        APPEND VALUE #( %tky = ls_book-%tky ) TO failed-book.
        APPEND VALUE #( %tky = ls_book-%tky
        %msg = NEW zcm_alm_lb( textid    = zcm_alm_lb=>dates_invalid
        severity = if_abap_behv_message=>severity-error
        attr1 = |{ ls_key-%param-DueDate DATE = USER }|
        attr2 = |{ ls_key-%param-LoanDate DATE = USER }| ) ) TO reported-book.
        CONTINUE.
      ENDIF.

      "Eingaben prüfen: MemberId darf nicht initial sein; in ZALM_LB_MEMBER prüfen,
      "ob Mitglied existiert und IsBlocked initial ist; DueDate >= LoanDate prüfen.
      "Server-seitigen Bestands-Guard auf dem Book (und ggf. Draft-_Loan-Einträgen) ausführen:
      "Sind noch Exemplare frei (AvailCopies > 0 bzw. aktive Loans < TotalCopies)?

      IF ls_book-AvailCopies <= 0.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-book.
        APPEND VALUE #( %tky = ls_key-%tky
        %msg = NEW zcm_alm_lb( textid    = zcm_alm_lb=>book_out_of_stock
        severity = if_abap_behv_message=>severity-error
        attr1 = | { ls_book-Title }| ) ) TO reported-book.
        CONTINUE.
      ENDIF.
      IF ls_book-IsArchived = abap_true.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-book.
        APPEND VALUE #( %tky = ls_key-%tky
        %msg = NEW zcm_alm_lb( textid    = zcm_alm_lb=>book_is_archived
        severity = if_abap_behv_message=>severity-error
        attr1 = |{ ls_book-Title }| ) ) TO reported-book.
        CONTINUE.
      ENDIF.

      SELECT SINGLE MemberId, IsBlocked, FullName FROM zalm_lb_i_member WHERE MemberId = @ls_key-%param-MemberId INTO @DATA(found_member).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-book.
        APPEND VALUE #( %tky = ls_key-%tky
        %msg = new_message( id =  'ZALM_LB_MSG'
        number = '010'
        severity = if_abap_behv_message=>severity-error
        v1 = | { ls_key-%param-MemberId }| ) ) TO reported-book.
        CONTINUE.
      ELSEIF found_member-IsBlocked = abap_true.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-book.
        APPEND VALUE #( %tky = ls_key-%tky
        %msg = new_message( id =  'ZALM_LB_MSG'
        number = '002'
        severity = if_abap_behv_message=>severity-error
        v1 = |{ found_member-MemberId }|
        v2 = found_member-FullName ) ) TO reported-book.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %tky    = ls_key-%tky
        %target = VALUE #( (
          %is_draft = ls_key-%is_draft
          MemberId  = ls_key-%param-MemberId
          LoanDate  = ls_key-%param-LoanDate
          DueDate   = ls_key-%param-DueDate
          StatusId  = 'AC'
          Note      = ls_key-%param-Note ) )
      ) TO lt_create_loans.

    ENDLOOP.

    IF lt_create_loans IS NOT INITIAL.
      MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Book
          CREATE BY \_Loan
          AUTO FILL CID
          FIELDS ( MemberId LoanDate DueDate StatusId Note )
          WITH lt_create_loans
        MAPPED DATA(lt_mapped)
        FAILED DATA(lt_failed).
      READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Book
          ALL FIELDS WITH CORRESPONDING #( lt_create_loans )
        RESULT DATA(lt_updated_books).
      result = VALUE #( FOR ls_upd IN lt_updated_books
                        ( %tky = ls_upd-%tky %param = ls_upd ) ).
    ENDIF.

    "(Hinweis: LoanNo und ExtensionCount übernimmt ggf. setInitialLoanData auf Loan, StatusId = 'AC' explizit mitgeben.)
    "Aktualisiertes Book lesen und über result zurückgeben.
    "DATA lt_update_loans TYPE TABLE FOR ZALM_LB_I_BOOK
*    MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
*    ENTITY Book
*        CREATE BY \_Loan
*        AUTO FILL CID
*        FIELDS ( MemberId LoanDate DueDate StatusId Note )
*        WITH VALUE #( ( MemberId        = ls_key-%param-MemberId
*                    LoanDate       = ls_key-%param-LoanDate
*                    DueDate     = ls_key-%param-DueDate
*                    StatusId        = 'AC'
*                    Note = ls_key-%param-Note ) )
*  MAPPED DATA(lt_mapped)
*  FAILED DATA(lt_failed).


  ENDMETHOD.

  METHOD get_instance_features.

    "Aktuelle Daten lesen
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
    ENTITY book FIELDS ( AvailCopies IsArchived ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_books).

    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE
          ENTITY Book BY \_Loan
            FIELDS ( BookUuid StatusId )
            WITH CORRESPONDING #( keys )
          RESULT DATA(lt_loans).


    " 2. Pro Buch eine Zeile in result anhängen
    LOOP AT lt_books ASSIGNING FIELD-SYMBOL(<ls_book>).
      DATA(lv_has_active_loans) = xsdbool(
        line_exists( lt_loans[ BookUuid = <ls_book>-BookUuid StatusId = 'AC' ] ) OR
        line_exists( lt_loans[ BookUuid = <ls_book>-BookUuid StatusId = 'EX' ] ) OR
        line_exists( lt_loans[ BookUuid = <ls_book>-BookUuid StatusId = 'OV' ] ) ).
      APPEND VALUE #(
        %tky             = <ls_book>-%tky
        %action-lendBook = COND #( WHEN <ls_book>-AvailCopies <= 0 OR <ls_book>-IsArchived = abap_true
                                   THEN if_abap_behv=>fc-o-disabled
                                   ELSE if_abap_behv=>fc-o-enabled )
        %action-duplicateBook = if_abap_behv=>fc-o-enabled
        %delete          = COND #( WHEN lv_has_active_loans = abap_true
                                   THEN if_abap_behv=>fc-o-disabled
                                   ELSE if_abap_behv=>fc-o-enabled )
        %update          = if_abap_behv=>fc-o-enabled
      ) TO result.
    ENDLOOP.

    "Oder:
*    result = VALUE #(
*      FOR ls_book IN lt_books
*      LET lv_has_active_loans = xsdbool(
*            line_exists( lt_loans[ BookUuid = ls_book-BookUuid StatusId = 'AC' ] ) OR
*            line_exists( lt_loans[ BookUuid = ls_book-BookUuid StatusId = 'EX' ] ) OR
*            line_exists( lt_loans[ BookUuid = ls_book-BookUuid StatusId = 'OV' ] ) )
*      IN (
*        %tky             = ls_book-%tky
*        %action-lendBook = COND #( WHEN ls_book-AvailCopies <= 0 OR ls_book-IsArchived = abap_true
*                                   THEN if_abap_behv=>fc-o-disabled
*                                   ELSE if_abap_behv=>fc-o-enabled )
*        %delete          = COND #( WHEN lv_has_active_loans = abap_true
*                                   THEN if_abap_behv=>fc-o-disabled
*                                   ELSE if_abap_behv=>fc-o-enabled )
*      ) ).
  ENDMETHOD.

  METHOD duplicateBook.
    READ ENTITIES OF zalm_lb_i_book IN LOCAL MODE ENTITY Book ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_books).

    DATA lt_create TYPE TABLE FOR CREATE zalm_lb_i_book.
    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_book) = VALUE #( lt_books[ KEY id COMPONENTS %tky = ls_key-%tky ] OPTIONAL ).
      IF ls_book IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %cid         = ls_key-%cid
        %is_draft    = ls_key-%is_draft
        Title        = |{ ls_book-Title } (Kopie)|
        Author       = ls_book-Author
        Category     = ls_book-Category
        PublishYear  = ls_book-PublishYear
        PageCount    = ls_book-PageCount
        Price        = ls_book-Price
        CurrencyCode = ls_book-CurrencyCode
        TotalCopies  = ls_book-TotalCopies
        AvailCopies  = ls_book-TotalCopies
        CoverUrl     = ls_book-CoverUrl
        AvgRating    = 0
        IsArchived   = abap_false
      ) TO lt_create.
    ENDLOOP.

    IF lt_create IS NOT INITIAL.
      MODIFY ENTITIES OF zalm_lb_i_book IN LOCAL MODE
        ENTITY Book
          CREATE FIELDS ( Title Author Category PublishYear PageCount Price
                          CurrencyCode TotalCopies AvailCopies CoverUrl
                          AvgRating IsArchived )
          WITH lt_create
        MAPPED   DATA(ls_created)
        FAILED   DATA(ls_failed)
        REPORTED DATA(ls_reported).

      mapped-book   = ls_created-book.
      failed-book   = ls_failed-book.
      reported-book = ls_reported-book.
    ENDIF.
  ENDMETHOD.


  METHOD getLibraryKpis.
  "In lhc_Book~getLibraryKpis: Kennzahlen aus ZALM_LB_I_BOOK und
  "ZALM_LB_I_LOAN aggregieren (OverdueLoans auf StatusId = 'OV'!) und als genau 1 Ergebniszeile in result zurückgeben.
  SELECT SINGLE
      COUNT( * )         AS TotalBooks,
      SUM( TotalCopies ) AS TotalCopies,
      SUM( AvailCopies ) AS AvailableCopies
      FROM zalm_lb_i_book
      INTO @DATA(ls_book_agg).

SELECT SINGLE COUNT( * )
      FROM zalm_lb_i_loan AS l
      INNER JOIN zalm_lb_i_loanstatus AS s ON l~StatusId = s~StatusId
      WHERE s~IsActiveLoan = @abap_true
      INTO @DATA(lv_active_loans).
    SELECT SINGLE COUNT( * )
      FROM zalm_lb_i_loan
      WHERE StatusId = 'OV'
      INTO @DATA(lv_overdue_loans).
    SELECT SINGLE AVG( AvgRating AS DEC( 3, 2 ) )
      FROM zalm_lb_i_book
      WHERE AvgRating > 0
      INTO @DATA(lv_avg_rating).


   DATA(ls_kpis) = VALUE zalm_lb_a_librarykpis(
      TotalBooks       = ls_book_agg-TotalBooks
      TotalCopies      = ls_book_agg-TotalCopies
      AvailableCopies  = ls_book_agg-AvailableCopies
      ActiveLoans      = lv_active_loans
      OverdueLoans     = lv_overdue_loans
      AvgLibraryRating = lv_avg_rating ).

    result = VALUE #( FOR ls_key IN keys
                      ( %cid   = ls_key-%cid
                        %param = ls_kpis ) ).

  ENDMETHOD.

ENDCLASS.
