# frozen_string_literal: true

if Rails.env.development?
  Rails.application.config.to_prepare do
    LetterOpenerWeb::ApplicationController.content_security_policy(false)
  end
end
