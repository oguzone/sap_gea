CLASS zcl_zone_iarc_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Belge durum kodunun (ZONE_IARC_T006-STATUS: NEW, MAPPED, EXCEPTION...)
    " ekranda gosterilecek metni (Karar 035). Kodlar veritabaninda ve
    " programda degismez; metinler ZONE_IARC_D001 domain sabit degerlerinden
    " oturum dilinde okunur (SE63 ile cevrilebilir). Metin yoksa kod doner.

    CLASS-METHODS text
      IMPORTING
        !iv_status     TYPE zone_iarc_t006-status
      RETURNING
        VALUE(rv_text) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_data_element TYPE string VALUE 'ZONE_IARC_E001'.

    CLASS-DATA gt_values TYPE ddfixvalues.
    CLASS-DATA gv_loaded TYPE abap_bool.
ENDCLASS.



CLASS zcl_zone_iarc_status IMPLEMENTATION.

  METHOD text.
    IF gv_loaded = abap_false.
      gv_loaded = abap_true.
      TRY.
          DATA(lo_type) = CAST cl_abap_elemdescr( cl_abap_typedescr=>describe_by_name( c_data_element ) ).
          gt_values = lo_type->get_ddic_fixed_values( p_langu = sy-langu ).
        CATCH cx_root.
          CLEAR gt_values.   " metin bulunamazsa kod gosterilir
      ENDTRY.
    ENDIF.

    rv_text = VALUE #( gt_values[ low = iv_status ]-ddtext OPTIONAL ).
    IF rv_text IS INITIAL.
      rv_text = iv_status.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
