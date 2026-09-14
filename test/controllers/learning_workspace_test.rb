require "test_helper"

class LearningWorkspaceTest < PersonalFinance::IntegrationTest
  test "starter roadmap is idempotent and bilingual" do
    2.times { post learning_items_path, params: {starter: "1"} }
    assert_equal 8, User.dashboard_owner.learning_items.count
    get root_path
    assert_select ".module-launcher-card[href=?]", learning_root_path, count: 1
    get learning_root_path(locale: :tr)
    assert_response :success
    assert_select "h1", "Gelişim Atölyesi"
    assert_includes response.body, "Hedefini ve çalışma düzenini belirle"
    get learning_root_path(locale: :en)
    assert_response :success
    assert_select "h1", "Learning Studio"
    assert_includes response.body, "Define your goal and study routine"
    assert_no_match(/translation_missing/, response.body)
  end

  test "custom learning lifecycle and spaced review" do
    post learning_items_path, params: {learning_item: {title: "Linux lab", track: "system_engineering", kind: "project"}}
    item = User.dashboard_owner.learning_items.last
    assert_redirected_to learning_item_path(item)
    get learning_item_path(item)
    assert_response :success
    patch learning_item_path(item), params: {learning_item: {status: "active", notes: "Investigate scheduling"}}
    assert_equal "active", item.reload.status
    assert_difference("Learning::Attempt.count") do
      post practice_learning_item_path(item), params: {attempt: {outcome: "solved", minutes: 45, confidence: 4, reflection: "Explain time complexity"}}
    end
    assert_equal Date.current + 7, item.reload.review_on
    assert_equal "review", item.status
    get learning_item_path(item, locale: :en)
    assert_response :success
    assert_includes response.body, "Explain time complexity"
    assert_no_difference("Learning::Attempt.count") do
      post practice_learning_item_path(item), params: {attempt: {outcome: "solved", minutes: -1, confidence: 8}}
      assert_response :unprocessable_entity
    end
    assert_equal Date.current + 7, item.reload.review_on
    delete learning_item_path(item)
    assert_not Learning::Item.exists?(item.id)
    assert_equal 0, Learning::Attempt.where(item_id: item.id).count
  end

  test "catalog imports questions once and reads allowlisted resources" do
    get learning_library_path(locale: :en, q: "two sum")
    assert_response :success
    assert_includes response.body, "Two Sum"
    2.times { post learning_items_path, params: {question: "two-sum"} }
    assert_equal 1, User.dashboard_owner.learning_items.where(source_key: "question:two-sum").count
    get learning_resource_path("algorithms--array")
    assert_response :success
    assert_select ".learning-markdown[lang=en] h2", text: "Introduction"
    assert_select ".learning-markdown strong", text: "Advantages"
    assert_select ".learning-markdown ul li"
    assert_select ".learning-markdown table"
    assert_select ".learning-markdown a[href=?]", learning_resource_path("algorithms--linked-list")
    get learning_resource_path("missing")
    assert_response :not_found
    post learning_items_path, params: {question: "missing"}
    assert_response :not_found
  end

  test "user scope applies to mutations and exported AI context" do
    other = User.create!(name: "Another learner", currency: "TRY", time_zone: "Europe/Istanbul")
    item = other.learning_items.create!(title: "Private item", notes: "Secret reflection")
    get learning_item_path(item)
    assert_response :not_found
    patch learning_item_path(item), params: {learning_item: {title: "Changed"}}
    assert_response :not_found
    post practice_learning_item_path(item), params: {attempt: {outcome: "solved", minutes: 20, confidence: 3}}
    assert_response :not_found
    delete learning_item_path(item)
    assert_response :not_found
    get learning_export_path
    assert_response :success
    assert_equal 1, JSON.parse(response.body).fetch("schema_version")
    assert_not_includes response.body, "Secret reflection"
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "completed items stay out of review suggestions and custom titles survive" do
    post learning_items_path, params: {starter: "1"}
    item = User.dashboard_owner.learning_items.first
    item.update!(status: "completed", review_on: Date.yesterday, title: "My custom roadmap step")
    get learning_root_path(locale: :tr)
    assert_select ".learning-next", text: /My custom roadmap step/, count: 0
    assert_select ".learning-grid h2", text: "My custom roadmap step"
    assert_equal "My custom roadmap step", item.display_title
  end

  test "catalog entries are unique and importable" do
    questions = Learning::Catalog.questions
    assert_equal questions.size, questions.map { |question| question.fetch("slug") }.uniq.size
    questions.each do |question|
      assert_match %r{\Ahttps://leetcode.com/problems/}, question.fetch("url")
      assert_includes Learning::Item::DIFFICULTIES, question.fetch("difficulty").downcase
      assert (1..1440).cover?(question.fetch("duration"))
    end
    Learning::Catalog.resources.each do |resource|
      assert Learning::Catalog::ROOT.join("#{resource.fetch("id")}.md").file?
    end
  end

  test "learning requires authentication" do
    delete session_path
    get learning_root_path
    assert_redirected_to new_session_path
    get learning_export_path
    assert_redirected_to new_session_path
  end

  test "invalid item is rendered and search filters roadmap" do
    post learning_items_path, params: {learning_item: {title: "", track: "unknown"}}
    assert_response :unprocessable_entity
    User.dashboard_owner.learning_items.create!(title: "Kernel lab", track: "system_engineering")
    get learning_root_path(track: "algorithms")
    assert_response :success
    assert_select ".learning-grid h2", count: 0
    get learning_root_path(q: "Kernel")
    assert_response :success
    assert_includes response.body, "Kernel lab"
  end
end
