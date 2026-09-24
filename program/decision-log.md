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
