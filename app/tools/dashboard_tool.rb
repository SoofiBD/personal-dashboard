# frozen_string_literal: true

class DashboardTool < AiTool
  function :get_overview, "Total balance, today's spending/income, learning status"
  function :get_recent_activity, "Cross-module activity from the last N days (default 3, max 30)",
    days: {type: "integer", description: "Number of days"}

  def get_overview
    today = Date.current
    today_expense = user.finance_transactions.expense.where(occurred_on: today).sum(:amount).to_f
    today_income = user.finance_transactions.income.where(occurred_on: today).sum(:amount).to_f

    {
      finance: {
        total_balance: user.financial_accounts.active.sum(&:current_balance).to_f,
        today_expense: today_expense,
        today_income: today_income,
        today_net: (today_income - today_expense).round(2)
      },
      learning: {
        pending: user.learning_items.where(status: %w[planned active]).count,
        active: user.learning_items.where(status: "active").count
      }
    }
  end

  def get_recent_activity(days: 3)
    start_date = days.to_i.clamp(1, 30).days.ago.to_date

    transactions = user.finance_transactions
      .where(occurred_on: start_date..Date.current)
      .includes(:category)
      .order(occurred_on: :desc)
      .limit(10)
      .map { |t| {type: "transaction", at: t.occurred_on.in_time_zone, amount: t.amount.to_f, kind: t.kind, category: t.category&.name, note: t.note} }

    attempts = user.learning_attempts
      .includes(:item)
      .where(created_at: start_date.beginning_of_day..)
      .order(created_at: :desc)
      .limit(5)
      .map { |a| {type: "learning_attempt", at: a.created_at, item: a.item.title, outcome: a.outcome, minutes: a.minutes} }

    (transactions + attempts).sort_by { |entry| entry[:at] }.reverse
  end
end
