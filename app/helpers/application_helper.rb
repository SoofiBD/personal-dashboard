module ApplicationHelper
  def dashboard_currency(value)
    currency = if respond_to?(:current_panel_user) && current_panel_user
      current_panel_user.currency
    else
      current_user&.currency || "$"
    end
    number_to_currency(value || 0, unit: currency, format: "%n %u", delimiter: ".", separator: ",")
  end

  def account_currency(value, account)
    number_to_currency(value || 0, unit: account.currency, format: "%n %u", delimiter: ".", separator: ",")
  end

  def finance_navigation_item(label, path, icon_name = nil, badge: nil)
    is_active = current_page?(path)
    class_name = is_active ? "sidebar-link is-active" : "sidebar-link"

    link_to path, class: class_name, "aria-current": (is_active ? "page" : nil) do
      concat finance_svg_icon(icon_name, class: "nav-icon") if icon_name
      concat content_tag(:span, label, class: "nav-label")
      concat content_tag(:span, badge, class: "nav-unread-badge", "aria-label": "#{badge} okunmamış bildirim") if badge.to_i.positive?
      if is_active
        concat content_tag(:span, "", class: "nav-active-pill")
      end
    end
  end

  def language_switcher
    current_locale = I18n.locale.to_sym
    content_tag(:div, class: "language-switcher", role: "group", "aria-label": t("app.sidebar.language", default: "Dil / Language")) do
      link_to(change_locale_path(:tr), class: "lang-btn #{"is-active" if current_locale == :tr}", title: "Türkçe", "aria-pressed": (current_locale == :tr)) do
        concat content_tag(:span, "🇹🇷", class: "lang-flag")
        concat content_tag(:span, "TR", class: "lang-code")
      end +
        link_to(change_locale_path(:en), class: "lang-btn #{"is-active" if current_locale == :en}", title: "English", "aria-pressed": (current_locale == :en)) do
          concat content_tag(:span, "🇬🇧", class: "lang-flag")
          concat content_tag(:span, "EN", class: "lang-code")
        end
    end
  end

  def finance_svg_icon(name, options = {})
    css_class = options[:class] || "icon"
    case name.to_s
    when "dashboard", "overview"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.rect(width: "7", height: "9", x: "3", y: "3", rx: "1") +
          tag.rect(width: "7", height: "5", x: "14", y: "3", rx: "1") +
          tag.rect(width: "7", height: "9", x: "14", y: "12", rx: "1") +
          tag.rect(width: "7", height: "5", x: "3", y: "16", rx: "1")
      end
    when "transactions", "activity"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.path(d: "m3 16 4 4 4-4") +
          tag.path(d: "M7 20V4") +
          tag.path(d: "m21 8-4-4-4 4") +
          tag.path(d: "M17 4v16")
      end
    when "recurring", "repeat"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.path(d: "m17 2 4 4-4 4") + tag.path(d: "M3 11V9a3 3 0 0 1 3-3h15") +
          tag.path(d: "m7 22-4-4 4-4") + tag.path(d: "M21 13v2a3 3 0 0 1-3 3H3")
      end
    when "accounts", "wallet"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.rect(width: "20", height: "14", x: "2", y: "5", rx: "2") +
          tag.line(x1: "2", x2: "22", y1: "10", y2: "10")
      end
    when "categories", "tags"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.path(d: "M12 2H2v10l9.29 9.29c.94.94 2.48.94 3.42 0l6.58-6.58c.94-.94.94-2.48 0-3.42L12 2Z") +
          tag.path(d: "M7 7h.01")
      end
    when "budget", "chart"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.path(d: "M21.21 15.89A10 10 0 1 1 8 2.83") +
          tag.path(d: "M22 12A10 10 0 0 0 12 2v10z")
      end
    when "savings_goals", "target", "piggy"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.circle(cx: "12", cy: "12", r: "10") +
          tag.circle(cx: "12", cy: "12", r: "6") +
          tag.circle(cx: "12", cy: "12", r: "2")
      end
    when "purchase_plans", "shopping", "sparkles"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.path(d: "m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z") +
          tag.path(d: "M5 3v4") +
          tag.path(d: "M19 17v4") +
          tag.path(d: "M3 5h4") +
          tag.path(d: "M17 19h4")
      end
    when "document", "file-text"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.path(d: "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z") +
          tag.polyline(points: "14 2 14 8 20 8") +
          tag.line(x1: "8", x2: "16", y1: "13", y2: "13") +
          tag.line(x1: "8", x2: "16", y1: "17", y2: "17")
      end
    when "arrow-up-right", "income"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.line(x1: "7", y1: "17", x2: "17", y2: "7") +
          tag.polyline(points: "7 7 17 7 17 17")
      end
    when "arrow-down-right", "expense"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.line(x1: "7", y1: "7", x2: "17", y2: "17") +
          tag.polyline(points: "17 7 17 17 7 17")
      end
    when "plus"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.line(x1: "12", y1: "5", x2: "12", y2: "19") +
          tag.line(x1: "5", y1: "12", x2: "19", y2: "12")
      end
    when "close"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.line(x1: "18", x2: "6", y1: "6", y2: "18") +
          tag.line(x1: "6", x2: "18", y1: "6", y2: "18")
      end
    when "edit"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.path(d: "M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z") +
          tag.path(d: "m15 5 4 4")
      end
    when "trash"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.path(d: "M3 6h18") +
          tag.path(d: "M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6") +
          tag.path(d: "M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2")
      end
    when "vault", "logo"
      content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: "2", stroke_linecap: "round", stroke_linejoin: "round", class: css_class) do
        tag.rect(width: "18", height: "18", x: "3", y: "3", rx: "2") +
          tag.circle(cx: "12", cy: "12", r: "4") +
          tag.line(x1: "12", x2: "12", y1: "8", y2: "10") +
          tag.line(x1: "12", x2: "12", y1: "14", y2: "16") +
          tag.line(x1: "8", x2: "10", y1: "12", y2: "12") +
          tag.line(x1: "14", x2: "16", y1: "12", y2: "12")
      end
    else
      content_tag(:span, "•", class: css_class)
    end
  end

  def quick_add_categories
    categories = PersonalFinance::Category.where(user_id: current_panel_user.id, kind: "expense").order(:name).to_a
    recent_ids = PersonalFinance::Transaction.where(user_id: current_panel_user.id).where.not(category_id: nil)
      .order(occurred_on: :desc, created_at: :desc).limit(24).pluck(:category_id).uniq

    (categories.sort_by { |category| recent_ids.index(category.id) || recent_ids.length } + categories).uniq.first(8)
  end

  def quick_add_categories_for(kind)
    return quick_add_categories if kind == "expense"

    PersonalFinance::Category.where(user_id: current_panel_user.id, kind: kind).order(:name).limit(8)
  end

  def quick_add_accounts
    PersonalFinance::Account.where(user_id: current_panel_user.id, is_active: true).order(:name)
  end
end
