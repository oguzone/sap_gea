*&---------------------------------------------------------------------*
*& Include ZONE_IARC_MAIN_TOP
*&---------------------------------------------------------------------*
*& SELECT-OPTIONS ... FOR tablo-alan icin TABLES (Karar 009). GO_APP:
*& calisan uygulama nesnesi (0100 ekrani acikken kontroller buna bagli).
*&---------------------------------------------------------------------*
TABLES zone_iarc_t006.

CLASS lcl_app DEFINITION DEFERRED.
DATA go_app TYPE REF TO lcl_app.
