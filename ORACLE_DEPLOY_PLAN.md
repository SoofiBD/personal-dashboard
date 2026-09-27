# Oracle Cloud yayın planı

Son gözden geçirme: 2026-09-27. Bu plan bir dağıtım kontrol listesidir; çalışan bir Oracle sunucusunda uçtan uca doğrulama yapılmadan “yayına hazır” kabul edilmez. Uygulama desteklenen Rails 8.1 serisine yükseltildi; parola sıfırlama alanı çakışması için yeni migration eklenmiştir. Migration eski parola sıfırlama bağlantılarını güvenlik gereği geçersiz kılar.

## Yayın mimarisi

- Dashboard, Oracle VM üzerinde HTTPS ile yayınlanacak. Rails, PostgreSQL, PDF işçisi, Stirling PDF, ChartDB ve Caddy Oracle tarafında çalışacak.
- Veritabanı ve işçi servisleri özel Docker ağlarında kalır; yalnız Caddy 80/443 üzerinden dışarı açılır.

## Oracle kapasitesi ve maliyet kontrolü

Oracle'ın [güncel Always Free kaynak belgesi](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm), A1 için toplam **2 OCPU / 12 GB RAM** ve boot + block volume toplamında **200 GB** ücretsiz kota listeliyor; eski plandaki 4 OCPU / 24 GB varsayımı geçerli kabul edilmemeli. Varsayılan boot volume yaklaşık 50 GB'dır; 200 GB'ın tamamı otomatik olarak VM dosya sistemi değildir. Uygunluk, bölge, kapasite ve ücretlendirme Oracle Console'da oluşturma anında tekrar kontrol edilir. Idle Always Free VM'ler geri alınabilir; yedekler VM dışında tutulur.

Yerel ARM ölçümünde yaklaşık imaj boyutları: Rails üretim 220 MB, PDF işçisi 176 MB, ChartDB 39 MB; önceki ölçümde Stirling PDF 3.27 GB, PostgreSQL 411 MB. Bunlar tek tek görünen imaj boyutlarıdır; paylaşılan katmanlar, build cache, veritabanı, yüklenen dosyalar ve yedekler yüzünden gerçek disk tüketimi ayrıca ölçülmelidir. Kaynak kod klasörünün Mac'te kapladığı yaklaşık 457 MB sunucu ihtiyacının doğru ölçüsü değildir. İlk ARM build'i ve Stirling/PDF eşzamanlı kullanımında CPU, RAM ve disk yük testi yapılır.

## Yayın öncesi kapılar

1. Açık PR'lar, yerel değişiklikler, CI lint/test/security kontrolleri ve migration durumu netleştirilir. Çalışan dal değil, doğrulanmış commit dağıtılır.
2. Alan adı ve Oracle Always Free uygun A1 kapasitesi doğrulanır. Ubuntu ARM VM, ev bölgesinde uygun boot volume ile oluşturulur. SSH anahtarı kullanılır; 22/TCP yalnız yönetim IP'sine sınırlandırılır (bu mümkün değilse ek SSH sertleştirmesi yapılır). Dışarıya yalnız 80/443 açılır. PostgreSQL, PDF, Stirling ve ChartDB portları yayınlanmaz.
3. VM'de Docker Engine ve Compose kurulur. Private repo için salt-okunur deploy key kullanılır; PAT URL içine veya shell geçmişine yazılmaz.
4. `secrets/` Git dışında, yalnız yönetici tarafından okunabilir izinlerle hazırlanır. `rails_master_key.txt` **mevcut `config/credentials.yml.enc` dosyasını açan gerçek anahtar** olmalıdır; rastgele yeni bir anahtar üretmek mevcut credentials'ı kullanılmaz hale getirir. `postgres_password.txt` ve `pdf_worker_api_key.txt` sağlanır. Gerçek değerler plana, Git'e veya loglara yazılmaz.
5. `.env.production.example` üzerinden Git dışı, yalnız yöneticiye okunabilir `.env.production` hazırlanır. `DATABASE_URL` içindeki parola `postgres_password.txt` ile birebir aynı olmalı; URL özel karakterleri uygun biçimde kodlanmalıdır. `DASHBOARD_DOMAIN` gerçek DNS kaydıyla eşleşir; `STIRLING_PDF_PASSWORD` benzersiz güçlü parola olmalıdır. Stirling'in belgelenmiş `SECURITY_INITIALLOGIN_PASSWORD` ayarı kullanılır; desteklenmeyen `_FILE` varyantına güvenilmez. İlk girişten sonra parola uygulama içinde değiştirilir ve varsayılan `admin/stirling` çalışmamalıdır. `GEMINI_API_KEY` gerekiyorsa güvenli biçimde eklenir. Web üzerinden parola sıfırlama kullanılacaksa `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM` ayarlanır ve teslimat test edilir; SMTP yokken sıfırlama e-postası gönderilmez. Eski plandaki `<<'EOF'` içinde `$(cat ...)` kullanımı parola yerleştirmez; bu yöntem kullanılmaz.
6. Compose doğrulanır, derlenir ve başlatılır:

   ```bash
   docker compose --env-file .env.production -f compose.production.yaml config --quiet
   docker compose --env-file .env.production -f compose.production.yaml build
   docker compose --env-file .env.production -f compose.production.yaml up -d
   docker compose --env-file .env.production -f compose.production.yaml ps
   ```

7. Web giriş noktası `db:prepare` çalıştırır. Ardından migration durumu kontrol edilir ve gerçek görev adı olan `dashboard:credentials:set` ile owner şifresi etkileşimli belirlenir; eski plandaki `dashboard:credentials:provision` görevi mevcut değildir. Parola en az 16 karakterdir ve kalıcı shell geçmişine yazılmaz.

   ```bash
   docker compose --env-file .env.production -f compose.production.yaml exec web ./bin/rails db:migrate:status
   docker compose --env-file .env.production -f compose.production.yaml exec web ./bin/rails dashboard:credentials:set
   ```

8. Dış ağdan HTTPS, oturum/MFA, parola sıfırlama e-postası ve tek kullanımlık bağlantı, finans, notlar, eğitim, spor, AI, PDF dönüştürme/düzenleme ve ChartDB kontrol edilir. PDF işçisi ve Stirling ağır işlemleri birlikte çalışırken `docker stats` ve `df -h` izlenir. Alan adı/TLS ve geri yükleme testi geçmeden üretim verisi taşınmaz. ChartDB'nin Monaco editörü tek başına yaklaşık 16 MB küçültülmüş JS dosyası üretir; uzak ağda ilk açılış süresi özellikle ölçülür.

## Yedek ve işletim

- PostgreSQL ve `storage_data` için düzenli, şifreli ve VM dışına taşınan yedek kurulur. Bir yedek üzerinde geri yükleme testi yapılır. `docker compose down -v` veri sildiği için olağan bakım komutu değildir.
- Docker imajları, build cache, loglar ve yüklenen belgeler için disk doluluk alarmı; web, jobs, PDF işçisi, Stirling ve veritabanı için sağlık kontrolleri izlenir. 50 GB varsayılan boot diskinde boş alan özellikle takip edilir.
- Güncelleme öncesi veritabanı/volume yedeği alınır; doğrulanmış commit için `build`, `up -d`, migration kontrolü ve kısa smoke test tekrarlanır. Başarısızlıkta önce uygulama commit'i geri alınır; veritabanı geri yükleme yalnız doğrulanmış yedek prosedürüyle yapılır.
