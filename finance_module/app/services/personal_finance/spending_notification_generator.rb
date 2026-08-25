module PersonalFinance
  class SpendingNotificationGenerator
    def self.call(transaction, goal: nil)
      new(transaction, goal).call
    end

    def initialize(transaction, goal)
      @transaction = transaction
      @goal = goal
      @user = transaction.user
    end

    def call
      create_goal_milestone_notification if @goal
      return unless @transaction.expense?

      create_limit_notification(:daily, @user.daily_spending_limit, @transaction.occurred_on.all_day)
      create_limit_notification(:weekly, @user.weekly_spending_limit, @transaction.occurred_on.beginning_of_week..@transaction.occurred_on.end_of_week)
      create_budget_notification
      create_unusual_spending_notification
    end

    private

    def create_limit_notification(period, limit, range)
      return unless limit.to_d.positive?

      spent = expenses.during(range).sum(:amount)
      return unless spent > limit

      label = (period == :daily) ? "Günlük" : "Haftalık"
      period_label = (period == :daily) ? "Bugün" : "Bu hafta"
      body = "#{period_label} #{spent.to_d.to_s("F")} harcadınız; limitiniz #{limit.to_d.to_s("F")}."
      create_once("#{period}_limit_#{@transaction.occurred_on}", "#{label} harcama limiti aşıldı", body)
    end

    def create_budget_notification
      budget = BudgetPeriod.find_by(user: @user, starts_on: @transaction.occurred_on.beginning_of_month)
      return unless budget && @transaction.category

      allocation = budget.allocations.find_by(category: @transaction.category)
      return unless allocation && allocation.spent > allocation.planned_amount

      body = "#{@transaction.category.name} için planlanan #{allocation.planned_amount.to_d.to_s("F")} tutarını aştınız."
      create_once("budget_overspend_#{budget.id}_#{allocation.id}", "Kategori bütçesi aşıldı", body)
    end

    def create_unusual_spending_notification
      previous = expenses.where("occurred_on < ?", @transaction.occurred_on).order(occurred_on: :desc).limit(10)
      return if previous.size < 3

      average = previous.average(:amount).to_d
      return unless average.positive? && @transaction.amount >= average * 2

      body = "#{@transaction.amount.to_d.to_s("F")} tutarındaki işlem, son harcamalarınızın ortalamasının belirgin üzerinde."
      create_once("unusual_spending_#{@transaction.id}", "Alışılmadık harcama tespit edildi", body)
    end

    def create_goal_milestone_notification
      percentage = (@goal.saved_amount / @goal.target_amount * 100).floor
      milestone = [100, 75, 50, 25].find { |value| percentage >= value }
      return unless milestone

      title = "Tasarruf hedefinde #{milestone}%"
      body = "#{@goal.name} hedefinizin #{milestone}% seviyesine ulaştınız."
      create_once("goal_milestone_#{@goal.id}_#{milestone}", title, body)
    end

    def expenses
      Transaction.where(user: @user, kind: "expense")
    end

    def create_once(kind, title, body)
      return if Notification.exists?(user: @user, kind: kind)

      Notification.create!(user: @user, kind: kind, title: title, body: body)
    end
  end
end
