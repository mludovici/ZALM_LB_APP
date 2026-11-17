CLASS zcl_alm_lb_openlib_qry DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF c_source_mode,
        live     TYPE string VALUE 'LIVE',
        fallback TYPE string VALUE 'FALLBACK',
      END OF c_source_mode.



    TYPES tt_result TYPE STANDARD TABLE OF zalm_lb_ce_openlibbook WITH EMPTY KEY.

    METHODS search_books
      IMPORTING
        iv_query        TYPE string
      RETURNING
        VALUE(rt_books) TYPE tt_result.
    METHODS get_book_by_key
      IMPORTING
        iv_key         TYPE zalm_lb_ce_openlibbook-openlibkey
      RETURNING
        VALUE(rs_book) TYPE zalm_lb_ce_openlibbook.


    INTERFACES:   if_oo_adt_classrun,
      if_rap_query_provider.
  PROTECTED SECTION.
  PRIVATE SECTION.

    " 1. Struktur für EIN einzelnes Buch aus dem 'docs'-Array
    TYPES: BEGIN OF ty_openlib_doc,
             key                TYPE string,
             title              TYPE string,
             author_name        TYPE STANDARD TABLE OF string WITH EMPTY KEY,
             first_publish_year TYPE i,
             isbn               TYPE STANDARD TABLE OF string WITH EMPTY KEY,
             cover_i            TYPE i,
           END OF ty_openlib_doc.

    " 2. Tabelle für ALLE Bücher aus dem 'docs'-Array
    TYPES tt_openlib_docs TYPE STANDARD TABLE OF ty_openlib_doc WITH EMPTY KEY.

    " 3. Die äußere Gesamtstruktur des JSONs
    TYPES: BEGIN OF ty_openlib_response,
             numfound TYPE i,
             docs     TYPE tt_openlib_docs,
           END OF ty_openlib_response.

    METHODS get_fallback_json
      IMPORTING
        iv_query       TYPE string
      RETURNING
        VALUE(rv_json) TYPE string.
    METHODS fetch_openlib_json
      IMPORTING
        iv_query       TYPE string
      EXPORTING
        ev_json        TYPE string
        ev_source_mode TYPE string.
    METHODS json_parsing IMPORTING rv_json TYPE string RETURNING VALUE(rs_response) TYPE ty_openlib_response.
    METHODS create_book IMPORTING ls_response TYPE ty_openlib_response  iv_source_mode TYPE string RETURNING VALUE(rt_books) TYPE tt_result.

ENDCLASS.



