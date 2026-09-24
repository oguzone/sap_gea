# ABAP Paket Yapısı ve İsimlendirme

> **Bu doküman MDP Group / `/MDPES/` namespace'inden bağımsızdır.** Kaynak kararlar: [../program/decision-log.md](../program/decision-log.md) Karar 001.

## Namespace Kararı (Karar 001)

Kayıtlı bir SAP namespace'i yok; müşteri (Z) namespace'inde **`ZONE_IARC`** ürün kodu kullanılıyor (Zonetegra + Incoming ARChive).

```text
Class      : ZCL_ZONE_IARC_<isim>     (örn. ZCL_ZONE_IARC_PARSER)
Interface  : ZIF_ZONE_IARC_<isim>     (örn. ZIF_ZONE_IARC_PROVIDER)
Exception  : ZCX_ZONE_IARC[_<alt>]    (örn. ZCX_ZONE_IARC_MAPPING)
DDIC tablo : ZONE_IARC_T0xx           (tablo adı zaten Z ile başladığı için
                                        ayrıca ikinci bir Z eklenmez)
Message cl.: ZONE_IARC_MC01
Auth obj.  : Z_IARC
```

Kayıtlı bir namespace (`/XXXX/`) ileride alınırsa (veya ürün MDP `/MDPES/` ailesine dahil edilirse), bu doküman ve `src/` altındaki tüm nesne adları göç planıyla birlikte güncellenir.

## Uzunluk Sınırları — Önden Kontrol Listesi

> Kardeş proje `zonetegra_edeclaration`'da (`ZONE_EDC` öneki, 3 karakter kısa ürün kodu) bu sınırlar **iki ayrı abapGit pull denemesinde gerçek aktivasyon hatası** olarak ortaya çıktı (decision-log Karar 005/006). `ZONE_IARC` öneki (`IARC` = 4 karakter) `EDC`'den (3 karakter) 1 karakter daha uzun olduğundan bütçe daha da dar — bu liste **önden** kontrol edilmeli.

| Nesne tipi | Teknik sınır | Önek tükettiği | Kalan bütçe (isim kısmı) |
|---|---|---|---|
| Class / Interface / Exception adı | **30 karakter** | `ZCL_ZONE_IARC_` / `ZIF_ZONE_IARC_` / `ZCX_ZONE_IARC_` = 14 karakter | **16 karakter** |
| DDIC tablo/yapı adı | **16 karakter** | `ZONE_IARC_` = 10 karakter | **6 karakter** — bu yüzden **açıklayıcı son ek kullanılmaz**, sadece `T001`, `T002`... sıra no (bkz. aşağı) |
| Yetki nesnesi adı | **10 karakter** | — | `Z_IARC` (6 karakter) kullanılır, `Z_ZONE_IARC` (11) **sığmaz** |
| DD03P-DATATYPE (alan veri tipi kısa kodu) | **4 karakter** | — | `STRING` yazılamaz → **`STRG`**; `XSTRING` yazılamaz → **`RSTR`** |
| SQL rezerve kelimeler | — | — | `SECTION`, `ORDER`, `GROUP`, `LEVEL`, `COMMENT` gibi kelimeler alan adı olarak **kullanılmaz** |
| CURR/QUAN tipi alan (para tutarı/miktar) | — | — | `WRBTR`/`DMBTR` gibi para birimi alanları **aynı tabloda bir `WAERS` alanına `REFTABLE`/`REFFIELD` ile referans vermeli**, yoksa "specify reference table and reference field" aktivasyon hatası alınır — gerçek pull'da `ZONE_IARC_T006-AMOUNT` için alındı (Karar 007) |

**Bu yüzden alınan tasarım kararı:** DDIC tablo bütçesi (6 karakter) `_C_API` gibi açıklayıcı customizing alt-son ekine (kardeş projenin ilk denemesinde kullandığı ve sonradan kısaltmak zorunda kaldığı desen) yer bırakmıyor. Bu nedenle **tüm tablolar** (customizing + runtime ayrımı yapılmadan) `ZONE_IARC_T001`, `T002`, … şeklinde **sıra numarasıyla** adlandırılır; anlamı [database-design.md](database-design.md) tablosunda açıklanır. Bu, `/MDPES/EDOC_T0xx` ve kardeş `ZISU_EDM_T001` paternleriyle de tutarlıdır.

Yeni bir class/interface eklerken isim kısmı (prefix sonrası) **16 karakteri**, yeni tablo eklerken sıra no **3 haneyi** (`T001`–`T999`) geçmemelidir.

## Paket Kararı

MVP kapsamı (tek entegratör — Zonetegra, tek akış — gelen e-Arşiv) çoklu alt paket ayrımını gerektirmeyecek kadar küçük:

```text
ZONE_IARC   -- tüm interface/class/exception/DDIC nesneleri
```

İleride ikinci bir entegratör veya ikinci bir belge tipi eklenirse alt paket ayrımı (`ZONE_IARC_CORE`/`ZONE_IARC_INT` vb.) değerlendirilir.

## Açık Kalan Paket Kararları

- `[?]` Transport layer / software component
- `[?]` Local (`$TMP`) / transportable paket kararı
- `[?]` Bu ürün ileride kayıtlı bir namespace'e (`/ZONE/` vb.) veya MDP `/MDPES/` ailesine taşınacak mı — şimdilik hayır varsayımıyla ilerleniyor

Bir karar netleştiğinde bu dosya güncellenmeli ve [../program/decision-log.md](../program/decision-log.md) içine kaydedilmelidir.
