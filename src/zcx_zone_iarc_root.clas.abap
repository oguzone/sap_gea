CLASS zcx_zone_iarc_root DEFINITION
  PUBLIC
  INHERITING FROM cx_dynamic_check
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_dyn_msg.
    INTERFACES if_t100_message.

    CONSTANTS:
      BEGIN OF generic,
        msgid TYPE symsgid VALUE 'ZONE_IARC_MC01',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'MV_ERROR_CODE',
        attr2 TYPE scx_attrname VALUE 'MV_DETAIL',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF generic.

    DATA mv_error_code TYPE string READ-ONLY.
    DATA mv_detail     TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        !textid        LIKE if_t100_message=>t100key OPTIONAL
        !previous      LIKE previous OPTIONAL
        !iv_error_code TYPE string OPTIONAL
        !iv_detail     TYPE string OPTIONAL.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_zone_iarc_root IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->mv_error_code = iv_error_code.
    me->mv_detail     = iv_detail.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = generic.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
