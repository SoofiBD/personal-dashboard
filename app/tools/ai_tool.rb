# frozen_string_literal: true

# Base class for assistant tools.
#
# To add a tool: subclass AiTool, declare each model-callable method with `function`,
# and add the class to AiTool.all. Write tools never write directly: they call `propose`,
# list their action types in ACTIONS, and apply the payload only after the user approves
# it (AiActionExecutor -> #apply).
class AiTool
  # action_type => instance method that applies an approved payload
  ACTIONS = {}.freeze

  def self.all = [FinanceTool, LearningTool, MemoryTool, DashboardTool, DocumentTool]

  def self.functions = @functions ||= {}

  # Declares a Gemini function backed by the public method of the same name.
  # Properties are JSON-schema hashes, e.g. amount: {type: "number", description: "Amount"}.
  def self.function(name, description, required: [], **properties)
    declaration = {name: name.to_s, description: description}
    declaration[:parameters] = {type: "object", properties: properties, required: required.map(&:to_s)} if properties.any?
    functions[name.to_s] = declaration
  end

  def self.declarations = all.flat_map { |tool| tool.functions.values }

  def self.action_types = all.flat_map { |tool| tool::ACTIONS.keys }

  def self.for_action(action_type) = all.find { |tool| tool::ACTIONS.key?(action_type) }

  def initialize(user:)
    @user = user
  end

  # Runs a model-requested function. Only declared functions and declared parameters get through.
  def call(name, args)
    declaration = self.class.functions.fetch(name)
    allowed = declaration.dig(:parameters, :properties)&.keys&.map(&:to_s) || []
    public_send(name, **args.to_h.slice(*allowed).transform_keys(&:to_sym))
  end

  def apply(action)
    public_send(self.class::ACTIONS.fetch(action.action_type), action.payload)
  end

  private

  attr_reader :user

  def propose(action_type, payload, summary)
    action = AiAction.propose!(user: user, action_type: action_type, payload: payload, summary: summary.to_s.first(500))
    {requires_confirmation: true, action_id: action.id, summary: action.summary}
  end

  # Applies at once, without the approval card. Still goes through AiAction so the write is logged
  # and uses the same #apply path as approved actions. Use only for additive, easily undone writes.
  def perform(action_type, payload, summary)
    action = AiAction.propose!(user: user, action_type: action_type, payload: payload, summary: summary.to_s.first(500))
    {done: true, summary: action.summary}.merge(AiActionExecutor.new(action).execute!)
  rescue AiActionExecutor::Error => e
    {error: e.message}
  end

  def require_finance_permission!
    raise AiActionExecutor::Error, "Bu hesap için finans düzenleme yetkiniz yok." unless user.can_manage_finances?
  end
end
