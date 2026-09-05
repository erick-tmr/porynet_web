module AccountData
  OAUTH_PROVIDERS = %w[google discord github facebook].freeze
  UNLOCKS = %w[collection porypc parser progress].freeze
  CONFIRMATION_STEPS = %w[inbox link login].freeze
  SECTIONS = %w[card avatar security save_file].freeze
  PASSWORD_RULES = %w[length mix unique].freeze
  STRENGTH_LEVELS = %w[none weak fair good elite].freeze
  BADGES = %w[boulder cascade thunder rainbow soul marsh volcano earth].freeze
  DEX_TOTAL = 151
  ERAS = %w[all current gen1 gen2 gen3 gen4 gen5 gen6 gen7 gen8 gen9 art].freeze
  PAGE_SIZE = 60
  SIGNUP_AVATARS = %w[red blue green].freeze

  Avatar = Data.define(:id, :name, :era, :key, :art) do
    def art? = art
  end

  MANIFEST = Rails.root.join("app/models/account_data/avatars.json")
  AVATARS = JSON.parse(MANIFEST.read, symbolize_names: true)
                .map { |row| Avatar.new(**row) }.freeze
  BY_ID = AVATARS.index_by(&:id).freeze

  Page = Data.define(:rows, :number, :total) do
    def first? = number == 1
    def last? = number >= total
    def many? = total > 1
  end

  Save = Data.define(:slug, :registered, :badges, :oak, :playtime) do
    def badge_count = badges.size
    def badges? = badges.any?
  end

  SAVES = [
    Save.new("yellow", 54, %w[boulder cascade], 41, "09:47"),
    Save.new("red", 87, %w[boulder cascade thunder earth], 12, "31:24"),
    Save.new("blue", 151, BADGES, 0, "62:10"),
    Save.new("green", 12, [], 96, "01:12"),
    Save.new("yellow-legacy", 73, %w[boulder cascade thunder], 22, "18:39")
  ].index_by(&:slug).freeze

  def self.unlock_number(index) = format("%02d", index + 1)

  def self.avatar(id) = BY_ID.fetch(id, AVATARS.first)

  def self.avatar_ids = AVATARS.map(&:id)

  def self.era(name) = ERAS.include?(name) ? name : "all"

  def self.search(era:, query:)
    rows = era == "all" ? AVATARS : AVATARS.select { |avatar| avatar.era == era }
    return rows if query.blank?

    needle = query.to_s.downcase
    rows.select { |avatar| avatar.name.downcase.include?(needle) }
  end

  def self.page(rows, number)
    total = [ (rows.size / PAGE_SIZE.to_f).ceil, 1 ].max
    picked = number.to_i.clamp(1, total)
    Page.new(rows: rows[(picked - 1) * PAGE_SIZE, PAGE_SIZE] || [], number: picked, total: total)
  end

  def self.save_for(slug) = SAVES.fetch(slug, SAVES.values.first)

  def self.trainer_id(user) = format("%05d", user.id)
end
