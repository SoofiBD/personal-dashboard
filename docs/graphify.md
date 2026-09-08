# Graphify ile kod ve not bilgi grafı

Graphify, dashboard'ın çalışırken kullandığı bir servis değildir. Kod, Markdown ve
diğer dokümanları yerelde tarayan bir geliştirme aracıdır. Bu ayrım, uygulama
imajına Python, tree-sitter veya LLM bağımlılıkları eklemeden bilgi grafı
özelliklerinden yararlanmayı sağlar.

## Hafif kurulum

Graphify'ı geliştirici makinesine bir kez kurun; uygulamanın `Gemfile`ına,
Docker imajına veya production Compose dosyalarına eklemeyin:

```bash
uv tool install graphifyy
cd personal-dashboard
graphify install --project --platform codex
graphify .
```

İlk haritalama `graphify-out/` altında `GRAPH_REPORT.md`, `graph.html` ve
`graph.json` üretir. Bu klasör `.gitignore` içindedir: grafikler kişisel
notları ve kaynak konumlarını içerebilir; depoya veya production'a gitmez.

## Yararlı günlük akış

```bash
# Modül/topluluk yapısını ve merkez düğümleri görmek
graphify explain "Notes::Note"

# Not bağlantılarının hangi kod yolundan yönetildiğini izlemek
graphify path "Notes::NotesController" "Notes::NoteLink"

# Kod değişikliğinden sonra yalnızca yerel grafiği güncellemek
graphify update .
```

Graphify'ın medya çıkarımı, bulut LLM sağlayıcıları, MCP sunucusu, grafik
veritabanı exportları ve dosya izleyicisi bu modülün ihtiyaçları için
kurulmaz. Not uygulamasının kendi araması, etiketleri ve çift yönlü
bağlantıları Rails/PostgreSQL içinde kalır. Uygulamadaki **Bağlantı grafiği**
bu ilişkileri bağımlılıksız SVG ile görselleştirir; Graphify'ın `graph.html`
çıktısı ise geliştirme sırasında kod ve doküman yapısını incelemek içindir.
