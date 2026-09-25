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

### Karar 012

```text
KONU: Gelen belgeleri XML ve HTML olarak goruntuleyebilecegim bir rapor
KARAR: ZONE_IARC_VIEWER raporu eklendi. Liste ZONE_IARC_T006 + T009
  LEFT OUTER JOIN (henuz parse edilmemis belgeler de gorunsun diye).
  "XML Goster" fonksiyon tusu ZONE_IARC_T007.XML_RAW'i CL_ABAP_BROWSER
  ile <pre> icinde gosterir. "HTML Goster" T009..T013'ten (baslik, tam
  tutar dokumu, baslik notu, vergi dip toplami, kalemler, kalem notu)
  okunabilir bir fatura HTML'i uretip ayni sekilde gosterir. Tum
  kullanici/tedarikci kaynakli metin alanlari (isim, not, aciklama)
  HTML-escape edilir (XSS/bozuk layout riskine karsi - bu veri disaridan
  - Bayt/tedarikci - geldigi icin guvenilmez kabul edildi).
SEÇENEKLER: Ayri XML/HTML raporlari yaz / tek rapor + iki fonksiyon
  tusu (secildi, ZONE_IARC_COCKPIT paterniyle tutarli)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın
GEREKÇE: CL_ABAP_BROWSER=>SHOW_HTML zaten kardes projede (Karar 009)
  ozel dynpro/CUA gerektirmeden dogrulanmis bir teknikti; ayni pattern
  tekrar kullanildi. I_STRUCTURE_NAME REUSE_ALV_GRID_DISPLAY'e
  verilmedi (liste birlestirilmis/yerel bir tip) - kolon basliklari
  teknik alan adi olarak gorunur, bu bilinen kucuk bir kozmetik eksik.
ETKİLENEN MODÜLLER/DOSYALAR: src/zone_iarc_viewer.prog.abap (yeni),
  src/README.md
```

### Karar 013

```text
KONU: ZONE_IARC_VIEWER aktivasyon hatalari - "Unable to interpret
  ZONE_IARC_T010" ve "Expression limiter '{' in string template not
  followed by space"
KARAR: Iki ayri hata: (1) CLASS-METHODS build_invoice_html
  imzasindaki "TYPE STANDARD TABLE OF zone_iarc_t01x" dogrudan kullanimi
  onceden TYPES ile adlandirilmis tiplere (tt_t010..tt_t013, WITH
  DEFAULT KEY) cevrildi. (2) CSS bloğu (lv_style) string template
  (|...|) ile kuruluyordu; CSS'teki duz suslu parantezler (body{...}
  vb.) ABAP tarafindan ifade sinirlayici sanildi - duz string literal'e
  ('...') cevrildi.
SEÇENEKLER: (2) icin alternatif: '{' -> '\{' / '}' -> '\}' escape et
  (JSON govdesinde yapildigi gibi) / duz string literale gec (secildi,
  CSS'te cok sayida brace oldugundan daha az hataya acik)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın (SAP'de aktivasyon sirasinda iki hatayi da
  sirayla bildirdi)
GEREKÇE: (1) somut sonucu bilinmiyor - eger T010 gercekten DDIC'te
  aktif degilse ayni hata TYPES satirinda da cikabilirdi, ama kullanici
  bir sonraki hatayi (CSS/string template) bildirdigi icin (1) numarali
  fix'in sorunu gercekten cozdugu anlasiliyor (T010 aktifmis). (2) ABAP
  string template'lerinde '{' her zaman ifade baslangici sayilir; JSON
  govdesi olustururken bu zaten biliniyordu ve dogru escape edilmisti,
  bu yeni CSS bloğunda atlanmisti.
ETKİLENEN MODÜLLER/DOSYALAR: src/zone_iarc_viewer.prog.abap
```

### Karar 014

```text
KONU: ZONE_IARC_VIEWER aktivasyon sonrasi calisma zamani/derleme hatasi -
  "LT_NOTE is not type-compatible with formal parameter IT_NOTE"
KARAR: SELECT ... INTO TABLE @DATA(lt_note) (ve lt_tax/lt_line/
  lt_line_note) EMPTY KEY'li anonim bir tablo tipi uretiyordu;
  build_invoice_html imzasindaki adlandirilmis tt_t01x tipleri (Karar
  013'te WITH DEFAULT KEY olarak tanimlanmisti) ile birebir
  uyusmuyordu. lt_note/lt_tax/lt_line/lt_line_note artik once
  "DATA lt_x TYPE tt_t01x." ile acikca bildirilip SELECT sonucu oraya
  okunuyor (inline @DATA(...) kullanilmiyor).
SEÇENEKLER: tt_t01x tanimini WITH EMPTY KEY'e cevir (SELECT'in urettigi
  tiple eslessin) / SELECT hedeflerini acikca tt_t01x ile tiple (secildi)
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın (SAP'de aktivasyon/calistirma sirasinda bildirdi)
GEREKÇE: Acikca ayni adlandirilmis tipi hem SELECT hedefinde hem metot
  imzasinda kullanmak, anonim tip uretiminin (SELECT INTO TABLE
  @DATA(...)) tam olarak hangi key tanimini urettigine bagli kalmaktan
  daha guvenilir ve ongorulebilir.
ETKİLENEN MODÜLLER/DOSYALAR: src/zone_iarc_viewer.prog.abap
```

