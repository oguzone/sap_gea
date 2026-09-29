CLASS zcl_zone_iarc_dashboard_html DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Gelen e-Arsiv kokpiti (ZONE_IARC_MAIN) sag panel gosterge sayfasi
    " (Karar 033). Ust bant (sirket/donem), 6 KPI, durum halkasi, son 12
    " ay sutun grafigi (toplam + muhasebelesen), en yuksek 5 satici,
    " muhasebelesme orani ve son gelen belgeler tablosu.
    "
    " SAP GUI HTML kontrolu IE motoruyla calisabilir: yalnizca IE11 uyumlu
    " CSS (flexbox), inline SVG; JavaScript / dis kutuphane yok. CSS '...'
    " literalleriyle kurulur ('{' string template'te ifade sinirlayicidir).

    TYPES:
      BEGIN OF ty_doc,
        provider_doc_id TYPE zone_iarc_t006-provider_doc_id,
        bukrs           TYPE zone_iarc_t006-bukrs,
        invoice_id      TYPE zone_iarc_t009-invoice_id,
        doc_date        TYPE zone_iarc_t006-doc_date,
        status          TYPE zone_iarc_t006-status,
        amount          TYPE zone_iarc_t006-amount,
        currency        TYPE zone_iarc_t006-currency,
        supplier_vkn    TYPE zone_iarc_t006-supplier_vkn,
        supplier_name   TYPE zone_iarc_t009-supplier_name,
        lifnr           TYPE zone_iarc_t006-lifnr,
        received_at     TYPE zone_iarc_t006-received_at,
      END OF ty_doc.
    TYPES tt_doc TYPE STANDARD TABLE OF ty_doc WITH DEFAULT KEY.

    METHODS build
      IMPORTING
        !it_doc        TYPE tt_doc
        !iv_period     TYPE string      " orn. "01.10.2025 - 29.09.2026"
      RETURNING
        VALUE(rv_html) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_status,
        status TYPE zone_iarc_t006-status,
        count  TYPE i,
      END OF ty_status,
      tt_status TYPE STANDARD TABLE OF ty_status WITH DEFAULT KEY,
      BEGIN OF ty_amount,
        currency TYPE waers,
        amount   TYPE p LENGTH 15 DECIMALS 2,
      END OF ty_amount,
      tt_amount TYPE STANDARD TABLE OF ty_amount WITH DEFAULT KEY,
      BEGIN OF ty_supplier,
        name   TYPE c LENGTH 60,
        amount TYPE p LENGTH 15 DECIMALS 2,
      END OF ty_supplier,
      tt_supplier TYPE STANDARD TABLE OF ty_supplier WITH DEFAULT KEY,
      BEGIN OF ty_month,
        key    TYPE c LENGTH 6,     " YYYYMM
        label  TYPE c LENGTH 5,     " MM/YY
        total  TYPE i,
        posted TYPE i,
      END OF ty_month,
      tt_month TYPE STANDARD TABLE OF ty_month WITH DEFAULT KEY.

    DATA mt_doc      TYPE tt_doc.
    DATA mt_status   TYPE tt_status.
    DATA mt_amount   TYPE tt_amount.
    DATA mt_supplier TYPE tt_supplier.
    DATA mt_month    TYPE tt_month.

    METHODS aggregate.
    METHODS build_months.
    METHODS css
      RETURNING VALUE(rv_css) TYPE string.
    METHODS header_bar
      IMPORTING
        !iv_period     TYPE string
      RETURNING
        VALUE(rv_html) TYPE string.
    METHODS kpi_row
      RETURNING VALUE(rv_html) TYPE string.
    METHODS kpi
      IMPORTING
        !iv_label      TYPE string
        !iv_value      TYPE string
        !iv_hint       TYPE string OPTIONAL
        !iv_color      TYPE string
      RETURNING
        VALUE(rv_html) TYPE string.
    METHODS status_card
      RETURNING VALUE(rv_html) TYPE string.
    METHODS month_card
      RETURNING VALUE(rv_html) TYPE string.
    METHODS supplier_card
      RETURNING VALUE(rv_html) TYPE string.
    METHODS recent_card
      RETURNING VALUE(rv_html) TYPE string.
    METHODS status_count
      IMPORTING
        !iv_status      TYPE zone_iarc_t006-status
      RETURNING
        VALUE(rv_count) TYPE i.
    METHODS status_color
      IMPORTING
        !iv_status      TYPE zone_iarc_t006-status
      RETURNING
        VALUE(rv_color) TYPE string.
    METHODS format_amount
      IMPORTING
        !iv_amount     TYPE p
        !iv_currency   TYPE waers
      RETURNING
        VALUE(rv_text) TYPE string.
    METHODS esc
      IMPORTING
        !iv_text       TYPE csequence
      RETURNING
        VALUE(rv_text) TYPE string.
