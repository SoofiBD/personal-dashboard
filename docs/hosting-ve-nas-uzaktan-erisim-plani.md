# Hosting ve NAS uzaktan erişim planı

## Amaç

Personal Dashboard'un üç kişi tarafından sürekli, güvenli ve ücretsiz kullanılabilmesi; mevcut Lenovo ix2-dl NAS üzerindeki dosyalara da uzaktan erişilebilmesi.

## Mevcut durum

- Uygulama Ruby on Rails, PostgreSQL, arka plan işleri, PDF dönüştürücü, Stirling PDF ve ChartDB servislerinden oluşur.
- Üretim için `compose.production.yaml` mevcut. PostgreSQL ve dosya depolama Docker volume'larında kalır.
- Uygulamada NAS modülü bulunmaktadır. `nas-worker`, NAS'a özel bir SMB hesabıyla bağlanır; worker internete yayınlanmaz.
- NAS ekranı mevcut haliyle yalnızca `owner` rolüne açıktır. Diğer kullanıcıların NAS dosyalarına erişmesi istenirse ayrıca rol/klasör yetkilendirmesi geliştirilmelidir.

## Lenovo ix2-dl değerlendirmesi

Lenovo ix2-dl, uygulamanın ana sunucusu olarak kullanılmayacak:

- Cihazın Marvell Kirkwood işlemcisi ve yaklaşık 256 MB belleği; Rails, PostgreSQL ve PDF servislerini çalıştırmak için yetersizdir.
- Özellikle Stirling PDF üretim tanımında 2 GB bellek sınırıyla yapılandırılmıştır.
- NAS'ın yönetim arayüzü veya SMB (TCP 445) hizmeti internete doğrudan açılmayacak.

NAS, dosya depolama cihazı olarak kullanılmaya devam edecek.

## Hedef mimari

```text
Kullanıcılar
    |
    | HTTPS / özel VPN
    v
Ücretsiz bulut sunucusu (Oracle Always Free adayı)
    ├── Personal Dashboard + PostgreSQL + PDF servisleri
    └── Güvenli VPN tüneli / subnet route
                 |
                 v
Ev ağı -> Lenovo ix2-dl (SMB yalnızca yerel ağda)
```

## Tercih edilen yaklaşım

1. Dashboard'u Oracle Cloud Always Free üzerinde Docker Compose ile yayınlamak.
2. NAS'a doğrudan internetten port açmamak.
3. Ev ağı ile bulut sunucusu arasında Tailscale veya WireGuard tabanlı özel ağ kurmak.
4. NAS SMB erişimini yalnızca bu özel ağ üzerinden `nas-worker` için kullanılabilir hale getirmek.

Bu yol, uygulama ve NAS'a dışarıdan erişimi bir araya getirirken NAS yönetim paneli ile SMB servislerini genel internete açık bırakmaz.

## OpenWrt seçeneği

Mevcut modem/router modeli destekliyorsa OpenWrt faydalı olabilir. OpenWrt üzerinde Tailscale veya WireGuard çalıştırılarak cihaz, ev ağı için sürekli çalışan VPN ağ geçidi (subnet router) olur. Böylece bulut sunucusundaki dashboard, NAS'ın yerel IP adresine özel tünel üzerinden erişir.

Bu seçenek ancak cihazın OpenWrt tarafından desteklenmesi ve Tailscale için yeterli flash/belleğe sahip olması halinde uygulanacak. Ek paketler için en az 16 MB flash ve 128 MB RAM tercih edilir. Kurulumdan önce cihazın tam donanım sürümü, mevcut internet bağlantı türü ve güvenli geri dönüş yöntemi doğrulanmalıdır; yanlış ürün yazılımı modemi kullanılmaz hale getirebilir veya ISS ayarlarını silebilir.

## Bekleyen bilgi ve kararlar

Modem/router bilgileri alındığında aşağıdakiler kontrol edilecek:

- Marka, model ve yazılım sürümü.
- Tailscale, WireGuard, OpenVPN istemcisi veya subnet router desteği.
- Dinamik DNS, IPv6 ve CGNAT durumu.
- Ev ağında sürekli çalışan başka bir cihaz olmadan güvenli ağ geçidi kurulup kurulamayacağı.

Router uygun değilse, NAS uzaktan erişimi için düşük güç tüketimli, sürekli açık ayrı bir ağ geçidi cihazı gerekir. Dashboard yine ücretsiz bulut sunucusunda çalışabilir; NAS entegrasyonu bu cihaz sağlanana kadar kapalı tutulur.

## Yayına geçmeden önce

- Oracle hesabında yalnızca Always Free kaynaklarının seçildiğini doğrulamak.
- Güçlü üretim veritabanı parolası ve `RAILS_MASTER_KEY` oluşturmak.
- Kullanıcı hesaplarını ve MFA'yı etkinleştirmek.
- PostgreSQL ve Active Storage verilerini şifreli, düzenli ve geri yüklemesi test edilmiş bir yedekleme düzenine almak.
- NAS için ayrı, en az yetkili SMB hesabı kullanmak.
