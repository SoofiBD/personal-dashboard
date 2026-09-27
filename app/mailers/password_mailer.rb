class PasswordMailer < ApplicationMailer
  def self.configured?
    %w[SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD SMTP_FROM DASHBOARD_DOMAIN].all? { |key| ENV[key].present? }
  end

  def reset(user, token)
    @reset_url = edit_password_url(token: token, host: ENV.fetch("DASHBOARD_DOMAIN"), protocol: "https")
    mail(to: user.email, from: ENV.fetch("SMTP_FROM"), subject: "Personal Dashboard parola sıfırlama")
  end
end
