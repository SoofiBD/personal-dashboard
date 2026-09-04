module PersonalFinance
  class DebtPayment < ApplicationRecord
    self.table_name = "finance_debt_payments"
    belongs_to :debt, class_name: "PersonalFinance::Debt"
    validates :amount, numericality: {greater_than: 0, less_than_or_equal_to: ->(payment) { payment.debt&.remaining_amount || 0 }}
    validates :paid_on, presence: true
    after_create :update_debt_balance

    private

    def update_debt_balance
      debt.with_lock do
        remaining_amount = debt.remaining_amount - amount
        if remaining_amount.negative?
          errors.add(:amount, "cannot exceed the remaining debt balance")
          raise ActiveRecord::RecordInvalid, self
        end

        debt.update!(
          remaining_amount: remaining_amount,
          remaining_installments: [debt.remaining_installments - 1, 0].max,
          next_payment_on: debt.next_payment_on&.advance(months: 1),
          active: remaining_amount.positive?
        )
      end
    end
  end
end
