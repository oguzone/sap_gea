CLASS zcl_zone_iarc_bdc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Standart muhasebe ekranlarini (FB01, FB60) doldurarak acmak icin
    " ortak batch-input altyapisi (Karar 030): BDC tablosu kurma, kullanici
    " bicimiyle tutar/tarih, CALL TRANSACTION ve olusan belgenin bulunmasi.
    "
    " CTU_PARAMS-NOBIEND = X: veri bitince islem diyalogda devam eder -
    " kullanici kontrol eder, eksik alani tamamlar, KAYDET ya da PARK eder.
    " Belge no mesajlardan okunur ve BKPF'den (BUKRS+BELNR+XBLNR)
    " dogrulanir; kullanici kaydetmeden cikarsa sonuc bos doner.

    TYPES:
      BEGIN OF ty_result,
        belnr  TYPE belnr_d,
        gjahr  TYPE gjahr,
        parked TYPE abap_bool,   " BKPF-BSTAT = V (park edildi)
      END OF ty_result.

    METHODS screen
      IMPORTING
        !iv_program TYPE bdcdata-program
        !iv_dynpro  TYPE bdcdata-dynpro.

    METHODS field
      IMPORTING
        !iv_name  TYPE bdcdata-fnam
        !iv_value TYPE csequence.

    METHODS execute
      IMPORTING
        !iv_tcode        TYPE sy-tcode
        !is_proposal     TYPE zcl_zone_iarc_post=>ty_proposal
        !iv_mode         TYPE ctu_params-dismode DEFAULT 'A'
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_zone_iarc_mapping.

    " Kullanici ondalik bicimi (orn. 2902,50) - binlik ayraci olmadan.
    CLASS-METHODS amount_text
      IMPORTING
        !iv_amount     TYPE wrbtr
        !iv_waers      TYPE waers
      RETURNING
        VALUE(rv_text) TYPE bdcdata-fval.

    CLASS-METHODS date_text
      IMPORTING
        !iv_date       TYPE d
      RETURNING
        VALUE(rv_text) TYPE bdcdata-fval.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES tt_msg TYPE STANDARD TABLE OF bdcmsgcoll WITH DEFAULT KEY.

    DATA mt_bdc TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY.

    METHODS find_document
      IMPORTING
        !it_msg          TYPE tt_msg
        !is_proposal     TYPE zcl_zone_iarc_post=>ty_proposal
      RETURNING
        VALUE(rs_result) TYPE ty_result.
ENDCLASS.



CLASS zcl_zone_iarc_bdc IMPLEMENTATION.

  METHOD screen.
    APPEND VALUE #( program = iv_program dynpro = iv_dynpro dynbegin = abap_true ) TO mt_bdc.
  ENDMETHOD.

  METHOD field.
    APPEND VALUE #( fnam = iv_name fval = iv_value ) TO mt_bdc.
  ENDMETHOD.

  METHOD execute.
    DATA lt_msg TYPE tt_msg.
    DATA ls_opt TYPE ctu_params.

    ls_opt-dismode = iv_mode.
    ls_opt-updmode = 'S'.          " senkron - belge hemen BKPF'de okunabilsin
    ls_opt-nobiend = abap_true.    " veri bitince diyalog devam etsin
    ls_opt-defsize = abap_true.

    TRY.
        CALL TRANSACTION iv_tcode WITH AUTHORITY-CHECK
          USING mt_bdc
          OPTIONS FROM ls_opt
          MESSAGES INTO lt_msg.
      CATCH cx_sy_authorization_error.
        RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
          EXPORTING
            iv_error_code = 'IARC_BDC_001'
            iv_detail     = |{ iv_tcode } islem yetkiniz yok| ##NO_TEXT.
    ENDTRY.

    rs_result = find_document( it_msg = lt_msg is_proposal = is_proposal ).
  ENDMETHOD.

  METHOD amount_text.
    WRITE iv_amount TO rv_text CURRENCY iv_waers NO-GROUPING LEFT-JUSTIFIED.
  ENDMETHOD.

  METHOD date_text.
    WRITE iv_date TO rv_text.
  ENDMETHOD.

  METHOD find_document.
    " Basari mesaji (F5 312 "Belge & ... kaydedildi") ya da park mesaji:
    " ilk degiskende belge no.
    DATA lv_belnr TYPE belnr_d.

    LOOP AT it_msg INTO DATA(ls_msg) WHERE msgtyp = 'S'.
      DATA(lv_candidate) = condense( CONV string( ls_msg-msgv1 ) ).
      IF lv_candidate IS INITIAL OR lv_candidate CN '0123456789' OR strlen( lv_candidate ) > 10.
        CONTINUE.
      ENDIF.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = lv_candidate
        IMPORTING
          output = lv_belnr.

      SELECT SINGLE gjahr, bstat FROM bkpf
        WHERE bukrs = @is_proposal-bukrs
          AND belnr = @lv_belnr
          AND xblnr = @is_proposal-xblnr
        INTO @DATA(ls_bkpf).
      IF sy-subrc = 0.
        rs_result-belnr  = lv_belnr.
        rs_result-gjahr  = ls_bkpf-gjahr.
        rs_result-parked = xsdbool( ls_bkpf-bstat = 'V' ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
