require "test_helper"

class AiSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.dashboard_owner
    password = ENV.fetch("DASHBOARD_AUTH_PASSWORD")
    @owner.update!(password: password, password_confirmation: password)
    post session_path, params: {password: password}
  end

  test "shows Gemini settings and saves a model" do
    get ai_settings_path
    assert_response :success
    assert_select "h1", "Sağlayıcı ve model"

    patch ai_settings_path, params: {user: {ai_model: "gemini-2.0-flash"}}
    assert_redirected_to ai_settings_path
    assert_equal "gemini-2.0-flash", @owner.reload.ai_model
  end

  test "requires authentication" do
    delete session_path
    get ai_settings_path
    assert_redirected_to new_session_path
  end

  test "shows the authenticated assistant workspace" do
    get ai_assistant_path

    assert_response :success
    assert_select "h1", "Birlikte karar verelim."
    assert_select "form[data-ai-form]"
    assert_select "a[href='#{ai_settings_path}']", "Sağlayıcı ve model"
  end
end
