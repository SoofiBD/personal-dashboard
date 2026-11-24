module PersonalFinance
  class CategorySuggester
    def self.call(user, note)
      query = note.to_s.strip.downcase
      return if query.length < 2

      Transaction.where(user: user).where.not(category_id: nil).where("LOWER(note) LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%").group(:category_id).order("COUNT(*) DESC").limit(1).pick(:category_id)
    end
  end
end
