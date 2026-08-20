class User < ApplicationRecord
  validates :name, presence: true, length: {maximum: 80}
  validates :currency, presence: true, length: {is: 3}
  validates :time_zone, presence: true

  def self.dashboard_owner
    first_or_create! do |user|
      user.name = ENV.fetch("DASHBOARD_OWNER_NAME", "Personal Dashboard")
      user.currency = ENV.fetch("DASHBOARD_CURRENCY", "TRY")
      user.time_zone = ENV.fetch("DASHBOARD_TIME_ZONE", "Europe/Istanbul")
    end
  end
end
