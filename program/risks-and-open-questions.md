# Açık Sorular ve Riskler

Durum etiketleri: `[ ]` Başlanmadı · `[~]` Devam ediyor · `[x]` Tamamlandı · `[!]` Bloke · `[?]` Karar bekliyor

## Açık Sorular

| # | Soru | Etki | Durum |
|---|---|---|---|
| S1 | ~~Gerçek entegratör API sözleşmesi nedir~~ — **büyük ölçüde çözüldü (2026-09-24):** entegratör **Bayt E-Belge Partner** (`ebelge.baytapi.com`), REST/JSON, `AuthenticateExt`/`GetInvoiceListExt`/`GetByInvoiceNoExt`/`DownloadFileExt`, request şemaları Postman koleksiyonuyla doğrulandı (Karar 010). **Kalan kısım → S8.** | Adapter (`ZCL_ZONE_IARC_PROVIDER`) request tarafı wiring edildi | `[~]` |
| S2 | ~~Ack mekanizması var mı~~ — **kesin çözüldü:** Bayt API'sinde ack/teyit servisi **yok**. Dedup tamamen `ZONE_IARC_T006.PROVIDER_DOC_ID` (InvoiceNo) unique key ile yapılır. Arayüzden `acknowledge_document` kaldırıldı. | Idempotency tasarımı | `[x]` |
| S8 | **(kritik)** Bayt response JSON şemaları doğrulanmadı — Postman koleksiyonu sadece REQUEST örnekleri içeriyor: `AuthenticateExt` Token alan adı, `GetInvoiceListExt` liste eleman alanları (InvoiceNo/SupplierTaxNumber varsayıldı), `GetByInvoiceNoExt` indirme URL alan adı, `DownloadFileExt` içerik formatı (JSON+base64 mü, ham dosya mı) — hepsi varsayım/TODO olarak kod içinde işaretli | `ZCL_ZONE_IARC_PROVIDER` gerçek bir test çağrısı yapılmadan güvenilir çalışmaz | `[?]` |
| S9 | Bayt Token'ı ~6 saat geçerli görünüyor (JWT `exp`-`iat` farkı) — şu an her `list_new_documents`/`get_document` çağrısında yeniden `AuthenticateExt` çağrılıyor (basit ama gereksiz yük). Token cache/yeniden kullanım eklenmeli mi? | Performans/servis yükü optimizasyonu | `[ ]` |
| S10 | `GetInvoiceListExt`'teki `TaxNumber` alanının amacı belirsiz (belirli karşı taraf filtresi mi, zorunlu mu) — şu an boş string gönderiliyor | Yanlış/eksik filtre riski | `[?]` |
| S11 | `PartnerPassCode`/`AccountantUserPassword` için `ZCL_ZONE_IARC_SECRET`, `CL_SECSTORE_ADMIN=>GET_DATA`/`SET_DATA` ile en-iyi-çaba (best-effort) yazıldı — **bu sistemde hiç test edilmedi** (sürüme bağlı, bkz. S7); sınıf/metot adları farklı çıkarsa yalnızca bu tek sınıf düzeltilmeli | Adapter gerçek ortamda çalışamaz bu doğrulanmadan | `[~]` |
| S3 | PO'suz senaryoda varsayılan GL hesabı/vergi kodu ne olacak, hangi durumlarda kullanıcıya sorulacak (tek genel kural mı, tedarikçi grubu bazlı mı)? | `ZONE_IARC_T005` alan doldurma | `[?]` |
| S4 | Ham XML saklama: DB tablo (`ZONE_IARC_T007`) mü yeterli, yoksa hacim nedeniyle content repository (ArchiveLink/SAP DMS) mı gerekli? | Saklama mimarisi, GİB 10 yıl yükümlülüğü | `[?]` |
| S5 | Bu ürün ileride kayıtlı bir SAP namespace'e veya MDP `/MDPES/` ailesine taşınacak mı? | Namespace/nesne adı göç planı | `[?]` |
| S6 | Transport layer / software component / local (`$TMP`) mü transportable paket mi? | Paket açılış detayı | `[?]` |
| S7 | Hedef SAP sürümü (S/4HANA mı ECC mi, hangi release)? | `ZCL_ZONE_IARC_POST` BAPI parametre detayları (S/4'te bazı MM alanları farklı); `CL_OSQL_TEST_ENVIRONMENT` tabanlı DB-bağımlı ABAP Unit testleri yalnızca ≥7.51'de mevcut — sürüm teyit edilmeden `zcl_zone_iarc_config`/`_resolver`/`_mapper` için test yazılmadı | `[?]` |

## Riskler

| # | Risk | Kategori | Azaltma |
|---|---|---|---|
| R1 | ~~API dokümantasyonu gecikirse adapter geliştirme başlayamaz~~ — Bayt Postman koleksiyonu alındı (2026-09-24), risk büyük ölçüde kapandı; kalan risk response şeması yanlış varsayılırsa adapter'ın gerçek ortamda hata vermesi (bkz. S8) | Entegrasyon | Mock provider (`ZCL_ZONE_IARC_MOCK`) ile pipeline'ın geri kalanı paralel geliştirilebilir; gerçek response örneği alınınca `ZCL_ZONE_IARC_PROVIDER` düzeltilmeli |
| R2 | VKN/TCKN → LIFNR eşleşmesi bulunamayan belgeler birikirse cockpit'te iş yükü oluşur | SAP veri kalitesi | `ZONE_IARC_T004` manuel override tablosu + pre-flight kontrol |
| R3 | PO'suz senaryoda hatalı GL/vergi varsayımı yanlış muhasebe kaydına yol açabilir | Muhasebe doğruluğu | Park + manuel onay zorunluluğu (Karar 002) bu riski büyük ölçüde azaltıyor — otomatik post tercih edilmedi |
| R4 | `ZONE_IARC` önekiyle yeni DDIC/class eklerken uzunluk sınırı aşılabilir | Teknik/DDIC | Yeni nesne eklemeden önce [../architecture/package-structure.md](../architecture/package-structure.md) kontrol listesi zorunlu |
