# Kişisel Finans Modülü — Ürün ve Mimari Taslağı

## Amaç

Panel hesabı, tüm araçların ortak sahibi olacak. Finans modülü bu hesabın altında çalışır:

```text
User (panel hesabı)
  ├── Finans verileri: hesaplar, işlemler, kategoriler, bütçeler, hedefler
  ├── PDF araç verileri: belgeler, düzenlemeler, çıktılar
  └── Gelecekteki araçların kendi verileri
```

Kullanıcı yalnızca panele giriş yapar. Finans sayfasına girdiğinde ikinci bir kayıt, aile/workspace veya banka bağlantısı istenmez. Her finans kaydında `user_id` bulunur; sorgular her zaman oturumdaki kullanıcı ile sınırlanır.

## Kapsam

İlk sürüm günlük kişisel bütçe kullanımını çözmeli:

1. Gelir ve giderleri elle kaydetmek.
2. Giderleri türüne göre takip etmek.
3. Aylık ve yıllık bütçe planı oluşturmak.
4. Birikim hedefi koymak ve hedefe ne zaman ulaşılacağını görmek.
5. Planlanan büyük bir satın almanın (ör. bilgisayar) güvenli olup olmadığını görmek.

İlk sürüm kapsamı dışı:

- Banka/Plaid bağlantısı, otomatik senkronizasyon ve açık bankacılık.
- Ortak aile bütçesi ve davet sistemi.
- Hisse, kripto, borç portföyü ve çift taraflı muhasebe.
- Abonelik/ödeme altyapısı.

Bu seçim, Maybe'nin güçlü ancak geniş finansal yapısından yalnızca kişisel bütçe için gerekli olan parçaları alır.

## Bilgi Mimarisi

Sol menüde panel araçları, finans altında ise bu beş görünüm yer alır:

| Sayfa | Kullanıcının cevabını aldığı soru | Ana içerik |
| --- | --- | --- |
| Genel Bakış | Bu ay durumum ne? | Net nakit akışı, kalan bütçe, yaklaşan hedefler, son işlemler |
| İşlemler | Param nereye gidiyor? | Gelir/gider listesi, arama, tarih ve kategori filtresi |
| Bütçe | Bu ay/yıl plana uyuyor muyum? | Aylık kategori limitleri, gerçekleşen harcama ve yıllık görünüm |
| Hedefler | Ne için ve ne kadar biriktiriyorum? | Hedef ilerlemesi, tahmini bitiş tarihi, aylık katkı |
| Satın Alma Planı | Bunu alabilir miyim? | Nakit etkisi, hedefleri geciktirme etkisi ve üç senaryo |

Mobilde finans alt menüsü üstte yatay kaydırılabilir sekmelere dönüşür. Büyük işlem tabloları kart görünümüne geçer; yatay taşma oluşturulmaz.

## Veri Modeli

Tüm para alanları `decimal(14,2)`; ekranda kullanıcının para birimiyle biçimlenir. Para birimi ilk aşamada kullanıcının profil ayarındaki `currency` değerinden gelir (varsayılan `TRY`). Tüm tarih ve dönem hesapları kullanıcının zaman diliminde yapılır.

```text
User
 ├── financial_accounts
 ├── categories
 ├── transactions
 ├── budget_periods
 │    └── budget_allocations
 ├── savings_goals
 │    └── goal_contributions
 └── purchase_plans
```

| Tablo | Temel alanlar | Not |
| --- | --- | --- |
| `financial_accounts` | `user_id`, `name`, `kind`, `opening_balance`, `is_active` | Nakit, banka, kart veya birikim hesabı. İlk sürümde manuel. |
| `categories` | `user_id`, `name`, `kind`, `color`, `icon`, `parent_id`, `sort_order` | `kind`: income, expense, transfer. En fazla iki seviye. |
| `transactions` | `user_id`, `financial_account_id`, `category_id`, `kind`, `amount`, `occurred_on`, `note`, `is_recurring` | `kind`: income, expense, transfer. Negatif tutar depolanmaz; tür işareti belirler. |
| `budget_periods` | `user_id`, `starts_on`, `ends_on`, `planned_income` | Aylık kayıt. `starts_on` için kullanıcı başına tekil indeks. |
| `budget_allocations` | `budget_period_id`, `category_id`, `planned_amount` | Yalnızca gider kategorileri. |
| `savings_goals` | `user_id`, `name`, `target_amount`, `target_date`, `starting_amount`, `monthly_contribution`, `priority`, `status` | Durum: active, paused, completed, archived. |
| `goal_contributions` | `savings_goal_id`, `transaction_id`, `amount`, `contributed_on`, `note` | İşleme bağlı veya bağımsız katkı. |
| `purchase_plans` | `user_id`, `name`, `price`, `planned_on`, `down_payment`, `monthly_cost`, `use_savings_goal`, `notes` | Bilgisayar gibi tek seferlik veya taksitli plan. |

