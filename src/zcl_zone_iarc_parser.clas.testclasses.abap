CLASS ltc_parser DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_zone_iarc_parser.

    METHODS setup.
    METHODS build_test_xml
      RETURNING VALUE(rv_xml) TYPE xstring.

    METHODS header_fields FOR TESTING RAISING cx_static_check.
    METHODS header_note FOR TESTING RAISING cx_static_check.
    METHODS header_tax_subtotal FOR TESTING RAISING cx_static_check.
    METHODS line_fields FOR TESTING RAISING cx_static_check.
    METHODS line_note_and_tax FOR TESTING RAISING cx_static_check.
    METHODS missing_mandatory_raises FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_parser IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_zone_iarc_parser( ).
  ENDMETHOD.

  METHOD build_test_xml.
    " ZCL_ZONE_IARC_MOCK'un urettigi belgeyle ayni yapi - gercek UBL-TR
    " AccountingSupplierParty/AccountingCustomerParty/LegalMonetaryTotal/
    " InvoiceLine iskeleti (bkz. sap-edonusum-team/program/
    " ubl-tr-field-inventory.md referansi).
    DATA(lv_xml) =
      |<ArchiveInvoice xmlns:cbc="urn:cbc" xmlns:cac="urn:cac">| &&
      |<cbc:UUID>TEST-UUID-0001</cbc:UUID>| &&
      |<cbc:ID>TESTINV-0001</cbc:ID>| &&
      |<cbc:IssueDate>2026-09-24</cbc:IssueDate>| &&
      |<cbc:IssueTime>09:15:30</cbc:IssueTime>| &&
      |<cbc:InvoiceTypeCode>SATIS</cbc:InvoiceTypeCode>| &&
      |<cbc:ProfileID>TICARIFATURA</cbc:ProfileID>| &&
      |<cbc:CopyIndicator>false</cbc:CopyIndicator>| &&
      |<cbc:Note>Test header notu 1</cbc:Note>| &&
      |<cbc:Note>Test header notu 2</cbc:Note>| &&
      |<cac:AccountingSupplierParty><cac:Party>| &&
      |<cac:PartyIdentification><cbc:ID schemeID="VKN">2222222222</cbc:ID></cac:PartyIdentification>| &&
      |<cac:PartyName><cbc:Name>Test Tedarikci A.S.</cbc:Name></cac:PartyName>| &&
      |</cac:Party></cac:AccountingSupplierParty>| &&
      |<cac:AccountingCustomerParty><cac:Party>| &&
      |<cac:PartyIdentification><cbc:ID schemeID="VKN">3333333333</cbc:ID></cac:PartyIdentification>| &&
      |<cac:PartyName><cbc:Name>Test Alici Ltd.</cbc:Name></cac:PartyName>| &&
      |</cac:Party></cac:AccountingCustomerParty>| &&
      |<cac:TaxTotal><cbc:TaxAmount>36.00</cbc:TaxAmount>| &&
      |<cac:TaxSubtotal><cbc:TaxableAmount>200.00</cbc:TaxableAmount><cbc:TaxAmount>36.00</cbc:TaxAmount>| &&
      |<cbc:Percent>18</cbc:Percent><cac:TaxCategory><cbc:Name>KDV</cbc:Name>| &&
      |<cac:TaxScheme><cbc:TaxTypeCode>0015</cbc:TaxTypeCode></cac:TaxScheme></cac:TaxCategory></cac:TaxSubtotal>| &&
      |</cac:TaxTotal>| &&
      |<cac:LegalMonetaryTotal>| &&
      |<cbc:LineExtensionAmount>200.00</cbc:LineExtensionAmount>| &&
      |<cbc:TaxExclusiveAmount>200.00</cbc:TaxExclusiveAmount>| &&
      |<cbc:TaxInclusiveAmount>236.00</cbc:TaxInclusiveAmount>| &&
      |<cbc:AllowanceTotalAmount>0.00</cbc:AllowanceTotalAmount>| &&
      |<cbc:ChargeTotalAmount>0.00</cbc:ChargeTotalAmount>| &&
      |<cbc:PayableAmount currencyID="TRY">236.00</cbc:PayableAmount>| &&
      |</cac:LegalMonetaryTotal>| &&
      |<cac:InvoiceLine>| &&
      |<cbc:Note>Test kalem notu</cbc:Note>| &&
      |<cbc:InvoicedQuantity unitCode="C62">2</cbc:InvoicedQuantity>| &&
      |<cbc:LineExtensionAmount>200.00</cbc:LineExtensionAmount>| &&
      |<cac:Item><cbc:Name>Test Hizmet</cbc:Name></cac:Item>| &&
      |<cac:Price><cbc:PriceAmount>100.00</cbc:PriceAmount></cac:Price>| &&
      |<cac:TaxTotal><cbc:TaxAmount>36.00</cbc:TaxAmount>| &&
      |<cac:TaxSubtotal><cbc:TaxableAmount>200.00</cbc:TaxableAmount><cbc:TaxAmount>36.00</cbc:TaxAmount>| &&
      |<cbc:Percent>18</cbc:Percent><cac:TaxCategory><cbc:Name>KDV</cbc:Name>| &&
      |<cac:TaxScheme><cbc:TaxTypeCode>0015</cbc:TaxTypeCode></cac:TaxScheme></cac:TaxCategory></cac:TaxSubtotal>| &&
      |</cac:TaxTotal>| &&
      |</cac:InvoiceLine>| &&
      |</ArchiveInvoice>|.
    rv_xml = cl_abap_codepage=>convert_to( lv_xml ).
  ENDMETHOD.

  METHOD header_fields.
    DATA(ls_header) = mo_cut->parse( build_test_xml( ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_header-uuid          exp = 'TEST-UUID-0001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-invoice_id    exp = 'TESTINV-0001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-issue_date    exp = '20260924' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-issue_time    exp = '091530' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-inv_type_code exp = 'SATIS' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-profile_id    exp = 'TICARIFATURA' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-copy_indicator exp = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-supplier_vkn  exp = '2222222222' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-supplier_name exp = 'Test Tedarikci A.S.' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-customer_vkn  exp = '3333333333' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-customer_name exp = 'Test Alici Ltd.' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-currency        exp = 'TRY' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-line_ext_amount exp = '200.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-tax_excl_amount exp = '200.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-tax_incl_amount exp = '236.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-payable_amount  exp = '236.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-tax_amount      exp = '36.00' ).
  ENDMETHOD.

  METHOD header_note.
    DATA(ls_header) = mo_cut->parse( build_test_xml( ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_header-note ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-note[ 1 ]-text exp = 'Test header notu 1' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-note[ 2 ]-text exp = 'Test header notu 2' ).
  ENDMETHOD.

  METHOD header_tax_subtotal.
    DATA(ls_header) = mo_cut->parse( build_test_xml( ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_header-tax_subtotal ) exp = 1 ).
    DATA(ls_sub) = ls_header-tax_subtotal[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_sub-taxable_amount exp = '200.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sub-tax_amount     exp = '36.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sub-tax_percent    exp = '18.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sub-tax_cat_name   exp = 'KDV' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sub-tax_type_code  exp = '0015' ).
  ENDMETHOD.

  METHOD line_fields.
    DATA(ls_header) = mo_cut->parse( build_test_xml( ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_header-line ) exp = 1 ).

    DATA(ls_line) = ls_header-line[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_line-line_no      exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-description  exp = 'Test Hizmet' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-quantity     exp = '2.000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-uom_code     exp = 'C62' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-unit_price   exp = '100.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-line_amount  exp = '200.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-tax_amount   exp = '36.00' ).
  ENDMETHOD.

  METHOD line_note_and_tax.
    DATA(ls_header) = mo_cut->parse( build_test_xml( ) ).
    DATA(ls_line) = ls_header-line[ 1 ].

    cl_abap_unit_assert=>assert_equals( act = lines( ls_line-note ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-note[ 1 ]-text exp = 'Test kalem notu' ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_line-tax_subtotal ) exp = 1 ).
    DATA(ls_sub) = ls_line-tax_subtotal[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_sub-tax_percent   exp = '18.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sub-tax_cat_name  exp = 'KDV' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sub-tax_type_code exp = '0015' ).
  ENDMETHOD.

  METHOD missing_mandatory_raises.
    " AccountingSupplierParty/VKN eksik - IARC_PARSE_003 beklenir.
    DATA(lv_xml) = cl_abap_codepage=>convert_to(
      |<ArchiveInvoice xmlns:cbc="urn:cbc" xmlns:cac="urn:cac">| &&
      |<cbc:UUID>TEST-UUID-0002</cbc:UUID>| &&
      |<cbc:ID>TESTINV-0002</cbc:ID>| &&
      |</ArchiveInvoice>| ).

    TRY.
        mo_cut->parse( lv_xml ).
        cl_abap_unit_assert=>fail( 'Zorunlu alan eksikken exception beklenirdi' ).
      CATCH zcx_zone_iarc_mapping INTO DATA(lx_mapping).
        cl_abap_unit_assert=>assert_equals( act = lx_mapping->mv_error_code exp = 'IARC_PARSE_003' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
