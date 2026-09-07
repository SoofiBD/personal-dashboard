require "test_helper"

class DatabaseToolsControllerTest < ActionDispatch::IntegrationTest
  test "designer and configuration require authentication" do
    get database_tools_path
    assert_redirected_to new_session_path
    get "/database-editor/config.js"
    assert_redirected_to new_session_path
    get "/internal/database_editor_authorization"
    assert_redirected_to new_session_path
  end

  test "signed in users receive private account scoped configuration and module navigation" do
    owner = User.dashboard_owner
    password = ENV.fetch("DASHBOARD_AUTH_PASSWORD")
    owner.update!(password: password, password_confirmation: password)
    post session_path, params: {password: password}
    assert_redirected_to root_path
    get "/database-editor/config.js"
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_includes response.body, "dashboardUser = '#{owner.id}'"
    assert_includes response.body, "DISABLE_ANALYTICS: 'true'"
    get "/internal/database_editor_authorization"
    assert_response :no_content
    assert_equal "no-store", response.headers["Cache-Control"]
    get database_tools_path(locale: :en)
    assert_response :success
    assert_select "h1", "Database Design"
    %w[design import export].each do |action|
      assert_select "a.database-tool-card[href=?]", "/database-editor/?action=#{action}" do
        assert_select "svg.icon-sm", count: 1
      end
    end
    assert_select ".sidebar a[href=?]", database_tools_path
  end
end
