CLASS zcl_zone_iarc_fb60 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Standart FB60 (Enjoy tedarikci faturasi) ekranini muhasebe onerisiyle
    " doldurup kullaniciya acar (Karar 030). Tek ekran - SAPMF05A 1100:
    "   baslik (Temel veriler sekmesi): islem (R fatura / G alacak dekontu),
    "   satici, tarihler, referans, brut tutar, PB, vergiyi hesapla, metin
    "   G/L satirlari tablo kontrolu: ACGL_ITEM-...(nn) - her KDV orani
    "   icin bir satir (hesap, matrah, vergi kodu, metin, masraf yeri).
    " Sirket kodu parametre ID'si (BUK) onceden set edilir - sirket kodu
    " popup'i cikmasin. Belge turu FB60'in varsayilanidir (Duzenleme
    " secenekleri). Calistirma/sonuc: ZCL_ZONE_IARC_BDC.

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
      BEGIN OF c_buscs,
        invoice TYPE c LENGTH 1 VALUE 'R',
        credit  TYPE c LENGTH 1 VALUE 'G',
      END OF c_buscs.
ENDCLASS.



CLASS zcl_zone_iarc_fb60 IMPLEMENTATION.

  METHOD run.
    DATA(lo_bdc) = NEW zcl_zone_iarc_bdc( ).
    DATA(ls_first) = VALUE zcl_zone_iarc_post=>ty_gl_line( is_proposal-lines[ 1 ] OPTIONAL ).

    SET PARAMETER ID 'BUK' FIELD is_proposal-bukrs.

    lo_bdc->screen( iv_program = 'SAPMF05A' iv_dynpro = '1100' ).
    lo_bdc->field( iv_name  = 'RF05A-BUSCS'
                   iv_value = COND string( WHEN is_proposal-credit_memo = abap_true
                                           THEN c_buscs-credit ELSE c_buscs-invoice ) ).
    lo_bdc->field( iv_name = 'INVFO-ACCNT' iv_value = is_proposal-lifnr ).
    lo_bdc->field( iv_name = 'INVFO-BLDAT' iv_value = zcl_zone_iarc_bdc=>date_text( is_proposal-bldat ) ).
    lo_bdc->field( iv_name = 'INVFO-BUDAT' iv_value = zcl_zone_iarc_bdc=>date_text( is_proposal-budat ) ).
    lo_bdc->field( iv_name = 'INVFO-XBLNR' iv_value = is_proposal-xblnr ).
    lo_bdc->field( iv_name = 'INVFO-WRBTR'
                   iv_value = zcl_zone_iarc_bdc=>amount_text( iv_amount = is_proposal-gross iv_waers = is_proposal-waers ) ).
    lo_bdc->field( iv_name = 'INVFO-WAERS' iv_value = is_proposal-waers ).
    lo_bdc->field( iv_name = 'INVFO-XMWST' iv_value = abap_true ).      " vergiyi hesapla
    lo_bdc->field( iv_name = 'INVFO-MWSKZ' iv_value = ls_first-mwskz ).
    lo_bdc->field( iv_name = 'INVFO-SGTXT' iv_value = is_proposal-bktxt ).

    LOOP AT is_proposal-lines INTO DATA(ls_line).
      DATA(lv_row) = |({ sy-tabix WIDTH = 2 ALIGN = RIGHT PAD = '0' })|.
      lo_bdc->field( iv_name = CONV #( |ACGL_ITEM-HKONT{ lv_row }| ) iv_value = ls_line-hkont ).
      lo_bdc->field( iv_name = CONV #( |ACGL_ITEM-WRBTR{ lv_row }| )
                     iv_value = zcl_zone_iarc_bdc=>amount_text( iv_amount = ls_line-amount iv_waers = is_proposal-waers ) ).
      lo_bdc->field( iv_name = CONV #( |ACGL_ITEM-MWSKZ{ lv_row }| ) iv_value = ls_line-mwskz ).
      lo_bdc->field( iv_name = CONV #( |ACGL_ITEM-SGTXT{ lv_row }| ) iv_value = ls_line-sgtxt ).
      IF ls_line-kostl IS NOT INITIAL.
        lo_bdc->field( iv_name = CONV #( |ACGL_ITEM-KOSTL{ lv_row }| ) iv_value = ls_line-kostl ).
      ENDIF.
    ENDLOOP.
    " OK kodu yok - ekran dolu acilir, kullanici Enter/Simule/Kaydet/Park
    " ile devam eder (NOBIEND).

    rs_result = lo_bdc->execute( iv_tcode = 'FB60' is_proposal = is_proposal iv_mode = iv_mode ).
  ENDMETHOD.

ENDCLASS.
