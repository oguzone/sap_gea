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
        mo_log->write( iv_step = 'POLL' iv_status = 'ERROR' iv_message = |{ lx_provider->mv_error_code } { lx_provider->mv_detail }| ).
        APPEND VALUE #( type = 'E' message = |{ lx_provider->mv_error_code } { lx_provider->mv_detail }| ) TO rt_messages.
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
        mo_log->write( iv_step = 'POLL' iv_status = 'ERROR' iv_message = |{ lx_provider->mv_error_code } { lx_provider->mv_detail }| ).
        APPEND VALUE #( type = 'E' message = |{ lx_provider->mv_error_code } { lx_provider->mv_detail }| ) TO rt_messages.
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
          iv_message = |{ lx_provider->mv_error_code } { lx_provider->mv_detail }| ).
        APPEND VALUE #( type = 'E' message = |{ lx_provider->mv_error_code } { lx_provider->mv_detail }| ) TO ct_messages.
        RETURN.
    ENDTRY.

    " Kuyruk/ham XML/parse/store/resolve/map/park - manuel yukleme
    " (ZONE_IARC_UPLOAD) ile ortak akis (Karar 019).
    DATA(ls_result) = NEW zcl_zone_iarc_intake( mo_log )->process(
      iv_bukrs           = iv_bukrs
      iv_provider_doc_id = CONV #( is_ref-provider_doc_id )
      iv_xml             = lv_xml
      is_meta            = ls_meta
      iv_ettn            = is_ref-ettn
      iv_received_at     = is_ref-received_at ).
    IF ls_result-status = 'EXCEPTION'.
      APPEND VALUE #( type = 'W' message = |{ is_ref-provider_doc_id }: { ls_result-message }| ) TO ct_messages.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
