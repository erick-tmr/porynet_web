module AccountData
  OAUTH_PROVIDERS = %w[google discord github facebook].freeze
  UNLOCKS = %w[collection porypc parser progress].freeze
  CONFIRMATION_STEPS = %w[inbox link login].freeze
  MENU_LINKS = %w[trainer_card tracker settings].freeze

  def self.unlock_number(index) = format("%02d", index + 1)
end
