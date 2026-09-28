CLASS zcl_zone_iarc_doc_view DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Tek bir gelen belgeyi popup tarayicida (CL_ABAP_BROWSER) gosterir:
    "   - SHOW_XML : ZONE_IARC_T007 ham UBL XML (escape edilmis <pre>)
    "   - SHOW_HTML: ZONE_IARC_T009..T013'ten okunabilir fatura
    " ZONE_IARC_VIEWER ve ZONE_IARC_INCOMING (grid) ortak kullanir
    " (Karar 025 - eskiden viewer icindeki FORM'lardaydi).

    " Adlandirilmis tablo tipleri - SELECT ... INTO TABLE @DATA(...) EMPTY
    " KEY'li anonim tip uretir ve metot imzasiyla uyusmaz (Karar 014).
    TYPES: tt_t010 TYPE STANDARD TABLE OF zone_iarc_t010 WITH DEFAULT KEY,
           tt_t011 TYPE STANDARD TABLE OF zone_iarc_t011 WITH DEFAULT KEY,
           tt_t012 TYPE STANDARD TABLE OF zone_iarc_t012 WITH DEFAULT KEY,
           tt_t013 TYPE STANDARD TABLE OF zone_iarc_t013 WITH DEFAULT KEY.

    CLASS-METHODS show_xml
      IMPORTING
        !iv_docid TYPE zone_iarc_t006-provider_doc_id.

    CLASS-METHODS show_html
      IMPORTING
        !iv_docid TYPE zone_iarc_t006-provider_doc_id.

    CLASS-METHODS escape
      IMPORTING
        !iv_text       TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS build_invoice_html
      IMPORTING
        !is_header     TYPE zone_iarc_t009
        !it_note       TYPE tt_t010
        !it_tax        TYPE tt_t011
        !it_line       TYPE tt_t012
        !it_line_note  TYPE tt_t013
      RETURNING
        VALUE(rv_html) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_doc_view IMPLEMENTATION.

  METHOD show_xml.
    SELECT SINGLE xml_raw FROM zone_iarc_t007
      WHERE provider_doc_id = @iv_docid
      INTO @DATA(lv_xml_raw).
    IF sy-subrc <> 0.
      MESSAGE 'Ham XML bulunamadi (ZONE_IARC_T007)' TYPE 'S' DISPLAY LIKE 'E' ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA lv_xml_text TYPE string.
    TRY.
        lv_xml_text = cl_abap_codepage=>convert_from( lv_xml_raw ).
      CATCH cx_root.
        MESSAGE 'XML UTF-8 olarak cozulemedi' TYPE 'S' DISPLAY LIKE 'E' ##NO_TEXT.
        RETURN.
    ENDTRY.

    DATA(lv_html) =
      |<html><head><meta charset="utf-8"></head><body>| &&
      |<h3>Ham UBL XML - { escape( CONV string( iv_docid ) ) }</h3>| &&
      |<pre style="white-space:pre-wrap;word-break:break-all;font-family:monospace;font-size:12px;">| &&
      escape( lv_xml_text ) &&
      |</pre></body></html>|.

    cl_abap_browser=>show_html(
      title       = |XML - { iv_docid }|
      html_string = lv_html ).
  ENDMETHOD.

  METHOD show_html.
    SELECT SINGLE bukrs, ettn FROM zone_iarc_t006
      WHERE provider_doc_id = @iv_docid
      INTO (@DATA(lv_bukrs), @DATA(lv_ettn)).
    IF sy-subrc <> 0 OR lv_ettn IS INITIAL.
      MESSAGE 'Belge bulunamadi veya henuz parse edilmemis' TYPE 'S' DISPLAY LIKE 'E' ##NO_TEXT.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zone_iarc_t009
      WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn
      INTO @DATA(ls_hdr).
    IF sy-subrc <> 0.
      MESSAGE 'UBL basligi bulunamadi (ZONE_IARC_T009)' TYPE 'S' DISPLAY LIKE 'E' ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA lt_note      TYPE tt_t010.
    DATA lt_tax       TYPE tt_t011.
    DATA lt_line      TYPE tt_t012.
    DATA lt_line_note TYPE tt_t013.

    SELECT * FROM zone_iarc_t010 WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn
      ORDER BY seq_no INTO TABLE @lt_note.
    SELECT * FROM zone_iarc_t011 WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn
      ORDER BY seq_no INTO TABLE @lt_tax.
    SELECT * FROM zone_iarc_t012 WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn
      ORDER BY line_no INTO TABLE @lt_line.
    SELECT * FROM zone_iarc_t013 WHERE bukrs = @lv_bukrs AND ettn = @lv_ettn
      ORDER BY line_no, seq_no INTO TABLE @lt_line_note.

    DATA(lv_html) = build_invoice_html(
      is_header    = ls_hdr
      it_note      = lt_note
      it_tax       = lt_tax
      it_line      = lt_line
      it_line_note = lt_line_note ).

    cl_abap_browser=>show_html(
      title       = |Fatura - { ls_hdr-invoice_id }|
      html_string = lv_html ).
  ENDMETHOD.

  METHOD escape.
    rv_text = iv_text.
    REPLACE ALL OCCURRENCES OF '&' IN rv_text WITH '&amp;'.
    REPLACE ALL OCCURRENCES OF '<' IN rv_text WITH '&lt;'.
    REPLACE ALL OCCURRENCES OF '>' IN rv_text WITH '&gt;'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_text WITH '&quot;'.
    REPLACE ALL OCCURRENCES OF `'` IN rv_text WITH '&#39;'.
  ENDMETHOD.

  METHOD build_invoice_html.
    " NOT: CSS blogu duz string literal ('...') ile kurulur, string
    " template (|...|) ile degil - '{' ABAP string template'lerinde
    " ifade sinirlayicidir (Karar 013).
    DATA(lv_style) =
      '<style>' &&
      'body{font-family:Arial,sans-serif;font-size:13px;margin:16px;}' &&
      'table{border-collapse:collapse;width:100%;margin-bottom:12px;}' &&
      'th,td{border:1px solid #ccc;padding:4px 8px;text-align:left;}' &&
      'th{background:#f2f2f2;}' &&
      'h3{margin-bottom:4px;}' &&
      '.tot{text-align:right;}' &&
      '</style>'.

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
      |</table>| ##NO_TEXT.

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
      |</table>| ##NO_TEXT.

    DATA(lv_notes) = ``.
    IF it_note IS NOT INITIAL.
      lv_notes = |<h3>Baslik Notlari</h3><ul>| ##NO_TEXT.
      LOOP AT it_note INTO DATA(ls_note).
        lv_notes = lv_notes && |<li>{ escape( CONV string( ls_note-note_text ) ) }</li>|.
      ENDLOOP.
      lv_notes = lv_notes && |</ul>|.
    ENDIF.

    DATA(lv_tax) = |<h3>Vergi Dip Toplami</h3><table>| &&
      |<tr><th>Matrah</th><th>Oran (%)</th><th>Vergi Tutari</th><th>Tur</th><th>GIB Kodu</th></tr>| ##NO_TEXT.
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
      |<th>Birim Fiyat</th><th>Tutar</th><th>KDV Tutari</th></tr>| ##NO_TEXT.
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
        |<tr><th>Kalem No</th><th>Not</th></tr>| ##NO_TEXT.
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