### Karar 015

```text
KONU: Gercek split-screen (ust liste / alt tab-detay) grid ALV cockpit
KARAR: ZCL_ZONE_IARC_GRID + ZONE_IARC_GRID raporu eklendi. Ozel dynpro
  YAZILMADI - CL_GUI_DOCKING_CONTAINER dogrudan aktif secim ekranina
  (sy-repid/sy-dynnr) baglaniyor, AT SELECTION-SCREEN OUTPUT'tan
  cagriliyor. Bu teknigin bu musteri hattinda (MDP-EgiderPusulasi/
  egdp-abap ZCL_EGDP_COCKPIT) GERCEKTEN CALISTIGI dogrulandi - birebir
  kopyalandi. Docking container icinde CL_GUI_SPLITTER_CONTAINER (2
  satir) ile ekran ikiye bolundu: ust CL_GUI_ALV_GRID (belge listesi,
  T006+T009 join), alt CL_GUI_ALV_GRID (detay - secili satira cift
  tiklayinca yuklenir). "Tab" yapisi CL_GUI_TAB_STRIP (native kontrol)
  ile DEGIL, alt grid'in arac cubugundaki 4 buton (Kalemler/Vergi-KDV/
  Dip Toplamlar/Notlar) ile saglandi - moda gore alt grid yok edilip
  (FREE) dogru DDIC yapisiyla (T012/T011/T010 veya ozel KV tipi) yeniden
  yaratiliyor.
SEÇENEKLER: Gercek split-screen dene (kullanici sectigi secenek) - alt
  detay icin CL_GUI_TAB_STRIP (native tab) / arac cubugu butonuyla tek
  grid'i degistir (secildi). Kullanicinin ilk istedigi "genuine risky"
  secenekti; alt kisimda CL_GUI_TAB_STRIP yerine arac cubugu tercih
  edildi cunku bu kod tabaninda TAB_STRIP'in dogrulanmis hic ornegi yok,
  splitter+docking+grid ise artik VAR (egdp-abap referansi).
KARAR TARİHİ: 2026-09-24
KARARI VEREN: Oğuz Sayın (once "gercek split-screen dene" secti)
GEREKÇE: egdp-abap'ta ayni CL_GUI_DOCKING_CONTAINER+CL_GUI_ALV_GRID
  teknigi zaten "✔ uretildi" (ZCL_EGDP_COCKPIT) durumunda; bu ayni
  ortamda calistigina dair somut kanit. Kardes projedeki (zonetegra_
  edeclaration) CNTL_ERROR (Karar 007/008 orada) FARKLI bir raporda
  (KDV1_PREVIEW) ve muhtemelen implementasyon hatasindan kaynaklanmis -
  teknigin kendisi genel olarak calisiyor, dogru kullanildiginda.
  CL_GUI_TAB_STRIP icin ayni turden bir "calisan referans" bulunamadigi
  icin o kisimda daha dusuk riskli arac cubugu alternatifi tercih edildi.
ETKİLENEN MODÜLLER/DOSYALAR: src/zcl_zone_iarc_grid.clas.abap (yeni),
  src/zone_iarc_grid.prog.abap (yeni), src/README.md
```

### Karar 016

