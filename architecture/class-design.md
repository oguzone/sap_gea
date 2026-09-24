# Sınıf / Interface Tasarımı

> Uzunluk sınırları için önce [package-structure.md](package-structure.md) okunmalı — tüm isimler orada tanımlı 30 karakter bütçesine göre seçildi.

## Nesne Envanteri

| Nesne | Rol |
|---|---|
| `ZIF_ZONE_IARC_TYPES` | Canonical gelen fatura modeli (DDIC bağımsız — header + line yapıları) |
| `ZIF_ZONE_IARC_PROVIDER` | Entegratör (Bayt E-Belge Partner) sözleşmesi |
| `ZCL_ZONE_IARC_FACTORY` | Uyarlamadan (`ZONE_IARC_T002`/`T003`) provider seçer, dinamik instantiate eder |
| `ZCL_ZONE_IARC_BASE` | Adapter abstract base (ortak HTTP/log/hata mapping + T001 şirket/muhasebeci parametresi) |
| `ZCL_ZONE_IARC_PROVIDER` | **Bayt E-Belge Partner adapter (pilot, tek entegratör)** |
| `ZCL_ZONE_IARC_MOCK` | Test mock provider |
| `ZCL_ZONE_IARC_PARSER` | UBL-TR `ArchiveInvoice` parse → canonical model |
| `ZCL_ZONE_IARC_STORE` | Canonical modeli normalize tablolara yazar (`ZONE_IARC_T009..T014` — başlık/not/vergi/kalem/kalem-not/kalem-vergi) |
| `ZCL_ZONE_IARC_RESOLVER` | VKN/TCKN → LIFNR eşleme (LFA1 + `ZONE_IARC_T004` override) |
| `ZCL_ZONE_IARC_MAPPER` | Hesap/vergi/PO eşleştirme kuralları uygulama (`ZONE_IARC_T005`) |
| `ZCL_ZONE_IARC_POST` | MIRO/FI park + onay sonrası post |
| `ZCL_ZONE_IARC_REVIEW` | Cockpit onay/red orchestrator (DI) |
| `ZCL_ZONE_IARC_POLLER` | Uçtan uca polling orchestrator (DI) — job entry noktası |
| `ZCL_ZONE_IARC_CONFIG` | Uyarlama okumanın tek yeri (no-hardcode) |
| `ZCL_ZONE_IARC_LOG` | Log yazma/okuma |
| `ZCL_ZONE_IARC_COCKPIT` | Worklist (**`CL_GUI_ALV_GRID`**, `CL_SALV_TABLE` değil) |
| `ZCX_ZONE_IARC_ROOT` | Kök exception |
| `ZCX_ZONE_IARC_PROVIDER` | Adapter/servis erişim hatası |
| `ZCX_ZONE_IARC_MAPPING` | Eşleme/hesap belirleme hatası |

## `ZIF_ZONE_IARC_PROVIDER` Sözleşmesi

> Bayt E-Belge Partner gerçek API'siyle doğrulandı (`program/decision-log.md` Karar 010): `list_new_documents` → `GetInvoiceListExt`, `get_document` → `GetByInvoiceNoExt` + `DownloadFileExt` (iki adım, tek metot arkasında gizli). `AuthenticateExt` adapter içinde (interface'te görünmez) çağrılır. Ack servisi yok — orijinal tasarımdaki `acknowledge_document` kaldırıldı.

```abap
INTERFACE zif_zone_iarc_provider PUBLIC.

  METHODS list_new_documents
    IMPORTING iv_bukrs TYPE bukrs
              iv_since TYPE timestampl
    RETURNING VALUE(rt_refs) TYPE STANDARD TABLE OF zif_zone_iarc_types=>ty_doc_ref.

  METHODS get_document
    IMPORTING iv_bukrs           TYPE bukrs
              iv_provider_doc_id TYPE string   " Bayt InvoiceNo
              iv_supplier_tax_no TYPE string   " Bayt SupplierTaxNumber - InvoiceNo tek basina yetmiyor
    EXPORTING ev_xml             TYPE xstring
              es_meta            TYPE zif_zone_iarc_types=>ty_doc_meta.

  METHODS get_provider_key
    RETURNING VALUE(rv_key) TYPE char10.

ENDINTERFACE.
```

**Sözleşme kuralları:**

- `list_new_documents`/`get_document` idempotent davranmalı. `get_document` tekrar çağrılsa da `ZONE_IARC_T006.PROVIDER_DOC_ID` unique key ile dedupe edilir (Bayt'ta ayrıca ack mekanizması yok).
- Adapter loglama yapmaz; logger (`ZCL_ZONE_IARC_LOG`) constructor injection ile alınır.
- Hata durumunda adapter `ZCX_ZONE_IARC_PROVIDER` fırlatır.
- Response JSON şeması henüz doğrulanmadı (`program/risks-and-open-questions.md` S8) — `ZCL_ZONE_IARC_PROVIDER` içindeki alan adı varsayımları gerçek örnekle doğrulanmalı.

## Provider Factory Akışı

```text
ZCL_ZONE_IARC_FACTORY.get_provider( iv_bukrs )
  1. ZONE_IARC_T001'den BUKRS aktif mi kontrol
  2. ZONE_IARC_T002'den ACTIVE_FLG='X' PROVIDER_KEY → ADAPTER_CLASS
  3. CREATE OBJECT lo_provider TYPE (lv_class)
  4. Constructor'da ZONE_IARC_T003 (endpoint+auth) + logger inject
  5. RETURN lo_provider  " REF TO zif_zone_iarc_provider
```

Çekirdek orchestrator (`ZCL_ZONE_IARC_POLLER`) yalnızca `ZIF_ZONE_IARC_PROVIDER` referansıyla çalışır; `ZCL_ZONE_IARC_PROVIDER` (Bayt) veya `ZCL_ZONE_IARC_MOCK` (test) ismini bilmez.

## Adapter Sorumluluk Sınırı

Adapter (`ZCL_ZONE_IARC_PROVIDER`) **yapar:** HTTP/SOAP/REST çağrısı, provider payload ↔ standart yapı dönüşümü, provider hata kodu → `ZCX_ZONE_IARC_PROVIDER` eşleme.

Adapter **yapmaz:** UBL parse (bu `ZCL_ZONE_IARC_PARSER`'da), tedarikçi eşleme, muhasebe kuralı, loglamayı kendi başına (logger enjekte edilir), cockpit/UI.

## Bağımlılık Yönetimi

- `ZCL_ZONE_IARC_POLLER`/`ZCL_ZONE_IARC_REVIEW` provider sınıfını ismen tanımaz — yalnız `ZIF_ZONE_IARC_PROVIDER`.
- Constructor injection tercih edilir; service locator anti-pattern'ından kaçınılır.
- Posting (`ZCL_ZONE_IARC_POST`) yalnızca standart SAP FI/MM BAPI'larına bağımlıdır (`BAPI_INCOMINGINVOICE_PARK`/`_POST` ve FI karşılığı) — üçüncü parti kütüphane yok.
