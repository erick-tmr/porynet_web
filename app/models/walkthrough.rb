module Walkthrough
  Encounter = Data.define(:dex, :name, :how, :rate, :level, :rarity, :tip_key, :evo_line) do
    def gift? = %w[GIFT STARTER TRADE].include?(how)
    def wild? = !gift?
  end

  Item = Data.define(:name, :where_key, :sprite)
  HiddenItem = Data.define(:name, :where_key, :image, :pin, :sprite)
  MapMarker = Data.define(:x_pct, :y_pct, :kind, :label)
  Shot = Data.define(:image, :label, :markers) do
    def map? = !image.nil?
  end
  AreaMap = Data.define(:image, :width, :height, :floor) do
    def floor? = !floor.empty?
  end

  Step = Data.define(:n, :title_key, :text_key, :items, :hidden, :shot) do
    def items? = items.any?
    def hidden? = hidden.any?
    def shot? = !shot.nil?
  end

  Trainer = Data.define(:cls, :name, :reward, :team, :sprite) # team: [{ dex:, name:, lvl: }]
  OakEntry = Data.define(:dex, :name, :qty, :why_key)
  BestCatch = Data.define(:dex, :slug, :rate, :tie, :alt_name, :alt_rate)

  GymStep = Data.define(:n, :text_key, :shot) do
    def shot? = !shot.nil?
  end

  Gym = Data.define(
    :type, :name, :intro_key, :shot, :badge, :badge_img, :tm, :puzzle, :trainers, :leader
  ) do
    def puzzle? = puzzle.any?
    def trainers? = trainers.any?
  end

  Location = Data.define(
    :slug, :kind, :name, :order, :note_key, :intro_key, :badge,
    :steps, :encounters, :trainers, :oak_queue, :gym, :gym_after, :area_maps
  ) do
    def initialize(gym: nil, gym_after: nil, area_maps: [], **rest)
      super(gym: gym, gym_after: gym_after, area_maps: area_maps, **rest)
    end

    def area_maps? = area_maps.any?

    def dex_list = encounters.map(&:dex)
    def wild_encounters = encounters.select(&:wild?)
    def catchable_count = wild_encounters.size
    def badge? = !badge.nil?
    def gym? = !gym.nil?

    # steps that lead up to the gym vs. the follow-up steps after it
    def lead_steps = gym_after ? steps.first(gym_after) : steps
    def after_steps = gym_after ? steps.drop(gym_after) : []
  end

  Leg = Data.define(:slug, :order, :special, :locations, :lead_key) do
    def single? = locations.one?
    def from = locations.first.name
    def to = locations.last.name
    def catch_count = locations.sum(&:catchable_count)
    def dex_list = locations.flat_map(&:dex_list).uniq
    def gyms = locations.select(&:badge?)
    def oak_queue = locations.flat_map(&:oak_queue).uniq(&:dex)
  end

  Game = Data.define(:slug, :name, :region, :dex_goal, :oak_queue, :locations, :legs, :best_catches) do
    def leg(slug) = legs.find { |l| l.slug == slug }

    def leg!(slug)
      leg(slug) || raise(ActiveRecord::RecordNotFound, "Unknown #{self.slug} leg: #{slug}")
    end

    def leg_before(current) = neighbor_leg(current, -1)
    def leg_after(current) = neighbor_leg(current, 1)

    def best_catch_here(location, encounter)
      found = best_catches[encounter.dex]
      found if found && found.slug == location.slug
    end

    def obtainable_dex = locations.flat_map(&:dex_list).uniq

    def obtainable_upto_leg(current)
      idx = locations.index(current.locations.last)
      locations.first(idx + 1).flat_map(&:dex_list).uniq
    end

    def new_dex_for_leg(current)
      idx = locations.index(current.locations.first)
      current.dex_list - locations.first(idx).flat_map(&:dex_list)
    end

    private

    def neighbor_leg(current, delta)
      pos = legs.index(current) + delta
      return nil if pos.negative? || pos >= legs.size

      legs[pos]
    end
  end

  def self.games = { "yellow" => Yellow.game }

  def self.find(slug) = games[slug]

  def self.find!(slug)
    find(slug) || raise(ActiveRecord::RecordNotFound, "No walkthrough for game: #{slug}")
  end
end
