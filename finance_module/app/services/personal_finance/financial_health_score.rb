module PersonalFinance
  class FinancialHealthScore
    attr_reader :score, :metrics, :suggestions

    def initialize(user, month = Date.current)
      @user = user
      @month = month.to_date
      calculate
    end

    def self.trend(user)
      5.downto(0).map do |months_ago|
        date = months_ago.months.ago.to_date
        result = new(user, date)
        {label: I18n.l(date, format: "%b"), score: result.score}
      end
    end

    private

    def calculate
      transactions = Transaction.where(user: @user, occurred_on: @month.all_month)
      income = transactions.income.sum(:amount).to_f
      expenses = transactions.expense.sum(:amount).to_f
      savings = [income - expenses, 0].max
      budget = BudgetPeriod.find_by(user: @user, starts_on: @month.beginning_of_month)
      within_budget = budget ? budget.allocations.count { |a| a.spent <= a.planned_amount } : 0
      budget_ratio = budget&.allocations&.any? ? within_budget.to_f / budget.allocations.size : 0.5
      balance = Account.where(user: @user, is_active: true).sum { |account| account.current_balance.to_f }
      debt = Debt.where(user: @user, active: true).sum(:remaining_amount).to_f
      income_ratio = income.positive? ? [income / [expenses, 1].max, 2].min / 2 : 0
      savings_rate = income.positive? ? [savings / income, 1].min : 0
      emergency = expenses.positive? ? [balance / expenses, 6].min / 6 : 0.5
      debt_ratio = income.positive? ? [1 - debt / income, 0].max : 0.5
      @metrics = {income_ratio: income_ratio, savings_rate: savings_rate, budget_ratio: budget_ratio, emergency: emergency, debt_ratio: debt_ratio}
      @score = ((income_ratio * 25) + (savings_rate * 25) + (budget_ratio * 20) + (emergency * 15) + (debt_ratio * 15)).round
      @suggestions = []
      @suggestions << "Giderlerinizi gelirin altında tutmaya odaklanın." if income_ratio < 0.6
      @suggestions << "Her ay gelirin en az %20'sini birikime ayırmayı deneyin." if savings_rate < 0.2
      @suggestions << "Kategori bütçe limitlerini gözden geçirin." if budget_ratio < 0.7
      @suggestions << "Acil durum fonunuzu en az üç aylık gider seviyesine çıkarın." if emergency < 0.5
      @suggestions << "Borç ödemelerini gelirinizin daha küçük bir bölümünde tutun." if debt_ratio < 0.5
      @suggestions << "Finansal görünümünüz dengeli; bu alışkanlıkları koruyun." if @suggestions.empty?
    end
  end
end
