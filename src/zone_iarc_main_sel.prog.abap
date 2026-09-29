*&---------------------------------------------------------------------*
*& Include ZONE_IARC_MAIN_SEL
*&---------------------------------------------------------------------*
*& Gosterge panelinin kapsami. Bos sirket kodu = tum sirketler.
*& Fatura tarihi varsayilani: son 12 ay (INITIALIZATION).
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS: s_bukrs FOR zone_iarc_t006-bukrs,
                  s_date  FOR zone_iarc_t006-doc_date.
SELECTION-SCREEN END OF BLOCK b01.
