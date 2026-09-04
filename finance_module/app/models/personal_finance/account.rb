module PersonalFinance
  class Account < ApplicationRecord
    self.table_name = "financial_accounts"

    belongs_to :user, class_name: "::User"
    has_many :transactions, class_name: "PersonalFinance::Transaction", foreign_key: :financial_account_id, dependent: :restrict_with_error
    has_many :recurring_rules, class_name: "PersonalFinance::RecurringRule", foreign_key: :financial_account_id, dependent: :restrict_with_error

    enum :kind, {cash: "cash", bank: "bank", card: "card", savings: "savings"}, validate: true

    validates :name, presence: true, length: {maximum: 80}
    validates :opening_balance, numericality: true
    validates :currency, presence: true, length: {is: 3}
    before_validation do
      self.currency = (currency.presence || user&.currency || "TRY").to_s.upcase
    end

    def current_balance
      opening_balance + transactions.sum("CASE WHEN kind = 'income' THEN amount WHEN kind = 'expense' THEN -amount ELSE 0 END")
    end

    def balance_history(months: 6)
      first_month = (Date.current.beginning_of_month - (months - 1).months)
      running_balance = opening_balance + transactions.where("occurred_on < ?", first_month).sum("CASE WHEN kind = 'income' THEN amount WHEN kind = 'expense' THEN -amount ELSE 0 END")
      totals = transactions.where(occurred_on: first_month..Date.current).group("DATE_TRUNC('month', occurred_on)").sum("CASE WHEN kind = 'income' THEN amount WHEN kind = 'expense' THEN -amount ELSE 0 END")
      months.times.map do |offset|
        month = first_month + offset.months
        running_balance += totals[month.to_time.beginning_of_month] || 0
        {month: month, balance: running_balance.to_f}
      end
    end

    def self.balance_histories(accounts, months: 6)
      accounts = accounts.to_a
      return {} if accounts.empty?

      first_month = Date.current.beginning_of_month - (months - 1).months
      account_ids = accounts.map(&:id)
      balance_sql = "CASE WHEN kind = 'income' THEN amount WHEN kind = 'expense' THEN -amount ELSE 0 END"
      opening_totals = Transaction.where(financial_account_id: account_ids).where("occurred_on < ?", first_month).group(:financial_account_id).sum(balance_sql)
      monthly_totals = Transaction.where(financial_account_id: account_ids, occurred_on: first_month..Date.current).group(:financial_account_id, "DATE_TRUNC('month', occurred_on)").sum(balance_sql).to_h { |(account_id, month), amount| [[account_id, month.to_date.beginning_of_month], amount] }

      accounts.to_h do |account|
        running_balance = account.opening_balance + opening_totals.fetch(account.id, 0)
        history = months.times.map do |offset|
          month = first_month + offset.months
          running_balance += monthly_totals.fetch([account.id, month], 0)
          {month: month, balance: running_balance.to_f}
        end
        [account, history]
      end
    end
  end
end
