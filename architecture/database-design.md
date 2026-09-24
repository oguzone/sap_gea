# DDIC & Uyarlama (Customizing) Spesifikasyonu

> Önce [package-structure.md](package-structure.md) — özellikle uzunluk sınırları tablosu — okunmalı. Bu yüzden tüm tablolar açıklayıcı son ek yerine **sıra numarasıyla** (`T001`, `T002`, …) adlandırılmıştır; anlamı buradaki tablo ile takip edilir.

Domain/Data Element **kullanılmıyor** — `ZONE_IARC_` öneki (10 karakter) sonrası 16 karakterlik sınırda anlamlı bir isme yer kalmıyor (kardeş projede aynı sorun yaşanmıştı). Alan tipi standart data element (`CHAR`/`XFELD`/`BUKRS`/`DATUM`/`TIMESTAMPL`/`LIFNR`/`SAKNR`/`MWSKZ`/`WAERS`) ile tanımlanır; enum doğrulama (`STATUS` değerleri, `SERVICE_TYPE` değerleri vb.) kod seviyesinde (`ZCL_ZONE_IARC_CONFIG` veya ilgili sınıf) yapılır.

**DD03P-DATATYPE kısa kod hatırlatması** (kardeş projede gerçek aktivasyon hatasına yol açmıştı): metin alanı için `STRG` (STRING değil), ham/binary için `RSTR` (XSTRING değil).

## Customizing Tabloları (delivery class C)

### `ZONE_IARC_T001` — BUKRS aktivasyon + polling parametresi
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| BUKRS | BUKRS | ✔ | Şirket kodu |
| ACTIVE_FLG | XFELD | | Aktif |
| POLL_INTERVAL_MIN | INT2 | | Polling sıklığı (dakika, varsayılan 15) |
| ENVIRONMENT | CHAR3 | | DEV/QAS/PRD |

### `ZONE_IARC_T002` — Provider master
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| PROVIDER_KEY | CHAR10 | ✔ | `ZONETEGRA` / `MOCK` |
| NAME | CHAR60 | | Görünür ad |
| ADAPTER_CLASS | SEOCLSNAME | | `ZCL_ZONE_IARC_PROVIDER` / `ZCL_ZONE_IARC_MOCK` |
| PROTOCOL | CHAR6 | | SOAP/REST |
| ACTIVE_FLG | XFELD | | |

### `ZONE_IARC_T003` — Provider endpoint + auth referans
| Alan | Tip | Key | Açıklama |
|---|---|---|---|
| MANDT | CLNT | ✔ | |
| PROVIDER_KEY | CHAR10 | ✔ | T002 FK |
| ENVIRONMENT | CHAR3 | ✔ | DEV/QAS/PRD |
| SERVICE_TYPE | CHAR8 | ✔ | `LIST` / `GET` / `ACK` |
| ENDPOINT_URL | STRG | | PRD için `https://` zorunlu |
| TIMEOUT_SEC | INT2 | | Varsayılan 30 |
| RETRY_COUNT | INT1 | | Varsayılan 2 |
| AUTH_TYPE | CHAR8 | | TOKEN/BASIC/CERT/OAUTH2 |
| STRUST_PSE | CHAR60 | | `AUTH_TYPE=CERT` zorunlu |
| SECSTORE_KEY | CHAR60 | | `AUTH_TYPE` ∈ {TOKEN,BASIC,OAUTH2} zorunlu — **secret asla açık tutulmaz** |
| ACTIVE_FLG | XFELD | | |

> Not: MDP `/MDPES/EDOC` mimarisindeki endpoint/auth ayrımı (T011/T012) burada tek tabloda birleştirildi çünkü tek entegratör var; ikinci servis eklenirse ayrıştırma değerlendirilir.

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
| PROVIDER_DOC_ID | CHAR40 | ✔ | Zonetegra taraflı belge ID (unique — dedupe/idempotency anahtarı) |
| ETTN | CHAR36 | | UBL UUID/ETTN |
| BUKRS | BUKRS | | |
| SUPPLIER_VKN | CHAR11 | | Gönderen VKN/TCKN |
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
| STEP | CHAR20 | | POLL/FETCH/PARSE/RESOLVE/MAP/PARK/APPROVE/REJECT/POST |
| LOG_STATUS | CHAR10 | | OK/ERROR — (`STATUS` yerine `LOG_STATUS`: T006'daki belge STATUS'uyla karışmasın) |
| MESSAGE | CHAR255 | | |
| CREATED_BY / CREATED_AT | (audit) | | |

## Diğer Repository Nesneleri

- **Yetki nesnesi:** `Z_IARC` (BUKRS, STATUS, ACTVT — 01 Görüntüle, 02 Eşleştir/Düzenle, özel aktivite Onayla&Postala / Reddet) — SU21.
- **Mesaj sınıfı:** `ZONE_IARC_MC01` (SE91).
- **Number range:** Gerekmiyor — belge kimliği Zonetegra'nın `PROVIDER_DOC_ID`'si + FI/MM kendi belge numarasını atar.
- **Background job:** `ZONE_IARC_POLL` raporu, SM36 periyodik (`ZONE_IARC_T001.POLL_INTERVAL_MIN`).
- **Cockpit:** `ZONE_IARC_COCKPIT` raporu + `ZCL_ZONE_IARC_COCKPIT` (`CL_GUI_ALV_GRID`).
- **SPRO/IMG:** T001-T005 için IMG activity ("Zonetegra Gelen e-Arşiv Uyarlamaları" düğümü).

## Aktivasyon Adımları (öneri)

1. Development package `ZONE_IARC` açılışı (SE21).
2. Tablolar SE11'de açılır (T001-T005 delivery class C, T006-T008 delivery class A).
3. SM30 bakım view'ı — her customizing tablosu için maintenance generator, yetki grubu `Z_IARC` (veya geçici `&NC&`).
4. Zonetegra pilot satırları (T002/T003) — API dokümantasyonu geldikten sonra doldurulur.
5. SPRO/IMG düğümü.
6. Class/interface iskeleti (abapGit) — Zonetegra API sözleşmesi doğrulanmadan gerçek adapter wiring'i yapılmaz; iskelet + mock provider önce üretilebilir.

## Onaylanacak (uyarlama netleşince)

- Zonetegra `list_new_documents`/`get_document` gerçek API sözleşmesi (senkron mu, sayfalama var mı, `since` parametresi timestamp mi sequence mi)
- `acknowledge_document` gerekli mi (yoksa idempotency salt T006 unique key ile)
- PO'suz senaryoda hesap/vergi varsayımı hangi durumlarda kullanıcıya sorulacak (T005 tek satır mı, BUKRS × tedarikçi grubu bazlı mı olacak)
