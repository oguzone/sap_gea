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
*&   - ZONE_IARC_INCOMING_MOD : 0100 ekrani modulleri (LCL_APP'e delege)
*&   - Ekran 0100             : CC_MAIN custom container (tam ekran)
*&   - ZCL_ZONE_IARC_GRID     : Veri okuma + ust/alt grid ALV
*&
*& Olay bloklari bilerek ince tutuldu - tum mantik siniflarda.
*&---------------------------------------------------------------------*
REPORT zone_iarc_incoming.

INCLUDE zone_iarc_incoming_top.   " TABLES, global tanimlar
INCLUDE zone_iarc_incoming_sel.   " Secim ekrani
INCLUDE zone_iarc_incoming_cls.   " Lokal siniflar
INCLUDE zone_iarc_incoming_mod.   " 0100 ekrani PBO/PAI modulleri

*&---------------------------------------------------------------------*
*& Olaylar
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  " F8: 0100 ekraninda split grid (ust liste / alt detay). Geri (F3)
  " secim ekranina doner (Karar 024).
  go_app = NEW #( ).
  go_app->execute( ).
