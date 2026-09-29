CLASS zcl_zone_iarc_history DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Tek belgenin islem gecmisini (ZONE_IARC_T008 log satirlari) popup
    " ALV'de gosterir (Karar 031): zaman (yerel saat), adim, durum
    " (trafik isigi), mesaj, kullanici. En eski kayit ustte.

    TYPES:
      BEGIN OF ty_row,
        status_icon TYPE icon_d,
        log_date    TYPE d,
        log_time    TYPE t,
        step        TYPE zone_iarc_t008-step,
        log_status  TYPE zone_iarc_t008-log_status,
        message     TYPE c LENGTH 255,
        created_by  TYPE syuname,
      END OF ty_row,
      tt_row TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.

    METHODS show
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id.

    METHODS read
      IMPORTING
        !iv_provider_doc_id TYPE zone_iarc_t006-provider_doc_id
      RETURNING
        VALUE(rt_row)       TYPE tt_row.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS field_catalog
      RETURNING
        VALUE(rt_fcat) TYPE lvc_t_fcat.
ENDCLASS.



CLASS zcl_zone_iarc_history IMPLEMENTATION.

  METHOD show.
    DATA(lt_row) = read( iv_provider_doc_id ).
    IF lt_row IS INITIAL.
      MESSAGE 'Bu belge icin log kaydi yok' TYPE 'S' DISPLAY LIKE 'W' ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA(lt_fcat)  = field_catalog( ).
    DATA(ls_layout) = VALUE lvc_s_layo( zebra      = abap_true
                                        cwidth_opt = abap_true
                                        grid_title = |Belge Gecmisi - { iv_provider_doc_id } ({ lines( lt_row ) } kayit)| ) ##NO_TEXT.

    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
      EXPORTING
        is_layout_lvc         = ls_layout
        it_fieldcat_lvc       = lt_fcat
        i_screen_start_column = 10
        i_screen_start_line   = 3
        i_screen_end_column   = 170
        i_screen_end_line     = 25
      TABLES
        t_outtab              = lt_row
      EXCEPTIONS
        OTHERS                = 1.
    IF sy-subrc <> 0.
      MESSAGE 'Gecmis goruntulenemedi' TYPE 'S' DISPLAY LIKE 'E' ##NO_TEXT.
    ENDIF.
  ENDMETHOD.

  METHOD read.
    SELECT step, log_status, message, created_by, created_at
      FROM zone_iarc_t008
      WHERE provider_doc_id = @iv_provider_doc_id
      ORDER BY created_at
      INTO TABLE @DATA(lt_log).

    LOOP AT lt_log INTO DATA(ls_log).
      DATA(ls_row) = VALUE ty_row(
        step        = ls_log-step
        log_status  = ls_log-log_status
        message     = ls_log-message
        created_by  = ls_log-created_by
        status_icon = SWITCH #( ls_log-log_status
                        WHEN 'OK'    THEN icon_led_green
                        WHEN 'ERROR' THEN icon_led_red
                        ELSE              icon_led_yellow ) ).
      CONVERT TIME STAMP ls_log-created_at TIME ZONE sy-zonlo
        INTO DATE ls_row-log_date TIME ls_row-log_time.
      APPEND ls_row TO rt_row.
    ENDLOOP.
  ENDMETHOD.

  METHOD field_catalog.
    rt_fcat = VALUE #(
      ( fieldname = 'STATUS_ICON' coltext = 'Durum'   icon = abap_true inttype = 'C' intlen = 4 outputlen = 5 )
      ( fieldname = 'LOG_DATE'    coltext = 'Tarih'   inttype = 'D' datatype = 'DATS' outputlen = 10 )
      ( fieldname = 'LOG_TIME'    coltext = 'Saat'    inttype = 'T' datatype = 'TIMS' outputlen = 8 )
      ( fieldname = 'STEP'        coltext = 'Adim'    inttype = 'C' intlen = 20  outputlen = 12 )
      ( fieldname = 'LOG_STATUS'  coltext = 'Sonuc'   inttype = 'C' intlen = 10  outputlen = 8 )
      ( fieldname = 'MESSAGE'     coltext = 'Mesaj'   inttype = 'C' intlen = 255 outputlen = 80 )
      ( fieldname = 'CREATED_BY'  coltext = 'Kullanici' ref_table = 'SYST' ref_field = 'UNAME' ) ) ##NO_TEXT.
  ENDMETHOD.

ENDCLASS.
