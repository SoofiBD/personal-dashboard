class User < ApplicationRecord
  validates :name, presence: true, length: {maximum: 80}
  validates :currency, presence: true, length: {is: 3}
  validates :time_zone, presence: true

  has_many :financial_accounts, class_name: "PersonalFinance::Account", dependent: :destroy
  has_many :finance_categories, class_name: "PersonalFinance::Category", dependent: :destroy
  has_many :finance_transactions, class_name: "PersonalFinance::Transaction", dependent: :destroy
  has_many :finance_budget_periods, class_name: "PersonalFinance::BudgetPeriod", dependent: :destroy
  has_many :finance_budget_templates, class_name: "PersonalFinance::BudgetTemplate", dependent: :destroy
  has_many :finance_notifications, class_name: "PersonalFinance::Notification", dependent: :destroy
  has_many :finance_savings_goals, class_name: "PersonalFinance::SavingsGoal", dependent: :destroy
  has_many :finance_purchase_plans, class_name: "PersonalFinance::PurchasePlan", dependent: :destroy

  def onboarded?
    onboarded_at.present? || financial_accounts.exists? || finance_categories.exists? || finance_transactions.exists?
  end

  def self.dashboard_owner
    first_or_create! do |user|
      user.name = ENV.fetch("DASHBOARD_OWNER_NAME", "Personal Dashboard")
      user.currency = ENV.fetch("DASHBOARD_CURRENCY", "TRY")
      user.time_zone = ENV.fetch("DASHBOARD_TIME_ZONE", "Europe/Istanbul")
    end
  end
end
