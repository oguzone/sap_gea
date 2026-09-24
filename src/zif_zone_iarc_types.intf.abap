INTERFACE zif_zone_iarc_types
  PUBLIC.

  " DDIC-bagimsiz canonical model. ZCL_ZONE_IARC_PARSER, UBL-TR ArchiveInvoice
  " XML'ini bu yapilara cevirir; ZCL_ZONE_IARC_STORE bunlari ZONE_IARC_T009..
  " T014 tablolarina yazar; ZCL_ZONE_IARC_MAPPER/_POST da bu yapilardan okur.
  " Alan kapsami sap-edonusum-team/program/ubl-tr-field-inventory.md
  " referans alinarak secildi (giden e-Fatura icin yazilmis olsa da
  " ArchiveInvoice ayni cbc:/cac: temel yapisini paylasir) - tam sema
  " dogrulamasi henuz yapilmadi (bkz. program/risks-and-open-questions.md).

  TYPES:
    BEGIN OF ty_doc_ref,
      provider_doc_id  TYPE string,    " Bayt: InvoiceNo (orn. PAB2025008140740)
      supplier_tax_no  TYPE string,    " Bayt: SupplierTaxNumber - GetByInvoiceNoExt icin InvoiceNo ile birlikte zorunlu
      ettn             TYPE string,
      received_at      TYPE timestampl,
    END OF ty_doc_ref.
  TYPES tt_doc_ref TYPE STANDARD TABLE OF ty_doc_ref WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_doc_meta,
      supplier_vkn TYPE string,
      doc_date     TYPE dats,
      amount       TYPE wrbtr,
      currency     TYPE waers,
    END OF ty_doc_meta.

  TYPES:
    BEGIN OF ty_note,
      seq_no TYPE i,
      text   TYPE string,
    END OF ty_note.
  TYPES tt_note TYPE STANDARD TABLE OF ty_note WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_tax_subtotal,
      seq_no           TYPE i,
      taxable_amount   TYPE p LENGTH 13 DECIMALS 2,
      tax_amount       TYPE p LENGTH 13 DECIMALS 2,
      tax_percent      TYPE p LENGTH 5 DECIMALS 2,
      tax_cat_name     TYPE string,   " TaxCategory/Name - orn. "KDV", "Stopaj"
      tax_type_code    TYPE string,   " TaxScheme/TaxTypeCode - GIB kodu, orn. "0015"
    END OF ty_tax_subtotal.
  TYPES tt_tax_subtotal TYPE STANDARD TABLE OF ty_tax_subtotal WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_line,
      line_no      TYPE i,
      description  TYPE string,
      quantity     TYPE p LENGTH 13 DECIMALS 3,
      uom_code     TYPE string,   " InvoicedQuantity/@unitCode - orn. "C62", "NIU"
      unit_price   TYPE p LENGTH 13 DECIMALS 2,
      line_amount  TYPE p LENGTH 13 DECIMALS 2,
      tax_amount   TYPE p LENGTH 13 DECIMALS 2,   " satir TaxTotal/TaxAmount toplami (T014 satirlarinin toplami ile tutarli olmali)
      note         TYPE tt_note,
      tax_subtotal TYPE tt_tax_subtotal,
    END OF ty_line.
  TYPES tt_line TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_header,
      uuid              TYPE string,
      invoice_id        TYPE string,
      issue_date        TYPE dats,
      issue_time        TYPE uzeit,
      inv_type_code     TYPE string,   " InvoiceTypeCode - orn. SATIS/IADE/TEVKIFAT (UBL kod tablosuna gore)
      profile_id        TYPE string,   " ProfileID - orn. TICARIFATURA/TEMELFATURA
      copy_indicator    TYPE abap_bool,
      currency          TYPE waers,
      supplier_vkn      TYPE string,
      supplier_name     TYPE string,
      customer_vkn      TYPE string,   " gelen belge senaryosunda genelde bizim sirketimiz
      customer_name     TYPE string,
      line_ext_amount   TYPE p LENGTH 13 DECIMALS 2,   " LegalMonetaryTotal/LineExtensionAmount
      tax_excl_amount   TYPE p LENGTH 13 DECIMALS 2,   " .../TaxExclusiveAmount
      tax_incl_amount   TYPE p LENGTH 13 DECIMALS 2,   " .../TaxInclusiveAmount
      allow_total       TYPE p LENGTH 13 DECIMALS 2,   " .../AllowanceTotalAmount
      charge_total      TYPE p LENGTH 13 DECIMALS 2,   " .../ChargeTotalAmount
      payable_amount    TYPE p LENGTH 13 DECIMALS 2,   " .../PayableAmount
      tax_amount        TYPE p LENGTH 13 DECIMALS 2,   " header TaxTotal/TaxAmount toplami (T011 satirlarinin toplami ile tutarli olmali)
      note              TYPE tt_note,
      tax_subtotal      TYPE tt_tax_subtotal,
      line              TYPE tt_line,
    END OF ty_header.

ENDINTERFACE.
