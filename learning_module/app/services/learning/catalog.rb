module Learning
  class Catalog
    ROOT = Rails.root.join("learning_module/content")
    def self.questions
      JSON.parse(ROOT.join("questions.json").read)
    end

    def self.resources
      JSON.parse(ROOT.join("resources.json").read)
    end

    def self.resource(id)
      resources.find { |entry| entry.fetch("id") == id }
    end

    def self.install!(user)
      user.with_lock do
        %w[plan arrays structures trees dynamic behavioral design mock].each_with_index do |key, index|
          user.learning_items.find_or_create_by!(source_key: "roadmap:#{key}") do |item|
            item.title = I18n.t("learning.seeds.#{key}.title", locale: :en)
            item.position = index * 10
            item.resource_key = {"plan" => "coding-interview-study-plan", "arrays" => "algorithms--array", "structures" => "algorithms--hash-table", "trees" => "algorithms--tree", "dynamic" => "algorithms--dynamic-programming", "behavioral" => "behavioral-interview", "design" => "system-design", "mock" => "mock-interviews"}.fetch(key)
          end
        end
      end
    end
  end
end
