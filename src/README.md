# src — ZONE_IARC abapGit Kaynağı

İlk kod iskeleti. Namespace/paket kararları için [../architecture/package-structure.md](../architecture/package-structure.md); tasarım kaynağı [../architecture/class-design.md](../architecture/class-design.md) ve [../architecture/database-design.md](../architecture/database-design.md).

## Kurulum (DEV sisteminde)

1. abapGit standalone kurulu olmalı.
2. SAP'de `ZONE_IARC` adında (transportable veya `$TMP`, bkz. [../program/risks-and-open-questions.md](../program/risks-and-open-questions.md) S6) bir paket açılmış olmalı.
3. abapGit'te **+ New Online** → bu repo URL'si → Package: `ZONE_IARC` → Pull.
4. Pull sonrası en az bir satır girin:
   - `ZONE_IARC_T001`: en az bir `BUKRS` (`ACTIVE_FLG = 'X'`) + gerçek entegratör kullanılacaksa `COMP_TAX_NO`/`COMP_SERIAL_NO`/`ACC_USER_CODE`/`ACC_TAX_NO`/`ACC_PWD_KEY` (Bayt kimlik bilgileri — mock ile test ediliyorsa gerekmez)
   - `ZONE_IARC_T002`: `PROVIDER_KEY = 'MOCK'`, `ADAPTER_CLASS = 'ZCL_ZONE_IARC_MOCK'`, `ACTIVE_FLG = 'X'` (gerçek `BAYT` satırı için `ADAPTER_CLASS = 'ZCL_ZONE_IARC_PROVIDER'`)
   - `ZONE_IARC_T003` (yalnız BAYT için): 4 satır (`SERVICE_TYPE` = `AUTH`/`LIST`/`GET`/`DOWNLOAD`), `ENDPOINT_URL` sırasıyla `.../AuthenticateExt`, `.../GetInvoiceListExt`, `.../GetByInvoiceNoExt`, `.../DownloadFileExt`; `SECSTORE_KEY` = `BAYT_PARTNER_PASSCODE` (gerçek `PartnerPassCode` SECSTORE'a girilir, customizing'e **asla düz metin girilmez**)
   - `ZONE_IARC_T005`: en az bir `BUKRS` + `PO_MATCH = ' '` satırı (`DEFAULT_HKONT`/`DEFAULT_MWSKZ` dolu) — yoksa PO'suz senaryo `ZCX_ZONE_IARC_MAPPING` ile durur

## Checklist Durumu

