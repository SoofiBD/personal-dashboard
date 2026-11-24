module PersonalFinance
  class Notification < ApplicationRecord
    self.table_name = "finance_notifications"

    belongs_to :user, class_name: "::User"

    validates :kind, :title, :body, presence: true

    scope :unread, -> { where(read_at: nil) }
    scope :recent_first, -> { order(created_at: :desc) }

    def read?
      read_at.present?
    end
  end
end
