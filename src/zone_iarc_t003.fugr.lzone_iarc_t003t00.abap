*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZONE_IARC_T003................................*
DATA:  BEGIN OF STATUS_ZONE_IARC_T003              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZONE_IARC_T003              .
CONTROLS: TCTRL_ZONE_IARC_T003
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZONE_IARC_T003              .
TABLES: ZONE_IARC_T003               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
