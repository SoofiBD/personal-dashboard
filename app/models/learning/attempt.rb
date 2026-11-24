module Learning
  class Attempt < ApplicationRecord
    self.table_name = "learning_attempts"
    OUTCOMES = %w[stuck partial solved].freeze
    belongs_to :user
    belongs_to :item, class_name: "Learning::Item"
    validates :outcome, inclusion: {in: OUTCOMES}
    validates :minutes, numericality: {only_integer: true, in: 1..1440}
    validates :confidence, numericality: {only_integer: true, in: 0..5}
    validates :reflection, length: {maximum: 20000}
    validate :same_owner

    private

    def same_owner
      errors.add(:item, :invalid) if item && item.user_id != user_id
    end
  end
end
