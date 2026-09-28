CLASS zcl_zone_iarc_intake DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Elde edilmis (entegratorden cekilmis VEYA manuel yuklenmis) tek bir
    " UBL belgesini pipeline'a sokar: kuyruk (T006) + ham XML (T007) ->
    " PARSE -> STORE (T009..T016) -> RESOLVE (LIFNR) -> MAP (-> MAPPED).
    " Muhasebe (park/FB01) kullanici aksiyonudur - ZCL_ZONE_IARC_ACTIONS.
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

    " Kayitli belgeyi (T006/T007) bastan isler - orn. tedarikci eslemesi
    " (LFA1 / ZONE_IARC_T004) sonradan yapildiysa. UBL tablolari zaten bu
    " belgeye aitse yeniden yazilmaz.
    METHODS reprocess
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
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

    " T009'da bu ETTN'nin sahibi olan belge no (yoksa bos).
    METHODS ettn_owner
      IMPORTING
        !iv_bukrs                  TYPE bukrs
        !iv_ettn                   TYPE string
      RETURNING
        VALUE(rv_provider_doc_id)  TYPE zone_iarc_t006-provider_doc_id.

    " PARSE -> STORE -> RESOLVE -> MAP. Kuyruk/ham XML kaydi hazir olmali.
    METHODS run_pipeline
      IMPORTING
        !iv_bukrs        TYPE bukrs
        !iv_xml          TYPE xstring
      RETURNING
        VALUE(rs_result) TYPE ty_result.

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

    rs_result = run_pipeline( iv_bukrs = iv_bukrs iv_xml = iv_xml ).
  ENDMETHOD.

  METHOD reprocess.
    mv_docid = iv_provider_doc_id.

    SELECT SINGLE bukrs FROM zone_iarc_t006
      WHERE provider_doc_id = @mv_docid
      INTO @DATA(lv_bukrs).
    SELECT SINGLE xml_raw FROM zone_iarc_t007
      WHERE provider_doc_id = @mv_docid
      INTO @DATA(lv_xml).
    IF lv_bukrs IS INITIAL OR lv_xml IS INITIAL.
      rs_result-status  = 'EXCEPTION'.
      rs_result-message = |Belge veya ham XML bulunamadi: { mv_docid }| ##NO_TEXT.
      RETURN.
    ENDIF.

    rs_result = run_pipeline( iv_bukrs = lv_bukrs iv_xml = lv_xml ).
  ENDMETHOD.

  METHOD run_pipeline.
    rs_result-status = 'NEW'.

    " --- PARSE ---
    TRY.
        DATA(ls_header) = NEW zcl_zone_iarc_parser( )->parse( iv_xml ).
      CATCH zcx_zone_iarc_mapping INTO DATA(lx_mapping).
        fail( EXPORTING iv_step = 'PARSE' iv_message = |{ lx_mapping->mv_error_code } { lx_mapping->mv_detail }| CHANGING cs_result = rs_result ).
        RETURN.
    ENDTRY.
    rs_result-ettn = ls_header-uuid.

    " --- STORE --- T009 anahtari BUKRS+ETTN. Bu belgeye aitse (yeniden
    " isleme) tekrar yazilmaz; baska belgeye aitse mukerrer ETTN - INSERT
    " kisa dokume (duplicate key) dusmesin.
    DATA(lv_owner) = ettn_owner( iv_bukrs = iv_bukrs iv_ettn = ls_header-uuid ).
    IF lv_owner IS NOT INITIAL AND lv_owner <> mv_docid.
      fail( EXPORTING iv_step    = 'STORE'
                      iv_message = |ETTN daha once alinmis: { ls_header-uuid }|
            CHANGING  cs_result  = rs_result ) ##NO_TEXT.
      RETURN.
    ENDIF.

    UPDATE zone_iarc_t006 SET ettn = @ls_header-uuid, status = 'PARSED'
      WHERE provider_doc_id = @mv_docid.
    IF lv_owner IS INITIAL.
      NEW zcl_zone_iarc_store( )->save(
        iv_bukrs           = iv_bukrs
        iv_provider_doc_id = mv_docid
        is_header          = ls_header ).
      mo_log->write( iv_provider_doc_id = mv_docid iv_step = 'STORE' iv_status = 'OK' ).
    ENDIF.
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

    " --- MAP --- (muhasebe kurali kontrolu)
    TRY.
        NEW zcl_zone_iarc_mapper( )->decide(
          iv_bukrs  = iv_bukrs
          iv_lifnr  = rs_result-lifnr
          is_header = ls_header ).
      CATCH zcx_zone_iarc_mapping INTO lx_mapping.
        fail( EXPORTING iv_step = 'MAP' iv_message = |{ lx_mapping->mv_error_code } { lx_mapping->mv_detail }| CHANGING cs_result = rs_result ).
        RETURN.
    ENDTRY.

    " Otomatik park YOK (Karar 028): belge "muhasebeye hazir" (MAPPED)
    " kalir; kullanici ZONE_IARC_INCOMING'den BAPI park ya da FB01 secer.
    DATA lv_no_error TYPE zone_iarc_t006-error_text.
    UPDATE zone_iarc_t006 SET status = 'MAPPED', error_text = @lv_no_error
      WHERE provider_doc_id = @mv_docid.
    mo_log->write( iv_provider_doc_id = mv_docid iv_step = 'MAP' iv_status = 'OK' ).
    rs_result-status = 'MAPPED'.
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

  METHOD ettn_owner.
    SELECT SINGLE provider_doc_id FROM zone_iarc_t009
      WHERE bukrs = @iv_bukrs AND ettn = @iv_ettn
      INTO @rv_provider_doc_id.
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
