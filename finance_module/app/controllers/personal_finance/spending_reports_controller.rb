module PersonalFinance
  class SpendingReportsController < ApplicationController
    def show
      RecurringTransactionGenerator.generate_due_for(current_panel_user)
      @from, @to = selected_range
      @previous_from = @from - period_length
      @previous_to = @from - 1.day

      categories = owned(Category).expense.includes(:children).order(:sort_order, :name).to_a
      current_spending = spending_by_category(@from..@to)
      previous_spending = spending_by_category(@previous_from..@previous_to)

      @category_data = categories.select { |category| category.parent_id.nil? }.filter_map do |category|
        child_ids = category.children.map(&:id)
        current = current_spending[category.id].to_f + child_ids.sum { |id| current_spending[id].to_f }
        previous = previous_spending[category.id].to_f + child_ids.sum { |id| previous_spending[id].to_f }
        next unless current.positive? || previous.positive?

        {
          id: category.id,
          name: category.name,
          color: category.color.presence || "#3B82F6",
          current: current,
          previous: previous,
          children: category.children.filter_map do |child|
            amount = current_spending[child.id].to_f
            {name: child.name, amount: amount, color: child.color.presence || category.color.presence || "#3B82F6"} if amount.positive?
          end
        }
      end.sort_by { |item| -item[:current] }

      @total_spending = @category_data.sum { |item| item[:current] }
      @previous_total_spending = @category_data.sum { |item| item[:previous] }
      @top_categories = @category_data.first(5)
      @comparison_change = @total_spending - @previous_total_spending
    end

    private

    def selected_range
      default_from = Date.current.beginning_of_month
      default_to = Date.current.end_of_month
      from = parse_date(params[:from]) || default_from
      to = parse_date(params[:to]) || default_to
      (from <= to) ? [from, to] : [default_from, default_to]
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end

    def period_length
      (@to - @from).to_i + 1
    end

    def spending_by_category(range)
      owned(Transaction).expense.during(range).where.not(category_id: nil).group(:category_id).sum(:amount)
    end
  end
end