| Nesne | Dosya | Durum |
|---|---|---|
| DDIC tabloları (kuyruk/log, 8 adet) | `zone_iarc_t001..t008.tabl.xml` | ✅ baseline — **DD03P INTTYPE kodları (`RSTR` için `y`, `STRG` için `g`) SE11 aktivasyonunda doğrulanmalı**, kardeş projede benzer bir DATATYPE hatası (`STRING`→`STRG`) gerçek pull'da ortaya çıkmıştı |
| DDIC tabloları (UBL normalize, 8 adet) | `zone_iarc_t009..t016.tabl.xml` | ✅ başlık (T009, tam tutar dökümü dahil) + başlık notu (T010) + başlık vergi alt toplamı (T011) + kalem (T012) + kalem notu (T013) + kalem vergi alt toplamı (T014) + gönderici tam detayı (T015) + alıcı tam detayı (T016 — adres/vergi dairesi/telefon/e-posta/bireysel Person alanları). Tüm `WRBTR` alanları `REFTABLE=ZONE_IARC_T009`/`REFFIELD=DOC_CURRENCY` ile para birimi referansı veriyor (Karar 007 kuralı burada da uygulandı) |
| Canonical model | `zif_zone_iarc_types.intf.abap` | ✅ genişletildi — not (`ty_note`), tekrarlı vergi alt toplamı (`ty_tax_subtotal`), tam `LegalMonetaryTotal` dökümü, alıcı bilgisi, kalem UOM kodu eklendi |
| UBL persist servisi | `zcl_zone_iarc_store.clas.abap` | ✅ canonical modeli T009..T016'ya yazar; poller'da PARSE'dan hemen sonra çağrılır |
| Provider sözleşmesi | `zif_zone_iarc_provider.intf.abap` | ✅ Bayt gerçek API'sine göre güncellendi — `acknowledge_document` kaldırıldı (ack servisi yok), `get_document` artık `iv_bukrs`+`iv_supplier_tax_no` alıyor (Karar 010) |
| Exception hiyerarşisi | `zcx_zone_iarc_root/_provider/_mapping.clas.abap` | ✅ baseline |
| Config | `zcl_zone_iarc_config.clas.abap` | ✅ tablo boşsa güvenli fallback (MOCK) döner |
| Log | `zcl_zone_iarc_log.clas.abap` | ✅ baseline (doğrudan tablo insert) |
| Adapter base | `zcl_zone_iarc_base.clas.abap` | ✅ endpoint (AUTH/LIST/GET/DOWNLOAD) + T001 şirket/muhasebeci parametresi yükleme. Secret okuma artık `ZCL_ZONE_IARC_SECRET`'e devrediliyor |
| Secret okuma/yazma | `zcl_zone_iarc_secret.clas.abap` | ✅ `CL_SECSTORE_ADMIN` ile en-iyi-çaba (best-effort) yazıldı — ⚠️ **bu sistemde doğrulanmadı** (S7/S11): sınıf/metot adları sürüme göre farklı olabilir, ama tüm okuma/yazma TEK bu sınıfta toplandığı için yanlış çıkarsa sadece burası düzeltilir |
| Hassas değer bakım raporu | `zone_iarc_secret.prog.abap` | ✅ Write-only ekran — şifre iki kez maskeli (`SCREEN-INVISIBLE`, özel dynpro gerektirmez) girilir, kaydedilir, ekrandan hemen temizlenir; "Kontrol Et" sadece var/yok bilgisi verir, **değeri asla geri göstermez** |
| Mock provider | `zcl_zone_iarc_mock.clas.abap` | ✅ çalışır — sabit 1 test belgesi üretir, pipeline'ın geri kalanını uçtan uca test etmeye yeter |
| Bayt provider (gerçek) | `zcl_zone_iarc_provider.clas.abap` | ✅ **request tarafı wiring edildi** (Karar 010) — `AuthenticateExt`/`GetInvoiceListExt`/`GetByInvoiceNoExt`/`DownloadFileExt` gerçek JSON gövdeleriyle çağrılıyor (`cl_http_client`+`/ui2/cl_json`). ⚠️ **response şeması doğrulanmadı** (S8) — Token/liste eleman/URL/dosya içerik alan adları varsayım; gerçek bir test çağrısından sonra düzeltilmeli. Secret okuma artık `ZCL_ZONE_IARC_SECRET` üzerinden — ama o da doğrulanmamış API kullanıyor (S11), bu yüzden gerçek ortamda hâlâ test edilmeli |
| Factory | `zcl_zone_iarc_factory.clas.abap` | ✅ dinamik `CREATE OBJECT`, BUKRS aktif değilse/adapter class bulunamazsa hata |
| UBL parser | `zcl_zone_iarc_parser.clas.abap` | ✅ genişletildi — gerçek UBL-TR XPath yapısını (`AccountingSupplierParty`/`AccountingCustomerParty`, tam `LegalMonetaryTotal`, tekrarlı başlık/kalem `cbc:Note`, tekrarlı `cac:TaxSubtotal`, kalem `unitCode`) `sap-edonusum-team/program/ubl-tr-field-inventory.md`'den referansla okur, `cbc:ID` gibi çok yerde geçen alanları `depth` parametresiyle doğru elemente skopluyor. ⚠️ prefiks (`cbc:`/`cac:`) sabit varsayılır (namespace-URI farkındalığı yok), sayısal alan CHAR→P dönüşümü (ondalık ayracı) SU3 ayarına duyarlı olabilir — gerçek Bayt örnek belgesiyle doğrulanmalı |
| Tedarikçi eşleme | `zcl_zone_iarc_resolver.clas.abap` | ✅ T004 override + LFA1 STCD1/STCD2 arama |
| Muhasebe kuralı kararı | `zcl_zone_iarc_mapper.clas.abap` | ✅ basit açık PO arama (EKKO/EKPO) + T005 kural okuma |
| Park/post | `zcl_zone_iarc_post.clas.abap` | ⛔ bilerek implemente edilmedi — `BAPI_INCOMINGINVOICE_PARK`/FI park/`BAPI_INCOMINGINVOICE_POST` gerçek parametre eşlemesi S/4 vs ECC kararına ve tolerans kuralına bağlı (TODO) |
| Poller orchestrator | `zcl_zone_iarc_poller.clas.abap` | ✅ uçtan uca akış (fetch→kuyruk→XML sakla→parse→**UBL normalize tabloya yaz**→resolve→map→park), her adım loglanır; PARK adımı yukarıdaki TODO nedeniyle her zaman EXCEPTION ile sonuçlanır (gerçek BAPI wiring'e kadar beklenen davranış) |
| Review orchestrator | `zcl_zone_iarc_review.clas.abap` | ✅ approve/reject, durum geçiş kontrolü |
| Worklist | `zone_iarc_cockpit.prog.abap` | ✅ `REUSE_ALV_GRID_DISPLAY` (`CL_GUI_ALV_GRID` tabanlı, `CL_SALV_TABLE` değil) + `SELECTION-SCREEN FUNCTION KEY` ile Onayla/Reddet — kardeş projede manuel `CL_GUI_DOCKING_CONTAINER` bağlamasının `CNTL_ERROR` verdiği bilindiği için (Karar 007/008) o riskli yol hiç denenmedi |
| Background job | `zone_iarc_poll.prog.abap` | ✅ SM36'da çalıştırılabilir; periyot okuma otomasyonu yok (TODO) |
| Belge görüntüleme raporu | `zone_iarc_viewer.prog.abap` | ✅ T006+T009 LEFT OUTER JOIN listesi (`REUSE_ALV_GRID_DISPLAY`, `I_STRUCTURE_NAME` verilmedi — kolon başlıkları teknik alan adı, kozmetik eksik) + `XML Göster`/`HTML Göster` fonksiyon tuşları (`CL_ABAP_BROWSER=>SHOW_HTML` ile popup, kardeş projede doğrulanmış teknik — Karar 009). HTML görünüm T009..T013'ten tam okunabilir fatura (başlık/tutarlar/notlar/vergi/kalemler) üretir, tüm metin alanları HTML-escape edilir |
| Split-screen grid ALV cockpit | `zcl_zone_iarc_grid.clas.abap` + `zone_iarc_grid.prog.abap` | ✅ Gerçek `CL_GUI_ALV_GRID` (özel dynpro yok — `CL_GUI_DOCKING_CONTAINER` doğrudan seçim ekranına bağlanıyor, `MDP-EgiderPusulasi/egdp-abap` `ZCL_EGDP_COCKPIT`'te doğrulanmış teknik, Karar 015). `CL_GUI_SPLITTER_CONTAINER` ile ekran ikiye bölünür: üst = belge listesi, alt = seçili belgenin detayı (çift tıkla). Alt gridin araç çubuğu butonlarıyla (Kalemler/Vergi-KDV/Dip Toplamlar/Notlar) mod değiştirilir — her modda grid `FREE` edilip doğru DDIC yapısıyla yeniden yaratılır. Native `CL_GUI_TAB_STRIP` **kullanılmadı** (bu kod tabanında doğrulanmış örneği yok) |
| Mesaj sınıfı | `zone_iarc_mc01.msag.xml` | ✅ baseline (10 mesaj) |
| ABAP Unit test | `zcl_zone_iarc_parser.clas.testclasses.abap` | ✅ 8 test (header alanları, header notu, header vergi alt toplamı, gönderici Party detayı, alıcı Person/bireysel senaryo, satır alanları, satır notu+vergi, zorunlu alan eksikliği exception) — DB bağımsız, self-contained. **Diğer sınıflar (config/resolver/mapper/store) için DB'ye bağımlı test henüz yok** — `CL_OSQL_TEST_ENVIRONMENT` gerektirir, bu da SAP sürümüne bağlıdır (≥7.51); sürüm teyit edilmeden eklenmedi (bkz. risks-and-open-questions.md) |

## Bilinen Sınırlamalar / TODO (bilerek eksik bırakılanlar)

- **Bayt response şeması doğrulanmadı (S8)** — `zcl_zone_iarc_provider` request tarafı gerçek, ama JSON response alan adları (Token, InvoiceNo/SupplierTaxNumber, indirme URL alanı, dosya içerik formatı) varsayım. Gerçek bir test çağrısından örnek response alınınca düzeltilmeli.
- **SECSTORE okuma/yazma doğrulanmadı (S11)** — `zcl_zone_iarc_secret` `CL_SECSTORE_ADMIN` kullanıyor ama bu sınıf/metotların bu SAP sürümünde var olup olmadığı, imzalarının birebir uyup uymadığı test edilmedi. Yanlış çıkarsa yalnızca bu tek sınıf düzeltilir. Doğrulanana kadar mock provider ile geri kalan pipeline test edilebilir.
- **Uyarlama ekranı (SM30) elle açılmalı** — `ZONE_IARC_T001/T002/T003`'ün hassas olmayan alanları (URL, environment, protocol vb.) için standart SM30 bakım görünümü abapGit ile üretilmedi; SE11 → *Utilities → Table Maintenance Generator* ile **elle** (birkaç dakikalık, standart bir adım) açılmalı. Şifre alanları (`ACC_PWD_KEY`/`SECSTORE_KEY`) bu ekranlarda sadece bir *referans anahtar adı* olarak görünür — gerçek değer `zone_iarc_secret.prog.abap` üzerinden ayrı girilir.
- **MIRO/FI park gerçek BAPI çağrısı yok** — `zcl_zone_iarc_post` TODO olarak bırakıldı; bu yüzden `zone_iarc_poll` çalıştırıldığında her belge `PARK` adımında `EXCEPTION` durumuna düşer (beklenen, hatalı değil).
- **UBL parser prefiks-sabit** — `cbc:`/`cac:` namespace prefiksinin GİB tarafından hep bu şekilde kullanıldığı varsayılıyor (namespace-URI ile değil, literal string eşleşmesiyle); gerçek namespace desteği (`get_elements_by_tag_name_ns`) henüz eklenmedi.
- **DD03P `INTTYPE` kodları doğrulanmadı** — özellikle `zone_iarc_t007.XML_RAW` (`RSTR`) ve `*_t00x.MESSAGE`/`ENDPOINT_URL` (`STRG`) alanları ilk abapGit pull'da SE11 aktivasyon hatası verirse (kardeş projedeki Karar 005 gibi) düzeltilip buraya not düşülmeli.
- Data element/domain oluşturulmadı; standart SAP built-in tipleri veya düz CHAR/NUMC kullanıldı (bkz. [../architecture/database-design.md](../architecture/database-design.md) adlandırma notu).
- Yetkilendirme nesnesi (`Z_IARC`) SU21'de henüz açılmadı; cockpit/job şu an yetki kontrolü yapmıyor.
