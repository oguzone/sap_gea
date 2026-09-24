REPORT zone_iarc_grid.

" Gelen e-Arsiv split-screen grid ALV cockpit. Ust: belge listesi,
" alt: secili belgenin detayi (Kalemler/Vergi-KDV/Dip Toplamlar/Notlar
" arasinda arac cubugu butonlariyla gecis). ZCL_ZONE_IARC_GRID icinde
" CL_GUI_DOCKING_CONTAINER dogrudan secim ekranina baglanir - ozel
" dynpro yok (egdp-abap/ZCL_EGDP_COCKPIT'te dogrulanmis teknik, bkz.
" program/decision-log.md Karar 015).

PARAMETERS: p_bukrs TYPE bukrs OBLIGATORY,
            p_stat  TYPE zone_iarc_t006-status.

DATA go_grid TYPE REF TO zcl_zone_iarc_grid.

INITIALIZATION.
  go_grid = NEW zcl_zone_iarc_grid( ).

AT SELECTION-SCREEN OUTPUT.
  go_grid->run( iv_bukrs = p_bukrs iv_status = p_stat ).
