CLASS zcl_zone_iarc_fb01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Standart FB01 ekranlarini muhasebe onerisiyle (ZCL_ZONE_IARC_POST=>
    " BUILD_PROPOSAL) doldurup kullaniciya acar (Karar 028):
    "   SAPMF05A 0100 - baslik (tarih, belge turu, sirket, PB, referans)
    "                   + satici satiri kaydi anahtari (31 / iade 21)
    "   SAPMF05A 0302 - satici satiri (brut tutar, vergi hesapla)
    "   SAPMF05A 0300 - gider satir(lar)i (40 / iade 50; matrah, vergi kodu)
    " CTU_PARAMS-NOBIEND = X: veri bitince islem diyalogda devam eder -
    " kullanici kontrol eder, eksik alani (orn. kodlama blogu) tamamlar ve
    " KAYDET ya da menuden PARK eder. Olusan belge no mesajlardan okunur,
    " BKPF'den dogrulanir.

    TYPES:
      BEGIN OF ty_result,
        belnr  TYPE belnr_d,
        gjahr  TYPE gjahr,
        parked TYPE abap_bool,   " BKPF-BSTAT = V (park edildi)
      END OF ty_result.

    METHODS run
      IMPORTING
        !is_proposal     TYPE zcl_zone_iarc_post=>ty_proposal
        !iv_mode         TYPE ctu_params-dismode DEFAULT 'A'
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_zone_iarc_mapping.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF c_bschl,
        vendor_invoice TYPE bschl VALUE '31',
        vendor_credit  TYPE bschl VALUE '21',
        gl_debit       TYPE bschl VALUE '40',
        gl_credit      TYPE bschl VALUE '50',
      END OF c_bschl.

    TYPES tt_msg TYPE STANDARD TABLE OF bdcmsgcoll WITH DEFAULT KEY.
    DATA mt_bdc TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY.

    METHODS build_bdc
      IMPORTING
        !is_proposal TYPE zcl_zone_iarc_post=>ty_proposal.
    METHODS screen
      IMPORTING
        !iv_program TYPE bdcdata-program
        !iv_dynpro  TYPE bdcdata-dynpro.
    METHODS field
      IMPORTING
        !iv_name  TYPE bdcdata-fnam
        !iv_value TYPE csequence.
    METHODS amount_text
      IMPORTING
        !iv_amount     TYPE wrbtr
        !iv_waers      TYPE waers
      RETURNING
        VALUE(rv_text) TYPE bdcdata-fval.
    METHODS date_text
      IMPORTING
        !iv_date       TYPE d
      RETURNING
        VALUE(rv_text) TYPE bdcdata-fval.
    METHODS find_document
      IMPORTING
        !it_msg          TYPE tt_msg
        !is_proposal     TYPE zcl_zone_iarc_post=>ty_proposal
      RETURNING
        VALUE(rs_result) TYPE ty_result.
ENDCLASS.



CLASS zcl_zone_iarc_fb01 IMPLEMENTATION.

  METHOD run.
    DATA lt_msg TYPE tt_msg.
    DATA ls_opt TYPE ctu_params.

    build_bdc( is_proposal ).

    ls_opt-dismode = iv_mode.
    ls_opt-updmode = 'S'.          " senkron - belge hemen BKPF'de okunabilsin
    ls_opt-nobiend = abap_true.    " veri bitince diyalog devam etsin
    ls_opt-defsize = abap_true.

    TRY.
        CALL TRANSACTION 'FB01' WITH AUTHORITY-CHECK
          USING mt_bdc
          OPTIONS FROM ls_opt
          MESSAGES INTO lt_msg.
      CATCH cx_sy_authorization_error.
        RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
          EXPORTING
            iv_error_code = 'IARC_FB01_001'
            iv_detail     = 'FB01 islem yetkiniz yok'.
    ENDTRY.

    rs_result = find_document( it_msg = lt_msg is_proposal = is_proposal ).
  ENDMETHOD.

  METHOD build_bdc.
    CLEAR mt_bdc.

    DATA(lv_vendor_key) = COND bschl( WHEN is_proposal-credit_memo = abap_true
                                      THEN c_bschl-vendor_credit ELSE c_bschl-vendor_invoice ).
    DATA(lv_gl_key)     = COND bschl( WHEN is_proposal-credit_memo = abap_true
                                      THEN c_bschl-gl_credit ELSE c_bschl-gl_debit ).
    DATA(ls_first)      = VALUE zcl_zone_iarc_post=>ty_gl_line( is_proposal-lines[ 1 ] OPTIONAL ).

    " --- Baslik + satici satiri anahtari
    screen( iv_program = 'SAPMF05A' iv_dynpro = '0100' ).
    field( iv_name = 'BKPF-BLDAT' iv_value = date_text( is_proposal-bldat ) ).
    field( iv_name = 'BKPF-BLART' iv_value = is_proposal-blart ).
    field( iv_name = 'BKPF-BUKRS' iv_value = is_proposal-bukrs ).
    field( iv_name = 'BKPF-BUDAT' iv_value = date_text( is_proposal-budat ) ).
    field( iv_name = 'BKPF-WAERS' iv_value = is_proposal-waers ).
    field( iv_name = 'BKPF-XBLNR' iv_value = is_proposal-xblnr ).
    field( iv_name = 'BKPF-BKTXT' iv_value = is_proposal-bktxt ).
    field( iv_name = 'RF05A-NEWBS' iv_value = lv_vendor_key ).
    field( iv_name = 'RF05A-NEWKO' iv_value = is_proposal-lifnr ).
    field( iv_name = 'BDC_OKCODE' iv_value = '/00' ).

    " --- Satici satiri (brut) + ilk gider satirinin anahtari
    screen( iv_program = 'SAPMF05A' iv_dynpro = '0302' ).
    field( iv_name = 'BSEG-WRBTR' iv_value = amount_text( iv_amount = is_proposal-gross iv_waers = is_proposal-waers ) ).
    field( iv_name = 'BKPF-XMWST' iv_value = abap_true ).        " vergiyi hesapla
    field( iv_name = 'BSEG-MWSKZ' iv_value = ls_first-mwskz ).
    field( iv_name = 'BSEG-ZFBDT' iv_value = date_text( is_proposal-bldat ) ).
    field( iv_name = 'BSEG-SGTXT' iv_value = is_proposal-bktxt ).
    field( iv_name = 'RF05A-NEWBS' iv_value = lv_gl_key ).
    field( iv_name = 'RF05A-NEWKO' iv_value = ls_first-hkont ).
    field( iv_name = 'BDC_OKCODE' iv_value = '/00' ).

    " --- Gider satirlari (her KDV orani icin bir satir)
    DATA(lv_count) = lines( is_proposal-lines ).
    LOOP AT is_proposal-lines INTO DATA(ls_line).
      DATA(lv_index) = sy-tabix.
      screen( iv_program = 'SAPMF05A' iv_dynpro = '0300' ).
      field( iv_name = 'BSEG-WRBTR' iv_value = amount_text( iv_amount = ls_line-amount iv_waers = is_proposal-waers ) ).
      field( iv_name = 'BSEG-MWSKZ' iv_value = ls_line-mwskz ).
      field( iv_name = 'BSEG-SGTXT' iv_value = ls_line-sgtxt ).
      IF ls_line-kostl IS NOT INITIAL.
        field( iv_name = 'COBL-KOSTL' iv_value = ls_line-kostl ).
      ENDIF.
      IF lv_index < lv_count.
        DATA(ls_next) = is_proposal-lines[ lv_index + 1 ].
        field( iv_name = 'RF05A-NEWBS' iv_value = lv_gl_key ).
        field( iv_name = 'RF05A-NEWKO' iv_value = ls_next-hkont ).
        field( iv_name = 'BDC_OKCODE' iv_value = '/00' ).
      ENDIF.
      " Son satirda OK kodu yok - kontrol kullaniciya gecer (NOBIEND).
    ENDLOOP.
  ENDMETHOD.

  METHOD screen.
    APPEND VALUE #( program = iv_program dynpro = iv_dynpro dynbegin = abap_true ) TO mt_bdc.
  ENDMETHOD.

  METHOD field.
    APPEND VALUE #( fnam = iv_name fval = iv_value ) TO mt_bdc.
  ENDMETHOD.

  METHOD amount_text.
    " Kullanici ondalik bicimi (orn. 2902,50) - binlik ayraci olmadan.
    WRITE iv_amount TO rv_text CURRENCY iv_waers NO-GROUPING LEFT-JUSTIFIED.
  ENDMETHOD.

  METHOD date_text.
    WRITE iv_date TO rv_text.
  ENDMETHOD.

  METHOD find_document.
    " FB01 basari mesaji (F5 312 "Belge & ... kaydedildi") ya da park
    " mesaji: ilk degiskende belge no. Referans (XBLNR) ile BKPF'den
    " dogrulanir; kullanici kaydetmeden cikarsa sonuc bos doner.
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
