# Karar Günlüğü

## Karar Şablonu

```text
KONU:
KARAR:
SEÇENEKLER:
KARAR TARİHİ:
KARARI VEREN:
GEREKÇE:
ETKİLENEN MODÜLLER/DOSYALAR:
```

Durum etiketleri: `[ ]` Başlanmadı · `[~]` Devam ediyor · `[x]` Tamamlandı · `[!]` Bloke · `[?]` Karar bekliyor

## Kayıtlı Kararlar

### Karar 001

```text
KONU: ABAP namespace / ürün kodu
KARAR: Kayıtlı bir SAP namespace'i yok; müşteri (Z) namespace'inde ZONE_IARC
  ürün kodu kullanılacak. Pattern: ZCL_ZONE_IARC_<isim> (class),
  ZIF_ZONE_IARC_<isim> (interface), ZCX_ZONE_IARC[_<alt>] (exception),
  ZONE_IARC_T0xx (DDIC tablo — sıra numaralı, açıklayıcı son ek yok),
  Z_IARC (yetki nesnesi, 10 karakter sınırı nedeniyle kısaltıldı).
SEÇENEKLER: zonetegra_inc_earcive (ilk öneri, çok uzun) / ZONE_INC_EARC (okunabilir
  ama DDIC/yetki nesnesi sınırlarına sığmıyor) / ZONE_IARC (seçildi)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın
GEREKÇE: Kardeş proje zonetegra_edeclaration'da (ZONE_EDC, 3 karakter ürün kodu)
  aynı önek deseni iki ayrı abapGit pull denemesinde uzunluk sınırı hatası verdi
  (bkz. o projenin decision-log.md Karar 005/006). ZONE_IARC (4 karakter ürün
  kodu) için aynı hataya düşmemek üzere sınırlar baştan hesaplandı — bkz.
  architecture/package-structure.md.
ETKİLENEN MODÜLLER/DOSYALAR: architecture/package-structure.md,
  architecture/class-design.md, architecture/database-design.md
```

### Karar 002

```text
KONU: Gelen belge için muhasebe kaydı nasıl atılsın
KARAR: Park + manuel onay. Belge FI/MM'de parked (taslak) olarak oluşturulur;
  muhasebe/satınalma kullanıcısı cockpit'ten inceleyip onay verir, onay
  sonrası postalanır. Tam otomatik postalama bu fazda yapılmaz.
SEÇENEKLER: Park + manuel onay (seçildi) / Tam otomatik post (PO/GR 3-way match
  başarılıysa direkt postala) / Sadece kayıt/arşiv (muhasebe kaydı yok)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın
GEREKÇE: PO/GR eşleşmesi olmayan veya tutar/vergi uyuşmazlığı olan belgelerde
  insan onayı olmadan postalama riski yüksek; park mekanizması SAP'nin standart
  MIRO/FI akışıyla zaten örtüşüyor.
ETKİLENEN MODÜLLER/DOSYALAR: architecture/technical-architecture.md,
  architecture/class-design.md (ZCL_ZONE_IARC_POST, ZCL_ZONE_IARC_REVIEW),
  architecture/database-design.md (ZONE_IARC_T005, T006)
```

### Karar 003

```text
KONU: SAP'nin Zonetegra servisinden belgeleri alma şekli
KARAR: Polling. SAP tarafında zamanlanmış bir job (ZONE_IARC_POLL, SM36)
  periyodik olarak Zonetegra servisine "yeni belge var mı" sorar ve UBL XML'i
  çeker. Push/webhook bu fazda kapsam dışı.
SEÇENEKLER: Polling (seçildi) / Push-webhook (SAP'nin inbound HTTP endpoint
  sunmasını gerektirir)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın
GEREKÇE: Mevcut e-Dönüşüm mimarisiyle (giden e-Fatura/e-Arşiv) simetrik; ek
  inbound HTTP handler, güvenlik/auth ve Basis/network onayı gerektirmiyor.
ETKİLENEN MODÜLLER/DOSYALAR: architecture/technical-architecture.md,
  architecture/class-design.md (ZCL_ZONE_IARC_POLLER),
  architecture/database-design.md (ZONE_IARC_T001, T003)
```

