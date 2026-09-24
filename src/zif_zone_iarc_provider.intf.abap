INTERFACE zif_zone_iarc_provider
  PUBLIC.

  " Entegrator (Bayt E-Belge Partner - ebelge.baytapi.com/baytebelgeservice)
  " sozlesmesi. ZCL_ZONE_IARC_PROVIDER (gercek) ve ZCL_ZONE_IARC_MOCK (test)
  " bu interface'i implemente eder; ornekler ZCL_ZONE_IARC_FACTORY uzerinden
  " uretilir - cagiran taraf hicbir zaman somut adapter sinifini bilmez
  " (bkz. architecture/class-design.md).
  "
  " API sozlesmesi "Bayt E-Belge Partner.postman_collection.json" ile
  " dogrulandi (program/decision-log.md Karar 010): AuthenticateExt (token),
  " GetInvoiceListExt (CustomerType=alici ile gelen belge listesi),
  " GetByInvoiceNoExt (belge detayi - InvoiceNo + SupplierTaxNumber gerekli,
  " bu yuzden GET_DOCUMENT iki parametre alir), DownloadFileExt (dosya
  " indirme). Ack servisi YOK - dedup ZONE_IARC_T006 unique key ile yapilir.
  " Response semalari (JSON alan adlari) Postman ornekleri sadece REQUEST
  " icerdigi icin dogrulanmadi - bkz. program/risks-and-open-questions.md S8.

  METHODS list_new_documents
    IMPORTING
      !iv_bukrs TYPE bukrs
      !iv_since TYPE timestampl
    RETURNING
      VALUE(rt_refs) TYPE zif_zone_iarc_types=>tt_doc_ref
    RAISING
      zcx_zone_iarc_provider.

  METHODS get_document
    IMPORTING
      !iv_bukrs           TYPE bukrs
      !iv_provider_doc_id TYPE string   " Bayt InvoiceNo
      !iv_supplier_tax_no TYPE string   " Bayt SupplierTaxNumber - InvoiceNo ile birlikte zorunlu
    EXPORTING
      !ev_xml  TYPE xstring
      !es_meta TYPE zif_zone_iarc_types=>ty_doc_meta
    RAISING
      zcx_zone_iarc_provider.

  METHODS get_provider_key
    RETURNING
      VALUE(rv_key) TYPE char10.

ENDINTERFACE.