CLASS zcl_alm_lb_openlib_qry IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( get_book_by_key( '/works/OL45883W' ) ).
*    out->write( search_books( 'Clean Code' ) ).
  ENDMETHOD.

  METHOD if_rap_query_provider~select.
    " 1. Suche & Filter aus dem Fiori-Request lesen
    DATA(lv_search) = io_request->get_search_expression( ).
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.
    ENDTRY.
    " Suchbegriff für die OpenLibrary-API bestimmen (Searchbar > Filter > Default)
    DATA(lv_query) = lv_search.
    IF lv_query IS INITIAL.
      LOOP AT lt_filter INTO DATA(ls_filter) WHERE name = 'TITLE'
                                                OR name = 'AUTHOR'
                                                OR name = 'ISBN'.
        READ TABLE ls_filter-range INTO DATA(ls_rng) INDEX 1.
        IF sy-subrc = 0 AND ls_rng-low IS NOT INITIAL.
          lv_query = ls_rng-low.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.
    IF lv_query IS INITIAL.
      lv_query = 'ABAP'. " Default beim ersten Öffnen ohne Filter
    ENDIF.
    " 2. Daten holen & parsen
    DATA(lt_all) = search_books( lv_query ).
    " 3. Lokal filtern (wichtig im FALLBACK-Modus & bei Feldfiltern)
    IF lv_search IS NOT INITIAL.
      DATA(lv_search_up) = to_upper( lv_search ).
      LOOP AT lt_all INTO DATA(ls_book).
        IF to_upper( ls_book-title )  NS lv_search_up
       AND to_upper( ls_book-author ) NS lv_search_up.
          DELETE lt_all.
        ENDIF.
      ENDLOOP.
    ENDIF.
    LOOP AT lt_filter INTO ls_filter.
      CASE ls_filter-name.
        WHEN 'TITLE'.
          DELETE lt_all WHERE title NOT IN ls_filter-range.
        WHEN 'AUTHOR'.
          DELETE lt_all WHERE author NOT IN ls_filter-range.
        WHEN 'ISBN'.
          DELETE lt_all WHERE isbn NOT IN ls_filter-range.
        WHEN 'OPENLIBKEY'.
          DELETE lt_all WHERE openlibkey NOT IN ls_filter-range.
      ENDCASE.
    ENDLOOP.
    " 4. Paging & Response (Pflicht bei Custom Entities!)
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_all ) ).
    ENDIF.
    IF io_request->is_data_requested( ).
      DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
      DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).
      DATA lt_paged TYPE tt_result.
      DATA(lv_from) = lv_offset + 1.
      DATA(lv_to)   = COND i( WHEN lv_page_size < 0
                              THEN lines( lt_all )
                              ELSE nmin( val1 = lv_offset + lv_page_size
                                         val2 = lines( lt_all ) ) ).
      IF lv_from <= lv_to.
        APPEND LINES OF lt_all FROM lv_from TO lv_to TO lt_paged.
      ENDIF.
      io_response->set_data( lt_paged ).
    ENDIF.
  ENDMETHOD.

  METHOD fetch_openlib_json.

    DATA: lo_client      TYPE REF TO if_http_client,
          lv_encoded_q   TYPE string,
          lv_url         TYPE string,
          lv_http_status TYPE i.

    " Standardmäßig auf LIVE setzen
    ev_source_mode = c_source_mode-live.

    " 1. Suchbegriff URL-sicher kodieren
    lv_encoded_q = cl_http_utility=>escape_url( unescaped = iv_query ).
    lv_url = |https://openlibrary.org/search.json?q={ lv_encoded_q }&fields=key,title,author_name,first_publish_year,isbn,cover_i&limit=20|.

    " 2. HTTP-Client erzeugen
    cl_http_client=>create_by_url(
      EXPORTING
        url                = lv_url
        ssl_id             = 'ANONYM'
      IMPORTING
        client             = lo_client
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active  = 2
        internal_error     = 3
        OTHERS             = 4 ).

    IF sy-subrc <> 0 OR lo_client IS NOT BOUND.
      ev_source_mode = c_source_mode-fallback.
      ev_json        = get_fallback_json( iv_query ).
      RETURN.
    ENDIF.

    " 3. Request senden (mit Timeout, z. B. 5 Sekunden)
    lo_client->send(
      EXPORTING
        timeout                    = 5
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        http_invalid_timeout       = 4
        OTHERS                     = 5 ).

    IF sy-subrc <> 0.
      lo_client->close( ).
      ev_source_mode = c_source_mode-fallback.
      ev_json        = get_fallback_json( iv_query ).
      RETURN.
    ENDIF.

    " 4. Antwort empfangen
    lo_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    lo_client->get_last_error( IMPORTING code = DATA(lv_code) message = DATA(lv_msg) ).

    IF sy-subrc <> 0.
      lo_client->close( ).
      ev_source_mode = c_source_mode-fallback.
      ev_json        = get_fallback_json( iv_query ).
      RETURN.
    ENDIF.

    " 5. HTTP-Status prüfen
    lo_client->response->get_status( IMPORTING code = lv_http_status ).

    IF lv_http_status = 200.
      ev_json = lo_client->response->get_cdata( ).
    ELSE.
      ev_source_mode = c_source_mode-fallback.
      ev_json        = get_fallback_json( iv_query ).
    ENDIF.

    " Verbindung sauber schließen
    lo_client->close( ).
  ENDMETHOD.

  METHOD get_fallback_json.
    " Baut ein realistisches JSON im OpenLibrary-Format mit 6 IT-/ABAP-Büchern
    rv_json =

      |\{| &&
      |  "numFound": 6,| &&
      |  "start": 0,| &&
      |  "numFoundExact": true,| &&
      |  "q": "{ iv_query }",| &&
      |  "docs": [| &&
      |    \{| &&
      |      "key": "/works/OL45883W",| &&
      |      "title": "Clean Code: A Handbook of Agile Software Craftsmanship",| &&
      |      "author_name": ["Robert C. Martin"],| &&
      |      "first_publish_year": 2008,| &&
      |      "isbn": ["9780132350884"],| &&
      |      "cover_i": 14625765,| &&
      |      "cover_url": "https://openlibrary.org"| &&
      |    \},| &&
      |    \{| &&
      |      "key": "/works/OL262421W",| &&
      |      "title": "Design Patterns: Elements of Reusable Object-Oriented Software",| &&
      |      "author_name": ["Erich Gamma", "Richard Helm", "Ralph Johnson", "John Vlissides"],| &&
      |      "first_publish_year": 1994,| &&
      |      "isbn": ["9780201633610"],| &&
      |      "cover_i": 8231856,| &&
      |      "cover_url": "https://openlibrary.org"| &&
      |    \},| &&
      |    \{| &&
      |      "key": "/works/OL17358695W",| &&
      |      "title": "Clean Architecture: A Craftsman's Guide to Software Structure and Design",| &&
      |      "author_name": ["Robert C. Martin"],| &&
      |      "first_publish_year": 2017,| &&
      |      "isbn": ["9780134494166"],| &&
      |      "cover_i": 8456721,| &&
      |      "cover_url": "https://openlibrary.org"| &&
      |    \},| &&
      |    \{| &&
      |      "key": "/works/OL5735363W",| &&
      |      "title": "The Pragmatic Programmer: Your Journey to Mastery",| &&
      |      "author_name": ["Andrew Hunt", "David Thomas"],| &&
      |      "first_publish_year": 1999,| &&
      |      "isbn": ["9780201616224"],| &&
      |      "cover_i": 10521270,| &&
      |      "cover_url": "https://openlibrary.org"| &&
      |    \},| &&
      |    \{| &&
      |      "key": "/works/OL16807788W",| &&
      |      "title": "ABAP Objects: ABAP Programming in SAP NetWeaver",| &&
      |      "author_name": ["Horst Keller", "Sascha Krüger"],| &&
      |      "first_publish_year": 2007,| &&
      |      "isbn": ["9781592290796"],| &&
      |      "cover_i": 6432198,| &&
      |      "cover_url": "https://openlibrary.org"| &&
      |    \},| &&
      |    \{| &&
      |      "key": "/works/OL17931325W",| &&
      |      "title": "Domain-Driven Design: Tackling Complexity in the Heart of Software",| &&
      |      "author_name": ["Eric Evans"],| &&
      |      "first_publish_year": 2003,| &&
      |      "isbn": ["9780321125215"],| &&
      |      "cover_i": 8245112,| &&
      |      "cover_url": "https://openlibrary.org"| &&
      |    \}| &&
      |  ]| &&
      |\}|.
  ENDMETHOD.

  METHOD json_parsing.
    /ui2/cl_json=>deserialize(
      EXPORTING
        json = rv_json
      CHANGING
        data = rs_response ).
  ENDMETHOD.

  METHOD create_book.
    DATA ls_book TYPE zalm_lb_ce_openlibbook.
    LOOP AT ls_response-docs INTO DATA(ls_doc).
      CLEAR ls_book.
      ls_book-openlibkey  = ls_doc-key.
      ls_book-title       = ls_doc-title.
      ls_book-publishyear = ls_doc-first_publish_year.
      ls_book-sourcemode  = iv_source_mode.
      ls_book-author      = concat_lines_of( table = ls_doc-author_name sep = `, ` ).
      READ TABLE ls_doc-isbn INTO ls_book-isbn INDEX 1.
      IF ls_doc-cover_i IS NOT INITIAL.
        ls_book-coverurl = |https://covers.openlibrary.org/b/id/{ ls_doc-cover_i }-M.jpg|.
      ELSEIF ls_book-isbn IS NOT INITIAL.
        ls_book-coverurl = |https://covers.openlibrary.org/b/isbn/{ ls_book-isbn }-M.jpg|.
      ENDIF.
      APPEND ls_book TO rt_books.
    ENDLOOP.
  ENDMETHOD.

  METHOD search_books.
    fetch_openlib_json(
      EXPORTING
        iv_query       = iv_query
      IMPORTING
        ev_json        = DATA(lv_json)
        ev_source_mode = DATA(lv_mode) ).
    rt_books = create_book( ls_response    = json_parsing( lv_json )
                            iv_source_mode = lv_mode ).
  ENDMETHOD.

  METHOD get_book_by_key.
    DATA(lt_books) = search_books( |key:"{ condense( iv_key ) }"| ).
    rs_book = VALUE #( lt_books[ openlibkey = iv_key ] OPTIONAL ).
    " Falls Live-Suche nichts liefert (z. B. UI-Zeile kam aus FALLBACK), im Fallback nachschlagen
    IF rs_book IS INITIAL.
      DATA(lt_fallback) = create_book( ls_response    = json_parsing( get_fallback_json( '' ) )
                                       iv_source_mode = c_source_mode-fallback ).
      rs_book = VALUE #( lt_fallback[ openlibkey = iv_key ] OPTIONAL ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
