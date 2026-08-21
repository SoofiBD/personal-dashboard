require "test_helper"

class PersonalFinance::PurchasePlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.first || User.create!(name: "Test User", currency: "TRY", time_zone: "Europe/Istanbul")
    @account = PersonalFinance::Account.create!(user: @user, name: "Card", kind: :bank, opening_balance: 5000)
    @category = PersonalFinance::Category.create!(user: @user, name: "Electronics", kind: :expense, color: "#EF4444")
    @plan = PersonalFinance::PurchasePlan.create!(
      user: @user,
      name: "Laptop",
      price: 2500,
      down_payment: 500,
      monthly_cost: 200,
      planned_on: Date.current + 1.month
    )
  end

  test "should get show with assessment details" do
    get finance_purchase_plan_path(@plan)
    assert_response :success
    assert_select "h1", "Laptop"
    assert_select "[data-scenario-input='price']"
  end

  test "should convert purchase plan to transaction" do
    assert_difference -> { PersonalFinance::Transaction.count }, 1 do
      post convert_finance_purchase_plan_path(@plan), params: {
        financial_account_id: @account.id,
        category_id: @category.id
      }
    end

    assert_redirected_to finance_purchase_plan_path(@plan)
    follow_redirect!
    assert_select ".flash-notice", text: /Plan bir işleme dönüştürüldü/

    # Verify transaction details
    t = PersonalFinance::Transaction.last
    assert_equal @account.id, t.financial_account_id
    assert_equal @category.id, t.category_id
    assert_equal 2500.0, t.amount.to_f
    assert_equal "Satın Alma: Laptop", t.note
  end
end
