require "test_helper"

class Notes::NoteTest < ActiveSupport::TestCase
  setup do
    @user = User.dashboard_owner
  end

  test "normalizes tags and creates links only to the owner's notes" do
    target = @user.notes.create!(title: "Bütçe fikri", body: "Hedef not")
    source = @user.notes.create!(title: "Plan", body: "[[Bütçe fikri]]", tags: " Plan, plan, Finans! ")

    source.sync_links!

    assert_equal %w[plan finans], source.tags
    assert_equal [target], source.linked_notes.to_a
    assert_equal [source], target.backlinks.to_a
  end

  test "does not link to a note owned by another user" do
    other_user = User.create!(name: "Reader", currency: "TRY", time_zone: "Europe/Istanbul", role: "viewer", locale: "tr", email: "reader@example.test")
    other_user.notes.create!(title: "Özel not", body: "")
    source = @user.notes.create!(title: "Plan", body: "[[Özel not]]")

    source.sync_links!

    assert_empty source.linked_notes
  end
end
