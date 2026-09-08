module Notes
  class NotesController < ApplicationController
    before_action :set_note, only: %i[show edit update destroy]

    def index
      @query = params[:q].to_s
      @tag = params[:tag].to_s.downcase
      @notes = current_user.notes.matching(@query).recent
      @notes = @notes.where("LOWER(tag_list) LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@tag)}%") if @tag.present?
      @tags = current_user.notes.pluck(:tag_list).flat_map { |list| list.to_s.split(",") }.map { |tag| tag.strip.downcase }.reject(&:blank?).tally.sort_by { |tag, count| [-count, tag] }
    end

    def graph
      @notes = current_user.notes.includes(:outgoing_links).recent
      @graph_nodes = @notes.map do |note|
        {
          id: note.id,
          title: note.title,
          pinned: note.pinned?,
          tags: note.tags,
          excerpt: note.body.to_s.gsub(/[#*_`\[\]]/, " ").squish.first(240),
          updated_at: I18n.l(note.updated_at, format: :short),
          url: notes_note_path(note)
        }
      end
      @graph_links = @notes.flat_map do |note|
        note.outgoing_links.filter_map do |link|
          {source: link.source_note_id, target: link.target_note_id} if @graph_nodes.any? { |node| node[:id] == link.target_note_id }
        end
      end
    end

    def show
    end

    def new
      @note = current_user.notes.build
    end

    def create
      @note = current_user.notes.build(note_params)
      if @note.save
        @note.sync_links!
        redirect_to notes_note_path(@note), notice: "Not kaydedildi."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @note.update(note_params)
        @note.sync_links!
        redirect_to notes_note_path(@note), notice: "Not güncellendi."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @note.destroy!
      redirect_to notes_root_path, notice: "Not silindi.", status: :see_other
    end

    private

    def set_note
      @note = current_user.notes.includes(:linked_notes, :backlinks).find(params[:id])
    end

    def note_params
      permitted = params.require(:note).permit(:title, :body, :pinned, :tag_list)
      permitted[:tags] = permitted.delete(:tag_list) if permitted.key?(:tag_list)
      permitted
    end
  end
end
