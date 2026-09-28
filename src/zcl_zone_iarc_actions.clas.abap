CLASS zcl_zone_iarc_actions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " ZONE_IARC_INCOMING grid'inden tetiklenen tek-belge aksiyonlari
    " (Karar 028). Her aksiyon durum kontrolu yapar, isi ilgili sinifa
    " devreder, ZONE_IARC_T006 + log'u gunceller ve COMMIT eder.
    "
    "   Durum akisi:  EXCEPTION --Yeniden Isle--> MAPPED
    "                 MAPPED --Park (BAPI)--> PARKED --Kesinlestir--> POSTED
    "                 MAPPED --FB01--> POSTED (ya da kullanici park ettiyse PARKED)

    TYPES:
      BEGIN OF ty_outcome,
        success TYPE abap_bool,
        message TYPE string,
      END OF ty_outcome.

    METHODS reprocess
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_outcome)   TYPE ty_outcome.

    METHODS park_bapi
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_outcome)   TYPE ty_outcome.

    METHODS post_parked
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_outcome)   TYPE ty_outcome.

    METHODS post_fb01
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_outcome)   TYPE ty_outcome.

    METHODS post_fb60
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_outcome)   TYPE ty_outcome.

    " Olusan muhasebe belgesini standart ekranda gosterir:
    " MIRO belgesi -> MIR4, FI belgesi -> FB03 (park ise FBV3).
    METHODS display_document
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_outcome)   TYPE ty_outcome.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_log TYPE REF TO zcl_zone_iarc_log.

    METHODS constructor_log
      RETURNING VALUE(ro_log) TYPE REF TO zcl_zone_iarc_log.

    METHODS read_queue
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rs_queue)     TYPE zone_iarc_t006.

    METHODS set_accounting
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
        !iv_status          TYPE zone_iarc_t006-status
        !iv_fi_belnr        TYPE belnr_d OPTIONAL
        !iv_miro_belnr      TYPE belnr_d OPTIONAL
        !iv_gjahr           TYPE gjahr.

    " Hata metnini kuyruga yazar (durum degismez), log + COMMIT.
    METHODS record_error
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
        !iv_step            TYPE zone_iarc_t008-step
        !iv_message         TYPE string
      RETURNING
        VALUE(rs_outcome)   TYPE ty_outcome.

    " FB01/FB60 ortak akisi: durum kontrolu -> oneri -> ekran -> T006.
    METHODS post_via_screen
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
        !iv_tcode           TYPE sy-tcode
      RETURNING
        VALUE(rs_outcome)   TYPE ty_outcome.

    METHODS refuse
      IMPORTING
        !iv_message       TYPE string
      RETURNING
        VALUE(rs_outcome) TYPE ty_outcome.

    METHODS call_display
      IMPORTING
        !iv_tcode         TYPE sy-tcode
      RETURNING
        VALUE(rs_outcome) TYPE ty_outcome.
ENDCLASS.



