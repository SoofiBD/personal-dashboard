module PersonalFinance
  class SeedDefaultCategories
    DEFAULT_EXPENSE_CATEGORIES = [
      {name: "Ev & Faturalar", kind: "expense", color: "#3B82F6", icon: "home", sort_order: 1},
      {name: "Market & Yemek", kind: "expense", color: "#10B981", icon: "shopping-cart", sort_order: 2},
      {name: "Ulaşım", kind: "expense", color: "#F59E0B", icon: "truck", sort_order: 3},
      {name: "Sağlık", kind: "expense", color: "#EC4899", icon: "heart", sort_order: 4},
      {name: "Eğitim", kind: "expense", color: "#8B5CF6", icon: "book", sort_order: 5},
      {name: "Eğlence", kind: "expense", color: "#06B6D4", icon: "smile", sort_order: 6},
      {name: "Alışveriş", kind: "expense", color: "#F97316", icon: "shopping-bag", sort_order: 7},
      {name: "Abonelikler", kind: "expense", color: "#6366F1", icon: "calendar", sort_order: 8},
      {name: "Diğer Gider", kind: "expense", color: "#64748B", icon: "tag", sort_order: 9}
    ].freeze

    DEFAULT_INCOME_CATEGORIES = [
      {name: "Maaş", kind: "income", color: "#10B981", icon: "dollar-sign", sort_order: 1},
      {name: "Serbest İş", kind: "income", color: "#3B82F6", icon: "laptop", sort_order: 2},
      {name: "Ek Gelir", kind: "income", color: "#F59E0B", icon: "plus-circle", sort_order: 3},
      {name: "İade / Hediye", kind: "income", color: "#EC4899", icon: "gift", sort_order: 4},
      {name: "Diğer Gelir", kind: "income", color: "#64748B", icon: "tag", sort_order: 5}
    ].freeze

    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      created_categories = []
      (DEFAULT_EXPENSE_CATEGORIES + DEFAULT_INCOME_CATEGORIES).each do |cat_data|
        category = @user.finance_categories.find_or_initialize_by(name: cat_data[:name])
        category.assign_attributes(cat_data)
        category.save! if category.new_record? || category.changed?
        created_categories << category
      end
      created_categories
    end
  end
end
