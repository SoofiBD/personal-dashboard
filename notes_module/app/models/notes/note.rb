module Notes
  class Note < ApplicationRecord
    self.table_name = "notes"

    belongs_to :user
    has_many :outgoing_links, class_name: "Notes::NoteLink", foreign_key: :source_note_id, dependent: :destroy, inverse_of: :source_note
    has_many :incoming_links, class_name: "Notes::NoteLink", foreign_key: :target_note_id, dependent: :destroy, inverse_of: :target_note
    has_many :linked_notes, through: :outgoing_links, source: :target_note
    has_many :backlinks, through: :incoming_links, source: :source_note

    validates :title, presence: true, length: {maximum: 160}
    validates :body, length: {maximum: 100_000}

    scope :recent, -> { order(pinned: :desc, updated_at: :desc) }
    scope :matching, ->(query) {
      return all if query.blank?

      escaped = ActiveRecord::Base.sanitize_sql_like(query.strip)
      where("title ILIKE :term OR body ILIKE :term OR tag_list ILIKE :term", term: "%#{escaped}%")
    }

    def tags
      tag_list.to_s.split(",").map { |tag| tag.strip.downcase }.reject(&:blank?).uniq
    end

    def tags=(value)
      self.tag_list = value.to_s.split(",").map { |tag| tag.strip.downcase.gsub(/[^[:alnum:] _-]/, "") }.reject(&:blank?).uniq.join(", ")
    end

    def sync_links!
      titles = body.to_s.scan(/\[\[([^\]]+)\]\]/).flatten.map { |title| title.strip }.reject(&:blank?).uniq
      targets = user.notes.where("LOWER(title) IN (?)", titles.map(&:downcase)).where.not(id: id)
      outgoing_links.where.not(target_note_id: targets.select(:id)).delete_all
      targets.find_each { |target| outgoing_links.find_or_create_by!(target_note: target, user: user) }
    end
  end
end