### Karar 004

```text
KONU: Kod iskeletine (src/) ne zaman ve ne kadar kapsamda baslanacagi
KARAR: Zonetegra'nin gercek API sozlesmesi (S1) ve MIRO/FI park BAPI detayi
  (S3/S4) beklenmeden, mock provider (ZCL_ZONE_IARC_MOCK) ile tum pipeline'i
  (poller->parser->resolver->mapper->post) uctan uca calistirilabilir hale
  getiren bir ilk abapGit iskeleti uretildi. Gercek Zonetegra adapter
  (ZCL_ZONE_IARC_PROVIDER) ve park/post BAPI cagrisi (ZCL_ZONE_IARC_POST)
  bilerek TODO/exception firlatacak sekilde birakildi.
SEÇENEKLER: API sozlesmesi/BAPI detayi netlesene kadar bekle / mock-first
  iskelet uret (secildi) / tasarim dokumanlarinda kal, hic kod yazma
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın
GEREKÇE: Kardeş proje zonetegra_edeclaration'da da GIB entegrasyon
  detaylari (auth yontemi) netlesmeden once diger tum katmanlarin (DB,
  factory, validation, mapping) mock/TODO ile ilerlemesi verimli oldugu
  gorulmustu; ayni strateji burada tekrarlandi.
ETKİLENEN MODÜLLER/DOSYALAR: src/ (tum dosyalar), src/README.md
```

### Karar 005

```text
KONU: UBL parser'in ilk versiyonu duz/gercek disi test XML'i okuyordu -
  gercek UBL-TR yapisina yaklastirma
KARAR: ZCL_ZONE_IARC_PARSER, edonusum reposundaki sap-edonusum-team/
  program/ubl-tr-field-inventory.md (giden e-Fatura icin yazilmis UBL-TR
  alan envanteri) referans alinarak yeniden yazildi. ArchiveInvoice ve
  Invoice ayni cbc:/cac: temel yapisini paylastigi icin
  AccountingSupplierParty/LegalMonetaryTotal/InvoiceLine/TaxTotal XPath'leri
  buradan tasindi. Ayni zamanda ZCL_ZONE_IARC_MOCK'un urettigi test XML'i
  de bu gercekci yapiya guncellendi (ikisi tutarli kalsin diye).
SEÇENEKLER: Zonetegra gercek ornek belgesi gelene kadar duz/basit test
  XML'inde kal / bilinen genel UBL-TR yapisina simdiden yaklas (secildi)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın
GEREKÇE: e-Fatura ve e-Arsiv (ArchiveInvoice) ayni GIB UBL-TR temelini
  paylasir; bu ortak yapi zaten baska bir projede dogrulanmis/dokumante
  edilmis durumda, dolayisiyla tahmin degil referans kullanildi. Kalan risk
  (namespace-URI farkindaligi, ondalik ayraci) src/README.md'de acikca
  isaretlendi - hala TAM dogrulanmis degil.
ETKİLENEN MODÜLLER/DOSYALAR: src/zcl_zone_iarc_parser.clas.abap,
  src/zcl_zone_iarc_mock.clas.abap, src/README.md
```

### Karar 006

```text
KONU: Ilk ABAP Unit test hangi sinifa yazilsin
KARAR: ZCL_ZONE_IARC_PARSER icin 3 testli (header alanlari, satir
  alanlari, zorunlu alan eksikligi exception) DB-bagimsiz test class
  eklendi (zcl_zone_iarc_parser.clas.testclasses.abap). Config/Resolver/
  Mapper gibi DB'ye bagimli siniflar icin CL_OSQL_TEST_ENVIRONMENT
  gerekir; bu API'nin mevcut oldugu SAP surumu (>=7.51) teyit
  edilmeden yazilmadi (program/risks-and-open-questions.md S7).
SEÇENEKLER: Hicbir test yazma / sadece DB-bagimsiz (parser) test yaz
  (secildi) / SAP surumunu varsayip DB-bagimli testleri de simdiden yaz
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın
GEREKÇE: Parser en yeni degisen ve en karmasik (XML DOM navigasyonu,
  derinlik skoplamasi) sinif oldugu icin en yuksek regresyon riski
  tasiyordu; DB-bagimli testler icin dogru API varsayimini netlesmeden
  yapmak yanlis/calismayan test kodu riski tasir.
ETKİLENEN MODÜLLER/DOSYALAR: src/zcl_zone_iarc_parser.clas.testclasses.abap,
  src/README.md, program/risks-and-open-questions.md (S7 eklendi)
```

