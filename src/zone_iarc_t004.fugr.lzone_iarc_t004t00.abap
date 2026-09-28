*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZONE_IARC_T004................................*
DATA:  BEGIN OF STATUS_ZONE_IARC_T004              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZONE_IARC_T004              .
CONTROLS: TCTRL_ZONE_IARC_T004
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZONE_IARC_T004              .
TABLES: ZONE_IARC_T004               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
