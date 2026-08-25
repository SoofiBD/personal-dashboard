module PersonalFinance
  class RecurringTransactionGenerator
    MAX_OCCURRENCES_PER_RUN = 366

    def self.generate_due_for(user, through: Date.current)
      RecurringRule.where(user: user).active.find_each do |rule|
        generate_due_for_rule(rule, through: through)
      end
    end

    def self.generate_due_for_rule(rule, through: Date.current)
      rule.with_lock do
        next_date = rule.next_occurrence_on
        occurrences = 0
        while next_date <= through && rule.can_generate_on?(next_date) && occurrences < MAX_OCCURRENCES_PER_RUN
          rule.transactions.create!(
            user: rule.user,
            account: rule.account,
            category: rule.category,
            kind: rule.kind,
            amount: rule.amount,
            occurred_on: next_date,
            note: rule.note,
            is_recurring: true
          )
          rule.update!(last_generated_on: next_date, generated_count: rule.generated_count + 1)
          next_date = rule.next_occurrence_on
          occurrences += 1
        end
      end
    end
  end
end
