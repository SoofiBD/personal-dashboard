Rails.application.config.session_store :cookie_store,
  key: "_personal_dashboard_session",
  same_site: :lax,
  secure: Rails.env.production?,
  httponly: true,
  expire_after: 12.hours
