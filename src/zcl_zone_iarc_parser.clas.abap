CLASS zcl_zone_iarc_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS parse
      IMPORTING
        !iv_xml TYPE xstring
      RETURNING
        VALUE(rs_header) TYPE zif_zone_iarc_types=>ty_header
      RAISING
        zcx_zone_iarc_mapping.

    METHODS is_duplicate
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rv_duplicate) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
    " Namespace-literal (cbc:/cac: prefiksi GIB tarafindan sabit kabul
    " edilir - bkz. sap-edonusum-team/program/ubl-tr-field-inventory.md
    " §1 "TR namespace"). Gercek namespace-URI farkindaligi (prefiks
    " degisirse de calisan cozum) icin get_elements_by_tag_name_ns
    " kullanilmali - bu ilk implementasyon prefiks sabitligine guvenir.

    TYPES ty_elements TYPE STANDARD TABLE OF REF TO if_ixml_element WITH EMPTY KEY.

    METHODS get_child_text
      IMPORTING
        !io_scope    TYPE REF TO if_ixml_element
        !iv_tag_name TYPE string
        !iv_depth    TYPE i DEFAULT 1
      RETURNING
        VALUE(rv_value) TYPE string.

    METHODS get_child_element
      IMPORTING
        !io_scope    TYPE REF TO if_ixml_element
        !iv_tag_name TYPE string
        !iv_depth    TYPE i DEFAULT 1
      RETURNING
        VALUE(ro_element) TYPE REF TO if_ixml_element.

    METHODS get_child_elements
      IMPORTING
        !io_scope    TYPE REF TO if_ixml_element
        !iv_tag_name TYPE string
        !iv_depth    TYPE i DEFAULT 1
      RETURNING
        VALUE(rt_elements) TYPE ty_elements.

    METHODS parse_notes
      IMPORTING
        !io_scope TYPE REF TO if_ixml_element
      RETURNING
        VALUE(rt_note) TYPE zif_zone_iarc_types=>tt_note.

    METHODS parse_tax_subtotals
      IMPORTING
        !io_tax_total TYPE REF TO if_ixml_element
      RETURNING
        VALUE(rt_subtotal) TYPE zif_zone_iarc_types=>tt_tax_subtotal.

    METHODS parse_line
      IMPORTING
        !io_line    TYPE REF TO if_ixml_element
        !iv_line_no TYPE i
      RETURNING
        VALUE(rs_line) TYPE zif_zone_iarc_types=>ty_line.
ENDCLASS.