```text
KONU: UBL gonderici (satici) ve alici icin ayri, tam detayli tablolar
KARAR: ZONE_IARC_T015 (Gonderici/Satici) ve ZONE_IARC_T016 (Alici)
  eklendi - ikisi de MANDT+BUKRS+ETTN key'li (tekil, 1 belge=1 satici+
  1 alici). Sadece VKN/isim degil, tam UBL Party detayi: adres (sokak/
  ilce/il/posta kodu/ulke), vergi dairesi (PartyTaxScheme/TaxScheme/
  Name), iletisim (telefon/e-posta), bireysel musteri icin Person
  (FirstName/FamilyName, UBL-09). ZIF_ZONE_IARC_TYPES'a ty_party tipi +
  ty_header'a supplier_party/customer_party alanlari eklendi.
  ZCL_ZONE_IARC_PARSER'a paylasilan bir PARSE_PARTY metodu eklendi (DRY -
  hem satici hem alici icin ayni kod kullanilir). T009'daki eski
  SUPPLIER_VKN/SUPPLIER_NAME/CUSTOMER_VKN/CUSTOMER_NAME alanlari
  KALDIRILMADI (ZCL_ZONE_IARC_RESOLVER LIFNR eslemesi icin hala bunlari
  okuyor) - T015/T016 bunlarin uzerine ek detay saglar, mevcut kod
  bozulmadi.
SEÇENEKLER: Mevcut T009 alanlarini ty_party ile degistir (invasive,
  cok sayida cagiran yeri etkiler) / sadece ekle, mevcut alanlari
  koru (secildi)
KARAR TARİHİ: 2026-09-25
KARARI VEREN: Oğuz Sayın
GEREKÇE: Additive yaklasim, RESOLVER/POLLER/VIEWER/GRID/testler gibi
  cok sayida mevcut cagiran yerini bozma riskini ortadan kaldirdi;
  "gereksiz refactor yapma" ilkesiyle tutarli.
NOT (surec hatasi): Bu degisikligi belgelerken PowerShell'in
  Get-Content/-replace/Set-Content zinciriyle database-design.md'yi
  duzenlemeye calisirken dosyanin Turkce karakter kodlamasi bozuldu
  (UTF-8 mojibake). Hemen fark edilip `git checkout --` ile son commit'e
  geri donuldu ve degisiklikler Edit tool ile guvenli sekilde tekrar
  yapildi. Ders: Turkce/UTF-8 metin dosyalarinda asla PowerShell
  metin degistirme zinciri kullanma, her zaman Edit tool kullan.
ETKİLENEN MODÜLLER/DOSYALAR: src/zone_iarc_t015.tabl.xml (yeni),
  src/zone_iarc_t016.tabl.xml (yeni), src/zif_zone_iarc_types.intf.abap,
  src/zcl_zone_iarc_parser.clas.abap, src/zcl_zone_iarc_store.clas.abap,
  src/zcl_zone_iarc_mock.clas.abap, src/zcl_zone_iarc_parser.clas.testclasses.abap,
  architecture/database-design.md, architecture/technical-architecture.md,
  architecture/class-design.md, src/README.md
```

### Karar 017

```text
KONU: Servis tarafi uyarlama ekrani (URL + kullanici/sifre) - sifre
  goruntulenebilir olmamali
KARAR: Iki ayri mekanizma: (1) URL/environment/protocol gibi HASSAS
  OLMAYAN alanlar icin ZONE_IARC_T001/T002/T003 standart SM30 bakim
  gorunumu ile yonetilir (SE11 Table Maintenance Generator - elle
  acilir, abapGit ile uretilmez). (2) Sifre (PartnerPassCode,
  AccountantUserPassword) icin: yeni ZCL_ZONE_IARC_SECRET sinifi
  (CL_SECSTORE_ADMIN=>GET_DATA/SET_DATA ile en-iyi-caba) + yeni
  ZONE_IARC_SECRET raporu. Bu rapor WRITE-ONLY'dir: deger iki kez
  maskeli (SCREEN-INVISIBLE teknigi, ozel dynpro gerekmez) girilir,
  kaydedilince ekrandan hemen CLEAR edilir; "Kontrol Et" butonu sadece
  var/yok bilgisi verir, degeri ASLA geri gostermez. ZCL_ZONE_IARC_BASE
  ve ZCL_ZONE_IARC_PROVIDER'daki eski READ_SECRET stub'i kaldirilip
  ZCL_ZONE_IARC_SECRET=>READ ile degistirildi.
SEÇENEKLER: Sifreyi de customizing tablosuna (duz metin) yaz - REDDEDILDI,
  guvenlik ilkesine aykiri / SECSTORE + ayri write-only rapor (secildi)
KARAR TARİHİ: 2026-09-25
KARARI VEREN: Oğuz Sayın (soruyu sordu: "sifre gorulebiliyor olmamasi
  lazim, bunu nasil sagliriz")
GEREKÇE: SAP'nin standart guvenlik ilkesi - hassas veri customizing
  tablosunda asla duz metin tutulmaz, sadece referans anahtar adi
  tutulur; gercek deger Secure Storage'da, erisimi kisitli ve
  uygulamadan geri okunamayacak sekilde tutulur. CL_SECSTORE_ADMIN
  API'si TEK bir sinifta (ZCL_ZONE_IARC_SECRET) izole edildi ki yanlis
  API varsayimi cikarsa duzeltme tek yerde kalsin (S7/S11 hala acik).
ETKİLENEN MODÜLLER/DOSYALAR: src/zcl_zone_iarc_secret.clas.abap (yeni),
  src/zone_iarc_secret.prog.abap (yeni), src/zcl_zone_iarc_base.clas.abap,
  src/zcl_zone_iarc_provider.clas.abap, src/README.md,
  program/risks-and-open-questions.md (S11 guncellendi)
```
