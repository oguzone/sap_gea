*&---------------------------------------------------------------------*
*& Include ZONE_IARC_UPLOAD_TOP
*&---------------------------------------------------------------------*
*& Global tanimlar. Durum lokal siniflarda tutulur; burada yalnizca
*& kontrol sonucu siddet sabitleri var.
*&---------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF gc_severity,
    error   TYPE c LENGTH 1 VALUE 'E',   " aktarimi engeller
    warning TYPE c LENGTH 1 VALUE 'W',   " aktarilir, dikkat gerekir
    info    TYPE c LENGTH 1 VALUE 'I',
  END OF gc_severity.
