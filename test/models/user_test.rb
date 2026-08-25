require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "legacy owner remains valid before password provisioning" do
    user = User.new(name: "Owner", currency: "TRY", time_zone: "Europe/Istanbul")

    assert user.valid?
    assert_not user.authenticate("unconfigured-password")
  end

  test "password provisioning requires a strong confirmed password" do
    user = User.new(name: "Owner", currency: "TRY", time_zone: "Europe/Istanbul")
    user.password = "short"
    user.password_confirmation = "different"

    assert_not user.valid?
    assert user.errors.added?(:password, "must be at least 16 characters")
    assert user.errors.added?(:password_confirmation, "does not match password")
  end

  test "provisioned owner authenticates only with the configured password" do
    password = "a-strong-dashboard-password"
    user = User.create!(
      name: "Owner",
      currency: "TRY",
      time_zone: "Europe/Istanbul",
      password: password,
      password_confirmation: password
    )

    assert user.authenticate(password)
    assert_not user.authenticate("incorrect-password")
  end

  test "dashboard owner lookup uses the same deterministic order for login and provisioning" do
    later_id = "ffffffff-ffff-4fff-8fff-ffffffffffff"
    earlier_id = "00000000-0000-4000-8000-000000000001"
    User.create!(id: later_id, name: "Created first", currency: "TRY", time_zone: "Europe/Istanbul", created_at: 1.day.ago)
    expected = User.create!(id: earlier_id, name: "Created later", currency: "TRY", time_zone: "Europe/Istanbul", created_at: Time.current)

    assert_equal expected, User.dashboard_owner
    assert_equal expected, User.dashboard_owner_record
  end

  test "password rotation increments the authentication version" do
    user = User.create!(name: "Owner", currency: "TRY", time_zone: "Europe/Istanbul")

    assert_difference -> { user.reload.authentication_version }, 1 do
      user.rotate_dashboard_password!("rotated-dashboard-password")
    end
    assert user.authenticate("rotated-dashboard-password")
  end
end
