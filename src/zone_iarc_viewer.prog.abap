REPORT zone_iarc_viewer.

" Gelen e-Arsiv belge goruntuleme raporu. Liste ZONE_IARC_T006 (kuyruk) +
" ZONE_IARC_T009 (UBL basligi, LEFT OUTER JOIN - henuz parse edilmemis
" belgelerde bos gelir) uzerinden gelir. Secilen belge icin:
"   - "XML Goster": ZONE_IARC_T007.XML_RAW ham icerigi (<pre> ile)
"   - "HTML Goster": ZONE_IARC_T009..T014'ten okunabilir fatura gorunumu
" Ikisi de CL_ABAP_BROWSER=>SHOW_HTML ile popup'ta acilir - kardes proje
" zonetegra_edeclaration'da (Karar 009) ayni teknik zaten dogrulanmisti,
" ozel dynpro/CUA gerektirmez.

TABLES: sscrfields, zone_iarc_t006.

CLASS lcl_html_util DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS escape
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS build_invoice_html
      IMPORTING
        is_header      TYPE zone_iarc_t009
        it_note        TYPE STANDARD TABLE OF zone_iarc_t010
        it_tax         TYPE STANDARD TABLE OF zone_iarc_t011
        it_line        TYPE STANDARD TABLE OF zone_iarc_t012
        it_line_note   TYPE STANDARD TABLE OF zone_iarc_t013
      RETURNING
        VALUE(rv_html) TYPE string.
ENDCLASS.

