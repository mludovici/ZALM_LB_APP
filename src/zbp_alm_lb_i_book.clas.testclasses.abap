*"* use this source file for your ABAP unit test classes
CLASS ltc_library_flow DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS teardown.
    METHODS test_stage_c_flow FOR TESTING.
ENDCLASS.

CLASS ltc_library_flow IMPLEMENTATION.
  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  METHOD test_stage_c_flow.
    " 1. Testbuch anlegen (TotalCopies = 2 -> AvailCopies wird per Determination = 2)
    MODIFY ENTITIES OF zalm_lb_i_book
      ENTITY Book
        CREATE FIELDS ( Title Author Category TotalCopies )
        WITH VALUE #( ( %cid        = 'NEW_BOOK_1'
                        Title       = 'Clean ABAP'
                        Author      = 'Stefan Roth'
                        Category    = 'ABAP'
                        TotalCopies = 2 ) )
      MAPPED DATA(lt_book_mapped)
      FAILED DATA(lt_book_failed)
      REPORTED DATA(lt_book_reported).

    cl_abap_unit_assert=>assert_initial( act = lt_book_failed msg = 'Buch anlegen fehlgeschlagen' ).
    DATA(ls_book_tky) = lt_book_mapped-book[ 1 ]-%tky.

    " 2. lendBook -> Bestand muss von 2 auf 1 sinken
    MODIFY ENTITIES OF zalm_lb_i_book
      ENTITY Book
        EXECUTE lendBook
        FROM VALUE #( ( %tky   = ls_book_tky
                        %param = VALUE #( MemberId = 'MEM-0001' ) ) )
      RESULT DATA(lt_lend_res)
      FAILED DATA(lt_lend_failed)
      REPORTED DATA(lt_lend_reported).

    cl_abap_unit_assert=>assert_initial( act = lt_lend_failed msg = 'lendBook fehlgeschlagen' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_lend_res[ 1 ]-%param-AvailCopies
      exp = 1
      msg = 'AvailCopies muss nach lendBook auf 1 stehen' ).

    " Neue Ausleihe über Assoziation lesen, um Loan-%tky zu bekommen
    READ ENTITIES OF zalm_lb_i_book
      ENTITY Book BY \_Loan
        ALL FIELDS WITH VALUE #( ( %tky = ls_book_tky ) )
      RESULT DATA(lt_loans).

    cl_abap_unit_assert=>assert_not_initial( act = lt_loans msg = 'Ausleihe wurde nicht angelegt' ).
    DATA(ls_loan_tky) = lt_loans[ 1 ]-%tky.

    " 3. extendLoan 2x -> ExtensionCount = 2, StatusId = 'EX'; 3. Versuch schlägt fehl
    MODIFY ENTITIES OF zalm_lb_i_book
      ENTITY Loan
        EXECUTE extendLoan
        FROM VALUE #( ( %tky   = ls_loan_tky
                        %param = VALUE #( Reason = 'Verlängerung 1' ) ) )
      RESULT DATA(lt_ext1)
      FAILED DATA(lt_ext1_failed).
    cl_abap_unit_assert=>assert_initial( act = lt_ext1_failed msg = '1. Verlängerung fehlgeschlagen' ).

    MODIFY ENTITIES OF zalm_lb_i_book
      ENTITY Loan
        EXECUTE extendLoan
        FROM VALUE #( ( %tky   = ls_loan_tky
                        %param = VALUE #( Reason = 'Verlängerung 2' ) ) )
      RESULT DATA(lt_ext2)
      FAILED DATA(lt_ext2_failed).
    cl_abap_unit_assert=>assert_initial( act = lt_ext2_failed msg = '2. Verlängerung fehlgeschlagen' ).
    cl_abap_unit_assert=>assert_equals( act = lt_ext2[ 1 ]-%param-ExtensionCount exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_ext2[ 1 ]-%param-StatusId exp = 'EX' ).

    MODIFY ENTITIES OF zalm_lb_i_book
      ENTITY Loan
        EXECUTE extendLoan
        FROM VALUE #( ( %tky   = ls_loan_tky
                        %param = VALUE #( Reason = 'Verlängerung 3' ) ) )
      RESULT DATA(lt_ext3)
      FAILED DATA(lt_ext3_failed).
    cl_abap_unit_assert=>assert_not_initial( act = lt_ext3_failed-loan msg = '3. Verlängerung muss scheitern' ).

    " 4. returnBook -> StatusId = 'RT', Bestand wieder 2
    MODIFY ENTITIES OF zalm_lb_i_book
      ENTITY Loan
        EXECUTE returnBook
        FROM VALUE #( ( %tky = ls_loan_tky ) )
      RESULT DATA(lt_ret)
      FAILED DATA(lt_ret_failed).
    cl_abap_unit_assert=>assert_initial( act = lt_ret_failed msg = 'returnBook fehlgeschlagen' ).
    cl_abap_unit_assert=>assert_equals( act = lt_ret[ 1 ]-%param-StatusId exp = 'RT' ).

    READ ENTITIES OF zalm_lb_i_book
      ENTITY Book FIELDS ( BookId AvailCopies ) WITH VALUE #( ( %tky = ls_book_tky ) )
      RESULT DATA(lt_book_after_return).
    cl_abap_unit_assert=>assert_equals( act = lt_book_after_return[ 1 ]-AvailCopies exp = 2 ).

    " 5. duplicateBook -> neue BookUuid & BookId, AvailCopies = TotalCopies
  " 5. Bestehendes DB-Buch duplizieren -> neue BookUuid & neue BookId
    SELECT SINGLE BookUuid, BookId
      FROM zalm_lb_i_book
      WHERE IsArchived = @abap_false
      INTO @DATA(ls_db_book).
    cl_abap_unit_assert=>assert_subrc( msg = 'Kein DB-Buch fuer duplicateBook gefunden' ).
    MODIFY ENTITIES OF zalm_lb_i_book
      ENTITY Book
        EXECUTE duplicateBook
        FROM VALUE #( ( %cid = 'DUP_1' BookUuid = ls_db_book-BookUuid ) )
      MAPPED DATA(lt_dup_mapped)
      FAILED DATA(lt_dup_failed).
    cl_abap_unit_assert=>assert_initial( act = lt_dup_failed msg = 'duplicateBook fehlgeschlagen' ).
    cl_abap_unit_assert=>assert_not_initial( act = lt_dup_mapped-book ).
    READ ENTITIES OF zalm_lb_i_book
      ENTITY Book FIELDS ( BookId TotalCopies AvailCopies ) WITH VALUE #( ( %tky = lt_dup_mapped-book[ 1 ]-%tky ) )
      RESULT DATA(lt_dup_book).
    cl_abap_unit_assert=>assert_not_initial( act = lt_dup_book[ 1 ]-BookId ).
    cl_abap_unit_assert=>assert_differs( act = lt_dup_book[ 1 ]-BookId exp = ls_db_book-BookId ).
    cl_abap_unit_assert=>assert_differs( act = lt_dup_mapped-book[ 1 ]-BookUuid exp = ls_db_book-BookUuid ).
    cl_abap_unit_assert=>assert_equals( act = lt_dup_book[ 1 ]-AvailCopies exp = lt_dup_book[ 1 ]-TotalCopies ).

    " 6. getLibraryKpis -> stimmige Summen
    READ ENTITIES OF zalm_lb_i_book
      ENTITY Book
        EXECUTE getLibraryKpis
        FROM VALUE #( ( %cid = 'KPI_1' ) )
      RESULT DATA(lt_kpis)
      FAILED DATA(lt_kpi_failed).
    cl_abap_unit_assert=>assert_initial( act = lt_kpi_failed msg = 'getLibraryKpis fehlgeschlagen' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lt_kpis[ 1 ]-%param-TotalBooks > 0 ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( lt_kpis[ 1 ]-%param-OverdueLoans >= 0 ) ).
  ENDMETHOD.
ENDCLASS.
