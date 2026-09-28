*&---------------------------------------------------------------------*
*& Include ZONE_IARC_INCOMING_CLS
*&---------------------------------------------------------------------*
*& LCL_APP : Uygulama akisi. Secim ekrani degerlerini
*&           ZCL_ZONE_IARC_GRID=>TY_FILTER'a cevirir, kayit varsa 0100
*&           ekranini acar; ekranin PBO/PAI'si buraya delege edilir.
*&           Her F8'de yeni ornek yaratilir; ornek GO_APP (TOP) ile
*&           liste ekrani acik kaldigi surece yasatilir (grid olay
*&           isleyicileri bu nesneye bagli).
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF c_fcode,
        back   TYPE sy-ucomm VALUE 'BACK',
        cancel TYPE sy-ucomm VALUE 'CANCEL',
        exit   TYPE sy-ucomm VALUE 'EXIT',
      END OF c_fcode.

    METHODS constructor.
    METHODS execute.
    METHODS on_pbo.
    METHODS on_pai
      IMPORTING
        !iv_ucomm TYPE sy-ucomm.

  PRIVATE SECTION.
    DATA mo_grid TYPE REF TO zcl_zone_iarc_grid.

    METHODS build_filter
      RETURNING VALUE(rs_filter) TYPE zcl_zone_iarc_grid=>ty_filter.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD constructor.
    mo_grid = NEW #( ).
  ENDMETHOD.

  METHOD execute.
    IF mo_grid->load( build_filter( ) ) = abap_true.
      CALL SCREEN 0100.
    ENDIF.
  ENDMETHOD.

  METHOD on_pbo.
    SET PF-STATUS 'STATUS_0100'.
    SET TITLEBAR 'TITLE_0100'.
    " SY-REPID/SY-DYNNR burada rapor baglaminda (ZONE_IARC_INCOMING/0100).
    mo_grid->show( iv_repid = sy-repid iv_dynnr = sy-dynnr ).
  ENDMETHOD.

  METHOD on_pai.
    " Grid olaylari (cift tik, hotspot, arac cubugu) uygulama olayi olarak
    " gelirse isleyicileri burada tetiklenir.
    cl_gui_cfw=>dispatch( ).

    CASE iv_ucomm.
      WHEN c_fcode-back OR c_fcode-cancel OR c_fcode-exit.
        mo_grid->free( ).
        LEAVE TO SCREEN 0.
    ENDCASE.
  ENDMETHOD.

  METHOD build_filter.
    " Secim ekrani SELECT-OPTIONS'lari global (header line'li) tablolardir;
    " [] ile govdeleri alinip ayni satir yapisindaki RANGE tiplerine atanir.
    rs_filter = VALUE #(
      bukrs    = s_bukrs[]
      ettn     = s_ettn[]
      invid    = s_invid[]
      docid    = s_docid[]
      vkn      = s_vkn[]
      sname    = s_sname[]
      lifnr    = s_lifnr[]
      docdate  = s_date[]
      invtype  = s_type[]
      profile  = s_prof[]
      currency = s_curr[]
      amount   = s_amnt[]
      status   = s_stat[]
      belnr    = s_belnr[] ).
  ENDMETHOD.

ENDCLASS.
