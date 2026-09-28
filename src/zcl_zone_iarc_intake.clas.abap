CLASS zcl_zone_iarc_intake DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Elde edilmis (entegratorden cekilmis VEYA manuel yuklenmis) tek bir
    " UBL belgesini pipeline'a sokar: kuyruk (T006) + ham XML (T007) ->
    " PARSE -> STORE (T009..T016) -> RESOLVE (LIFNR) -> MAP -> PARK.
    " Belgenin NEREDEN geldigini bilmez - ZCL_ZONE_IARC_POLLER (Bayt) ve
    " ZONE_IARC_UPLOAD (yerel dosya) ayni akisi kullanir (Karar 019).
    "
    " COMMIT yapmaz - LUW sinirini cagiran belirler.

    TYPES:
      BEGIN OF ty_result,
        status  TYPE zone_iarc_t006-status,
        ettn    TYPE zone_iarc_t006-ettn,
        lifnr   TYPE lifnr,
        message TYPE string,
      END OF ty_result.

    METHODS constructor
      IMPORTING
        !io_log TYPE REF TO zcl_zone_iarc_log OPTIONAL.

    METHODS process
      IMPORTING
        !iv_bukrs           TYPE bukrs
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
        !iv_xml             TYPE xstring
        !is_meta            TYPE zif_zone_iarc_types=>ty_doc_meta OPTIONAL
        !iv_ettn            TYPE string OPTIONAL
        !iv_received_at     TYPE timestampl OPTIONAL
      RETURNING
        VALUE(rs_result)    TYPE ty_result.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_log   TYPE REF TO zcl_zone_iarc_log.
    DATA mv_docid TYPE zone_iarc_t006-provider_doc_id.

    METHODS insert_queue
      IMPORTING
        !iv_bukrs       TYPE bukrs
        !is_meta        TYPE zif_zone_iarc_types=>ty_doc_meta
        !iv_ettn        TYPE string
        !iv_received_at TYPE timestampl.

    METHODS insert_raw_xml
      IMPORTING
        !iv_xml TYPE xstring.

    METHODS is_ettn_stored
      IMPORTING
        !iv_bukrs        TYPE bukrs
        !iv_ettn         TYPE string
      RETURNING
        VALUE(rv_stored) TYPE abap_bool.

    " Belgeyi EXCEPTION'a ceker, log yazar, sonucu doldurur.
    METHODS fail
      IMPORTING
        !iv_step    TYPE zone_iarc_t008-step
        !iv_message TYPE string
      CHANGING
        !cs_result  TYPE ty_result.
ENDCLASS.



