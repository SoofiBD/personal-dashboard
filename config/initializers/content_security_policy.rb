# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self, "https://fonts.gstatic.com"
    policy.img_src :self, :data
    policy.object_src :none
    policy.script_src :self, "https://cdn.jsdelivr.net"
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self
    policy.base_uri :none
    policy.frame_ancestors :none
  end
end
