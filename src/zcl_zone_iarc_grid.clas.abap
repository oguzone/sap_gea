CLASS zcl_zone_iarc_grid DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Gelen e-Arsiv split-screen grid ALV cockpit. Ekran ikiye bolunur:
    " ust = belge listesi (ZONE_IARC_T006+T009), alt = secili belgenin
    " detayi (Kalemler/Vergi/Dip Toplam/Notlar arasinda arac cubugu
    " butonlariyla gecis - "tab" gibi davranir).
    "
    " Ozel dynpro YOK - CL_GUI_DOCKING_CONTAINER dogrudan aktif secim
    " ekranina (sy-repid/sy-dynnr) baglanir. Bu teknik bu ayni musteri
    " hattinda (egdp-abap/ZCL_EGDP_COCKPIT) zaten calisir durumda
    " dogrulanmisti - aynen kopyalandi (bkz. program/decision-log.md
    " Karar 015).
    "
    " CL_GUI_TAB_STRIP (gercek native tab kontrolu) kullanilmadi - bu
    " kod tabaninda hic dogrulanmis bir ornegi yok, ekstra risk olurdu.
    " Bunun yerine tek bir "detay" grid'i, mod degistikce (LINE/TAX/
    " TOTAL/NOTE) yok edilip yeniden yaratiliyor (yapisi degistigi icin
    " ayni grid instance'ini yeniden kullanmak yerine bu daha guvenli).

    TYPES:
      BEGIN OF ty_master,
        provider_doc_id TYPE zone_iarc_t006-provider_doc_id,
        bukrs           TYPE zone_iarc_t006-bukrs,
        ettn            TYPE zone_iarc_t006-ettn,
        status          TYPE zone_iarc_t006-status,
        supplier_vkn    TYPE zone_iarc_t006-supplier_vkn,
        doc_date        TYPE zone_iarc_t006-doc_date,
        amount          TYPE zone_iarc_t006-amount,
        currency        TYPE zone_iarc_t006-currency,
        invoice_id      TYPE zone_iarc_t009-invoice_id,
        supplier_name   TYPE zone_iarc_t009-supplier_name,
      END OF ty_master.
    TYPES tt_master TYPE STANDARD TABLE OF ty_master WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_kv,
        label TYPE char40,
        value TYPE char40,
      END OF ty_kv.
    TYPES tt_kv TYPE STANDARD TABLE OF ty_kv WITH DEFAULT KEY.

    METHODS run
      IMPORTING
        !iv_bukrs  TYPE bukrs  OPTIONAL
        !iv_status TYPE zone_iarc_t006-status OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_cont        TYPE REF TO cl_gui_docking_container.
    DATA mo_splitter    TYPE REF TO cl_gui_splitter_container.
    DATA mo_top_grid    TYPE REF TO cl_gui_alv_grid.
    DATA mo_bottom_grid TYPE REF TO cl_gui_alv_grid.

    DATA mt_master TYPE tt_master.
    DATA mv_bukrs  TYPE bukrs.
    DATA mv_status TYPE zone_iarc_t006-status.

    DATA mv_sel_bukrs TYPE bukrs.
    DATA mv_sel_ettn  TYPE zone_iarc_t006-ettn.
    DATA mv_mode      TYPE char10 VALUE 'LINE'.  " LINE / TAX / TOTAL / NOTE

    DATA mt_detail_line  TYPE STANDARD TABLE OF zone_iarc_t012.
    DATA mt_detail_tax   TYPE STANDARD TABLE OF zone_iarc_t011.
    DATA mt_detail_note  TYPE STANDARD TABLE OF zone_iarc_t010.
    DATA mt_detail_total TYPE tt_kv.

    METHODS refresh_master.
    METHODS build_screen.
    METHODS build_top_grid.
    METHODS show_detail.
    METHODS rebuild_bottom_grid.

    METHODS handle_top_toolbar
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object.
    METHODS handle_top_user_command
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    METHODS handle_top_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row.

    METHODS handle_bottom_toolbar
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object.
    METHODS handle_bottom_user_command
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
ENDCLASS.



