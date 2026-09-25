CLASS zcl_zone_iarc_secret DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Sifre/secret okuma-yazma icin TEK yer. Musteri tablolarinda (T001.
    " ACC_PWD_KEY, T003.SECSTORE_KEY) sadece bir REFERANS ANAHTAR ADI
    " tutulur - gercek deger hicbir zaman DDIC tabloda duz metin
    " saklanmaz. Gercek deger SAP'nin guvenli depolamasinda (Secure
    " Storage) tutulur.
    "
    " *** DOGRULANMASI GEREKEN NOKTA (bkz. program/risks-and-open-
    " questions.md S11/S7) ***: CL_SECSTORE_ADMIN bu asagida kullanilan
    " metot imzalariyla (GET_DATA/SET_DATA) bu SAP surumunde mevcut
    " olmayabilir - eski/farkli surumlerde farkli bir API (orn. eski
    " SECSTORE FM'leri veya CL_SECSTORAGE) gerekebilir. WRITE/READ
    " metotlari BURADA TEK YERDE tutuldugu icin, API farkli cikarsa
    " sadece bu iki metot duzeltilir - cagiran hicbir yer degismez.
    CONSTANTS gc_area TYPE string VALUE 'ZONE_IARC'.

    CLASS-METHODS read
      IMPORTING
        !iv_key TYPE string
      RETURNING
        VALUE(rv_value) TYPE string
      RAISING
        zcx_zone_iarc_provider.

    CLASS-METHODS write
      IMPORTING
        !iv_key   TYPE string
        !iv_value TYPE string
      RAISING
        zcx_zone_iarc_provider.

    " Deger var mi diye kontrol eder - GERCEK DEGERI ASLA DONMEZ/
    " GORUNTULEMEZ. Bakim raporunda "kayitli mi?" gostermek icin kullanilir.
    CLASS-METHODS exists
      IMPORTING
        !iv_key TYPE string
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_secret IMPLEMENTATION.

  METHOD read.
    TRY.
        rv_value = cl_secstore_admin=>get_data(
          area = gc_area
          id   = iv_key ).
      CATCH cx_root INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_zone_iarc_provider
          EXPORTING
            previous      = lx_error
            iv_error_code = 'IARC_SEC_001'
            iv_detail     = |Secret okunamadi (key: { iv_key }) - CL_SECSTORE_ADMIN bu sistemde dogrulanmali (S7/S11)|.
    ENDTRY.

    IF rv_value IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zone_iarc_provider
        EXPORTING
          iv_error_code = 'IARC_SEC_002'
          iv_detail     = |Secret bos veya kayitli degil (key: { iv_key })|.
    ENDIF.
  ENDMETHOD.

  METHOD write.
    TRY.
        cl_secstore_admin=>set_data(
          area  = gc_area
          id    = iv_key
          value = iv_value ).
        COMMIT WORK.
      CATCH cx_root INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_zone_iarc_provider
          EXPORTING
            previous      = lx_error
            iv_error_code = 'IARC_SEC_003'
            iv_detail     = |Secret yazilamadi (key: { iv_key }) - CL_SECSTORE_ADMIN bu sistemde dogrulanmali (S7/S11)|.
    ENDTRY.
  ENDMETHOD.

  METHOD exists.
    TRY.
        DATA(lv_value) = read( iv_key ).
        rv_exists = xsdbool( lv_value IS NOT INITIAL ).
      CATCH zcx_zone_iarc_provider.
        rv_exists = abap_false.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
