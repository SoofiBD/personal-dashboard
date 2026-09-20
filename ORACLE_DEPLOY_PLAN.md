# Oracle Cloud Free Tier Deploy Plan — Personal Dashboard

**Created:** 2026-09-20  
**Repo:** https://github.com/SoofiBD/personal-dashboard  
**Backup PR:** #109 (branch: `deploy-backup-20260920`)

---

## 🎯 Hedef

- **Platform:** Oracle Cloud Free Tier (ARM, 4 OCPU, 24 GB RAM, 200 GB disk)
- **Uygulama:** Rails 7.2 + Docker Compose (multi-service)
- **Kullanıcılar:** 3 kişi (sen + 2)
- **Maliyet:** $0 (Free Tier limitleri içinde)
- **NAS Erişimi:** OpenWrt router → Tailscale Subnet Router (sonraki aşama)

---

## 📋 Servisler (compose.production.yaml + compose.nas.yaml)

| Servis | Açıklama | Port (internal) |
|--------|----------|-----------------|
| `web` | Rails app (Puma) | 3000 |
| `jobs` | Solid Queue worker | — |
| `pdf-worker` | Python PDF conversion API | 8000 |
| `stirling-pdf` | Stirling PDF (Docker image) | 8080 |
| `chartdb` | ChartDB (custom build) | 80 |
| `gateway` | Caddy reverse proxy + auto-HTTPS | 80/443 |
| `db` | PostgreSQL 16 | 5432 |
| `nas-worker` | SMB adapter (Python/Flask) | 8000 |

**Network topology:** `edge` (public) → `gateway` → internal networks (`database`, `pdf`, `stirling`, `chartdb`, `nas`)

---

## 🔐 Secrets Yönetimi

Tüm secrets `./secrets/` klasöründe **dosya tabanlı** (Docker secrets), **git'e yazılmaz**.

| Secret Dosyası | Kaynak | Not |
|----------------|--------|-----|
| `rails_master_key.txt` | `rails credentials:edit` veya `rails secret` | 64+ char |
| `postgres_password.txt` | `openssl rand -hex 32` | |
| `pdf_worker_api_key.txt` | `openssl rand -hex 32` | |
| `stirling_pdf_password.txt` | `openssl rand -hex 32` | Stirling PDF admin şifresi |
| `nas_api_token.txt` | Mevcut `.env.nas.local`'den | 32+ char, HMAC |
| `nas_password.txt` | Mevcut `.env.nas.local`'den | NAS SMB şifresi |

---

## 📦 Deploy Adımları

### 1. Oracle VM Oluştur
```bash
# Oracle Console → Compute → Instances → Create Instance
# - Image: Ubuntu 24.04 (ARM)
# - Shape: VM.Standard.A1.Flex → 4 OCPU, 24 GB RAM
# - Boot volume: 200 GB
# - SSH Key: senin public key'in
# - VCN: Default (public subnet)
```

**Security List Ingress Rules:**
| Port | Protocol | Source | Açıklama |
|------|----------|--------|----------|
| 22 | TCP | 0.0.0.0/0 | SSH |
| 80 | TCP | 0.0.0.0/0 | HTTP (Caddy) |
| 443 | TCP | 0.0.0.0/0 | HTTPS (Caddy) |

---

### 2. VM'e Bağlan + Docker Kur
```bash
ssh ubuntu@<VM_PUBLIC_IP>

sudo apt update && sudo apt install -y docker.io docker-compose-plugin git
sudo usermod -aG docker $USER
newgrp docker  # veya logout/login

docker compose version  # doğrula
```

---

### 3. Tailscale Kur (VM tarafı)
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# Output URL'yi tarayıcıda aç → authenticate
# Exit node KAPALI
```

---

### 4. Proje Clone
```bash
# Private repo → Deploy key veya PAT
# Deploy key önerilir: GitHub repo Settings → Deploy keys → Add key (VM'in ~/.ssh/id_ed25519.pub)

