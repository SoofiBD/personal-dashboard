require "test_helper"

class PersonalFinance::DebtPaymentTest < ActiveSupport::TestCase
  test "rejects a payment greater than the remaining debt balance" do
    debt = create_debt(remaining_amount: 100)
    payment = debt.payments.build(amount: 100.01, paid_on: Date.current)

    assert_not payment.valid?
    assert payment.errors.of_kind?(:amount, :less_than_or_equal_to)
    assert_no_difference -> { debt.payments.count } do
      assert_raises(ActiveRecord::RecordInvalid) { payment.save! }
    end
    assert_equal 100, debt.reload.remaining_amount
    assert debt.active?
  end

  test "keeps a debt active after a partial payment" do
    debt = create_debt(remaining_amount: 100, remaining_installments: 2)

    debt.payments.create!(amount: 40, paid_on: Date.current)

    debt.reload
    assert_equal 60, debt.remaining_amount
    assert_equal 1, debt.remaining_installments
    assert debt.active?
  end

  test "marks a debt inactive when a payment clears its balance" do
    debt = create_debt(remaining_amount: 100, remaining_installments: 1)

    debt.payments.create!(amount: 100, paid_on: Date.current)

    debt.reload
    assert_equal 0, debt.remaining_amount
    assert_equal 0, debt.remaining_installments
    assert_not debt.active?
  end

  private

  def create_debt(remaining_amount:, remaining_installments: 3)
    user = User.create!(name: "Owner", currency: "TRY", time_zone: "Europe/Istanbul")
    PersonalFinance::Debt.create!(
      user: user,
      name: "Credit card",
      total_amount: 100,
      remaining_amount: remaining_amount,
      monthly_payment: 40,
      remaining_installments: remaining_installments,
      next_payment_on: Date.current,
      active: true
    )
  end
end
