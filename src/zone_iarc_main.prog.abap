*&---------------------------------------------------------------------*
*& Report ZONE_IARC_MAIN
*&---------------------------------------------------------------------*
*& Gelen e-Arsiv Kokpit (Karar 033/034). Tek giris noktasi - secim ekrani
*& olmadan dogrudan acilir:
*&   - Sol: gruplanmis butonlar (belgeler, aktarim, uyarlama, izleme) -
*&     ilgili programi / SM30 bakimini / islemi acar.
*&   - Sag: HTML gosterge paneli (ZCL_ZONE_IARC_DASHBOARD) - aktif sirket
*&     kodlari (ZONE_IARC_T001), son 12 ay.
*&
*& Sorumluluklar:
*&   - ZONE_IARC_MAIN_TOP : Global tanimlar
*&   - ZONE_IARC_MAIN_CLS : LCL_SCOPE (kapsam), LCL_LAUNCHER (buton ->
*&                          hedef), LCL_APP (akis)
*&   - ZONE_IARC_MAIN_MOD : 0100 ekrani PBO/PAI modulleri
*&   - Ekran 0100         : sol butonlar + CC_DASH custom container
*&---------------------------------------------------------------------*
REPORT zone_iarc_main.

INCLUDE zone_iarc_main_top.   " Global tanimlar
INCLUDE zone_iarc_main_cls.   " Lokal siniflar
INCLUDE zone_iarc_main_mod.   " 0100 ekrani modulleri

*&---------------------------------------------------------------------*
*& Olaylar
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  go_app = NEW #( ).
  go_app->run( ).
