CLASS zcl_zone_iarc_fb01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Standart FB01 ekranlarini muhasebe onerisiyle (ZCL_ZONE_IARC_POST=>
    " BUILD_PROPOSAL) doldurup kullaniciya acar (Karar 028/030):
    "   SAPMF05A 0100 - baslik (tarih, belge turu, sirket, PB, referans)
    "                   + satici satiri kaydi anahtari (31 / iade 21)
    "   SAPMF05A 0302 - satici satiri (brut tutar, vergi hesapla)
    "   SAPMF05A 0300 - gider satir(lar)i (40 / iade 50; matrah, vergi kodu)
    " Calistirma/sonuc: ZCL_ZONE_IARC_BDC.

    METHODS run
      IMPORTING
        !is_proposal     TYPE zcl_zone_iarc_post=>ty_proposal
        !iv_mode         TYPE ctu_params-dismode DEFAULT 'A'
      RETURNING
        VALUE(rs_result) TYPE zcl_zone_iarc_bdc=>ty_result
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
ENDCLASS.



CLASS zcl_zone_iarc_fb01 IMPLEMENTATION.

  METHOD run.
    DATA(lo_bdc) = NEW zcl_zone_iarc_bdc( ).

    DATA(lv_vendor_key) = COND bschl( WHEN is_proposal-credit_memo = abap_true
                                      THEN c_bschl-vendor_credit ELSE c_bschl-vendor_invoice ).
    DATA(lv_gl_key)     = COND bschl( WHEN is_proposal-credit_memo = abap_true
                                      THEN c_bschl-gl_credit ELSE c_bschl-gl_debit ).
    DATA(ls_first)      = VALUE zcl_zone_iarc_post=>ty_gl_line( is_proposal-lines[ 1 ] OPTIONAL ).

    " --- Baslik + satici satiri anahtari
    lo_bdc->screen( iv_program = 'SAPMF05A' iv_dynpro = '0100' ).
    lo_bdc->field( iv_name = 'BKPF-BLDAT' iv_value = zcl_zone_iarc_bdc=>date_text( is_proposal-bldat ) ).
    lo_bdc->field( iv_name = 'BKPF-BLART' iv_value = is_proposal-blart ).
    lo_bdc->field( iv_name = 'BKPF-BUKRS' iv_value = is_proposal-bukrs ).
    lo_bdc->field( iv_name = 'BKPF-BUDAT' iv_value = zcl_zone_iarc_bdc=>date_text( is_proposal-budat ) ).
    lo_bdc->field( iv_name = 'BKPF-WAERS' iv_value = is_proposal-waers ).
    lo_bdc->field( iv_name = 'BKPF-XBLNR' iv_value = is_proposal-xblnr ).
    lo_bdc->field( iv_name = 'BKPF-BKTXT' iv_value = is_proposal-bktxt ).
    lo_bdc->field( iv_name = 'RF05A-NEWBS' iv_value = lv_vendor_key ).
    lo_bdc->field( iv_name = 'RF05A-NEWKO' iv_value = is_proposal-lifnr ).
    lo_bdc->field( iv_name = 'BDC_OKCODE' iv_value = '/00' ).

    " --- Satici satiri (brut) + ilk gider satirinin anahtari
    lo_bdc->screen( iv_program = 'SAPMF05A' iv_dynpro = '0302' ).
    lo_bdc->field( iv_name = 'BSEG-WRBTR'
                   iv_value = zcl_zone_iarc_bdc=>amount_text( iv_amount = is_proposal-gross iv_waers = is_proposal-waers ) ).
    lo_bdc->field( iv_name = 'BKPF-XMWST' iv_value = abap_true ).        " vergiyi hesapla
    lo_bdc->field( iv_name = 'BSEG-MWSKZ' iv_value = ls_first-mwskz ).
    lo_bdc->field( iv_name = 'BSEG-ZFBDT' iv_value = zcl_zone_iarc_bdc=>date_text( is_proposal-bldat ) ).
    lo_bdc->field( iv_name = 'BSEG-SGTXT' iv_value = is_proposal-bktxt ).
    lo_bdc->field( iv_name = 'RF05A-NEWBS' iv_value = lv_gl_key ).
    lo_bdc->field( iv_name = 'RF05A-NEWKO' iv_value = ls_first-hkont ).
    lo_bdc->field( iv_name = 'BDC_OKCODE' iv_value = '/00' ).

    " --- Gider satirlari (her KDV orani icin bir satir)
    DATA(lv_count) = lines( is_proposal-lines ).
    LOOP AT is_proposal-lines INTO DATA(ls_line).
      DATA(lv_index) = sy-tabix.
      lo_bdc->screen( iv_program = 'SAPMF05A' iv_dynpro = '0300' ).
      lo_bdc->field( iv_name = 'BSEG-WRBTR'
                     iv_value = zcl_zone_iarc_bdc=>amount_text( iv_amount = ls_line-amount iv_waers = is_proposal-waers ) ).
      lo_bdc->field( iv_name = 'BSEG-MWSKZ' iv_value = ls_line-mwskz ).
      lo_bdc->field( iv_name = 'BSEG-SGTXT' iv_value = ls_line-sgtxt ).
      IF ls_line-kostl IS NOT INITIAL.
        lo_bdc->field( iv_name = 'COBL-KOSTL' iv_value = ls_line-kostl ).
      ENDIF.
      IF lv_index < lv_count.
        DATA(ls_next) = is_proposal-lines[ lv_index + 1 ].
        lo_bdc->field( iv_name = 'RF05A-NEWBS' iv_value = lv_gl_key ).
        lo_bdc->field( iv_name = 'RF05A-NEWKO' iv_value = ls_next-hkont ).
        lo_bdc->field( iv_name = 'BDC_OKCODE' iv_value = '/00' ).
      ENDIF.
      " Son satirda OK kodu yok - kontrol kullaniciya gecer (NOBIEND).
    ENDLOOP.

    rs_result = lo_bdc->execute( iv_tcode = 'FB01' is_proposal = is_proposal iv_mode = iv_mode ).
  ENDMETHOD.

ENDCLASS.