Veri sahipliği için her tablo `user_id` üzerinden kontrol edilir. Dolaylı bağlı kayıtlarda (`budget_allocation`, `goal_contribution`) sahiplik üst kayıttan doğrulanır; istemciden gelen yabancı anahtar asla tek başına yetki kanıtı sayılmaz.

## Finans Mantığı

### İşlem ve kategori

- Gelir, gider ve transfer ayrı türlerdir. Transfer, gelir/gider raporlarına dahil edilmez.
- Kategori silindiğinde eski işlemler silinmez; kategori `Kategorisiz`e taşınır.
- Varsayılan gider grupları: Ev & faturalar, Market & yemek, Ulaşım, Sağlık, Eğitim, Eğlence, Alışveriş, Abonelikler, Diğer.
- Varsayılan gelir grupları: Maaş, Serbest iş, Ek gelir, İade/hediye, Diğer.
- Kullanıcı istediği kategori ve alt kategoriyi ekleyebilir; renk/ikon yalnızca görsel ayrım içindir.

### Aylık bütçe

Bir ayın bütçesi şunları gösterir:

```text
Kalan bütçe = Planlanan gider toplamı − gerçekleşen uygun giderler
Kategori kalan = Kategori limiti − o kategorinin gerçekleşen gideri
Plan dışı = Gerçekleşen gider − kategori limiti (limit aşılmışsa)
```

Ay ilk açıldığında, kullanıcının bir önceki ay planı varsa kategori limitleri kopyalanır. Gelir gerçekleşmesi, gider bütçesiyle karıştırılmaz: planlanan gelir ve gerçekleşen gelir ayrı gösterilir. Böylece düzensiz gelirli kullanıcı da net tabloyu görür.

### Yıllık plan

Yıllık görünüm, aylık planları yan yana toplar:

- Her ay için planlanan / gerçekleşen gelir, gider ve net fark.
- Kategori bazında yıllık limit ve harcama.
- 12 aylık nakit akışı çizgisi.
- Henüz bütçesi oluşmamış aylar için "Plan ekle" durumu.

Yıllık plan, ayrı bir harcama kaynağı değildir; aylık bütçelerin raporlanmış görünümüdür. Böylece çift veri girişi yapılmaz.

### Birikim hedefi

```text
Kalan hedef = max(hedef tutar − başlangıç tutarı − katkılar, 0)
Tahmini ay = kalan hedef / aylık katkı
Tahmini tarih = bugünün ayı + yukarı yuvarlanmış tahmini ay
```

Hedefe yapılan katkı istenirse ilgili birikim hesabına yapılan transferle ilişkilendirilir. Bu transfer harcama olarak sayılmaz.

### “Alabilir miyim?” analizi

Satın alma sayfası kesin bir finansal tavsiye vermez; kullanıcıya şeffaf bir planlama sonucu sunar.

```text
Serbest aylık nakit = Son 3 ay ortalama geliri −
                      Son 3 ay temel gider ortalaması −
                      Aktif hedeflerin aylık katkıları

Peşin ödeme sonrası güvenlik payı = Kullanılabilir nakit − peşin ödeme −
                                    1 aylık temel gider
```

Sonuç üç kolay anlaşılır durumla gösterilir:

- **Rahat:** Ödeme sonrası güvenlik payı pozitiftir ve aylık nakit akışı bozulmaz.
- **Planla:** Hedef tarihi veya aylık katkı etkilenir; etki gün/ay olarak açıklanır.
- **Ertele:** Ödeme bir aylık temel gider tamponunu azaltır ya da nakit akışını eksiye indirir.

Kullanıcı peşin, 3/6/12 taksit ve hedef birikimini kullanma senaryolarını yan yana görür. Hesaplama girdileri ve varsayımlar her zaman ekranda görünür ve düzenlenebilir olmalıdır.

## Genel Bakış Ekranı

Üstte ay seçici ve belirgin bir “İşlem ekle” düğmesi bulunur. İlk satırdaki dört kart:

1. Bu ay net nakit akışı.
2. Bütçeden kalan tutar.
3. Birikim hedeflerine bu ay ayrılan tutar.
4. Güvenle harcanabilecek tutar.

Alt kısımda iki görselleştirme vardır:

