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

" XML/HTML gosterimi ZCL_ZONE_IARC_DOC_VIEW'de (Karar 025 - grid ile ortak).

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
    WHEN 'FC01' OR 'FC02'.
      IF p_docid IS INITIAL.
        MESSAGE 'Once bir belge (provider doc id) girin' TYPE 'S' DISPLAY LIKE 'E' ##NO_TEXT.
      ELSEIF sscrfields-ucomm = 'FC01'.
        zcl_zone_iarc_doc_view=>show_xml( p_docid ).
      ELSE.
        zcl_zone_iarc_doc_view=>show_html( p_docid ).
      ENDIF.
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
    " GT_LIST yerel bir tip (T006+T009 birlesimi), tek bir DDIC yapisi
    " yok - I_STRUCTURE_NAME verilemedigi icin alan katalogu elle kurulur,
    " yoksa "alan katalogu bulunamadi" hatasi alinir.
    DATA(lt_fcat) = VALUE slis_t_fieldcat_alv(
      ddictxt = 'M'
      ( fieldname = 'PROVIDER_DOC_ID' ref_tabname = 'ZONE_IARC_T006' ref_fieldname = 'PROVIDER_DOC_ID' seltext_m = 'Fatura No (Bayt)' )
      ( fieldname = 'INVOICE_ID'      ref_tabname = 'ZONE_IARC_T009' ref_fieldname = 'INVOICE_ID'      seltext_m = 'UBL Fatura No' )
      ( fieldname = 'ETTN'            ref_tabname = 'ZONE_IARC_T006' ref_fieldname = 'ETTN'            seltext_m = 'ETTN' )
      ( fieldname = 'BUKRS'           ref_tabname = 'ZONE_IARC_T006' ref_fieldname = 'BUKRS'           seltext_m = 'Sirket Kodu' )
      ( fieldname = 'STATUS'          ref_tabname = 'ZONE_IARC_T006' ref_fieldname = 'STATUS'          seltext_m = 'Durum' )
      ( fieldname = 'SUPPLIER_VKN'    ref_tabname = 'ZONE_IARC_T006' ref_fieldname = 'SUPPLIER_VKN'    seltext_m = 'Satici VKN' )
      ( fieldname = 'SUPPLIER_NAME'   ref_tabname = 'ZONE_IARC_T009' ref_fieldname = 'SUPPLIER_NAME'   seltext_m = 'Satici Adi' )
      ( fieldname = 'DOC_DATE'        ref_tabname = 'ZONE_IARC_T006' ref_fieldname = 'DOC_DATE'        seltext_m = 'Fatura Tarihi' )
      ( fieldname = 'AMOUNT'          ref_tabname = 'ZONE_IARC_T006' ref_fieldname = 'AMOUNT'          seltext_m = 'Tutar'
        cfieldname = 'CURRENCY' )
      ( fieldname = 'CURRENCY'        ref_tabname = 'ZONE_IARC_T006' ref_fieldname = 'CURRENCY'        seltext_m = 'Para Birimi' )
      ( fieldname = 'PAYABLE_AMOUNT'  ref_tabname = 'ZONE_IARC_T009' ref_fieldname = 'PAYABLE_AMOUNT'  seltext_m = 'Odenecek Tutar'
        cfieldname = 'CURRENCY' ) ) ##NO_TEXT.

    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      EXPORTING
        it_fieldcat   = lt_fcat
      TABLES
        t_outtab      = gt_list
      EXCEPTIONS
        program_error = 1
        OTHERS        = 2.
  ENDIF.
