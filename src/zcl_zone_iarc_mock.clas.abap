CLASS zcl_zone_iarc_mock DEFINITION
  PUBLIC
  INHERITING FROM zcl_zone_iarc_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_zone_iarc_provider.

    METHODS constructor.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mv_seq TYPE i.
ENDCLASS.



CLASS zcl_zone_iarc_mock IMPLEMENTATION.

  METHOD constructor.
    super->constructor( iv_provider_key = 'MOCK' ).
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~get_provider_key.
    rv_key = 'MOCK'.
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~list_new_documents.
    " Sabit tek test belgesi doner - Bayt response semasi (S8) dogrulanana
    " kadar pipeline'in geri kalanini (parse/resolve/map/park) test etmeye
    " yeter (bkz. program/decision-log.md, mock-first strateji).
    mv_seq = mv_seq + 1.
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    APPEND VALUE #(
      provider_doc_id = |MOCKINV-{ mv_seq }|
      supplier_tax_no = '1111111111'
      ettn            = |MOCK-{ mv_seq }-ETTN|
      received_at     = lv_now ) TO rt_refs.
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~get_document.
    " UBL-TR ArchiveInvoice yapisina paralel (cbc:/cac: prefiksli) - bkz.
    " sap-edonusum-team/program/ubl-tr-field-inventory.md. Gercek Bayt
    " ornek belgesi gelene kadar ZCL_ZONE_IARC_PARSER'i uctan uca test
    " etmek icin kullanilir; namespace xmlns bildirimi bilerek basitlestirildi
    " (prefiks sabit kabul edilir, TODO: gercek namespace-URI kontrolu).
    DATA(lv_issue_date) = sy-datum+0(4) && '-' && sy-datum+4(2) && '-' && sy-datum+6(2).
    DATA(lv_xml) =
      |<ArchiveInvoice xmlns:cbc="urn:cbc" xmlns:cac="urn:cac">| &&
      |<cbc:UUID>MOCK-UUID-{ sy-uzeit }</cbc:UUID>| &&
      |<cbc:ID>MOCKINV-0001</cbc:ID>| &&
      |<cbc:IssueDate>{ lv_issue_date }</cbc:IssueDate>| &&
      |<cbc:IssueTime>14:30:00</cbc:IssueTime>| &&
      |<cbc:InvoiceTypeCode>SATIS</cbc:InvoiceTypeCode>| &&
      |<cbc:ProfileID>TICARIFATURA</cbc:ProfileID>| &&
      |<cbc:CopyIndicator>false</cbc:CopyIndicator>| &&
      |<cbc:Note>Mock header notu</cbc:Note>| &&
      |<cac:AccountingSupplierParty><cac:Party>| &&
      |<cac:PartyIdentification><cbc:ID schemeID="VKN">1111111111</cbc:ID></cac:PartyIdentification>| &&
      |<cac:PartyName><cbc:Name>Mock Tedarikci A.S.</cbc:Name></cac:PartyName>| &&
      |<cac:PostalAddress><cbc:StreetName>Mock Cad. No:1</cbc:StreetName>| &&
      |<cbc:CitySubdivisionName>Kadikoy</cbc:CitySubdivisionName><cbc:CityName>Istanbul</cbc:CityName>| &&
      |<cbc:PostalZone>34000</cbc:PostalZone><cac:Country><cbc:Name>Turkiye</cbc:Name></cac:Country>| &&
      |</cac:PostalAddress>| &&
      |<cac:PartyTaxScheme><cac:TaxScheme><cbc:Name>Kadikoy VD</cbc:Name></cac:TaxScheme></cac:PartyTaxScheme>| &&
      |<cac:Contact><cbc:Telephone>02161234567</cbc:Telephone><cbc:ElectronicMail>satici@mock.com</cbc:ElectronicMail></cac:Contact>| &&
      |</cac:Party></cac:AccountingSupplierParty>| &&
      |<cac:AccountingCustomerParty><cac:Party>| &&
      |<cac:PartyIdentification><cbc:ID schemeID="VKN">2222222222</cbc:ID></cac:PartyIdentification>| &&
      |<cac:PartyName><cbc:Name>Mock Alici Ltd.</cbc:Name></cac:PartyName>| &&
      |<cac:PostalAddress><cbc:StreetName>Mock Sok. No:2</cbc:StreetName>| &&
      |<cbc:CitySubdivisionName>Cankaya</cbc:CitySubdivisionName><cbc:CityName>Ankara</cbc:CityName>| &&
      |<cbc:PostalZone>06000</cbc:PostalZone><cac:Country><cbc:Name>Turkiye</cbc:Name></cac:Country>| &&
      |</cac:PostalAddress>| &&
      |<cac:PartyTaxScheme><cac:TaxScheme><cbc:Name>Cankaya VD</cbc:Name></cac:TaxScheme></cac:PartyTaxScheme>| &&
      |<cac:Contact><cbc:Telephone>03127654321</cbc:Telephone><cbc:ElectronicMail>alici@mock.com</cbc:ElectronicMail></cac:Contact>| &&
      |</cac:Party></cac:AccountingCustomerParty>| &&
      |<cac:TaxTotal><cbc:TaxAmount>18.00</cbc:TaxAmount>| &&
      |<cac:TaxSubtotal><cbc:TaxableAmount>100.00</cbc:TaxableAmount><cbc:TaxAmount>18.00</cbc:TaxAmount>| &&
      |<cbc:Percent>18</cbc:Percent><cac:TaxCategory><cbc:Name>KDV</cbc:Name>| &&
      |<cac:TaxScheme><cbc:TaxTypeCode>0015</cbc:TaxTypeCode></cac:TaxScheme></cac:TaxCategory></cac:TaxSubtotal>| &&
      |</cac:TaxTotal>| &&
      |<cac:LegalMonetaryTotal>| &&
      |<cbc:LineExtensionAmount>100.00</cbc:LineExtensionAmount>| &&
      |<cbc:TaxExclusiveAmount>100.00</cbc:TaxExclusiveAmount>| &&
      |<cbc:TaxInclusiveAmount>118.00</cbc:TaxInclusiveAmount>| &&
      |<cbc:AllowanceTotalAmount>0.00</cbc:AllowanceTotalAmount>| &&
      |<cbc:ChargeTotalAmount>0.00</cbc:ChargeTotalAmount>| &&
      |<cbc:PayableAmount currencyID="TRY">118.00</cbc:PayableAmount>| &&
      |</cac:LegalMonetaryTotal>| &&
      |<cac:InvoiceLine>| &&
      |<cbc:Note>Mock kalem notu</cbc:Note>| &&
      |<cbc:InvoicedQuantity unitCode="C62">1</cbc:InvoicedQuantity>| &&
      |<cbc:LineExtensionAmount>100.00</cbc:LineExtensionAmount>| &&
      |<cac:Item><cbc:Name>Mock Hizmet</cbc:Name></cac:Item>| &&
      |<cac:Price><cbc:PriceAmount>100.00</cbc:PriceAmount></cac:Price>| &&
      |<cac:TaxTotal><cbc:TaxAmount>18.00</cbc:TaxAmount>| &&
      |<cac:TaxSubtotal><cbc:TaxableAmount>100.00</cbc:TaxableAmount><cbc:TaxAmount>18.00</cbc:TaxAmount>| &&
      |<cbc:Percent>18</cbc:Percent><cac:TaxCategory><cbc:Name>KDV</cbc:Name>| &&
      |<cac:TaxScheme><cbc:TaxTypeCode>0015</cbc:TaxTypeCode></cac:TaxScheme></cac:TaxCategory></cac:TaxSubtotal>| &&
      |</cac:TaxTotal>| &&
      |</cac:InvoiceLine>| &&
      |</ArchiveInvoice>|.
    ev_xml = cl_abap_codepage=>convert_to( lv_xml ).

    es_meta-supplier_vkn = '1111111111'.
    es_meta-doc_date     = sy-datum.
    es_meta-amount       = '118.00'.
    es_meta-currency     = 'TRY'.
  ENDMETHOD.

ENDCLASS.
