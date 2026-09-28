*&---------------------------------------------------------------------*
*& Include ZONE_IARC_UPLOAD_CLS
*&---------------------------------------------------------------------*
*& LCX_UPLOAD  : Program ici hata (dosya okuma vb.)
*& LCL_FILE    : Yerel dosya secimi (F4) ve okuma (SAP GUI gerekir)
*& LCL_CHECKER : Parse edilmis UBL uzerinde on kontroller
*& LCL_OUTPUT  : Sonuc listesi (klasik liste - WRITE)
*& LCL_APP     : Akis - oku > parse > kontrol > (test degilse) aktar
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* LCX_UPLOAD
*----------------------------------------------------------------------*
CLASS lcx_upload DEFINITION INHERITING FROM cx_static_check FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        !iv_text TYPE string.
    METHODS get_text REDEFINITION.
  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.

CLASS lcx_upload IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    mv_text = iv_text.
  ENDMETHOD.

  METHOD get_text.
    result = mv_text.
  ENDMETHOD.
ENDCLASS.


*----------------------------------------------------------------------*
* LCL_FILE
*----------------------------------------------------------------------*
CLASS lcl_file DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS f4
      CHANGING
        !cv_path TYPE rlgrap-filename.

    CLASS-METHODS read
      IMPORTING
        !iv_path      TYPE string
      RETURNING
        VALUE(rv_xml) TYPE xstring
      RAISING
        lcx_upload.
ENDCLASS.

CLASS lcl_file IMPLEMENTATION.
  METHOD f4.
    DATA lt_files TYPE filetable.
    DATA lv_rc    TYPE i.

    cl_gui_frontend_services=>file_open_dialog(
      EXPORTING
        window_title = 'UBL XML dosyasi secin'
        file_filter  = 'XML dosyalari (*.xml)|*.xml|Tum dosyalar (*.*)|*.*'
      CHANGING
        file_table   = lt_files
        rc           = lv_rc
      EXCEPTIONS
        OTHERS       = 1 ) ##NO_TEXT.
    IF sy-subrc = 0 AND lv_rc > 0.
      cv_path = lt_files[ 1 ]-filename.
    ENDIF.
  ENDMETHOD.

  METHOD read.
    " Ikili (BIN) okunur - XML'in kendi encoding bildirimi (UTF-8) parser'a
    " oldugu gibi gitsin, SAP GUI kod sayfasi donusumu araya girmesin.
    DATA lt_bin TYPE solix_tab.
    DATA lv_len TYPE i.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename   = iv_path
        filetype   = 'BIN'
      IMPORTING
        filelength = lv_len
      CHANGING
        data_tab   = lt_bin
      EXCEPTIONS
        OTHERS     = 1 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcx_upload
        EXPORTING iv_text = |Dosya okunamadi: { iv_path }| ##NO_TEXT.
    ENDIF.
    IF lv_len = 0.
      RAISE EXCEPTION TYPE lcx_upload
        EXPORTING iv_text = |Dosya bos: { iv_path }| ##NO_TEXT.
    ENDIF.

    rv_xml = cl_bcs_convert=>solix_to_xstring( it_solix = lt_bin iv_size = lv_len ).
  ENDMETHOD.
ENDCLASS.


*----------------------------------------------------------------------*
* LCL_CHECKER
*----------------------------------------------------------------------*
CLASS lcl_checker DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_check,
        severity TYPE c LENGTH 1,   " gc_severity-error/warning/info
        text     TYPE string,
      END OF ty_check.
    TYPES tt_check TYPE STANDARD TABLE OF ty_check WITH EMPTY KEY.

    METHODS constructor
      IMPORTING
        !iv_bukrs  TYPE bukrs
        !iv_docid  TYPE zone_iarc_t006-provider_doc_id
        !is_header TYPE zif_zone_iarc_types=>ty_header.

    METHODS run
      RETURNING
        VALUE(rt_check) TYPE tt_check.

    CLASS-METHODS has_error
      IMPORTING
        !it_check       TYPE tt_check
      RETURNING
        VALUE(rv_error) TYPE abap_bool.

  PRIVATE SECTION.
    CONSTANTS c_tolerance     TYPE decfloat34 VALUE '0.01'.
    CONSTANTS c_earsiv_profil TYPE string VALUE 'EARSIVFATURA'.

    DATA mv_bukrs  TYPE bukrs.
    DATA mv_docid  TYPE zone_iarc_t006-provider_doc_id.
    DATA ms_header TYPE zif_zone_iarc_types=>ty_header.
    DATA mt_check  TYPE tt_check.

    METHODS add
      IMPORTING
        !iv_severity TYPE c
        !iv_text     TYPE string.

    METHODS check_mandatory.
    METHODS check_receiver.
    METHODS check_totals.
    METHODS check_duplicates.
    METHODS check_supplier_mapping.

    CLASS-METHODS differs
      IMPORTING
        !iv_a             TYPE decfloat34
        !iv_b             TYPE decfloat34
      RETURNING
        VALUE(rv_differs) TYPE abap_bool.
