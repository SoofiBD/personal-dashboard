require "test_helper"

class UserFlowsTest < ActionDispatch::IntegrationTest
  PASSWORD = ENV.fetch("DASHBOARD_AUTH_PASSWORD")

  setup do
    @owner = User.dashboard_owner
    @owner.update!(password: PASSWORD, password_confirmation: PASSWORD, onboarded_at: Time.current)
    RateLimitCounter.delete_all
  end

  test "authenticates, completes MFA, and logs out" do
    @owner.prepare_mfa!
    @owner.enable_mfa!(Totp.code_for(@owner.mfa_secret))

    post session_path, params: {password: "incorrect-password"}
    assert_response :unprocessable_content

    post session_path, params: {password: PASSWORD}
    assert_redirected_to mfa_path

    post verify_mfa_path, params: {code: Totp.code_for(@owner.mfa_secret)}
    assert_redirected_to root_path

    get finance_root_path
    assert_response :success

    delete session_path
    get finance_root_path
    assert_redirected_to new_session_path
  end

  test "limits repeated invalid passwords" do
    SessionsController::LOGIN_ATTEMPT_LIMIT.times do
      post session_path, params: {password: "incorrect-password"}
      assert_response :unprocessable_content
    end

    post session_path, params: {password: "incorrect-password"}
    assert_response :too_many_requests
    assert_equal SessionsController::LOGIN_ATTEMPT_WINDOW.to_i.to_s, response.headers["Retry-After"]
  end

  test "allows finance read access but reserves user management for owners" do
    editor = create_user("Editor", "editor@example.test", "editor")
    viewer = create_user("Viewer", "viewer@example.test", "viewer")

    sign_in_as(editor)
    get finance_root_path
    assert_response :success
    get users_path
    assert_redirected_to finance_root_path

    sign_in_as(viewer)
    get finance_accounts_path
    assert_response :success
    get users_path
    assert_redirected_to finance_root_path
  end

  test "onboards a finance user, records a transaction, and queues a PDF conversion" do
    @owner.update!(onboarded_at: nil)
    sign_in_as(@owner)

    post finance_onboarding_path, params: {
      currency: "TRY",
      accounts: [{name: "Main account", kind: "bank", opening_balance: "1000"}],
      categories: [{name: "Food", kind: "expense", color: "#3B82F6", icon: "cart", enabled: "1"}],
      planned_income: "10000",
      allocations: {"Food" => "3000"}
    }
    assert_redirected_to finance_root_path

    account = @owner.financial_accounts.find_by!(name: "Main account")
    category = @owner.finance_categories.find_by!(name: "Food")
    budget = @owner.finance_budget_periods.find_by!(starts_on: Date.current.beginning_of_month)
    assert_equal 3000, budget.allocations.find_by!(category: category).planned_amount.to_i

    assert_difference("PersonalFinance::Transaction.count", 1) do
      post finance_transactions_path, params: {transaction: {
        financial_account_id: account.id, category_id: category.id, kind: "expense",
        amount: "125", occurred_on: Date.current, note: "First grocery purchase"
      }}
    end
    assert_redirected_to finance_transactions_path

    upload = fixture_file_upload("report.pdf", "application/pdf")
    assert_enqueued_with(job: PersonalFinance::PdfDocumentConversionJob) do
      post finance_document_conversions_path, params: {pdf_file: upload, annotation_mode: "both"}
    end
    conversion = PersonalFinance::DocumentConversion.where(user: @owner).order(:created_at).last
    assert_predicate conversion, :processing?
    assert_predicate conversion, :source_pdf_available?
    assert_equal "%PDF-integration-test\n", conversion.source_pdf_binary
  end

  private

  def create_user(name, email, role)
    User.create!(name: name, email: email, role: role, currency: "TRY", time_zone: "Europe/Istanbul", locale: "tr", password: PASSWORD, password_confirmation: PASSWORD, onboarded_at: Time.current)
  end

  def sign_in_as(user)
    delete session_path if authenticated_request?
    post session_path, params: {identifier: user.email, password: PASSWORD}
    assert_redirected_to root_path
  end

  def authenticated_request?
    get root_path
    response.successful?
  end
end