- Gelir/gider/serbest nakit için 6 aylık çizgi veya sütun grafiği.
- Kategori limitlerine karşı gerçekleşen harcama için yatay ilerleme çubukları.

Grafikte renk tek başına anlam taşımaz; tutar, etiket ve durum metni de bulunur. Kartlar bir sonraki eyleme bağlanır: örneğin limit aşımı kartı kullanıcıyı ilgili bütçe kategorisine götürür.

## Kullanıcı Akışları

### İlk kullanım

1. Kullanıcı panele kayıt olur ve finansı ilk kez açar.
2. Para birimini ve aylık net gelir beklentisini girer.
3. İsteğe bağlı olarak nakit/banka/birikim hesaplarını ekler.
4. Hazır kategorileri onaylar veya düzenler.
5. Bu ay için gider limitlerini belirler.
6. İsteğe bağlı ilk birikim hedefini ekler.

Kurulum 3 kısa adımda tamamlanır; hesap ve hedef adımları atlanabilir. Kullanıcı doğrudan “ilk işlem ekle”ye de geçebilir.

### Hızlı işlem ekleme

Tek ekranda tür, tutar, tarih, kategori ve not alanları bulunur. Gider seçiliyken sadece gider kategorileri listelenir. Form başarısız olursa alan altındaki hata korunur ve form başındaki hata özeti odağa taşınır.

### Bilgisayar satın alma

1. Kullanıcı hedef adını, fiyatı ve almak istediği tarihi girer.
2. Sistem seçili para kaynağı ve taksit seçenekleriyle senaryoları hesaplar.
3. Kullanıcı senaryoyu kaydeder veya bütçe/hedefe geri döner.
4. Satın alma gerçekleştiğinde plan tek tıkla işleme dönüştürülebilir.

## Uygulama Sınırları ve Rotalar

Finans, panelin bir alt modülüdür; bağımsız kullanıcı/oturum modeli taşımaz.

```text
/finance                         Genel bakış
/finance/transactions            İşlemler
/finance/budget/:month           Aylık bütçe
/finance/budget/year/:year       Yıllık plan
/finance/goals                   Birikim hedefleri
/finance/purchases               Satın alma planları
```

Her route, panelin merkezi `require_authentication` kontrolünden geçer. Finans controller/service katmanları yalnızca `Current.user` (veya uygulamadaki eşdeğeri) üzerinden veri yükler. Gelecekte PDF modülü de aynı kontrolü ve aynı `User` modelini kullanır.

## Uygulama Sırası

1. Merkezi panel kimlik doğrulaması ve `User` sahiplik sınırı.
2. Hesap, kategori ve işlem tabloları; işlem CRUD'u ve temel raporlar.
3. Aylık bütçe ve kategori limitleri.
4. Yıllık görünüm ve tahmin hesapları.
5. Birikim hedefleri ve katkılar.
6. Satın alma senaryosu ve işlemleştirme.

## Maybe'den Alınan, Alınmayanlar

| Karar | Gerekçe |
| --- | --- |
| İşlem / kategori / aylık bütçe ayrımı alındı | Raporlama ile bütçe limitlerini temiz ayırır. |
| Kategori hiyerarşisi en fazla iki seviyede tutuldu | Kullanıcının hızlı sınıflandırma ihtiyacına yeterli, gezinmesi kolay. |
| Dönem tabanlı bütçe alındı | Yıllık planı aylık verinin üstünde gösterebiliriz. |
| Aile modeli yerine `User` sahipliği kullanıldı | Panel tek kullanıcı hesabına göre tasarlanıyor. |
| Banka bağlantıları, yatırım/varlık, Plaid, abonelik ve AI sohbet alınmadı | İlk sürümün odak ve bakım maliyetini gereksiz büyütür. |

## Kabul Kriterleri

- Kullanıcı giriş yapmadan finans verilerine erişemez.
- Bir kullanıcı başka bir kullanıcının işlemi, hedefi veya bütçesini URL/API üzerinden okuyamaz ya da değiştiremez.
- Aylık bütçe, kategori limiti ile gerçekleşen gideri doğru karşılaştırır; transferler bu hesaplara girmez.
- Yıllık sayfa, aylık bütçe verisini tekrar veri girişi istemeden toplar.
- Birikim hedefi hedefe kalan tutarı ve tahmini bitiş tarihini gösterir.
- Satın alma planı, varsayımlarını görünür kılar ve sonucu “Rahat / Planla / Ertele” olarak açıklar.
- Formlar etiketli alanlara, alan içi hatalara ve klavye ile görünür odak durumuna sahiptir.
