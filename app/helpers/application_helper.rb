module ApplicationHelper
  def dashboard_currency(value)
    number_to_currency(value, unit: User.dashboard_owner.currency, format: "%n %u", delimiter: ".", separator: ",")
  end

  def finance_navigation_item(label, path)
    class_name = current_page?(path) ? "sidebar-link is-active" : "sidebar-link"
    link_to label, path, class: class_name
  end
end
