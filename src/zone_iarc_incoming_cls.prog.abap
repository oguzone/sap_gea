*&---------------------------------------------------------------------*
*& Include ZONE_IARC_INCOMING_CLS
*&---------------------------------------------------------------------*
*& LCL_APP : Uygulama akisi. Tek sorumlulugu secim ekrani degerlerini
*&           ZCL_ZONE_IARC_GRID=>TY_FILTER'a cevirip grid'e devretmek.
*&           Her F8'de yeni ornek yaratilir; ornek GO_APP (TOP) ile
*&           liste ekrani acik kaldigi surece yasatilir (grid olay
*&           isleyicileri bu nesneye bagli).
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor.
    METHODS execute.

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
    IF mo_grid->run( build_filter( ) ) = abap_true.
      " Grid'ler DEFAULT_SCREEN'e (liste ekrani) yerlesti; liste ekraninin
      " acilmasi icin en az bir liste satiri gerekir - kontrol bunu ortur.
      WRITE space.
    ENDIF.
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
