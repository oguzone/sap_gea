*&---------------------------------------------------------------------*
*& Include ZONE_IARC_INCOMING_MOD
*&---------------------------------------------------------------------*
*& 0100 ekrani modulleri - mantik yok, LCL_APP'e delege eder.
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  go_app->on_pbo( ).
ENDMODULE.

MODULE user_command_0100 INPUT.
  go_app->on_pai( sy-ucomm ).
ENDMODULE.
