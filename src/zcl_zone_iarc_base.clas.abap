CLASS zcl_zone_iarc_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PROTECTED.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        !iv_provider_key TYPE char10.

  PROTECTED SECTION.
    " Servis tipleri Bayt E-Belge Partner API'sine gore (bkz.
    " "Bayt E-Belge Partner.postman_collection.json", program/decision-log.md
    " Karar 010): AUTH=AuthenticateExt, LIST=GetInvoiceListExt,
    " GET=GetByInvoiceNoExt, DOWNLOAD=DownloadFileExt. ACK servisi yok.
    DATA mv_provider_key      TYPE char10.
    DATA mv_endpoint_auth     TYPE string.
    DATA mv_endpoint_list     TYPE string.
    DATA mv_endpoint_get      TYPE string.
    DATA mv_endpoint_download TYPE string.
    DATA mv_timeout_sec       TYPE i.
    DATA mv_retry_count       TYPE i.
    DATA mo_log               TYPE REF TO zcl_zone_iarc_log.

    METHODS load_endpoint_config
      IMPORTING
        !iv_environment TYPE char3 DEFAULT 'DEV'.

    METHODS get_company_params
      IMPORTING
        !iv_bukrs TYPE bukrs
      EXPORTING
        !ev_comp_tax_no    TYPE zone_iarc_t001-comp_tax_no
        !ev_comp_serial_no TYPE zone_iarc_t001-comp_serial_no
        !ev_acc_user_code  TYPE zone_iarc_t001-acc_user_code
        !ev_acc_tax_no     TYPE zone_iarc_t001-acc_tax_no
        !ev_acc_password   TYPE string
      RAISING
        zcx_zone_iarc_provider.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_base IMPLEMENTATION.

  METHOD constructor.
    mv_provider_key = iv_provider_key.
    mo_log          = NEW zcl_zone_iarc_log( ).
    load_endpoint_config( ).
  ENDMETHOD.

  METHOD load_endpoint_config.
    SELECT SINGLE endpoint_url timeout_sec retry_count FROM zone_iarc_t003
      INTO (@mv_endpoint_auth, @mv_timeout_sec, @mv_retry_count)
      WHERE provider_key  = @mv_provider_key
        AND environment   = @iv_environment
        AND service_type  = 'AUTH'
        AND active_flg    = @abap_true.

    SELECT SINGLE endpoint_url FROM zone_iarc_t003
      INTO @mv_endpoint_list
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
      INTO @mv_endpoint_download
      WHERE provider_key  = @mv_provider_key
        AND environment   = @iv_environment
        AND service_type  = 'DOWNLOAD'
        AND active_flg    = @abap_true.

    IF mv_timeout_sec IS INITIAL.
      mv_timeout_sec = 30.
    ENDIF.
    IF mv_retry_count IS INITIAL.
      mv_retry_count = 2.
    ENDIF.
  ENDMETHOD.

  METHOD get_company_params.
    SELECT SINGLE comp_tax_no comp_serial_no acc_user_code acc_tax_no acc_pwd_key
      FROM zone_iarc_t001
      INTO (@ev_comp_tax_no, @ev_comp_serial_no, @ev_acc_user_code, @ev_acc_tax_no, @DATA(lv_pwd_key))
      WHERE bukrs = @iv_bukrs.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_zone_iarc_provider
        EXPORTING
          iv_error_code = 'IARC_PROV_010'
          iv_detail     = |BUKRS { iv_bukrs } icin Bayt sirket/muhasebeci parametresi (ZONE_IARC_T001) bulunamadi|.
    ENDIF.
    ev_acc_password = zcl_zone_iarc_secret=>read( lv_pwd_key ).
  ENDMETHOD.

ENDCLASS.
