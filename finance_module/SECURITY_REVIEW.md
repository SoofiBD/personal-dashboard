# Finans modülü güvenlik incelemesi

Tarih: 25 Ağustos 2026
Kapsam: `finance_module/` ve host uygulamadaki kimlik doğrulama entegrasyonu.

## Sonuç

Finans route'ları host uygulamanın parola korumalı session kimliğine bağlanmıştır. Modül, sahiplik doğrulamasını controller sorgusunda, model validasyonlarında ve yabancı anahtar kısıtlarında katmanlı olarak uygular. Parola provision edilmeden erişim kapalı kalır.

## Kontroller

| Alan | Sonuç | Kanıt |
| --- | --- | --- |
| Kimlik doğrulama | Geçti | Tüm finance controller'ları önce `require_authentication`, sonra `require_panel_user` filtresinden geçer. Resolver yalnızca session içindeki geçerli kullanıcı UUID'sini kabul eder. |
| BOLA / IDOR | Geçti | Kaynak getiren controller'lar `owned(Model).find(params[:id])` kullanır; doğrudan `Model.find` yoktur. |
| Toplu atama | Geçti | Tüm güçlü parametre listelerinde `user_id` yoktur. Sahiplik controller tarafından atanır. |
| Çapraz kullanıcı ilişki kurma | Geçti | İşlem-hesap/kategori, bütçe-kategori, hedef-işlem ve plan-hedef ilişkileri modelde aynı kullanıcı kontrolü yapar. |
| SQL enjeksiyonu | Geçti | Kullanıcı girdisiyle birleştirilmiş SQL bulunmuyor; sorgular Active Record bağlama mekanizmasını kullanır. |
| XSS | Geçti | Görünümler kullanıcı metnini ERB'nin varsayılan kaçış mekanizmasıyla yazar; `raw`, `html_safe` veya dinamik JavaScript yoktur. |
| CSRF | Host sorumluluğu | Modül normal `ApplicationController`dan türediği için Rails CSRF korumasını devralır. Host bunu devre dışı bırakmamalı. |
| Hassas oturum çerezi | Geçti | Cookie session `Secure` (production), `HttpOnly`, `SameSite=Lax` ve 12 saat sona erme ayarı kullanır. Login/logout sırasında session yenilenir. |
| Hassas browser cache | Geçti | Finance ve session yanıtları `no-store` kullanır; service worker yalnızca statik offline sayfasını cache'ler. |

## Doğrulanacak dağıtım ayarları

- Üretimde HTTPS zorunluluğu (`force_ssl`) ve HSTS.
- Kayıt/giriş ve parola sıfırlama uç noktalarında oran sınırlama.
- CSP, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` ve dar bir `Permissions-Policy`.
- Host ID tipi UUID değilse migration'lardaki `type: :uuid` alanlarının bigint olacak şekilde **migration çalıştırılmadan önce** değiştirilmesi.

## Test senaryoları

Dağıtım öncesi iki farklı kullanıcıyla şu senaryolar uygulanmalı:

1. Kullanıcı A'nın bir işlem URL'sini kullanıcı B oturumunda aç; yanıt 404 olmalı.
2. Kullanıcı B'nin hesap veya kategori kimliğini A'nın işlem formuna gönder; validasyon reddetmeli.
3. İstek gövdesine `user_id`, `role` veya başka beklenmeyen alanlar ekle; kayıt sahibi değişmemeli.
4. Metin alanlarına HTML/JavaScript metni gir; sayfa yeniden gösterildiğinde metin çalıştırılmadan kaçırılmış görünmeli.
5. Oturumu kapatıp eski oturum çereziyle finans sayfasını aç; erişim reddedilmeli.
