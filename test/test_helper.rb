ENV["RAILS_ENV"] ||= "test"
ENV["DASHBOARD_AUTH_PASSWORD"] = "test-dashboard-password"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class PersonalFinance::IntegrationTest < ActionDispatch::IntegrationTest
  TEST_PASSWORD = ENV.fetch("DASHBOARD_AUTH_PASSWORD")

  setup :sign_in_dashboard_owner

  private

  def sign_in_dashboard_owner
    owner = User.dashboard_owner
    owner.update!(password: TEST_PASSWORD, password_confirmation: TEST_PASSWORD)
    post session_path, params: {password: TEST_PASSWORD}
    assert_redirected_to finance_root_path
  end
end
