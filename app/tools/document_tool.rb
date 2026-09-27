# frozen_string_literal: true

class DocumentTool
  extend Langchain::ToolDefinition

  def initialize(user:)
    @user = user
  end

  define_function :list_documents, description: "Recent PDF-to-Markdown documents owned by the user"

  define_function :get_document, description: "Document markdown and notes by document id" do
    property :id, type: "string", description: "Document UUID", required: true
  end

  define_function :update_document_content, description: "Propose updating a completed document's markdown or private notes; user confirmation is required" do
    property :id, type: "string", description: "Document UUID", required: true
    property :markdown_content, type: "string", description: "Replacement markdown", required: false
    property :custom_notes, type: "string", description: "Replacement private notes", required: false
  end

  def list_documents
    result = user.document_conversions.order(created_at: :desc).limit(12).map do |document|
      {id: document.id, filename: document.source_filename, status: document.status, updated_at: document.updated_at}
    end
    tool_response(result)
  end

  def get_document(id:)
    document = user.document_conversions.find_by(id: id)
    return tool_response(error: "Document not found") unless document

    tool_response(id: document.id, filename: document.source_filename, status: document.status, markdown_content: document.markdown_content, custom_notes: document.custom_notes)
  end

  def update_document_content(id:, markdown_content: nil, custom_notes: nil)
    document = user.document_conversions.completed.find_by(id: id)
    return tool_response(error: "Completed document not found") unless document
    return tool_response(error: "No document change supplied") if markdown_content.blank? && custom_notes.blank?

    action = AiAction.propose!(user: user, action_type: "documents.update_content", payload: {id: document.id, markdown_content: markdown_content, custom_notes: custom_notes}.compact, summary: "PDF içeriğini güncelle: #{document.source_filename}")
    tool_response(requires_confirmation: true, action_id: action.id, summary: action.summary)
  end

  private

  attr_reader :user

  def tool_response(content = nil, **kwargs)
    Langchain::ToolResponse.new(content: (kwargs.presence || content).to_json)
  end
end
