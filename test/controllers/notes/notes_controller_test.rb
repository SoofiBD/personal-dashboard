require "test_helper"

class Notes::NotesControllerTest < PersonalFinance::IntegrationTest
  test "lists, creates and searches notes" do
    get notes_root_path
    assert_response :success
    assert_select "h1", "Notlar"

    get new_notes_note_path
    assert_response :success
    assert_select "input[name='note[title]']"

    assert_difference("Notes::Note.count", 1) do
      post notes_notes_path, params: {note: {title: "Haftalık plan", body: "Öncelikler", tag_list: "plan, iş", pinned: "1"}}
    end
    note = Notes::Note.last
    assert_redirected_to notes_note_path(note)

    get notes_root_path(q: "Öncelikler")
    assert_response :success
    assert_select ".notes-card h2", "Haftalık plan"
  end

  test "shows a graph scoped to the current user's notes" do
    User.dashboard_owner.notes.create!(title: "Bağlı not", body: "")
    source = User.dashboard_owner.notes.create!(title: "Kaynak not", body: "[[Bağlı not]]")
    source.sync_links!

    get graph_notes_notes_path

    assert_response :success
    assert_select "[data-notes-graph]"
    assert_match "Kaynak not", response.body
    assert_select "[data-graph-search]"
    assert_select "[data-graph-layout]"
    assert_select "[data-graph-zoom-in]"
    assert_select "[data-graph-details]"
  end
end
