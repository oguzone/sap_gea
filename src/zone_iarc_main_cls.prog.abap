*&---------------------------------------------------------------------*
*& Include ZONE_IARC_MAIN_CLS
*&---------------------------------------------------------------------*
*& LCL_SCOPE    : Kokpit kapsami - aktif sirket kodlari (ZONE_IARC_T001)
*&                ve son 12 ay. Secim ekrani yok (Karar 034).
*& LCL_LAUNCHER : Sol paneldeki buton (fonksiyon kodu) -> hedef program /
*&                SM30 bakimi / islem. Tek yerde toplanir.
*& LCL_APP      : Akis - dogrudan 0100 kokpit ekrani; PBO/PAI.
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* LCL_SCOPE
*----------------------------------------------------------------------*
CLASS lcl_scope DEFINITION FINAL.
  PUBLIC SECTION.
    " ZONE_IARC_T001'de aktif sirketler; hic yoksa bos aralik (= hepsi).
    CLASS-METHODS company_codes
      RETURNING
        VALUE(rt_bukrs) TYPE zcl_zone_iarc_dashboard=>tr_bukrs.

    " Son 12 ay: 11 ay onceki ayin 1'i .. bugun.
    CLASS-METHODS last_12_months
      RETURNING
        VALUE(rt_date) TYPE zcl_zone_iarc_dashboard=>tr_date.
ENDCLASS.

CLASS lcl_scope IMPLEMENTATION.
  METHOD company_codes.
    SELECT bukrs FROM zone_iarc_t001
      WHERE active_flg = @abap_true
      INTO TABLE @DATA(lt_active).
    rt_bukrs = VALUE #( FOR ls_active IN lt_active
                        ( sign = 'I' option = 'EQ' low = ls_active-bukrs ) ).
  ENDMETHOD.

  METHOD last_12_months.
    DATA lv_year  TYPE i.
    DATA lv_month TYPE i.
    DATA lv_low   TYPE d.

    lv_year  = sy-datum(4).
    lv_month = sy-datum+4(2) - 11.
    IF lv_month < 1.
      lv_month = lv_month + 12.
      lv_year  = lv_year - 1.
    ENDIF.
    lv_low = |{ lv_year WIDTH = 4 ALIGN = RIGHT PAD = '0' }{ lv_month WIDTH = 2 ALIGN = RIGHT PAD = '0' }01|.
    rt_date = VALUE #( ( sign = 'I' option = 'BT' low = lv_low high = sy-datum ) ).
  ENDMETHOD.
ENDCLASS.


*----------------------------------------------------------------------*
* LCL_LAUNCHER
*----------------------------------------------------------------------*
CLASS lcl_launcher DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        !it_bukrs TYPE zcl_zone_iarc_dashboard=>tr_bukrs
        !it_date  TYPE zcl_zone_iarc_dashboard=>tr_date.

    " Fonksiyon kodu taninirsa hedefi acar ve ABAP_TRUE doner.
    METHODS launch
      IMPORTING
        !iv_fcode         TYPE sy-ucomm
      RETURNING
        VALUE(rv_handled) TYPE abap_bool.

  PRIVATE SECTION.
    DATA mt_bukrs TYPE zcl_zone_iarc_dashboard=>tr_bukrs.
    DATA mt_date  TYPE zcl_zone_iarc_dashboard=>tr_date.

    METHODS submit
      IMPORTING
        !iv_program TYPE programm.
    METHODS maintain
      IMPORTING
        !iv_table TYPE tabname.
    METHODS call_tcode
      IMPORTING
        !iv_tcode TYPE sy-tcode.
ENDCLASS.

