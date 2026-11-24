class HomeController < ApplicationController
  before_action :require_authentication

  def show
    @hide_sidebar = true
    @modules = [
      {
        key: "learning",
        title_key: "learning.title",
        default_title: "Learning Studio",
        description_key: "learning.subtitle",
        default_description: "Interview preparation, study plans and practice tracking.",
        path: learning_root_path,
        badge_key: "learning.badge",
        default_badge: "Learning",
        icon: "notes"
      },
      {
        key: "finance",
        title_key: "home.modules.finance.title",
        default_title: "Finance",
        description_key: "home.modules.finance.description",
        default_description: "Gelir-gider takibi, bütçeler, borçlar, hedefler ve akış analizi tek panelde.",
        path: finance_root_path,
        badge_key: "home.modules.finance.badge",
        default_badge: "Core",
        icon: "dashboard"
      },
      {
        key: "markitdown",
        title_key: "home.modules.markitdown.title",
        default_title: "MarkItDown",
        description_key: "home.modules.markitdown.description",
        default_description: "PDF ve belge içeriklerini temiz Markdown çıktısına dönüştürüp düzenleyin.",
        path: finance_document_conversions_path,
        badge_key: "home.modules.markitdown.badge",
        default_badge: "Docs",
        icon: "document"
      },
      {
        key: "pdf_tools",
        title_key: "home.modules.pdf_tools.title",
        default_title: "PDF Editor",
        description_key: "home.modules.pdf_tools.description",
        default_description: "PDF birleştirme, bölme, dönüştürme ve düzenleme araçlarını yerelde kullanın.",
        path: finance_pdf_tools_path,
        badge_key: "home.modules.pdf_tools.badge",
        default_badge: "PDF Tools",
        icon: "document"
      }
    ]
  end
end
