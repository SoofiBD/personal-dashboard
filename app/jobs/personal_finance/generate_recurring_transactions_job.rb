module PersonalFinance
  class GenerateRecurringTransactionsJob < ApplicationJob
    queue_as :default

    def perform(user_id = nil)
      scope = user_id ? User.where(id: user_id) : User.all
      scope.find_each { |user| RecurringTransactionGenerator.generate_due_for(user) }
    end
  end
end
