module PersonalFinance
  class FinancialHealthScore
    attr_reader :score, :metrics, :suggestions

    def initialize(user, month = Date.current)
      @user = user
      @month = month.to_date
      calculate
    end

    def self.trend(user)
      first_month = 5.months.ago.to_date.beginning_of_month
      months = 6.times.map { |offset| first_month + offset.months }
      totals = monthly_totals(user, first_month, Date.current.end_of_month)
      budget_ratios = budget_ratios(user, months)
      balance = current_balance(user)
      debt = Debt.where(user: user, active: true).sum(:remaining_amount).to_f

      months.map do |month|
        values = totals.fetch(month, {income: 0, expenses: 0})
        metrics = metrics_for(**values, budget_ratio: budget_ratios.fetch(month, 0.5), balance: balance, debt: debt)
        {label: I18n.l(month, format: "%b"), score: score_for(metrics)}
      end
    end

    def self.monthly_totals(user, first_month, last_month)
      Transaction.where(user: user, occurred_on: first_month..last_month).group("DATE_TRUNC('month', occurred_on)").pluck(
        Arel.sql("DATE_TRUNC('month', occurred_on)"),
        Arel.sql("COALESCE(SUM(CASE WHEN kind = 'income' THEN amount ELSE 0 END), 0)"),
        Arel.sql("COALESCE(SUM(CASE WHEN kind = 'expense' THEN amount ELSE 0 END), 0)")
      ).to_h { |date, income, expenses| [date.to_date.beginning_of_month, {income: income.to_f, expenses: expenses.to_f}] }
    end

    def self.current_balance(user)
      Account.where(user: user, is_active: true).left_joins(:transactions).group("financial_accounts.id").pluck(Arel.sql("financial_accounts.opening_balance + COALESCE(SUM(CASE WHEN finance_transactions.kind = 'income' THEN finance_transactions.amount WHEN finance_transactions.kind = 'expense' THEN -finance_transactions.amount ELSE 0 END), 0)")).sum(&:to_f)
    end

    def self.budget_ratios(user, months)
      budgets = BudgetPeriod.where(user: user, starts_on: months).includes(allocations: {category: :children})
      spending = Transaction.where(user: user, kind: "expense", occurred_on: months.first..months.last.end_of_month).group("DATE_TRUNC('month', occurred_on)", :category_id).sum(:amount).to_h { |(month, category_id), amount| [[month.to_date.beginning_of_month, category_id], amount] }

      budgets.to_h do |budget|
        allocations = budget.allocations
        within_budget = allocations.count do |allocation|
          category_ids = [allocation.category_id] + allocation.category.children.map(&:id)
          category_ids.sum { |category_id| spending[[budget.starts_on, category_id]].to_f } <= allocation.planned_amount
        end
        [budget.starts_on, allocations.any? ? within_budget.to_f / allocations.size : 0.5]
      end
    end

    def self.metrics_for(income:, expenses:, budget_ratio:, balance:, debt:)
      savings = [income - expenses, 0].max
      {
        income_ratio: income.positive? ? [income / [expenses, 1].max, 2].min / 2 : 0,
        savings_rate: income.positive? ? [savings / income, 1].min : 0,
        budget_ratio: budget_ratio,
        emergency: expenses.positive? ? [balance / expenses, 6].min / 6 : 0.5,
        debt_ratio: income.positive? ? [1 - debt / income, 0].max : 0.5
      }
    end

    def self.score_for(metrics)
      ((metrics[:income_ratio] * 25) + (metrics[:savings_rate] * 25) + (metrics[:budget_ratio] * 20) + (metrics[:emergency] * 15) + (metrics[:debt_ratio] * 15)).round
    end

    private

    def calculate
      totals = self.class.monthly_totals(@user, @month.beginning_of_month, @month.end_of_month).fetch(@month.beginning_of_month, {income: 0, expenses: 0})
      income = totals[:income]
      expenses = totals[:expenses]
      budget_ratio = self.class.budget_ratios(@user, [@month.beginning_of_month]).fetch(@month.beginning_of_month, 0.5)
      balance = self.class.current_balance(@user)
      debt = Debt.where(user: @user, active: true).sum(:remaining_amount).to_f
      @metrics = self.class.metrics_for(income: income, expenses: expenses, budget_ratio: budget_ratio, balance: balance, debt: debt)
      @score = self.class.score_for(@metrics)
      @suggestions = []
      @suggestions << "Giderlerinizi gelirin altında tutmaya odaklanın." if @metrics[:income_ratio] < 0.6
      @suggestions << "Her ay gelirin en az %20'sini birikime ayırmayı deneyin." if @metrics[:savings_rate] < 0.2
      @suggestions << "Kategori bütçe limitlerini gözden geçirin." if @metrics[:budget_ratio] < 0.7
      @suggestions << "Acil durum fonunuzu en az üç aylık gider seviyesine çıkarın." if @metrics[:emergency] < 0.5
      @suggestions << "Borç ödemelerini gelirinizin daha küçük bir bölümünde tutun." if @metrics[:debt_ratio] < 0.5
      @suggestions << "Finansal görünümünüz dengeli; bu alışkanlıkları koruyun." if @suggestions.empty?
    end
  end
end
