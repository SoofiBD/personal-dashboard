require "test_helper"
require "minitest/mock"

class PersonalFinance::PaymentReminderNotificationsJobTest < ActiveJob::TestCase
  test "delegates to the reminder generator" do
    called = false
    PersonalFinance::PaymentReminderNotificationGenerator.stub :call, -> { called = true } do
      PersonalFinance::PaymentReminderNotificationsJob.perform_now
    end

    assert called
  end
end
