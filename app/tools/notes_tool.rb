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

  define_function :update_note, description: "Propose updating a note by title; user confirmation is required" do
    property :title, type: "string", description: "Existing note title", required: true
    property :new_title, type: "string", description: "Replacement title", required: false
    property :body, type: "string", description: "Replacement body", required: false
    property :tags, type: "string", description: "Replacement tags", required: false
  end

  define_function :delete_note, description: "Propose deleting a note by title; user confirmation is required" do
    property :title, type: "string", description: "Existing note title", required: true
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

    tool_response(content: {id: note.id, title: note.title, body: note.body, tags: note.tags, updated_at: note.updated_at})
  end

  def update_note(title:, new_title: nil, body: nil, tags: nil)
    note = user.notes.find_by(title: title)
    return tool_response(content: {error: "Note not found"}) unless note
    payload = {id: note.id, title: new_title, body: body, tags: tags}.compact
    return tool_response(content: {error: "No change supplied"}) if payload.except(:id).empty?
    action = AiAction.propose!(user: user, action_type: "notes.update", payload: payload, summary: "Notu güncelle: #{note.title}")
    tool_response(content: {requires_confirmation: true, action_id: action.id, summary: action.summary})
  end

  def delete_note(title:)
    note = user.notes.find_by(title: title)
    return tool_response(content: {error: "Note not found"}) unless note
    action = AiAction.propose!(user: user, action_type: "notes.delete", payload: {id: note.id}, summary: "Notu sil: #{note.title}")
    tool_response(content: {requires_confirmation: true, action_id: action.id, summary: action.summary})
  end

  def create_note(title:, body:, tags: "")
    return tool_response(content: {error: "Bu hesap için not düzenleme yetkisi yok"}) unless user.can_manage_notes?
    action = AiAction.propose!(user: user, action_type: "notes.create", payload: {title: title, body: body, tags: tags}, summary: "Not oluştur: #{title}")
    tool_response(content: {requires_confirmation: true, action_id: action.id, summary: action.summary})
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
