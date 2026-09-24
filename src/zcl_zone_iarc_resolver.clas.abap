CLASS zcl_zone_iarc_resolver DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS resolve
      IMPORTING
        !iv_vkn_tckn TYPE char11
      RETURNING
        VALUE(rv_lifnr) TYPE lifnr.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_resolver IMPLEMENTATION.

  METHOD resolve.
    " 1) Manuel override (ZONE_IARC_T004) - musteri VKN/TCKN'yi bilerek
    "    farkli bir LIFNR'a baglamak isterse.
    DATA(lo_config) = NEW zcl_zone_iarc_config( ).
    rv_lifnr = lo_config->get_vendor_override( iv_vkn_tckn ).
    IF rv_lifnr IS NOT INITIAL.
      RETURN.
    ENDIF.

    " 2) LFA1 STCD1 (VKN, 10 hane) / STCD2 (TCKN, 11 hane) otomatik arama.
    IF strlen( iv_vkn_tckn ) = 10.
      SELECT SINGLE lifnr FROM lfa1
        INTO @rv_lifnr
        WHERE stcd1 = @iv_vkn_tckn.
    ELSEIF strlen( iv_vkn_tckn ) = 11.
      SELECT SINGLE lifnr FROM lfa1
        INTO @rv_lifnr
        WHERE stcd2 = @iv_vkn_tckn.
    ENDIF.
    " Bulunamazsa rv_lifnr bos doner; cagiran (ZCL_ZONE_IARC_POLLER)
    " STATUS=EXCEPTION olarak isaretler (bkz. architecture/
    " technical-architecture.md hata yonetimi tablosu).
  ENDMETHOD.

ENDCLASS.
