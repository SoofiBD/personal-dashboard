require "test_helper"

class AiSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.dashboard_owner
    password = ENV.fetch("DASHBOARD_AUTH_PASSWORD")
    @owner.update!(password: password, password_confirmation: password)
    post session_path, params: {password: password}
  end

  test "shows local AI settings and saves a model returned by Jan" do
    jan = Object.new
    jan.define_singleton_method(:health) { {connected: true, models: ["qwen3-4b"]} }
    jan.define_singleton_method(:models) { ["qwen3-4b"] }
    jan.define_singleton_method(:base_url) { "http://jan:1337" }

    with_jan_client(jan) do
      get ai_settings_path
      assert_response :success
      assert_select "h1", "Jan bağlantısı"
      assert_select "option[value='qwen3-4b']", "qwen3-4b"

      patch ai_settings_path, params: {user: {ai_model: "qwen3-4b"}}
      assert_redirected_to ai_settings_path
    end

    assert_equal "jan_local", @owner.reload.ai_provider
    assert_equal "qwen3-4b", @owner.ai_model
  end

  test "requires authentication" do
    delete session_path
    get ai_settings_path
    assert_redirected_to new_session_path
  end

  private

  def with_jan_client(client)
    original = Ai::JanClient.method(:new)
    Ai::JanClient.define_singleton_method(:new) { |*_args, **_options| client }
    yield
  ensure
    Ai::JanClient.define_singleton_method(:new, original)
  end
end
