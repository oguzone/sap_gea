*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZONE_IARC_T005................................*
DATA:  BEGIN OF STATUS_ZONE_IARC_T005              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZONE_IARC_T005              .
CONTROLS: TCTRL_ZONE_IARC_T005
            TYPE TABLEVIEW USING SCREEN '0001'.
*.........table declarations:.................................*
TABLES: *ZONE_IARC_T005              .
TABLES: ZONE_IARC_T005               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
