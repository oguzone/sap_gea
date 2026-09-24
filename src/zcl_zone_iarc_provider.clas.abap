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
    " Token onbelleklenmiyor - her BUKRS icin polling cagrisi basina bir kez
    " AuthenticateExt cagrilir (basit ve dogru, ama optimum degil; token
    " 6 saat gecerli gorunuyor [JWT exp-iat farki] - onbellekleme ileride
    " eklenebilir, bkz. program/risks-and-open-questions.md S9).

    METHODS authenticate
      IMPORTING
        !iv_bukrs TYPE bukrs
      RETURNING
        VALUE(rv_token) TYPE string
      RAISING
        zcx_zone_iarc_provider.

    METHODS http_post
      IMPORTING
        !iv_url  TYPE string
        !iv_body TYPE string
      RETURNING
        VALUE(rv_response) TYPE string
      RAISING
        zcx_zone_iarc_provider.

    METHODS json_escape
      IMPORTING
        !iv_value TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.
ENDCLASS.



CLASS zcl_zone_iarc_provider IMPLEMENTATION.

  METHOD constructor.
    super->constructor( iv_provider_key = 'BAYT' ).
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~get_provider_key.
    rv_key = 'BAYT'.
  ENDMETHOD.

  METHOD json_escape.
    rv_value = iv_value.
    REPLACE ALL OCCURRENCES OF '\' IN rv_value WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_value WITH '\"'.
  ENDMETHOD.

  METHOD http_post.
    TRY.
        cl_http_client=>create_by_url(
          EXPORTING url    = iv_url
          IMPORTING client = DATA(lo_client) ).
      CATCH cx_root INTO DATA(lx_create).
        RAISE EXCEPTION TYPE zcx_zone_iarc_provider
          EXPORTING
            previous      = lx_create
            iv_error_code = 'IARC_PROV_020'
            iv_detail     = |HTTP client olusturulamadi: { iv_url }|.
    ENDTRY.

    lo_client->propertytype_logon_popup = if_http_client=>co_disabled.
    lo_client->request->set_method( if_http_request=>co_request_method_post ).
    lo_client->request->set_content_type( 'application/json' ).
    lo_client->request->set_cdata( iv_body ).

    IF mv_timeout_sec > 0.
      lo_client->set_timeout_ms( mv_timeout_sec * 1000 ).
    ENDIF.

    lo_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        http_invalid_timeout       = 4
        OTHERS                     = 5 ).
    IF sy-subrc <> 0.
      lo_client->close( ).
      RAISE EXCEPTION TYPE zcx_zone_iarc_provider
        EXPORTING
          iv_error_code = 'IARC_PROV_021'
          iv_detail     = |Bayt servisine gonderim basarisiz (sy-subrc={ sy-subrc }): { iv_url }|.
    ENDIF.

    lo_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).
    IF sy-subrc <> 0.
      lo_client->close( ).
      RAISE EXCEPTION TYPE zcx_zone_iarc_provider
        EXPORTING
          iv_error_code = 'IARC_PROV_022'
          iv_detail     = |Bayt servisinden cevap alinamadi (sy-subrc={ sy-subrc }): { iv_url }|.
    ENDIF.

    lo_client->response->get_status( IMPORTING code = DATA(lv_code) reason = DATA(lv_reason) ).
    rv_response = lo_client->response->get_cdata( ).
    lo_client->close( ).

    IF lv_code <> 200.
      RAISE EXCEPTION TYPE zcx_zone_iarc_provider
        EXPORTING
          iv_error_code = 'IARC_PROV_023'
          iv_detail     = |Bayt HTTP { lv_code } { lv_reason }: { iv_url }|.
    ENDIF.
  ENDMETHOD.

  METHOD authenticate.
    get_company_params(
      EXPORTING iv_bukrs          = iv_bukrs
      IMPORTING ev_comp_tax_no    = DATA(lv_comp_tax_no)
                ev_comp_serial_no = DATA(lv_comp_serial_no)
                ev_acc_user_code  = DATA(lv_acc_user_code)
                ev_acc_password   = DATA(lv_acc_password) ).

    DATA(lv_partner_pass) = read_secret( 'BAYT_PARTNER_PASSCODE' ).

    " Alan adlari AuthenticateExt request'inden birebir (Postman koleksiyonu
    " ile dogrulandi - bkz. program/decision-log.md Karar 010).
    DATA(lv_body) =
      |\{| &&
      |"PartnerPassCode":"{ json_escape( lv_partner_pass ) }",| &&
      |"AccountantUserCode":"{ json_escape( lv_acc_user_code ) }",| &&
      |"AccountantUserPassword":"{ json_escape( lv_acc_password ) }",| &&
      |"CompanyTaxNumber":"{ json_escape( lv_comp_tax_no ) }",| &&
      |"CompanySerialNo":"{ json_escape( lv_comp_serial_no ) }"| &&
      |\}|.

    DATA(lv_response) = http_post( iv_url = mv_endpoint_auth iv_body = lv_body ).

    " TODO S8: response semasi dogrulanmadi - "Token" alan adi PascalCase
    " tutarliligina dayanarak varsayildi (request'lerde Token boyle
    " kullaniliyor). Gercek response ornegi gelince dogrulanmali.
    TYPES: BEGIN OF ty_auth_response,
             token TYPE string,
           END OF ty_auth_response.
    DATA ls_response TYPE ty_auth_response.
    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_response pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data = ls_response ).

    IF ls_response-token IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zone_iarc_provider
        EXPORTING
          iv_error_code = 'IARC_PROV_024'
          iv_detail     = 'AuthenticateExt yanitindan Token okunamadi (response semasi dogrulanmali)'.
    ENDIF.
    rv_token = ls_response-token.
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~list_new_documents.
    get_company_params(
      EXPORTING iv_bukrs          = iv_bukrs
      IMPORTING ev_comp_tax_no    = DATA(lv_comp_tax_no)
                ev_comp_serial_no = DATA(lv_comp_serial_no)
                ev_acc_user_code  = DATA(lv_acc_user_code)
                ev_acc_tax_no     = DATA(lv_acc_tax_no) ).

    DATA(lv_token)         = authenticate( iv_bukrs ).
    DATA(lv_partner_pass)  = read_secret( 'BAYT_PARTNER_PASSCODE' ).

    CONVERT TIME STAMP iv_since TIME ZONE sy-zonlo INTO DATE DATA(lv_since_date) TIME DATA(lv_since_time).
    DATA(lv_start_date) = |{ lv_since_date+0(4) }-{ lv_since_date+4(2) }-{ lv_since_date+6(2) }|.
    DATA(lv_end_date)   = |{ sy-datum+0(4) }-{ sy-datum+4(2) }-{ sy-datum+6(2) }|.

    " TaxNumber alaninin amaci (belirli bir karsi taraf filtresi mi, yoksa
    " zorunlu bir alan mi) Postman'da acik degil - bos birakildi, TODO S8.
    DATA(lv_body) =
      |\{| &&
      |"PartnerPassCode":"{ json_escape( lv_partner_pass ) }",| &&
      |"CompanyTaxNumber":"{ json_escape( lv_comp_tax_no ) }",| &&
      |"CompanySerialNo":"{ json_escape( lv_comp_serial_no ) }",| &&
      |"AccountantUserCode":"{ json_escape( lv_acc_user_code ) }",| &&
      |"AccountantTaxNumber":"{ json_escape( lv_acc_tax_no ) }",| &&
      |"CustomerType":"alici",| &&
      |"TaxNumber":"",| &&
      |"StartDate":"{ lv_start_date }",| &&
      |"EndDate":"{ lv_end_date }",| &&
      |"EInvoiceType":0,| &&
      |"Token":"{ lv_token }"| &&
      |\}|.

    DATA(lv_response) = http_post( iv_url = mv_endpoint_list iv_body = lv_body ).

    " TODO S8: response semasi (liste elemani alan adlari: InvoiceNo,
    " SupplierTaxNumber varsayildi) dogrulanmadi - gercek ornek gelince
    " duzeltilmeli.
    TYPES: BEGIN OF ty_list_item,
             invoice_no        TYPE string,
             supplier_tax_no   TYPE string,
           END OF ty_list_item.
    DATA lt_items TYPE STANDARD TABLE OF ty_list_item WITH EMPTY KEY.
    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_response pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data = lt_items ).

    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    LOOP AT lt_items INTO DATA(ls_item).
      APPEND VALUE #(
        provider_doc_id = ls_item-invoice_no
        supplier_tax_no = ls_item-supplier_tax_no
        received_at     = lv_now ) TO rt_refs.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_zone_iarc_provider~get_document.
    get_company_params(
      EXPORTING iv_bukrs          = iv_bukrs
      IMPORTING ev_comp_tax_no    = DATA(lv_comp_tax_no)
                ev_comp_serial_no = DATA(lv_comp_serial_no)
                ev_acc_user_code  = DATA(lv_acc_user_code)
                ev_acc_tax_no     = DATA(lv_acc_tax_no) ).

    DATA(lv_token)        = authenticate( iv_bukrs ).
    DATA(lv_partner_pass) = read_secret( 'BAYT_PARTNER_PASSCODE' ).

    " Adim 1: GetByInvoiceNoExt - belge detayi (indirme URL'i icerdigi
    " varsayiliyor, TODO S8). CustomerTaxNumber = bizim sirket (biz aliciyiz,
    " gelen belge senaryosu).
    DATA(lv_get_body) =
      |\{| &&
      |"PartnerPassCode":"{ json_escape( lv_partner_pass ) }",| &&
      |"CompanyTaxNumber":"{ json_escape( lv_comp_tax_no ) }",| &&
      |"CompanySerialNo":"{ json_escape( lv_comp_serial_no ) }",| &&
      |"SupplierTaxNumber":"{ json_escape( iv_supplier_tax_no ) }",| &&
      |"CustomerTaxNumber":"{ json_escape( lv_comp_tax_no ) }",| &&
      |"InvoiceNo":"{ json_escape( iv_provider_doc_id ) }",| &&
      |"AccountantUserCode":"{ json_escape( lv_acc_user_code ) }",| &&
      |"AccountantTaxNumber":"{ json_escape( lv_acc_tax_no ) }",| &&
      |"EInvoiceType":0,| &&
      |"Token":"{ lv_token }"| &&
      |\}|.

    DATA(lv_get_response) = http_post( iv_url = mv_endpoint_get iv_body = lv_get_body ).

    " TODO S8: alan adlari (Url, Amount, Currency, IssueDate) varsayim -
    " gercek response ornegi ile dogrulanmali.
    TYPES: BEGIN OF ty_detail_response,
             url      TYPE string,
             amount   TYPE string,
             currency TYPE string,
             issue_date TYPE string,
           END OF ty_detail_response.
    DATA ls_detail TYPE ty_detail_response.
    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_get_response pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data = ls_detail ).

    IF ls_detail-url IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zone_iarc_provider
        EXPORTING
          iv_error_code = 'IARC_PROV_025'
          iv_detail     = |GetByInvoiceNoExt yanitindan indirme URL'i okunamadi: { iv_provider_doc_id }|.
    ENDIF.

    " Adim 2: DownloadFileExt - dosya icerigi. Response'un JSON icinde
    " base64 mi, yoksa dogrudan XML/binary mi dondugu dogrulanmadi (TODO
    " S8); asagida "iceriginBase64" varsayimi ile yaziliyor.
    DATA(lv_download_body) =
      |\{| &&
      |"PartnerPassCode":"{ json_escape( lv_partner_pass ) }",| &&
      |"CompanyTaxNumber":"{ json_escape( lv_comp_tax_no ) }",| &&
      |"CompanySerialNo":"{ json_escape( lv_comp_serial_no ) }",| &&
      |"Url":"{ json_escape( ls_detail-url ) }"| &&
      |\}|.

    DATA(lv_download_response) = http_post( iv_url = mv_endpoint_download iv_body = lv_download_body ).

    TYPES: BEGIN OF ty_download_response,
             content_base64 TYPE string,
           END OF ty_download_response.
    DATA ls_download TYPE ty_download_response.
    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_download_response pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data = ls_download ).

    IF ls_download-content_base64 IS NOT INITIAL.
      TRY.
          ev_xml = cl_http_utility=>decode_x_base64( ls_download-content_base64 ).
        CATCH cx_root INTO DATA(lx_decode).
          RAISE EXCEPTION TYPE zcx_zone_iarc_provider
            EXPORTING
              previous      = lx_decode
              iv_error_code = 'IARC_PROV_026'
              iv_detail     = 'DownloadFileExt icerigi base64 decode edilemedi'.
      ENDTRY.
    ELSE.
      " Response JSON degil, dogrudan dosya govdesi olabilir (TODO S8) -
      " bu durumda http_post yerine raw response gerekir; simdilik hata.
      RAISE EXCEPTION TYPE zcx_zone_iarc_provider
        EXPORTING
          iv_error_code = 'IARC_PROV_027'
          iv_detail     = 'DownloadFileExt response formati dogrulanmadi (TODO)'.
    ENDIF.

    es_meta-supplier_vkn = iv_supplier_tax_no.
    es_meta-currency     = ls_detail-currency.
    IF ls_detail-issue_date CO '0123456789' AND strlen( ls_detail-issue_date ) = 8.
      es_meta-doc_date = ls_detail-issue_date.
    ENDIF.
    IF ls_detail-amount IS NOT INITIAL.
      es_meta-amount = ls_detail-amount.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
