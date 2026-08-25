require "test_helper"

class PersonalFinance::TagsControllerTest < PersonalFinance::IntegrationTest
  setup do
    @user = User.dashboard_owner
    @account = PersonalFinance::Account.create!(user: @user, name: "Bank", kind: "bank", opening_balance: 0)
    @category = PersonalFinance::Category.create!(user: @user, name: "Travel", kind: "expense", color: "#3B82F6")
    @transaction = PersonalFinance::Transaction.create!(user: @user, account: @account, category: @category, kind: "expense", amount: 300, occurred_on: Date.current)
    @tag = PersonalFinance::Tag.create!(user: @user, name: "Vacation")
    @transaction.tags << @tag
  end

  test "shows tag spending totals" do
    get report_finance_tags_path

    assert_response :success
    assert_select ".transaction-tag", text: "Vacation"
    assert_select ".value-negative", text: /300/
  end

  test "merges tags without duplicating transaction relationships" do
    source = PersonalFinance::Tag.create!(user: @user, name: "Holiday")
    @transaction.tags << source

    patch merge_finance_tags_path, params: {target_id: @tag.id, source_ids: [source.id]}

    assert_redirected_to finance_tags_path
    assert_equal [@tag.id], @transaction.reload.tags.pluck(:id)
    assert_not PersonalFinance::Tag.exists?(source.id)
  end
end
