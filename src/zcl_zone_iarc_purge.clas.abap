CLASS zcl_zone_iarc_purge DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Kuyruga alinmis bir belgeyi tum verisiyle siler: T006 (kuyruk),
    " T007 (ham XML), T009..T016 (UBL normalize tablolari). T008 log
    " kayitlari SILINMEZ (denetim izi) - bunun yerine bir DELETE log
    " satiri eklenir (Karar 021).
    "
    " Muhasebeye yansimis (FI/MIRO belge no dolu ya da PARKED/POSTED)
    " belge silinmez - once SAP tarafinda belge ters kayit/silme yapilmali.
    "
    " COMMIT yapmaz - LUW sinirini cagiran belirler.

    TYPES:
      BEGIN OF ty_result,
        provider_doc_id TYPE zone_iarc_t006-provider_doc_id,
        deleted         TYPE abap_bool,
        message         TYPE string,
      END OF ty_result.
    TYPES tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    METHODS constructor
      IMPORTING
        !io_log TYPE REF TO zcl_zone_iarc_log OPTIONAL.

    METHODS delete
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_result)    TYPE ty_result.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_log TYPE REF TO zcl_zone_iarc_log.

    METHODS is_posted
      IMPORTING
        !is_queue        TYPE zone_iarc_t006
      RETURNING
        VALUE(rv_posted) TYPE abap_bool.

    " UBL tablolari yalnizca bu belgeye aitse silinir: ayni ETTN baska
    " bir belge no ile daha once alinmissa (intake bu durumda ikinci
    " belgeyi EXCEPTION'a ceker) T009.. verisi ILK belgenindir.
    METHODS delete_ubl_data
      IMPORTING
        !is_queue TYPE zone_iarc_t006.
ENDCLASS.



CLASS zcl_zone_iarc_purge IMPLEMENTATION.

  METHOD constructor.
    mo_log = COND #( WHEN io_log IS BOUND THEN io_log ELSE NEW zcl_zone_iarc_log( ) ).
  ENDMETHOD.

  METHOD delete.
    rs_result-provider_doc_id = iv_provider_doc_id.

    SELECT SINGLE * FROM zone_iarc_t006
      WHERE provider_doc_id = @iv_provider_doc_id
      INTO @DATA(ls_queue).
    IF sy-subrc <> 0.
      rs_result-message = |Belge bulunamadi: { iv_provider_doc_id }| ##NO_TEXT.
      RETURN.
    ENDIF.

    IF is_posted( ls_queue ) = abap_true.
      rs_result-message = |{ iv_provider_doc_id }: muhasebe belgesi var ({ ls_queue-status }), silinemez| ##NO_TEXT.
      RETURN.
    ENDIF.

    delete_ubl_data( ls_queue ).
    DELETE FROM zone_iarc_t007 WHERE provider_doc_id = @iv_provider_doc_id.
    DELETE FROM zone_iarc_t006 WHERE provider_doc_id = @iv_provider_doc_id.

    mo_log->write( iv_provider_doc_id = iv_provider_doc_id
                   iv_step            = 'DELETE'
                   iv_status          = 'OK'
                   iv_message         = |Belge silindi (kullanici { sy-uname })| ) ##NO_TEXT.

    rs_result-deleted = abap_true.
    rs_result-message = |{ iv_provider_doc_id }: silindi| ##NO_TEXT.
  ENDMETHOD.

  METHOD is_posted.
    rv_posted = xsdbool( is_queue-fi_belnr   IS NOT INITIAL
                      OR is_queue-miro_belnr IS NOT INITIAL
                      OR is_queue-status     = 'PARKED'
                      OR is_queue-status     = 'POSTED' ).
  ENDMETHOD.

  METHOD delete_ubl_data.
    IF is_queue-ettn IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE provider_doc_id FROM zone_iarc_t009
      WHERE bukrs = @is_queue-bukrs AND ettn = @is_queue-ettn
      INTO @DATA(lv_owner).
    IF sy-subrc <> 0 OR lv_owner <> is_queue-provider_doc_id.
      RETURN.
    ENDIF.

    DELETE FROM zone_iarc_t014 WHERE bukrs = @is_queue-bukrs AND ettn = @is_queue-ettn.
    DELETE FROM zone_iarc_t013 WHERE bukrs = @is_queue-bukrs AND ettn = @is_queue-ettn.
    DELETE FROM zone_iarc_t012 WHERE bukrs = @is_queue-bukrs AND ettn = @is_queue-ettn.
    DELETE FROM zone_iarc_t011 WHERE bukrs = @is_queue-bukrs AND ettn = @is_queue-ettn.
    DELETE FROM zone_iarc_t010 WHERE bukrs = @is_queue-bukrs AND ettn = @is_queue-ettn.
    DELETE FROM zone_iarc_t015 WHERE bukrs = @is_queue-bukrs AND ettn = @is_queue-ettn.
    DELETE FROM zone_iarc_t016 WHERE bukrs = @is_queue-bukrs AND ettn = @is_queue-ettn.
    DELETE FROM zone_iarc_t009 WHERE bukrs = @is_queue-bukrs AND ettn = @is_queue-ettn.
  ENDMETHOD.

ENDCLASS.
