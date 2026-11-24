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

  test "returns to the requested editor page after sign-in, not the auth subrequest" do
    get "/internal/pdf_editor_authorization", headers: {"X-Forwarded-Uri" => "/pdf-editor/merge-pdfs"}
    assert_redirected_to new_session_path

    post session_path, params: {password: PASSWORD}
    assert_redirected_to "/pdf-editor/merge-pdfs"
  end

  test "ignores forwarded paths outside the editor" do
    get "/internal/pdf_editor_authorization", headers: {"X-Forwarded-Uri" => "//evil.example/x"}
    post session_path, params: {password: PASSWORD}

    assert_redirected_to "/pdf-editor/"
  end
end
