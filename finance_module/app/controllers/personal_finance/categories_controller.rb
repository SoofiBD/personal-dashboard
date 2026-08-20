module PersonalFinance
  class CategoriesController < ApplicationController
    before_action :set_category, only: %i[edit update destroy]
    def index
      @categories = owned(Category).includes(:children).order(:kind, :sort_order, :name)
    end
    def new
      @category = owned(Category).new(kind: params[:kind] || "expense")
    end
    def edit; end
    def create
      @category = owned(Category).new(category_params)
      save_or_render
    end
    def update
      @category.assign_attributes(category_params)
      save_or_render
    end
    def destroy
      @category.destroy!
      redirect_to finance_categories_path, notice: "Category deleted."
    end
    private
    def set_category
      @category = owned(Category).find(params[:id])
    end
    def category_params
      params.require(:category).permit(:name, :kind, :color, :icon, :parent_id, :sort_order)
    end
    def save_or_render
      @category.save ? redirect_to(finance_categories_path, notice: "Category saved.") : render(action_name == "update" ? :edit : :new, status: :unprocessable_entity)
    end
  end
end
