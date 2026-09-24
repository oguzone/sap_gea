INTERFACE zif_zone_iarc_provider
  PUBLIC.

  " Entegrator (Zonetegra) sozlesmesi. ZCL_ZONE_IARC_PROVIDER (gercek) ve
  " ZCL_ZONE_IARC_MOCK (test) bu interface'i implemente eder; ornekler
  " ZCL_ZONE_IARC_FACTORY uzerinden uretilir - cagiran taraf hicbir zaman
  " somut adapter sinifini bilmez (bkz. architecture/class-design.md).
  "
  " Zonetegra'nin gercek API sozlesmesi (senkron mu, sayfalama var mi,
  " SINCE parametresi timestamp mi sequence mi) henuz dogrulanmadi - bkz.
  " program/risks-and-open-questions.md S1. LIST_NEW_DOCUMENTS/GET_DOCUMENT
  " imzalari bu yuzden ilk taslak, gercek sozlesme gelince degisebilir.

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
      !iv_provider_doc_id TYPE string
    EXPORTING
      !ev_xml  TYPE xstring
      !es_meta TYPE zif_zone_iarc_types=>ty_doc_meta
    RAISING
      zcx_zone_iarc_provider.

  METHODS acknowledge_document
    IMPORTING
      !iv_provider_doc_id TYPE string
    RAISING
      zcx_zone_iarc_provider.

  METHODS get_provider_key
    RETURNING
      VALUE(rv_key) TYPE char10.

ENDINTERFACE.
