# Zonetegra — Gelen e-Arşiv SAP Ürünü

Zonetegra servisi üzerinden gelen (tedarikçilerden alınan) **e-Arşiv UBL-TR `ArchiveInvoice`** faturalarını SAP'a periyodik olarak çeken, ham XML'i saklayan, tedarikçi/hesap eşlemesi yapan ve kullanıcı onayına açık (**park edilmiş**) muhasebe/satınalma belgesi olarak aktaran ürün.

> **Bu ürün MDP Group / e-Dönüşüm (`/MDPES/`) ürününden bağımsızdır.** Zonetegra müşteri hattında, kardeş proje `zonetegra_edeclaration`'dan da ayrı, kendi paket kodu (`ZONE_IARC`) ile geliştirilir.

## Doküman Durumu

Proje **taslak / tasarım** aşamasındadır. Aşağıdaki 3 temel karar bu oturumda netleşti (detay: [program/decision-log.md](program/decision-log.md)):

| Karar | Seçilen |
|---|---|
| Alma şekli | **Polling** (periyodik SM36 job) — push/webhook bu fazda kapsam dışı |
| Muhasebeleştirme | **Park + manuel onay** — hiçbir belge onaysız postalanmaz |
| Paket/isimlendirme | **`ZONE_IARC`** (müşteri Z-namespace, kayıtlı SAP namespace yok) |

Zonetegra'nın gerçek servis API sözleşmesi (endpoint, auth, sayfalama, ack) **henüz doğrulanmamıştır** — bkz. [program/risks-and-open-questions.md](program/risks-and-open-questions.md).

Durum etiketleri (kardeş projeyle ortak):

- `[ ]` Başlanmadı · `[~]` Devam ediyor · `[x]` Tamamlandı · `[!]` Bloke · `[?]` Karar bekliyor

## Ana Klasörler

```text
architecture/   Paket/isimlendirme, teknik mimari (pipeline), sınıf tasarımı, DDIC
program/        Karar günlüğü, açık sorular/riskler
```

## Mimari Akış (özet)

```text
[SM36 job] → Zonetegra servisi (polling) → kuyruk + ham XML sakla
   → UBL parse → tedarikçi (VKN/TCKN→LIFNR) eşleme → hesap/vergi/PO eşleştirme
   → PARK (MIRO veya FI) → kullanıcı onayı → POST
```

Detay: [architecture/technical-architecture.md](architecture/technical-architecture.md)

## Öncelikli Okuma Sırası

1. Bu dosya
2. [architecture/package-structure.md](architecture/package-structure.md) — isimlendirme ve uzunluk sınırları (yeni nesne açmadan önce **mutlaka**)
3. [architecture/technical-architecture.md](architecture/technical-architecture.md)
4. [architecture/class-design.md](architecture/class-design.md)
5. [architecture/database-design.md](architecture/database-design.md)
6. [program/risks-and-open-questions.md](program/risks-and-open-questions.md)

## Kod İskeleti

`src/` altında abapGit iskeleti üretildi (8 tablo, interface/class'lar, worklist + SM36 job raporu). Durum ve bilinen sınırlamalar: [src/README.md](src/README.md). Özet: mock provider ile pipeline uçtan uca çalıştırılabilir; Zonetegra gerçek adapter'ı ve MIRO/FI park BAPI çağrısı bilerek TODO bırakıldı (API sözleşmesi doğrulanmadan).

## Sonraki Adımlar (henüz yok — plan)

- `modules/` — muhasebeleştirme kural kataloğu, tedarikçi eşleme senaryoları (netleştikçe eklenecek)
- `testing/` — test stratejisi, kabul kriterleri
- `operations/` — job zamanlama, izleme
- Zonetegra API sözleşmesi doğrulanınca `zcl_zone_iarc_provider` gerçek wiring + `zcl_zone_iarc_post` gerçek BAPI çağrısı
