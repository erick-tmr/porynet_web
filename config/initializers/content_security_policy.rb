# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    policy.style_src   :self
    policy.font_src    :self
    policy.img_src     :self, :data
    policy.connect_src :self
    policy.object_src  :none
    policy.base_uri    :self
  end

  # A per-request nonce authorizes the inline <script type="importmap"> block
  # (and the module shim) that javascript_importmap_tags emits under script-src.
  # No nonce on style-src: every inline style was flattened into CSS classes.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
