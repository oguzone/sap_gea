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
    " Kontroller cagiran raporun dynpro'sundaki CUSTOM CONTAINER alanina
    " (ZONE_IARC_INCOMING 0100 / CC_MAIN) yerlestirilir. Secim ekranina
    " docking ve DEFAULT_SCREEN teknikleri bu sistemde ALV gostermedi
    " (Karar 024 - Karar 015/022/023'un yerine).
    "
    " Kullanim: LOAD( filtre ) -> kayit varsa rapor CALL SCREEN yapar;
    " dynpro PBO'sunda SHOW( repid dynnr ), cikista FREE( ).
    "
    " CL_GUI_TAB_STRIP (gercek native tab kontrolu) kullanilmadi - bu
    " kod tabaninda hic dogrulanmis bir ornegi yok, ekstra risk olurdu.
    " Bunun yerine tek bir "detay" grid'i, mod degistikce (LINE/TAX/
    " TOTAL/NOTE) yok edilip yeniden yaratiliyor (yapisi degistigi icin
    " ayni grid instance'ini yeniden kullanmak yerine bu daha guvenli).

    " Veritabanindan okunan duz satir (SELECT hedefi - ic tablo iceremez).
    TYPES:
      BEGIN OF ty_master_db,
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
      END OF ty_master_db.
    TYPES tt_master_db TYPE STANDARD TABLE OF ty_master_db WITH DEFAULT KEY.

    " Grid satiri = veritabani satiri + hucre renkleri (Durum sutunu).
    TYPES:
      BEGIN OF ty_master.
        INCLUDE TYPE ty_master_db.
    TYPES:
        status_text TYPE c LENGTH 30,     " Durum - Turkce metin (Karar 035)
        t_color     TYPE lvc_t_scol,
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

    CONSTANTS c_container_name TYPE c LENGTH 7 VALUE 'CC_MAIN'.

    " Veriyi okur. Kayit yoksa durum cubugunda uyari verir ve ABAP_FALSE
    " doner (rapor secim ekraninda kalir).
    METHODS load
      IMPORTING
        !is_filter      TYPE ty_filter
      RETURNING
        VALUE(rv_found) TYPE abap_bool.

    " Dynpro PBO'sundan cagrilir; kontroller yalnizca ilk seferde kurulur.
    " IV_REPID/IV_DYNNR rapor baglaminda okunup verilmeli (bu sinifin
    " icinde SY-REPID sinif havuzunu gosterir).
    METHODS show
      IMPORTING
        !iv_repid TYPE sy-repid
        !iv_dynnr TYPE sy-dynnr.

    " Dynpro'dan cikarken tum kontrolleri serbest birakir.
    METHODS free.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mo_container   TYPE REF TO cl_gui_custom_container.
    DATA mo_splitter    TYPE REF TO cl_gui_splitter_container.
    DATA mo_top_grid    TYPE REF TO cl_gui_alv_grid.
    DATA mo_bottom_grid TYPE REF TO cl_gui_alv_grid.
    DATA mo_header_html TYPE REF TO cl_gui_html_viewer.   " ust ALV ozet paneli (HTML)

    DATA mt_master TYPE tt_master.
    DATA ms_filter TYPE ty_filter.

    DATA mv_sel_bukrs TYPE bukrs.
    DATA mv_sel_ettn  TYPE zone_iarc_t006-ettn.
    DATA mv_sel_invid TYPE zone_iarc_t009-invoice_id.
    DATA mv_mode      TYPE char10 VALUE 'LINE'.  " LINE / TAX / TOTAL / NOTE

    DATA mt_detail_line  TYPE STANDARD TABLE OF zone_iarc_t012.
    DATA mt_detail_tax   TYPE STANDARD TABLE OF zone_iarc_t011.
    DATA mt_detail_note  TYPE STANDARD TABLE OF zone_iarc_t010.
    DATA mt_detail_total TYPE tt_kv.

    METHODS refresh_master.
    METHODS status_color
      IMPORTING
        !iv_status    TYPE zone_iarc_t006-status
      RETURNING
        VALUE(rv_col) TYPE lvc_col.

    " Ust grid'i yeniler ve basliktaki kayit sayisini gunceller
    " (baslik yalnizca ilk gosterimde kuruluyordu - hep 0 kalirdi).
    METHODS refresh_top_grid.

    " Ust ALV'nin ustundeki HTML ozet paneli (ZCL_ZONE_IARC_SUMMARY_HTML):
    " solda sirket karti, sagda KPI + grafikler. Liste her yenilendiginde
    " yeniden cizilir (Karar 027).
    METHODS build_header.
    METHODS master_title
      RETURNING VALUE(rv_title) TYPE lvc_title.
    METHODS build_screen
      IMPORTING
        !iv_repid TYPE sy-repid
        !iv_dynnr TYPE sy-dynnr.
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

    " Muhasebe aksiyonlari (ZCL_ZONE_IARC_ACTIONS - Karar 028): secili
    " belge icin Yeniden Isle / Park (BAPI) / Kesinlestir / FB01 /
    " Muhasebe Belgesi.
    METHODS run_action
      IMPORTING
        !iv_ucomm TYPE sy-ucomm.
    METHODS confirm_action
      IMPORTING
        !iv_question        TYPE string
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

    " T010/T011/T012 alanlarinin cogu veri elemani olmadan (dogrudan tip)
    " tanimli - DDIC'ten kolon basligi gelmez. Katalog DDIC'ten uretilir,
    " basliklar COLUMN_TEXT'ten doldurulur, teknik anahtarlar gizlenir.
    METHODS build_detail_fcat
      IMPORTING
        !iv_tabname    TYPE tabname
      RETURNING
        VALUE(rt_fcat) TYPE lvc_t_fcat.
    METHODS column_text
      IMPORTING
        !iv_fieldname  TYPE lvc_fname
      RETURNING
        VALUE(rv_text) TYPE lvc_txtcol.
    METHODS bottom_title
      RETURNING
        VALUE(rv_title) TYPE lvc_title.

    METHODS handle_top_toolbar
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object.
    METHODS handle_top_user_command
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
    METHODS handle_top_double_click
      FOR EVENT double_click OF cl_gui_alv_grid
      IMPORTING e_row.
    METHODS handle_top_menu_button
      FOR EVENT menu_button OF cl_gui_alv_grid
      IMPORTING e_object e_ucomm.

    " Fatura no sutunlarinda tek tik (hotspot) = detay
    METHODS handle_top_hotspot
      FOR EVENT hotspot_click OF cl_gui_alv_grid
      IMPORTING e_row_id.

    " Ust gridde secili satir; secim yoksa imlecin bulundugu satir;
    " liste tek satirsa o satir. Bulunamazsa bos yapi doner.
    METHODS current_master
      RETURNING VALUE(rs_master) TYPE ty_master.
    " Belgenin detayini alt gride getirir.
    METHODS open_detail
      IMPORTING
        !is_master TYPE ty_master.

    METHODS handle_bottom_toolbar
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object.
    METHODS handle_bottom_user_command
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.
ENDCLASS.



