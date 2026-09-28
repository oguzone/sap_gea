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
    " Etiketler okunabilirlik icin 'cbc:UUID' gibi onekli yazilir ama
    " eslesme YALNIZCA yerel ada (UUID) gore yapilir - gercek dosyalarda
    " onek farkli olabilir veya varsayilan namespace kullanilabilir
    " (Karar 019). UBL-TR'de ayni seviyede cbc/cac altinda ayni yerel
    " adli iki element olmadigi icin onek atlamak guvenlidir.

    TYPES ty_elements TYPE STANDARD TABLE OF REF TO if_ixml_element WITH EMPTY KEY.

    " iv_depth: 1 = yalnizca dogrudan cocuklar, 0 = tum alt agac,
    " n = en fazla n seviye (IF_IXML_ELEMENT->GET_ELEMENTS_BY_TAG_NAME ile ayni).
    METHODS collect_children
      IMPORTING
        !io_scope      TYPE REF TO if_ixml_element
        !iv_local_name TYPE string
        !iv_depth      TYPE i
      CHANGING
        !ct_elements   TYPE ty_elements.

    " Elementin oneksiz adi. GET_NAME genelde zaten yerel adi verir;
    " 'cbc:UUID' seklinde dondugu durumlara karsi onek yine de atilir.
    METHODS local_name
      IMPORTING
        !io_element    TYPE REF TO if_ixml_element
      RETURNING
        VALUE(rv_name) TYPE string.

    " Asil fatura elementini bulur: kok dogrudan Invoice ise kokun
    " kendisi; entegrator bir zarf (envelope) icine koymussa alt agactaki
    " ilk Invoice elementi.
    METHODS find_invoice_root
      IMPORTING
        !io_root          TYPE REF TO if_ixml_element
      RETURNING
        VALUE(ro_invoice) TYPE REF TO if_ixml_element.

    " Gonderici/alicida birden fazla PartyIdentification olabilir (VKN,
    " MERSISNO, TICARETSICILNO...) - schemeID VKN/TCKN olani secilir.
    " Unvan: kurumsal PartyName; yoksa (sahis - TCKN) Person Ad + Soyad.
    METHODS display_name
      IMPORTING
        !is_party      TYPE zif_zone_iarc_types=>ty_party
      RETURNING
        VALUE(rv_name) TYPE string.

    METHODS find_tax_id
      IMPORTING
        !io_party    TYPE REF TO if_ixml_element
      EXPORTING
        !ev_value    TYPE string
        !ev_scheme   TYPE string.

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

    METHODS parse_party
      IMPORTING
        !io_party_wrap TYPE REF TO if_ixml_element   " cac:AccountingSupplierParty/CustomerParty
      RETURNING
        VALUE(rs_party) TYPE zif_zone_iarc_types=>ty_party.
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

    DATA(lo_doc_root) = lo_document->get_root_element( ).
    IF lo_doc_root IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_PARSE_002'
          iv_detail     = 'UBL XML kok elementi bulunamadi'.
    ENDIF.
    DATA(lo_root) = find_invoice_root( lo_doc_root ).

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

    " --- Satici (cac:AccountingSupplierParty/cac:Party/...) - tam detay
    "     (adres/vergi dairesi/iletisim) ZONE_IARC_T015'e yazilir.
    DATA(lo_supplier_wrap) = get_child_element( io_scope = lo_root iv_tag_name = 'cac:AccountingSupplierParty' ).
    IF lo_supplier_wrap IS BOUND.
      rs_header-supplier_party = parse_party( lo_supplier_wrap ).
      rs_header-supplier_vkn   = rs_header-supplier_party-vkn_tckn.
      rs_header-supplier_name  = display_name( rs_header-supplier_party ).
    ENDIF.

    " --- Alici (cac:AccountingCustomerParty/cac:Party/...) - gelen belge
    "     senaryosunda genelde bizim sirketimiz; yine de XML'den okunur
    "     (audit/karsilastirma amacli). Tam detay ZONE_IARC_T016'ya yazilir.
    DATA(lo_customer_wrap) = get_child_element( io_scope = lo_root iv_tag_name = 'cac:AccountingCustomerParty' ).
    IF lo_customer_wrap IS BOUND.
      rs_header-customer_party = parse_party( lo_customer_wrap ).
      rs_header-customer_vkn   = rs_header-customer_party-vkn_tckn.
      rs_header-customer_name  = display_name( rs_header-customer_party ).
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

    " Hangi alanin eksik oldugu ve kok element adi mesajda yer alir -
    " teshis icin (T100 degiskeni 50 karakterle sinirli; tam metin
    " MV_DETAIL'de).
    DATA lt_missing TYPE string_table.
    IF rs_header-uuid IS INITIAL.
      APPEND 'UUID' TO lt_missing.
    ENDIF.
    IF rs_header-invoice_id IS INITIAL.
      APPEND 'ID' TO lt_missing.
    ENDIF.
    IF rs_header-supplier_vkn IS INITIAL.
      APPEND COND string( WHEN lo_supplier_wrap IS BOUND THEN 'Satici VKN'
                          ELSE 'AccountingSupplierParty' ) TO lt_missing ##NO_TEXT.
    ENDIF.
    IF lt_missing IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_PARSE_003'
          iv_detail     = |Eksik: { concat_lines_of( table = lt_missing sep = ', ' ) } (kok: { local_name( lo_root ) })| ##NO_TEXT.
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

  METHOD parse_party.
    " io_party_wrap = cac:AccountingSupplierParty veya cac:AccountingCustomerParty;
    " gercek alanlar bunun tek cocugu olan cac:Party altinda.
    DATA(lo_party) = get_child_element( io_scope = io_party_wrap iv_tag_name = 'cac:Party' iv_depth = 1 ).
    IF lo_party IS NOT BOUND.
      RETURN.
    ENDIF.

    find_tax_id( EXPORTING io_party  = lo_party
                 IMPORTING ev_value  = rs_party-vkn_tckn
                           ev_scheme = rs_party-scheme_id ).

    DATA(lo_name_wrap) = get_child_element( io_scope = lo_party iv_tag_name = 'cac:PartyName' iv_depth = 1 ).
    IF lo_name_wrap IS BOUND.
      rs_party-party_name = get_child_text( io_scope = lo_name_wrap iv_tag_name = 'cbc:Name' ).
    ENDIF.

    " Bireysel musteri (UBL-09 Person element - schemeID=TCKN durumunda).
    DATA(lo_person) = get_child_element( io_scope = lo_party iv_tag_name = 'cac:Person' iv_depth = 1 ).
    IF lo_person IS BOUND.
      rs_party-first_name  = get_child_text( io_scope = lo_person iv_tag_name = 'cbc:FirstName' ).
      rs_party-family_name = get_child_text( io_scope = lo_person iv_tag_name = 'cbc:FamilyName' ).
    ENDIF.

    DATA(lo_addr) = get_child_element( io_scope = lo_party iv_tag_name = 'cac:PostalAddress' iv_depth = 1 ).
    IF lo_addr IS BOUND.
      rs_party-street      = get_child_text( io_scope = lo_addr iv_tag_name = 'cbc:StreetName' ).
      rs_party-district    = get_child_text( io_scope = lo_addr iv_tag_name = 'cbc:CitySubdivisionName' ).
      rs_party-city        = get_child_text( io_scope = lo_addr iv_tag_name = 'cbc:CityName' ).
      rs_party-postal_zone = get_child_text( io_scope = lo_addr iv_tag_name = 'cbc:PostalZone' ).
      DATA(lo_country) = get_child_element( io_scope = lo_addr iv_tag_name = 'cac:Country' ).
      IF lo_country IS BOUND.
        rs_party-country = get_child_text( io_scope = lo_country iv_tag_name = 'cbc:Name' ).
      ENDIF.
    ENDIF.

    DATA(lo_tax_scheme_wrap) = get_child_element( io_scope = lo_party iv_tag_name = 'cac:PartyTaxScheme' iv_depth = 1 ).
    IF lo_tax_scheme_wrap IS BOUND.
      DATA(lo_tax_scheme) = get_child_element( io_scope = lo_tax_scheme_wrap iv_tag_name = 'cac:TaxScheme' ).
      IF lo_tax_scheme IS BOUND.
        rs_party-tax_office = get_child_text( io_scope = lo_tax_scheme iv_tag_name = 'cbc:Name' ).
      ENDIF.
    ENDIF.

    DATA(lo_contact) = get_child_element( io_scope = lo_party iv_tag_name = 'cac:Contact' iv_depth = 1 ).
    IF lo_contact IS BOUND.
      rs_party-telephone = get_child_text( io_scope = lo_contact iv_tag_name = 'cbc:Telephone' ).
      rs_party-email     = get_child_text( io_scope = lo_contact iv_tag_name = 'cbc:ElectronicMail' ).
    ENDIF.
  ENDMETHOD.

  METHOD get_child_elements.
    " 'cbc:UUID' -> 'UUID' (onek yoksa ad oldugu gibi kalir)
    DATA(lv_local_name) = iv_tag_name.
    FIND FIRST OCCURRENCE OF ':' IN iv_tag_name MATCH OFFSET DATA(lv_colon).
    IF sy-subrc = 0.
      lv_local_name = substring( val = iv_tag_name off = lv_colon + 1 ).
    ENDIF.

    collect_children(
      EXPORTING
        io_scope      = io_scope
        iv_local_name = lv_local_name
        iv_depth      = iv_depth
      CHANGING
        ct_elements   = rt_elements ).
  ENDMETHOD.

  METHOD local_name.
    rv_name = io_element->get_name( ).
    FIND FIRST OCCURRENCE OF ':' IN rv_name MATCH OFFSET DATA(lv_colon).
    IF sy-subrc = 0.
      rv_name = substring( val = rv_name off = lv_colon + 1 ).
    ENDIF.
  ENDMETHOD.

  METHOD find_invoice_root.
    ro_invoice = io_root.
    IF local_name( io_root ) = 'Invoice'
       OR get_child_element( io_scope = io_root iv_tag_name = 'cbc:UUID' ) IS BOUND.
      RETURN.
    ENDIF.
    DATA(lo_inner) = get_child_element( io_scope = io_root iv_tag_name = 'Invoice' iv_depth = 0 ).
    IF lo_inner IS BOUND.
      ro_invoice = lo_inner.
    ENDIF.
  ENDMETHOD.

  METHOD display_name.
    rv_name = is_party-party_name.
    IF rv_name IS INITIAL.
      rv_name = condense( |{ is_party-first_name } { is_party-family_name }| ).
    ENDIF.
  ENDMETHOD.

  METHOD find_tax_id.
    CLEAR: ev_value, ev_scheme.
    DATA(lt_id_wrap) = get_child_elements( io_scope = io_party iv_tag_name = 'cac:PartyIdentification' ).
    LOOP AT lt_id_wrap INTO DATA(lo_id_wrap).
      DATA(lo_id_el) = get_child_element( io_scope = lo_id_wrap iv_tag_name = 'cbc:ID' ).
      IF lo_id_el IS NOT BOUND.
        CONTINUE.
      ENDIF.
      DATA(lv_scheme) = to_upper( lo_id_el->get_attribute( name = 'schemeID' ) ).
      IF ev_value IS INITIAL.   " yedek: ilk bulunan
        ev_value  = lo_id_el->get_value( ).
        ev_scheme = lv_scheme.
      ENDIF.
      IF lv_scheme = 'VKN' OR lv_scheme = 'TCKN'.
        ev_value  = lo_id_el->get_value( ).
        ev_scheme = lv_scheme.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD collect_children.
    DATA(lo_child) = io_scope->get_first_child( ).
    WHILE lo_child IS BOUND.
      IF lo_child->get_type( ) = if_ixml_node=>co_node_element.
        DATA(lo_element) = CAST if_ixml_element( lo_child ).
        IF local_name( lo_element ) = iv_local_name.
          APPEND lo_element TO ct_elements.
        ENDIF.
        IF iv_depth <> 1.
          collect_children(
            EXPORTING
              io_scope      = lo_element
              iv_local_name = iv_local_name
              iv_depth      = COND #( WHEN iv_depth = 0 THEN 0 ELSE iv_depth - 1 )
            CHANGING
              ct_elements   = ct_elements ).
        ENDIF.
      ENDIF.
      lo_child = lo_child->get_next( ).
    ENDWHILE.
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
