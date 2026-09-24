REPORT zone_iarc_cockpit.

" Gelen e-Arsiv worklist. REUSE_ALV_GRID_DISPLAY kullanilir (CL_GUI_ALV_GRID
" teknolojisi, SALV degil) - kardesi projede manuel CL_GUI_DOCKING_CONTAINER
" baglamasinin CNTL_ERROR verdigi ogrenildi (zonetegra_edeclaration
" program/decision-log.md Karar 007/008); ayni riski almamak icin
" REUSE_ALV_GRID_DISPLAY ve SELECTION-SCREEN FUNCTION KEY (Karar 009
" paterni) tercih edildi - interaktif ALV toolbar/PF-STATUS gerektirmez.

TABLES: sscrfields.

SELECTION-SCREEN FUNCTION KEY 1. " Onayla
SELECTION-SCREEN FUNCTION KEY 2. " Reddet

PARAMETERS: p_bukrs TYPE bukrs OBLIGATORY,
            p_docid TYPE zone_iarc_t006-provider_doc_id.
SELECT-OPTIONS: s_stat FOR zone_iarc_t006-status.

DATA: gt_queue TYPE STANDARD TABLE OF zone_iarc_t006.

INITIALIZATION.
  sscrfields-functxt_01 = 'Onayla'.
  sscrfields-functxt_02 = 'Reddet'.

  " STATUS bir aralik degil, sabit deger listesi (enum) - "DEFAULT x TO y"
  " kullanmak hem yanlis mantik (alfabetik araliktaki her seyi secer) hem
  " de 'PARKED' > 'EXCEPTION' oldugu icin "Alt sinir ust sinirdan buyuk"
  " aktivasyon/generation hatasi verir. Bunun yerine iki ayri EQ degeri
  " programatik olarak eklenir.
  s_stat-sign   = 'I'.
  s_stat-option = 'EQ'.
  s_stat-low    = 'PARKED'.
  APPEND s_stat.
  s_stat-low    = 'EXCEPTION'.
  APPEND s_stat.

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      IF p_docid IS INITIAL.
        MESSAGE 'Once bir belge (provider doc id) girin' TYPE 'S' DISPLAY LIKE 'E'.
      ELSE.
        TRY.
            NEW zcl_zone_iarc_review( )->approve( p_docid ).
            MESSAGE |{ p_docid } onaylandi ve postalandi| TYPE 'S'.
          CATCH zcx_zone_iarc_mapping INTO DATA(lx_err1).
            MESSAGE lx_err1->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        ENDTRY.
      ENDIF.
    WHEN 'FC02'.
      IF p_docid IS INITIAL.
        MESSAGE 'Once bir belge (provider doc id) girin' TYPE 'S' DISPLAY LIKE 'E'.
      ELSE.
        DATA lv_reason TYPE string VALUE 'Kullanici reddi (cockpit)'.
        TRY.
            NEW zcl_zone_iarc_review( )->reject( iv_provider_doc_id = p_docid iv_reason = lv_reason ).
            MESSAGE |{ p_docid } reddedildi| TYPE 'S'.
          CATCH zcx_zone_iarc_mapping INTO DATA(lx_err2).
            MESSAGE lx_err2->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        ENDTRY.
      ENDIF.
  ENDCASE.

START-OF-SELECTION.
  SELECT * FROM zone_iarc_t006
    INTO TABLE @gt_queue
    WHERE bukrs  = @p_bukrs
      AND status IN @s_stat
    ORDER BY received_at DESCENDING.

  IF gt_queue IS INITIAL.
    MESSAGE 'Secim kriterlerine uyan belge yok' TYPE 'S' DISPLAY LIKE 'W'.
  ELSE.
    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      EXPORTING
        i_structure_name = 'ZONE_IARC_T006'
      TABLES
        t_outtab         = gt_queue
      EXCEPTIONS
        program_error    = 1
        OTHERS           = 2.
  ENDIF.
