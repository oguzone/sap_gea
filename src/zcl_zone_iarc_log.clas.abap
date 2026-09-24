CLASS zcl_zone_iarc_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS write
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t008-provider_doc_id OPTIONAL
        !iv_step            TYPE zone_iarc_t008-step
        !iv_status          TYPE zone_iarc_t008-log_status DEFAULT 'OK'
        !iv_message         TYPE zone_iarc_t008-message OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_log IMPLEMENTATION.

  METHOD write.
    " KVKK/guvenlik: MESSAGE alanina hassas payload/credential yazilmamali.
    DATA ls_log TYPE zone_iarc_t008.

    ls_log-guid            = cl_system_uuid=>create_uuid_c32_static( ).
    ls_log-provider_doc_id = iv_provider_doc_id.
    ls_log-step            = iv_step.
    ls_log-log_status      = iv_status.
    ls_log-message         = iv_message.
    ls_log-created_by      = sy-uname.
    GET TIME STAMP FIELD ls_log-created_at.

    INSERT zone_iarc_t008 FROM @ls_log.
    " Insert basarisiz olsa bile loglama akisi is akisini kesmemeli; sy-subrc
    " kasitli olarak kontrol edilmiyor.
  ENDMETHOD.

ENDCLASS.
