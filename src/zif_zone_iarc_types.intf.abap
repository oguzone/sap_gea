INTERFACE zif_zone_iarc_types
  PUBLIC.

  " DDIC-bagimsiz canonical model. ZCL_ZONE_IARC_PARSER, UBL-TR ArchiveInvoice
  " XML'ini bu yapilara cevirir; ZCL_ZONE_IARC_MAPPER/_POST bu yapilardan
  " okur. Alan listesi UBL ArchiveInvoice semasinin cekirdek (zorunlu)
  " alanlarini kapsar - tam sema dogrulamasi henuz yapilmadi (bkz.
  " program/risks-and-open-questions.md).

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
    BEGIN OF ty_line,
      line_no      TYPE i,
      description  TYPE string,
      quantity     TYPE p LENGTH 13 DECIMALS 3,
      unit_price   TYPE p LENGTH 13 DECIMALS 2,
      line_amount  TYPE p LENGTH 13 DECIMALS 2,
      tax_percent  TYPE p LENGTH 5 DECIMALS 2,
      tax_amount   TYPE p LENGTH 13 DECIMALS 2,
    END OF ty_line.
  TYPES tt_line TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_header,
      uuid            TYPE string,
      invoice_id      TYPE string,
      issue_date      TYPE dats,
      supplier_vkn    TYPE string,
      supplier_name   TYPE string,
      currency        TYPE waers,
      payable_amount  TYPE p LENGTH 13 DECIMALS 2,
      tax_amount      TYPE p LENGTH 13 DECIMALS 2,
      line            TYPE tt_line,
    END OF ty_header.
  " Alan kapsami sap-edonusum-team/program/ubl-tr-field-inventory.md (giden
  " e-Fatura icin yazilmis olsa da UBL-TR ArchiveInvoice ayni cbc:/cac:
  " temel yapisini paylasir - kok element ve bazi ek bloklar farkli, ama
  " AccountingSupplierParty/LegalMonetaryTotal/InvoiceLine/TaxTotal
  " XPath'leri ortaktir) referans alinarak secildi.

ENDINTERFACE.
