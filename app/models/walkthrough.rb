module Walkthrough
  # Marker categories in the order the map legend lists them.
  MAP_CATEGORIES = %w[trainer npc item hidden exit].freeze

  # Categories that are signposts, not chores: they raise a hint but never tick off.
  NON_TICKABLE = %w[exit npc].freeze

  DENSE_TRAINERS = 6

  Encounter = Data.define(:dex, :name, :how, :rate, :level, :rarity, :tip_key, :evo_line) do
    def gift? = %w[GIFT STARTER TRADE].include?(how)
    def wild? = !gift?
  end

  Item = Data.define(:name, :where_key, :sprite, :at, :tick) do
    def initialize(at: nil, tick: nil, **rest) = super
  end

  HiddenItem = Data.define(:name, :where_key, :image, :pin, :sprite, :at, :tick) do
    def initialize(at: nil, tick: nil, **rest) = super
  end
  LaterItem = Data.define(:name, :sprite, :kind, :need, :where_key, :after_key, :image, :pin) do
    def image? = !image.nil?
  end
  TriviaCard = Data.define(:dex, :name, :tone, :rows)
  Trivia = Data.define(:anchor, :title_key, :intro_key, :note_key, :cards)
  Missable = Data.define(:anchor, :title_key, :body_key, :tip_key, :after_step)
  Shot = Data.define(:image, :label) do
    def map? = !image.nil?
  end
  # What the game says about a place you can walk into, generated into yellow_places.json from
  # the disassembly: the kind of building, a Gym's leader and prize, a Mart's stock, whatever
  # someone inside hands over, and how many trainers and item balls wait in there.
  Gift = Data.define(:dex, :name, :level, :sold) do
    def sold? = sold
  end
  GymFacts = Data.define(:leader, :types, :badge, :tm)
  GiftItem = Data.define(:name, :qty) do
    def stack? = qty > 1
  end
  Place = Data.define(:kind, :gym, :stock, :gift_mon, :gift_item, :trainers, :items) do
    def initialize(gym: nil, stock: [], gift_mon: [], gift_item: [], trainers: 0, items: 0, **rest)
      super(gym: gym, stock: stock, gift_mon: gift_mon, gift_item: gift_item,
        trainers: trainers, items: items, **rest)
    end

    def gym? = !gym.nil?
    def stock? = stock.any?
    def gift_item? = gift_item.any?
    def trainers? = trainers.positive?
    def items? = items.positive?
  end

  # One clickable point on an area map, read from the game data. `x`/`y` are percentages of the
  # rendered PNG; `ref` joins back to the game fact (OPP_CLASS:party, an item const, a map const).
  # An exit also carries the `place` its door leads to, when the game states anything about it.
  MapMarker = Data.define(:id, :cat, :key, :name, :x, :y, :align, :lane, :glyph, :edge, :ref,
    :note, :place) do
    def initialize(key: nil, glyph: nil, edge: nil, lane: 0, note: nil, place: nil, **rest) = super
    def key? = !key.nil?
    def tickable? = !NON_TICKABLE.include?(cat)
    def glyph_or_key = glyph || key
    def note? = !note.nil?
    def place? = !place.nil?
  end

  AreaMap = Data.define(:image, :width, :height, :floor, :name, :markers) do
    def initialize(name: "", markers: [], **rest) = super
    def floor? = !floor.empty?
    def markers? = markers.any?
    def marker_counts = markers.group_by(&:cat).transform_values(&:size)
    def tickable_count = markers.count(&:tickable?)
    def markers_in(cat) = markers.select { |marker| marker.cat == cat }
    # A map half-again wider than it is tall reads as a horizontal strip; it gets the full-width
    # landscape template (map on top, legend spread beneath) instead of the side-by-side split.
    def landscape? = width * 2 >= height * 3
  end

  StepLink = Data.define(:leg, :anchor)

  Step = Data.define(:n, :title_key, :text_key, :items, :hidden, :shot, :link) do
    def items? = items.any?
    def hidden? = hidden.any?
    def shot? = !shot.nil?
    def link? = !link.nil?
  end

  # team: [{dex:,name:,lvl:}]; where/battle: Shot or nil. `opp` is the "OPP_CLASS:party" pair from
  # the map object, which resolves `marker_key` so the card and its pin show the same letter.
  Trainer = Data.define(:cls, :name, :reward, :team, :sprite, :where, :battle, :opp, :marker_key,
    :tick) do
    def initialize(opp: nil, marker_key: nil, tick: nil, **rest) = super
    def marker_key? = !marker_key.nil?
  end
  # An in-game trade: give one species, receive another with a fixed nickname. give/receive are
  # { dex:, name: }; house/inside are Shots (the building on the overworld, the NPC inside).
  Trade = Data.define(:give, :receive, :nick, :npc_key, :title_key, :where_key, :note_key, :house,
    :inside)

  OakEntry = Data.define(:dex, :name, :qty, :why_key)
  BestCatch = Data.define(:dex, :slug, :rate, :tie, :alt_name, :alt_rate, :only) do
    def initialize(tie: false, alt_name: nil, alt_rate: nil, only: false, **rest) = super
    def rate? = !rate.nil?
  end

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
    :steps, :encounters, :trainers, :trades, :oak_queue, :gym, :gym_after, :area_maps, :later,
    :trivia, :missable
  ) do
    def initialize(gym: nil, gym_after: nil, area_maps: [], later: [], trivia: nil, missable: nil,
      trades: [], **rest)
      super(gym: gym, gym_after: gym_after, area_maps: area_maps, later: later, trivia: trivia,
        missable: missable, trades: trades, **rest)
    end

    def area_maps? = area_maps.any?
    def later? = later.any?
    def trivia? = !trivia.nil?
    def missable_after?(step_n) = !missable.nil? && missable.after_step == step_n

    def dex_list = encounters.map(&:dex)
    def wild_encounters = encounters.select(&:wild?)
    def catchable_count = wild_encounters.size
    def badge? = !badge.nil?
    def gym? = !gym.nil?

    def dense_trainers? = trainers.size > DENSE_TRAINERS

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
