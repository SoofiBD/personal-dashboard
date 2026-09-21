# frozen_string_literal: true

class NotesTool
  extend Langchain::ToolDefinition

  def initialize(user:)
    @user = user
  end

  define_function :search_notes, description: "Search notes by title/body/tags" do
    property :query, type: "string", description: "Search query", required: true
  end

  define_function :get_note, description: "Full note by title" do
    property :title, type: "string", description: "Note title", required: true
  end

  define_function :create_note, description: "Create note. Params: title, body, tags" do
    property :title, type: "string", description: "Title", required: true
    property :body, type: "string", description: "Body", required: true
    property :tags, type: "string", description: "Comma-separated tags", required: false
  end

  define_function :list_recent_notes, description: "Last N notes (default 10)" do
    property :limit, type: "integer", description: "Max results", required: false
  end

  def search_notes(query:)
    notes = user.notes.matching(query).limit(20).map do |n|
      {title: n.title, body: n.body.truncate(200), tags: n.tags, updated_at: n.updated_at}
    end
    tool_response(content: notes)
  end

  def get_note(title:)
    note = user.notes.find_by(title: title)
    return tool_response(content: {error: "Note '#{title}' not found"}) unless note

    tool_response(content: {title: note.title, body: note.body, tags: note.tags, updated_at: note.updated_at})
  end

  def create_note(title:, body:, tags: "")
    note = user.notes.create!(title: title, body: body, tag_list: tags)
    note.sync_links!
    tool_response(content: {success: true, id: note.id, title: note.title})
  end

  def list_recent_notes(limit: 10)
    notes = user.notes.recent.limit(limit).map do |n|
      {title: n.title, body: n.body.truncate(150), tags: n.tags, updated_at: n.updated_at}
    end
    tool_response(content: notes)
  end

  private

  attr_reader :user

  def tool_response(content:)
    Langchain::ToolResponse.new(content: content.to_json)
  end
end
