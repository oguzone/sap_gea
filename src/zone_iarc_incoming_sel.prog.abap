*&---------------------------------------------------------------------*
*& Include ZONE_IARC_INCOMING_SEL
*&---------------------------------------------------------------------*
*& Secim ekrani. Bos birakilan kriter = filtre yok. Sirket kodu
*& zorunlu (tum sirketlerin tek seferde cekilmesini engeller).
*&---------------------------------------------------------------------*

" Belge anahtarlari
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS: s_bukrs FOR zone_iarc_t006-bukrs OBLIGATORY,
                  s_ettn  FOR zone_iarc_t006-ettn LOWER CASE,
                  s_invid FOR zone_iarc_t009-invoice_id,
                  s_docid FOR zone_iarc_t006-provider_doc_id.
SELECTION-SCREEN END OF BLOCK b01.

" Muhatap (gonderici / satici)
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
  SELECT-OPTIONS: s_vkn   FOR zone_iarc_t006-supplier_vkn,
                  s_sname FOR zone_iarc_t009-supplier_name LOWER CASE,
                  s_lifnr FOR zone_iarc_t006-lifnr.
SELECTION-SCREEN END OF BLOCK b02.

" Belge bilgileri
SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-b03.
  SELECT-OPTIONS: s_date FOR zone_iarc_t006-doc_date,
                  s_type FOR zone_iarc_t009-inv_type_code,
                  s_prof FOR zone_iarc_t009-profile_id,
                  s_curr FOR zone_iarc_t006-currency,
                  s_amnt FOR zone_iarc_t006-amount.
SELECTION-SCREEN END OF BLOCK b03.

" Isleme durumu / muhasebe
SELECTION-SCREEN BEGIN OF BLOCK b04 WITH FRAME TITLE TEXT-b04.
  SELECT-OPTIONS: s_stat  FOR zone_iarc_t006-status,
                  s_belnr FOR zone_iarc_t006-fi_belnr.
SELECTION-SCREEN END OF BLOCK b04.
