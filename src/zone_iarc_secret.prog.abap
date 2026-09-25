REPORT zone_iarc_secret.

" Hassas deger (PartnerPassCode / AccountantUserPassword) bakim raporu.
" Amac: sifre HICBIR ZAMAN duz metin customizing tablosunda (ZONE_IARC_T001/
" T003) tutulmaz - oralarda sadece bir REFERANS ANAHTAR ADI (orn.
" "BAYT_PARTNER_PASSCODE") tutulur. Gercek deger bu rapor uzerinden
" ZCL_ZONE_IARC_SECRET araciligiyla SAP Secure Storage'a yazilir.
"
" Bu rapor WRITE-ONLY'dir: girilen deger hicbir zaman geri okunup
" ekranda gosterilmez, sadece "kayitli mi?" bilgisi (var/yok) gosterilir.
" Sifre alanlari SCREEN-INVISIBLE ile maskelenir (klasik, ozel dynpro
" gerektirmeyen bir teknik).

TABLES: sscrfields.

SELECTION-SCREEN FUNCTION KEY 1. " Kaydet
SELECTION-SCREEN FUNCTION KEY 2. " Kontrol Et

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_key TYPE string LOWER CASE OBLIGATORY.
SELECTION-SCREEN SKIP.
SELECTION-SCREEN COMMENT /1(79) TEXT-002.
PARAMETERS: p_pwd1 TYPE string LOWER CASE,
            p_pwd2 TYPE string LOWER CASE.
SELECTION-SCREEN END OF BLOCK b1.

INITIALIZATION.
  sscrfields-functxt_01 = 'Kaydet'.
  sscrfields-functxt_02 = 'Kontrol Et'.

AT SELECTION-SCREEN OUTPUT.
  " Sifre alanlarini maskele (yazilan karakterler gorunmesin).
  LOOP AT SCREEN.
    IF screen-name = 'P_PWD1' OR screen-name = 'P_PWD2'.
      screen-invisible = 1.
      screen-input     = 1.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      PERFORM save_secret.
    WHEN 'FC02'.
      PERFORM check_secret.
  ENDCASE.

FORM save_secret.
  IF p_key IS INITIAL.
    MESSAGE 'Once bir anahtar adi girin (orn. BAYT_PARTNER_PASSCODE)' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF p_pwd1 IS INITIAL.
    MESSAGE 'Yeni deger bos olamaz' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF p_pwd1 <> p_pwd2.
    MESSAGE 'Girilen iki deger birbiriyle eslesmiyor' TYPE 'S' DISPLAY LIKE 'E'.
    CLEAR: p_pwd1, p_pwd2.
    RETURN.
  ENDIF.

  TRY.
      zcl_zone_iarc_secret=>write( iv_key = p_key iv_value = p_pwd1 ).
      MESSAGE |{ p_key } icin deger kaydedildi| TYPE 'S'.
    CATCH zcx_zone_iarc_provider INTO DATA(lx_error).
      MESSAGE lx_error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

  " Ekrandaki degeri hemen temizle - bellekte tutulmasin.
  CLEAR: p_pwd1, p_pwd2.
ENDFORM.

FORM check_secret.
  IF p_key IS INITIAL.
    MESSAGE 'Once bir anahtar adi girin' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF zcl_zone_iarc_secret=>exists( p_key ) = abap_true.
    MESSAGE |{ p_key } icin bir deger kayitli (deger goruntulenmez)| TYPE 'S'.
  ELSE.
    MESSAGE |{ p_key } icin kayitli bir deger yok| TYPE 'S' DISPLAY LIKE 'W'.
  ENDIF.
ENDFORM.
