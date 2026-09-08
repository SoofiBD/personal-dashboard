module Notes
  class NoteLink < ApplicationRecord
    self.table_name = "note_links"

    belongs_to :user
    belongs_to :source_note, class_name: "Notes::Note"
    belongs_to :target_note, class_name: "Notes::Note"

    validates :target_note_id, uniqueness: {scope: :source_note_id}
    validate :notes_belong_to_link_owner

    private

    def notes_belong_to_link_owner
      return if user_id.blank? || source_note.blank? || target_note.blank?
      return if source_note.user_id == user_id && target_note.user_id == user_id

      errors.add(:base, "linked notes must belong to the same user")
    end
  end
end
