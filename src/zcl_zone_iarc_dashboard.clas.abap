CLASS zcl_zone_iarc_dashboard DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Gelen e-Arsiv kokpiti (ZONE_IARC_MAIN) sag panel (Karar 033):
    " secilen sirket/donem icin belgeleri okur, ZCL_ZONE_IARC_DASHBOARD_HTML
    " ile gosterge sayfasini uretir ve cagiran dynpro'daki CC_DASH custom
    " container'inda CL_GUI_HTML_VIEWER ile gosterir.

    TYPES tr_bukrs TYPE RANGE OF bukrs.
    TYPES tr_date  TYPE RANGE OF zone_iarc_t006-doc_date.

    CONSTANTS c_container_name TYPE c LENGTH 7 VALUE 'CC_DASH'.

    METHODS constructor
      IMPORTING
        !it_bukrs TYPE tr_bukrs
        !it_date  TYPE tr_date.

    " Dynpro PBO'sundan cagrilir; kontroller yalnizca ilk seferde kurulur.
    " IV_REPID/IV_DYNNR rapor baglaminda okunup verilmeli.
    METHODS show
      IMPORTING
        !iv_repid TYPE sy-repid
        !iv_dynnr TYPE sy-dynnr.

    " Veriyi yeniden okuyup sayfayi yeniden cizer (orn. bir programdan donunce).
    METHODS refresh.

    METHODS free.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mt_bukrs     TYPE tr_bukrs.
    DATA mt_date      TYPE tr_date.
    DATA mo_container TYPE REF TO cl_gui_custom_container.
    DATA mo_html      TYPE REF TO cl_gui_html_viewer.

    METHODS read_documents
      RETURNING
        VALUE(rt_doc) TYPE zcl_zone_iarc_dashboard_html=>tt_doc.

    METHODS period_text
      RETURNING
        VALUE(rv_text) TYPE string.

    " HTML'i 255 karakterlik satir tablosu olarak kontrole yukler.
    METHODS display
      IMPORTING
        !iv_html TYPE string.
ENDCLASS.



CLASS zcl_zone_iarc_dashboard IMPLEMENTATION.

  METHOD constructor.
    mt_bukrs = it_bukrs.
    mt_date  = it_date.
  ENDMETHOD.

  METHOD show.
    IF mo_container IS BOUND.
      RETURN.
    ENDIF.
    mo_container = NEW cl_gui_custom_container(
      container_name = c_container_name
      repid          = iv_repid
      dynnr          = iv_dynnr ).
    mo_html = NEW cl_gui_html_viewer( parent = mo_container ).
    refresh( ).
  ENDMETHOD.

  METHOD refresh.
    IF mo_html IS NOT BOUND.
      RETURN.
    ENDIF.
    display( NEW zcl_zone_iarc_dashboard_html( )->build(
               it_doc    = read_documents( )
               iv_period = period_text( ) ) ).
  ENDMETHOD.

  METHOD free.
    IF mo_container IS BOUND.
      mo_container->free( ).
    ENDIF.
    CLEAR: mo_container, mo_html.
  ENDMETHOD.

  METHOD read_documents.
    SELECT a~provider_doc_id, a~bukrs, b~invoice_id, a~doc_date, a~status,
           a~amount, a~currency, a~supplier_vkn, b~supplier_name, a~lifnr,
           a~received_at
      FROM zone_iarc_t006 AS a
      LEFT OUTER JOIN zone_iarc_t009 AS b
        ON b~bukrs = a~bukrs AND b~ettn = a~ettn
      WHERE a~bukrs    IN @mt_bukrs
        AND a~doc_date IN @mt_date
      INTO CORRESPONDING FIELDS OF TABLE @rt_doc.
  ENDMETHOD.

  METHOD period_text.
    DATA ls_date LIKE LINE OF mt_date.
    ls_date = VALUE #( mt_date[ 1 ] OPTIONAL ).
    IF ls_date IS INITIAL.
      rv_text = `Tum donemler` ##NO_TEXT.
    ELSEIF ls_date-high IS INITIAL.
      rv_text = |{ ls_date-low DATE = USER }|.
    ELSE.
      rv_text = |{ ls_date-low DATE = USER } - { ls_date-high DATE = USER }|.
    ENDIF.
  ENDMETHOD.

  METHOD display.
    TYPES ty_html_line TYPE c LENGTH 255.
    DATA lt_data  TYPE STANDARD TABLE OF ty_html_line WITH DEFAULT KEY.
    DATA lv_chunk TYPE ty_html_line.
    DATA lv_url   TYPE c LENGTH 250.
    DATA lv_off   TYPE i.

    DATA(lv_len) = strlen( iv_html ).
    WHILE lv_off < lv_len.
      lv_chunk = substring( val = iv_html off = lv_off len = nmin( val1 = 255 val2 = lv_len - lv_off ) ).
      APPEND lv_chunk TO lt_data.
      lv_off = lv_off + 255.
    ENDWHILE.

    mo_html->load_data(
      IMPORTING
        assigned_url = lv_url
      CHANGING
        data_table   = lt_data
      EXCEPTIONS
        OTHERS       = 1 ).
    IF sy-subrc = 0.
      mo_html->show_url( url = lv_url ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
