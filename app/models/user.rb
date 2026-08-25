class User < ApplicationRecord
  has_secure_password validations: false

  validates :name, presence: true, length: {maximum: 80}
  validates :currency, presence: true, length: {is: 3}
  validates :time_zone, presence: true
  validate :password_security_requirements

  has_many :financial_accounts, class_name: "PersonalFinance::Account", dependent: :destroy
  has_many :finance_categories, class_name: "PersonalFinance::Category", dependent: :destroy
  has_many :finance_transactions, class_name: "PersonalFinance::Transaction", dependent: :destroy
  has_many :finance_budget_periods, class_name: "PersonalFinance::BudgetPeriod", dependent: :destroy
  has_many :finance_budget_templates, class_name: "PersonalFinance::BudgetTemplate", dependent: :destroy
  has_many :finance_notifications, class_name: "PersonalFinance::Notification", dependent: :destroy
  has_many :finance_subscriptions, class_name: "PersonalFinance::Subscription", dependent: :destroy
  has_many :finance_debts, class_name: "PersonalFinance::Debt", dependent: :destroy
  has_many :finance_savings_goals, class_name: "PersonalFinance::SavingsGoal", dependent: :destroy
  has_many :finance_purchase_plans, class_name: "PersonalFinance::PurchasePlan", dependent: :destroy

  def onboarded?
    onboarded_at.present? || financial_accounts.exists? || finance_categories.exists? || finance_transactions.exists?
  end

  def self.dashboard_owner
    order(:id).first_or_create! do |user|
      user.name = ENV.fetch("DASHBOARD_OWNER_NAME", "Personal Dashboard")
      user.currency = ENV.fetch("DASHBOARD_CURRENCY", "TRY")
      user.time_zone = ENV.fetch("DASHBOARD_TIME_ZONE", "Europe/Istanbul")
    end
  end

  def self.dashboard_owner_record
    order(:id).first
  end

  def rotate_dashboard_password!(new_password)
    self.password = new_password
    self.password_confirmation = new_password
    self.authentication_version += 1
    save!
  end

  private

  def password_security_requirements
    return if password.nil?

    errors.add(:password, "must be at least 16 characters") if password.length < 16
    errors.add(:password, "must not exceed 72 bytes") if password.bytesize > 72
    errors.add(:password_confirmation, "does not match password") unless password == password_confirmation
  end
end
