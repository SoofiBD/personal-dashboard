module PersonalFinance
  class TagsController < ApplicationController
    before_action :set_tag, only: %i[edit update destroy]

    def index
      @tags = owned(Tag).left_joins(:transactions).select("finance_tags.*, COUNT(finance_transactions.id) AS transactions_count").group("finance_tags.id").order(:name)
      @tag = owned(Tag).new
    end

    def report
      @from = parse_date(params[:from]) || Date.current.beginning_of_month
      @to = parse_date(params[:to]) || Date.current.end_of_month
      @from, @to = Date.current.beginning_of_month, Date.current.end_of_month if @from > @to
      @tag_spending = owned(Tag).joins(:transactions).merge(Transaction.expense.during(@from..@to)).select("finance_tags.*, SUM(finance_transactions.amount) AS total_spending").group("finance_tags.id").order("total_spending DESC")
    end

    def new
      @tag = owned(Tag).new
    end

    def create
      @tag = owned(Tag).new(tag_params)
      save_or_render
    end

    def edit
    end

    def update
      @tag.assign_attributes(tag_params)
      save_or_render
    end

    def destroy
      @tag.destroy!
      redirect_to finance_tags_path, notice: "Etiket silindi."
    end

    def merge
      target = owned(Tag).find(params[:target_id])
      sources = owned(Tag).where(id: Array(params[:source_ids])).where.not(id: target.id)
      ActiveRecord::Base.transaction do
        TransactionTag.where(tag: sources).find_each do |join|
          if TransactionTag.exists?(transaction_id: join.transaction_id, tag_id: target.id)
            join.destroy!
          else
            join.update!(tag: target)
          end
        end
        sources.destroy_all
      end
      redirect_to finance_tags_path, notice: "Etiketler birleştirildi."
    rescue ActiveRecord::RecordNotFound
      redirect_to finance_tags_path, alert: "Geçerli bir hedef etiket seçin."
    end

    private

    def set_tag
      @tag = owned(Tag).find(params[:id])
    end

    def tag_params
      params.require(:tag).permit(:name)
    end

    def save_or_render
      if @tag.save
        redirect_to finance_tags_path, notice: "Etiket kaydedildi."
      else
        render((action_name == "update") ? :edit : :new, status: :unprocessable_entity)
      end
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end
  end
end
