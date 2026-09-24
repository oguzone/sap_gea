CLASS zcl_zone_iarc_config DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Uyarlama okumanin tek yeri (no-hardcode). Tablo boşsa güvenli fallback
    " döner - böylece customizing girilmeden de pipeline mock provider ile
    " calisabilir (bkz. architecture/database-design.md).

    METHODS is_bukrs_active
      IMPORTING
        !iv_bukrs TYPE bukrs
      RETURNING
        VALUE(rv_active) TYPE abap_bool.

    METHODS get_poll_interval
      IMPORTING
        !iv_bukrs TYPE bukrs
      RETURNING
        VALUE(rv_minutes) TYPE i.

    METHODS get_active_provider_key
      IMPORTING
        !iv_bukrs TYPE bukrs
      RETURNING
        VALUE(rv_key) TYPE char10.

    METHODS get_adapter_class
      IMPORTING
        !iv_provider_key TYPE char10
      RETURNING
        VALUE(rv_class) TYPE seoclsname.

    METHODS get_vendor_override
      IMPORTING
        !iv_vkn_tckn TYPE char11
      RETURNING
        VALUE(rv_lifnr) TYPE lifnr.

    METHODS get_posting_rule
      IMPORTING
        !iv_bukrs TYPE bukrs
        !iv_po_match TYPE abap_bool
      EXPORTING
        !ev_hkont TYPE saknr
        !ev_mwskz TYPE mwskz
        !ev_tolerance_pct TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_config IMPLEMENTATION.

  METHOD is_bukrs_active.
    SELECT SINGLE active_flg FROM zone_iarc_t001
      INTO @DATA(lv_flg)
      WHERE bukrs = @iv_bukrs.
    rv_active = COND #( WHEN sy-subrc = 0 AND lv_flg = abap_true THEN abap_true ELSE abap_false ).
  ENDMETHOD.

  METHOD get_poll_interval.
    SELECT SINGLE poll_interval_min FROM zone_iarc_t001
      INTO @DATA(lv_min)
      WHERE bukrs = @iv_bukrs.
    rv_minutes = COND #( WHEN sy-subrc = 0 AND lv_min > 0 THEN lv_min ELSE 15 ).
  ENDMETHOD.

  METHOD get_active_provider_key.
    " MVP kapsaminda tek entegrator (ZONETEGRA); T002'de birden fazla
    " ACTIVE_FLG='X' kaydi varsa ilk bulunan doner - BUKRS bazli oncelik
    " kurali henuz yok (bkz. program/risks-and-open-questions.md).
    SELECT SINGLE provider_key FROM zone_iarc_t002
      INTO @rv_key
      WHERE active_flg = @abap_true.
    IF sy-subrc <> 0.
      rv_key = 'MOCK'.
    ENDIF.
  ENDMETHOD.

  METHOD get_adapter_class.
    SELECT SINGLE adapter_class FROM zone_iarc_t002
      INTO @rv_class
      WHERE provider_key = @iv_provider_key
        AND active_flg   = @abap_true.
    IF sy-subrc <> 0.
      rv_class = 'ZCL_ZONE_IARC_MOCK'.
    ENDIF.
  ENDMETHOD.

  METHOD get_vendor_override.
    SELECT SINGLE lifnr FROM zone_iarc_t004
      INTO @rv_lifnr
      WHERE vkn_tckn    = @iv_vkn_tckn
        AND active_flg  = @abap_true.
  ENDMETHOD.

  METHOD get_posting_rule.
    SELECT SINGLE default_hkont default_mwskz tolerance_pct
      FROM zone_iarc_t005
      INTO (@ev_hkont, @ev_mwskz, @DATA(lv_tol))
      WHERE bukrs    = @iv_bukrs
        AND po_match = @iv_po_match.
    ev_tolerance_pct = COND #( WHEN sy-subrc = 0 THEN lv_tol ELSE 0 ).
  ENDMETHOD.

ENDCLASS.
