module Walkthrough
  BOULDER_ICON = "walkthrough/yellow/icons/boulder.png".freeze

  MAP_CATEGORIES = %w[trainer npc pokemon item hidden exit hole].freeze

  NON_TICKABLE = %w[exit npc hole].freeze

  LINKED_CATEGORIES = %w[exit hole].freeze

  DENSE_TRAINERS = 6

  ROUTE_HUES = 10

  METHOD_UNLOCK = {
    "OLD ROD" => 17,     # Vermilion City, the Fishing Guru
    "SUPER ROD" => 31,   # Route 12, the Super Rod house
    "GOOD ROD" => 35,    # Fuchsia City, the Good Rod house
    "SURF" => 36         # Safari Zone, HM03 in the Secret House
  }.freeze

  GIFT_SECTION = "GIFT"
  GAME_CORNER_METHOD = "GAME CORNER".freeze
  STATIC_METHOD = "STATIC".freeze

  SECTION_ICONS = {
    GIFT_SECTION => "walkthrough/items/poke-ball.png",
    "GRASS" => "walkthrough/yellow/icons/tall-grass.png",
    "CAVE" => "walkthrough/items/escape-rope.png",
    "FLOORS" => "walkthrough/items/town-map.png",
    "SAFARI" => "walkthrough/items/safari-ball.png",
    "SURF" => "walkthrough/items/tm-water.png",
    "OLD ROD" => "walkthrough/items/old-rod.png",
    "GOOD ROD" => "walkthrough/items/good-rod.png",
    "SUPER ROD" => "walkthrough/items/super-rod.png",
    "STATIC" => "walkthrough/items/poke-flute.png",
    "FOSSIL" => "walkthrough/items/dome-fossil.png",
    "GAME CORNER" => "walkthrough/items/coin-case.png"
  }.freeze

  class UnknownEncounterSection < StandardError; end

  EncounterPlace = Data.define(:floor, :kind, :rate, :min_level, :max_level) do
    KIND_BY_HOW = {
      "GRASS" => "grass", "CAVE" => "grass", "FLOORS" => "grass", "SAFARI" => "grass",
      "SURF" => "water", "OLD ROD" => "old_rod", "GOOD ROD" => "good_rod",
      "SUPER ROD" => "super_rod"
    }.freeze

    def surf? = kind == "water"
    def rod? = kind.end_with?("_rod")
    def method?(how) = KIND_BY_HOW[how] == kind
    def levels = min_level == max_level ? min_level.to_s : "#{min_level}–#{max_level}"
  end

  Encounter = Data.define(:dex, :name, :how, :rate, :level, :rarity, :tip_key, :evo_line,
    :from_key, :unlock_key, :unlock_icon, :needs_badge, :places, :at_map, :unlocked_from) do
    def initialize(from_key: nil, unlock_key: nil, unlock_icon: nil, needs_badge: nil, places: [], unlocked_from: 0, **rest) = super
    def gift? = %w[GIFT STARTER TRADE].include?(how)
    def purchased? = how == GAME_CORNER_METHOD
    def static? = how == STATIC_METHOD
    def wild? = !gift?
    def section = gift? ? GIFT_SECTION : how
    def badge_locked? = !needs_badge.nil?
    def open_after?(badges) = needs_badge.nil? || badges.include?(needs_badge)
    def from? = !from_key.nil?
    def unlock? = !unlock_key.nil?
    def places? = places.size > 1 || places.any?(&:floor)
    def best_place = places.max_by(&:rate)
  end

  EncounterSection = Data.define(:code, :icon, :encounters) do
    def key = code.parameterize
    def gift? = code == GIFT_SECTION
    def size = encounters.size
    def dex_list = encounters.map(&:dex).uniq
    def label_key = "walkthrough.ui.catchsec_#{key.tr('-', '_')}_label"
    def hint_key = "walkthrough.ui.catchsec_#{key.tr('-', '_')}_hint"
  end

  Item = Data.define(:name, :where_key, :sprite, :at, :tick, :key) do
    def initialize(at: nil, tick: nil, key: nil, **rest) = super
    def key? = !key.nil?
  end

  HiddenItem = Data.define(:name, :where_key, :image, :pin, :sprite, :at, :tick, :key) do
    def initialize(at: nil, tick: nil, key: nil, **rest) = super
    def key? = !key.nil?
  end
  LaterItem = Data.define(:name, :sprite, :kind, :need, :where_key, :after_key, :image, :pin,
    :key, :tick) do
    def initialize(key: nil, tick: nil, **rest) = super
    def image? = !image.nil?
    def key? = !key.nil?
  end
  TriviaCard = Data.define(:dex, :name, :tone, :rows)
  MarkedFact = Data.define(:key, :state, :mark)
  Trivia = Data.define(:anchor, :title_key, :intro_key, :note_key, :cards, :facts, :shot, :art,
    :note_icon, :tag_key, :warning, :pins, :marks) do
    def initialize(facts: [], art: nil, note_icon: nil, tag_key: nil, warning: nil, pins: {}, marks: {}, **rest) = super
    def art? = !art.nil?
    def note_icon? = !note_icon.nil?
    def tag? = !tag_key.nil?
    def warning? = !warning.nil?
  end

  TriviaWarning = Data.define(:title_key, :body_key, :specimen)
  TriviaSpecimen = Data.define(:dex, :name, :note_key)
  GrindMon = Data.define(:dex, :name, :tone, :rarity, :share, :levels, :level, :exp, :fill,
                         :type, :hp, :speed, :tips_key)

  GrindStep = Data.define(:n, :title_key, :body_key)
  GrindSpot = Data.define(:anchor, :after_map, :title_key, :intro_key, :art, :formula_key,
                          :mons, :note_icon, :lead_level, :steps, :warn_key) do
    def after?(area) = area&.name == after_map
  end

  Missable = Data.define(:anchor, :title_key, :body_key, :tip_key, :after_step)
  Shot = Data.define(:image, :label, :caption_key) do
    def initialize(caption_key: nil, **rest) = super
    def map? = !image.nil?
    def caption? = !caption_key.nil?
  end
  Gift = Data.define(:dex, :name, :level, :sold) do
    def sold? = sold
  end
  GymFacts = Data.define(:leader, :types, :badge, :tm, :quiz) do
    def initialize(quiz: [], **rest) = super
  end
  GiftItem = Data.define(:name, :qty) do
    def stack? = qty > 1
  end
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

  MartItem = Data.define(:name, :sprite, :price, :desc_key, :tm_no, :move, :mtype, :rec, :rec_key,
    :tick) do
    def initialize(price: nil, desc_key: nil, tm_no: nil, move: nil, mtype: nil, rec: false,
      rec_key: nil, tick: nil, **rest)
      super(price: price, desc_key: desc_key, tm_no: tm_no, move: move, mtype: mtype, rec: rec,
        rec_key: rec_key, tick: tick, **rest)
    end

    def tick? = !tick.nil?

    def price? = !price.nil?
    def desc? = !desc_key.nil?
    def tm? = !tm_no.nil?
    def rec? = rec
    def rec_key? = !rec_key.nil?
    def label = tm? ? "TM#{format('%02d', tm_no)} · #{move}" : name
  end

  MartCounter = Data.define(:title_key, :items) do
    def initialize(title_key: nil, **rest) = super
  end

  MartTrade = Data.define(:drink, :drink_sprite, :price, :tm_short, :tm_sprite, :move, :mtype,
    :note_key, :tick)

  Prize = Data.define(:name, :sprite, :level, :mtype, :coins, :note_key) do
    def note? = !note_key.nil?
    def mon? = !level.nil?
  end

  PrizeWindow = Data.define(:id, :prizes)
  PrizeRoom = Data.define(:windows, :piles) do
    COINS_PER_BUY = 50
    BUY_PRICE = 1000

    def coins_per_buy = COINS_PER_BUY
    def buy_price = BUY_PRICE
    def dearest = windows.flat_map(&:prizes).max_by(&:coins)
    def payout = (dearest.coins / COINS_PER_BUY.to_f).ceil * BUY_PRICE
  end

  DrinkBuy = Data.define(:qty, :name, :sprite, :cost)

  RoofTrades = Data.define(:shot, :trades, :buys, :total)

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

  Mart = Data.define(:slug, :count, :blurb_key, :buy_key, :counters, :floors, :roof) do
    def initialize(blurb_key: nil, buy_key: nil, counters: [], floors: [], roof: nil, **rest)
      super(blurb_key: blurb_key, buy_key: buy_key, counters: counters, floors: floors,
        roof: roof, **rest)
    end

    def roof? = !roof.nil?
    def multi? = floors.any?
    def blurb? = !blurb_key.nil?
    def buy? = !buy_key.nil?
    def floor_items = floors.flat_map(&:counters).flat_map(&:items)
    def tm_count = floor_items.count { |item| item.tm? && item.price? }
    def stone_count = floor_items.count { |item| item.name.end_with?(" Stone") }
    def priciest = floor_items.filter_map(&:price).max
  end

  MapMarker = Data.define(:id, :cat, :key, :name, :x, :y, :align, :lane, :glyph, :edge, :ref,
    :note, :place, :step) do
    def initialize(key: nil, glyph: nil, edge: nil, lane: 0, note: nil, place: nil, step: nil, **rest) = super
    def key? = !key.nil?
    def tickable? = !NON_TICKABLE.include?(cat)
    def glyph_or_key = glyph || key
    def note? = !note.nil?
    def place? = !place.nil?
    def step? = !step.nil?
  end

  AreaMap = Data.define(:image, :width, :height, :floor, :name, :markers, :title, :route,
    :route_kind, :boulders) do
    def initialize(name: "", markers: [], title: nil, route: [], route_kind: "ride", boulders: [], **rest) = super
    def route? = route.any?
    def route_legs
      route.each_with_index.map do |points, i|
        RouteLeg.new(points: points, n: i + 1, boulder: boulders[i])
      end
    end
    def caption = title || floor
    def captioned? = !caption.empty?
    def markers? = markers.any?
    def marker_counts = markers.group_by(&:cat).transform_values(&:size)
    def tickable_count = markers.count(&:tickable?)
    def markers_in(cat) = markers.select { |marker| marker.cat == cat }
    SPLIT_COLUMN_PX = 675

    def landscape?
      width * 3 >= height * 4 ||                                # a horizontal strip
        (width > height && width * 5 > SPLIT_COLUMN_PX * 4) ||  # the column cannot enlarge it
        width > SPLIT_COLUMN_PX                                 # the column cannot hold it
    end
  end

  RouteLeg = Data.define(:points, :n, :boulder) do
    def initialize(boulder: nil, **rest) = super
    def boulder? = !boulder.nil?
    def line = points.map { |x, y| "#{x},#{y}" }.join(" ")
    def tip = points.last
    def hue = (n - 1) % ROUTE_HUES + 1

    def heading
      to_x, to_y = tip
      from_x, from_y = points[-2] || tip
      (Math.atan2(to_y - from_y, to_x - from_x) * 180 / Math::PI).round(1)
    end
  end

  StepLink = Data.define(:leg, :anchor)

  DexSeen = Data.define(:num, :name, :species, :types, :height, :weight, :text, :art, :catch_key)

  StepMap = Data.define(:image, :width, :height, :box, :legs, :kind) do
    def initialize(kind: "ride", **rest) = super
    def view_box = box.join(" ")
  end

  Step = Data.define(:n, :title_key, :text_key, :items, :hidden, :shots, :link, :pins, :marks, :map,
    :dex_seen, :line, :step_map) do
    def initialize(shots: [], pins: {}, marks: {}, map: nil, dex_seen: nil, line: nil, step_map: nil, **rest) = super
    def line? = !line.nil?
    def step_map? = !step_map.nil?
    def strip? = shots.size > 1
    def items? = items.any?
    def hidden? = hidden.any?
    def shots? = shots.any?
    def link? = !link.nil?
    def marks? = marks.any?
    def map? = !map.nil?
    def dex_seen? = !dex_seen.nil?
  end

  Trainer = Data.define(:cls, :name, :reward, :team, :sprite, :where, :battle, :opp, :marker_key,
    :tick, :note_key, :note_link, :floor) do
    def initialize(opp: nil, marker_key: nil, tick: nil, note_key: nil, note_link: nil, floor: nil, **rest) = super
    def marker_key? = !marker_key.nil?
    def note_key? = !note_key.nil?
    def note_link? = !note_link.nil?
    def feature? = battle&.map? == true
  end
  Trade = Data.define(:give, :receive, :nick, :ot_name, :npc_key, :title_key, :where_key, :note_key,
    :house, :inside, :tick, :at_map) do
    def initialize(tick: nil, **rest) = super
  end

  Evolution = Data.define(:from, :to, :kind, :arg) do
    def level? = kind == :level
    def stone? = kind == :stone
    def trade? = kind == :trade
  end

  Window = Data.define(:number, :badge, :gym, :slugs) do
    def final? = badge.nil?
    def leader = gym&.leader&.name
    def gym_name = gym&.name
    def label = format("%02d", number)
    def covers?(slug) = slugs.include?(slug)
  end

  LaterStage = Data.define(:dex, :name, :kind, :args) do
    def catch? = kind == :catch
    def note_key = "walkthrough.ui.ld_later_#{kind}"
  end

  PlanEntry = Data.define(:dex, :name, :at, :stop_name, :qty, :covers, :chain, :fresh, :boxed,
    :done_at, :done_how, :how, :rate, :best, :why_key, :why_args, :later) do
    def catch_at = done_at || stop_name
    def later? = !later.nil?
    def fresh? = fresh
    def boxed? = boxed
    def best? = !best.nil?
    def rated? = !Gen1Guide.parse_rate(rate).nil?
    def queued? = fresh && qty.positive?
    def skipped? = fresh && qty.zero?
  end

  ChallengeNote = Data.define(:kind, :args)
  FamilyStage = Data.define(:dex, :name, :step_key, :step_args, :owed)
  Family = Data.define(:name, :stages) do
    def total = stages.size
  end

  OakTile = Data.define(:dex, :name, :via_key, :via_args)
  OakGroup = Data.define(:kind, :tiles, :note_key, :pick) do
    def initialize(pick: nil, **rest) = super(pick: pick, **rest)

    def any? = tiles.any?
    def required = pick || tiles.size
  end
  LockedEntry = Data.define(:dex, :name, :gate_key, :gate_args, :where_key, :where_args)

  PagePlan = Data.define(:window, :entries, :notes, :families, :groups, :earlier, :locked, :due) do
    def queue = entries.select(&:queued?)
    def bodies = queue.sum(&:qty)
    def skipped = entries.select(&:skipped?)
    def boxed = entries.reject(&:fresh?)
    def stages = families.sum(&:total)
    def due_count = due.size
    def queue_at(slug) = queue.select { |entry| entry.at == slug }
    def entry_for(dex) = entries.find { |entry| entry.dex == dex }
    def living? = queue.any? || entries.any?
    def oak? = groups.any?(&:any?) || earlier.any?
    def any? = living? || oak?
  end

  OakEntry = Data.define(:dex, :name, :qty, :why_key)
  OakExample = Data.define(:dex, :name, :how)
  BestCatch = Data.define(:dex, :slug, :place, :how, :rate, :tie, :alt_name, :alt_rate, :only,
    :armed_only) do
    def initialize(place: nil, how: nil, tie: false, alt_name: nil, alt_rate: nil, only: false, armed_only: false, **rest) = super
    def rate? = !rate.nil?
  end

  GymStep = Data.define(:n, :text_key, :shot, :answers) do
    def initialize(answers: [], **rest) = super
    def shot? = !shot.nil?
    def answers? = answers.any?
  end

  Gym = Data.define(
    :type, :name, :intro_key, :shot, :area, :badge, :badge_img, :tm, :puzzle, :trainers, :leader,
    :needs, :needs_key
  ) do
    def initialize(area: nil, needs: nil, needs_key: nil, **rest) = super
    def needs? = !needs.nil?
    def puzzle? = puzzle.any?
    def trainers? = trainers.any?
    def area? = !area.nil?
    def pins = area? ? area.markers_in("trainer") + area.markers_in("item") + puzzle_doors : []
    def puzzle_doors = area.markers_in("exit").then { |doors| doors.one? ? [] : doors }
  end

  Dojo = Data.define(:anchor, :map, :name, :type, :intro_key, :when_key, :prize_key, :shot, :area,
    :steps, :trainers, :leader, :note_key, :choice) do
    def initialize(area: nil, **rest) = super
    def pins = area.markers_in("trainer")
    def cards = trainers + [ leader ]
    def purse = cards.sum(&:reward)
  end

  DojoPick = Data.define(:side, :dex, :name, :level, :stats, :knows, :learns, :note_key)

  DojoStat = Data.define(:key, :value, :fill, :lead)

  DojoMove = Data.define(:name, :level)

  DojoChoice = Data.define(:anchor, :intro_key, :room_key, :rec_key, :picks) do
    def left = picks.first
    def right = picks.last
  end

  LeagueMember = Data.define(:key, :tone, :numeral, :numeral_right, :trainer) do
    def initialize(numeral_right: false, **rest) = super
    def tick = trainer.tick
    def ace?(index) = index == trainer.team.size - 1
  end

  ChampionTeam = Data.define(:key, :dex, :name, :team) do
    def ace?(index) = index == team.size - 1
  end

  LeagueChampion = Data.define(:trainer, :teams) do
    def tick = trainer.tick
  end

  League = Data.define(:copy_key, :brief, :members, :champion, :after) do
    def ticks = members.map(&:tick) << champion.tick
  end

  Location = Data.define(
    :slug, :kind, :name, :title, :order, :note_key, :intro_key, :badge,
    :steps, :encounters, :trainers, :trades, :oak_queue, :gym, :gym_after, :gym_finale,
    :area_maps, :later, :trivia, :missable, :mart, :grind, :second_visit, :dojo
  ) do
    def initialize(name:, title: nil, gym: nil, gym_after: nil, gym_finale: false, area_maps: [],
      later: [], trivia: nil, missable: nil, trades: [], mart: nil, grind: nil,
      second_visit: nil, dojo: nil, **rest)
      super(name: name, title: title || name, gym: gym, gym_after: gym_after,
        gym_finale: gym_finale, area_maps: area_maps,
        later: later, trivia: Array(trivia).compact, missable: missable, trades: trades, mart: mart,
        grind: grind, second_visit: second_visit, dojo: dojo, **rest)
    end

    def dojo? = !dojo.nil?
    def mart? = !mart.nil?
    def area_maps? = area_maps.any?
    def later? = later.any?
    def trivia? = trivia.any?
    def grind? = !grind.nil?
    def missable_after?(step_n) = !missable.nil? && missable.after_step == step_n

    def dex_list = encounters.select { |enc| enc.unlocked_from <= order }.map(&:dex)

    def dex_list_after(badges)
      encounters.select { |enc| enc.unlocked_from <= order && enc.open_after?(badges) }.map(&:dex)
    end
    def wild_encounters = encounters.select(&:wild?)
    def catchable_count = wild_encounters.size

    def encounter_sections = sections_for(encounters)

    def sections_for(list)
      grouped = list.group_by(&:section)
      missing = grouped.keys - SECTION_ICONS.keys
      raise UnknownEncounterSection, "#{slug}: no section for #{missing.join(', ')}" if missing.any?

      SECTION_ICONS.filter_map do |code, icon|
        found = grouped[code]
        EncounterSection.new(code: code, icon: icon, encounters: found) if found
      end
    end

    def encounters_on(map) = encounters.select { |enc| enc.at_map == map }
    def encounters_off(maps) = encounters.reject { |enc| maps.include?(enc.at_map) }
    def trades_on(map) = trades.select { |trade| trade.at_map == map }
    def trades_off(maps) = trades.reject { |trade| maps.include?(trade.at_map) }
    def badge? = !badge.nil?
    def gym? = !gym.nil?
    def gym_finale? = gym_finale
    def band_gym? = gym? && !gym_finale

    def gym_walk? = band_gym? && kind == "GYM"
    def gym_steps = gym_walk? ? lead_steps : []
    def band_steps = gym_walk? ? [] : lead_steps

    def dense_trainers? = trainers.size > DENSE_TRAINERS

    def step_groups
      return [] if steps.none?(&:map?)

      runs = steps.chunk_while { |before, after| before.map == after.map }
      runs.each_with_object([]) { |run, groups| absorb_run(groups, run) }
    end

    def absorb_run(groups, run)
      area = area_map_named(run.first.map)
      return groups << [ area, run ] if area || groups.empty?

      groups[-1] = [ groups.last.first, groups.last.last + run ]
    end

    def area_map_named(name) = area_maps.find { |area| area.name == name }

    def lead_steps = steps.first(gym_after || second_visit&.after || steps.size)
    def trailing_steps = gym_after ? steps.drop(gym_after) : []

    def second_visit? = !second_visit.nil?
    def second_visit_steps = second_visit ? steps.drop(second_visit.after) : []
    def after_steps = gym_finale ? [] : trailing_steps
    def finale_steps = gym_finale ? trailing_steps : []
  end

  SecondVisit = Data.define(:after, :lead_key)

  Leg = Data.define(:slug, :order, :special, :locations, :lead_key) do
    def single? = locations.one?
    def from = locations.first.title
    def to = (finale || locations.last).title
    def catch_count = locations.sum(&:catchable_count)
    def dex_list = locations.flat_map(&:dex_list).uniq
    def gyms = locations.select(&:badge?)
    def finale = locations.find(&:gym_finale?)
    def oak_queue = locations.flat_map(&:oak_queue).uniq(&:dex)
  end

  Game = Data.define(:slug, :name, :region, :dex_goal, :oak_example, :locations, :legs,
    :best_catches, :windows, :guide) do
    def key = guide::K
    def evolutions = guide.evolutions

    def image_prefix = "walkthrough/#{slug}"
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

    def stops = locations.map(&:order).max

    def first_gym_location = locations.find(&:gym?)

    def obtainable_upto_leg(current)
      idx = locations.index(current.locations.last)
      locations.first(idx + 1).flat_map(&:dex_list).uniq
    end

    def new_dex_for_leg(current)
      idx = locations.index(current.locations.first)
      current.dex_list - locations.first(idx).flat_map(&:dex_list)
    end

    def plan_for(current) = Challenge.plan(self, current)

    def covers(dex) = Challenge.covered_by(self, dex)

    def registerable_upto_leg(current) = Challenge.registerable(self, Challenge.leg_order(current).last.slug)

    private

    def neighbor_leg(current, delta)
      pos = legs.index(current) + delta
      return nil if pos.negative? || pos >= legs.size

      legs[pos]
    end
  end

  MewFact = Data.define(:label_key, :value_key, :tone)
  MewTldr = Data.define(:n, :title_key, :text_key, :phase)
  MewTrainer = Data.define(:name_key, :where_key, :role_key, :role_tone, :sprite, :tag, :shot)
  MewSleeper = Data.define(:dex, :name, :move_key)
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
  MewSpare = Data.define(:id, :cls, :name_key, :role_key, :where_key, :tag, :map, :marker, :key, :shot) do
    def progress_id = "#{map}/#{marker}"
  end
  MewStage = Data.define(:stage, :level, :n, :kind, :label) do
    def default? = stage.zero?
  end
  MewGlitch = Data.define(:facts, :tldr, :untouched, :packlist, :sleepers, :phases, :second,
    :stages, :baseline, :vc_ot, :vc_tid, :dex)

  FriendshipRow = Data.define(:action_key, :values) do
    def gain? = values.first.positive?
  end
  PikachuFriendship = Data.define(:start, :threshold, :max, :rows)

  CatchStep = Data.define(:n, :title_key, :text_key, :rows, :code_key) do
    def initialize(code_key: nil, **rest) = super
    def code? = !code_key.nil?
    def rows? = rows.any?
  end
  CatchRow = Data.define(:label_key, :value, :tone) do
    def initialize(label_key: nil, tone: nil, **rest) = super
    def labelled? = !label_key.nil?
  end
  CatchCalc = Data.define(:n, :text_key, :value, :tone)
  CatchItem = Data.define(:key, :sprite, :rate, :rate_note, :flee, :after_key, :tone)
  CatchFlee = Data.define(:label_key, :normal, :angry)
  CatchOdds = Data.define(:label_key, :value, :best)
  CatchTarget = Data.define(:dex, :name, :label_key, :odds, :note_key) do
    def note? = !note_key.nil?
  end
  CatchPanel = Data.define(:key, :sprites, :eyebrow_key, :title_key, :lead_key, :steps, :formula_key,
    :calc, :items, :flee, :cards) do
    def initialize(steps: [], calc: [], items: [], flee: [], cards: [], formula_key: nil, **rest) = super
    def formula? = !formula_key.nil?
  end
  CatchCard = Data.define(:key, :title_key, :text_key)
  SafariCatching = Data.define(:anchor, :panels, :targets, :cards, :verdict_key, :consolation_key,
    :sample)

  BadgeCard = Data.define(:no, :name, :image, :leader, :city, :kind, :effect_key, :level, :field) do
    def obey? = kind == "obey"
    def field? = !field.nil?
  end
  BadgeRule = Data.define(:no, :label_key, :title_key, :text_key)
  BadgeGuide = Data.define(:anchor, :cards, :rules)

  ExpShare = Data.define(:anchor, :sprite, :max_party, :party, :fighters, :verdicts, :legend,
    :trivia)
  ExpVerdict = Data.define(:tone, :text_key)
  ExpLegendText = Data.define(:row, :state, :text_key)
  ExpTrivia = Data.define(:tag_key, :title_key, :text_key)

  SurfPikachu = Data.define(:anchor, :art, :beach, :stadium, :sprite, :chips, :shots, :scores,
    :steps)
  SurfShot = Data.define(:key, :image, :tone)
  SurfScore = Data.define(:key, :value, :alt, :tone) do
    def alt? = !alt.nil?
  end
  SurfStadiumStep = Data.define(:key, :glyph, :tone)

  MansionDiary = Data.define(:anchor, :art, :card, :mon, :pages)
  DiaryPage = Data.define(:key, :tone)
  DiaryMon = Data.define(:dex, :name, :species, :sprite, :height, :weight)

  FossilWait = Data.define(:anchor, :count, :steps, :fossils, :facts)
  FossilStep = Data.define(:n, :title_key, :text_key)
  FossilCard = Data.define(:dex, :name, :item, :art, :sprite, :height, :weight)

  TrueEnding = Data.define(:anchor, :copy_key, :tiles, :tags, :art, :mew, :shot, :league_leg)
  EndingTag = Data.define(:dex, :key, :tone)

  GUIDES = [ Yellow, YellowLegacy ].freeze

  def self.games
    @games ||= GUIDES.to_h { |guide| [ guide::SLUG, guide.game ] }.freeze
  end

  def self.find(slug) = games[slug]

  def self.trades_for(slug)
    @trades_for ||= {}
    @trades_for[slug] ||= find!(slug).locations.flat_map(&:trades).index_by(&:tick).freeze
  end

  def self.find!(slug)
    find(slug) || raise(ActiveRecord::RecordNotFound, "No walkthrough for game: #{slug}")
  end
end