git clone git@github.com:SoofiBD/personal-dashboard.git
cd personal-dashboard

# Veya PAT ile:
# git clone https://<PAT>@github.com/SoofiBD/personal-dashboard.git
```

---

### 5. Secrets Oluştur
```bash
mkdir -p secrets

# Mevcut .env.nas.local'den değerleri al
source .env.nas.local  # NAS_API_TOKEN, NAS_PASSWORD export olur

echo "super-secret-master-key-$(openssl rand -hex 32)" > secrets/rails_master_key.txt
echo "$(openssl rand -hex 32)" > secrets/postgres_password.txt
echo "$(openssl rand -hex 32)" > secrets/pdf_worker_api_key.txt
echo "$(openssl rand -hex 32)" > secrets/stirling_pdf_password.txt
echo "$NAS_API_TOKEN" > secrets/nas_api_token.txt
echo "$NAS_PASSWORD" > secrets/nas_password.txt

chmod 600 secrets/*.txt
```

---

### 6. `.env.production` Oluştur
```bash
cat > .env.production <<'EOF'
# Database
POSTGRES_DB=personal_dashboard_production
POSTGRES_USER=personal_dashboard
DATABASE_URL=postgresql://personal_dashboard:$(cat secrets/postgres_password.txt)@db:5432/personal_dashboard_production

# Domain — Caddy buna göre SSL alacak
DASHBOARD_DOMAIN=dash.burak.dev  # VEYA senin subdomain'in

# Timezone
DASHBOARD_TIME_ZONE=Europe/Istanbul

# AI — Gemini API Key
GEMINI_API_KEY=AIzaSy...  # SENİN KEY'İNİ BURAYA YAZ

# NAS Worker URL (internal Docker network)
NAS_WORKER_URL=http://nas-worker:8000
EOF
```

---

### 7. Build & Deploy
```bash
# Build (ARM64 için ilk sefer biraz sürer)
docker compose -f compose.production.yaml -f compose.nas.yaml build

# Başlat
docker compose -f compose.production.yaml -f compose.nas.yaml up -d

# Logları izle
docker compose -f compose.production.yaml -f compose.nas.yaml logs -f web
docker compose -f compose.production.yaml -f compose.nas.yaml logs -f nas-worker
```

---

### 8. DB Migration & Admin User
```bash
docker compose -f compose.production.yaml -f compose.nas.yaml exec web ./bin/rails db:migrate

docker compose -f compose.production.yaml -f compose.nas.yaml exec web ./bin/rails dashboard:credentials:provision
# Şifre soracak — KAYDET!
```

---

### 9. Doğrulama
- `https://dash.burak.dev` → açılmalı (Caddy auto-HTTPS)
- Giriş yap → Dashboard çalışıyor mu?
- NAS sekmesi → "Not configured" mı, yoksa bağlanıyor mu? (OpenWrt Tailscale sonra)

---

## 🌐 OpenWrt + Tailscale Subnet Router (NAS Erişimi İçin)

**Senaryo:** Lenovo ix2-dl (192.168.1.110) → OpenWrt router → Tailscale subnet router → Oracle VM

### OpenWrt'de:
```bash
# SSH into OpenWrt
opkg update && opkg install tailscale

# Subnet router olarak başlat
tailscale up --advertise-routes=192.168.1.0/24 --accept-routes

# Tailscale admin panel (https://login.tailscale.com/admin/machines) → 
# OpenWrt cihazını bul → "Routes" sekmesi → 192.168.1.0/24 onayla
```

### Oracle VM'de (zaten Tailscale kurulu):
```bash
# Route'ları kabul et
sudo tailscale up --accept-routes

# Test
tailscale ping <openwrt-tailscale-ip>
ping 192.168.1.110  # NAS'ın LAN IP'si — artık ulaşılabilir olmalı
```

### NAS Config (değişmez):
```bash
# .env.nas.local zaten doğru:
NAS_HOST=192.168.1.110  # LAN IP, Tailscale sayesinde VM'den erişilebilir
NAS_USER=admin
NAS_PASSWORD=...
NAS_SHARE=yedek
```

**Önemli:** ix2-dl'e **dokunmuyorsun**, OpenWrt router subnet router olur.

---

## 🔄 Güncelleme / Bakım

```bash
cd personal-dashboard
git pull origin main  # veya deploy branch
docker compose -f compose.production.yaml -f compose.nas.yaml build
docker compose -f compose.production.yaml -f compose.nas.yaml up -d
docker compose -f compose.production.yaml -f compose.nas.yaml exec web ./bin/rails db:migrate
```

---

## 💾 Backup Stratejisi

### Veritabanı (Günlük Cron)
```bash
# /etc/cron.daily/backup-db
#!/bin/bash
DATE=$(date +%F)
docker exec personal-dashboard-db-1 pg_dump -U personal_dashboard personal_dashboard_production | gzip > /root/backups/db_${DATE}.sql.gz
find /root/backups -name "db_*.sql.gz" -mtime +30 -delete
```

### Docker Volumes (Haftalık)
```bash
# /etc/cron.weekly/backup-volumes
#!/bin/bash
DATE=$(date +%F)
tar -czf /root/backups/volumes_${DATE}.tar.gz /var/lib/docker/volumes/personal-dashboard_*
```

### Restore
```bash
# DB
gunzip -c db_2026-09-20.sql.gz | docker exec -i personal-dashboard-db-1 psql -U personal_dashboard personal_dashboard_production

# Volumes
tar -xzf volumes_2026-09-20.tar.gz -C /
docker compose -f compose.production.yaml -f compose.nas.yaml up -d
```

---

## 🩺 Health Checks & Monitoring

```bash
# Servis durumu
docker compose -f compose.production.yaml -f compose.nas.yaml ps

# Health check'ler (compose'da tanımlı)
docker compose -f compose.production.yaml -f compose.nas.yaml exec web ruby -rnet/http -e "puts Net::HTTP.get_response(URI('http://127.0.0.1:3000/up')).code"

# Loglar
docker compose -f compose.production.yaml -f compose.nas.yaml logs --tail=100 web
docker compose -f compose.production.yaml -f compose.nas.yaml logs --tail=100 nas-worker
```

---

## 🚨 Troubleshooting Checklist

| Sorun | Kontrol |
|-------|---------|
| Site açılmıyor | `docker compose ps` → gateway/web healthy mi? |
| SSL yok | Caddy log: `docker compose logs gateway` → Let's Encrypt rate limit? |
| DB bağlantı hatası | `DATABASE_URL` doğru mu? `postgres_password.txt` secrets ile eşleşiyor mu? |
| NAS "Not configured" | `NAS_WORKER_URL` env var mı? `nas-worker` healthy mi? |
| NAS bağlantı hatası | Tailscale route onaylandı mı? `ping 192.168.1.110` VM'den çalışıyor mu? |
| Out of memory | `docker stats` → memory limit artır (compose'da `mem_limit`) |
| Disk doldu | `df -h` → log rotate, backup temizliği |

---

## 📝 Notlar / Sonraki Adımlar

- [ ] Domain DNS: `dash.burak.dev` → VM public IP (A record)
- [ ] OpenWrt Tailscale subnet router kurulumu
- [ ] NAS erişimi test et (listele, indir, yükle)
- [ ] Monitoring ekle (opsiyonel: uptime-kuma, prometheus/grafana)
- [ ] Backup cron job'ları aktif et
- [ ] `compose.test.yaml` CI/CD pipeline'a entegre et

---

## 📞 Acil Durumda

```bash
# Tüm servisleri durdur
docker compose -f compose.production.yaml -f compose.nas.yaml down

# Sadece web'i restart et
docker compose -f compose.production.yaml -f compose.nas.yaml restart web

# Tam temizlik (VERİ KAYBI!)
docker compose -f compose.production.yaml -f compose.nas.yaml down -v
```