*&---------------------------------------------------------------------*
*& Include ZONE_IARC_INCOMING_CLS
*&---------------------------------------------------------------------*
*& LCL_APP : Uygulama akisi. Tek sorumlulugu secim ekrani degerlerini
*&           ZCL_ZONE_IARC_GRID=>TY_FILTER'a cevirip grid'e devretmek.
*&           Singleton - docking container/grid ayni oturumda bir kez
*&           yaratilmali (her PBO'da yenisi yaratilirsa kontroller
*&           ust uste biner).
*&---------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS get
      RETURNING VALUE(ro_app) TYPE REF TO lcl_app.

    METHODS on_selection_screen_output.

  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO lcl_app.

    DATA mo_grid TYPE REF TO zcl_zone_iarc_grid.

    METHODS constructor.

    METHODS build_filter
      RETURNING VALUE(rs_filter) TYPE zcl_zone_iarc_grid=>ty_filter.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD get.
    IF go_instance IS NOT BOUND.
      go_instance = NEW #( ).
    ENDIF.
    ro_app = go_instance.
  ENDMETHOD.

  METHOD constructor.
    mo_grid = NEW #( ).
  ENDMETHOD.

  METHOD on_selection_screen_output.
    mo_grid->run( build_filter( ) ).
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
