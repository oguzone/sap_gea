CLASS ltc_parser DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_zone_iarc_parser.

    METHODS setup.
    METHODS build_test_xml
      RETURNING VALUE(rv_xml) TYPE xstring.

    METHODS header_fields FOR TESTING RAISING cx_static_check.
    METHODS line_fields FOR TESTING RAISING cx_static_check.
    METHODS missing_mandatory_raises FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_parser IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_zone_iarc_parser( ).
  ENDMETHOD.

  METHOD build_test_xml.
    " ZCL_ZONE_IARC_MOCK'un urettigi belgeyle ayni yapi - gercek UBL-TR
    " AccountingSupplierParty/LegalMonetaryTotal/InvoiceLine iskeleti
    " (bkz. sap-edonusum-team/program/ubl-tr-field-inventory.md referansi).
    DATA(lv_xml) =
      |<ArchiveInvoice xmlns:cbc="urn:cbc" xmlns:cac="urn:cac">| &&
      |<cbc:UUID>TEST-UUID-0001</cbc:UUID>| &&
      |<cbc:ID>TESTINV-0001</cbc:ID>| &&
      |<cbc:IssueDate>2026-09-24</cbc:IssueDate>| &&
      |<cac:AccountingSupplierParty><cac:Party>| &&
      |<cac:PartyIdentification><cbc:ID schemeID="VKN">2222222222</cbc:ID></cac:PartyIdentification>| &&
      |<cac:PartyName><cbc:Name>Test Tedarikci A.S.</cbc:Name></cac:PartyName>| &&
      |</cac:Party></cac:AccountingSupplierParty>| &&
      |<cac:TaxTotal><cbc:TaxAmount>36.00</cbc:TaxAmount></cac:TaxTotal>| &&
      |<cac:LegalMonetaryTotal><cbc:PayableAmount currencyID="TRY">236.00</cbc:PayableAmount></cac:LegalMonetaryTotal>| &&
      |<cac:InvoiceLine>| &&
      |<cbc:InvoicedQuantity>2</cbc:InvoicedQuantity>| &&
      |<cbc:LineExtensionAmount>200.00</cbc:LineExtensionAmount>| &&
      |<cac:Item><cbc:Name>Test Hizmet</cbc:Name></cac:Item>| &&
      |<cac:Price><cbc:PriceAmount>100.00</cbc:PriceAmount></cac:Price>| &&
      |<cac:TaxTotal><cbc:TaxAmount>36.00</cbc:TaxAmount>| &&
      |<cac:TaxSubtotal><cbc:Percent>18</cbc:Percent></cac:TaxSubtotal></cac:TaxTotal>| &&
      |</cac:InvoiceLine>| &&
      |</ArchiveInvoice>|.
    rv_xml = cl_abap_codepage=>convert_to( lv_xml ).
  ENDMETHOD.

  METHOD header_fields.
    DATA(ls_header) = mo_cut->parse( build_test_xml( ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_header-uuid        exp = 'TEST-UUID-0001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-invoice_id  exp = 'TESTINV-0001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-issue_date  exp = '20260924' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-supplier_vkn  exp = '2222222222' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-supplier_name exp = 'Test Tedarikci A.S.' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-currency       exp = 'TRY' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-payable_amount exp = '236.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-tax_amount     exp = '36.00' ).
  ENDMETHOD.

  METHOD line_fields.
    DATA(ls_header) = mo_cut->parse( build_test_xml( ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_header-line ) exp = 1 ).

    DATA(ls_line) = ls_header-line[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_line-line_no      exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-description  exp = 'Test Hizmet' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-quantity     exp = '2.000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-unit_price   exp = '100.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-line_amount  exp = '200.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-tax_amount   exp = '36.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-tax_percent  exp = '18.00' ).
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
