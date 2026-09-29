CLASS zcl_zone_iarc_summary_html DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " ZONE_IARC_INCOMING ust ALV'nin ustundeki ozet paneli icin HTML uretir
    " (Karar 027). Sol: sirket karti. Sag: KPI kutulari, durum dagilimi
    " (SVG halka grafik), en yuksek tutarli 5 satici (cubuk grafik).
    "
    " SAP GUI HTML kontrolu IE motoruyla calisabilir - bu yuzden yalnizca
    " IE11 uyumlu CSS (flexbox, CSS degiskeni yok, grid yok), inline SVG,
    " JavaScript ve dis kutuphane YOK. CSS '...' literalleriyle kurulur
    " ('{' string template'te ifade sinirlayicidir - Karar 013).

    TYPES:
      BEGIN OF ty_doc,
        bukrs         TYPE zone_iarc_t006-bukrs,
        status        TYPE zone_iarc_t006-status,
        amount        TYPE zone_iarc_t006-amount,
        currency      TYPE zone_iarc_t006-currency,
        supplier_vkn  TYPE zone_iarc_t006-supplier_vkn,
        lifnr         TYPE zone_iarc_t006-lifnr,       " bos = cari eslesmemis
        supplier_name TYPE zone_iarc_t009-supplier_name,
      END OF ty_doc.
    TYPES tt_doc TYPE STANDARD TABLE OF ty_doc WITH DEFAULT KEY.

    METHODS build
      IMPORTING
        !it_doc        TYPE tt_doc
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
      tt_supplier TYPE STANDARD TABLE OF ty_supplier WITH DEFAULT KEY.

    DATA mt_doc      TYPE tt_doc.
    DATA mt_status   TYPE tt_status.
    DATA mt_amount   TYPE tt_amount.
    DATA mt_supplier TYPE tt_supplier.

    METHODS aggregate.
    METHODS css
      RETURNING VALUE(rv_css) TYPE string.
    METHODS company_card
      RETURNING VALUE(rv_html) TYPE string.
    METHODS kpi_block
      RETURNING VALUE(rv_html) TYPE string.
    METHODS kpi
      IMPORTING
        !iv_label      TYPE string
        !iv_value      TYPE string
        !iv_color      TYPE string
      RETURNING
        VALUE(rv_html) TYPE string.
    METHODS status_card
      RETURNING VALUE(rv_html) TYPE string.
    METHODS supplier_card
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



