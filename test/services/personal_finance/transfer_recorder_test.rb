require "test_helper"

class PersonalFinance::TransferRecorderTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Transfer owner", currency: "TRY", time_zone: "Europe/Istanbul")
    @source = PersonalFinance::Account.create!(user: @user, name: "Cash", kind: "cash", opening_balance: 500)
    @destination = PersonalFinance::Account.create!(user: @user, name: "Savings", kind: "savings", opening_balance: 100)
  end

  test "creates balanced inbound and outbound postings" do
    outbound, inbound = PersonalFinance::TransferRecorder.call(user: @user, source_account: @source,
      destination_account: @destination, amount: 125, occurred_on: Date.current, note: "Save")

    assert_equal outbound.transfer_group_id, inbound.transfer_group_id
    assert_predicate outbound, :transfer_direction_outbound?
    assert_predicate inbound, :transfer_direction_inbound?
    assert_equal 375.0, @source.reload.current_balance.to_f
    assert_equal 225.0, @destination.reload.current_balance.to_f
  end

  test "does not persist a transfer across currencies" do
    usd_account = PersonalFinance::Account.create!(user: @user, name: "USD", kind: "bank", opening_balance: 0, currency: "USD")

    assert_raises(PersonalFinance::TransferRecorder::Error) do
      PersonalFinance::TransferRecorder.call(user: @user, source_account: @source, destination_account: usd_account,
        amount: 125, occurred_on: Date.current)
    end
    assert_equal 0, PersonalFinance::Transaction.where(kind: "transfer").count
  end
end
