# Teknik Mimari — Gelen e-Arşiv Pipeline

> Namespace/isimlendirme için önce [package-structure.md](package-structure.md) okunmalı.

## Mimari İlkeler

- Pull tabanlı (polling) alım — Bayt push/webhook göndermez, SAP sorar
- Hiçbir belge kullanıcı onayı olmadan postalanmaz (**park + manuel onay**)
- Tek entegratör (Bayt E-Belge Partner, `ebelge.baytapi.com`) ama provider factory pattern korunur (test/mock ayrımı + ileride ikinci servis ihtimali)
- Ham UBL XML değiştirilmeden saklanır (GİB 10 yıl saklama yükümlülüğü)
- İş hatası (VKN eşleşmedi, tutar toleransı aşıldı) / teknik hata (servis erişilemedi) ayrımı — yalnız teknik hata retry edilir

## Ana Akış

> Entegratör API'si "Bayt E-Belge Partner" (Postman koleksiyonuyla doğrulandı — `program/decision-log.md` Karar 010). Request şemaları kesin; **response şemaları henüz doğrulanmadı** (S8).

```text
[SM36 job — ZONE_IARC_POLL rapor, periyot ZONE_IARC_T001.POLL_INTERVAL_MIN]
        │
        ▼
ZCL_ZONE_IARC_POLLER  (orchestrator, DI)
        │  ZIF_ZONE_IARC_PROVIDER.list_new_documents( bukrs, son_cekim_ts )
        ▼
ZCL_ZONE_IARC_PROVIDER (Bayt adapter)
        │  1. AuthenticateExt → Token (PartnerPassCode + BUKRS'a ait muhasebeci/şirket bilgisi)
        │  2. GetInvoiceListExt (CustomerType="alici" → BİZ ALICIYIZ = gelen belge,
        │     EInvoiceType=0 → e-Arşiv, StartDate/EndDate) → belge referans listesi (InvoiceNo + SupplierTaxNumber)
        ▼
   .get_document( bukrs, invoice_no, supplier_tax_no )
        │  3. GetByInvoiceNoExt (InvoiceNo+SupplierTaxNumber+CustomerTaxNumber=biz) → belge detayı + indirme URL'i [?]
        │  4. DownloadFileExt (Url) → dosya içeriği (UBL XML, format [?])
        ▼
ZONE_IARC_T006 (kuyruk, STATUS=NEW) + ZONE_IARC_T007 (ham XML, RSTR alan)
        │
        ▼
ZCL_ZONE_IARC_PARSER   → UBL parse + zorunlu alan/şema kontrolü
        │                 + duplicate check (PROVIDER_DOC_ID unique key → idempotency)
        ▼
ZCL_ZONE_IARC_STORE    → normalize UBL modeli yazılır: ZONE_IARC_T009 (başlık,
        │                 tam tutar dökümü) + T010 (başlık notu) + T011 (başlık
        │                 vergi alt toplamı) + T012 (kalem) + T013 (kalem notu)
        │                 + T014 (kalem vergi alt toplamı) — hepsi BUKRS+ETTN
        │                 (+ kalemler için LINE_NO) ile birbirine bağlı
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
3. Parse / Store / Resolve / Map (`ZCL_ZONE_IARC_PARSER`, `ZCL_ZONE_IARC_STORE`, `ZCL_ZONE_IARC_RESOLVER`, `ZCL_ZONE_IARC_MAPPER`)
4. Posting (`ZCL_ZONE_IARC_POST`) — standart SAP FI/MM BAPI'ları
5. Persistence/Log (`ZONE_IARC_T006/T007/T008` kuyruk+XML+log, `ZONE_IARC_T009..T014` normalize UBL verisi, `ZCL_ZONE_IARC_LOG`)
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
