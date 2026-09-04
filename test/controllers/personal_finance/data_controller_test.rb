require "test_helper"

class PersonalFinance::DataControllerTest < PersonalFinance::IntegrationTest
  setup do
    @user = User.dashboard_owner
    @user.update!(onboarded_at: Time.current)
  end

  test "shows backup export options" do
    get finance_data_path

    assert_response :success
    assert_select "a[href='#{export_finance_data_path(format: :json)}']", text: "JSON Yedeğini İndir"
    assert_select "a[href='#{export_finance_data_path(format: :csv)}']", text: "CSV Yedeğini İndir"
  end

  test "exports the current users data as json" do
    account = PersonalFinance::Account.create!(user: @user, name: "Backup account", kind: "bank", opening_balance: 100)

    get export_finance_data_path(format: :json)

    assert_response :success
    assert_equal "application/json", response.media_type

    payload = JSON.parse(response.body)
    assert_equal 1, payload.dig("metadata", "version")
    assert_includes payload.dig("data", "accounts").pluck("id"), account.id
  end

  test "exports the current users data as csv" do
    PersonalFinance::Account.create!(user: @user, name: "Backup account", kind: "bank", opening_balance: 100)

    get export_finance_data_path(format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_equal %w[table id attributes], CSV.parse(response.body).first
  end

  test "imports a JSON backup for the current user" do
    upload = fixture_file_upload("finance-backup.json", "application/json")

    assert_difference("PersonalFinance::Account.count", 1) do
      post import_finance_data_path, params: {backup_file: upload}
    end

    assert_redirected_to finance_data_path
    assert_equal "Imported account", PersonalFinance::Account.where(user: @user).order(:created_at).last.name
  end
end
