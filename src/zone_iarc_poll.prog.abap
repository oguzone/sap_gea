REPORT zone_iarc_poll.

" SM36 arka plan job'inda calistirilir (periyot ZONE_IARC_T001.
" POLL_INTERVAL_MIN'e gore planlanir - job zamanlamasi henuz otomatik
" okumuyor, TODO). Bayt E-Belge Partner servisinden yeni belgeleri ceker,
" parse/resolve/map/park pipeline'ini calistirir.

PARAMETERS: p_bukrs TYPE bukrs OBLIGATORY.

START-OF-SELECTION.
  DATA(lt_messages) = NEW zcl_zone_iarc_poller( )->run( p_bukrs ).

  LOOP AT lt_messages INTO DATA(ls_msg).
    WRITE: / ls_msg-type, ls_msg-message.
  ENDLOOP.

  IF lt_messages IS INITIAL.
    WRITE: / 'Calisma tamamlandi, hata mesaji yok (detay: ZONE_IARC_T008 log tablosu).'.
  ENDIF.
