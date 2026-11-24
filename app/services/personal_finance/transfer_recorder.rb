module PersonalFinance
  class TransferRecorder
    class Error < StandardError; end

    def self.call(user:, source_account:, destination_account:, amount:, occurred_on:, note: nil)
      new(user: user, source_account: source_account, destination_account: destination_account,
        amount: amount, occurred_on: occurred_on, note: note).call
    end

    def initialize(user:, source_account:, destination_account:, amount:, occurred_on:, note:)
      @user, @source_account, @destination_account = user, source_account, destination_account
      @amount, @occurred_on, @note = amount, occurred_on, note
    end

    def call
      validate!
      group_id = SecureRandom.uuid
      Transaction.transaction do
        outbound = Transaction.create!(user: @user, account: @source_account, kind: "transfer", amount: @amount,
          occurred_on: @occurred_on, note: @note, transfer_group_id: group_id, transfer_direction: "outbound")
        inbound = Transaction.create!(user: @user, account: @destination_account, kind: "transfer", amount: @amount,
          occurred_on: @occurred_on, note: @note, transfer_group_id: group_id, transfer_direction: "inbound")
        [outbound, inbound]
      end
    end

    private

    def validate!
      raise Error, "Transfer accounts must be different." if @source_account == @destination_account
      raise Error, "Transfer accounts must belong to the same user." unless [@source_account, @destination_account].all? { |account| account.user_id == @user.id }
      raise Error, "Transfers currently require matching account currencies." unless @source_account.currency == @destination_account.currency
    end
  end
end