ENDCLASS.



CLASS zcl_zone_iarc_dashboard_html IMPLEMENTATION.

  METHOD build.
    mt_doc = it_doc.
    aggregate( ).
    build_months( ).

    rv_html =
      |<!DOCTYPE html><html><head>| &&
      |<meta http-equiv="X-UA-Compatible" content="IE=edge">| &&
      |<style>| && css( ) && |</style></head><body>| &&
      header_bar( iv_period ) &&
      kpi_row( ) &&
      |<div class="row">| && status_card( ) && month_card( ) && supplier_card( ) && |</div>| &&
      recent_card( ) &&
      |</body></html>|.
  ENDMETHOD.

  METHOD aggregate.
    DATA ls_status   TYPE ty_status.
    DATA ls_amount   TYPE ty_amount.
    DATA ls_supplier TYPE ty_supplier.

    CLEAR: mt_status, mt_amount, mt_supplier.
    LOOP AT mt_doc INTO DATA(ls_doc).
      ls_status-status = ls_doc-status.
      ls_status-count  = 1.
      COLLECT ls_status INTO mt_status.

      ls_amount-currency = ls_doc-currency.
      ls_amount-amount   = ls_doc-amount.
      COLLECT ls_amount INTO mt_amount.

      ls_supplier-name   = COND #( WHEN ls_doc-supplier_name IS NOT INITIAL THEN ls_doc-supplier_name
                                   ELSE ls_doc-supplier_vkn ).
      ls_supplier-amount = ls_doc-amount.
      COLLECT ls_supplier INTO mt_supplier.
    ENDLOOP.

    SORT mt_status BY count DESCENDING.
    SORT mt_amount BY amount DESCENDING.
    SORT mt_supplier BY amount DESCENDING.
    DELETE mt_supplier FROM 6.
  ENDMETHOD.

  METHOD build_months.
    " Bugunden geriye 12 ay (en eski solda).
    DATA lv_year  TYPE i.
    DATA lv_month TYPE i.
    DATA ls_month TYPE ty_month.

    CLEAR mt_month.
    DO 12 TIMES.
      DATA(lv_back) = 12 - sy-index.
      lv_year  = sy-datum(4).
      lv_month = sy-datum+4(2) - lv_back.
      WHILE lv_month < 1.
        lv_month = lv_month + 12.
        lv_year  = lv_year - 1.
      ENDWHILE.
      CLEAR ls_month.
      ls_month-key   = |{ lv_year }{ lv_month WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
      ls_month-label = |{ lv_month WIDTH = 2 ALIGN = RIGHT PAD = '0' }/{ lv_year MOD 100 WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
      LOOP AT mt_doc INTO DATA(ls_doc).
        CHECK ls_doc-doc_date(6) = ls_month-key.
        ls_month-total = ls_month-total + 1.
        IF ls_doc-status = 'POSTED'.
          ls_month-posted = ls_month-posted + 1.
        ENDIF.
      ENDLOOP.
      APPEND ls_month TO mt_month.
    ENDDO.
  ENDMETHOD.

  METHOD css.
    rv_css =
      '*{box-sizing:border-box;margin:0;padding:0;}' &&
      'body{font-family:"Segoe UI",Arial,sans-serif;font-size:12px;color:#1f2937;' &&
      'background:#eef2f7;padding:10px;}' &&
      '.hdr{display:flex;justify-content:space-between;align-items:center;color:#ffffff;' &&
      'background:linear-gradient(135deg,#0b3d91 0%,#1e6fd9 100%);border-radius:10px;' &&
      'padding:12px 16px;margin-bottom:10px;}' &&
      '.hdr h1{font-size:18px;font-weight:600;}' &&
      '.hdr .sub{font-size:11px;opacity:0.85;margin-top:2px;}' &&
      '.hdr .per{text-align:right;font-size:11px;opacity:0.9;}' &&
      '.hdr .per b{display:block;font-size:13px;opacity:1;}' &&
      '.kpis{display:flex;margin-bottom:10px;}' &&
      '.kpi{flex:1;background:#ffffff;border-radius:10px;padding:10px 12px;margin-right:8px;' &&
      'box-shadow:0 1px 3px rgba(15,23,42,0.10);border-top:4px solid #1e6fd9;}' &&
      '.kpi:last-child{margin-right:0;}' &&
      '.kpi .l{font-size:10px;color:#64748b;text-transform:uppercase;letter-spacing:0.5px;' &&
      'white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' &&
      '.kpi .n{font-size:22px;font-weight:700;margin-top:4px;white-space:nowrap;' &&
      'overflow:hidden;text-overflow:ellipsis;}' &&
      '.kpi .h{font-size:10px;color:#94a3b8;margin-top:2px;white-space:nowrap;}' &&
      '.row{display:flex;margin-bottom:10px;}' &&
      '.card{background:#ffffff;border-radius:10px;padding:10px 14px;margin-right:8px;' &&
      'box-shadow:0 1px 3px rgba(15,23,42,0.10);}' &&
      '.card:last-child{margin-right:0;}' &&
      '.card h2{font-size:11px;font-weight:600;color:#64748b;text-transform:uppercase;' &&
      'letter-spacing:0.6px;margin-bottom:8px;}' &&
      '.c-status{flex:0 0 24%;}' &&
      '.c-month{flex:1;}' &&
      '.c-supp{flex:0 0 30%;}' &&
      '.donut{display:flex;align-items:center;}' &&
      '.legend{margin-left:10px;}' &&
      '.lg{display:flex;align-items:center;margin:3px 0;white-space:nowrap;}' &&
      '.dot{width:9px;height:9px;border-radius:50%;margin-right:6px;}' &&
      '.lg b{margin-left:6px;}' &&
      '.rate{margin-top:10px;}' &&
      '.rate .tr{height:8px;background:#eef2f7;border-radius:4px;margin-top:4px;}' &&
      '.rate .fl{height:8px;border-radius:4px;background:#16a34a;}' &&
      '.bar{display:flex;align-items:center;margin:6px 0;}' &&
      '.bar .nm{width:40%;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' &&
      '.bar .tr{flex:1;height:10px;background:#eef2f7;border-radius:5px;margin:0 8px;}' &&
      '.bar .fl{height:10px;border-radius:5px;' &&
      'background:linear-gradient(90deg,#1e6fd9 0%,#38bdf8 100%);}' &&
      '.bar .am{width:28%;text-align:right;white-space:nowrap;font-weight:600;}' &&
      '.mlg{font-size:10px;color:#64748b;margin-top:4px;}' &&
      '.mlg span{display:inline-block;width:9px;height:9px;border-radius:2px;margin:0 4px 0 10px;}' &&
      'table{width:100%;border-collapse:collapse;}' &&
      'th{text-align:left;font-size:10px;color:#64748b;text-transform:uppercase;' &&
      'padding:6px 8px;border-bottom:1px solid #e2e8f0;}' &&
      'td{padding:6px 8px;border-bottom:1px solid #f1f5f9;white-space:nowrap;}' &&
      'td.r,th.r{text-align:right;}' &&
      '.warn{color:#f59e0b;font-weight:600;}' &&
      '.badge{display:inline-block;padding:2px 8px;border-radius:10px;color:#ffffff;' &&
      'font-size:10px;font-weight:600;}' &&
      '.empty{color:#94a3b8;padding:6px 0;}' &&
      '@media (max-width:1100px){' &&
      '.c-supp{display:none;}' &&
      '.kpi .n{font-size:17px;}' &&
      '}'.
  ENDMETHOD.

  METHOD header_bar.
    " Tek sirket kodu ise T001 unvani, birden fazlaysa sayisi.
    DATA lt_bukrs TYPE STANDARD TABLE OF bukrs WITH DEFAULT KEY.
    LOOP AT mt_doc INTO DATA(ls_doc).
      IF NOT line_exists( lt_bukrs[ table_line = ls_doc-bukrs ] ).
        APPEND ls_doc-bukrs TO lt_bukrs.
      ENDIF.
    ENDLOOP.

    DATA lv_title TYPE string.
    DATA lv_sub   TYPE string.
    IF lines( lt_bukrs ) = 1.
      DATA(lv_bukrs) = lt_bukrs[ 1 ].
      SELECT SINGLE butxt, ort01 FROM t001 WHERE bukrs = @lv_bukrs INTO @DATA(ls_t001).
      lv_title = COND #( WHEN ls_t001-butxt IS NOT INITIAL THEN |{ ls_t001-butxt }| ELSE |Sirket { lv_bukrs }| ) ##NO_TEXT.
      lv_sub   = condense( |Sirket Kodu { lv_bukrs } { ls_t001-ort01 }| ) ##NO_TEXT.
    ELSEIF lt_bukrs IS INITIAL.
      lv_title = `Gelen e-Arsiv Kokpit` ##NO_TEXT.
      lv_sub   = `Secilen donemde belge yok` ##NO_TEXT.
    ELSE.
      lv_title = `Gelen e-Arsiv Kokpit` ##NO_TEXT.
      lv_sub   = |{ lines( lt_bukrs ) } sirket kodu| ##NO_TEXT.
    ENDIF.

    rv_html =
      |<div class="hdr"><div><h1>{ esc( lv_title ) }</h1><div class="sub">{ esc( lv_sub ) }</div></div>| &&
      |<div class="per">Donem<b>{ esc( iv_period ) }</b>| &&
      |Guncelleme { sy-datum DATE = USER } { sy-uzeit TIME = USER }</div></div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD kpi_row.
    DATA(lv_total)   = lines( mt_doc ).
    DATA(lv_posted)  = status_count( 'POSTED' ).
    DATA(lv_waiting) = status_count( 'MAPPED' ) + status_count( 'PARKED' ).
    DATA(lv_error)   = status_count( 'EXCEPTION' ).
    DATA(lv_no_vendor) = REDUCE i( INIT n = 0 FOR ls_doc IN mt_doc WHERE ( lifnr IS INITIAL ) NEXT n = n + 1 ).

    DATA(ls_main)  = VALUE ty_amount( mt_amount[ 1 ] OPTIONAL ).
    DATA(lv_amount) = format_amount( iv_amount = ls_main-amount iv_currency = ls_main-currency ).
    DATA(lv_amount_hint) = COND string( WHEN lines( mt_amount ) > 1
                                        THEN |+{ lines( mt_amount ) - 1 } farkli para birimi| ) ##NO_TEXT.
    DATA(lv_rate) = COND i( WHEN lv_total > 0 THEN lv_posted * 100 / lv_total ELSE 0 ).

    rv_html =
      |<div class="kpis">| &&
      kpi( iv_label = `Gelen Belge`      iv_value = |{ lv_total }|     iv_color = `#1e6fd9` iv_hint = `secilen donem` ) &&
      kpi( iv_label = `Muhasebelesen`    iv_value = |{ lv_posted }|    iv_color = `#16a34a` iv_hint = |%{ lv_rate }| ) &&
      kpi( iv_label = `Beklemede`        iv_value = |{ lv_waiting }|   iv_color = `#eab308` iv_hint = `hazir + park` ) &&
      kpi( iv_label = `Cari Eslesmeyen`  iv_value = |{ lv_no_vendor }| iv_color = `#f59e0b` iv_hint = `tedarikci yok` ) &&
      kpi( iv_label = `Hatali`           iv_value = |{ lv_error }|     iv_color = `#dc2626` iv_hint = `islem bekliyor` ) &&
      kpi( iv_label = `Toplam Tutar`     iv_value = lv_amount          iv_color = `#7c3aed` iv_hint = lv_amount_hint ) &&
      |</div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD kpi.
    rv_html =
      |<div class="kpi" style="border-top-color:{ iv_color };">| &&
      |<div class="l">{ esc( iv_label ) }</div>| &&
      |<div class="n">{ esc( iv_value ) }</div>| &&
      |<div class="h">{ esc( iv_hint ) }&nbsp;</div></div>|.
  ENDMETHOD.

  METHOD status_card.
    " SVG halka: r=15.915 -> cevre = 100, stroke-dasharray yuzde olarak.
    DATA(lv_total) = lines( mt_doc ).
    DATA lv_pct    TYPE p LENGTH 7 DECIMALS 2.
    DATA lv_offset TYPE p LENGTH 7 DECIMALS 2 VALUE 25.
    DATA lv_rest   TYPE p LENGTH 7 DECIMALS 2.

    DATA(lv_svg) =
      |<svg width="110" height="110" viewBox="0 0 42 42">| &&
      |<circle cx="21" cy="21" r="15.915" fill="transparent" stroke="#eef2f7" stroke-width="6"></circle>|.
    DATA(lv_legend) = ``.

    LOOP AT mt_status INTO DATA(ls_status).
      lv_pct  = COND #( WHEN lv_total > 0 THEN CONV decfloat34( ls_status-count ) * 100 / lv_total ELSE 0 ).
      lv_rest = 100 - lv_pct.
      DATA(lv_color) = status_color( ls_status-status ).
      lv_svg = lv_svg &&
        |<circle cx="21" cy="21" r="15.915" fill="transparent" stroke="{ lv_color }" stroke-width="6" | &&
        |stroke-dasharray="{ lv_pct } { lv_rest }" stroke-dashoffset="{ lv_offset }"></circle>|.
      lv_offset = lv_offset - lv_pct.
      lv_legend = lv_legend &&
        |<div class="lg"><span class="dot" style="background:{ lv_color };"></span>| &&
        |{ esc( zcl_zone_iarc_status=>text( ls_status-status ) ) }<b>{ ls_status-count }</b></div>|.
    ENDLOOP.

    lv_svg = lv_svg &&
      |<text x="21" y="23.5" text-anchor="middle" font-size="8" font-weight="700" fill="#1f2937">{ lv_total }</text>| &&
      |</svg>|.

    " Muhasebelesme orani
    DATA(lv_rate) = COND i( WHEN lv_total > 0 THEN status_count( 'POSTED' ) * 100 / lv_total ELSE 0 ).

    rv_html =
      |<div class="card c-status"><h2>Durum Dagilimi</h2>| &&
      |<div class="donut">{ lv_svg }<div class="legend">{ lv_legend }</div></div>| &&
      |<div class="rate">Muhasebelesme orani <b>%{ lv_rate }</b>| &&
      |<div class="tr"><div class="fl" style="width:{ lv_rate }%;"></div></div></div>| &&
      |</div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD month_card.
    " SVG sutun grafigi: acik mavi = gelen, yesil = muhasebelesen.
    DATA(lv_max) = REDUCE i( INIT m = 1 FOR ls_m IN mt_month NEXT m = nmax( val1 = m val2 = ls_m-total ) ).
    DATA lv_x      TYPE i.
    DATA lv_h      TYPE i.
    DATA lv_hp     TYPE i.
    DATA lv_y      TYPE i.
    DATA lv_yp     TYPE i.

    DATA(lv_svg) = |<svg width="100%" height="150" viewBox="0 0 372 150" preserveAspectRatio="none">|.
    lv_svg = lv_svg && |<line x1="0" y1="120" x2="372" y2="120" stroke="#e2e8f0" stroke-width="1"></line>|.

    LOOP AT mt_month INTO DATA(ls_month).
      lv_x  = ( sy-tabix - 1 ) * 31 + 4.
      lv_h  = ls_month-total * 100 / lv_max.
      lv_hp = ls_month-posted * 100 / lv_max.
      lv_y  = 120 - lv_h.
      lv_yp = 120 - lv_hp.
      lv_svg = lv_svg &&
        |<rect x="{ lv_x }" y="{ lv_y }" width="22" height="{ lv_h }" rx="3" fill="#bfdbfe"></rect>| &&
        |<rect x="{ lv_x }" y="{ lv_yp }" width="22" height="{ lv_hp }" rx="3" fill="#16a34a"></rect>| &&
        |<text x="{ lv_x + 11 }" y="136" text-anchor="middle" font-size="8" fill="#64748b">{ ls_month-label }</text>|.
      IF ls_month-total > 0.
        lv_svg = lv_svg &&
          |<text x="{ lv_x + 11 }" y="{ lv_y - 3 }" text-anchor="middle" font-size="8" font-weight="700" fill="#1f2937">| &&
          |{ ls_month-total }</text>|.
      ENDIF.
    ENDLOOP.
    lv_svg = lv_svg && |</svg>|.

    rv_html =
      |<div class="card c-month"><h2>Son 12 Ay - Gelen Belgeler</h2>{ lv_svg }| &&
      |<div class="mlg"><span style="background:#bfdbfe;"></span>Gelen| &&
      |<span style="background:#16a34a;"></span>Muhasebelesen</div></div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD supplier_card.
    DATA lv_width    TYPE p LENGTH 7 DECIMALS 1.
    DATA lv_max      TYPE p LENGTH 15 DECIMALS 2.
    DATA lv_currency TYPE waers.
    lv_max      = VALUE #( mt_supplier[ 1 ]-amount OPTIONAL ).
    lv_currency = VALUE #( mt_amount[ 1 ]-currency OPTIONAL ).
    DATA(lv_bars) = ``.

    LOOP AT mt_supplier INTO DATA(ls_supplier).
      lv_width = COND #( WHEN lv_max > 0 THEN ls_supplier-amount * 100 / lv_max ELSE 0 ).
      lv_bars = lv_bars &&
        |<div class="bar"><div class="nm">{ esc( ls_supplier-name ) }</div>| &&
        |<div class="tr"><div class="fl" style="width:{ lv_width }%;"></div></div>| &&
        |<div class="am">{ esc( format_amount( iv_amount = ls_supplier-amount iv_currency = lv_currency ) ) }</div></div>|.
    ENDLOOP.
    IF lv_bars IS INITIAL.
      lv_bars = |<div class="empty">Veri yok</div>| ##NO_TEXT.
    ENDIF.

    rv_html = |<div class="card c-supp"><h2>En Yuksek Tutarli 5 Satici</h2>{ lv_bars }</div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD recent_card.
    DATA(lt_recent) = mt_doc.
    SORT lt_recent BY received_at DESCENDING.
    DELETE lt_recent FROM 9.

    DATA(lv_rows) = ``.
    LOOP AT lt_recent INTO DATA(ls_doc).
      DATA(lv_color) = status_color( ls_doc-status ).
      DATA(lv_supplier) = COND string( WHEN ls_doc-supplier_name IS NOT INITIAL THEN |{ ls_doc-supplier_name }|
                                       ELSE `-` ).
      " Cari eslesmemisse turuncu uyari.
      DATA(lv_lifnr_cell) = COND string( WHEN ls_doc-lifnr IS NOT INITIAL
                                         THEN esc( |{ ls_doc-lifnr ALPHA = OUT }| )
                                         ELSE `<span class="warn">Eslesmedi</span>` ) ##NO_TEXT.
      DATA(lv_invoice)  = COND string( WHEN ls_doc-invoice_id IS NOT INITIAL THEN |{ ls_doc-invoice_id }|
                                       ELSE |{ ls_doc-provider_doc_id }| ).
      lv_rows = lv_rows &&
        |<tr><td>{ ls_doc-doc_date DATE = USER }</td>| &&
        |<td>{ esc( lv_invoice ) }</td>| &&
        |<td>{ esc( ls_doc-supplier_vkn ) }</td>| &&
        |<td>{ esc( lv_supplier ) }</td>| &&
        |<td>{ lv_lifnr_cell }</td>| &&
        |<td class="r">{ esc( format_amount( iv_amount = ls_doc-amount iv_currency = ls_doc-currency ) ) }</td>| &&
        |<td><span class="badge" style="background:{ lv_color };">{ esc( zcl_zone_iarc_status=>text( ls_doc-status ) ) }</span></td></tr>|.
    ENDLOOP.
    IF lv_rows IS INITIAL.
      lv_rows = |<tr><td colspan="7" class="empty">Belge yok</td></tr>| ##NO_TEXT.
    ENDIF.

    rv_html =
      |<div class="card"><h2>Son Gelen Belgeler</h2><table>| &&
      |<tr><th>Tarih</th><th>Fatura No</th><th>VKN/TCKN</th><th>Satici</th><th>Cari No</th>| &&
      |<th class="r">Tutar</th><th>Durum</th></tr>| &&
      lv_rows && |</table></div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD status_count.
    rv_count = VALUE #( mt_status[ status = iv_status ]-count OPTIONAL ).
  ENDMETHOD.

  METHOD status_color.
    rv_color = SWITCH #( iv_status
      WHEN 'NEW'       THEN `#94a3b8`
      WHEN 'PARSED'    THEN `#38bdf8`
      WHEN 'MAPPED'    THEN `#eab308`
      WHEN 'PARKED'    THEN `#1e6fd9`
      WHEN 'POSTED'    THEN `#16a34a`
      WHEN 'REJECTED'  THEN `#f59e0b`
      WHEN 'EXCEPTION' THEN `#dc2626`
      ELSE `#64748b` ).
  ENDMETHOD.

  METHOD format_amount.
    rv_text = |{ iv_amount NUMBER = USER DECIMALS = 2 } { iv_currency }|.
  ENDMETHOD.

  METHOD esc.
    rv_text = zcl_zone_iarc_doc_view=>escape( CONV string( iv_text ) ).
  ENDMETHOD.

ENDCLASS.