### Karar 007

```text
KONU: Ilk abapGit pull'da ZONE_IARC_T006 aktivasyon hatasi
KARAR: "ZONE_IARC_T006-AMOUNT (specify reference table AND reference
  field)" hatasi alindi - WRBTR (para tutari, CURR tipi) alani hangi
  alanin para birimini tasidigini bilmeli. AMOUNT alanina REFTABLE=
  ZONE_IARC_T006 / REFFIELD=CURRENCY eklendi (CURRENCY alani zaten ayni
  tabloda WAERS ile tanimliydi).
SEÇENEKLER: AMOUNT'u custom DEC alanina cevir (referans gerektirmez) /
  WRBTR'yi koru + REFTABLE/REFFIELD ekle (secildi)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın (SAP'de pull sirasinda hatayi bildirdi)
GEREKÇE: Bu tercih degil, SAP DDIC'in sabit teknik kisiti - CURR/QUAN
  tipi her alan bir para birimi/birim referans alanina sahip olmali.
  WRBTR standart data element olarak korunmasi (custom DEC yerine)
  tercih edildi cunku dogru ondalik/yuvarlama davranisini SAP'nin kendi
  para birimi mantigindan alir.
ETKİLENEN MODÜLLER/DOSYALAR: src/zone_iarc_t006.tabl.xml,
  architecture/database-design.md (REFTABLE/REFFIELD notu eklenmeli - TODO)
```

### Karar 008

```text
KONU: ZONE_IARC_COCKPIT "Alt sinir ust sinirdan buyuk" hatasi
KARAR: SELECT-OPTIONS s_stat icin "DEFAULT 'PARKED' TO 'EXCEPTION'"
  kullanilmisti - STATUS alfabetik bir aralik degil sabit deger listesi
  (enum) oldugundan hem mantik hatasiydi hem de 'PARKED' > 'EXCEPTION'
  alfabetik oldugu icin "Alt sinir ust sinirdan buyuk" hatasi verdi.
  DEFAULT clause kaldirildi; INITIALIZATION'da iki ayri EQ degeri
  (PARKED, EXCEPTION) programatik olarak s_stat'a APPEND edildi.
SEÇENEKLER: DEFAULT 'EXCEPTION' TO 'PARKED' (alfabetik siraya cevir -
  yine mantik hatali kalirdi, PARSED/MAPPED/POSTED gibi aradaki degerler
  de dahil olurdu) / iki ayri EQ degeri APPEND et (secildi)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın (SAP'de calistirinca hatayi bildirdi)
GEREKÇE: STATUS bir siralama/araligi olan alan degil; "PARKED VEYA
  EXCEPTION" istegi bir TO araligiyla degil, birden fazla EQ deger
  girisiyle ifade edilmeli.
ETKİLENEN MODÜLLER/DOSYALAR: src/zone_iarc_cockpit.prog.abap
```

### Karar 009

```text
KONU: SELECT-OPTIONS ... FOR ZONE_IARC_T006-STATUS - STATUS alani
  gorunmuyor/cozulmuyor
KARAR: TABLES: sscrfields. bildirimi vardi ama TABLES: zone_iarc_t006.
  yoktu. Klasik SELECT-OPTIONS ... FOR <tablo>-<alan> sozdizimi, <tablo>
  identifier'inin programda bilinen bir data nesnesi (TABLES work area)
  olmasini gerektirir; PARAMETERS ... TYPE zone_iarc_t006-provider_doc_id
  (TYPE ile DDIC referansi) calisiyordu ama SELECT-OPTIONS...FOR (klasik
  sozdizim) calismiyordu. TABLES listesine zone_iarc_t006 eklendi.
SEÇENEKLER: TABLES: zone_iarc_t006. ekle (secildi) / SELECT-OPTIONS'u
  yerel bir TYPE tanimina baglayacak sekilde yeniden yaz
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın (SAP'de yazarken fark etti)
GEREKÇE: TABLES work area + SELECT-OPTIONS FOR kombinasyonu klasik ve
  en az degisiklik gerektiren duzeltme; DATA: gt_queue TYPE STANDARD
  TABLE OF zone_iarc_t006 ile isim celismesi yok (TABLES ve TYPE OF
  ayni DDIC tablo adini farkli baglamlarda kullanabilir).
ETKİLENEN MODÜLLER/DOSYALAR: src/zone_iarc_cockpit.prog.abap
```

