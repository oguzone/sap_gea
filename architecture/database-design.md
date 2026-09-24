# DDIC & Uyarlama (Customizing) Spesifikasyonu

> Önce [package-structure.md](package-structure.md) — özellikle uzunluk sınırları tablosu — okunmalı. Bu yüzden tüm tablolar açıklayıcı son ek yerine **sıra numarasıyla** (`T001`, `T002`, …) adlandırılmıştır; anlamı buradaki tablo ile takip edilir.

Domain/Data Element **kullanılmıyor** — `ZONE_IARC_` öneki (10 karakter) sonrası 16 karakterlik sınırda anlamlı bir isme yer kalmıyor (kardeş projede aynı sorun yaşanmıştı). Alan tipi standart data element (`CHAR`/`XFELD`/`BUKRS`/`DATUM`/`TIMESTAMPL`/`LIFNR`/`SAKNR`/`MWSKZ`/`WAERS`) ile tanımlanır; enum doğrulama (`STATUS` değerleri, `SERVICE_TYPE` değerleri vb.) kod seviyesinde (`ZCL_ZONE_IARC_CONFIG` veya ilgili sınıf) yapılır.

**DD03P-DATATYPE kısa kod hatırlatması** (kardeş projede gerçek aktivasyon hatasına yol açmıştı): metin alanı için `STRG` (STRING değil), ham/binary için `RSTR` (XSTRING değil).

## Customizing Tabloları (delivery class C)

### `ZONE_IARC_T001` — BUKRS aktivasyon + Bayt şirket/muhasebeci bilgisi
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| BUKRS | BUKRS | ✔ | Şirket kodu |
| ACTIVE_FLG | XFELD | | Aktif |
| POLL_INTERVAL_MIN | INT2 | | Polling sıklığı (dakika, varsayılan 15) |
| ENVIRONMENT | CHAR3 | | DEV/QAS/PRD |
| COMP_TAX_NO | CHAR11 | | Bayt `CompanyTaxNumber` — bu BUKRS'un VKN'si |
| COMP_SERIAL_NO | CHAR20 | | Bayt `CompanySerialNo` (örn. `BC-123-456-789`) |
| ACC_USER_CODE | CHAR20 | | Bayt `AccountantUserCode` — muhasebeci kullanıcı kodu |
| ACC_TAX_NO | CHAR11 | | Bayt `AccountantTaxNumber` |
| ACC_PWD_KEY | CHAR60 | | `AccountantUserPassword` için SECSTORE referans adı — **şifre asla açık tutulmaz** |

> Bayt API'si (`AuthenticateExt`/`GetInvoiceListExt`/`GetByInvoiceNoExt`) her çağrıda bu 4 kimlik alanını (CompanyTaxNumber, CompanySerialNo, AccountantUserCode, AccountantTaxNumber) + ortak `PartnerPassCode`'u ister — bkz. `program/decision-log.md` Karar 010.

### `ZONE_IARC_T002` — Provider master
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| PROVIDER_KEY | CHAR10 | ✔ | `BAYT` / `MOCK` |
| NAME | CHAR60 | | Görünür ad (örn. "Bayt E-Belge Partner") |
| ADAPTER_CLASS | SEOCLSNAME | | `ZCL_ZONE_IARC_PROVIDER` / `ZCL_ZONE_IARC_MOCK` |
| PROTOCOL | CHAR6 | | `REST` |
| ACTIVE_FLG | XFELD | | |

### `ZONE_IARC_T003` — Provider endpoint + auth referans
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| PROVIDER_KEY | CHAR10 | ✔ | T002 FK |
| ENVIRONMENT | CHAR3 | ✔ | DEV/QAS/PRD |
| SERVICE_TYPE | CHAR8 | ✔ | `AUTH` (`AuthenticateExt`) / `LIST` (`GetInvoiceListExt`) / `GET` (`GetByInvoiceNoExt`) / `DOWNLOAD` (`DownloadFileExt`) |
| ENDPOINT_URL | STRG | | Örn. `https://ebelge.baytapi.com/baytebelgeservice/AuthenticateExt` |
| TIMEOUT_SEC | INT2 | | Varsayılan 30 |
| RETRY_COUNT | INT1 | | Varsayılan 2 |
| AUTH_TYPE | CHAR8 | | `TOKEN` (Bayt: `PartnerPassCode` + kullanıcı bazlı `Token`, kendine özgü — standart OAUTH2/BASIC değil) |
| STRUST_PSE | CHAR60 | | Kullanılmıyor (Bayt sertifika tabanlı auth istemiyor) |
| SECSTORE_KEY | CHAR60 | | `PartnerPassCode` için SECSTORE referans adı (örn. `BAYT_PARTNER_PASSCODE`) — **secret asla açık tutulmaz** |
| ACTIVE_FLG | XFELD | | |

