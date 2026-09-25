CLASS zcl_zone_iarc_store DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Parse edilmis UBL canonical modelini (ZIF_ZONE_IARC_TYPES=>ty_header)
    " normalize tablolara (ZONE_IARC_T009..T016) yazar. Anahtar zinciri:
    " BUKRS + ETTN (baslik ve baslik-alt tablolari), + LINE_NO (kalem ve
    " kalem-alt tablolari). T015 (gonderici/satici) ve T016 (alici) tam
    " UBL Party detayini (adres/vergi dairesi/iletisim) tekil (1 belge = 1
    " satici + 1 alici) tasir. Tekrar cagirma (retry) korumasi yok -
    " yukarida ZCL_ZONE_IARC_PARSER->is_duplicate( ) ile PROVIDER_DOC_ID
    " bazinda zaten engelleniyor (bkz. ZCL_ZONE_IARC_POLLER).

    METHODS save
      IMPORTING
        !iv_bukrs           TYPE bukrs
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
        !is_header          TYPE zif_zone_iarc_types=>ty_header.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_store IMPLEMENTATION.

  METHOD save.
    " --- T009: Baslik (tekil) ---
    DATA ls_t009 TYPE zone_iarc_t009.
    ls_t009-bukrs           = iv_bukrs.
    ls_t009-ettn            = is_header-uuid.
    ls_t009-provider_doc_id = iv_provider_doc_id.
    ls_t009-invoice_id      = is_header-invoice_id.
    ls_t009-issue_date      = is_header-issue_date.
    ls_t009-issue_time      = is_header-issue_time.
    ls_t009-inv_type_code   = is_header-inv_type_code.
    ls_t009-profile_id      = is_header-profile_id.
    ls_t009-copy_ind        = COND #( WHEN is_header-copy_indicator = abap_true THEN abap_true ELSE space ).
    ls_t009-doc_currency    = is_header-currency.
    ls_t009-supplier_vkn    = is_header-supplier_vkn.
    ls_t009-supplier_name   = is_header-supplier_name.
    ls_t009-customer_vkn    = is_header-customer_vkn.
    ls_t009-customer_name   = is_header-customer_name.
    ls_t009-line_ext_amount = is_header-line_ext_amount.
    ls_t009-tax_excl_amount = is_header-tax_excl_amount.
    ls_t009-tax_incl_amount = is_header-tax_incl_amount.
    ls_t009-allow_total     = is_header-allow_total.
    ls_t009-charge_total    = is_header-charge_total.
    ls_t009-payable_amount  = is_header-payable_amount.
    ls_t009-tax_amount      = is_header-tax_amount.
    ls_t009-line_count      = lines( is_header-line ).
    ls_t009-created_by      = sy-uname.
    GET TIME STAMP FIELD ls_t009-created_at.
    INSERT zone_iarc_t009 FROM @ls_t009.

    " --- T015/T016: Gonderici (satici) / Alici tam Party detayi (tekil) ---
    IF is_header-supplier_party IS NOT INITIAL.
      DATA(ls_t015) = CORRESPONDING zone_iarc_t015( is_header-supplier_party ).
      ls_t015-bukrs = iv_bukrs.
      ls_t015-ettn  = is_header-uuid.
      INSERT zone_iarc_t015 FROM @ls_t015.
    ENDIF.
    IF is_header-customer_party IS NOT INITIAL.
      DATA(ls_t016) = CORRESPONDING zone_iarc_t016( is_header-customer_party ).
      ls_t016-bukrs = iv_bukrs.
      ls_t016-ettn  = is_header-uuid.
      INSERT zone_iarc_t016 FROM @ls_t016.
    ENDIF.

    " --- T010: Baslik notlari (tekrarli) ---
    DATA lt_t010 TYPE STANDARD TABLE OF zone_iarc_t010.
    LOOP AT is_header-note INTO DATA(ls_note).
      APPEND VALUE #(
        bukrs     = iv_bukrs
        ettn      = is_header-uuid
        seq_no    = ls_note-seq_no
        note_text = ls_note-text ) TO lt_t010.
    ENDLOOP.
    IF lt_t010 IS NOT INITIAL.
      INSERT zone_iarc_t010 FROM TABLE @lt_t010.
    ENDIF.

    " --- T011: Baslik vergi alt toplamlari (tekrarli) ---
    DATA lt_t011 TYPE STANDARD TABLE OF zone_iarc_t011.
    LOOP AT is_header-tax_subtotal INTO DATA(ls_hdr_tax).
      APPEND VALUE #(
        bukrs          = iv_bukrs
        ettn           = is_header-uuid
        seq_no         = ls_hdr_tax-seq_no
        taxable_amount = ls_hdr_tax-taxable_amount
        tax_amount     = ls_hdr_tax-tax_amount
        tax_percent    = ls_hdr_tax-tax_percent
        tax_cat_name   = ls_hdr_tax-tax_cat_name
        tax_type_code  = ls_hdr_tax-tax_type_code ) TO lt_t011.
    ENDLOOP.
    IF lt_t011 IS NOT INITIAL.
      INSERT zone_iarc_t011 FROM TABLE @lt_t011.
    ENDIF.

    " --- T012/T013/T014: Kalemler + kalem notlari + kalem vergi alt toplamlari ---
    DATA lt_t012 TYPE STANDARD TABLE OF zone_iarc_t012.
    DATA lt_t013 TYPE STANDARD TABLE OF zone_iarc_t013.
    DATA lt_t014 TYPE STANDARD TABLE OF zone_iarc_t014.

    LOOP AT is_header-line INTO DATA(ls_line).
      APPEND VALUE #(
        bukrs       = iv_bukrs
        ettn        = is_header-uuid
        line_no     = ls_line-line_no
        item_name   = ls_line-description
        quantity    = ls_line-quantity
        uom_code    = ls_line-uom_code
        unit_price  = ls_line-unit_price
        line_amount = ls_line-line_amount
        tax_amount  = ls_line-tax_amount ) TO lt_t012.

      LOOP AT ls_line-note INTO DATA(ls_line_note).
        APPEND VALUE #(
          bukrs     = iv_bukrs
          ettn      = is_header-uuid
          line_no   = ls_line-line_no
          seq_no    = ls_line_note-seq_no
          note_text = ls_line_note-text ) TO lt_t013.
      ENDLOOP.

      LOOP AT ls_line-tax_subtotal INTO DATA(ls_line_tax).
        APPEND VALUE #(
          bukrs          = iv_bukrs
          ettn           = is_header-uuid
          line_no        = ls_line-line_no
          seq_no         = ls_line_tax-seq_no
          taxable_amount = ls_line_tax-taxable_amount
          tax_amount     = ls_line_tax-tax_amount
          tax_percent    = ls_line_tax-tax_percent
          tax_cat_name   = ls_line_tax-tax_cat_name
          tax_type_code  = ls_line_tax-tax_type_code ) TO lt_t014.
      ENDLOOP.
    ENDLOOP.

    IF lt_t012 IS NOT INITIAL.
      INSERT zone_iarc_t012 FROM TABLE @lt_t012.
    ENDIF.
    IF lt_t013 IS NOT INITIAL.
      INSERT zone_iarc_t013 FROM TABLE @lt_t013.
    ENDIF.
    IF lt_t014 IS NOT INITIAL.
      INSERT zone_iarc_t014 FROM TABLE @lt_t014.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
