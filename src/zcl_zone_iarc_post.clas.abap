CLASS zcl_zone_iarc_post DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Gelen e-Arsiv faturasinin muhasebelestirilmesi (Karar 028).
    "
    " BUILD_PROPOSAL: saklanan UBL verisinden (T006/T009/T011) ve
    "   uyarlamadan (T005 gider hesabi/masraf yeri/belge turu, T017 KDV
    "   orani -> vergi kodu) tek bir muhasebe onerisi uretir. Hem BAPI hem
    "   FB01 ekran yolu (ZCL_ZONE_IARC_FB01) ayni oneriyi kullanir.
    " PARK_INVOICE: BAPI_INCOMINGINVOICE_PARK - siparissiz, G/L satirli
    "   MIRO park belgesi (MIR4'te gorunur, oradan duzeltilip kaydedilebilir).
    " POST_PARKED: BAPI_INCOMINGINVOICE_POST - park belgesini kesinlestirir.
    "
    " Kapsam: SIPARISSIZ (G/L) fatura. Siparisli (PO/GR 3'lu eslesme)
    " senaryo henuz yok - UBL'de siparis referansi okunmuyor.

    TYPES:
      BEGIN OF ty_gl_line,
        hkont  TYPE saknr,
        amount TYPE wrbtr,     " vergi haric (matrah)
        mwskz  TYPE mwskz,
        kostl  TYPE kostl,
        sgtxt  TYPE sgtxt,
      END OF ty_gl_line,
      tt_gl_line TYPE STANDARD TABLE OF ty_gl_line WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_proposal,
        provider_doc_id TYPE zone_iarc_t006-provider_doc_id,
        bukrs           TYPE bukrs,
        lifnr           TYPE lifnr,
        blart           TYPE blart,
        bldat           TYPE bldat,
        budat           TYPE budat,
        waers           TYPE waers,
        xblnr           TYPE xblnr1,
        bktxt           TYPE bktxt,
        gross           TYPE wrbtr,       " odenecek tutar (vergi dahil)
        credit_memo     TYPE abap_bool,   " InvoiceTypeCode = IADE
        lines           TYPE tt_gl_line,
      END OF ty_proposal.

    TYPES:
      BEGIN OF ty_doc_ref,
        belnr TYPE belnr_d,
        gjahr TYPE gjahr,
      END OF ty_doc_ref.

    METHODS build_proposal
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_proposal)  TYPE ty_proposal
      RAISING
        zcx_zone_iarc_mapping.

    METHODS park_invoice
      IMPORTING
        !is_proposal  TYPE ty_proposal
      RETURNING
        VALUE(rs_doc) TYPE ty_doc_ref
      RAISING
        zcx_zone_iarc_mapping.

    METHODS post_parked
      IMPORTING
        !iv_belnr TYPE belnr_d
        !iv_gjahr TYPE gjahr
      RAISING
        zcx_zone_iarc_mapping.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_default_blart TYPE blart VALUE 'KR'.   " T005-DEFAULT_BLART bossa

    TYPES tt_t011 TYPE STANDARD TABLE OF zone_iarc_t011 WITH DEFAULT KEY.

    METHODS raise_error
      IMPORTING
        !iv_code TYPE string
        !iv_text TYPE string
      RAISING
        zcx_zone_iarc_mapping.

    " RETURN tablosunda E/A varsa geri alir ve hata firlatir, yoksa COMMIT.
    METHODS finish_bapi
      IMPORTING
        !it_return TYPE bapiret2_t
        !iv_code   TYPE string
      RAISING
        zcx_zone_iarc_mapping.
ENDCLASS.