### Karar 010

```text
KONU: Gercek entegrator API sozlesmesi teslim edildi (S1 buyuk olcude
  cozuldu)
KARAR: Entegrator "Bayt E-Belge Partner" (ebelge.baytapi.com/
  baytebelgeservice), REST/JSON, "Bayt E-Belge Partner.postman_collection.json"
  ile dogrulandi. 4 endpoint: AuthenticateExt (PartnerPassCode +
  AccountantUserCode/Password + CompanyTaxNumber/SerialNo -> Token, JWT
  ~6 saat gecerli), GetInvoiceListExt (CustomerType="alici" -> BIZ ALICIYIZ
  = gelen belge senaryosu; EInvoiceType=0 e-Arsiv/1 e-Mustahsil/2
  e-Serbest Meslek; StartDate/EndDate araligi -> belge listesi),
  GetByInvoiceNoExt (InvoiceNo+SupplierTaxNumber+CustomerTaxNumber ->
  belge detayi), DownloadFileExt (Url -> dosya icerigi, Url baska bir
  domain'e - authrestapi.superentegrator.com - isaret ediyor, Bayt'in
  SuperEntegrator uzerine kurulu bir partner API'si oldugu anlasiliyor).
  ACK servisi YOK - S2 kesin cozuldu. ZIF_ZONE_IARC_PROVIDER interface'i
  buna gore guncellendi: acknowledge_document kaldirildi, get_document
  artik iv_bukrs + iv_supplier_tax_no aliyor (GetByInvoiceNoExt'in
  InvoiceNo tek basina yetmiyor). ZCL_ZONE_IARC_PROVIDER gercek HTTP/JSON
  istek govdeleri ile yazildi (cl_http_client + /ui2/cl_json). ZONE_IARC_T001
  sirket/muhasebeci alanlariyla (COMP_TAX_NO/COMP_SERIAL_NO/ACC_USER_CODE/
  ACC_TAX_NO/ACC_PWD_KEY) genisletildi; ZONE_IARC_T003 SERVICE_TYPE
  degerleri AUTH/LIST/GET/DOWNLOAD oldu (ACK kaldirildi).
GUVENLIK NOTU: Postman koleksiyonunda PartnerPassCode duz metin
  (541857E2-...) olarak geldi - digerlerinin aksine maskelenmemisti. Bu
  deger hicbir commit'e/dosyaya yazilmadi; sadece SECSTORE referans
  mekanizmasi (ACC_PWD_KEY / T003.SECSTORE_KEY) tasarlandi, gercek deger
  SAP'de guvenli depoya girilecek.
SEÇENEKLER: Response semasi netlesene kadar wiring'i erteleyip sadece
  request tarafini yaz (secildi) / response alan adlarini da kesin
  varsayip tam wiring yaz (reddedildi - Postman'da response ornegi yok,
  yanlis varsayimla "calisiyormus gibi gorunen ama calismayan" kod riski)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın (gercek Postman koleksiyonunu paylasti)
GEREKÇE: Request semasi %100 dogrulanabilir kaynaktan (calisan Postman
  ornegi) geldigi icin guvenle kod haline getirildi; response semasi ise
  hicbir ornek icermedigi icin tahmin olurdu - bu yuzden acikca TODO/S8
  olarak isaretlenip varsayimlar yorum satirlarinda belirtildi (ornegin
  "Token" alan adi, liste eleman alanlari, indirme URL alan adi).
ETKİLENEN MODÜLLER/DOSYALAR: src/zif_zone_iarc_provider.intf.abap,
  src/zif_zone_iarc_types.intf.abap, src/zcl_zone_iarc_base.clas.abap,
  src/zcl_zone_iarc_provider.clas.abap, src/zcl_zone_iarc_mock.clas.abap,
  src/zcl_zone_iarc_poller.clas.abap, src/zone_iarc_t001.tabl.xml,
  architecture/database-design.md, architecture/technical-architecture.md,
  program/risks-and-open-questions.md (S1/S2 guncellendi, S8-S11 eklendi)
```

