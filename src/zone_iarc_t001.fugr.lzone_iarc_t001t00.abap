*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZONE_IARC_T001................................*
DATA:  BEGIN OF STATUS_ZONE_IARC_T001              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZONE_IARC_T001              .
CONTROLS: TCTRL_ZONE_IARC_T001
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZONE_IARC_T001              .
TABLES: ZONE_IARC_T001               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
