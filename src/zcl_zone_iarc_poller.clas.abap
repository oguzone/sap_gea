CLASS zcl_zone_iarc_poller DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS run
      IMPORTING
        !iv_bukrs TYPE bukrs
      RETURNING
        VALUE(rt_messages) TYPE bapiret2_t.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_log TYPE REF TO zcl_zone_iarc_log.

    METHODS process_one
      IMPORTING
        !iv_bukrs      TYPE bukrs
        !io_provider   TYPE REF TO zif_zone_iarc_provider
        !is_ref        TYPE zif_zone_iarc_types=>ty_doc_ref
      CHANGING
        !ct_messages   TYPE bapiret2_t.
ENDCLASS.



CLASS zcl_zone_iarc_poller IMPLEMENTATION.

  METHOD run.
    mo_log = NEW zcl_zone_iarc_log( ).

    TRY.
        DATA(lo_provider) = zcl_zone_iarc_factory=>get_provider( iv_bukrs ).
      CATCH zcx_zone_iarc_provider INTO DATA(lx_provider).
        mo_log->write( iv_step = 'POLL' iv_status = 'ERROR' iv_message = lx_provider->get_text( ) ).
        APPEND VALUE #( type = 'E' message = lx_provider->get_text( ) ) TO rt_messages.
        RETURN.
    ENDTRY.

    DATA lv_since TYPE timestampl.
    GET TIME STAMP FIELD lv_since.
    " TIMESTAMPL paketlenmis tarih/saat formatidir, duz saniye sayaci
    " degildir - dogru gun cikartma icin CL_ABAP_TSTMP kullanilir. Basit
    " varsayilan: son 24 saat (T001'e tasinmali - TODO).
    CALL METHOD cl_abap_tstmp=>subtractsecs
      EXPORTING
        secs  = 86400
      CHANGING
        tstmp = lv_since.

    TRY.
        DATA(lt_refs) = lo_provider->list_new_documents( iv_bukrs = iv_bukrs iv_since = lv_since ).
      CATCH zcx_zone_iarc_provider INTO lx_provider.
        mo_log->write( iv_step = 'POLL' iv_status = 'ERROR' iv_message = lx_provider->get_text( ) ).
        APPEND VALUE #( type = 'E' message = lx_provider->get_text( ) ) TO rt_messages.
        RETURN.
    ENDTRY.

    mo_log->write( iv_step = 'POLL' iv_status = 'OK'
      iv_message = |{ lines( lt_refs ) } yeni belge referansi bulundu| ).

    LOOP AT lt_refs INTO DATA(ls_ref).
      process_one(
        EXPORTING
          iv_bukrs    = iv_bukrs
          io_provider = lo_provider
          is_ref      = ls_ref
        CHANGING
          ct_messages = rt_messages ).
    ENDLOOP.
  ENDMETHOD.

  METHOD process_one.
    DATA(lo_parser) = NEW zcl_zone_iarc_parser( ).

    IF lo_parser->is_duplicate( is_ref-provider_doc_id ) = abap_true.
      mo_log->write( iv_provider_doc_id = is_ref-provider_doc_id iv_step = 'FETCH' iv_status = 'OK'
        iv_message = 'Duplicate - atlandi' ).
      RETURN.
    ENDIF.

    TRY.
        io_provider->get_document(
          EXPORTING iv_bukrs           = iv_bukrs
                    iv_provider_doc_id = is_ref-provider_doc_id
                    iv_supplier_tax_no = is_ref-supplier_tax_no
          IMPORTING ev_xml             = DATA(lv_xml)
                    es_meta            = DATA(ls_meta) ).
      CATCH zcx_zone_iarc_provider INTO DATA(lx_provider).
        mo_log->write( iv_provider_doc_id = is_ref-provider_doc_id iv_step = 'FETCH' iv_status = 'ERROR'
          iv_message = lx_provider->get_text( ) ).
        APPEND VALUE #( type = 'E' message = lx_provider->get_text( ) ) TO ct_messages.
        RETURN.
    ENDTRY.

    " Kuyruk + ham XML kaydi (STATUS=NEW -> asagida guncellenecek).
    DATA ls_queue TYPE zone_iarc_t006.
    ls_queue-provider_doc_id = is_ref-provider_doc_id.
    ls_queue-ettn            = is_ref-ettn.
    ls_queue-bukrs           = iv_bukrs.
    ls_queue-supplier_vkn    = ls_meta-supplier_vkn.
    ls_queue-doc_date        = ls_meta-doc_date.
    ls_queue-amount          = ls_meta-amount.
    ls_queue-currency        = ls_meta-currency.
    ls_queue-status          = 'NEW'.
    ls_queue-received_at     = is_ref-received_at.
    ls_queue-created_by      = sy-uname.
    GET TIME STAMP FIELD ls_queue-created_at.
    INSERT zone_iarc_t006 FROM @ls_queue.

    DATA ls_xml TYPE zone_iarc_t007.
    ls_xml-provider_doc_id = is_ref-provider_doc_id.
    ls_xml-xml_raw         = lv_xml.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_raw(
          EXPORTING if_algorithm  = 'SHA256'
                    if_data       = lv_xml
          IMPORTING ef_hashstring = ls_xml-checksum ).
      CATCH cx_abap_message_digest.
        CLEAR ls_xml-checksum. " bilerek yutuluyor - butunluk dogrulama best-effort (TODO)
    ENDTRY.
    GET TIME STAMP FIELD ls_xml-stored_at.
    INSERT zone_iarc_t007 FROM @ls_xml.

    TRY.
        DATA(ls_header) = lo_parser->parse( lv_xml ).
      CATCH zcx_zone_iarc_mapping INTO DATA(lx_mapping).
        UPDATE zone_iarc_t006 SET status = 'EXCEPTION' error_text = lx_mapping->get_text( )
          WHERE provider_doc_id = is_ref-provider_doc_id.
        mo_log->write( iv_provider_doc_id = is_ref-provider_doc_id iv_step = 'PARSE' iv_status = 'ERROR'
          iv_message = lx_mapping->get_text( ) ).
        RETURN.
    ENDTRY.

    UPDATE zone_iarc_t006 SET ettn = ls_header-uuid status = 'PARSED'
      WHERE provider_doc_id = is_ref-provider_doc_id.

    " UBL modelini normalize tablolara yaz (T009 baslik .. T014 kalem vergi
    " alt toplami) - kalicilik icin XML'i tekrar parse etmeye gerek kalmaz.
    NEW zcl_zone_iarc_store( )->save(
      iv_bukrs           = iv_bukrs
      iv_provider_doc_id = is_ref-provider_doc_id
      is_header          = ls_header ).
    mo_log->write( iv_provider_doc_id = is_ref-provider_doc_id iv_step = 'STORE' iv_status = 'OK' ).

    DATA(lo_resolver) = NEW zcl_zone_iarc_resolver( ).
    DATA(lv_lifnr)    = lo_resolver->resolve( ls_header-supplier_vkn ).
    IF lv_lifnr IS INITIAL.
      UPDATE zone_iarc_t006 SET status = 'EXCEPTION'
        error_text = |Tedarikci esleme bulunamadi: { ls_header-supplier_vkn }|
        WHERE provider_doc_id = is_ref-provider_doc_id.
      mo_log->write( iv_provider_doc_id = is_ref-provider_doc_id iv_step = 'RESOLVE' iv_status = 'ERROR'
        iv_message = |Tedarikci esleme bulunamadi: { ls_header-supplier_vkn }| ).
      RETURN.
    ENDIF.
    UPDATE zone_iarc_t006 SET lifnr = lv_lifnr WHERE provider_doc_id = is_ref-provider_doc_id.

    DATA(lo_mapper) = NEW zcl_zone_iarc_mapper( ).
    TRY.
        DATA(ls_decision) = lo_mapper->decide(
          iv_bukrs  = iv_bukrs
          iv_lifnr  = lv_lifnr
          is_header = ls_header ).
      CATCH zcx_zone_iarc_mapping INTO lx_mapping.
        UPDATE zone_iarc_t006 SET status = 'EXCEPTION' error_text = lx_mapping->get_text( )
          WHERE provider_doc_id = is_ref-provider_doc_id.
        mo_log->write( iv_provider_doc_id = is_ref-provider_doc_id iv_step = 'MAP' iv_status = 'ERROR'
          iv_message = lx_mapping->get_text( ) ).
        RETURN.
    ENDTRY.
    UPDATE zone_iarc_t006 SET status = 'MAPPED' WHERE provider_doc_id = is_ref-provider_doc_id.

    DATA(lo_post) = NEW zcl_zone_iarc_post( ).
    TRY.
        lo_post->park(
          EXPORTING
            iv_bukrs    = iv_bukrs
            iv_lifnr    = lv_lifnr
            is_header   = ls_header
            is_decision = ls_decision
          IMPORTING
            ev_fi_belnr   = DATA(lv_fi_belnr)
            ev_miro_belnr = DATA(lv_miro_belnr) ).
        UPDATE zone_iarc_t006 SET status = 'PARKED' fi_belnr = lv_fi_belnr miro_belnr = lv_miro_belnr
          WHERE provider_doc_id = is_ref-provider_doc_id.
        mo_log->write( iv_provider_doc_id = is_ref-provider_doc_id iv_step = 'PARK' iv_status = 'OK' ).
      CATCH zcx_zone_iarc_mapping INTO lx_mapping.
        UPDATE zone_iarc_t006 SET status = 'EXCEPTION' error_text = lx_mapping->get_text( )
          WHERE provider_doc_id = is_ref-provider_doc_id.
        mo_log->write( iv_provider_doc_id = is_ref-provider_doc_id iv_step = 'PARK' iv_status = 'ERROR'
          iv_message = lx_mapping->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
