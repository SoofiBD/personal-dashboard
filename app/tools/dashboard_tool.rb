# frozen_string_literal: true

class DashboardTool
  extend Langchain::ToolDefinition

  def initialize(user:)
    @user = user
  end

  define_function :get_overview, description: "Balance, today spending, active workout, learning status, note count"

  define_function :get_recent_activity, description: "Cross-module activity last N days (default 3)" do
    property :days, type: "integer", description: "Number of days", required: false
  end

  def get_overview
    range = Date.current.beginning_of_month..Date.current.end_of_month
    today = Date.current

    # Finance
    total_balance = user.financial_accounts.active.sum(:opening_balance) +
      user.finance_transactions.where("occurred_on < ?", range.begin)
        .sum("CASE WHEN kind = 'income' THEN amount WHEN kind = 'expense' THEN -amount ELSE 0 END")
    today_expense = user.finance_transactions.expense.where(occurred_on: today).sum(:amount).to_f
    today_income = user.finance_transactions.income.where(occurred_on: today).sum(:amount).to_f

    # Notes
    note_count = user.notes.count

    # Learning
    pending_learning = user.learning_items.where(status: %w[planned active]).count
    active_learning = user.learning_items.where(status: "active").count

    # Gym
    active_workout = user.gym_workouts.active.first
    recent_workouts_count = user.gym_workouts.where("started_at >= ?", 7.days.ago).count

    tool_response(content: {
      finance: {
        total_balance: total_balance.to_f,
        today_expense: today_expense,
        today_income: today_income,
        today_net: (today_income - today_expense).round(2)
      },
      notes: {count: note_count},
      learning: {pending: pending_learning, active: active_learning},
      gym: {active_workout: active_workout&.id, recent_workouts_7d: recent_workouts_count}
    })
  end

  def get_recent_activity(days: 3)
    start_date = days.days.ago.to_date
    end_date = Date.current

    # Recent transactions
    transactions = user.finance_transactions
      .where(occurred_on: start_date..end_date)
      .includes(:category, :account)
      .order(occurred_on: :desc)
      .limit(10)
      .map do |t|
      {type: "transaction", date: t.occurred_on, amount: t.amount.to_f, kind: t.kind,
       category: t.category&.name, note: t.note}
    end

    # Recent notes
    notes = user.notes
      .where(updated_at: start_date..end_date)
      .order(updated_at: :desc)
      .limit(5)
      .map { |n| {type: "note", title: n.title, updated_at: n.updated_at} }

    # Recent workouts
    workouts = user.gym_workouts
      .where(started_at: start_date..end_date)
      .order(started_at: :desc)
      .limit(5)
      .map do |w|
      {type: "workout", status: w.status, started_at: w.started_at,
       routine: w.routine&.name}
    end

    # Recent learning attempts
    attempts = user.learning_attempts
      .joins(:item)
      .where(created_at: start_date..end_date)
      .order(created_at: :desc)
      .limit(5)
      .map do |a|
      {type: "learning_attempt", item: a.item.title, outcome: a.outcome, minutes: a.minutes,
       created_at: a.created_at}
    end

    all = (transactions + notes + workouts + attempts).sort_by do |a|
      -a.values.find do |v|
        v.is_a?(Date) || v.is_a?(Time) || v.is_a?(DateTime)
      end&.to_i
    end
    tool_response(content: all.first(20))
  end

  private

  attr_reader :user

  def tool_response(content:)
    Langchain::ToolResponse.new(content: content.to_json)
  end
end
