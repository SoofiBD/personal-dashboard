# frozen_string_literal: true

# shortcut: langchainrb 0.19.5 sends tool results with role "function", which the Gemini API
# now rejects (400 "Role 'function' is not supported"); drop this once langchainrb ships a fix.
Langchain::Assistant::Messages::GoogleGeminiMessage.prepend(Module.new do
  def tool_hash = super.merge(role: "user")
end)
