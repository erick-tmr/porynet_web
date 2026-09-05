# frozen_string_literal: true

Rails.application.config.after_initialize do
  Rails.application.routes_reloader.execute_unless_loaded
end
