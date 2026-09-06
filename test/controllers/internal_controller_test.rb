require "test_helper"

class InternalControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = ENV.fetch("DASHBOARD_AUTH_PASSWORD")

  setup do
    @owner = User.dashboard_owner
    @owner.update!(password: PASSWORD, password_confirmation: PASSWORD)
  end

  test "PDF editor authorization requires an authenticated Rails session" do
    get "/internal/pdf_editor_authorization"
    assert_redirected_to new_session_path

    post session_path, params: {password: PASSWORD}
    get "/internal/pdf_editor_authorization"

    assert_response :no_content
    assert_equal "no-store", response.headers["Cache-Control"]
  end
end