CLASS zcl_zone_iarc_intake IMPLEMENTATION.

  METHOD constructor.
    mo_log = COND #( WHEN io_log IS BOUND THEN io_log ELSE NEW zcl_zone_iarc_log( ) ).
  ENDMETHOD.

  METHOD process.
    mv_docid = iv_provider_doc_id.

    insert_queue( iv_bukrs = iv_bukrs is_meta = is_meta iv_ettn = iv_ettn iv_received_at = iv_received_at ).
    insert_raw_xml( iv_xml ).
    rs_result-status = 'NEW'.

    " --- PARSE ---
    TRY.
        DATA(ls_header) = NEW zcl_zone_iarc_parser( )->parse( iv_xml ).
      CATCH zcx_zone_iarc_mapping INTO DATA(lx_mapping).
        fail( EXPORTING iv_step = 'PARSE' iv_message = lx_mapping->get_text( ) CHANGING cs_result = rs_result ).
        RETURN.
    ENDTRY.
    rs_result-ettn = ls_header-uuid.

    " --- STORE --- T009 anahtari BUKRS+ETTN: ayni ETTN farkli bir belge
    " no ile ikinci kez gelirse INSERT kisa dokume (duplicate key) dusmesin.
    IF is_ettn_stored( iv_bukrs = iv_bukrs iv_ettn = ls_header-uuid ) = abap_true.
      fail( EXPORTING iv_step    = 'STORE'
                      iv_message = |ETTN daha once alinmis: { ls_header-uuid }|
            CHANGING  cs_result  = rs_result ) ##NO_TEXT.
      RETURN.
    ENDIF.

    UPDATE zone_iarc_t006 SET ettn = @ls_header-uuid, status = 'PARSED'
      WHERE provider_doc_id = @mv_docid.
    NEW zcl_zone_iarc_store( )->save(
      iv_bukrs           = iv_bukrs
      iv_provider_doc_id = mv_docid
      is_header          = ls_header ).
    mo_log->write( iv_provider_doc_id = mv_docid iv_step = 'STORE' iv_status = 'OK' ).
    rs_result-status = 'PARSED'.

    " --- RESOLVE ---
    rs_result-lifnr = NEW zcl_zone_iarc_resolver( )->resolve( CONV #( ls_header-supplier_vkn ) ).
    IF rs_result-lifnr IS INITIAL.
      fail( EXPORTING iv_step    = 'RESOLVE'
                      iv_message = |Tedarikci esleme bulunamadi: { ls_header-supplier_vkn }|
            CHANGING  cs_result  = rs_result ) ##NO_TEXT.
      RETURN.
    ENDIF.
    UPDATE zone_iarc_t006 SET lifnr = @rs_result-lifnr WHERE provider_doc_id = @mv_docid.

    " --- MAP ---
    TRY.
        DATA(ls_decision) = NEW zcl_zone_iarc_mapper( )->decide(
          iv_bukrs  = iv_bukrs
          iv_lifnr  = rs_result-lifnr
          is_header = ls_header ).
      CATCH zcx_zone_iarc_mapping INTO lx_mapping.
        fail( EXPORTING iv_step = 'MAP' iv_message = lx_mapping->get_text( ) CHANGING cs_result = rs_result ).
        RETURN.
    ENDTRY.
    UPDATE zone_iarc_t006 SET status = 'MAPPED' WHERE provider_doc_id = @mv_docid.
    rs_result-status = 'MAPPED'.

    " --- PARK ---
    TRY.
        NEW zcl_zone_iarc_post( )->park(
          EXPORTING
            iv_bukrs      = iv_bukrs
            iv_lifnr      = rs_result-lifnr
            is_header     = ls_header
            is_decision   = ls_decision
          IMPORTING
            ev_fi_belnr   = DATA(lv_fi_belnr)
            ev_miro_belnr = DATA(lv_miro_belnr) ).
      CATCH zcx_zone_iarc_mapping INTO lx_mapping.
        fail( EXPORTING iv_step = 'PARK' iv_message = lx_mapping->get_text( ) CHANGING cs_result = rs_result ).
        RETURN.
    ENDTRY.
    UPDATE zone_iarc_t006 SET status = 'PARKED', fi_belnr = @lv_fi_belnr, miro_belnr = @lv_miro_belnr
      WHERE provider_doc_id = @mv_docid.
    mo_log->write( iv_provider_doc_id = mv_docid iv_step = 'PARK' iv_status = 'OK' ).
    rs_result-status = 'PARKED'.
  ENDMETHOD.

  METHOD insert_queue.
    DATA ls_queue TYPE zone_iarc_t006.
    ls_queue-provider_doc_id = mv_docid.
    ls_queue-ettn            = iv_ettn.
    ls_queue-bukrs           = iv_bukrs.
    ls_queue-supplier_vkn    = is_meta-supplier_vkn.
    ls_queue-doc_date        = is_meta-doc_date.
    ls_queue-amount          = is_meta-amount.
    ls_queue-currency        = is_meta-currency.
    ls_queue-status          = 'NEW'.
    ls_queue-received_at     = iv_received_at.
    IF ls_queue-received_at IS INITIAL.
      GET TIME STAMP FIELD ls_queue-received_at.
    ENDIF.
    ls_queue-created_by      = sy-uname.
    GET TIME STAMP FIELD ls_queue-created_at.
    INSERT zone_iarc_t006 FROM @ls_queue.
  ENDMETHOD.

  METHOD insert_raw_xml.
    DATA ls_xml TYPE zone_iarc_t007.
    ls_xml-provider_doc_id = mv_docid.
    ls_xml-xml_raw         = iv_xml.
    " EF_HASHSTRING STRING tipinde; tablo alani (CHAR) ile dogrudan
    " eslestirilemez (IMPORTING tip uyumlulugu) - ara degisken kullanilir.
    DATA lv_hash TYPE string.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_raw(
          EXPORTING if_algorithm  = 'SHA256'
                    if_data       = iv_xml
          IMPORTING ef_hashstring = lv_hash ).
        ls_xml-checksum = lv_hash.
      CATCH cx_abap_message_digest.
        CLEAR ls_xml-checksum. " bilerek yutuluyor - butunluk dogrulama best-effort (TODO)
    ENDTRY.
    GET TIME STAMP FIELD ls_xml-stored_at.
    INSERT zone_iarc_t007 FROM @ls_xml.
  ENDMETHOD.

  METHOD is_ettn_stored.
    SELECT SINGLE @abap_true FROM zone_iarc_t009
      WHERE bukrs = @iv_bukrs AND ettn = @iv_ettn
      INTO @rv_stored.
  ENDMETHOD.

  METHOD fail.
    DATA lv_error TYPE zone_iarc_t006-error_text.
    lv_error = iv_message.
    UPDATE zone_iarc_t006 SET status = 'EXCEPTION', error_text = @lv_error
      WHERE provider_doc_id = @mv_docid.
    mo_log->write( iv_provider_doc_id = mv_docid iv_step = iv_step iv_status = 'ERROR'
                   iv_message = CONV #( iv_message ) ).
    cs_result-status  = 'EXCEPTION'.
    cs_result-message = iv_message.
  ENDMETHOD.

ENDCLASS.
