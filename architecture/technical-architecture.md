# Teknik Mimari — Gelen e-Arşiv Pipeline

> Namespace/isimlendirme için önce [package-structure.md](package-structure.md) okunmalı.

## Mimari İlkeler

- Pull tabanlı (polling) alım — Zonetegra push/webhook göndermez, SAP sorar
- Hiçbir belge kullanıcı onayı olmadan postalanmaz (**park + manuel onay**)
- Tek entegratör (Zonetegra) ama provider factory pattern korunur (test/mock ayrımı + ileride ikinci servis ihtimali)
- Ham UBL XML değiştirilmeden saklanır (GİB 10 yıl saklama yükümlülüğü)
- İş hatası (VKN eşleşmedi, tutar toleransı aşıldı) / teknik hata (servis erişilemedi) ayrımı — yalnız teknik hata retry edilir

## Ana Akış

```text
[SM36 job — ZONE_IARC_POLL rapor, periyot ZONE_IARC_T001.POLL_INTERVAL_MIN]
        │
        ▼
ZCL_ZONE_IARC_POLLER  (orchestrator, DI)
        │  ZIF_ZONE_IARC_PROVIDER.list_new_documents( bukrs, son_cekim_ts )
        ▼
Zonetegra servisi (SOAP/REST — sözleşme [?], bkz. risks-and-open-questions.md)
        │  ──► yeni belge referansları (UUID/ETTN listesi)
        ▼
   .get_document( doc_id ) → UBL XML (xstring) + zarf meta (gönderen VKN, tarih, tutar)
        │
        ▼
ZONE_IARC_T006 (kuyruk, STATUS=NEW) + ZONE_IARC_T007 (ham XML, RSTR alan)
        │
        ▼
ZCL_ZONE_IARC_PARSER   → UBL parse + zorunlu alan/şema kontrolü
        │                 + duplicate check (PROVIDER_DOC_ID unique key → idempotency)
        ▼
ZCL_ZONE_IARC_RESOLVER → gönderen VKN/TCKN → SAP tedarikçi (LIFNR)
        │                 bulunamazsa → STATUS=EXCEPTION, cockpit'te bekler
        ▼
ZCL_ZONE_IARC_MAPPER   → hesap/vergi kodu/PO eşleştirme stratejisi (ZONE_IARC_T005 kuralı)
        │
        ▼
ZCL_ZONE_IARC_POST     → PO var: MIRO PARK (BAPI_INCOMINGINVOICE_PARK)
        │                 PO yok: FI tedarikçi fatura PARK
        ▼
        STATUS=PARKED → ZCL_ZONE_IARC_COCKPIT (worklist, CL_GUI_ALV_GRID)
        │
        ▼ (kullanıcı: Onayla / Reddet)
ZCL_ZONE_IARC_REVIEW   → onay: park belgeyi postala (STATUS=POSTED, FI/MIRO belge no kuyruğa yazılır)
        │                 red: STATUS=REJECTED + zorunlu red nedeni
        ▼
ZCL_ZONE_IARC_LOG + ZONE_IARC_T008 — her adım (istek/cevap/hata) loglanır
```

## Katmanlar

1. Job / Orchestration (`ZCL_ZONE_IARC_POLLER`, `ZCL_ZONE_IARC_REVIEW`)
2. Provider Adapter (`ZIF_ZONE_IARC_PROVIDER` + `ZCL_ZONE_IARC_PROVIDER` / `ZCL_ZONE_IARC_MOCK`)
3. Parse / Resolve / Map (`ZCL_ZONE_IARC_PARSER`, `ZCL_ZONE_IARC_RESOLVER`, `ZCL_ZONE_IARC_MAPPER`)
4. Posting (`ZCL_ZONE_IARC_POST`) — standart SAP FI/MM BAPI'ları
5. Persistence/Log (`ZONE_IARC_T006/T007/T008`, `ZCL_ZONE_IARC_LOG`)
6. Configuration (`ZCL_ZONE_IARC_CONFIG`, `ZONE_IARC_T001..T005`)
7. Cockpit (`ZCL_ZONE_IARC_COCKPIT`)

## Hata Yönetimi

| Tür | Örnek | Davranış |
|---|---|---|
| İş hatası | VKN eşleşmedi, tutar toleransı aşıldı, zorunlu UBL alanı eksik, duplicate belge | STATUS=EXCEPTION, cockpit'te kullanıcı müdahalesi bekler, retry yok |
| Teknik hata | Servis erişilemedi, timeout, XML parse hatası, auth hatası | `ZONE_IARC_T003.RETRY_COUNT` kadar otomatik retry, sonra EXCEPTION |

## Yetkilendirme (özet)

Görüntüleme / Eşleştirme / Onaylama&Postalama / Reddetme ayrı `ACTVT` değerleri — muhasebe onay yetkisi ile entegrasyon/IT yetkisi ayrılmalı (SoD). Detay: [database-design.md](database-design.md) `Z_IARC` yetki nesnesi.

## Saklama (Arşiv) Gereksinimi

GİB mevzuatı gereği e-Arşiv belgeleri elektronik ortamda **en az 10 yıl** değiştirilmeden saklanmalı. `ZONE_IARC_T007.XML_RAW` (RSTR) + `CHECKSUM` (bütünlük doğrulama) bu amaçla tutulur. Hacim büyürse DB tablo yerine content repository (ArchiveLink/SAP DMS) + pointer saklama değerlendirilebilir (`[?]`, bkz. risks-and-open-questions.md).
