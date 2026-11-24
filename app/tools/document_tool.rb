# frozen_string_literal: true

class DocumentTool < AiTool
  ACTIONS = {"documents.update_content" => :apply_update_content}.freeze

  function :list_documents, "Recent PDF-to-Markdown documents owned by the user"
  function :get_document, "Document markdown and notes by document id",
    required: %i[id],
    id: {type: "string", description: "Document UUID"}
  function :update_document_content, "Propose updating a completed document's markdown or private notes; user confirmation is required",
    required: %i[id],
    id: {type: "string", description: "Document UUID"},
    markdown_content: {type: "string", description: "Replacement markdown"},
    custom_notes: {type: "string", description: "Replacement private notes"}

  def list_documents
    user.document_conversions.order(created_at: :desc).limit(12).map do |document|
      {id: document.id, filename: document.source_filename, status: document.status, updated_at: document.updated_at}
    end
  end

  def get_document(id:)
    document = user.document_conversions.find_by(id: id)
    return {error: "Document not found"} unless document

    {id: document.id, filename: document.source_filename, status: document.status, markdown_content: document.markdown_content, custom_notes: document.custom_notes}
  end

  def update_document_content(id:, markdown_content: nil, custom_notes: nil)
    document = user.document_conversions.completed.find_by(id: id)
    return {error: "Completed document not found"} unless document
    return {error: "No document change supplied"} if markdown_content.blank? && custom_notes.blank?

    propose("documents.update_content", {id: document.id, markdown_content: markdown_content, custom_notes: custom_notes}.compact, "PDF içeriğini güncelle: #{document.source_filename}")
  end

  def apply_update_content(payload)
    require_finance_permission!
    document = user.document_conversions.completed.find(payload.fetch("id"))
    document.update!(payload.slice("markdown_content", "custom_notes").compact_blank)
    {record_type: "document_conversion", record_id: document.id}
  end
end