CLASS zcl_zone_iarc_summary_html IMPLEMENTATION.

  METHOD build.
    mt_doc = it_doc.
    aggregate( ).

    rv_html =
      |<!DOCTYPE html><html><head>| &&
      |<meta http-equiv="X-UA-Compatible" content="IE=edge">| &&
      |<style>| && css( ) && |</style></head><body>| &&
      |<div class="wrap">| &&
      company_card( ) &&
      kpi_block( ) &&
      status_card( ) &&
      supplier_card( ) &&
      |</div></body></html>|.
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
    DELETE mt_supplier FROM 6.   " en yuksek 5
  ENDMETHOD.

  METHOD css.
    rv_css =
      '*{box-sizing:border-box;margin:0;padding:0;}' &&
      'html,body{height:100%;}' &&
      'body{font-family:"Segoe UI",Arial,sans-serif;font-size:12px;color:#1f2937;' &&
      'background:#eef2f7;padding:8px;overflow:hidden;}' &&
      '.wrap{display:flex;height:100%;}' &&
      '.card{background:#ffffff;border-radius:10px;padding:10px 14px;margin-right:8px;' &&
      'box-shadow:0 1px 3px rgba(15,23,42,0.10);overflow:hidden;}' &&
      '.card h2{font-size:11px;font-weight:600;color:#64748b;text-transform:uppercase;' &&
      'letter-spacing:0.6px;margin-bottom:8px;}' &&
      '.company{flex:0 0 24%;color:#ffffff;' &&
      'background:linear-gradient(135deg,#0b3d91 0%,#1e6fd9 100%);}' &&
      '.company h1{font-size:17px;font-weight:600;line-height:1.2;margin-bottom:2px;}' &&
      '.company .sub{font-size:11px;opacity:0.8;margin-bottom:8px;}' &&
      '.kv{display:flex;justify-content:space-between;padding:3px 0;' &&
      'border-bottom:1px solid rgba(255,255,255,0.18);}' &&
      '.kv .k{opacity:0.75;}' &&
      '.kv .v{font-weight:600;}' &&
      '.kpis{flex:0 0 34%;display:flex;flex-wrap:wrap;align-content:space-between;margin-right:8px;}' &&
      '.kpi{width:32%;height:calc(50% - 4px);margin-right:2%;background:#ffffff;border-radius:10px;padding:8px 12px;' &&
      'box-shadow:0 1px 3px rgba(15,23,42,0.10);border-left:4px solid #1e6fd9;' &&
      'display:flex;flex-direction:column;justify-content:center;}' &&
      '.kpi:nth-child(3n){margin-right:0;}' &&
      '.kpi .l{font-size:10px;color:#64748b;text-transform:uppercase;letter-spacing:0.5px;}' &&
      '.kpi .n{font-size:20px;font-weight:700;margin-top:4px;white-space:nowrap;}' &&
      '.status{flex:0 0 19%;}' &&
      '.donut{display:flex;align-items:center;}' &&
      '.legend{margin-left:10px;}' &&
      '.lg{display:flex;align-items:center;margin:3px 0;white-space:nowrap;}' &&
      '.dot{width:9px;height:9px;border-radius:50%;margin-right:6px;}' &&
      '.lg b{margin-left:6px;}' &&
      '.suppliers{flex:1;margin-right:0;}' &&
      '.bar{display:flex;align-items:center;margin:5px 0;}' &&
      '.bar .nm{width:38%;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}' &&
      '.bar .tr{flex:1;height:10px;background:#eef2f7;border-radius:5px;margin:0 8px;}' &&
      '.bar .fl{height:10px;border-radius:5px;' &&
      'background:linear-gradient(90deg,#1e6fd9 0%,#38bdf8 100%);}' &&
      '.bar .am{width:26%;text-align:right;white-space:nowrap;font-weight:600;}' &&
      '.empty{color:#94a3b8;}'.
  ENDMETHOD.

  METHOD company_card.
    " Birden fazla sirket kodu listelendiyse ilki gosterilir, digerleri sayilir.
    DATA lt_bukrs TYPE STANDARD TABLE OF bukrs WITH DEFAULT KEY.
    LOOP AT mt_doc INTO DATA(ls_doc).
      IF NOT line_exists( lt_bukrs[ table_line = ls_doc-bukrs ] ).
        APPEND ls_doc-bukrs TO lt_bukrs.
      ENDIF.
    ENDLOOP.
    DATA(lv_bukrs) = VALUE bukrs( lt_bukrs[ 1 ] OPTIONAL ).

    SELECT SINGLE butxt, ort01, land1, waers FROM t001
      WHERE bukrs = @lv_bukrs
      INTO @DATA(ls_t001).
    SELECT SINGLE comp_tax_no FROM zone_iarc_t001
      WHERE bukrs = @lv_bukrs
      INTO @DATA(lv_tax_no).

    DATA(lv_name) = COND string( WHEN ls_t001-butxt IS NOT INITIAL THEN ls_t001-butxt
                                 ELSE |Sirket { lv_bukrs }| ) ##NO_TEXT.
    DATA(lv_more) = COND string( WHEN lines( lt_bukrs ) > 1
                                 THEN | (+{ lines( lt_bukrs ) - 1 } sirket)| ELSE `` ) ##NO_TEXT.

    " Bos bilgiler icin "-" (bos deger / "A110 - / TR" gibi yarim satir olmasin).
    DATA(lv_location) = condense( |{ ls_t001-ort01 } { ls_t001-land1 }| ).
    DATA(lv_sub) = |Sirket Kodu { lv_bukrs }{ lv_more }| &&
                   COND string( WHEN lv_location IS NOT INITIAL THEN | - { lv_location }| ) ##NO_TEXT.
    DATA(lv_vkn) = COND string( WHEN lv_tax_no IS NOT INITIAL THEN |{ lv_tax_no }| ELSE `-` ).

    rv_html =
      |<div class="card company">| &&
      |<h1>{ esc( lv_name ) }</h1>| &&
      |<div class="sub">{ esc( lv_sub ) }</div>| &&
      |<div class="kv"><span class="k">VKN</span><span class="v">{ esc( lv_vkn ) }</span></div>| &&
      |<div class="kv"><span class="k">Para Birimi</span><span class="v">{ esc( ls_t001-waers ) }</span></div>| &&
      |<div class="kv"><span class="k">Kullanici</span><span class="v">{ esc( sy-uname ) }</span></div>| &&
      |<div class="kv"><span class="k">Rapor Zamani</span>| &&
      |<span class="v">{ sy-datum DATE = USER } { sy-uzeit TIME = USER }</span></div>| &&
      |</div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD kpi_block.
    " Toplam tutar: en buyuk para birimi; baska para birimi varsa sayisi eklenir.
    DATA(ls_main) = VALUE ty_amount( mt_amount[ 1 ] OPTIONAL ).
    DATA(lv_total) = format_amount( iv_amount = ls_main-amount iv_currency = ls_main-currency ).
    IF lines( mt_amount ) > 1.
      lv_total = |{ lv_total } +{ lines( mt_amount ) - 1 }|.
    ENDIF.

    DATA(lv_posted) = status_count( 'PARKED' ) + status_count( 'POSTED' ).
    DATA(lv_no_vendor) = REDUCE i( INIT n = 0 FOR ls_doc IN mt_doc WHERE ( lifnr IS INITIAL ) NEXT n = n + 1 ).

    rv_html =
      |<div class="kpis">| &&
      kpi( iv_label = `Toplam Belge`     iv_value = |{ lines( mt_doc ) }|              iv_color = `#1e6fd9` ) &&
      kpi( iv_label = `Toplam Tutar`     iv_value = lv_total                          iv_color = `#7c3aed` ) &&
      kpi( iv_label = `Muhasebe`         iv_value = |{ lv_posted }|                   iv_color = `#16a34a` ) &&
      kpi( iv_label = `Cari Eslesmeyen`  iv_value = |{ lv_no_vendor }|                iv_color = `#f59e0b` ) &&
      kpi( iv_label = `Hatali`           iv_value = |{ status_count( 'EXCEPTION' ) }| iv_color = `#dc2626` ) &&
      kpi( iv_label = `Muhasebeye Hazir` iv_value = |{ status_count( 'MAPPED' ) }|    iv_color = `#eab308` ) &&
      |</div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD kpi.
    rv_html =
      |<div class="kpi" style="border-left-color:{ iv_color };">| &&
      |<div class="l">{ esc( iv_label ) }</div>| &&
      |<div class="n">{ esc( iv_value ) }</div></div>|.
  ENDMETHOD.

  METHOD status_card.
    " SVG halka: r=15.915 -> cevre = 100, stroke-dasharray yuzde olarak verilir.
    DATA(lv_total) = lines( mt_doc ).
    DATA lv_pct    TYPE p LENGTH 7 DECIMALS 2.
    DATA lv_offset TYPE p LENGTH 7 DECIMALS 2 VALUE 25.
    DATA lv_rest   TYPE p LENGTH 7 DECIMALS 2.

    DATA(lv_svg) =
      |<svg width="96" height="96" viewBox="0 0 42 42">| &&
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
        |{ esc( ls_status-status ) }<b>{ ls_status-count }</b></div>|.
    ENDLOOP.

    lv_svg = lv_svg &&
      |<text x="21" y="23.5" text-anchor="middle" font-size="8" font-weight="700" fill="#1f2937">{ lv_total }</text>| &&
      |</svg>|.

    rv_html =
      |<div class="card status"><h2>Durum Dagilimi</h2>| &&
      |<div class="donut">{ lv_svg }<div class="legend">{ lv_legend }</div></div></div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD supplier_card.
    DATA lv_width TYPE p LENGTH 7 DECIMALS 1.
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

    rv_html = |<div class="card suppliers"><h2>En Yuksek Tutarli 5 Satici</h2>{ lv_bars }</div>| ##NO_TEXT.
  ENDMETHOD.

  METHOD status_count.
    rv_count = VALUE #( mt_status[ status = iv_status ]-count OPTIONAL ).
  ENDMETHOD.

  METHOD status_color.
    rv_color = SWITCH #( iv_status
      WHEN 'NEW'       THEN `#94a3b8`
      WHEN 'PARSED'    THEN `#38bdf8`
      WHEN 'MAPPED'    THEN `#1e6fd9`
      WHEN 'PARKED'    THEN `#16a34a`
      WHEN 'POSTED'    THEN `#15803d`
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
