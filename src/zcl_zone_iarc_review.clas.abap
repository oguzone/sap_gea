CLASS zcl_zone_iarc_review DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS approve
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RAISING
        zcx_zone_iarc_mapping.

    METHODS reject
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
        !iv_reason          TYPE string
      RAISING
        zcx_zone_iarc_mapping.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS read_queue
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_queue) TYPE zone_iarc_t006
      RAISING
        zcx_zone_iarc_mapping.
ENDCLASS.



CLASS zcl_zone_iarc_review IMPLEMENTATION.

  METHOD read_queue.
    SELECT SINGLE * FROM zone_iarc_t006
      INTO @rs_queue
      WHERE provider_doc_id = @iv_provider_doc_id.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_REV_001'
          iv_detail     = |Belge bulunamadi: { iv_provider_doc_id }|.
    ENDIF.
  ENDMETHOD.

  METHOD approve.
    DATA(ls_queue) = read_queue( iv_provider_doc_id ).
    IF ls_queue-status <> 'PARKED'.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_REV_002'
          iv_detail     = |Belge PARKED durumunda degil: { ls_queue-status }|.
    ENDIF.

    DATA(lo_post) = NEW zcl_zone_iarc_post( ).
    DATA(lo_log)  = NEW zcl_zone_iarc_log( ).

    " Yalnizca BAPI ile park edilmis MIRO belgesi kesinlestirilebilir
    " (FB01'den park edilen FI belgesi FBV0 ile kaydedilir).
    IF ls_queue-miro_belnr IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_REV_004'
          iv_detail     = |MIRO park belgesi yok - FI park belgesini FBV0 ile kaydedin| ##NO_TEXT.
    ENDIF.
    lo_post->post_parked( iv_belnr = ls_queue-miro_belnr iv_gjahr = ls_queue-gjahr ).

    UPDATE zone_iarc_t006 SET status = 'POSTED' changed_by = sy-uname
      WHERE provider_doc_id = iv_provider_doc_id.
    lo_log->write( iv_provider_doc_id = iv_provider_doc_id iv_step = 'APPROVE' iv_status = 'OK' ).
  ENDMETHOD.

  METHOD reject.
    DATA(ls_queue) = read_queue( iv_provider_doc_id ).
    IF ls_queue-status <> 'PARKED' AND ls_queue-status <> 'EXCEPTION'.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_REV_003'
          iv_detail     = |Belge bu durumdan reddedilemez: { ls_queue-status }|.
    ENDIF.

    UPDATE zone_iarc_t006 SET status = 'REJECTED' error_text = iv_reason changed_by = sy-uname
      WHERE provider_doc_id = iv_provider_doc_id.

    NEW zcl_zone_iarc_log( )->write(
      iv_provider_doc_id = iv_provider_doc_id iv_step = 'REJECT' iv_status = 'OK' iv_message = iv_reason ).
  ENDMETHOD.

ENDCLASS.
