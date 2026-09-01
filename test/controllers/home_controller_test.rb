require "test_helper"

class HomeControllerTest < PersonalFinance::IntegrationTest
  test "renders workspace hub without sidebar in Turkish" do
    get root_path(locale: :tr)
    assert_response :success
    assert_select ".workspace-hub-container"
    assert_select ".sidebar", count: 0
    assert_select ".module-launcher-card", count: 3
    assert_select ".module-launcher-card", text: /PDF Düzenleme/i
    assert_select "h1", text: "İçerik Merkeziniz"
  end

  test "renders workspace hub without sidebar in English" do
    get root_path(locale: :en)
    assert_response :success
    assert_select ".workspace-hub-container"
    assert_select ".sidebar", count: 0
    assert_select ".module-launcher-card", count: 3
    assert_select ".module-launcher-card", text: /PDF Editor/i
    assert_select "h1", text: "Content Hub"
  end
end
