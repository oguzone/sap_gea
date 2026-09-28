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
        lifnr           TYPE zone_iarc_t006-lifnr,
        doc_date        TYPE zone_iarc_t006-doc_date,
        amount          TYPE zone_iarc_t006-amount,
        currency        TYPE zone_iarc_t006-currency,
        fi_belnr        TYPE zone_iarc_t006-fi_belnr,
        miro_belnr      TYPE zone_iarc_t006-miro_belnr,
        invoice_id      TYPE zone_iarc_t009-invoice_id,
        supplier_name   TYPE zone_iarc_t009-supplier_name,
        inv_type_code   TYPE zone_iarc_t009-inv_type_code,
        profile_id      TYPE zone_iarc_t009-profile_id,
        payable_amount  TYPE zone_iarc_t009-payable_amount,
      END OF ty_master.
    TYPES tt_master TYPE STANDARD TABLE OF ty_master WITH DEFAULT KEY.

    " Secim ekranindaki SELECT-OPTIONS'larin karsiligi (bos aralik = filtre yok).
    TYPES: tr_bukrs    TYPE RANGE OF zone_iarc_t006-bukrs,
           tr_ettn     TYPE RANGE OF zone_iarc_t006-ettn,
           tr_docid    TYPE RANGE OF zone_iarc_t006-provider_doc_id,
           tr_vkn      TYPE RANGE OF zone_iarc_t006-supplier_vkn,
           tr_lifnr    TYPE RANGE OF zone_iarc_t006-lifnr,
           tr_date     TYPE RANGE OF zone_iarc_t006-doc_date,
           tr_status   TYPE RANGE OF zone_iarc_t006-status,
           tr_currency TYPE RANGE OF zone_iarc_t006-currency,
           tr_amount   TYPE RANGE OF zone_iarc_t006-amount,
           tr_belnr    TYPE RANGE OF zone_iarc_t006-fi_belnr,
           tr_invid    TYPE RANGE OF zone_iarc_t009-invoice_id,
           tr_sname    TYPE RANGE OF zone_iarc_t009-supplier_name,
           tr_invtype  TYPE RANGE OF zone_iarc_t009-inv_type_code,
           tr_profile  TYPE RANGE OF zone_iarc_t009-profile_id.

    TYPES:
      BEGIN OF ty_filter,
        bukrs    TYPE tr_bukrs,
        ettn     TYPE tr_ettn,
        docid    TYPE tr_docid,
        vkn      TYPE tr_vkn,
        lifnr    TYPE tr_lifnr,
        docdate  TYPE tr_date,
        status   TYPE tr_status,
        currency TYPE tr_currency,
        amount   TYPE tr_amount,
        belnr    TYPE tr_belnr,
        invid    TYPE tr_invid,
        sname    TYPE tr_sname,
        invtype  TYPE tr_invtype,
        profile  TYPE tr_profile,
      END OF ty_filter.

    TYPES:
      BEGIN OF ty_kv,
        label TYPE char40,
        value TYPE char40,
      END OF ty_kv.
    TYPES tt_kv TYPE STANDARD TABLE OF ty_kv WITH DEFAULT KEY.

    METHODS run
      IMPORTING
        !is_filter TYPE ty_filter.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_cont        TYPE REF TO cl_gui_docking_container.
    DATA mo_splitter    TYPE REF TO cl_gui_splitter_container.
    DATA mo_top_grid    TYPE REF TO cl_gui_alv_grid.
    DATA mo_bottom_grid TYPE REF TO cl_gui_alv_grid.

    DATA mt_master TYPE tt_master.
    DATA ms_filter TYPE ty_filter.

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

    " Ust gridde secili belgeleri onay sonrasi ZCL_ZONE_IARC_PURGE ile
    " siler (Karar 021).
    METHODS delete_selected.
    METHODS confirm_delete
      IMPORTING
        !iv_count          TYPE i
      RETURNING
        VALUE(rv_confirmed) TYPE abap_bool.
    METHODS clear_detail.

    " Yerel tipli tablolar (ty_master, ty_kv) icin DDIC yapisi yok -
    " I_STRUCTURE_NAME verilemedigi icin alan katalogu elle kurulur,
    " yoksa CL_GUI_ALV_GRID "alan katalogu bulunamadi" hatasi verir.
    METHODS build_master_fcat
      RETURNING VALUE(rt_fcat) TYPE lvc_t_fcat.
    METHODS build_kv_fcat
      RETURNING VALUE(rt_fcat) TYPE lvc_t_fcat.

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
    ms_filter = is_filter.
    refresh_master( ).

    IF mo_cont IS NOT BOUND.
      build_screen( ).
      build_top_grid( ).
    ELSE.
      mo_top_grid->refresh_table_display( ).
    ENDIF.
  ENDMETHOD.

  METHOD refresh_master.
    " Secim ekrani ilk acildiginda (sirket kodu henuz girilmemisken)
    " tum sirketleri cekmemek icin: sirket kodu yoksa liste bos gelir.
    IF ms_filter-bukrs IS INITIAL.
      CLEAR mt_master.
      RETURN.
    ENDIF.

    SELECT a~provider_doc_id, a~bukrs, a~ettn, a~status, a~supplier_vkn,
           a~lifnr, a~doc_date, a~amount, a~currency, a~fi_belnr, a~miro_belnr,
           b~invoice_id, b~supplier_name, b~inv_type_code, b~profile_id,
           b~payable_amount
      FROM zone_iarc_t006 AS a
      LEFT OUTER JOIN zone_iarc_t009 AS b
        ON b~bukrs = a~bukrs AND b~ettn = a~ettn
      INTO CORRESPONDING FIELDS OF TABLE @mt_master
      WHERE a~bukrs           IN @ms_filter-bukrs
        AND a~ettn            IN @ms_filter-ettn
        AND a~provider_doc_id IN @ms_filter-docid
        AND a~supplier_vkn    IN @ms_filter-vkn
        AND a~lifnr           IN @ms_filter-lifnr
        AND a~doc_date        IN @ms_filter-docdate
        AND a~status          IN @ms_filter-status
        AND a~currency        IN @ms_filter-currency
        AND a~amount          IN @ms_filter-amount
        AND a~fi_belnr        IN @ms_filter-belnr
        AND b~invoice_id      IN @ms_filter-invid
        AND b~supplier_name   IN @ms_filter-sname
        AND b~inv_type_code   IN @ms_filter-invtype
        AND b~profile_id      IN @ms_filter-profile
      ORDER BY a~received_at DESCENDING.
  ENDMETHOD.

  METHOD build_screen.
    " Docking'i AKTIF secim ekranina baglar - ayri dynpro gerekmez
    " (egdp-abap/ZCL_EGDP_COCKPIT'te dogrulanmis teknik).
    mo_cont = NEW cl_gui_docking_container(
      repid = sy-repid
      dynnr = sy-dynnr
      side  = cl_gui_docking_container=>dock_at_bottom
      ratio = 60 ).  " secim ekraninin ust kismi (14 kriter) gorunur kalsin

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

    DATA(lt_fcat) = build_master_fcat( ).

    mo_top_grid->set_table_for_first_display(
      EXPORTING
        is_layout       = ls_layout
      CHANGING
        it_outtab       = mt_master
        it_fieldcatalog = lt_fcat ).
  ENDMETHOD.

  METHOD build_master_fcat.
    " REF_TABLE/REF_FIELD -> tip/uzunluk DDIC'ten gelir; COLTEXT -> baslik.
    rt_fcat = VALUE #(
      ( fieldname = 'PROVIDER_DOC_ID' ref_table = 'ZONE_IARC_T006' ref_field = 'PROVIDER_DOC_ID' coltext = 'Fatura No (Bayt)' )
      ( fieldname = 'INVOICE_ID'      ref_table = 'ZONE_IARC_T009' ref_field = 'INVOICE_ID'      coltext = 'UBL Fatura No' )
      ( fieldname = 'ETTN'            ref_table = 'ZONE_IARC_T006' ref_field = 'ETTN'            coltext = 'ETTN' )
      ( fieldname = 'BUKRS'           ref_table = 'ZONE_IARC_T006' ref_field = 'BUKRS'           coltext = 'Sirket Kodu' )
      ( fieldname = 'STATUS'          ref_table = 'ZONE_IARC_T006' ref_field = 'STATUS'          coltext = 'Durum' )
      ( fieldname = 'SUPPLIER_VKN'    ref_table = 'ZONE_IARC_T006' ref_field = 'SUPPLIER_VKN'    coltext = 'Satici VKN/TCKN' )
      ( fieldname = 'SUPPLIER_NAME'   ref_table = 'ZONE_IARC_T009' ref_field = 'SUPPLIER_NAME'   coltext = 'Satici Adi' )
      ( fieldname = 'DOC_DATE'        ref_table = 'ZONE_IARC_T006' ref_field = 'DOC_DATE'        coltext = 'Fatura Tarihi' )
      ( fieldname = 'AMOUNT'          ref_table = 'ZONE_IARC_T006' ref_field = 'AMOUNT'          coltext = 'Tutar'
        cfieldname = 'CURRENCY' )
      ( fieldname = 'CURRENCY'        ref_table = 'ZONE_IARC_T006' ref_field = 'CURRENCY'        coltext = 'Para Birimi' )
      ( fieldname = 'PAYABLE_AMOUNT'  ref_table = 'ZONE_IARC_T009' ref_field = 'PAYABLE_AMOUNT'  coltext = 'Odenecek Tutar'
        cfieldname = 'CURRENCY' )
      ( fieldname = 'LIFNR'           ref_table = 'ZONE_IARC_T006' ref_field = 'LIFNR'           coltext = 'Cari No' )
      ( fieldname = 'INV_TYPE_CODE'   ref_table = 'ZONE_IARC_T009' ref_field = 'INV_TYPE_CODE'   coltext = 'Fatura Tipi' )
      ( fieldname = 'PROFILE_ID'      ref_table = 'ZONE_IARC_T009' ref_field = 'PROFILE_ID'      coltext = 'Senaryo' )
      ( fieldname = 'FI_BELNR'        ref_table = 'ZONE_IARC_T006' ref_field = 'FI_BELNR'        coltext = 'FI Belge No' )
      ( fieldname = 'MIRO_BELNR'      ref_table = 'ZONE_IARC_T006' ref_field = 'MIRO_BELNR'      coltext = 'MIRO Belge No' ) ) ##NO_TEXT.
  ENDMETHOD.

  METHOD build_kv_fcat.
    rt_fcat = VALUE #(
      ( fieldname = 'LABEL' coltext = 'Alan'  inttype = 'C' intlen = 40 outputlen = 30 )
      ( fieldname = 'VALUE' coltext = 'Deger' inttype = 'C' intlen = 40 outputlen = 25 ) ) ##NO_TEXT.
  ENDMETHOD.

  METHOD handle_top_toolbar.
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button( function = 'REFR' icon = '@42@' text = 'Yenile'
                             quickinfo = 'Listeyi yenile' ) TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'DELE' icon = '@11@' text = 'Sil'
                             quickinfo = 'Secili belgeleri tum UBL verisiyle sil' ) TO e_object->mt_toolbar ##NO_TEXT.
  ENDMETHOD.

  METHOD handle_top_user_command.
    CASE e_ucomm.
      WHEN 'REFR'.
        refresh_master( ).
        mo_top_grid->refresh_table_display( ).
      WHEN 'DELE'.
        delete_selected( ).
    ENDCASE.
  ENDMETHOD.

  METHOD delete_selected.
    DATA lt_rows TYPE lvc_t_row.
    mo_top_grid->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
    DELETE lt_rows WHERE rowtype IS NOT INITIAL.   " ara toplam/toplam satirlari
    IF lt_rows IS INITIAL.
      MESSAGE 'Silmek icin en az bir satir secin' TYPE 'S' DISPLAY LIKE 'W' ##NO_TEXT.
      RETURN.
    ENDIF.

    IF confirm_delete( lines( lt_rows ) ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lo_purge) = NEW zcl_zone_iarc_purge( ).
    DATA lv_deleted TYPE i.
    DATA lv_refused TYPE string.
    LOOP AT lt_rows INTO DATA(ls_row).
      READ TABLE mt_master INDEX ls_row-index INTO DATA(ls_master).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(ls_result) = lo_purge->delete( ls_master-provider_doc_id ).
      IF ls_result-deleted = abap_true.
        lv_deleted = lv_deleted + 1.
      ELSEIF lv_refused IS INITIAL.
        lv_refused = ls_result-message.   " ilk red nedeni kullaniciya gosterilir
      ENDIF.
    ENDLOOP.
    COMMIT WORK.

    clear_detail( ).
    refresh_master( ).
    mo_top_grid->refresh_table_display( ).

    DATA lv_msg TYPE string.
    IF lv_refused IS INITIAL.
      lv_msg = |{ lv_deleted } belge silindi| ##NO_TEXT.
      MESSAGE lv_msg TYPE 'S'.
    ELSE.
      lv_msg = |{ lv_deleted } belge silindi, { lines( lt_rows ) - lv_deleted } silinemedi. { lv_refused }| ##NO_TEXT.
      MESSAGE lv_msg TYPE 'I'.
    ENDIF.
  ENDMETHOD.

  METHOD confirm_delete.
    DATA lv_answer   TYPE c LENGTH 1.
    DATA lv_question TYPE c LENGTH 400.
    lv_question = |{ iv_count } belge; kuyruk, ham XML ve tum UBL tablolarindan silinecek. Emin misiniz?| ##NO_TEXT.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Belge Silme'
        text_question         = lv_question
        text_button_1         = 'Sil'
        text_button_2         = 'Vazgec'
        default_button        = '2'
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        OTHERS                = 1 ##NO_TEXT.
    rv_confirmed = xsdbool( sy-subrc = 0 AND lv_answer = '1' ).
  ENDMETHOD.

  METHOD clear_detail.
    " Silinen belgenin detayi alt gridde kalmasin.
    CLEAR: mv_sel_bukrs, mv_sel_ettn,
           mt_detail_line, mt_detail_tax, mt_detail_note, mt_detail_total.
    IF mo_bottom_grid IS BOUND.
      mo_bottom_grid->refresh_table_display( ).
    ENDIF.
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
        DATA(lt_kv_fcat) = build_kv_fcat( ).
        mo_bottom_grid->set_table_for_first_display(
          EXPORTING is_layout       = ls_layout
          CHANGING  it_outtab       = mt_detail_total
                    it_fieldcatalog = lt_kv_fcat ).
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
