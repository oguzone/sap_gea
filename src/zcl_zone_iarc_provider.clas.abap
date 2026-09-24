CLASS zcl_zone_iarc_provider DEFINITION
  PUBLIC
  INHERITING FROM zcl_zone_iarc_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_zone_iarc_provider.

    METHODS constructor.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_zone_iarc_provider IMPLEMENTATION.

  METHOD constructor.
    super->constructor( iv_provider_key = 'ZONETEGRA' ).
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~get_provider_key.
    rv_key = 'ZONETEGRA'.
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~list_new_documents.
    " BILEREK IMPLEMENTE EDILMEDI: Zonetegra'nin gercek LIST servis
    " sozlesmesi (protokol, request/response semasi, SINCE parametresi
    " formati, sayfalama) henuz dogrulanmadi - bkz.
    " program/risks-and-open-questions.md S1. Gercek HTTP cagrisi bu bilgi
    " gelmeden yazilirsa hatali/tahmini bir sozlesme kod tabanina girer.
    " Simdilik ZCL_ZONE_IARC_MOCK ile pipeline'in geri kalani test edilir.
    RAISE EXCEPTION TYPE zcx_zone_iarc_provider
      EXPORTING
        iv_error_code = 'IARC_PROV_001'
        iv_detail     = 'Zonetegra LIST servis sozlesmesi henuz dogrulanmadi (TODO)'.
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~get_document.
    RAISE EXCEPTION TYPE zcx_zone_iarc_provider
      EXPORTING
        iv_error_code = 'IARC_PROV_002'
        iv_detail     = 'Zonetegra GET servis sozlesmesi henuz dogrulanmadi (TODO)'.
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~acknowledge_document.
    " ACK servisi opsiyonel olabilir (bkz. risks-and-open-questions.md S2);
    " sozlesme netlesmeden no-op birakildi.
  ENDMETHOD.

ENDCLASS.
