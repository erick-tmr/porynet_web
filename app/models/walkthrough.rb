module Walkthrough
  # Marker categories in the order the map legend lists them.
  MAP_CATEGORIES = %w[trainer npc item hidden exit].freeze

  # Categories that are signposts, not chores: they raise a hint but never tick off.
  NON_TICKABLE = %w[exit npc].freeze

  DENSE_TRAINERS = 6

  # `from_key`/`unlock_key` are optional locale keys for a gift Pokémon: who hands it over and any
  # condition to unlock it (Bulbasaur needs Pikachu's friendship at 147+, Squirtle the Thunder
  # Badge). `unlock_icon` is the R2 image that condition shows (a Pikachu, a badge).
  Encounter = Data.define(:dex, :name, :how, :rate, :level, :rarity, :tip_key, :evo_line,
    :from_key, :unlock_key, :unlock_icon) do
    def initialize(from_key: nil, unlock_key: nil, unlock_icon: nil, **rest) = super
    def gift? = %w[GIFT STARTER TRADE].include?(how)
    def wild? = !gift?
    def from? = !from_key.nil?
    def unlock? = !unlock_key.nil?
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
  Trivia = Data.define(:anchor, :title_key, :intro_key, :note_key, :cards, :shot, :yellow_only)
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
  # `note` is a locale key for a hand-authored line about places the game data cannot describe,
  # e.g. the Name Rater (renames a Pokémon but hands over nothing) or a flavor house; it leads
  # the hint in place of the generic "a house" line.
  Place = Data.define(:kind, :note, :gym, :stock, :gift_mon, :gift_item, :trainers, :items) do
    def initialize(note: nil, gym: nil, stock: [], gift_mon: [], gift_item: [], trainers: 0,
      items: 0, **rest)
      super(note: note, gym: gym, stock: stock, gift_mon: gift_mon, gift_item: gift_item,
        trainers: trainers, items: items, **rest)
    end

    def note? = !note.nil?
    def gym? = !gym.nil?
    def stock? = stock.any?
    def gift_item? = gift_item.any?
    def trainers? = trainers.positive?
    def items? = items.positive?
  end

  # What a place sells, one row per item. Its price and (for a TM) number/move/type come from the
  # generated item catalog in yellow_places.json; `desc_key` is a shared localized blurb, `rec_key`
  # the note behind a ★ recommended pick. `mtype` names a TM's sprite (tm-<type>).
  MartItem = Data.define(:name, :sprite, :price, :desc_key, :tm_no, :move, :mtype, :rec, :rec_key) do
    def initialize(price: nil, desc_key: nil, tm_no: nil, move: nil, mtype: nil, rec: false,
      rec_key: nil, **rest)
      super(price: price, desc_key: desc_key, tm_no: tm_no, move: move, mtype: mtype, rec: rec,
        rec_key: rec_key, **rest)
    end

    def price? = !price.nil?
    def desc? = !desc_key.nil?
    def tm? = !tm_no.nil?
    def rec? = rec
    def rec_key? = !rec_key.nil?
    def label = tm? ? "TM#{format('%02d', tm_no)} · #{move}" : name
  end

  # A labelled group of items on a shop counter. A plain city Mart has a single unlabelled counter;
  # a Celadon floor can split its stock across several (an item counter and a TM counter).
  MartCounter = Data.define(:title_key, :items) do
    def initialize(title_key: nil, **rest) = super
  end

  # A Celadon rooftop drink the thirsty girl swaps for a TM.
  MartTrade = Data.define(:drink, :drink_sprite, :tm_short, :tm_sprite, :move)

  # One floor of the Celadon Dept. Store: its label, what kind of counter it is, an optional free
  # TM gift, its item counters, and (rooftop only) the drink -> TM trades.
  MartFloor = Data.define(:id, :label, :kind, :name_key, :motto_key, :note_key, :gift, :counters,
    :trades) do
    def initialize(motto_key: nil, note_key: nil, gift: nil, counters: [], trades: [], **rest)
      super(motto_key: motto_key, note_key: note_key, gift: gift, counters: counters,
        trades: trades, **rest)
    end

    def note? = !note_key.nil?
    def motto? = !motto_key.nil?
    def gift? = !gift.nil?
    def trades? = trades.any?
  end

  # A place you can shop. A city Mart carries `counters`; the Celadon Dept. Store carries `floors`
  # and the store-header stats read off them.
  Mart = Data.define(:slug, :count, :blurb_key, :buy_key, :counters, :floors) do
    def initialize(blurb_key: nil, buy_key: nil, counters: [], floors: [], **rest)
      super(blurb_key: blurb_key, buy_key: buy_key, counters: counters, floors: floors, **rest)
    end

    def multi? = floors.any?
    def blurb? = !blurb_key.nil?
    def buy? = !buy_key.nil?
    def floor_items = floors.flat_map(&:counters).flat_map(&:items)
    def tm_count = floor_items.count { |item| item.tm? && item.price? }
    def stone_count = floor_items.count { |item| item.name.end_with?(" Stone") }
    def priciest = floor_items.filter_map(&:price).max
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
  # `note_key` is an optional locale key for a hand-authored caption on the card (e.g. the Mew
  # glitch warnings on the Cerulean Swimmer and Misty).
  Trainer = Data.define(:cls, :name, :reward, :team, :sprite, :where, :battle, :opp, :marker_key,
    :tick, :note_key) do
    def initialize(opp: nil, marker_key: nil, tick: nil, note_key: nil, **rest) = super
    def marker_key? = !marker_key.nil?
    def note_key? = !note_key.nil?
    # A boss (the rival, a Team Rocket duo) carries a battle face-off shot; those get their own
    # full-width feature row rather than a cell in the trainer grid.
    def feature? = battle&.map? == true
  end
  # An in-game trade: give one species, receive another with a fixed nickname. give/receive are
  # { dex:, name: }; house/inside are Shots (the building on the overworld, the NPC inside).
  Trade = Data.define(:give, :receive, :nick, :npc_key, :title_key, :where_key, :note_key, :house,
    :inside)

  Evolution = Data.define(:from, :to, :kind, :arg) do
    def level? = kind == :level
    def stone? = kind == :stone
    def trade? = kind == :trade
  end

  OakEntry = Data.define(:dex, :name, :qty, :why_key)
  OakExample = Data.define(:dex, :name, :how)
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
    :steps, :encounters, :trainers, :trades, :oak_queue, :gym, :gym_after, :gym_finale,
    :area_maps, :later, :trivia, :missable, :mart
  ) do
    def initialize(gym: nil, gym_after: nil, gym_finale: false, area_maps: [], later: [],
      trivia: nil, missable: nil, trades: [], mart: nil, **rest)
      super(gym: gym, gym_after: gym_after, gym_finale: gym_finale, area_maps: area_maps,
        later: later, trivia: trivia, missable: missable, trades: trades, mart: mart, **rest)
    end

    def mart? = !mart.nil?
    def area_maps? = area_maps.any?
    def later? = later.any?
    def trivia? = !trivia.nil?
    def missable_after?(step_n) = !missable.nil? && missable.after_step == step_n

    def dex_list = encounters.map(&:dex)
    def wild_encounters = encounters.select(&:wild?)
    def catchable_count = wild_encounters.size
    def badge? = !badge.nil?
    def gym? = !gym.nil?
    def gym_finale? = gym_finale
    def band_gym? = gym? && !gym_finale

    def dense_trainers? = trainers.size > DENSE_TRAINERS

    # steps that lead up to the gym, then the rest: rendered after the gym in this band, or
    # held back with the gym itself when it closes the whole leg
    def lead_steps = gym_after ? steps.first(gym_after) : steps
    def trailing_steps = gym_after ? steps.drop(gym_after) : []
    def after_steps = gym_finale ? [] : trailing_steps
    def finale_steps = gym_finale ? trailing_steps : []
  end

  Leg = Data.define(:slug, :order, :special, :locations, :lead_key) do
    def single? = locations.one?
    def from = locations.first.name
    def to = (finale || locations.last).name
    def catch_count = locations.sum(&:catchable_count)
    def dex_list = locations.flat_map(&:dex_list).uniq
    def gyms = locations.select(&:badge?)
    def finale = locations.find(&:gym_finale?)
    def oak_queue = locations.flat_map(&:oak_queue).uniq(&:dex)
  end

  Game = Data.define(:slug, :name, :region, :dex_goal, :oak_example, :locations, :legs, :best_catches) do
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

    def first_gym_location = locations.find(&:gym?)

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

  # The Mew glitch guide is a bespoke page, not a location: it carries curated, game-verified
  # structured content (trainer identities and parties, the level formula) alongside locale keys
  # for its prose. `tone` values name a card accent the stylesheet resolves.
  MewFact = Data.define(:label_key, :value_key, :tone)
  MewTldr = Data.define(:n, :title_key, :text_key, :phase)
  # A trainer to leave standing, identified by class + spot (no battle needed for the card).
  # `sprite` is a trainer-sprite basename (walkthrough/yellow/trainers/<sprite>.png); `shot` is the
  # generator's per-Trainer scene image key; `tag` is the map-band chip drawn over that shot.
  MewTrainer = Data.define(:name_key, :where_key, :role_key, :role_tone, :sprite, :tag, :shot)
  MewSleeper = Data.define(:dex, :name, :move_key)
  # One pack-list row: either a Pokémon (`dex` set) or a plain tile with a `glyph` like "x20".
  MewPackItem = Data.define(:dex, :glyph, :name_key, :note_key) do
    def initialize(dex: nil, glyph: nil, **rest) = super
    def pokemon? = !dex.nil?
  end
  MewStep = Data.define(:n, :title_key, :text_key, :tag_key, :tag_tone, :note_key, :note_label_key,
    :shot) do
    def initialize(tag_key: nil, tag_tone: nil, note_key: nil, note_label_key: nil, **rest) = super
    def tag? = !tag_key.nil?
    def note? = !note_key.nil?
  end
  MewPhase = Data.define(:label_key, :title_key, :meta_key, :tone, :steps)
  MewSecondStep = Data.define(:n, :title_key, :text_key)
  # One Trainer the Mew glitch needs left un-beaten. `map`/`marker` join to the very tick key the
  # annotated maps store under, so `progress_id` is the shared handle the map pin and this card
  # both toggle; `key` is that pin's letter on its map, `shot` an optional WHERE frame.
  MewSpare = Data.define(:id, :cls, :name_key, :role_key, :where_key, :tag, :map, :marker, :key, :shot) do
    def progress_id = "#{map}/#{marker}"
  end
  # One row of the level calculator. `kind` picks the recipe locale key; `n` fills its count.
  MewStage = Data.define(:stage, :level, :n, :kind, :label) do
    def default? = stage.zero?
  end
  MewGlitch = Data.define(:facts, :tldr, :untouched, :packlist, :sleepers, :phases, :second,
    :stages, :baseline, :vc_ot, :vc_tid)

  # Yellow's Pikachu carries a hidden friendship value (0-255, starts at 90); the Cerulean
  # Bulbasaur unlocks at 147. `values` is the game's per-band change [0-99, 100-199, 200-255],
  # taken verbatim from HappinessChangeTable in the disassembly.
  FriendshipRow = Data.define(:action_key, :values) do
    def gain? = values.first.positive?
  end
  PikachuFriendship = Data.define(:start, :threshold, :max, :rows)

  def self.games = { "yellow" => Yellow.game }

  def self.find(slug) = games[slug]

  def self.find!(slug)
    find(slug) || raise(ActiveRecord::RecordNotFound, "No walkthrough for game: #{slug}")
  end
end
