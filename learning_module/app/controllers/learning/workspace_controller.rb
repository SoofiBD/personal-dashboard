module Learning
  class WorkspaceController < ApplicationController
    before_action :require_authentication
    before_action :prevent_sensitive_caching
    before_action :set_item, only: %i[show update destroy practice]

    def index
      @all = current_user.learning_items.order(:position, :id).to_a
      @items = @all.select do |item|
        (params[:track].blank? || item.track == params[:track]) &&
          (params[:status].blank? || item.status == params[:status]) &&
          (params[:q].blank? || item.display_title.downcase.include?(params[:q].to_s.downcase))
      end
      @due = @all.select { |item| item.status != "completed" && item.review_on && item.review_on <= Date.current }.sort_by(&:review_on)
      @next = @due.first || @all.find { |item| item.status == "active" } || @all.find { |item| item.status == "planned" }
      @minutes = current_user.learning_attempts.where(created_at: Time.current.beginning_of_week..Time.current).sum(:minutes)
    end

    def new
      @item = current_user.learning_items.build
    end

    def create
      if params[:starter] == "1"
        Catalog.install!(current_user)
        redirect_to learning_root_path, notice: t("learning.saved")
      elsif params[:question].present?
        question = Catalog.questions.find { |q| q.fetch("slug") == params[:question] }
        raise ActiveRecord::RecordNotFound unless question
        current_user.with_lock do
          @item = current_user.learning_items.find_or_create_by!(source_key: "question:#{question.fetch("slug")}") do |item|
            item.assign_attributes(title: question.fetch("title"), kind: "question", track: "algorithms", difficulty: question.fetch("difficulty").downcase, estimated_minutes: question.fetch("duration"))
          end
        end
        redirect_to learning_item_path(@item), notice: t("learning.saved")
      else
        @item = current_user.learning_items.build(item_params)
        if @item.save
          redirect_to learning_item_path(@item), notice: t("learning.saved")
        else
          render :new, status: :unprocessable_entity
        end
      end
    end

    def show
      @attempt = @item.attempts.build
      @history = @item.attempts.where.not(id: nil).order(created_at: :desc)
    end

    def update
      if @item.update(item_params)
        redirect_to learning_item_path(@item), notice: t("learning.saved")
      else
        @attempt = @item.attempts.build
        @history = @item.attempts.where.not(id: nil).order(created_at: :desc)
        render :show, status: :unprocessable_entity
      end
    end

    def practice
      @attempt = @item.attempts.build(params.require(:attempt).permit(:outcome, :minutes, :confidence, :reflection))
      @attempt.user = current_user
      if @attempt.valid?
        @item.with_lock do
          @attempt.save!
          days = (@attempt.outcome == "solved") ? [1, 1, 2, 4, 7, 14][@attempt.confidence] : 1
          @item.update!(confidence: @attempt.confidence, status: "review", review_on: Date.current + days)
        end
        redirect_to learning_item_path(@item), notice: t("learning.practice_saved")
      else
        @history = @item.attempts.where.not(id: nil).order(created_at: :desc)
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      @item.destroy!
      redirect_to learning_root_path, notice: t("learning.deleted"), status: :see_other
    end

    def library
      @questions = Catalog.questions.select { |q| params[:q].blank? || [q["title"], q["topic"], q["difficulty"]].join(" ").downcase.include?(params[:q].to_s.downcase) }
      @resources = Catalog.resources.select { |r| params[:q].blank? || r["title"].downcase.include?(params[:q].to_s.downcase) }
      @added = current_user.learning_items.pluck(:source_key)
    end

    def resource
      @resource = Catalog.resource(params[:id])
      raise ActiveRecord::RecordNotFound unless @resource
      @body = Catalog::ROOT.join("#{@resource.fetch("id")}.md").read
    end

    def export
      send_data JSON.pretty_generate(Context.build(current_user)), filename: "learning-context.json", type: "application/json"
    end

    private

    def set_item
      @item = current_user.learning_items.find(params[:id])
    end

    def item_params
      params.require(:learning_item).permit(:title, :track, :kind, :status, :difficulty, :position, :confidence, :estimated_minutes, :target_on, :review_on, :notes)
    end
  end
end
