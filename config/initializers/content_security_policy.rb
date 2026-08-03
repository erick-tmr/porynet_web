# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    policy.style_src   :self
    policy.font_src    :self
    policy.img_src     :self, :data, *Array(Rails.application.config.x.r2_public_host.presence)
    policy.connect_src :self
    policy.object_src  :none
    policy.base_uri    :self
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  # script-src covers the importmap JSON block. style-src covers exactly one thing: the stylesheet
  # Turbo injects at boot for its progress bar, which it nonces from the csp-nonce meta tag.
  # A nonce matches elements, never attributes, so inline style= stays blocked either way.
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