CLASS zcl_zone_iarc_parser IMPLEMENTATION.

  METHOD is_duplicate.
    SELECT SINGLE @abap_true FROM zone_iarc_t006
      INTO @rv_duplicate
      WHERE provider_doc_id = @iv_provider_doc_id.
    IF sy-subrc <> 0.
      rv_duplicate = abap_false.
    ENDIF.
  ENDMETHOD.

  METHOD parse.
    DATA(lo_ixml)       = cl_ixml=>create( ).
    DATA(lo_stream_fac) = lo_ixml->create_stream_factory( ).
    DATA(lo_istream)    = lo_stream_fac->create_istream_xstring( string = iv_xml ).
    DATA(lo_document)   = lo_ixml->create_document( ).
    DATA(lo_parser)     = lo_ixml->create_parser(
                             stream_factory = lo_stream_fac
                             istream        = lo_istream
                             document       = lo_document ).

    IF lo_parser->parse( ) <> 0.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_PARSE_001'
          iv_detail     = 'UBL XML parse edilemedi (gecersiz XML)'.
    ENDIF.

    DATA(lo_root) = lo_document->get_root_element( ).
    IF lo_root IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_PARSE_002'
          iv_detail     = 'UBL XML kok elementi bulunamadi'.
    ENDIF.

    " --- Header ana alanlari: root'un dogrudan cocuklari (depth=1) -
    "     InvoiceLine icindeki ayni isimli alanlarla (ornegin cbc:ID)
    "     karismamasi icin.
    rs_header-uuid          = get_child_text( io_scope = lo_root iv_tag_name = 'cbc:UUID' ).
    rs_header-invoice_id    = get_child_text( io_scope = lo_root iv_tag_name = 'cbc:ID' ).
    rs_header-inv_type_code = get_child_text( io_scope = lo_root iv_tag_name = 'cbc:InvoiceTypeCode' ).
    rs_header-profile_id    = get_child_text( io_scope = lo_root iv_tag_name = 'cbc:ProfileID' ).

    DATA(lv_copy_ind) = get_child_text( io_scope = lo_root iv_tag_name = 'cbc:CopyIndicator' ).
    rs_header-copy_indicator = COND #( WHEN lv_copy_ind = 'true' THEN abap_true ELSE abap_false ).

    DATA(lv_issue_date) = get_child_text( io_scope = lo_root iv_tag_name = 'cbc:IssueDate' ).
    REPLACE ALL OCCURRENCES OF '-' IN lv_issue_date WITH ''. " UBL: YYYY-MM-DD -> DATS YYYYMMDD
    IF lv_issue_date CO '0123456789' AND strlen( lv_issue_date ) = 8.
      rs_header-issue_date = lv_issue_date.
    ENDIF.

    DATA(lv_issue_time) = get_child_text( io_scope = lo_root iv_tag_name = 'cbc:IssueTime' ).
    REPLACE ALL OCCURRENCES OF ':' IN lv_issue_time WITH ''. " UBL: HH:MM:SS -> UZEIT HHMMSS
    IF lv_issue_time CO '0123456789' AND strlen( lv_issue_time ) = 6.
      rs_header-issue_time = lv_issue_time.
    ENDIF.

    rs_header-note = parse_notes( lo_root ).

    " --- Satici (cac:AccountingSupplierParty/cac:Party/...).
    DATA(lo_supplier_party) = get_child_element( io_scope = lo_root iv_tag_name = 'cac:AccountingSupplierParty' ).
    IF lo_supplier_party IS BOUND.
      DATA(lo_supplier) = get_child_element( io_scope = lo_supplier_party iv_tag_name = 'cac:Party' iv_depth = 1 ).
      IF lo_supplier IS BOUND.
        DATA(lo_supplier_id) = get_child_element( io_scope = lo_supplier iv_tag_name = 'cac:PartyIdentification' iv_depth = 1 ).
        IF lo_supplier_id IS BOUND.
          rs_header-supplier_vkn = get_child_text( io_scope = lo_supplier_id iv_tag_name = 'cbc:ID' ).
        ENDIF.
        DATA(lo_supplier_name_el) = get_child_element( io_scope = lo_supplier iv_tag_name = 'cac:PartyName' iv_depth = 1 ).
        IF lo_supplier_name_el IS BOUND.
          rs_header-supplier_name = get_child_text( io_scope = lo_supplier_name_el iv_tag_name = 'cbc:Name' ).
        ENDIF.
      ENDIF.
    ENDIF.

    " --- Alici (cac:AccountingCustomerParty/cac:Party/...) - gelen belge
    "     senaryosunda genelde bizim sirketimiz; yine de XML'den okunur
    "     (audit/karsilastirma amacli).
    DATA(lo_customer_party) = get_child_element( io_scope = lo_root iv_tag_name = 'cac:AccountingCustomerParty' ).
    IF lo_customer_party IS BOUND.
      DATA(lo_customer) = get_child_element( io_scope = lo_customer_party iv_tag_name = 'cac:Party' iv_depth = 1 ).
      IF lo_customer IS BOUND.
        DATA(lo_customer_id) = get_child_element( io_scope = lo_customer iv_tag_name = 'cac:PartyIdentification' iv_depth = 1 ).
        IF lo_customer_id IS BOUND.
          rs_header-customer_vkn = get_child_text( io_scope = lo_customer_id iv_tag_name = 'cbc:ID' ).
        ENDIF.
        DATA(lo_customer_name_el) = get_child_element( io_scope = lo_customer iv_tag_name = 'cac:PartyName' iv_depth = 1 ).
        IF lo_customer_name_el IS BOUND.
          rs_header-customer_name = get_child_text( io_scope = lo_customer_name_el iv_tag_name = 'cbc:Name' ).
        ENDIF.
      ENDIF.
    ENDIF.

    " --- Tutar toplamlari (cac:LegalMonetaryTotal - tekil blok).
    DATA(lo_monetary) = get_child_element( io_scope = lo_root iv_tag_name = 'cac:LegalMonetaryTotal' ).
    IF lo_monetary IS BOUND.
      rs_header-line_ext_amount = get_child_text( io_scope = lo_monetary iv_tag_name = 'cbc:LineExtensionAmount' ).
      rs_header-tax_excl_amount = get_child_text( io_scope = lo_monetary iv_tag_name = 'cbc:TaxExclusiveAmount' ).
      rs_header-tax_incl_amount = get_child_text( io_scope = lo_monetary iv_tag_name = 'cbc:TaxInclusiveAmount' ).
      rs_header-allow_total     = get_child_text( io_scope = lo_monetary iv_tag_name = 'cbc:AllowanceTotalAmount' ).
      rs_header-charge_total    = get_child_text( io_scope = lo_monetary iv_tag_name = 'cbc:ChargeTotalAmount' ).

      DATA(lo_payable_el) = get_child_element( io_scope = lo_monetary iv_tag_name = 'cbc:PayableAmount' ).
      IF lo_payable_el IS BOUND.
        " TODO: ondalik ayraci kullanicinin SU3 ondalik gosterim ayarina
        " bagli olarak CHAR->P donusumunde farkli yorumlanabilir; gercek
        " Bayt ornek belge gelince guvenli sayisal parse ile degistirilmeli.
        rs_header-payable_amount = lo_payable_el->get_value( ).
        rs_header-currency       = lo_payable_el->get_attribute( name = 'currencyID' ).
      ENDIF.
    ENDIF.

    " --- Vergi toplami (header seviyesi cac:TaxTotal - tekrarli TaxSubtotal icerir).
    DATA(lo_tax_total) = get_child_element( io_scope = lo_root iv_tag_name = 'cac:TaxTotal' ).
    IF lo_tax_total IS BOUND.
      rs_header-tax_amount   = get_child_text( io_scope = lo_tax_total iv_tag_name = 'cbc:TaxAmount' ).
      rs_header-tax_subtotal = parse_tax_subtotals( lo_tax_total ).
    ENDIF.

    " --- Kalemler (cac:InvoiceLine, root'un dogrudan cocuklari, birden fazla).
    DATA(lt_lines) = get_child_elements( io_scope = lo_root iv_tag_name = 'cac:InvoiceLine' ).
    DATA(lv_line_no) = 0.
    LOOP AT lt_lines INTO DATA(lo_line).
      lv_line_no = lv_line_no + 1.
      APPEND parse_line( io_line = lo_line iv_line_no = lv_line_no ) TO rs_header-line.
    ENDLOOP.

    IF rs_header-uuid IS INITIAL OR rs_header-invoice_id IS INITIAL OR rs_header-supplier_vkn IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_PARSE_003'
          iv_detail     = 'Zorunlu UBL alani eksik (UUID/ID/AccountingSupplierParty VKN)'.
    ENDIF.
  ENDMETHOD.

  METHOD parse_notes.
    DATA(lt_note_el) = get_child_elements( io_scope = io_scope iv_tag_name = 'cbc:Note' ).
    DATA(lv_seq) = 0.
    LOOP AT lt_note_el INTO DATA(lo_note_el).
      lv_seq = lv_seq + 1.
      APPEND VALUE #( seq_no = lv_seq text = lo_note_el->get_value( ) ) TO rt_note.
    ENDLOOP.
  ENDMETHOD.

  METHOD parse_tax_subtotals.
    DATA(lt_subtotal_el) = get_child_elements( io_scope = io_tax_total iv_tag_name = 'cac:TaxSubtotal' ).
    DATA(lv_seq) = 0.
    LOOP AT lt_subtotal_el INTO DATA(lo_sub).
      lv_seq = lv_seq + 1.
      DATA(ls_subtotal) = VALUE zif_zone_iarc_types=>ty_tax_subtotal(
        seq_no         = lv_seq
        taxable_amount = get_child_text( io_scope = lo_sub iv_tag_name = 'cbc:TaxableAmount' )
        tax_amount     = get_child_text( io_scope = lo_sub iv_tag_name = 'cbc:TaxAmount' )
        tax_percent    = get_child_text( io_scope = lo_sub iv_tag_name = 'cbc:Percent' ) ).

      DATA(lo_category) = get_child_element( io_scope = lo_sub iv_tag_name = 'cac:TaxCategory' ).
      IF lo_category IS BOUND.
        ls_subtotal-tax_cat_name = get_child_text( io_scope = lo_category iv_tag_name = 'cbc:Name' ).
        DATA(lo_scheme) = get_child_element( io_scope = lo_category iv_tag_name = 'cac:TaxScheme' ).
        IF lo_scheme IS BOUND.
          ls_subtotal-tax_type_code = get_child_text( io_scope = lo_scheme iv_tag_name = 'cbc:TaxTypeCode' ).
        ENDIF.
      ENDIF.

      APPEND ls_subtotal TO rt_subtotal.
    ENDLOOP.
  ENDMETHOD.

  METHOD parse_line.
    rs_line-line_no     = iv_line_no.
    rs_line-line_amount = get_child_text( io_scope = io_line iv_tag_name = 'cbc:LineExtensionAmount' ).
    rs_line-note        = parse_notes( io_line ).

    DATA(lo_qty_el) = get_child_element( io_scope = io_line iv_tag_name = 'cbc:InvoicedQuantity' ).
    IF lo_qty_el IS BOUND.
      rs_line-quantity = lo_qty_el->get_value( ).
      rs_line-uom_code = lo_qty_el->get_attribute( name = 'unitCode' ).
    ENDIF.

    DATA(lo_item) = get_child_element( io_scope = io_line iv_tag_name = 'cac:Item' ).
    IF lo_item IS BOUND.
      rs_line-description = get_child_text( io_scope = lo_item iv_tag_name = 'cbc:Name' ).
    ENDIF.

    DATA(lo_price) = get_child_element( io_scope = io_line iv_tag_name = 'cac:Price' ).
    IF lo_price IS BOUND.
      rs_line-unit_price = get_child_text( io_scope = lo_price iv_tag_name = 'cbc:PriceAmount' ).
    ENDIF.

    DATA(lo_line_tax) = get_child_element( io_scope = io_line iv_tag_name = 'cac:TaxTotal' ).
    IF lo_line_tax IS BOUND.
      rs_line-tax_amount   = get_child_text( io_scope = lo_line_tax iv_tag_name = 'cbc:TaxAmount' ).
      rs_line-tax_subtotal = parse_tax_subtotals( lo_line_tax ).
    ENDIF.
  ENDMETHOD.

  METHOD get_child_elements.
    DATA(lo_nodes) = io_scope->get_elements_by_tag_name( depth = iv_depth name = iv_tag_name ).
    IF lo_nodes IS NOT BOUND.
      RETURN.
    ENDIF.
    DO lo_nodes->get_length( ) TIMES.
      DATA(lv_idx) = sy-index - 1.
      DATA(lo_node) = lo_nodes->get_item( lv_idx ).
      DATA(lo_el) = CAST if_ixml_element( lo_node ).
      IF lo_el IS BOUND.
        APPEND lo_el TO rt_elements.
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD get_child_element.
    DATA(lt_elements) = get_child_elements( io_scope = io_scope iv_tag_name = iv_tag_name iv_depth = iv_depth ).
    IF lines( lt_elements ) > 0.
      ro_element = lt_elements[ 1 ].
    ENDIF.
  ENDMETHOD.

  METHOD get_child_text.
    DATA(lo_el) = get_child_element( io_scope = io_scope iv_tag_name = iv_tag_name iv_depth = iv_depth ).
    IF lo_el IS BOUND.
      rv_value = lo_el->get_value( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
