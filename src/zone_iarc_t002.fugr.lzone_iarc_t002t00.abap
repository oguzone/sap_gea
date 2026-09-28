*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZONE_IARC_T002................................*
DATA:  BEGIN OF STATUS_ZONE_IARC_T002              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZONE_IARC_T002              .
CONTROLS: TCTRL_ZONE_IARC_T002
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZONE_IARC_T002              .
TABLES: ZONE_IARC_T002               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
