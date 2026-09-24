CLASS zcl_zone_iarc_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PROTECTED.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        !iv_provider_key TYPE char10.

  PROTECTED SECTION.
    DATA mv_provider_key  TYPE char10.
    DATA mv_endpoint_list TYPE string.
    DATA mv_endpoint_get  TYPE string.
    DATA mv_endpoint_ack  TYPE string.
    DATA mv_timeout_sec   TYPE i.
    DATA mv_retry_count   TYPE i.
    DATA mo_log           TYPE REF TO zcl_zone_iarc_log.

    METHODS load_endpoint_config
      IMPORTING
        !iv_environment TYPE char3 DEFAULT 'DEV'.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_base IMPLEMENTATION.

  METHOD constructor.
    mv_provider_key = iv_provider_key.
    mo_log          = NEW zcl_zone_iarc_log( ).
    load_endpoint_config( ).
  ENDMETHOD.

  METHOD load_endpoint_config.
    " ZONE_IARC_T003'ten SERVICE_TYPE bazinda (LIST/GET/ACK) endpoint/auth
    " okunur. Gercek Zonetegra URL/auth degerleri henuz customizing'e
    " girilmedi (bkz. program/risks-and-open-questions.md S1) - bu yuzden
    " satirlar bulunamazsa alanlar bos kalir, cagiran somut adapter (
    " ZCL_ZONE_IARC_PROVIDER) bunu ZCX_ZONE_IARC_PROVIDER ile bildirir.
    SELECT SINGLE endpoint_url timeout_sec retry_count FROM zone_iarc_t003
      INTO (@mv_endpoint_list, @mv_timeout_sec, @mv_retry_count)
      WHERE provider_key  = @mv_provider_key
        AND environment   = @iv_environment
        AND service_type  = 'LIST'
        AND active_flg    = @abap_true.

    SELECT SINGLE endpoint_url FROM zone_iarc_t003
      INTO @mv_endpoint_get
      WHERE provider_key  = @mv_provider_key
        AND environment   = @iv_environment
        AND service_type  = 'GET'
        AND active_flg    = @abap_true.

    SELECT SINGLE endpoint_url FROM zone_iarc_t003
      INTO @mv_endpoint_ack
      WHERE provider_key  = @mv_provider_key
        AND environment   = @iv_environment
        AND service_type  = 'ACK'
        AND active_flg    = @abap_true.

    IF mv_timeout_sec IS INITIAL.
      mv_timeout_sec = 30.
    ENDIF.
    IF mv_retry_count IS INITIAL.
      mv_retry_count = 2.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
