*&---------------------------------------------------------------------*
*& Report ZONE_IARC_UPLOAD
*&---------------------------------------------------------------------*
*& Manuel UBL aktarimi - yerel bilgisayardaki bir e-Arsiv UBL XML
*& dosyasini okur, parse eder, kontrol eder ve (test modu kapaliysa)
*& entegratorden gelmis gibi ayni pipeline'a sokar (Karar 019).
*&
*& Sorumluluklar:
*&   - ZONE_IARC_UPLOAD_TOP : Global tanimlar
*&   - ZONE_IARC_UPLOAD_SEL : Secim ekrani
*&   - ZONE_IARC_UPLOAD_CLS : LCX_UPLOAD  - program ici hata
*&                            LCL_FILE    - yerel dosya okuma / F4
*&                            LCL_CHECKER - on kontroller (E/W/I)
*&                            LCL_OUTPUT  - sonuc listesi
*&                            LCL_APP     - akis
*&   - ZCL_ZONE_IARC_INTAKE : Kuyruk -> parse -> store -> resolve ->
*&                            map -> park (poller ile ortak)
*&---------------------------------------------------------------------*
REPORT zone_iarc_upload.

INCLUDE zone_iarc_upload_top.   " Global tanimlar
INCLUDE zone_iarc_upload_sel.   " Secim ekrani
INCLUDE zone_iarc_upload_cls.   " Lokal siniflar

*&---------------------------------------------------------------------*
*& Olaylar
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  lcl_file=>f4( CHANGING cv_path = p_file ).

START-OF-SELECTION.
  NEW lcl_app( )->run( ).