CLASS zcl_zone_iarc_actions IMPLEMENTATION.

  METHOD constructor_log.
    IF mo_log IS NOT BOUND.
      mo_log = NEW zcl_zone_iarc_log( ).
    ENDIF.
    ro_log = mo_log.
  ENDMETHOD.

  METHOD reprocess.
    DATA(ls_queue) = read_queue( iv_provider_doc_id ).
    IF ls_queue-status = 'PARKED' OR ls_queue-status = 'POSTED'
       OR ls_queue-fi_belnr IS NOT INITIAL OR ls_queue-miro_belnr IS NOT INITIAL.
      rs_outcome = refuse( |Muhasebe belgesi olan belge yeniden islenemez ({ ls_queue-status })| ) ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA(ls_result) = NEW zcl_zone_iarc_intake( constructor_log( ) )->reprocess( iv_provider_doc_id ).
    COMMIT WORK.

    rs_outcome-success = xsdbool( ls_result-status = 'MAPPED' ).
    rs_outcome-message = COND #( WHEN rs_outcome-success = abap_true
                                 THEN |{ iv_provider_doc_id }: muhasebeye hazir (MAPPED)|
                                 ELSE |{ iv_provider_doc_id }: { ls_result-message }| ) ##NO_TEXT.
  ENDMETHOD.

  METHOD park_bapi.
    DATA(ls_queue) = read_queue( iv_provider_doc_id ).
    IF ls_queue-status <> 'MAPPED'.
      rs_outcome = refuse( |Park icin durum MAPPED olmali (su an { ls_queue-status }) - once "Yeniden Isle"| ) ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA(lo_post) = NEW zcl_zone_iarc_post( ).
    TRY.
        DATA(ls_doc) = lo_post->park_invoice( lo_post->build_proposal( iv_provider_doc_id ) ).
      CATCH zcx_zone_iarc_mapping INTO DATA(lx_error).
        rs_outcome = record_error( iv_provider_doc_id = iv_provider_doc_id iv_step = 'PARK'
                                   iv_message = lx_error->mv_detail ).
        RETURN.
    ENDTRY.

    set_accounting( iv_provider_doc_id = iv_provider_doc_id
                    iv_status          = 'PARKED'
                    iv_miro_belnr      = ls_doc-belnr
                    iv_gjahr           = ls_doc-gjahr ).
    rs_outcome-success = abap_true.
    rs_outcome-message = |MIRO park belgesi { ls_doc-belnr }/{ ls_doc-gjahr } olusturuldu| ##NO_TEXT.
  ENDMETHOD.

  METHOD post_parked.
    DATA(ls_queue) = read_queue( iv_provider_doc_id ).
    IF ls_queue-status <> 'PARKED'.
      rs_outcome = refuse( |Kesinlestirme icin durum PARKED olmali (su an { ls_queue-status })| ) ##NO_TEXT.
      RETURN.
    ENDIF.
    IF ls_queue-miro_belnr IS INITIAL.
      rs_outcome = refuse( |FB01'den park edilmis FI belgesi - "Belgeyi Goster" ile FBV3'ten kaydedin| ) ##NO_TEXT.
      RETURN.
    ENDIF.

    TRY.
        NEW zcl_zone_iarc_post( )->post_parked( iv_belnr = ls_queue-miro_belnr iv_gjahr = ls_queue-gjahr ).
      CATCH zcx_zone_iarc_mapping INTO DATA(lx_error).
        rs_outcome = record_error( iv_provider_doc_id = iv_provider_doc_id iv_step = 'POST'
                                   iv_message = lx_error->mv_detail ).
        RETURN.
    ENDTRY.

    set_accounting( iv_provider_doc_id = iv_provider_doc_id
                    iv_status          = 'POSTED'
                    iv_miro_belnr      = ls_queue-miro_belnr
                    iv_gjahr           = ls_queue-gjahr ).
    rs_outcome-success = abap_true.
    rs_outcome-message = |{ ls_queue-miro_belnr }/{ ls_queue-gjahr } kesinlestirildi| ##NO_TEXT.
  ENDMETHOD.

  METHOD post_fb01.
    rs_outcome = post_via_screen( iv_provider_doc_id = iv_provider_doc_id iv_tcode = 'FB01' ).
  ENDMETHOD.

  METHOD post_fb60.
    rs_outcome = post_via_screen( iv_provider_doc_id = iv_provider_doc_id iv_tcode = 'FB60' ).
  ENDMETHOD.

  METHOD post_via_screen.
    DATA(ls_queue) = read_queue( iv_provider_doc_id ).
    IF ls_queue-status <> 'MAPPED'.
      rs_outcome = refuse( |{ iv_tcode } icin durum MAPPED olmali (su an { ls_queue-status }) - once "Yeniden Isle"| ) ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA ls_result TYPE zcl_zone_iarc_bdc=>ty_result.
    TRY.
        DATA(ls_proposal) = NEW zcl_zone_iarc_post( )->build_proposal( iv_provider_doc_id ).
        ls_result = SWITCH #( iv_tcode
          WHEN 'FB60' THEN NEW zcl_zone_iarc_fb60( )->run( ls_proposal )
          ELSE             NEW zcl_zone_iarc_fb01( )->run( ls_proposal ) ).
      CATCH zcx_zone_iarc_mapping INTO DATA(lx_error).
        rs_outcome = record_error( iv_provider_doc_id = iv_provider_doc_id iv_step = CONV #( iv_tcode )
                                   iv_message = lx_error->mv_detail ).
        RETURN.
    ENDTRY.

    IF ls_result-belnr IS INITIAL.
      rs_outcome = refuse( |{ iv_tcode } belgesi kaydedilmedi (islem iptal edildi)| ) ##NO_TEXT.
      RETURN.
    ENDIF.

    set_accounting( iv_provider_doc_id = iv_provider_doc_id
                    iv_status          = COND #( WHEN ls_result-parked = abap_true THEN 'PARKED' ELSE 'POSTED' )
                    iv_fi_belnr        = ls_result-belnr
                    iv_gjahr           = ls_result-gjahr ).
    rs_outcome-success = abap_true.
    rs_outcome-message = |FI belgesi { ls_result-belnr }/{ ls_result-gjahr } | &&
                         COND string( WHEN ls_result-parked = abap_true THEN `park edildi` ELSE `kaydedildi` ) ##NO_TEXT.
  ENDMETHOD.

  METHOD display_document.
    DATA(ls_queue) = read_queue( iv_provider_doc_id ).

    IF ls_queue-miro_belnr IS NOT INITIAL.
      SET PARAMETER ID 'RBN' FIELD ls_queue-miro_belnr.
      SET PARAMETER ID 'GJR' FIELD ls_queue-gjahr.
      rs_outcome = call_display( 'MIR4' ).
    ELSEIF ls_queue-fi_belnr IS NOT INITIAL.
      SET PARAMETER ID 'BLN' FIELD ls_queue-fi_belnr.
      SET PARAMETER ID 'BUK' FIELD ls_queue-bukrs.
      SET PARAMETER ID 'GJR' FIELD ls_queue-gjahr.
      rs_outcome = call_display( COND #( WHEN ls_queue-status = 'PARKED' THEN 'FBV3' ELSE 'FB03' ) ).
    ELSE.
      rs_outcome = refuse( 'Bu belge icin henuz muhasebe belgesi yok' ) ##NO_TEXT.
    ENDIF.
  ENDMETHOD.

  METHOD call_display.
    TRY.
        CALL TRANSACTION iv_tcode WITH AUTHORITY-CHECK AND SKIP FIRST SCREEN.
        rs_outcome-success = abap_true.
      CATCH cx_sy_authorization_error.
        rs_outcome = refuse( |{ iv_tcode } islem yetkiniz yok| ) ##NO_TEXT.
    ENDTRY.
  ENDMETHOD.

  METHOD read_queue.
    SELECT SINGLE * FROM zone_iarc_t006
      WHERE provider_doc_id = @iv_provider_doc_id
      INTO @rs_queue.
  ENDMETHOD.

  METHOD set_accounting.
    DATA lv_now      TYPE zone_iarc_t006-changed_at.
    DATA lv_no_error TYPE zone_iarc_t006-error_text.
    GET TIME STAMP FIELD lv_now.

    UPDATE zone_iarc_t006
      SET status     = @iv_status,
          fi_belnr   = @iv_fi_belnr,
          miro_belnr = @iv_miro_belnr,
          gjahr      = @iv_gjahr,
          error_text = @lv_no_error,
          changed_by = @sy-uname,
          changed_at = @lv_now
      WHERE provider_doc_id = @iv_provider_doc_id.

    constructor_log( )->write( iv_provider_doc_id = iv_provider_doc_id
                               iv_step            = CONV #( iv_status )
                               iv_status          = 'OK'
                               iv_message         = |FI { iv_fi_belnr } MIRO { iv_miro_belnr } / { iv_gjahr }| ) ##NO_TEXT.
    COMMIT WORK.
  ENDMETHOD.

  METHOD record_error.
    DATA lv_error TYPE zone_iarc_t006-error_text.
    lv_error = iv_message.
    UPDATE zone_iarc_t006 SET error_text = @lv_error
      WHERE provider_doc_id = @iv_provider_doc_id.
    constructor_log( )->write( iv_provider_doc_id = iv_provider_doc_id
                               iv_step            = iv_step
                               iv_status          = 'ERROR'
                               iv_message         = CONV #( iv_message ) ).
    COMMIT WORK.

    rs_outcome-message = iv_message.
  ENDMETHOD.

  METHOD refuse.
    rs_outcome-message = iv_message.
  ENDMETHOD.

ENDCLASS.
