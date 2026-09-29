*&---------------------------------------------------------------------*
*& Report ZONE_IARC_MAIN
*&---------------------------------------------------------------------*
*& Gelen e-Arsiv Kokpit (Karar 033). Tek giris noktasi:
*&   - Sol: gruplanmis butonlar (belgeler, aktarim, uyarlama, izleme) -
*&     ilgili programi / SM30 bakimini / islemi acar.
*&   - Sag: HTML gosterge paneli (ZCL_ZONE_IARC_DASHBOARD) - KPI'lar,
*&     durum dagilimi, son 12 ay grafigi, en yuksek saticilar, son belgeler.
*&
*& Sorumluluklar:
*&   - ZONE_IARC_MAIN_TOP : Global tanimlar
*&   - ZONE_IARC_MAIN_SEL : Secim ekrani (sirket kodu, fatura tarihi)
*&   - ZONE_IARC_MAIN_CLS : LCL_LAUNCHER (buton -> hedef), LCL_APP (akis)
*&   - ZONE_IARC_MAIN_MOD : 0100 ekrani PBO/PAI modulleri
*&   - Ekran 0100         : sol butonlar + CC_DASH custom container
*&---------------------------------------------------------------------*
REPORT zone_iarc_main.

INCLUDE zone_iarc_main_top.   " Global tanimlar
INCLUDE zone_iarc_main_sel.   " Secim ekrani
INCLUDE zone_iarc_main_cls.   " Lokal siniflar
INCLUDE zone_iarc_main_mod.   " 0100 ekrani modulleri

*&---------------------------------------------------------------------*
*& Olaylar
*&---------------------------------------------------------------------*
INITIALIZATION.
  lcl_app=>set_default_period( ).

START-OF-SELECTION.
  go_app = NEW #( ).
  go_app->run( ).
