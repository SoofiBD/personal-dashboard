# Personal Dashboard

Tek kullanıcılı, kendi sunucunda çalıştırabileceğin kişisel finans dashboard’u. İlk modül Finance'tır; yeni modüller ileride `finance_module/` ile aynı sınırı izleyerek eklenebilir.

## Teknoloji ve veri sınırları

- Rails 7.1, Ruby 3.3 ve PostgreSQL 16
- Docker Compose ile sabit geliştirme ortamı
- Finans verileri PostgreSQL'de tutulur.
- Sahip adı, para birimi, saat dilimi ve veritabanı bağlantısı `.env.local` içindedir; kaynak kodda saklanmaz.
- Uygulama tek kişiliktir; kayıt veya giriş akışı yoktur. İlk sayfa açılışında yapılandırılmış dashboard sahibi oluşturulur.

## Başlatma

```bash
cp -n .env.example .env.local
# .env.local içindeki POSTGRES_PASSWORD değerini değiştir.
docker compose up --build
```

Tarayıcıda `http://localhost:3000/finance` adresini aç. İlk açılışta migration'lar otomatik uygulanır.

Container'ları arka planda başlatmak için:

```bash
docker compose up --build -d
```

Durdurmak için:

```bash
docker compose down
```

`docker compose down -v` veritabanı dahil yerel Docker verilerini siler; yalnızca sıfırdan başlamak istiyorsan kullan.

## Test

```bash
docker compose exec -T \
  -e RAILS_ENV=test \
  -e DATABASE_URL=postgresql://personal_dashboard:local-development-password@db:5432/personal_dashboard_test \
  web ./bin/rails test
```

Bu test komutu development veritabanına dokunmaz. Testlerde kullanıcı sahipliği ve dashboard'un oturumsuz, tek-kullanıcı akışı doğrulanır.

## Mimari

- `finance_module/`: Finance domain modelleri, controller'ları, servisleri, view'ları ve migration'ları.
- `app/`: Host dashboard layout'u, uygulama yardımcısı ve tek kullanıcı yapılandırması.
- `config/application.rb`: Finance paketini Rails yükleme/migration/view yollarına bağlar.
- `compose.yaml`: Web ve PostgreSQL servisleri.

Finans modülünün mevcut veri modeli korunmuştur. Yeni özellik eklenirken önce mevcut tabloların karşılayıp karşılamadığı kontrol edilmeli; gerekli değişiklikler geri alınabilir migration'lar olarak eklenmelidir.