CLASS lcl_html_util IMPLEMENTATION.

  METHOD escape.
    rv_text = iv_text.
    REPLACE ALL OCCURRENCES OF '&' IN rv_text WITH '&amp;'.
    REPLACE ALL OCCURRENCES OF '<' IN rv_text WITH '&lt;'.
    REPLACE ALL OCCURRENCES OF '>' IN rv_text WITH '&gt;'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_text WITH '&quot;'.
    REPLACE ALL OCCURRENCES OF `'` IN rv_text WITH '&#39;'.
  ENDMETHOD.

  METHOD build_invoice_html.
    DATA(lv_style) =
      |<style>| &&
      |body{font-family:Arial,sans-serif;font-size:13px;margin:16px;}| &&
      |table{border-collapse:collapse;width:100%;margin-bottom:12px;}| &&
      |th,td{border:1px solid #ccc;padding:4px 8px;text-align:left;}| &&
      |th{background:#f2f2f2;}| &&
      |h3{margin-bottom:4px;}| &&
      |.tot{text-align:right;}| &&
      |</style>|.

    DATA(lv_header) =
      |<h3>UBL Fatura Basligi</h3>| &&
      |<table>| &&
      |<tr><th>Fatura No</th><td>{ escape( CONV string( is_header-invoice_id ) ) }</td>| &&
      |<th>UUID (ETTN)</th><td>{ escape( CONV string( is_header-ettn ) ) }</td></tr>| &&
      |<tr><th>Tarih</th><td>{ is_header-issue_date DATE = USER }</td>| &&
      |<th>Saat</th><td>{ is_header-issue_time TIME = USER }</td></tr>| &&
      |<tr><th>Belge Tipi</th><td>{ escape( CONV string( is_header-inv_type_code ) ) }</td>| &&
      |<th>Profil</th><td>{ escape( CONV string( is_header-profile_id ) ) }</td></tr>| &&
      |<tr><th>Satici VKN</th><td>{ escape( CONV string( is_header-supplier_vkn ) ) }</td>| &&
      |<th>Satici Adi</th><td>{ escape( CONV string( is_header-supplier_name ) ) }</td></tr>| &&
      |<tr><th>Alici VKN</th><td>{ escape( CONV string( is_header-customer_vkn ) ) }</td>| &&
      |<th>Alici Adi</th><td>{ escape( CONV string( is_header-customer_name ) ) }</td></tr>| &&
      |</table>|.

    DATA(lv_totals) =
      |<h3>Tutarlar ({ is_header-doc_currency })</h3>| &&
      |<table>| &&
      |<tr><th>Mal/Hizmet Toplami</th><td class="tot">{ is_header-line_ext_amount }</td></tr>| &&
      |<tr><th>KDV Haric Tutar</th><td class="tot">{ is_header-tax_excl_amount }</td></tr>| &&
      |<tr><th>Toplam Vergi</th><td class="tot">{ is_header-tax_amount }</td></tr>| &&
      |<tr><th>KDV Dahil Tutar</th><td class="tot">{ is_header-tax_incl_amount }</td></tr>| &&
      |<tr><th>Iskonto Toplami</th><td class="tot">{ is_header-allow_total }</td></tr>| &&
      |<tr><th>Ek Ucret Toplami</th><td class="tot">{ is_header-charge_total }</td></tr>| &&
      |<tr><th><b>Odenecek Tutar</b></th><td class="tot"><b>{ is_header-payable_amount }</b></td></tr>| &&
      |</table>|.

    DATA(lv_notes) = ``.
    IF it_note IS NOT INITIAL.
      lv_notes = |<h3>Baslik Notlari</h3><ul>|.
      LOOP AT it_note INTO DATA(ls_note).
        lv_notes = lv_notes && |<li>{ escape( CONV string( ls_note-note_text ) ) }</li>|.
      ENDLOOP.
      lv_notes = lv_notes && |</ul>|.
    ENDIF.

    DATA(lv_tax) = |<h3>Vergi Dip Toplami</h3><table>| &&
      |<tr><th>Matrah</th><th>Oran (%)</th><th>Vergi Tutari</th><th>Tur</th><th>GIB Kodu</th></tr>|.
    LOOP AT it_tax INTO DATA(ls_tax).
      lv_tax = lv_tax &&
        |<tr><td class="tot">{ ls_tax-taxable_amount }</td>| &&
        |<td class="tot">{ ls_tax-tax_percent }</td>| &&
        |<td class="tot">{ ls_tax-tax_amount }</td>| &&
        |<td>{ escape( CONV string( ls_tax-tax_cat_name ) ) }</td>| &&
        |<td>{ escape( CONV string( ls_tax-tax_type_code ) ) }</td></tr>|.
    ENDLOOP.
    lv_tax = lv_tax && |</table>|.

    DATA(lv_lines) = |<h3>Kalemler</h3><table>| &&
      |<tr><th>No</th><th>Aciklama</th><th>Miktar</th><th>Birim</th>| &&
      |<th>Birim Fiyat</th><th>Tutar</th><th>KDV Tutari</th></tr>|.
    LOOP AT it_line INTO DATA(ls_line).
      lv_lines = lv_lines &&
        |<tr><td>{ ls_line-line_no }</td>| &&
        |<td>{ escape( CONV string( ls_line-item_name ) ) }</td>| &&
        |<td class="tot">{ ls_line-quantity }</td>| &&
        |<td>{ escape( CONV string( ls_line-uom_code ) ) }</td>| &&
        |<td class="tot">{ ls_line-unit_price }</td>| &&
        |<td class="tot">{ ls_line-line_amount }</td>| &&
        |<td class="tot">{ ls_line-tax_amount }</td></tr>|.
    ENDLOOP.
    lv_lines = lv_lines && |</table>|.

    DATA(lv_line_notes) = ``.
    IF it_line_note IS NOT INITIAL.
      lv_line_notes = |<h3>Kalem Notlari</h3><table>| &&
        |<tr><th>Kalem No</th><th>Not</th></tr>|.
      LOOP AT it_line_note INTO DATA(ls_line_note).
        lv_line_notes = lv_line_notes &&
          |<tr><td>{ ls_line_note-line_no }</td>| &&
          |<td>{ escape( CONV string( ls_line_note-note_text ) ) }</td></tr>|.
      ENDLOOP.
      lv_line_notes = lv_line_notes && |</table>|.
    ENDIF.

    rv_html = |<html><head><meta charset="utf-8">{ lv_style }</head><body>| &&
      lv_header && lv_totals && lv_notes && lv_tax && lv_lines && lv_line_notes &&
      |</body></html>|.
  ENDMETHOD.

ENDCLASS.

SELECTION-SCREEN FUNCTION KEY 1. " XML Goster
SELECTION-SCREEN FUNCTION KEY 2. " HTML Goster

PARAMETERS: p_bukrs TYPE bukrs OBLIGATORY,
            p_docid TYPE zone_iarc_t006-provider_doc_id.
SELECT-OPTIONS: s_idate FOR zone_iarc_t006-doc_date,
                s_stat  FOR zone_iarc_t006-status.

TYPES:
  BEGIN OF ty_list,
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
    payable_amount  TYPE zone_iarc_t009-payable_amount,
  END OF ty_list.
DATA gt_list TYPE STANDARD TABLE OF ty_list.

INITIALIZATION.
  sscrfields-functxt_01 = 'XML Goster'.
  sscrfields-functxt_02 = 'HTML Goster'.

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      PERFORM show_xml USING p_docid.
    WHEN 'FC02'.
      PERFORM show_html USING p_docid.
  ENDCASE.

START-OF-SELECTION.
  SELECT a~provider_doc_id, a~bukrs, a~ettn, a~status, a~supplier_vkn,
         a~doc_date, a~amount, a~currency,
         b~invoice_id, b~supplier_name, b~payable_amount
    FROM zone_iarc_t006 AS a
    LEFT OUTER JOIN zone_iarc_t009 AS b
      ON b~bukrs = a~bukrs AND b~ettn = a~ettn
    INTO TABLE @gt_list
    WHERE a~bukrs    = @p_bukrs
      AND a~doc_date IN @s_idate
      AND a~status   IN @s_stat
    ORDER BY a~received_at DESCENDING.

  IF gt_list IS INITIAL.
    MESSAGE 'Secim kriterlerine uyan belge yok' TYPE 'S' DISPLAY LIKE 'W'.
  ELSE.
    " I_STRUCTURE_NAME verilmedi (GT_LIST birlestirilmis/yerel bir tip,
    " tek bir DDIC yapisina karsilik gelmiyor) - ALV kolon basliklari bu
    " yuzden teknik alan adi olarak gorunur (kucuk kozmetik eksik,
    " fonksiyonel sorun degil).
    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      TABLES
        t_outtab      = gt_list
      EXCEPTIONS
        program_error = 1
        OTHERS        = 2.
  ENDIF.

FORM show_xml USING iv_docid TYPE zone_iarc_t006-provider_doc_id.
  IF iv_docid IS INITIAL.
    MESSAGE 'Once bir belge (provider doc id) girin' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SELECT SINGLE xml_raw FROM zone_iarc_t007
    INTO @DATA(lv_xml_raw)
    WHERE provider_doc_id = @iv_docid.
  IF sy-subrc <> 0.
    MESSAGE |XML bulunamadi: { iv_docid }| TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  DATA(lv_xml_text) = cl_abap_codepage=>convert_from( lv_xml_raw ).
  DATA(lv_html) =
    |<html><head><meta charset="utf-8"></head><body>| &&
    |<h3>Ham UBL XML - { iv_docid }</h3>| &&
    |<pre style="white-space:pre-wrap;word-break:break-all;font-family:monospace;font-size:12px;">| &&
    lcl_html_util=>escape( lv_xml_text ) &&
    |</pre></body></html>|.

  cl_abap_browser=>show_html(
    title       = |XML - { iv_docid }|
    html_string = lv_html ).
ENDFORM.

FORM show_html USING iv_docid TYPE zone_iarc_t006-provider_doc_id.
  IF iv_docid IS INITIAL.
    MESSAGE 'Once bir belge (provider doc id) girin' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SELECT SINGLE bukrs, ettn FROM zone_iarc_t006
    INTO (@DATA(lv_bukrs), @DATA(lv_ettn))
    WHERE provider_doc_id = @iv_docid.
  IF sy-subrc <> 0 OR lv_ettn IS INITIAL.
    MESSAGE |Belge henuz parse edilmemis veya bulunamadi: { iv_docid }| TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SELECT SINGLE * FROM zone_iarc_t009
    INTO @DATA(ls_hdr)
    WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn.
  IF sy-subrc <> 0.
    MESSAGE |UBL basligi bulunamadi: { iv_docid }| TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  SELECT * FROM zone_iarc_t010 INTO TABLE @DATA(lt_note)
    WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn ORDER BY seq_no.
  SELECT * FROM zone_iarc_t011 INTO TABLE @DATA(lt_tax)
    WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn ORDER BY seq_no.
  SELECT * FROM zone_iarc_t012 INTO TABLE @DATA(lt_line)
    WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn ORDER BY line_no.
  SELECT * FROM zone_iarc_t013 INTO TABLE @DATA(lt_line_note)
    WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn ORDER BY line_no, seq_no.

  DATA(lv_html) = lcl_html_util=>build_invoice_html(
    is_header    = ls_hdr
    it_note      = lt_note
    it_tax       = lt_tax
    it_line      = lt_line
    it_line_note = lt_line_note ).

  cl_abap_browser=>show_html(
    title       = |Fatura - { ls_hdr-invoice_id }|
    html_string = lv_html ).
ENDFORM.