CLASS zcl_zone_iarc_grid IMPLEMENTATION.

  METHOD run.
    mv_bukrs  = iv_bukrs.
    mv_status = iv_status.
    refresh_master( ).

    IF mo_cont IS NOT BOUND.
      build_screen( ).
      build_top_grid( ).
    ELSE.
      mo_top_grid->refresh_table_display( ).
    ENDIF.
  ENDMETHOD.

  METHOD refresh_master.
    DATA lr_status TYPE RANGE OF zone_iarc_t006-status.
    IF mv_status IS NOT INITIAL.
      lr_status = VALUE #( ( sign = 'I' option = 'EQ' low = mv_status ) ).
    ENDIF.

    SELECT a~provider_doc_id, a~bukrs, a~ettn, a~status, a~supplier_vkn,
           a~doc_date, a~amount, a~currency,
           b~invoice_id, b~supplier_name
      FROM zone_iarc_t006 AS a
      LEFT OUTER JOIN zone_iarc_t009 AS b
        ON b~bukrs = a~bukrs AND b~ettn = a~ettn
      INTO CORRESPONDING FIELDS OF TABLE @mt_master
      WHERE a~bukrs  = @mv_bukrs
        AND a~status IN @lr_status
      ORDER BY a~received_at DESCENDING.
  ENDMETHOD.

  METHOD build_screen.
    " Docking'i AKTIF secim ekranina baglar - ayri dynpro gerekmez
    " (egdp-abap/ZCL_EGDP_COCKPIT'te dogrulanmis teknik).
    mo_cont = NEW cl_gui_docking_container(
      repid = sy-repid
      dynnr = sy-dynnr
      side  = cl_gui_docking_container=>dock_at_bottom
      ratio = 95 ).

    mo_splitter = NEW cl_gui_splitter_container(
      parent  = mo_cont
      rows    = 2
      columns = 1 ).
    mo_splitter->set_row_height( id = 1 height = 55 ).
  ENDMETHOD.

  METHOD build_top_grid.
    mo_top_grid = NEW cl_gui_alv_grid( i_parent = mo_splitter->get_container( row = 1 column = 1 ) ).

    SET HANDLER handle_top_toolbar      FOR mo_top_grid.
    SET HANDLER handle_top_user_command FOR mo_top_grid.
    SET HANDLER handle_top_double_click FOR mo_top_grid.

    DATA(ls_layout) = VALUE lvc_s_layo(
      zebra      = abap_true
      sel_mode   = 'A'
      cwidth_opt = abap_true
      grid_title = |Gelen e-Arsiv Belgeleri ({ lines( mt_master ) } kayit)| ) ##NO_TEXT.

    mo_top_grid->set_table_for_first_display(
      EXPORTING
        is_layout  = ls_layout
      CHANGING
        it_outtab  = mt_master ).
  ENDMETHOD.

  METHOD handle_top_toolbar.
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button( function = 'REFR' icon = '@42@' text = 'Yenile'
                             quickinfo = 'Listeyi yenile' ) TO e_object->mt_toolbar ##NO_TEXT.
  ENDMETHOD.

  METHOD handle_top_user_command.
    CASE e_ucomm.
      WHEN 'REFR'.
        refresh_master( ).
        mo_top_grid->refresh_table_display( ).
    ENDCASE.
  ENDMETHOD.

  METHOD handle_top_double_click.
    READ TABLE mt_master INDEX e_row-index INTO DATA(ls_master).
    IF sy-subrc <> 0 OR ls_master-ettn IS INITIAL.
      MESSAGE 'Bu belge henuz parse edilmemis (UBL basligi yok)' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    mv_sel_bukrs = ls_master-bukrs.
    mv_sel_ettn  = ls_master-ettn.
    show_detail( ).
  ENDMETHOD.

  METHOD show_detail.
    CASE mv_mode.
      WHEN 'LINE'.
        SELECT * FROM zone_iarc_t012 INTO TABLE @mt_detail_line
          WHERE bukrs = @mv_sel_bukrs AND ettn = @mv_sel_ettn ORDER BY line_no.
      WHEN 'TAX'.
        SELECT * FROM zone_iarc_t011 INTO TABLE @mt_detail_tax
          WHERE bukrs = @mv_sel_bukrs AND ettn = @mv_sel_ettn ORDER BY seq_no.
      WHEN 'NOTE'.
        SELECT * FROM zone_iarc_t010 INTO TABLE @mt_detail_note
          WHERE bukrs = @mv_sel_bukrs AND ettn = @mv_sel_ettn ORDER BY seq_no.
      WHEN 'TOTAL'.
        SELECT SINGLE * FROM zone_iarc_t009 INTO @DATA(ls_hdr)
          WHERE bukrs = @mv_sel_bukrs AND ettn = @mv_sel_ettn.
        CLEAR mt_detail_total.
        IF sy-subrc = 0.
          APPEND VALUE #( label = 'Mal/Hizmet Toplami' value = ls_hdr-line_ext_amount ) TO mt_detail_total.
          APPEND VALUE #( label = 'KDV Haric Tutar'    value = ls_hdr-tax_excl_amount ) TO mt_detail_total.
          APPEND VALUE #( label = 'Toplam Vergi'       value = ls_hdr-tax_amount )      TO mt_detail_total.
          APPEND VALUE #( label = 'KDV Dahil Tutar'    value = ls_hdr-tax_incl_amount ) TO mt_detail_total.
          APPEND VALUE #( label = 'Iskonto Toplami'    value = ls_hdr-allow_total )     TO mt_detail_total.
          APPEND VALUE #( label = 'Ek Ucret Toplami'   value = ls_hdr-charge_total )    TO mt_detail_total.
          APPEND VALUE #( label = 'Odenecek Tutar'     value = ls_hdr-payable_amount )  TO mt_detail_total.
          APPEND VALUE #( label = 'Para Birimi'        value = ls_hdr-doc_currency )    TO mt_detail_total.
        ENDIF.
    ENDCASE.

    rebuild_bottom_grid( ).
  ENDMETHOD.

  METHOD rebuild_bottom_grid.
    " Mod degistikce satir tipi de degistigi icin (T012/T011/T010/KV),
    " ayni grid instance'ini yeniden kullanmak yerine yok edip yeniden
    " yaratmak daha guvenli (SET_TABLE_FOR_FIRST_DISPLAY'i farkli satir
    " tipiyle ikinci kez cagirmanin garantili davranisi belirsiz).
    IF mo_bottom_grid IS BOUND.
      mo_bottom_grid->free( ).
      CLEAR mo_bottom_grid.
    ENDIF.

    mo_bottom_grid = NEW cl_gui_alv_grid( i_parent = mo_splitter->get_container( row = 2 column = 1 ) ).
    SET HANDLER handle_bottom_toolbar      FOR mo_bottom_grid.
    SET HANDLER handle_bottom_user_command FOR mo_bottom_grid.

    DATA(lv_title) = SWITCH string( mv_mode
      WHEN 'LINE'  THEN 'Kalemler'
      WHEN 'TAX'   THEN 'Vergi / KDV Bilgileri'
      WHEN 'NOTE'  THEN 'Notlar'
      WHEN 'TOTAL' THEN 'Dip Toplamlar'
      ELSE '' ) ##NO_TEXT.
    DATA(ls_layout) = VALUE lvc_s_layo( zebra = abap_true cwidth_opt = abap_true grid_title = lv_title ).

    CASE mv_mode.
      WHEN 'LINE'.
        mo_bottom_grid->set_table_for_first_display(
          EXPORTING is_layout = ls_layout i_structure_name = 'ZONE_IARC_T012'
          CHANGING  it_outtab = mt_detail_line ).
      WHEN 'TAX'.
        mo_bottom_grid->set_table_for_first_display(
          EXPORTING is_layout = ls_layout i_structure_name = 'ZONE_IARC_T011'
          CHANGING  it_outtab = mt_detail_tax ).
      WHEN 'NOTE'.
        mo_bottom_grid->set_table_for_first_display(
          EXPORTING is_layout = ls_layout i_structure_name = 'ZONE_IARC_T010'
          CHANGING  it_outtab = mt_detail_note ).
      WHEN 'TOTAL'.
        mo_bottom_grid->set_table_for_first_display(
          EXPORTING is_layout = ls_layout
          CHANGING  it_outtab = mt_detail_total ).
    ENDCASE.
  ENDMETHOD.

  METHOD handle_bottom_toolbar.
    " Not: aktif modu vurgulamak icin BUTN_TYPE ile "basili" gorunum
    " denenmedi - STB_BUTTON alan semantigi bu proje icinde dogrulanmis
    " degildi, gereksiz risk olurdu. Aktif mod yerine grid basligindan
    " (grid_title) anlasilir (bkz. REBUILD_BOTTOM_GRID).
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button( function = 'LINE'  text = 'Kalemler' )      TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'TAX'   text = 'Vergi/KDV' )     TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'TOTAL' text = 'Dip Toplamlar' ) TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'NOTE'  text = 'Notlar' )        TO e_object->mt_toolbar ##NO_TEXT.
  ENDMETHOD.

  METHOD handle_bottom_user_command.
    CASE e_ucomm.
      WHEN 'LINE' OR 'TAX' OR 'TOTAL' OR 'NOTE'.
        mv_mode = e_ucomm.
        show_detail( ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
