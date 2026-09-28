*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZONE_IARC_T017................................*
DATA:  BEGIN OF STATUS_ZONE_IARC_T017              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZONE_IARC_T017              .
CONTROLS: TCTRL_ZONE_IARC_T017
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZONE_IARC_T017              .
TABLES: ZONE_IARC_T017               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
