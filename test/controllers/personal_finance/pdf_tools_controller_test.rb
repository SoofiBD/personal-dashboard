require "test_helper"

class PersonalFinance::PdfToolsControllerTest < PersonalFinance::IntegrationTest
  setup do
    User.dashboard_owner.update!(onboarded_at: Time.current)
  end

  test "renders the dashboard-native PDF tools page" do
    get finance_pdf_tools_path

    assert_response :success
    assert_select "h1", text: "PDF Çalışma Alanı"
    assert_select ".pdf-tools-hero .pdf-tools-status", text: /Hazır|Bekleniyor/
    assert_select "#pdf-tools-ai-title", text: "AI modu"
    assert_select "a[href='/pdf-editor/add-text']", text: "Aracı aç"
    assert_select "a[href='/pdf-editor/merge-pdfs']", text: "Aracı aç"
    assert_select "a[href='/pdf-editor/compress-pdf']", text: "Aracı aç"
    assert_select "a[href='/pdf-editor/sign']", text: "Aracı aç"
  end

  test "renders the PDF tools page in English" do
    get finance_pdf_tools_path(locale: :en)

    assert_response :success
    assert_select "h1", text: "PDF Workspace"
    assert_select ".pdf-tools-hero .pdf-tools-status", text: /Ready|Waiting/
    assert_select "#pdf-tools-ai-title", text: "AI mode"
  end
end
