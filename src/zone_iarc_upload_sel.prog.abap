*&---------------------------------------------------------------------*
*& Include ZONE_IARC_UPLOAD_SEL
*&---------------------------------------------------------------------*
*& Secim ekrani. Test modu varsayilan olarak ACIK - once belge kontrol
*& edilir, veritabanina hicbir sey yazilmaz.
*&---------------------------------------------------------------------*

" Belge
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS: p_bukrs TYPE bukrs OBLIGATORY,
              p_file  TYPE rlgrap-filename LOWER CASE OBLIGATORY,
              p_docid TYPE zone_iarc_t006-provider_doc_id.   " bos = UBL cbc:ID
SELECTION-SCREEN END OF BLOCK b01.

" Calisma modu
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
  PARAMETERS: p_test AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b02.
