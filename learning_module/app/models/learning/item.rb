module Learning
  class Item < ApplicationRecord
    self.table_name = "learning_items"
    TRACKS = %w[interview algorithms system_engineering].freeze
    KINDS = %w[topic question project mock].freeze
    STATUSES = %w[planned active review completed].freeze
    DIFFICULTIES = %w[easy medium hard].freeze
    belongs_to :user
    has_many :attempts, class_name: "Learning::Attempt", dependent: :destroy
    validates :title, presence: true, length: {maximum: 200}
    validates :track, inclusion: {in: TRACKS}
    validates :kind, inclusion: {in: KINDS}
    validates :status, inclusion: {in: STATUSES}
    validates :difficulty, inclusion: {in: DIFFICULTIES}
    validates :confidence, numericality: {only_integer: true, in: 0..5}
    validates :position, numericality: {only_integer: true, in: 0..10000}
    validates :estimated_minutes, numericality: {only_integer: true, in: 1..1440}
    validates :notes, length: {maximum: 50000}

    def display_title
      return title unless source_key&.start_with?("roadmap:")

      key = "learning.seeds.#{source_key.delete_prefix("roadmap:")}.title"
      (title == I18n.t(key, locale: :en)) ? I18n.t(key) : title
    end
  end
end
