CLASS lhc_ZALM_LB_CE_OpenLibBook DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ZALM_LB_CE_OpenLibBook RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ ZALM_LB_CE_OpenLibBook RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK ZALM_LB_CE_OpenLibBook.

    METHODS importFromOpenLib FOR MODIFY
      IMPORTING keys FOR ACTION ZALM_LB_CE_OpenLibBook~importFromOpenLib RESULT result.

ENDCLASS.

CLASS lhc_ZALM_LB_CE_OpenLibBook IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%action-importFromOpenLib = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZALM_LB_OL'
        ID 'ACTVT' FIELD '01'.
      result-%action-importFromOpenLib = COND #(
        WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
        ELSE                   if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.

  METHOD read.
    DATA(lo_qry) = NEW zcl_alm_lb_openlib_qry( ).
    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_ol) = lo_qry->get_book_by_key( ls_key-OpenLibKey ).
      IF ls_ol IS NOT INITIAL.
        APPEND CORRESPONDING #( ls_ol ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD lock.
  ENDMETHOD.

  METHOD importFromOpenLib.
    DATA(lo_qry) = NEW zcl_alm_lb_openlib_qry( ).
    SELECT FROM ZALM_LB_I_Book FIELDS Isbn WHERE Isbn <> '' INTO TABLE @DATA(lt_books).

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_ol) = lo_qry->get_book_by_key( ls_key-OpenLibKey ).
      IF ls_ol IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-zalm_lb_ce_openlibbook.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Buch { ls_key-OpenLibKey } konnte nicht geladen werden.| ) )
          TO reported-zalm_lb_ce_openlibbook.
        CONTINUE.
      ENDIF.

      " Dubletten-Check (nur wenn ISBN vorhanden)
      " DATA(ls_book) = VALUE #( lt_books[ Isbn = ls_ol-Isbn ] OPTIONAL ).
*     " IF ls_book IS NOT INITIAL.
      IF ls_ol-Isbn IS NOT INITIAL AND line_exists( lt_books[ Isbn = ls_ol-Isbn ] ).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-zalm_lb_ce_openlibbook.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZALM_LB_MSG'
                    number   = '014' " passende Nummer
                    severity = if_abap_behv_message=>severity-success
                    v1       = ls_ol-Title
                    v2 = ls_ol-Isbn ) )
          TO reported-zalm_lb_ce_openlibbook.
        CONTINUE.
      ENDIF.
      " Ab hier hat man ls_ol-Title, ls_ol-Author, ls_ol-Isbn, ls_ol-PublishYear, ls_ol-CoverUrl
      " -> Dubletten-Check gegen ZALM_LB_BOOK
      " -> MODIFY ENTITIES OF zalm_lb_i_book ...
      MODIFY ENTITIES OF zalm_lb_i_book
      ENTITY Book
        CREATE FIELDS ( Title Author Isbn Category PublishYear CoverUrl
                        TotalCopies Price CurrencyCode IsArchived )
        WITH VALUE #( ( %cid         = |IMP_{ sy-tabix }|
                        Title        = ls_ol-Title
                        Author       = ls_ol-Author
                        Isbn         = ls_ol-Isbn
                        Category     = ''
                        PublishYear  = ls_ol-PublishYear
                        CoverUrl     = ls_ol-CoverUrl
                        TotalCopies  = 1
                        Price        = '0.00'
                        CurrencyCode = 'EUR'
                        IsArchived   = abap_false ) )
      MAPPED   DATA(lt_book_mapped)
      FAILED   DATA(lt_book_failed)
      REPORTED DATA(lt_book_reported).

      IF lt_book_failed-book IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-zalm_lb_ce_openlibbook.
        " Erste Fehlermeldung aus Book-BO durchreichen (falls vorhanden)
        READ TABLE lt_book_reported-book INTO DATA(ls_book_rep) INDEX 1.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = COND #( WHEN ls_book_rep-%msg IS BOUND
                                       THEN ls_book_rep-%msg
                                       ELSE new_message( id       = 'ZALM_LB_MSG'
                    number   = '013' " passende Nummer
                    severity = if_abap_behv_message=>severity-success
                    v1       = ls_ol-Title  ) ) )
          TO reported-zalm_lb_ce_openlibbook.
        CONTINUE.
      ENDIF.

      " Erfolg: $self (= ZALM_LB_CE_OpenLibBook) für result zurückgeben + Erfolgsmeldung
      APPEND VALUE #( %tky   = ls_key-%tky
                      %param = CORRESPONDING #( ls_ol ) )
        TO result.
      APPEND VALUE #( %tky = ls_key-%tky
                      %msg = new_message( id       = 'ZALM_LB_MSG'
                    number   = '012' " passende Nummer
                    severity = if_abap_behv_message=>severity-success
                    v1       = ls_ol-Title ) )
        TO reported-zalm_lb_ce_openlibbook.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS lsc_ZALM_LB_CE_OPENLIBBOOK DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS finalize REDEFINITION.

    METHODS check_before_save REDEFINITION.

    METHODS save REDEFINITION.

    METHODS cleanup REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_ZALM_LB_CE_OPENLIBBOOK IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