> Not: MDP `/MDPES/EDOC` mimarisindeki endpoint/auth ayrımı (T011/T012) burada tek tabloda birleştirildi çünkü tek entegratör var; ikinci servis eklenirse ayrıştırma değerlendirilir. `ACK` servis tipi **kaldırıldı** — Bayt API'sinde teyit/onay servisi yok, dedup `ZONE_IARC_T006` unique key ile yapılır.

### `ZONE_IARC_T004` — Tedarikçi eşleme override
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| VKN_TCKN | CHAR11 | ✔ | Gönderen VKN(10)/TCKN(11) |
| LIFNR | LIFNR | | Eşlenen SAP tedarikçi — boşsa LFA1 STCD1/STCD2 otomatik arama denenir |
| ACTIVE_FLG | XFELD | | |

### `ZONE_IARC_T005` — Muhasebeleştirme kuralı
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| BUKRS | BUKRS | ✔ | |
| PO_MATCH | CHAR1 | ✔ | `X`=PO'lu (MIRO park), boş=PO'suz (FI park) |
| DEFAULT_HKONT | SAKNR | | PO'suz senaryoda varsayılan GL hesap — `[?]` Süreç netleşmeli |
| DEFAULT_MWSKZ | MWSKZ | | Varsayılan vergi kodu — `[?]` |
| TOLERANCE_PCT | DEC(5,2) | | Tutar tolerans yüzdesi (PO'lu senaryoda) |

## Runtime Tabloları (delivery class A)

### `ZONE_IARC_T006` — Gelen belge kuyruğu
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| PROVIDER_DOC_ID | CHAR40 | ✔ | Bayt `InvoiceNo` (örn. `PAB2025008140740`, unique — dedupe/idempotency anahtarı) |
| ETTN | CHAR36 | | UBL UUID/ETTN (belge indirilip parse edilince doldurulur) |
| BUKRS | BUKRS | | |
| SUPPLIER_VKN | CHAR11 | | Bayt `SupplierTaxNumber` (gönderen VKN/TCKN) |
| LIFNR | LIFNR | | Eşlenen tedarikçi (resolve sonrası) |
| DOC_DATE | DATUM | | Fatura tarihi |
| AMOUNT | WRBTR | | Toplam tutar — **CURR tipi, para birimi referansı CURRENCY alanına verilmeli** (DDIC'te `REFTABLE=ZONE_IARC_T006`/`REFFIELD=CURRENCY`, yoksa aktivasyon hatası: "specify reference table and reference field" — gerçek pull'da alındı, bkz. `program/decision-log.md` Karar 007) |
| CURRENCY | WAERS | | AMOUNT alanının para birimi referansı |
| STATUS | CHAR10 | | NEW/FETCHED/PARSED/MAPPED/PARKED/POSTED/EXCEPTION/REJECTED |
| ERROR_TEXT | CHAR255 | | İş/teknik hata mesajı (STATUS=EXCEPTION) |
| FI_BELNR | BELNR_D | | Park/post sonrası FI belge no |
| MIRO_BELNR | BELNR_D | | PO'lu senaryoda MIRO belge no |
| RECEIVED_AT | TIMESTAMPL | | |
| CREATED_BY / CREATED_AT / CHANGED_BY / CHANGED_AT | (audit) | | |

### `ZONE_IARC_T007` — Ham XML saklama
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| PROVIDER_DOC_ID | CHAR40 | ✔ | T006 FK |
| XML_RAW | RSTR | | Orijinal UBL XML, byte-exact (GİB 10 yıl saklama) |
| CHECKSUM | CHAR64 | | SHA-256 — bütünlük doğrulama |
| STORED_AT | TIMESTAMPL | | |

> Architect kararı: hacim büyürse DB tablo yerine content repository (ArchiveLink/SAP DMS) + burada yalnızca pointer tutulması değerlendirilebilir.

### `ZONE_IARC_T008` — Log
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| GUID | CHAR32 | ✔ | Log kaydı ID (`cl_system_uuid`) |
| PROVIDER_DOC_ID | CHAR40 | | İlgili belge (varsa) |
| STEP | CHAR20 | | POLL/FETCH/PARSE/STORE/RESOLVE/MAP/PARK/APPROVE/REJECT/POST |
| LOG_STATUS | CHAR10 | | OK/ERROR — (`STATUS` yerine `LOG_STATUS`: T006'daki belge STATUS'uyla karışmasın) |
| MESSAGE | CHAR255 | | |
| CREATED_BY / CREATED_AT | (audit) | | |

## UBL Normalize Tabloları (T009–T014)

> Parse edilen UBL belgesinin (başlık, not, vergi dip toplam, kalem, kalem notu, kalem vergi) her yapısı ayrı bir tabloda saklanır — böylece downstream raporlama/kontrol XML'i tekrar parse etmek zorunda kalmaz. Tüm tablolar `BUKRS` + `ETTN` (UUID) ile T009'a, kalem-alt tabloları ayrıca `LINE_NO` ile T012'ye bağlanır. Para tutarı alanları (`WRBTR`) `REFTABLE=ZONE_IARC_T009`/`REFFIELD=DOC_CURRENCY` ile T009'un para birimine referans verir (Karar 007'deki DDIC kuralı — her `WRBTR` alanı için tekrarlandı). `ZCL_ZONE_IARC_STORE` bu 6 tabloyu doldurur; poller'da `PARSE` adımından hemen sonra, `RESOLVE`'dan önce çağrılır.

### `ZONE_IARC_T009` — UBL Başlığı
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| BUKRS | BUKRS | ✔ | |
| ETTN | CHAR36 | ✔ | UBL UUID |
| PROVIDER_DOC_ID | CHAR40 | | T006 FK (Bayt InvoiceNo) |
| INVOICE_ID | CHAR40 | | `cbc:ID` — fatura no |
| ISSUE_DATE | DATUM | | `cbc:IssueDate` |
| ISSUE_TIME | UZEIT | | `cbc:IssueTime` |
| INV_TYPE_CODE | CHAR10 | | `cbc:InvoiceTypeCode` |
| PROFILE_ID | CHAR20 | | `cbc:ProfileID` |
| COPY_IND | XFELD | | `cbc:CopyIndicator` |
| DOC_CURRENCY | WAERS | | `cbc:DocumentCurrencyCode` — diğer tüm `WRBTR` alanlarının referansı |
| SUPPLIER_VKN / SUPPLIER_NAME | CHAR11 / CHAR60 | | `AccountingSupplierParty` |
| CUSTOMER_VKN / CUSTOMER_NAME | CHAR11 / CHAR60 | | `AccountingCustomerParty` (gelen belgede genelde bizim şirketimiz) |
| LINE_EXT_AMOUNT / TAX_EXCL_AMOUNT / TAX_INCL_AMOUNT / ALLOW_TOTAL / CHARGE_TOTAL / PAYABLE_AMOUNT | WRBTR | | `LegalMonetaryTotal` alt alanları |
| TAX_AMOUNT | WRBTR | | Header `TaxTotal/TaxAmount` (T011 satırlarının toplamı ile tutarlı olmalı) |
| LINE_COUNT | NUMC(3) | | Kalem sayısı |
| CREATED_BY / CREATED_AT | (audit) | | |

### `ZONE_IARC_T010` — UBL Başlık Notu (tekrarlı)
Key: `MANDT, BUKRS, ETTN, SEQ_NO`. `NOTE_TEXT` (STRG) — `cbc:Note` (başlık seviyesi, birden fazla olabilir).

### `ZONE_IARC_T011` — UBL Başlık Vergi Alt Toplamı (tekrarlı)
Key: `MANDT, BUKRS, ETTN, SEQ_NO`. `cac:TaxTotal/cac:TaxSubtotal` — `TAXABLE_AMOUNT`/`TAX_AMOUNT` (WRBTR), `TAX_PERCENT` (NUMC 3, tam yüzde), `TAX_CAT_NAME` (CHAR20, örn. "KDV"), `TAX_TYPE_CODE` (CHAR10, GİB kodu örn. `0015`).

### `ZONE_IARC_T012` — UBL Kalem
Key: `MANDT, BUKRS, ETTN, LINE_NO`. `ITEM_NAME` (CHAR100), `QUANTITY` (özel DEC(13,3) — standart `QUAN` tipi kullanılmadı, birim referansı gerektirmemesi için; bkz. not aşağıda), `UOM_CODE` (CHAR10, `InvoicedQuantity/@unitCode`), `UNIT_PRICE`/`LINE_AMOUNT`/`TAX_AMOUNT` (WRBTR, T009 referanslı).

> **Not:** `QUANTITY` bilerek standart `QUAN` veri elemanı (örn. `MENGE`) ile değil, düz `DEC` tipiyle tanımlandı — `QUAN` tipi de `CURR` gibi bir birim referans alanı ister (aynı Karar 007 kısıtı), bu proje için gereksiz karmaşıklık olurdu.

### `ZONE_IARC_T013` — UBL Kalem Notu (tekrarlı)
Key: `MANDT, BUKRS, ETTN, LINE_NO, SEQ_NO`. `NOTE_TEXT` (STRG) — kalem seviyesi `cbc:Note`.

### `ZONE_IARC_T014` — UBL Kalem Vergi Alt Toplamı (tekrarlı)
Key: `MANDT, BUKRS, ETTN, LINE_NO, SEQ_NO`. T011 ile aynı alan yapısı, kalem seviyesinde.

## Diğer Repository Nesneleri

- **Yetki nesnesi:** `Z_IARC` (BUKRS, STATUS, ACTVT — 01 Görüntüle, 02 Eşleştir/Düzenle, özel aktivite Onayla&Postala / Reddet) — SU21.
- **Mesaj sınıfı:** `ZONE_IARC_MC01` (SE91).
- **Number range:** Gerekmiyor — belge kimliği Bayt'ın `InvoiceNo`'su + FI/MM kendi belge numarasını atar.
- **Background job:** `ZONE_IARC_POLL` raporu, SM36 periyodik (`ZONE_IARC_T001.POLL_INTERVAL_MIN`).
- **Cockpit:** `ZONE_IARC_COCKPIT` raporu + `ZCL_ZONE_IARC_COCKPIT` (`CL_GUI_ALV_GRID`).
- **SPRO/IMG:** T001-T005 için IMG activity ("Gelen e-Arşiv Uyarlamaları" düğümü).

## Aktivasyon Adımları (öneri)

1. Development package `ZONE_IARC` açılışı (SE21).
2. Tablolar SE11'de açılır (T001-T005 delivery class C, T006-T014 delivery class A).
3. SM30 bakım view'ı — her customizing tablosu için maintenance generator, yetki grubu `Z_IARC` (veya geçici `&NC&`).
4. Bayt pilot satırları: `ZONE_IARC_T002` (`PROVIDER_KEY='BAYT'`), `ZONE_IARC_T003` (4 `SERVICE_TYPE` satırı — AUTH/LIST/GET/DOWNLOAD, URL'ler `program/decision-log.md` Karar 010'da listeli), `ZONE_IARC_T001` (her aktif BUKRS için şirket/muhasebeci bilgisi + `ACC_PWD_KEY`/`PartnerPassCode` SECSTORE'a girilir — **asla düz metin customizing'e yazılmaz**).
5. SPRO/IMG düğümü.
6. Class/interface iskeleti (abapGit) — request tarafı (AuthenticateExt/GetInvoiceListExt/GetByInvoiceNoExt/DownloadFileExt payload'ları) Postman koleksiyonuyla doğrulanıp yazıldı; **response şemaları hâlâ doğrulanmadı** (bkz. risks-and-open-questions.md S8) — gerçek bir test çağrısından örnek response alınınca `ZCL_ZONE_IARC_PROVIDER` güncellenmeli.

## Onaylanacak (uyarlama netleşince)

- **S8 (kritik):** Bayt response JSON şemaları (`AuthenticateExt`→Token alan adı, `GetInvoiceListExt`→liste eleman alanları, `GetByInvoiceNoExt`→URL alan adı, `DownloadFileExt`→içerik base64 mü ham dosya mı) — şu an sadece REQUEST örnekleri var, response örneği yok
- `GetInvoiceListExt`'teki `TaxNumber` alanının amacı (belirli karşı taraf filtresi mi, zorunlu mu) — şu an boş gönderiliyor
- SECSTORE gerçek okuma API'si (SAP sürümüne bağlı, bkz. S7)
- PO'suz senaryoda hesap/vergi varsayımı hangi durumlarda kullanıcıya sorulacak (T005 tek satır mı, BUKRS × tedarikçi grubu bazlı mı olacak)
