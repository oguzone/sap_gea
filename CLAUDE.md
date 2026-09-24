# CLAUDE.md

Bu dosya, Claude Code'a bu repo üzerinde çalışırken rehberlik eder.

## Repo niteliği

Bu repo, SAP üzerinde geliştirilecek **Gelen e-Arşiv** ürününün (Zonetegra servisi üzerinden tedarikçilerden gelen e-Arşiv UBL-TR `ArchiveInvoice` faturalarının periyodik çekilmesi, saklanması, tedarikçi/hesap eşlemesi yapılması ve kullanıcı onayı sonrası muhasebe/satınalma belgesi olarak postalanması) analiz, mimari ve DDIC dokümanlarını içerir. Henüz kod, DDIC nesnesi veya transport yok; tasarım/spesifikasyon aşamasındadır.

**Önemli — bağımsızlık uyarısı:** Bu ürün, MDP Group / SAP e-Dönüşüm (`/MDPES/` namespace, `sap-edonusum-team` repo, `MDP_ABAP_STANDARDS.md`) ürününden **tamamen bağımsızdır**. `/MDPES/` namespace'i, MDP paket tablosu, DDIC rezervasyonu veya rol dosyaları bu repoya uygulanmaz.

**Kardeş proje notu:** Aynı `workspace_one` altında **`zonetegra_edeclaration`** (e-Beyanname/KDV1) reposu, aynı müşteri (Zonetegra) için, `ZONE_EDC` ürün koduyla geliştiriliyor. Bu repo (`ZONE_IARC` ürün kodu) onunla **aynı müşteri hattında ama ayrı bir üründür** — kod tabanı, paket ve tablolar paylaşılmaz; yalnızca adlandırma pattern'i (`Z<isim>_ZONE_<ÜRÜN KODU>_...`) ve öğrenilen DDIC kısıtları (bkz. `architecture/package-structure.md`) ortak referans olarak kullanılır. Bir karar veya nesne ismi üretirken bu iki projeyi karıştırma.

Tüm içerik Türkçe'dir; mevcut dokümanları düzenlerken ve yeni doküman yazarken bu dili koru.

## Okuma stratejisi

Doküman seti küçük. Görev tipine göre:

- **Ürün kapsamı / pipeline soruları** → [README.md](README.md)
- **Paket/namespace/isimlendirme, uzunluk sınırları** → [architecture/package-structure.md](architecture/package-structure.md)
- **Mimari akış, katmanlar** → [architecture/technical-architecture.md](architecture/technical-architecture.md)
- **Sınıf/interface tasarımı, provider factory** → [architecture/class-design.md](architecture/class-design.md)
- **DDIC tablo/alan detayı** → [architecture/database-design.md](architecture/database-design.md)
- **Açık kararlar / riskler** → [program/risks-and-open-questions.md](program/risks-and-open-questions.md)
- **Alınan kararlar geçmişi** → [program/decision-log.md](program/decision-log.md)

## Açık kararlar hakkında

Bu doküman setinde Zonetegra servisinin gerçek API sözleşmesi (endpoint, auth, `list`/`get`/`ack` davranışı, sayfalama) **henüz doğrulanmamıştır** — bkz. [program/risks-and-open-questions.md](program/risks-and-open-questions.md). Bu tür konularda ABAP kodu veya kesin teknik tasarım önerirken:

1. Önce `program/risks-and-open-questions.md` dosyasını kontrol et — soru zaten açık mı listelenmiş?
2. Kesin bir karar/doğrulama yoksa, kullanıcıdan karar/teyit iste veya öneriyi "taslak/geçici" olarak işaretle; sanki API sözleşmesi netmiş gibi kesin wiring kodu üretme.
3. Bir karar netleşirse [program/decision-log.md](program/decision-log.md) içine kaydet (şablon dosyanın içinde) ve etkilenen dosyaları güncelle.

## Düzenleme kuralları

- Başlıklar, gövde metni ve tablo etiketleri Türkçe olmalı.
- Doküman içi çapraz linkler dosyanın bulunduğu konumdan göreceli olmalı (örn. `architecture/` içinden `../program/decision-log.md`).
- Yeni DDIC nesnesi önerirken **önce** [architecture/package-structure.md](architecture/package-structure.md) içindeki uzunluk sınırı tablosunu kontrol et — kardeş projede (`zonetegra_edeclaration`) bu sınırlar aşıldığında gerçek abapGit aktivasyon hatası alınmıştı (Karar 005/006 orada).
- Liste/kokpit ekranlarında **`CL_SALV_TABLE` değil `CL_GUI_ALV_GRID`** kullanılır (bu müşteri hattında sabitlenmiş tercih).
