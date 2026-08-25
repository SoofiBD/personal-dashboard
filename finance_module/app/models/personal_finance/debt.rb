module PersonalFinance
  class Debt < ApplicationRecord
    self.table_name = "finance_debts"
    belongs_to :user, class_name: "::User"
    has_many :payments, class_name: "PersonalFinance::DebtPayment", dependent: :destroy
    validates :name, presence: true
    validates :total_amount, :remaining_amount, :monthly_payment, numericality: {greater_than_or_equal_to: 0}
    validates :remaining_installments, numericality: {only_integer: true, greater_than_or_equal_to: 0}

    def payoff_date
      return unless next_payment_on && remaining_installments.positive?
      next_payment_on.advance(months: remaining_installments - 1)
    end
  end
end