CLASS zcl_zone_iarc_post IMPLEMENTATION.

  METHOD build_proposal.
    SELECT SINGLE * FROM zone_iarc_t006
      WHERE provider_doc_id = @iv_provider_doc_id
      INTO @DATA(ls_queue).
    IF sy-subrc <> 0.
      raise_error( iv_code = `IARC_POST_010` iv_text = |Belge bulunamadi: { iv_provider_doc_id }| ) ##NO_TEXT.
    ENDIF.
    IF ls_queue-lifnr IS INITIAL.
      raise_error( iv_code = `IARC_POST_011`
                   iv_text = |Tedarikci eslenmemis (VKN { ls_queue-supplier_vkn }) - eslemeyi yapip "Yeniden Isle" calistirin| ) ##NO_TEXT.
    ENDIF.

    SELECT SINGLE * FROM zone_iarc_t009
      WHERE bukrs = @ls_queue-bukrs AND ettn = @ls_queue-ettn
      INTO @DATA(ls_header).
    IF sy-subrc <> 0.
      raise_error( iv_code = `IARC_POST_012` iv_text = |UBL basligi yok (T009) - belge parse edilmemis| ) ##NO_TEXT.
    ENDIF.

    DATA lt_tax TYPE tt_t011.
    SELECT * FROM zone_iarc_t011
      WHERE bukrs = @ls_queue-bukrs AND ettn = @ls_queue-ettn
      ORDER BY seq_no
      INTO TABLE @lt_tax.

    " Siparissiz kural (PO_MATCH = bos) - siparisli senaryo henuz yok.
    DATA lv_hkont TYPE saknr.
    DATA lv_mwskz TYPE mwskz.
    DATA lv_kostl TYPE kostl.
    DATA lv_blart TYPE blart.
    DATA lv_tol   TYPE i.
    DATA(lo_config) = NEW zcl_zone_iarc_config( ).
    lo_config->get_posting_rule(
      EXPORTING
        iv_bukrs         = ls_queue-bukrs
        iv_po_match      = abap_false
      IMPORTING
        ev_hkont         = lv_hkont
        ev_mwskz         = lv_mwskz
        ev_tolerance_pct = lv_tol
        ev_kostl         = lv_kostl
        ev_blart         = lv_blart ).
    IF lv_hkont IS INITIAL.
      raise_error( iv_code = `IARC_POST_013`
                   iv_text = |ZONE_IARC_T005'te { ls_queue-bukrs } icin siparissiz kural / gider hesabi yok| ) ##NO_TEXT.
    ENDIF.

    rs_proposal-provider_doc_id = ls_queue-provider_doc_id.
    rs_proposal-bukrs           = ls_queue-bukrs.
    rs_proposal-lifnr           = ls_queue-lifnr.
    rs_proposal-blart           = COND #( WHEN lv_blart IS NOT INITIAL THEN lv_blart ELSE c_default_blart ).
    rs_proposal-bldat           = ls_header-issue_date.
    rs_proposal-budat           = sy-datum.
    rs_proposal-waers           = ls_header-doc_currency.
    rs_proposal-xblnr           = ls_header-invoice_id.
    rs_proposal-bktxt           = |e-Arsiv { ls_header-invoice_id }| ##NO_TEXT.
    rs_proposal-gross           = ls_header-payable_amount.
    rs_proposal-credit_memo     = xsdbool( ls_header-inv_type_code = 'IADE' ).

    " Her KDV alt toplami bir gider satiri (matrah + vergi kodu). Alt toplam
    " yoksa tek satir: vergi haric tutar + varsayilan vergi kodu.
    LOOP AT lt_tax INTO DATA(ls_tax).
      DATA(lv_line_mwskz) = lo_config->get_tax_code( iv_bukrs = ls_queue-bukrs iv_tax_percent = ls_tax-tax_percent ).
      IF lv_line_mwskz IS INITIAL.
        lv_line_mwskz = lv_mwskz.
      ENDIF.
      APPEND VALUE #( hkont  = lv_hkont
                      amount = ls_tax-taxable_amount
                      mwskz  = lv_line_mwskz
                      kostl  = lv_kostl
                      sgtxt  = |{ ls_header-invoice_id } KDV %{ ls_tax-tax_percent ALPHA = OUT }| )
        TO rs_proposal-lines ##NO_TEXT.
    ENDLOOP.
    IF rs_proposal-lines IS INITIAL.
      APPEND VALUE #( hkont  = lv_hkont
                      amount = ls_header-tax_excl_amount
                      mwskz  = lv_mwskz
                      kostl  = lv_kostl
                      sgtxt  = |{ ls_header-invoice_id }| )
        TO rs_proposal-lines.
    ENDIF.

    IF line_exists( rs_proposal-lines[ mwskz = space ] ).
      raise_error( iv_code = `IARC_POST_014`
                   iv_text = |Vergi kodu belirlenemedi - ZONE_IARC_T017 (KDV orani) ya da T005-DEFAULT_MWSKZ girin| ) ##NO_TEXT.
    ENDIF.
  ENDMETHOD.

  METHOD park_invoice.
    DATA ls_header TYPE bapi_incinv_create_header.
    DATA lt_item   TYPE STANDARD TABLE OF bapi_incinv_create_item WITH DEFAULT KEY.
    DATA lt_gl     TYPE STANDARD TABLE OF bapi_incinv_create_gl_account WITH DEFAULT KEY.
    DATA lt_return TYPE bapiret2_t.
    DATA lv_item   TYPE rblgp.

    ls_header-invoice_ind  = xsdbool( is_proposal-credit_memo = abap_false ).   " X=fatura, bos=alacak dekontu
    ls_header-doc_date     = is_proposal-bldat.
    ls_header-pstng_date   = is_proposal-budat.
    ls_header-ref_doc_no   = is_proposal-xblnr.
    ls_header-comp_code    = is_proposal-bukrs.
    ls_header-diff_inv     = is_proposal-lifnr.       " siparissiz faturada satici buradan
    ls_header-currency     = is_proposal-waers.
    ls_header-gross_amount = is_proposal-gross.
    ls_header-calc_tax_ind = abap_true.
    ls_header-bline_date   = is_proposal-bldat.
    ls_header-header_txt   = is_proposal-bktxt.

    LOOP AT is_proposal-lines INTO DATA(ls_line).
      lv_item = lv_item + 1.
      APPEND VALUE #( invoice_doc_item = lv_item
                      gl_account       = ls_line-hkont
                      item_amount      = ls_line-amount
                      db_cr_ind        = 'S'
                      comp_code        = is_proposal-bukrs
                      tax_code         = ls_line-mwskz
                      costcenter       = ls_line-kostl
                      item_text        = ls_line-sgtxt ) TO lt_gl.
    ENDLOOP.

    CALL FUNCTION 'BAPI_INCOMINGINVOICE_PARK'
      EXPORTING
        headerdata       = ls_header
      IMPORTING
        invoicedocnumber = rs_doc-belnr
        fiscalyear       = rs_doc-gjahr
      TABLES
        itemdata         = lt_item
        glaccountdata    = lt_gl
        return           = lt_return.

    IF rs_doc-belnr IS INITIAL AND NOT line_exists( lt_return[ type = 'E' ] ).
      APPEND VALUE #( type = 'E' message = 'Park belgesi numarasi donmedi' ) TO lt_return ##NO_TEXT.
    ENDIF.
    finish_bapi( it_return = lt_return iv_code = `IARC_POST_020` ).
  ENDMETHOD.

  METHOD post_parked.
    DATA lt_return TYPE bapiret2_t.

    CALL FUNCTION 'BAPI_INCOMINGINVOICE_POST'
      EXPORTING
        invoicedocnumber = iv_belnr
        fiscalyear       = iv_gjahr
      TABLES
        return           = lt_return.

    finish_bapi( it_return = lt_return iv_code = `IARC_POST_030` ).
  ENDMETHOD.

  METHOD finish_bapi.
    LOOP AT it_return INTO DATA(ls_return) WHERE type = 'E' OR type = 'A'.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      raise_error( iv_code = iv_code iv_text = CONV #( ls_return-message ) ).
    ENDLOOP.

    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = abap_true.
  ENDMETHOD.

  METHOD raise_error.
    RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
      EXPORTING
        iv_error_code = iv_code
        iv_detail     = iv_text.
  ENDMETHOD.

ENDCLASS.
