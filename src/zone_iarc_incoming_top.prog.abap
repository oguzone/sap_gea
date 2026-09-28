*&---------------------------------------------------------------------*
*& Include ZONE_IARC_INCOMING_TOP
*&---------------------------------------------------------------------*
*& SELECT-OPTIONS ... FOR tablo-alan kullanimi icin TABLES zorunlu
*& (bkz. program/decision-log.md Karar 009). GO_APP: calisan uygulama
*& nesnesi (liste ekrani acikken grid olaylari buna bagli).
*&---------------------------------------------------------------------*
TABLES: zone_iarc_t006,
        zone_iarc_t009.

CLASS lcl_app DEFINITION DEFERRED.
DATA go_app TYPE REF TO lcl_app.   " liste ekrani acikken grid'i yasatir
