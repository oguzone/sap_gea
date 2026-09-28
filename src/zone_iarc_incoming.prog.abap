*&---------------------------------------------------------------------*
*& Report ZONE_IARC_INCOMING
*&---------------------------------------------------------------------*
*& Gelen e-Arsiv belgeleri - split-screen grid ALV (eski adi
*& ZONE_IARC_GRID, bkz. program/decision-log.md Karar 018).
*&
*& Sorumluluklar:
*&   - ZONE_IARC_INCOMING_TOP : TABLES (SELECT-OPTIONS ... FOR icin)
*&   - ZONE_IARC_INCOMING_SEL : Secim ekrani (4 blok, 14 kriter)
*&   - ZONE_IARC_INCOMING_CLS : LCL_APP - secim ekranini filtreye
*&                              cevirir, ZCL_ZONE_IARC_GRID'e devreder
*&   - ZCL_ZONE_IARC_GRID     : Veri okuma + ust/alt grid ALV
*&
*& Olay bloklari bilerek ince tutuldu - tum mantik siniflarda.
*&---------------------------------------------------------------------*
REPORT zone_iarc_incoming.

INCLUDE zone_iarc_incoming_top.   " TABLES, global tanimlar
INCLUDE zone_iarc_incoming_sel.   " Secim ekrani
INCLUDE zone_iarc_incoming_cls.   " Lokal siniflar

*&---------------------------------------------------------------------*
*& Olaylar
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
  " Grid, docking container ile AKTIF secim ekranina baglanir; her
  " PBO'da guncel secim kriterleriyle liste yenilenir (Enter = yenile).
  lcl_app=>get( )->on_selection_screen_output( ).
