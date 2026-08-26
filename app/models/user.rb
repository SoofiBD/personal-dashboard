class User < ApplicationRecord
  has_secure_password validations: false
  encrypts :mfa_secret

  ROLES = %w[owner editor viewer].freeze
  LOCALES = %w[tr en].freeze

  validates :name, presence: true, length: {maximum: 80}
  validates :currency, presence: true, length: {is: 3}
  validates :time_zone, presence: true
  validates :role, inclusion: {in: ROLES}
  validates :locale, inclusion: {in: LOCALES}
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}, unless: :owner?
  validates :email, uniqueness: {case_sensitive: false}, allow_blank: true
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
      user.email = ENV["DASHBOARD_OWNER_EMAIL"]
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

  def owner?
    role == "owner"
  end

  def editor?
    role == "editor"
  end

  def can_manage_finances?
    owner? || editor?
  end

  def login_identifier
    email.presence || name
  end

  def mfa_pending_setup?
    mfa_secret.present? && !mfa_enabled?
  end

  def prepare_mfa!
    update!(mfa_secret: Totp.generate_secret, mfa_enabled: false, mfa_confirmed_at: nil)
  end

  def enable_mfa!(code)
    return false unless Totp.valid?(mfa_secret, code)

    update!(mfa_enabled: true, mfa_confirmed_at: Time.current)
  end

  def disable_mfa!
    update!(mfa_secret: nil, mfa_enabled: false, mfa_confirmed_at: nil)
  end

  private

  def password_security_requirements
    return if password.nil?

    errors.add(:password, "must be at least 16 characters") if password.length < 16
    errors.add(:password, "must not exceed 72 bytes") if password.bytesize > 72
    errors.add(:password_confirmation, "does not match password") unless password == password_confirmation
  end
end
