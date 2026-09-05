module AccountData
  OAUTH_PROVIDERS = %w[google discord github facebook].freeze
  UNLOCKS = %w[collection porypc parser progress].freeze
  CONFIRMATION_STEPS = %w[inbox link login].freeze
  MENU_LINKS = %w[trainer_card tracker settings].freeze
  SECTIONS = %w[card avatar security save_file].freeze
  PASSWORD_RULES = %w[length mix unique].freeze
  STRENGTH_LEVELS = %w[none weak fair good elite].freeze
  BADGES = %w[boulder cascade thunder rainbow soul marsh volcano earth].freeze
  DEX_TOTAL = 151

  Avatar = Data.define(:id, :group, :key, :art) do
    def art? = art
  end

  HERO_AVATARS = %w[red blue green].freeze
  ELITE_AVATARS = %w[lance lorelei bruno agatha].freeze
  CLASS_AVATARS = %w[biker birdkeeper cueball engineer fisherman gambler hiker pokemaniac rocket
                     scientist youngster].freeze

  AVATARS = [
    *HERO_AVATARS.map { |id| Avatar.new(id, "heroes", "account/avatars/#{id}.png", false) },
    *ELITE_AVATARS.map { |id| Avatar.new(id, "elite", "walkthrough/art/#{id}-art.png", true) },
    *CLASS_AVATARS.map do |id|
      Avatar.new(id, "trainers", "walkthrough/yellow/trainers/#{id}-gen1.png", false)
    end
  ].freeze

  AVATAR_GROUPS = %w[all heroes elite trainers].freeze
  SIGNUP_AVATARS = HERO_AVATARS

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

  def self.avatar(id) = AVATARS.find { |entry| entry.id == id } || AVATARS.first

  def self.avatar_ids = AVATARS.map(&:id)

  def self.avatars_in(group)
    return AVATARS if group == "all"

    AVATARS.select { |entry| entry.group == group }
  end

  def self.avatar_group(name) = AVATAR_GROUPS.include?(name) ? name : "all"

  def self.save_for(slug) = SAVES.fetch(slug, SAVES.fetch(SAVES.keys.first))

  def self.trainer_id(user) = format("%05d", user.id)
end
