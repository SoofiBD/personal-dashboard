# Finans modülü güvenlik incelemesi

Tarih: 20 Ağustos 2026  
Kapsam: `finance_module/` kaynak kodu; yalnızca kullanıcının sağladığı yerel çalışma alanı.

## Sonuç

Statik incelemede raporlanacak kritik veya yüksek şiddetli bir bulgu yok. Modül, sahiplik doğrulamasını controller sorgusunda, model validasyonlarında ve yabancı anahtar kısıtlarında katmanlı olarak uygular.

## Kontroller

| Alan | Sonuç | Kanıt |
| --- | --- | --- |
| Kimlik doğrulama | Geçti | Tüm controller'lar `require_panel_user` filtresinden geçer. Kullanıcı host panelin oturum resolver'ından alınır. |
| BOLA / IDOR | Geçti | Kaynak getiren controller'lar `owned(Model).find(params[:id])` kullanır; doğrudan `Model.find` yoktur. |
| Toplu atama | Geçti | Tüm güçlü parametre listelerinde `user_id` yoktur. Sahiplik controller tarafından atanır. |
| Çapraz kullanıcı ilişki kurma | Geçti | İşlem-hesap/kategori, bütçe-kategori, hedef-işlem ve plan-hedef ilişkileri modelde aynı kullanıcı kontrolü yapar. |
| SQL enjeksiyonu | Geçti | Kullanıcı girdisiyle birleştirilmiş SQL bulunmuyor; sorgular Active Record bağlama mekanizmasını kullanır. |
| XSS | Geçti | Görünümler kullanıcı metnini ERB'nin varsayılan kaçış mekanizmasıyla yazar; `raw`, `html_safe` veya dinamik JavaScript yoktur. |
| CSRF | Host sorumluluğu | Modül normal `ApplicationController`dan türediği için Rails CSRF korumasını devralır. Host bunu devre dışı bırakmamalı. |
| Hassas oturum çerezi | Host sorumluluğu | Üretimde `Secure`, `HttpOnly` ve `SameSite=Lax` ya da daha sıkı ayarlar zorunlu olmalı. |

## Doğrulanacak dağıtım ayarları

- Üretimde HTTPS zorunluluğu (`force_ssl`) ve HSTS.
- Oturum çerezinde `secure: true`, `httponly: true`, `same_site: :lax` veya `:strict`.
- Kayıt/giriş ve parola sıfırlama uç noktalarında oran sınırlama.
- Finans sayfaları için `Cache-Control: no-store`.
- CSP, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` ve dar bir `Permissions-Policy`.
- Host ID tipi UUID değilse migration'lardaki `type: :uuid` alanlarının bigint olacak şekilde **migration çalıştırılmadan önce** değiştirilmesi.

## Test senaryoları

Dağıtım öncesi iki farklı kullanıcıyla şu senaryolar uygulanmalı:

1. Kullanıcı A'nın bir işlem URL'sini kullanıcı B oturumunda aç; yanıt 404 olmalı.
2. Kullanıcı B'nin hesap veya kategori kimliğini A'nın işlem formuna gönder; validasyon reddetmeli.
3. İstek gövdesine `user_id`, `role` veya başka beklenmeyen alanlar ekle; kayıt sahibi değişmemeli.
4. Metin alanlarına HTML/JavaScript metni gir; sayfa yeniden gösterildiğinde metin çalıştırılmadan kaçırılmış görünmeli.
5. Oturumu kapatıp eski oturum çereziyle finans sayfasını aç; erişim reddedilmeli.

