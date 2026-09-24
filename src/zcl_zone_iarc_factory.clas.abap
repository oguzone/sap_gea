CLASS zcl_zone_iarc_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS get_provider
      IMPORTING
        !iv_bukrs TYPE bukrs
      RETURNING
        VALUE(ro_provider) TYPE REF TO zif_zone_iarc_provider
      RAISING
        zcx_zone_iarc_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_factory IMPLEMENTATION.

  METHOD get_provider.
    " Cagiran taraf (ZCL_ZONE_IARC_POLLER) somut adapter ismini hicbir zaman
    " bilmez - yalnizca ZIF_ZONE_IARC_PROVIDER referansiyla calisir (bkz.
    " architecture/class-design.md).
    DATA(lo_config) = NEW zcl_zone_iarc_config( ).

    IF lo_config->is_bukrs_active( iv_bukrs ) = abap_false.
      RAISE EXCEPTION TYPE zcx_zone_iarc_provider
        EXPORTING
          iv_error_code = 'IARC_CFG_001'
          iv_detail     = |BUKRS { iv_bukrs } icin gelen e-Arsiv aktif degil|.
    ENDIF.

    DATA(lv_key)   = lo_config->get_active_provider_key( iv_bukrs ).
    DATA(lv_class) = lo_config->get_adapter_class( lv_key ).

    TRY.
        CREATE OBJECT ro_provider TYPE (lv_class).
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE zcx_zone_iarc_provider
          EXPORTING
            previous      = lx_create
            iv_error_code = 'IARC_CFG_002'
            iv_detail     = |Adapter sinifi olusturulamadi: { lv_class }|.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
