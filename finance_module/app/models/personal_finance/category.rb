module PersonalFinance
  class Category < ApplicationRecord
    self.table_name = "finance_categories"

    belongs_to :user, class_name: "::User"
    belongs_to :parent, class_name: "PersonalFinance::Category", optional: true
    has_many :children, class_name: "PersonalFinance::Category", foreign_key: :parent_id, dependent: :restrict_with_error
    has_many :transactions, class_name: "PersonalFinance::Transaction", dependent: :nullify
    has_many :recurring_rules, class_name: "PersonalFinance::RecurringRule", dependent: :nullify

    enum :kind, {income: "income", expense: "expense", transfer: "transfer"}, validate: true

    validates :name, presence: true, length: {maximum: 80}, uniqueness: {scope: :user_id}
    validates :color, format: {with: /\A#[0-9A-Fa-f]{6}\z/}
    validate :parent_belongs_to_same_user_and_kind

    def full_name
      parent ? "#{parent.name} › #{name}" : name
    end

    def self_and_descendant_ids
      [id] + children.pluck(:id)
    end

    private

    def parent_belongs_to_same_user_and_kind
      return unless parent
      errors.add(:parent, "must belong to the same user") if parent.user_id != user_id
      errors.add(:parent, "must have the same type") if parent.kind != kind
      errors.add(:parent, "cannot be nested more than one level") if parent.parent_id.present?
    end
  end
end
