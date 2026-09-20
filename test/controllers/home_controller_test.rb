require "test_helper"

class HomeControllerTest < PersonalFinance::IntegrationTest
  test "renders workspace hub without sidebar in Turkish" do
    get root_path(locale: :tr)
    assert_response :success
    assert_select ".workspace-hub-container"
    assert_select ".sidebar", count: 0
    assert_select ".module-launcher-card", count: 8
    assert_select ".module-launcher-card", text: /Notlar/i
    assert_select ".module-launcher-card", text: /Spor Salonu/i
    assert_select "a.module-launcher-card[href='#{gym_root_path}']", count: 1
    assert_select ".module-launcher-card", text: /PDF Düzenleme/i
    assert_select "h1", text: "İçerik Merkeziniz"
  end

  test "renders workspace hub without sidebar in English" do
    get root_path(locale: :en)
    assert_response :success
    assert_select ".workspace-hub-container"
    assert_select ".sidebar", count: 0
    assert_select ".module-launcher-card", count: 8
    assert_select ".module-launcher-card", text: /Notes/i
    assert_select ".module-launcher-card", text: /Spor Salonu/i
    assert_select "a.module-launcher-card[href='#{gym_root_path}']", count: 1
    assert_select ".module-launcher-card", text: /PDF Editor/i
    assert_select "h1", text: "Content Hub"
  end
end
