module PersonalFinance
  class DebtPayment < ApplicationRecord
    self.table_name = "finance_debt_payments"
    belongs_to :debt, class_name: "PersonalFinance::Debt"
    validates :amount, numericality: {greater_than: 0}
    validates :paid_on, presence: true
    after_create :update_debt_balance

    private

    def update_debt_balance
      debt.with_lock do
        debt.update!(remaining_amount: [debt.remaining_amount - amount, 0].max, remaining_installments: [debt.remaining_installments - 1, 0].max, next_payment_on: debt.next_payment_on&.advance(months: 1), active: debt.remaining_amount > amount)
      end
    end
  end
end