ENDCLASS.

CLASS lcl_checker IMPLEMENTATION.
  METHOD constructor.
    mv_bukrs  = iv_bukrs.
    mv_docid  = iv_docid.
    ms_header = is_header.
  ENDMETHOD.

  METHOD run.
    CLEAR mt_check.
    check_mandatory( ).
    check_receiver( ).
    check_totals( ).
    check_duplicates( ).
    check_supplier_mapping( ).
    rt_check = mt_check.
  ENDMETHOD.

  METHOD has_error.
    rv_error = xsdbool( line_exists( it_check[ severity = gc_severity-error ] ) ).
  ENDMETHOD.

  METHOD add.
    APPEND VALUE #( severity = iv_severity text = iv_text ) TO mt_check.
  ENDMETHOD.

  METHOD check_mandatory.
    IF ms_header-uuid IS INITIAL.
      add( iv_severity = gc_severity-error iv_text = 'ETTN (cbc:UUID) bos' ) ##NO_TEXT.
    ELSEIF strlen( ms_header-uuid ) <> 36.
      add( iv_severity = gc_severity-warning
           iv_text     = |ETTN 36 karakter degil: { ms_header-uuid }| ) ##NO_TEXT.
    ENDIF.

    IF ms_header-invoice_id IS INITIAL.
      add( iv_severity = gc_severity-error iv_text = 'Fatura No (cbc:ID) bos' ) ##NO_TEXT.
    ENDIF.
    IF mv_docid IS INITIAL.
      add( iv_severity = gc_severity-error iv_text = 'Belge no belirlenemedi (parametre ve cbc:ID bos)' ) ##NO_TEXT.
    ENDIF.
    IF ms_header-issue_date IS INITIAL.
      add( iv_severity = gc_severity-error iv_text = 'Fatura tarihi (cbc:IssueDate) bos' ) ##NO_TEXT.
    ENDIF.
    IF ms_header-currency IS INITIAL.
      add( iv_severity = gc_severity-warning iv_text = 'Para birimi (DocumentCurrencyCode) bos' ) ##NO_TEXT.
    ENDIF.

    IF ms_header-supplier_vkn IS INITIAL.
      add( iv_severity = gc_severity-error iv_text = 'Gonderici VKN/TCKN bos' ) ##NO_TEXT.
    ELSEIF ms_header-supplier_vkn CN '0123456789'
        OR NOT ( strlen( ms_header-supplier_vkn ) = 10 OR strlen( ms_header-supplier_vkn ) = 11 ).
      add( iv_severity = gc_severity-warning
           iv_text     = |Gonderici VKN/TCKN 10/11 haneli sayi degil: { ms_header-supplier_vkn }| ) ##NO_TEXT.
    ENDIF.

    IF ms_header-profile_id <> c_earsiv_profil.
      add( iv_severity = gc_severity-warning
           iv_text     = |Senaryo { c_earsiv_profil } degil: { ms_header-profile_id }| ) ##NO_TEXT.
    ENDIF.

    IF ms_header-line IS INITIAL.
      add( iv_severity = gc_severity-warning iv_text = 'Belgede kalem (cac:InvoiceLine) yok' ) ##NO_TEXT.
    ENDIF.
  ENDMETHOD.

  METHOD check_receiver.
    " Gelen belgede alici = bizim sirketimiz olmali (T001-COMP_TAX_NO).
    SELECT SINGLE comp_tax_no FROM zone_iarc_t001
      WHERE bukrs = @mv_bukrs
      INTO @DATA(lv_comp_tax_no).
    IF sy-subrc <> 0.
      add( iv_severity = gc_severity-warning
           iv_text     = |ZONE_IARC_T001'de { mv_bukrs } kaydi yok - alici VKN kontrol edilemedi| ) ##NO_TEXT.
    ELSEIF lv_comp_tax_no <> ms_header-customer_vkn.
      add( iv_severity = gc_severity-warning
           iv_text     = |Alici VKN ({ ms_header-customer_vkn }) sirket VKN'si ({ lv_comp_tax_no }) ile uyusmuyor| ) ##NO_TEXT.
    ENDIF.
  ENDMETHOD.

  METHOD check_totals.
    DATA(lv_line_sum) = REDUCE decfloat34( INIT s = CONV decfloat34( 0 )
                                           FOR ls_line IN ms_header-line
                                           NEXT s = s + ls_line-line_amount ).
    DATA(lv_tax_sum)  = REDUCE decfloat34( INIT s = CONV decfloat34( 0 )
                                           FOR ls_tax IN ms_header-tax_subtotal
                                           NEXT s = s + ls_tax-tax_amount ).

    IF ms_header-line IS NOT INITIAL
       AND differs( iv_a = lv_line_sum iv_b = CONV #( ms_header-line_ext_amount ) ) = abap_true.
      add( iv_severity = gc_severity-warning
           iv_text     = |Kalem toplami ({ lv_line_sum }) <> LineExtensionAmount ({ ms_header-line_ext_amount })| ) ##NO_TEXT.
    ENDIF.

    IF ms_header-tax_subtotal IS NOT INITIAL
       AND differs( iv_a = lv_tax_sum iv_b = CONV #( ms_header-tax_amount ) ) = abap_true.
      add( iv_severity = gc_severity-warning
           iv_text     = |Vergi alt toplamlari ({ lv_tax_sum }) <> TaxTotal/TaxAmount ({ ms_header-tax_amount })| ) ##NO_TEXT.
    ENDIF.

    IF differs( iv_a = CONV #( ms_header-tax_excl_amount + ms_header-tax_amount )
                iv_b = CONV #( ms_header-tax_incl_amount ) ) = abap_true.
      add( iv_severity = gc_severity-warning
           iv_text     = |Vergi haric + vergi <> Vergi dahil ({ ms_header-tax_incl_amount })| ) ##NO_TEXT.
    ENDIF.

    IF ms_header-payable_amount <= 0.
      add( iv_severity = gc_severity-warning iv_text = 'Odenecek tutar sifir veya negatif' ) ##NO_TEXT.
    ENDIF.
  ENDMETHOD.

  METHOD check_duplicates.
    IF mv_docid IS NOT INITIAL
       AND NEW zcl_zone_iarc_parser( )->is_duplicate( mv_docid ) = abap_true.
      add( iv_severity = gc_severity-error
           iv_text     = |Belge no { mv_docid } daha once aktarilmis (ZONE_IARC_T006)| ) ##NO_TEXT.
    ENDIF.

    IF ms_header-uuid IS NOT INITIAL.
      SELECT SINGLE @abap_true FROM zone_iarc_t009
        WHERE bukrs = @mv_bukrs AND ettn = @ms_header-uuid
        INTO @DATA(lv_ettn_exists).
      IF lv_ettn_exists = abap_true.
        add( iv_severity = gc_severity-error
             iv_text     = |ETTN { ms_header-uuid } bu sirket kodunda daha once aktarilmis| ) ##NO_TEXT.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD check_supplier_mapping.
    IF ms_header-supplier_vkn IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_lifnr) = NEW zcl_zone_iarc_resolver( )->resolve( CONV #( ms_header-supplier_vkn ) ).
    IF lv_lifnr IS INITIAL.
      add( iv_severity = gc_severity-warning
           iv_text     = |Tedarikci bulunamadi (VKN { ms_header-supplier_vkn }) - belge EXCEPTION'a duser| ) ##NO_TEXT.
    ELSE.
      add( iv_severity = gc_severity-info
           iv_text     = |Tedarikci eslesti: { lv_lifnr ALPHA = OUT }| ) ##NO_TEXT.
    ENDIF.
  ENDMETHOD.

  METHOD differs.
    rv_differs = xsdbool( abs( iv_a - iv_b ) > c_tolerance ).
  ENDMETHOD.
ENDCLASS.


*----------------------------------------------------------------------*
* LCL_OUTPUT
*----------------------------------------------------------------------*
CLASS lcl_output DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS header
      IMPORTING
        !iv_file   TYPE csequence
        !iv_docid  TYPE zone_iarc_t006-provider_doc_id
        !is_header TYPE zif_zone_iarc_types=>ty_header.

    METHODS checks
      IMPORTING
        !it_check TYPE lcl_checker=>tt_check.

    METHODS item_list
      IMPORTING
        !is_header TYPE zif_zone_iarc_types=>ty_header.

    METHODS test_mode_note
      IMPORTING
        !iv_has_error TYPE abap_bool.

    METHODS blocked_note.

    METHODS parse_error
      IMPORTING
        !iv_text TYPE string.

    METHODS result
      IMPORTING
        !is_result TYPE zcl_zone_iarc_intake=>ty_result
        !iv_docid  TYPE zone_iarc_t006-provider_doc_id.

  PRIVATE SECTION.
    METHODS section
      IMPORTING
        !iv_title TYPE string.

    METHODS pair
      IMPORTING
        !iv_label TYPE string
        !iv_value TYPE string.
ENDCLASS.

CLASS lcl_output IMPLEMENTATION.
  METHOD section.
    SKIP.
    FORMAT COLOR COL_HEADING INTENSIFIED ON.
    WRITE: / iv_title.
    FORMAT COLOR OFF INTENSIFIED OFF.
    ULINE.
  ENDMETHOD.

  METHOD pair.
    WRITE: / iv_label, 30 iv_value.
  ENDMETHOD.

  METHOD header.
    section( 'Belge' ) ##NO_TEXT.
    pair( iv_label = 'Dosya'          iv_value = CONV #( iv_file ) ) ##NO_TEXT.
    pair( iv_label = 'Belge No (kuyruk)' iv_value = CONV #( iv_docid ) ) ##NO_TEXT.
    pair( iv_label = 'Fatura No'      iv_value = is_header-invoice_id ) ##NO_TEXT.
    pair( iv_label = 'ETTN'           iv_value = is_header-uuid ) ##NO_TEXT.
    pair( iv_label = 'Tarih / Saat'   iv_value = |{ is_header-issue_date DATE = USER } { is_header-issue_time TIME = USER }| ) ##NO_TEXT.
    pair( iv_label = 'Fatura Tipi'    iv_value = is_header-inv_type_code ) ##NO_TEXT.
    pair( iv_label = 'Senaryo'        iv_value = is_header-profile_id ) ##NO_TEXT.
    pair( iv_label = 'Para Birimi'    iv_value = CONV #( is_header-currency ) ) ##NO_TEXT.

    section( 'Gonderici (Satici)' ) ##NO_TEXT.
    pair( iv_label = 'VKN/TCKN'       iv_value = is_header-supplier_vkn ) ##NO_TEXT.
    pair( iv_label = 'Unvan'          iv_value = is_header-supplier_name ) ##NO_TEXT.
    pair( iv_label = 'Vergi Dairesi'  iv_value = is_header-supplier_party-tax_office ) ##NO_TEXT.
    pair( iv_label = 'Adres'          iv_value = |{ is_header-supplier_party-street } { is_header-supplier_party-district } { is_header-supplier_party-city }| ) ##NO_TEXT.

    section( 'Alici' ) ##NO_TEXT.
    pair( iv_label = 'VKN/TCKN'       iv_value = is_header-customer_vkn ) ##NO_TEXT.
    pair( iv_label = 'Unvan'          iv_value = is_header-customer_name ) ##NO_TEXT.

    section( 'Tutarlar' ) ##NO_TEXT.
    pair( iv_label = 'Mal/Hizmet Toplami' iv_value = |{ is_header-line_ext_amount }| ) ##NO_TEXT.
    pair( iv_label = 'Vergi Haric'        iv_value = |{ is_header-tax_excl_amount }| ) ##NO_TEXT.
    pair( iv_label = 'Toplam Vergi'       iv_value = |{ is_header-tax_amount }| ) ##NO_TEXT.
    pair( iv_label = 'Vergi Dahil'        iv_value = |{ is_header-tax_incl_amount }| ) ##NO_TEXT.
    pair( iv_label = 'Iskonto'            iv_value = |{ is_header-allow_total }| ) ##NO_TEXT.
    pair( iv_label = 'Odenecek Tutar'     iv_value = |{ is_header-payable_amount }| ) ##NO_TEXT.
  ENDMETHOD.

  METHOD checks.
    section( 'Kontroller' ) ##NO_TEXT.
    IF it_check IS INITIAL.
      WRITE: / icon_led_green AS ICON, 'Tum kontroller basarili' ##NO_TEXT.
      RETURN.
    ENDIF.
    LOOP AT it_check INTO DATA(ls_check).
      CASE ls_check-severity.
        WHEN gc_severity-error.
          WRITE: / icon_led_red AS ICON, ls_check-text.
        WHEN gc_severity-warning.
          WRITE: / icon_led_yellow AS ICON, ls_check-text.
        WHEN OTHERS.
          WRITE: / icon_led_green AS ICON, ls_check-text.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD item_list.
    DATA lv_desc TYPE c LENGTH 40.

    section( |Kalemler ({ lines( is_header-line ) })| ) ##NO_TEXT.
    FORMAT COLOR COL_KEY.
    WRITE: /  'No',       6 'Aciklama',   48 'Miktar',   64 'Birim',
           72 'Birim Fiyat', 90 'Tutar', 108 'Vergi' ##NO_TEXT.
    FORMAT COLOR OFF.

    LOOP AT is_header-line INTO DATA(ls_line).
      lv_desc = ls_line-description.
      WRITE: / ls_line-line_no LEFT-JUSTIFIED,
             6 lv_desc,
            48(14) ls_line-quantity,
            64(6)  ls_line-uom_code,
            72(16) ls_line-unit_price,
            90(16) ls_line-line_amount,
           108(16) ls_line-tax_amount.
    ENDLOOP.
  ENDMETHOD.

  METHOD test_mode_note.
    SKIP.
    FORMAT COLOR COL_TOTAL.
    IF iv_has_error = abap_true.
      WRITE: / 'TEST MODU - kayit yapilmadi. Hatalar giderilmeden gercek aktarim yapilamaz.' ##NO_TEXT.
    ELSE.
      WRITE: / 'TEST MODU - kayit yapilmadi. Aktarmak icin "Test modu" isaretini kaldirip tekrar calistirin.' ##NO_TEXT.
    ENDIF.
    FORMAT COLOR OFF.
  ENDMETHOD.

  METHOD blocked_note.
    SKIP.
    FORMAT COLOR COL_NEGATIVE.
    WRITE: / 'AKTARIM YAPILMADI - yukaridaki kirmizi kontrolleri giderin.' ##NO_TEXT.
    FORMAT COLOR OFF.
  ENDMETHOD.

  METHOD parse_error.
    section( 'UBL parse edilemedi' ) ##NO_TEXT.
    FORMAT COLOR COL_NEGATIVE.
    WRITE: / icon_led_red AS ICON, iv_text.
    FORMAT COLOR OFF.
  ENDMETHOD.

  METHOD result.
    section( 'Aktarim Sonucu' ) ##NO_TEXT.
    pair( iv_label = 'Belge No' iv_value = CONV #( iv_docid ) ) ##NO_TEXT.
    pair( iv_label = 'Durum'    iv_value = CONV #( is_result-status ) ) ##NO_TEXT.
    IF is_result-lifnr IS NOT INITIAL.
      pair( iv_label = 'Tedarikci' iv_value = |{ is_result-lifnr ALPHA = OUT }| ) ##NO_TEXT.
    ENDIF.

    IF is_result-status = 'EXCEPTION'.
      FORMAT COLOR COL_NEGATIVE.
      pair( iv_label = 'Hata' iv_value = is_result-message ) ##NO_TEXT.
      FORMAT COLOR OFF.
    ENDIF.

    SKIP.
    WRITE: / 'Belge kaydedildi. ZONE_IARC_INCOMING raporundan goruntuleyebilirsiniz.' ##NO_TEXT.
  ENDMETHOD.
ENDCLASS.


*----------------------------------------------------------------------*
* LCL_XML_DIAG - parse hatasinda dosyanin gercek yapisini gosterir
* (kok element, onek, namespace, kokun alt elementleri, ilk karakterler)
* - beklenen UBL yapisindan nerede ayristigini gormek icin.
*----------------------------------------------------------------------*
CLASS lcl_xml_diag DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS write
      IMPORTING
        !iv_xml TYPE xstring.

  PRIVATE SECTION.
    CONSTANTS c_max_children TYPE i VALUE 40.
    CONSTANTS c_head_bytes   TYPE i VALUE 400.
    CONSTANTS c_chunk        TYPE i VALUE 100.

    CLASS-METHODS write_head
      IMPORTING
        !iv_xml TYPE xstring.

    CLASS-METHODS write_tree
      IMPORTING
        !iv_xml TYPE xstring.

    CLASS-METHODS leaf_value
      IMPORTING
        !io_node        TYPE REF TO if_ixml_node
      RETURNING
        VALUE(rv_value) TYPE string.
ENDCLASS.

CLASS lcl_xml_diag IMPLEMENTATION.
  METHOD write.
    SKIP.
    FORMAT COLOR COL_HEADING INTENSIFIED ON.
    WRITE: / 'Dosya yapisi (teshis)' ##NO_TEXT.
    FORMAT COLOR OFF INTENSIFIED OFF.
    ULINE.
    write_head( iv_xml ).
    write_tree( iv_xml ).
  ENDMETHOD.

  METHOD write_head.
    DATA lv_head  TYPE string.
    DATA lv_chunk TYPE string.

    DATA(lv_size) = xstrlen( iv_xml ).
    WRITE: / 'Boyut (byte):', lv_size ##NO_TEXT.
    IF lv_size >= 2 AND iv_xml(2) = '504B'.
      WRITE: / 'Dosya bir ZIP arsivi (PK) - once acilip icindeki XML secilmeli.' ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA(lv_len) = nmin( val1 = lv_size val2 = c_head_bytes ).
    TRY.
        cl_abap_conv_in_ce=>create( input       = iv_xml(lv_len)
                                    encoding    = 'UTF-8'
                                    ignore_cerr = abap_true )->read( IMPORTING data = lv_head ).
      CATCH cx_root.
        lv_head = '(UTF-8 olarak cozulemedi)' ##NO_TEXT.
    ENDTRY.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf   IN lv_head WITH ` `.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_head WITH ` `.

    SKIP.
    WRITE: / |Ilk { lv_len } byte:| ##NO_TEXT.
    WHILE lv_head IS NOT INITIAL.
      lv_chunk = substring( val = lv_head len = nmin( val1 = c_chunk val2 = strlen( lv_head ) ) ).
      WRITE: / lv_chunk.
      lv_head = substring( val = lv_head off = strlen( lv_chunk ) ).
    ENDWHILE.
  ENDMETHOD.

  METHOD write_tree.
    DATA(lo_ixml)       = cl_ixml=>create( ).
    DATA(lo_stream_fac) = lo_ixml->create_stream_factory( ).
    DATA(lo_document)   = lo_ixml->create_document( ).
    DATA(lo_parser)     = lo_ixml->create_parser(
                             stream_factory = lo_stream_fac
                             istream        = lo_stream_fac->create_istream_xstring( string = iv_xml )
                             document       = lo_document ).
    SKIP.
    IF lo_parser->parse( ) <> 0.
      WRITE: / 'XML gecersiz - iXML parse edemedi.' ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA(lo_root) = lo_document->get_root_element( ).
    IF lo_root IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(lv_root_name)   = lo_root->get_name( ).
    DATA(lv_root_prefix) = lo_root->get_namespace_prefix( ).
    DATA(lv_root_uri)    = lo_root->get_namespace_uri( ).
    WRITE: / 'Kok element  :', lv_root_name ##NO_TEXT.
    WRITE: / 'Onek         :', lv_root_prefix ##NO_TEXT.
    WRITE: / 'Namespace URI:', lv_root_uri ##NO_TEXT.

    SKIP.
    WRITE: / 'Kokun dogrudan alt elementleri (onek / ad / deger):' ##NO_TEXT.
    DATA lv_count TYPE i.
    DATA(lo_child) = lo_root->get_first_child( ).
    WHILE lo_child IS BOUND AND lv_count < c_max_children.
      IF lo_child->get_type( ) = if_ixml_node=>co_node_element.
        lv_count = lv_count + 1.
        DATA(lv_prefix) = lo_child->get_namespace_prefix( ).
        DATA(lv_name)   = lo_child->get_name( ).
        DATA(lv_value)  = leaf_value( lo_child ).
        WRITE: / lv_count, lv_prefix, 20 lv_name, 55 lv_value.
      ENDIF.
      lo_child = lo_child->get_next( ).
    ENDWHILE.
  ENDMETHOD.

  METHOD leaf_value.
    " Yalnizca tek metin cocugu olan (yaprak) elementlerin degeri gosterilir.
    DATA(lo_first) = io_node->get_first_child( ).
    IF lo_first IS BOUND
       AND lo_first->get_type( ) = if_ixml_node=>co_node_text
       AND lo_first->get_next( ) IS NOT BOUND.
      rv_value = lo_first->get_value( ).
      IF strlen( rv_value ) > 60.
        rv_value = |{ substring( val = rv_value len = 60 ) }...|.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


*----------------------------------------------------------------------*
* LCL_APP
*----------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS run.

  PRIVATE SECTION.
    DATA mo_output TYPE REF TO lcl_output.

    METHODS read_file
      RETURNING
        VALUE(rv_xml) TYPE xstring
      RAISING
        lcx_upload.

    METHODS parse
      IMPORTING
        !iv_xml          TYPE xstring
      RETURNING
        VALUE(rs_header) TYPE zif_zone_iarc_types=>ty_header
      RAISING
        lcx_upload.

    METHODS determine_docid
      IMPORTING
        !is_header      TYPE zif_zone_iarc_types=>ty_header
      RETURNING
        VALUE(rv_docid) TYPE zone_iarc_t006-provider_doc_id.

    METHODS import
      IMPORTING
        !iv_xml    TYPE xstring
        !iv_docid  TYPE zone_iarc_t006-provider_doc_id
        !is_header TYPE zif_zone_iarc_types=>ty_header.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.
  METHOD run.
    mo_output = NEW #( ).

    TRY.
        DATA(lv_xml) = read_file( ).
      CATCH lcx_upload INTO DATA(lx_upload).
        MESSAGE lx_upload->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    TRY.
        DATA(ls_header) = parse( lv_xml ).
      CATCH lcx_upload INTO lx_upload.
        " Durum cubugu mesaji kesilir - tam metin + dosya yapisi listede.
        mo_output->parse_error( lx_upload->get_text( ) ).
        lcl_xml_diag=>write( lv_xml ).
        RETURN.
    ENDTRY.

    DATA(lv_docid) = determine_docid( ls_header ).
    DATA(lt_check) = NEW lcl_checker( iv_bukrs  = p_bukrs
                                      iv_docid  = lv_docid
                                      is_header = ls_header )->run( ).
    DATA(lv_has_error) = lcl_checker=>has_error( lt_check ).

    mo_output->header( iv_file = p_file iv_docid = lv_docid is_header = ls_header ).
    mo_output->checks( lt_check ).
    mo_output->item_list( ls_header ).

    IF p_test = abap_true.
      mo_output->test_mode_note( lv_has_error ).
    ELSEIF lv_has_error = abap_true.
      mo_output->blocked_note( ).
    ELSE.
      import( iv_xml = lv_xml iv_docid = lv_docid is_header = ls_header ).
    ENDIF.
  ENDMETHOD.

  METHOD read_file.
    rv_xml = lcl_file=>read( CONV #( p_file ) ).
  ENDMETHOD.

  METHOD parse.
    TRY.
        rs_header = NEW zcl_zone_iarc_parser( )->parse( iv_xml ).
      CATCH zcx_zone_iarc_mapping INTO DATA(lx_mapping).
        RAISE EXCEPTION TYPE lcx_upload
          EXPORTING iv_text = |{ lx_mapping->mv_error_code } - { lx_mapping->mv_detail }|.
    ENDTRY.
  ENDMETHOD.

  METHOD determine_docid.
    " Entegratorden gelen belgelerde kuyruk anahtari Bayt InvoiceNo'dur;
    " bu da UBL cbc:ID ile aynidir. Parametre verilmisse o kullanilir.
    rv_docid = COND #( WHEN p_docid IS NOT INITIAL THEN p_docid
                       ELSE is_header-invoice_id ).
  ENDMETHOD.

  METHOD import.
    DATA(ls_result) = NEW zcl_zone_iarc_intake( )->process(
      iv_bukrs           = p_bukrs
      iv_provider_doc_id = iv_docid
      iv_xml             = iv_xml
      is_meta            = VALUE #( supplier_vkn = is_header-supplier_vkn
                                    doc_date     = is_header-issue_date
                                    amount       = is_header-payable_amount
                                    currency     = is_header-currency )
      iv_ettn            = is_header-uuid ).
    COMMIT WORK.

    mo_output->result( is_result = ls_result iv_docid = iv_docid ).
  ENDMETHOD.
ENDCLASS.