CLASS lcl_launcher IMPLEMENTATION.
  METHOD constructor.
    mt_bukrs = it_bukrs.
    mt_date  = it_date.
  ENDMETHOD.

  METHOD launch.
    rv_handled = abap_true.
    CASE iv_fcode.
      " --- Belgeler
      WHEN 'LIST'.
        " Kokpitin sirket/donem kapsami listenin secim ekranina tasinir.
        SUBMIT zone_iarc_incoming VIA SELECTION-SCREEN
          WITH s_bukrs IN mt_bukrs
          WITH s_date  IN mt_date
          AND RETURN.
      WHEN 'POLL'.
        submit( 'ZONE_IARC_POLL' ).      " Bayt: adiniza duzenlenen belgeleri cek
      WHEN 'VIEW'.
        submit( 'ZONE_IARC_VIEWER' ).
      WHEN 'APPR'.
        submit( 'ZONE_IARC_COCKPIT' ).
      " --- Aktarim
      WHEN 'UPLD'.
        submit( 'ZONE_IARC_UPLOAD' ).
      " --- Uyarlama
      WHEN 'T001' OR 'T002' OR 'T003' OR 'T004' OR 'T005' OR 'T017'.
        maintain( CONV #( |ZONE_IARC_{ iv_fcode }| ) ).
      WHEN 'SECR'.
        submit( 'ZONE_IARC_SECRET' ).
      " --- Izleme
      WHEN 'JOBS'.
        call_tcode( 'SM37' ).
      WHEN OTHERS.
        rv_handled = abap_false.
    ENDCASE.
  ENDMETHOD.

  METHOD submit.
    SUBMIT (iv_program) VIA SELECTION-SCREEN AND RETURN.
  ENDMETHOD.

  METHOD maintain.
    CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
      EXPORTING
        action    = 'U'
        view_name = iv_table
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD call_tcode.
    TRY.
        CALL TRANSACTION iv_tcode WITH AUTHORITY-CHECK.
      CATCH cx_sy_authorization_error.
        DATA(lv_msg) = |{ iv_tcode } islem yetkiniz yok| ##NO_TEXT.
        MESSAGE lv_msg TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.


*----------------------------------------------------------------------*
* LCL_APP
*----------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF c_fcode,
        back    TYPE sy-ucomm VALUE 'BACK',
        cancel  TYPE sy-ucomm VALUE 'CANCEL',
        exit    TYPE sy-ucomm VALUE 'EXIT',
        refresh TYPE sy-ucomm VALUE 'REFR',
      END OF c_fcode.

    METHODS constructor.
    METHODS run.
    METHODS on_pbo.
    METHODS on_pai
      IMPORTING
        !iv_ucomm TYPE sy-ucomm.

  PRIVATE SECTION.
    DATA mo_dashboard TYPE REF TO zcl_zone_iarc_dashboard.
    DATA mo_launcher  TYPE REF TO lcl_launcher.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.
  METHOD constructor.
    DATA(lt_bukrs) = lcl_scope=>company_codes( ).
    DATA(lt_date)  = lcl_scope=>last_12_months( ).
    mo_dashboard = NEW #( it_bukrs = lt_bukrs it_date = lt_date ).
    mo_launcher  = NEW #( it_bukrs = lt_bukrs it_date = lt_date ).
  ENDMETHOD.

  METHOD run.
    CALL SCREEN 0100.
  ENDMETHOD.

  METHOD on_pbo.
    SET PF-STATUS 'STATUS_0100'.
    SET TITLEBAR 'TITLE_0100'.
    " SY-REPID/SY-DYNNR burada rapor baglaminda (ZONE_IARC_MAIN/0100).
    mo_dashboard->show( iv_repid = sy-repid iv_dynnr = sy-dynnr ).
  ENDMETHOD.

  METHOD on_pai.
    cl_gui_cfw=>dispatch( ).

    CASE iv_ucomm.
      WHEN c_fcode-back OR c_fcode-cancel OR c_fcode-exit.
        mo_dashboard->free( ).
        LEAVE TO SCREEN 0.
      WHEN c_fcode-refresh.
        mo_dashboard->refresh( ).
      WHEN OTHERS.
        " Acilan programdan/bakimdan donunce sayilar degismis olabilir.
        IF mo_launcher->launch( iv_ucomm ) = abap_true.
          mo_dashboard->refresh( ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
