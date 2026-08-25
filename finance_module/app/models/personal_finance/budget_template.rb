module PersonalFinance
  class BudgetTemplate < ApplicationRecord
    self.table_name = "finance_budget_templates"

    PREDEFINED_TEMPLATES = {
      "Öğrenci" => {"Market & Yemek" => 3500, "Ulaşım" => 1000, "Eğitim" => 1500, "Eğlence" => 1000, "Diğer Gider" => 1000},
      "Çalışan" => {"Ev & Faturalar" => 12000, "Market & Yemek" => 6000, "Ulaşım" => 2500, "Sağlık" => 1500, "Eğlence" => 2500},
      "Aile" => {"Ev & Faturalar" => 18000, "Market & Yemek" => 12000, "Ulaşım" => 3500, "Sağlık" => 2500, "Eğitim" => 3000, "Eğlence" => 2000}
    }.freeze

    belongs_to :user, class_name: "::User"

    validates :name, presence: true, length: {maximum: 80}, uniqueness: {scope: :user_id}
    validate :valid_allocation_data

    def self.ensure_predefined_for!(user)
      PREDEFINED_TEMPLATES.each do |name, allocations|
        find_or_create_by!(user: user, name: name) do |template|
          template.predefined = true
          template.allocation_data = allocations.map { |category_name, planned_amount| {"category_name" => category_name, "planned_amount" => planned_amount.to_s} }
        end
      end
    end

    def self.save_budget!(user:, budget:, name:)
      template = where(user: user, name: name.strip).first_or_initialize
      raise ActiveRecord::RecordInvalid, template if template.predefined?

      template.allocation_data = budget.allocations.includes(:category).filter_map do |allocation|
        next unless allocation.category

        {"category_name" => allocation.category.name, "planned_amount" => allocation.planned_amount.to_d.to_s("F")}
      end
      template.save!
      template
    end

    def apply_to!(budget)
      allocations = resolved_allocations(budget.user)
      raise ActiveRecord::RecordInvalid, self if allocations.empty?

      BudgetPeriod.transaction do
        budget.allocations.destroy_all
        allocations.each do |category, amount|
          budget.allocations.create!(category: category, planned_amount: amount)
        end
        budget.update!(planned_income: allocations.sum { |_category, amount| amount })
      end
    end

    private

    def resolved_allocations(user)
      expense_categories = Category.where(user: user, kind: "expense").index_by(&:name)
      allocation_data.filter_map do |item|
        category = expense_categories[item["category_name"]]
        amount = if item["planned_amount"].present?
          item["planned_amount"].to_d
        end
        [category, amount] if category && amount&.positive?
      end
    end

    def valid_allocation_data
      return if allocation_data.is_a?(Array) && allocation_data.all? { |item| item.is_a?(Hash) && item["category_name"].present? && item["planned_amount"].present? }

      errors.add(:allocation_data, "must contain category allocations")
    end
  end
end
