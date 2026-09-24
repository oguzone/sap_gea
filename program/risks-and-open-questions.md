# Açık Sorular ve Riskler

Durum etiketleri: `[ ]` Başlanmadı · `[~]` Devam ediyor · `[x]` Tamamlandı · `[!]` Bloke · `[?]` Karar bekliyor

## Açık Sorular

| # | Soru | Etki | Durum |
|---|---|---|---|
| S1 | Zonetegra servisinin gerçek API sözleşmesi nedir (`list`/`get`/`ack` endpoint, protokol SOAP/REST, auth türü, sayfalama, `since` parametresi timestamp mi sequence mi)? | Adapter (`ZCL_ZONE_IARC_PROVIDER`) gerçek wiring'i bu olmadan yapılamaz | `[?]` |
| S2 | Zonetegra `acknowledge_document` (teyit) mekanizması sunuyor mu, yoksa dedupe tamamen `ZONE_IARC_T006.PROVIDER_DOC_ID` unique key ile mi yapılacak? | Idempotency tasarımı | `[?]` |
| S3 | PO'suz senaryoda varsayılan GL hesabı/vergi kodu ne olacak, hangi durumlarda kullanıcıya sorulacak (tek genel kural mı, tedarikçi grubu bazlı mı)? | `ZONE_IARC_T005` alan doldurma | `[?]` |
| S4 | Ham XML saklama: DB tablo (`ZONE_IARC_T007`) mü yeterli, yoksa hacim nedeniyle content repository (ArchiveLink/SAP DMS) mı gerekli? | Saklama mimarisi, GİB 10 yıl yükümlülüğü | `[?]` |
| S5 | Bu ürün ileride kayıtlı bir SAP namespace'e veya MDP `/MDPES/` ailesine taşınacak mı? | Namespace/nesne adı göç planı | `[?]` |
| S6 | Transport layer / software component / local (`$TMP`) mü transportable paket mi? | Paket açılış detayı | `[?]` |
| S7 | Hedef SAP sürümü (S/4HANA mı ECC mi, hangi release)? | `ZCL_ZONE_IARC_POST` BAPI parametre detayları (S/4'te bazı MM alanları farklı); `CL_OSQL_TEST_ENVIRONMENT` tabanlı DB-bağımlı ABAP Unit testleri yalnızca ≥7.51'de mevcut — sürüm teyit edilmeden `zcl_zone_iarc_config`/`_resolver`/`_mapper` için test yazılmadı | `[?]` |

## Riskler

| # | Risk | Kategori | Azaltma |
|---|---|---|---|
| R1 | Zonetegra API dokümantasyonu gecikirse adapter geliştirme başlayamaz | Entegrasyon | Mock provider (`ZCL_ZONE_IARC_MOCK`) ile pipeline'ın geri kalanı paralel geliştirilebilir |
| R2 | VKN/TCKN → LIFNR eşleşmesi bulunamayan belgeler birikirse cockpit'te iş yükü oluşur | SAP veri kalitesi | `ZONE_IARC_T004` manuel override tablosu + pre-flight kontrol |
| R3 | PO'suz senaryoda hatalı GL/vergi varsayımı yanlış muhasebe kaydına yol açabilir | Muhasebe doğruluğu | Park + manuel onay zorunluluğu (Karar 002) bu riski büyük ölçüde azaltıyor — otomatik post tercih edilmedi |
| R4 | `ZONE_IARC` önekiyle yeni DDIC/class eklerken uzunluk sınırı aşılabilir | Teknik/DDIC | Yeni nesne eklemeden önce [../architecture/package-structure.md](../architecture/package-structure.md) kontrol listesi zorunlu |
