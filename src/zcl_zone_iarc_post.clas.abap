CLASS zcl_zone_iarc_post DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS park
      IMPORTING
        !iv_bukrs    TYPE bukrs
        !iv_lifnr    TYPE lifnr
        !is_header   TYPE zif_zone_iarc_types=>ty_header
        !is_decision TYPE zcl_zone_iarc_mapper=>ty_decision
      EXPORTING
        !ev_fi_belnr   TYPE belnr_d
        !ev_miro_belnr TYPE belnr_d
      RAISING
        zcx_zone_iarc_mapping.

    METHODS post_parked
      IMPORTING
        !iv_bukrs      TYPE bukrs
        !iv_fi_belnr   TYPE belnr_d OPTIONAL
        !iv_miro_belnr TYPE belnr_d OPTIONAL
      RAISING
        zcx_zone_iarc_mapping.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_post IMPLEMENTATION.

  METHOD park.
    " BILEREK IMPLEMENTE EDILMEDI: gercek BAPI_INCOMINGINVOICE_PARK (PO'lu)
    " / FI belge park (PO'suz) cagrisi, kullanilacak SAP surumune (S/4 vs
    " ECC), hesap planina ve tolerans kurallarina (ZONE_IARC_T005) bagli
    " parametre detayi gerektiriyor - henuz dogrulanmadi (bkz.
    " program/risks-and-open-questions.md S3, S4). Iskelet burada akisi
    " (hangi BAPI cagrilacagi PO_MATCH'e gore) belgelemek icindir.
    IF is_decision-po_match = abap_true.
      " TODO: BAPI_INCOMINGINVOICE_PARK
      "   HEADERDATA-INVOICE_IND = ' ' (park), REF_DOC_NO = is_header-invoice_id,
      "   BUKRS = iv_bukrs, ITEMDATA[] is_decision-ebeln uzerinden GR/PO satirlari,
      "   tolerans kontrolu is_decision-tolerance_pct ile karsilastirilir.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_POST_001'
          iv_detail     = 'MIRO park (BAPI_INCOMINGINVOICE_PARK) henuz wiring edilmedi (TODO)'.
    ELSE.
      " TODO: FI tedarikci fatura park - BAPI_ACC_DOCUMENT_POST (test_run
      "   veya park-uyumlu cagri) / klasik FB60 park BDC alternatifi.
      "   is_decision-hkont / is_decision-mwskz varsayilan olarak kullanilir.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_POST_002'
          iv_detail     = 'FI tedarikci fatura park henuz wiring edilmedi (TODO)'.
    ENDIF.
  ENDMETHOD.

  METHOD post_parked.
    " TODO: Park edilmis belgeyi (FI veya MIRO) kesin postaya cevirme -
    " BAPI_INCOMINGINVOICE_POST veya FI karsiligi. Onay akisindan sonra
    " cagrilir (bkz. ZCL_ZONE_IARC_REVIEW).
    RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
      EXPORTING
        iv_error_code = 'IARC_POST_003'
        iv_detail     = 'Park->post gecisi henuz wiring edilmedi (TODO)'.
  ENDMETHOD.

ENDCLASS.