CLASS zcl_zone_iarc_grid IMPLEMENTATION.

  METHOD load.
    ms_filter = is_filter.
    refresh_master( ).

    IF mt_master IS INITIAL.
      MESSAGE 'Secim kriterlerine uygun belge yok (ZONE_IARC_T006)' TYPE 'S' DISPLAY LIKE 'W' ##NO_TEXT.
      RETURN.
    ENDIF.
    rv_found = abap_true.
  ENDMETHOD.

  METHOD show.
    IF mo_container IS BOUND.
      RETURN.
    ENDIF.
    build_screen( iv_repid = iv_repid iv_dynnr = iv_dynnr ).
    build_header( ).
    build_top_grid( ).
    " Alt grid bastan (bos) kurulur - Kalemler/Vergi/Dip Toplam/Notlar
    " butonlari gorunur olsun, detayin nereye gelecegi belli olsun.
    rebuild_bottom_grid( ).
  ENDMETHOD.

  METHOD free.
    " Konteyneri serbest birakmak alt kontrolleri (splitter, grid'ler)
    " de serbest birakir.
    IF mo_container IS BOUND.
      mo_container->free( ).
    ENDIF.
    CLEAR: mo_container, mo_splitter, mo_top_grid, mo_bottom_grid, mo_header_html.
  ENDMETHOD.

  METHOD refresh_top_grid.
    mo_top_grid->set_gridtitle( master_title( ) ).
    mo_top_grid->refresh_table_display( ).
    build_header( ).
  ENDMETHOD.

  METHOD build_header.
    TYPES ty_html_line TYPE c LENGTH 255.
    DATA lt_data TYPE STANDARD TABLE OF ty_html_line WITH DEFAULT KEY.
    DATA lv_url  TYPE c LENGTH 250.

    IF mo_header_html IS NOT BOUND.
      mo_header_html = NEW cl_gui_html_viewer( parent = mo_splitter->get_container( row = 1 column = 1 ) ).
    ENDIF.

    DATA(lv_html) = NEW zcl_zone_iarc_summary_html( )->build(
                      CORRESPONDING #( mt_master ) ).

    " HTML kontrolu veriyi 255 karakterlik satir tablosu olarak alir;
    " satirlar tam uzunlukta birlestirilir (satir sonu eklenmez).
    DATA(lv_len) = strlen( lv_html ).
    DATA lv_off   TYPE i.
    DATA lv_chunk TYPE ty_html_line.
    WHILE lv_off < lv_len.
      lv_chunk = substring( val = lv_html off = lv_off len = nmin( val1 = 255 val2 = lv_len - lv_off ) ).
      APPEND lv_chunk TO lt_data.
      lv_off = lv_off + 255.
    ENDWHILE.

    mo_header_html->load_data(
      IMPORTING
        assigned_url = lv_url
      CHANGING
        data_table   = lt_data
      EXCEPTIONS
        OTHERS       = 1 ).
    IF sy-subrc = 0.
      mo_header_html->show_url( url = lv_url ).
    ENDIF.
  ENDMETHOD.

  METHOD master_title.
    rv_title = |Gelen e-Arsiv Belgeleri ({ lines( mt_master ) } kayit)| ##NO_TEXT.
  ENDMETHOD.

  METHOD refresh_master.
    " Tum sirketleri tek seferde cekmemek icin sirket kodu zorunlu.
    IF ms_filter-bukrs IS INITIAL.
      CLEAR mt_master.
      RETURN.
    ENDIF.

    DATA lt_db TYPE tt_master_db.
    SELECT a~provider_doc_id, a~bukrs, a~ettn, a~status, a~supplier_vkn,
           a~lifnr, a~doc_date, a~amount, a~currency, a~fi_belnr, a~miro_belnr,
           b~invoice_id, b~supplier_name, b~inv_type_code, b~profile_id,
           b~payable_amount
      FROM zone_iarc_t006 AS a
      LEFT OUTER JOIN zone_iarc_t009 AS b
        ON b~bukrs = a~bukrs AND b~ettn = a~ettn
      INTO CORRESPONDING FIELDS OF TABLE @lt_db
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

    mt_master = CORRESPONDING #( lt_db ).
    LOOP AT mt_master ASSIGNING FIELD-SYMBOL(<ls_master>).
      <ls_master>-status_text = zcl_zone_iarc_status=>text( <ls_master>-status ).
      <ls_master>-t_color = VALUE #( ( fname = 'STATUS_TEXT'
                                       color = VALUE #( col = status_color( <ls_master>-status ) int = 1 ) ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD status_color.
    " ALV renk kodlari (COL tip grubu).
    rv_col = SWITCH #( iv_status
      WHEN 'EXCEPTION' THEN col_negative    " kirmizi
      WHEN 'REJECTED'  THEN col_group       " turuncu
      WHEN 'MAPPED'    THEN col_total       " sari - muhasebeye hazir
      WHEN 'PARKED'    THEN col_heading     " mavi
      WHEN 'POSTED'    THEN col_positive    " yesil
      ELSE                  col_normal ).   " gri - NEW / PARSED
  ENDMETHOD.

  METHOD build_screen.
    mo_container = NEW cl_gui_custom_container(
      container_name = c_container_name
      repid          = iv_repid
      dynnr          = iv_dynnr ).

    mo_splitter = NEW cl_gui_splitter_container(
      parent  = mo_container
      rows    = 3
      columns = 1 ).
    " 1 = HTML ozet paneli, 2 = belge listesi, 3 = detay (yuzde)
    mo_splitter->set_row_height( id = 1 height = 28 ).
    mo_splitter->set_row_height( id = 2 height = 37 ).
  ENDMETHOD.

  METHOD build_top_grid.
    mo_top_grid = NEW cl_gui_alv_grid( i_parent = mo_splitter->get_container( row = 2 column = 1 ) ).

    SET HANDLER handle_top_toolbar      FOR mo_top_grid.
    SET HANDLER handle_top_user_command FOR mo_top_grid.
    SET HANDLER handle_top_double_click FOR mo_top_grid.
    SET HANDLER handle_top_hotspot      FOR mo_top_grid.
    SET HANDLER handle_top_menu_button  FOR mo_top_grid.

    DATA(ls_layout) = VALUE lvc_s_layo(
      zebra      = abap_true
      sel_mode   = 'A'
      cwidth_opt = abap_true
      ctab_fname = 'T_COLOR'          " Durum hucresi renkleri
      grid_title = master_title( ) ).

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
      ( fieldname = 'PROVIDER_DOC_ID' ref_table = 'ZONE_IARC_T006' ref_field = 'PROVIDER_DOC_ID' coltext = 'Fatura No (Bayt)'
        hotspot = abap_true )
      ( fieldname = 'INVOICE_ID'      ref_table = 'ZONE_IARC_T009' ref_field = 'INVOICE_ID'      coltext = 'UBL Fatura No'
        hotspot = abap_true )
      ( fieldname = 'ETTN'            ref_table = 'ZONE_IARC_T006' ref_field = 'ETTN'            coltext = 'ETTN' )
      ( fieldname = 'BUKRS'           ref_table = 'ZONE_IARC_T006' ref_field = 'BUKRS'           coltext = 'Sirket Kodu' )
      ( fieldname = 'STATUS_TEXT'     coltext = 'Durum' inttype = 'C' intlen = 30 outputlen = 16 )
      ( fieldname = 'STATUS'          ref_table = 'ZONE_IARC_T006' ref_field = 'STATUS'          coltext = 'Durum Kodu'
        no_out = abap_true )
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
    APPEND VALUE stb_button( function = 'REFR' icon = icon_refresh text = 'Yenile'
                             quickinfo = 'Listeyi yenile' ) TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'DELE' icon = icon_delete text = 'Sil'
                             quickinfo = 'Secili belgeleri tum UBL verisiyle sil' ) TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button( function = 'DETL' icon = icon_select_detail text = 'Detay'
                             quickinfo = 'Secili belgenin detayini alt gride getir' ) TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'XML' icon = icon_xml_doc text = 'XML'
                             quickinfo = 'Ham UBL XML goster' ) TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'HTML' icon = icon_display text = 'HTML'
                             quickinfo = 'Okunabilir fatura gorunumu (HTML)' ) TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'HIST' icon = icon_protocol text = 'Gecmis'
                             quickinfo = 'Belgenin islem gecmisi (log)' ) TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button( function = 'REPR' icon = icon_execute_object text = 'Yeniden Isle'
                             quickinfo = 'Tedarikci eslemesi/kural kontrolunu tekrarla' ) TO e_object->mt_toolbar ##NO_TEXT.
    " Muhasebe aksiyonlari tek acilir menude (Karar 030) - icerik
    " HANDLE_TOP_MENU_BUTTON'da, secili belgenin durumuna gore.
    APPEND VALUE stb_button( function = 'ACCT' icon = icon_release text = 'Muhasebelestir' butn_type = 2
                             quickinfo = 'Park (BAPI) / Kesinlestir / FB01 / FB60 / Muhasebe belgesi' ) TO e_object->mt_toolbar ##NO_TEXT.
  ENDMETHOD.

  METHOD handle_top_user_command.
    CASE e_ucomm.
      WHEN 'REFR'.
        refresh_master( ).
        refresh_top_grid( ).
      WHEN 'DELE'.
        delete_selected( ).
      WHEN 'DETL' OR 'XML' OR 'HTML' OR 'HIST'.
        DATA(ls_master) = current_master( ).
        IF ls_master IS INITIAL.
          MESSAGE 'Once listeden bir satir secin' TYPE 'S' DISPLAY LIKE 'W' ##NO_TEXT.
          RETURN.
        ENDIF.
        CASE e_ucomm.
          WHEN 'DETL'.
            open_detail( ls_master ).
          WHEN 'XML'.
            zcl_zone_iarc_doc_view=>show_xml( ls_master-provider_doc_id ).
          WHEN 'HTML'.
            zcl_zone_iarc_doc_view=>show_html( ls_master-provider_doc_id ).
          WHEN 'HIST'.
            NEW zcl_zone_iarc_history( )->show( ls_master-provider_doc_id ).
        ENDCASE.
      WHEN 'REPR' OR 'PARK' OR 'POST' OR 'FB01' OR 'FB60' OR 'SHOW'.
        run_action( e_ucomm ).
    ENDCASE.
  ENDMETHOD.

  METHOD handle_top_menu_button.
    CHECK e_ucomm = 'ACCT'.

    " Secili belge varsa durumuna uymayan secenekler pasif gosterilir.
    DATA(ls_master) = current_master( ).
    DATA(lv_known)  = xsdbool( ls_master IS NOT INITIAL ).
    DATA(lv_ready)  = xsdbool( lv_known = abap_false OR ls_master-status = 'MAPPED' ).
    DATA(lv_parked) = xsdbool( lv_known = abap_false
                               OR ( ls_master-status = 'PARKED' AND ls_master-miro_belnr IS NOT INITIAL ) ).
    DATA(lv_has_doc) = xsdbool( lv_known = abap_false
                                OR ls_master-fi_belnr IS NOT INITIAL OR ls_master-miro_belnr IS NOT INITIAL ).

    e_object->add_function( fcode = 'PARK' icon = icon_incomplete text = 'Park (BAPI - MIRO)'
                            disabled = xsdbool( lv_ready = abap_false ) ) ##NO_TEXT.
    e_object->add_function( fcode = 'POST' icon = icon_system_okay text = 'Kesinlestir (BAPI)'
                            disabled = xsdbool( lv_parked = abap_false ) ) ##NO_TEXT.
    e_object->add_separator( ).
    e_object->add_function( fcode = 'FB60' icon = icon_change text = 'FB60 ile kaydet (ekran)'
                            disabled = xsdbool( lv_ready = abap_false ) ) ##NO_TEXT.
    e_object->add_function( fcode = 'FB01' icon = icon_change text = 'FB01 ile kaydet (ekran)'
                            disabled = xsdbool( lv_ready = abap_false ) ) ##NO_TEXT.
    e_object->add_separator( ).
    e_object->add_function( fcode = 'SHOW' icon = icon_display text = 'Muhasebe belgesini goster'
                            disabled = xsdbool( lv_has_doc = abap_false ) ) ##NO_TEXT.
  ENDMETHOD.

  METHOD run_action.
    DATA(ls_master) = current_master( ).
    IF ls_master IS INITIAL.
      MESSAGE 'Once listeden bir satir secin' TYPE 'S' DISPLAY LIKE 'W' ##NO_TEXT.
      RETURN.
    ENDIF.

    CASE iv_ucomm.
      WHEN 'PARK'.
        IF confirm_action( |{ ls_master-provider_doc_id } icin BAPI ile MIRO park belgesi olusturulsun mu?| ) = abap_false.
          RETURN.
        ENDIF.
      WHEN 'POST'.
        IF confirm_action( |{ ls_master-provider_doc_id } park belgesi kesin kaydedilsin mi?| ) = abap_false.
          RETURN.
        ENDIF.
    ENDCASE.

    DATA(lo_actions) = NEW zcl_zone_iarc_actions( ).
    DATA(ls_outcome) = SWITCH zcl_zone_iarc_actions=>ty_outcome( iv_ucomm
      WHEN 'REPR' THEN lo_actions->reprocess( ls_master-provider_doc_id )
      WHEN 'PARK' THEN lo_actions->park_bapi( ls_master-provider_doc_id )
      WHEN 'POST' THEN lo_actions->post_parked( ls_master-provider_doc_id )
      WHEN 'FB01' THEN lo_actions->post_fb01( ls_master-provider_doc_id )
      WHEN 'FB60' THEN lo_actions->post_fb60( ls_master-provider_doc_id )
      WHEN 'SHOW' THEN lo_actions->display_document( ls_master-provider_doc_id ) ).

    IF iv_ucomm <> 'SHOW'.
      refresh_master( ).
      refresh_top_grid( ).
    ENDIF.

    IF ls_outcome-message IS INITIAL.
      RETURN.
    ELSEIF ls_outcome-success = abap_true.
      MESSAGE ls_outcome-message TYPE 'S'.
    ELSE.
      MESSAGE ls_outcome-message TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

  METHOD confirm_action.
    DATA lv_answer   TYPE c LENGTH 1.
    DATA lv_question TYPE c LENGTH 400.
    lv_question = iv_question.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Muhasebe'
        text_question         = lv_question
        text_button_1         = 'Evet'
        text_button_2         = 'Vazgec'
        default_button        = '2'
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        OTHERS                = 1 ##NO_TEXT.
    rv_confirmed = xsdbool( sy-subrc = 0 AND lv_answer = '1' ).
  ENDMETHOD.

  METHOD current_master.
    DATA lt_rows  TYPE lvc_t_row.
    DATA lv_index TYPE i.

    mo_top_grid->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
    DELETE lt_rows WHERE rowtype IS NOT INITIAL.
    IF lt_rows IS NOT INITIAL.
      lv_index = lt_rows[ 1 ]-index.
    ELSE.
      mo_top_grid->get_current_cell( IMPORTING e_row = lv_index ).
    ENDIF.
    IF lv_index <= 0 AND lines( mt_master ) = 1.
      lv_index = 1.
    ENDIF.

    IF lv_index > 0.
      READ TABLE mt_master INDEX lv_index INTO rs_master.
    ENDIF.
  ENDMETHOD.

  METHOD open_detail.
    IF is_master-ettn IS INITIAL.
      MESSAGE 'Bu belge henuz parse edilmemis (UBL basligi yok)' TYPE 'S' DISPLAY LIKE 'W' ##NO_TEXT.
      RETURN.
    ENDIF.
    mv_sel_bukrs = is_master-bukrs.
    mv_sel_ettn  = is_master-ettn.
    mv_sel_invid = COND #( WHEN is_master-invoice_id IS NOT INITIAL THEN is_master-invoice_id
                           ELSE is_master-provider_doc_id ).
    show_detail( ).
  ENDMETHOD.

  METHOD handle_top_hotspot.
    READ TABLE mt_master INDEX e_row_id-index INTO DATA(ls_master).
    IF sy-subrc = 0.
      open_detail( ls_master ).
    ENDIF.
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
    refresh_top_grid( ).

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
    CLEAR: mv_sel_bukrs, mv_sel_ettn, mv_sel_invid,
           mt_detail_line, mt_detail_tax, mt_detail_note, mt_detail_total.
    IF mo_bottom_grid IS BOUND.
      mo_bottom_grid->refresh_table_display( ).
    ENDIF.
  ENDMETHOD.

  METHOD handle_top_double_click.
    READ TABLE mt_master INDEX e_row-index INTO DATA(ls_master).
    IF sy-subrc = 0.
      open_detail( ls_master ).
    ENDIF.
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

    mo_bottom_grid = NEW cl_gui_alv_grid( i_parent = mo_splitter->get_container( row = 3 column = 1 ) ).
    SET HANDLER handle_bottom_toolbar      FOR mo_bottom_grid.
    SET HANDLER handle_bottom_user_command FOR mo_bottom_grid.

    DATA(ls_layout) = VALUE lvc_s_layo( zebra = abap_true cwidth_opt = abap_true grid_title = bottom_title( ) ).

    CASE mv_mode.
      WHEN 'LINE'.
        DATA(lt_fcat) = build_detail_fcat( 'ZONE_IARC_T012' ).
        mo_bottom_grid->set_table_for_first_display(
          EXPORTING is_layout       = ls_layout
          CHANGING  it_outtab       = mt_detail_line
                    it_fieldcatalog = lt_fcat ).
      WHEN 'TAX'.
        lt_fcat = build_detail_fcat( 'ZONE_IARC_T011' ).
        mo_bottom_grid->set_table_for_first_display(
          EXPORTING is_layout       = ls_layout
          CHANGING  it_outtab       = mt_detail_tax
                    it_fieldcatalog = lt_fcat ).
      WHEN 'NOTE'.
        lt_fcat = build_detail_fcat( 'ZONE_IARC_T010' ).
        mo_bottom_grid->set_table_for_first_display(
          EXPORTING is_layout       = ls_layout
          CHANGING  it_outtab       = mt_detail_note
                    it_fieldcatalog = lt_fcat ).
      WHEN 'TOTAL'.
        DATA(lt_kv_fcat) = build_kv_fcat( ).
        mo_bottom_grid->set_table_for_first_display(
          EXPORTING is_layout       = ls_layout
          CHANGING  it_outtab       = mt_detail_total
                    it_fieldcatalog = lt_kv_fcat ).
    ENDCASE.
  ENDMETHOD.

  METHOD bottom_title.
    DATA(lv_mode_text) = SWITCH string( mv_mode
      WHEN 'LINE'  THEN 'Kalemler'
      WHEN 'TAX'   THEN 'Vergi / KDV Bilgileri'
      WHEN 'NOTE'  THEN 'Notlar'
      WHEN 'TOTAL' THEN 'Dip Toplamlar'
      ELSE '' ) ##NO_TEXT.
    IF mv_sel_invid IS INITIAL.
      rv_title = |{ lv_mode_text } - belge secin| ##NO_TEXT.
    ELSE.
      rv_title = |{ lv_mode_text } - { mv_sel_invid }| ##NO_TEXT.
    ENDIF.
  ENDMETHOD.

  METHOD build_detail_fcat.
    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name       = iv_tabname
      CHANGING
        ct_fieldcat            = rt_fcat
      EXCEPTIONS
        inconsistent_interface = 1
        program_error          = 2
        OTHERS                 = 3.
    IF sy-subrc <> 0.
      CLEAR rt_fcat.
      RETURN.
    ENDIF.

    LOOP AT rt_fcat ASSIGNING FIELD-SYMBOL(<ls_fcat>).
      CASE <ls_fcat>-fieldname.
        WHEN 'MANDT'.
          <ls_fcat>-tech = abap_true.
        WHEN 'BUKRS' OR 'ETTN'.
          <ls_fcat>-no_out = abap_true.   " ust gridde zaten var; layout'tan eklenebilir
      ENDCASE.

      DATA(lv_text) = column_text( <ls_fcat>-fieldname ).
      IF lv_text IS NOT INITIAL.
        <ls_fcat>-coltext   = lv_text.
        <ls_fcat>-reptext   = lv_text.
        <ls_fcat>-scrtext_l = lv_text.
        <ls_fcat>-scrtext_m = lv_text.
        <ls_fcat>-scrtext_s = lv_text.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD column_text.
    rv_text = SWITCH #( iv_fieldname
      WHEN 'BUKRS'          THEN 'Sirket Kodu'
      WHEN 'ETTN'           THEN 'ETTN'
      WHEN 'SEQ_NO'         THEN 'Sira'
      WHEN 'LINE_NO'        THEN 'Kalem No'
      WHEN 'ITEM_NAME'      THEN 'Mal/Hizmet'
      WHEN 'QUANTITY'       THEN 'Miktar'
      WHEN 'UOM_CODE'       THEN 'Birim'
      WHEN 'UNIT_PRICE'     THEN 'Birim Fiyat'
      WHEN 'LINE_AMOUNT'    THEN 'Tutar'
      WHEN 'TAX_AMOUNT'     THEN 'Vergi Tutari'
      WHEN 'TAXABLE_AMOUNT' THEN 'Matrah'
      WHEN 'TAX_PERCENT'    THEN 'Oran (%)'
      WHEN 'TAX_CAT_NAME'   THEN 'Vergi Turu'
      WHEN 'TAX_TYPE_CODE'  THEN 'GIB Vergi Kodu'
      WHEN 'NOTE_TEXT'      THEN 'Not' ) ##NO_TEXT.
  ENDMETHOD.

  METHOD handle_bottom_toolbar.
    " Not: aktif modu vurgulamak icin BUTN_TYPE ile "basili" gorunum
    " denenmedi - STB_BUTTON alan semantigi bu proje icinde dogrulanmis
    " degildi, gereksiz risk olurdu. Aktif mod yerine grid basligindan
    " (grid_title) anlasilir (bkz. REBUILD_BOTTOM_GRID).
    APPEND VALUE stb_button( butn_type = 3 ) TO e_object->mt_toolbar.
    APPEND VALUE stb_button( function = 'LINE'  icon = icon_protocol    text = 'Kalemler' )      TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'TAX'   icon = icon_sum         text = 'Vergi/KDV' )     TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'TOTAL' icon = icon_display     text = 'Dip Toplamlar' ) TO e_object->mt_toolbar ##NO_TEXT.
    APPEND VALUE stb_button( function = 'NOTE'  icon = icon_information text = 'Notlar' )        TO e_object->mt_toolbar ##NO_TEXT.
  ENDMETHOD.

  METHOD handle_bottom_user_command.
    CASE e_ucomm.
      WHEN 'LINE' OR 'TAX' OR 'TOTAL' OR 'NOTE'.
        mv_mode = e_ucomm.
        show_detail( ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