### Karar 011

```text
KONU: Parse edilen UBL verisi sadece bellekte/queue'da degil, normalize
  tablolarda saklanmali (baslik, not, vergi dip toplam, kalem, kalem notu,
  kalem vergi)
KARAR: 6 yeni runtime tablo eklendi: ZONE_IARC_T009 (UBL baslik - UUID,
  ID, tarih/saat, InvoiceTypeCode, ProfileID, satici/alici, tam
  LegalMonetaryTotal dokumu, header TaxAmount), T010 (baslik notu,
  tekrarli), T011 (baslik vergi alt toplami, tekrarli), T012 (kalem),
  T013 (kalem notu, tekrarli), T014 (kalem vergi alt toplami, tekrarli).
  Anahtar zinciri: tum tablolar MANDT+BUKRS+ETTN (UUID) ile birbirine
  bagli; kalem ve kalem-alt tablolari ayrica LINE_NO tasir. Yeni
  ZCL_ZONE_IARC_STORE sinifi canonical modeli (ZIF_ZONE_IARC_TYPES)
  bu tablolara yazar; poller'da PARSE adimindan hemen sonra, RESOLVE'dan
  once cagrilir. Canonical model (ty_header/ty_line) de bu kapsamda
  genisletildi: ty_note, ty_tax_subtotal (tekrarli), tam
  LegalMonetaryTotal alanlari, alici (customer) bilgisi, kalem UOM kodu
  eklendi. ZCL_ZONE_IARC_PARSER buna gore genisletildi (cbc:Note,
  cac:TaxSubtotal, cac:AccountingCustomerParty, InvoicedQuantity/@unitCode
  parse ediliyor). Mock XML ve ABAP Unit testleri de yeni alanlari
  kapsayacak sekilde guncellendi (6 test).
SEÇENEKLER: Sadece XML'i sakla (T007), gerektiginde tekrar parse et
  (mevcut durum) / normalize tablolara da yaz (secildi) - raporlama/
  kontrol/muhasebe eslestirme XML tekrar parse etmeden calisabilsin diye
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın
GEREKÇE: Kullanici, muhasebelestirme asamasina gecmeden once UBL'in tum
  yapisal alanlarinin (baslik/not/vergi/kalem/kalem-not/kalem-vergi)
  ayri tablolarda, ortak anahtar (sirket kodu + ETTN, kalemler icin +
  kalem no) ile saklanmasini talep etti. QUANTITY alani bilerek standart
  QUAN tipiyle degil duz DEC ile tanimlandi - QUAN da CURR gibi birim
  referans alani ister (Karar 007 kisitiyla ayni sorun), gereksiz
  karmasiklik olurdu. Tum WRBTR alanlari ayni Karar 007 kuraliyla
  T009.DOC_CURRENCY'ye referans verir (baska bir tablodaki alana referans
  vermek DDIC'te gecerlidir, ayni tabloda olma zorunlulugu yok).
ETKİLENEN MODÜLLER/DOSYALAR: src/zone_iarc_t009..t014.tabl.xml (yeni),
  src/zcl_zone_iarc_store.clas.abap (yeni), src/zif_zone_iarc_types.intf.abap,
  src/zcl_zone_iarc_parser.clas.abap, src/zcl_zone_iarc_parser.clas.testclasses.abap,
  src/zcl_zone_iarc_mock.clas.abap, src/zcl_zone_iarc_poller.clas.abap,
  architecture/database-design.md, architecture/technical-architecture.md,
  architecture/class-design.md
```
