CLASS zcl_zone_iarc_mapper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_decision,
        po_match      TYPE abap_bool,
        ebeln         TYPE ebeln,
        hkont         TYPE saknr,
        mwskz         TYPE mwskz,
        tolerance_pct TYPE i,
      END OF ty_decision.

    METHODS decide
      IMPORTING
        !iv_bukrs  TYPE bukrs
        !iv_lifnr  TYPE lifnr
        !is_header TYPE zif_zone_iarc_types=>ty_header
      RETURNING
        VALUE(rs_decision) TYPE ty_decision
      RAISING
        zcx_zone_iarc_mapping.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS find_open_po
      IMPORTING
        !iv_lifnr TYPE lifnr
        !iv_bukrs TYPE bukrs
      RETURNING
        VALUE(rv_ebeln) TYPE ebeln.
ENDCLASS.



CLASS zcl_zone_iarc_mapper IMPLEMENTATION.

  METHOD decide.
    rs_decision-ebeln = find_open_po( iv_lifnr = iv_lifnr iv_bukrs = iv_bukrs ).
    rs_decision-po_match = COND #( WHEN rs_decision-ebeln IS NOT INITIAL THEN abap_true ELSE abap_false ).

    DATA(lo_config) = NEW zcl_zone_iarc_config( ).
    lo_config->get_posting_rule(
      EXPORTING
        iv_bukrs         = iv_bukrs
        iv_po_match       = rs_decision-po_match
      IMPORTING
        ev_hkont          = rs_decision-hkont
        ev_mwskz          = rs_decision-mwskz
        ev_tolerance_pct  = rs_decision-tolerance_pct ).

    IF rs_decision-po_match = abap_false AND rs_decision-hkont IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zone_iarc_mapping
        EXPORTING
          iv_error_code = 'IARC_MAP_001'
          iv_detail     = |BUKRS { iv_bukrs } icin PO'suz senaryo muhasebelestirme kurali (ZONE_IARC_T005) tanimli degil|.
    ENDIF.
  ENDMETHOD.

  METHOD find_open_po.
    " Basit acik PO aramasi: tedarikci + sirket kodu bazinda henuz tam
    " faturalanmamis bir siparis kalemi var mi (EKKO/EKPO). Gercek 3-way
    " match (miktar/tutar tolerans) kontrolu ZCL_ZONE_IARC_POST'ta,
    " MIRO park cagrisindan once yapilir - burada sadece PO_MATCH=X/bos
    " karari icin varlik kontrolu yeterlidir.
    SELECT SINGLE ekko~ebeln FROM ekko
      INNER JOIN ekpo ON ekpo~ebeln = ekko~ebeln
      INTO @rv_ebeln
      WHERE ekko~bukrs = @iv_bukrs
        AND ekko~lifnr = @iv_lifnr
        AND ekpo~loekz = @space.
  ENDMETHOD.

ENDCLASS.
