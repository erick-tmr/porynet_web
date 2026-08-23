module Walkthrough
  # Marker categories in the order the map legend lists them.
  MAP_CATEGORIES = %w[trainer npc item hidden exit].freeze

  # Categories that are signposts, not chores: they raise a hint but never tick off.
  NON_TICKABLE = %w[exit npc].freeze

  DENSE_TRAINERS = 6

  # A rod or Surf encounter is only a catch once you hold the tool, and the guide hands each one
  # over at a fixed stop. Keyed by method, valued by that stop's `order`, so a fishing card on an
  # early route counts toward the dex from the stop that arms you rather than from the route the
  # water happens to be on. Without this the Oak deadline would owe you a Magikarp before Brock,
  # four legs before the Old Rod exists.
  METHOD_UNLOCK = {
    "OLD ROD" => 17,     # Vermilion City, the Fishing Guru
    "SUPER ROD" => 31,   # Route 12, the Super Rod house
    "GOOD ROD" => 35,    # Fuchsia City, the Good Rod house
    "SURF" => 36         # Safari Zone, HM03 in the Secret House
  }.freeze

  GIFT_SECTION = "GIFT"
  GAME_CORNER_METHOD = "GAME CORNER".freeze

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

  # `from_key`/`unlock_key` are optional locale keys for a gift Pokémon: who hands it over and any
  # condition to unlock it (Bulbasaur needs Pikachu's friendship at 147+, Squirtle the Thunder
  # Badge). `unlock_icon` is the R2 image that condition shows (a Pikachu, a badge).
  # One map's share of a species inside a location: which floor, which method finds it there, and
  # the real slot-weighted rate and level band the game gives that pairing. A floor can carry
  # several of these at once, since Seafoam B3F has cave grass, Surf water and a Super Rod table
  # that disagree about who lives there.
  EncounterPlace = Data.define(:floor, :kind, :rate, :min_level, :max_level) do
    # The card's method tag (hand-authored, an editorial choice) mapped onto the game table it is
    # really read from. The cave, floor and Safari tags all read the same "grass" table.
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
    :from_key, :unlock_key, :unlock_icon, :needs_badge, :places, :at_map) do
    def initialize(from_key: nil, unlock_key: nil, unlock_icon: nil, needs_badge: nil, places: [], **rest) = super
    def gift? = %w[GIFT STARTER TRADE].include?(how)
    # Bought over a counter rather than hunted, so what the card carries where a rate would go is
    # a price in coins, and the counter restocks forever.
    def purchased? = how == GAME_CORNER_METHOD
    def wild? = !gift?
    def section = gift? ? GIFT_SECTION : how
    # The earliest stop whose `order` can register this species: everything walked into is open
    # from the start, a rod or Surf card only once that tool is in the bag.
    def unlocked_from = METHOD_UNLOCK.fetch(how, 0)
    # A gift the game itself locks behind a badge (`wBeatGymFlags`), so it cannot be registered
    # until that gym is beaten. Nil for everything you can just walk up to.
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

  # `key` is the letter this thing's pin wears on the location's map, so the card can tell the
  # reader exactly which marker to hunt for. Nil when no single pin matches.
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
  # `after_map` pins the block to one of a stop's maps, for a page that draws its maps one at a
  # time: the Diglett's Cave grinding note belongs under the cave, not at the end of a walk that
  # finishes four maps away. Left unset it renders where it always has, below the steps.
  Trivia = Data.define(:anchor, :title_key, :intro_key, :note_key, :cards, :shot, :art, :note_icon,
    :tag_key, :warning, :pins, :marks) do
    def initialize(art: nil, note_icon: nil, tag_key: nil, warning: nil, pins: {}, marks: {}, **rest) = super
    def art? = !art.nil?
    def note_icon? = !note_icon.nil?
    # A section that is about one particular thing says so in its eyebrow ("TRIVIA · NAME RATER"),
    # because a page can carry more than one and "TRIVIA" alone stops telling them apart.
    def tag? = !tag_key.nil?
    def warning? = !warning.nil?
  end

  # The one rule a trivia section exists to warn about, and the single specimen in this save it
  # bites on: the Mr. Mime you traded for cannot be renamed, and here is its name, struck out.
  TriviaWarning = Data.define(:title_key, :body_key, :specimen)
  TriviaSpecimen = Data.define(:dex, :name, :note_key)
  # One species worth farming at a grinding spot, and what the game pays for it. `exp` is Gen 1's
  # own arithmetic, base experience times level over seven, so the figure on the card is the one
  # the battle really awards; `fill` is that against the best on offer here, which is what the bar
  # under it draws. Everything but the tips comes out of the game (tools/maps/dex.py).
  GrindMon = Data.define(:dex, :name, :tone, :rarity, :share, :levels, :level, :exp, :fill,
                         :type, :hp, :speed, :tips_key)

  # A place worth stopping at to level up: what lives there, what each one pays, and the Repel
  # trick that filters the cheap one out. `lead_level` is one above the top level the common
  # species reaches, which is exactly what Repel needs to leave only the rare one.
  GrindStep = Data.define(:n, :title_key, :body_key)
  GrindSpot = Data.define(:anchor, :after_map, :title_key, :intro_key, :art, :formula_key,
                          :mons, :note_icon, :lead_level, :steps, :warn_key) do
    def after?(area) = area&.name == after_map
  end

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

  # A labelled group of items on a shop counter. A plain city Mart has a single unlabelled counter;
  # a Celadon floor can split its stock across several (an item counter and a TM counter).
  MartCounter = Data.define(:title_key, :items) do
    def initialize(title_key: nil, **rest) = super
  end

  # A Celadon rooftop drink the thirsty girl swaps for a TM.
  MartTrade = Data.define(:drink, :drink_sprite, :price, :tm_short, :tm_sprite, :move, :mtype,
    :note_key)

  # One prize on a Game Corner counter: a species with the level it comes at, or a TM.
  Prize = Data.define(:name, :sprite, :level, :mtype, :coins, :note_key) do
    def note? = !note_key.nil?
    def mon? = !level.nil?
  end

  # One of the three prize counters, and the section that draws all of them.
  PrizeWindow = Data.define(:id, :prizes)
  PrizeRoom = Data.define(:windows, :piles) do
    # The counter sells coins in one size only: 50 for 1000 yen (text/GameCorner.asm).
    COINS_PER_BUY = 50
    BUY_PRICE = 1000

    def coins_per_buy = COINS_PER_BUY
    def buy_price = BUY_PRICE
    def dearest = windows.flat_map(&:prizes).max_by(&:coins)
    def payout = (dearest.coins / COINS_PER_BUY.to_f).ceil * BUY_PRICE
  end

  # One line of the rooftop shopping list: how many of a drink to buy, and what that costs.
  DrinkBuy = Data.define(:qty, :name, :sprite, :cost)

  # The rooftop trade section: where the girl stands, what she pays, and the bag you need first.
  RoofTrades = Data.define(:shot, :trades, :buys, :total)

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

  # One clickable point on an area map, read from the game data. `x`/`y` are percentages of the
  # rendered PNG; `ref` joins back to the game fact (OPP_CLASS:party, an item const, a map const).
  # An exit also carries the `place` its door leads to, when the game states anything about it.
  # `step` is the number of the step that collects this marker, so the pin can offer a way back
  # into the instructions that explain it. Nil for anything no step points at.
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

  # A map says which slice of the location it draws: `floor` for a dungeon's own floors, and
  # `title` for a map a stop borrows from another location, since the page is named after the stop
  # and a borrowed map has to name the place it really draws.
  AreaMap = Data.define(:image, :width, :height, :floor, :name, :markers, :title) do
    def initialize(name: "", markers: [], title: nil, **rest) = super
    def caption = title || floor
    def captioned? = !caption.empty?
    def markers? = markers.any?
    def marker_counts = markers.group_by(&:cat).transform_values(&:size)
    def tickable_count = markers.count(&:tickable?)
    def markers_in(cat) = markers.select { |marker| marker.cat == cat }
    # A map half-again wider than it is tall reads as a horizontal strip, and so does one simply
    # too wide for the column the split template would give it: the map shares that row with the
    # legend at 1.55fr of 2.55, which is about 675px with the page at its widest, and a picture
    # wider than that can only be shown there by scrolling a frame narrower than itself. Either
    # way it takes the full-width landscape template, map on top and legend spread beneath.
    SPLIT_COLUMN_PX = 675

    def landscape? = width * 2 >= height * 3 || width > SPLIT_COLUMN_PX
  end

  StepLink = Data.define(:leg, :anchor)

  # `pins` names the map markers this step's prose points at, as { token => "map-name/marker-id" }.
  # The copy interpolates the token (`%{center}`) and the view fills in the letter that pin wears
  # today. Authored as ids, never as letters: a letter is the marker's position in its map's run, so
  # one new item ball would shift every letter after it and silently re-point the prose. `marks` is
  # the resolved { token => letter } the view actually interpolates.
  # A Pokémon a step registers in the dex without catching it: an NPC shows it to you and the
  # entry fills in as seen. Everything but `catch_key` is the game's own dex screen, generated
  # from the disassembly (tools/maps/dex.py), so the card cannot drift from what the game prints.
  # `catch_key` is the locale line telling the reader where the catch itself happens.
  DexSeen = Data.define(:num, :name, :species, :types, :height, :weight, :text, :art, :catch_key)

  Step = Data.define(:n, :title_key, :text_key, :items, :hidden, :shot, :link, :pins, :marks, :map,
    :dex_seen) do
    def initialize(pins: {}, marks: {}, map: nil, dex_seen: nil, **rest) = super
    def items? = items.any?
    def hidden? = hidden.any?
    def shot? = !shot.nil?
    def link? = !link.nil?
    def marks? = marks.any?
    def map? = !map.nil?
    def dex_seen? = !dex_seen.nil?
  end

  # team: [{dex:,name:,lvl:}]; where/battle: Shot or nil. `opp` is the "OPP_CLASS:party" pair from
  # the map object, which resolves `marker_key` so the card and its pin show the same letter.
  # `note_key` is an optional locale key for a hand-authored caption on the card (e.g. the Mew
  # glitch warnings on the Cerulean Swimmer and Misty).
  Trainer = Data.define(:cls, :name, :reward, :team, :sprite, :where, :battle, :opp, :marker_key,
    :tick, :note_key, :floor) do
    def initialize(opp: nil, marker_key: nil, tick: nil, note_key: nil, floor: nil, **rest) = super
    def marker_key? = !marker_key.nil?
    def note_key? = !note_key.nil?
    # A boss (the rival, a Team Rocket duo) carries a battle face-off shot; those get their own
    # full-width feature row rather than a cell in the trainer grid.
    def feature? = battle&.map? == true
  end
  # An in-game trade: give one species, receive another with a fixed nickname. give/receive are
  # { dex:, name: }; house/inside are Shots (the building on the overworld, the NPC inside). A
  # trade shown on two stops (the one that flags it, the one that walks to it) carries the tick id
  # of the first, so trading once ticks it on both.
  Trade = Data.define(:give, :receive, :nick, :npc_key, :title_key, :where_key, :note_key, :house,
    :inside, :tick, :at_map) do
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

  # The stage directly above a queued species, and how the plan means to fill it: caught on its own
  # odds, grown from a spare body taken here, or out of reach on one cartridge. This is what makes
  # a quota legible on the card, so `kind` names the line to print and `args` fills its blanks.
  LaterStage = Data.define(:dex, :name, :kind, :args) do
    def catch? = kind == :catch
    def note_key = "walkthrough.ui.ld_later_#{kind}"
  end

  PlanEntry = Data.define(:dex, :name, :at, :stop_name, :qty, :covers, :chain, :fresh, :boxed,
    :done_at, :how, :rate, :best, :why_key, :why_args, :later) do
    def later? = !later.nil?
    def fresh? = fresh
    def boxed? = boxed
    def best? = !best.nil?
    def rated? = !Yellow.parse_rate(rate).nil?
    def queued? = fresh && qty.positive?
    def skipped? = fresh && qty.zero?
  end

  ChallengeNote = Data.define(:kind, :args)
  FamilyStage = Data.define(:dex, :name, :step_key, :step_args, :owed)
  Family = Data.define(:name, :stages) do
    def total = stages.size
  end

  OakTile = Data.define(:dex, :name, :via_key, :via_args)
  # `pick` is how many of the group's tiles a run can actually register, when that is fewer than
  # the tiles shown: three Eevee stones are three species, but one Eevee only ever becomes one.
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
    def living? = queue.any?
    def oak? = groups.any?(&:any?) || earlier.any?
    def any? = living? || oak?
  end

  OakEntry = Data.define(:dex, :name, :qty, :why_key)
  OakExample = Data.define(:dex, :name, :how)
  BestCatch = Data.define(:dex, :slug, :rate, :tie, :alt_name, :alt_rate, :only, :armed_only) do
    def initialize(tie: false, alt_name: nil, alt_rate: nil, only: false, armed_only: false, **rest) = super
    def rate? = !rate.nil?
  end

  GymStep = Data.define(:n, :text_key, :shot) do
    def shot? = !shot.nil?
  end

  Gym = Data.define(
    :type, :name, :intro_key, :shot, :area, :badge, :badge_img, :tm, :puzzle, :trainers, :leader
  ) do
    def initialize(area: nil, **rest) = super
    def puzzle? = puzzle.any?
    def trainers? = trainers.any?
    def area? = !area.nil?
    def pins = area? ? area.markers_in("trainer") : []
  end

  # `name` is the place the game knows, and it stays on everything anchored to that place: the map
  # titlebar, the catch cards, the challenge planner's "do at" badge. `title` is what the guide
  # calls the stop, which parts company with the name when a stop walks well past its own map
  # (Diglett's Cave, whose steps carry on through Route 2 into Viridian). Defaults to the name.
  Location = Data.define(
    :slug, :kind, :name, :title, :order, :note_key, :intro_key, :badge,
    :steps, :encounters, :trainers, :trades, :oak_queue, :gym, :gym_after, :gym_finale,
    :area_maps, :later, :trivia, :missable, :mart, :grind
  ) do
    def initialize(name:, title: nil, gym: nil, gym_after: nil, gym_finale: false, area_maps: [],
      later: [], trivia: nil, missable: nil, trades: [], mart: nil, grind: nil, **rest)
      super(name: name, title: title || name, gym: gym, gym_after: gym_after,
        gym_finale: gym_finale, area_maps: area_maps,
        later: later, trivia: trivia, missable: missable, trades: trades, mart: mart,
        grind: grind, **rest)
    end

    def mart? = !mart.nil?
    def area_maps? = area_maps.any?
    def later? = later.any?
    def trivia? = !trivia.nil?
    def grind? = !grind.nil?
    def missable_after?(step_n) = !missable.nil? && missable.after_step == step_n

    # What this stop can actually add to the dex when you walk it. The cards still list every
    # species that lives here; this is the subset you are equipped to catch on arrival.
    def dex_list = encounters.select { |enc| enc.unlocked_from <= order }.map(&:dex)

    # The same, minus anything the game locks behind a badge you are not holding yet. Oak's
    # deadline reads this one: a gift a gym unlocks cannot stand registered before that gym.
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

    # A stop that borrows other places' maps draws them one at a time, and what lives on a map
    # belongs under it: the Diglett cards under the cave, the Mr. Mime trade under Route 2, rather
    # than both piled at the end of a walk that finishes four maps away. Anything naming a map the
    # page does not draw stays where it always was, below the steps.
    def encounters_on(map) = encounters.select { |enc| enc.at_map == map }
    def encounters_off(maps) = encounters.reject { |enc| maps.include?(enc.at_map) }
    def trades_on(map) = trades.select { |trade| trade.at_map == map }
    def trades_off(maps) = trades.reject { |trade| maps.include?(trade.at_map) }
    def badge? = !badge.nil?
    def gym? = !gym.nil?
    def gym_finale? = gym_finale
    def band_gym? = gym? && !gym_finale

    def dense_trainers? = trainers.size > DENSE_TRAINERS

    # A stop that walks off its own map (the Cut detour crosses four of them) reads as one wall of
    # steps over one pile of maps, and the reader has to work out which map any given step is on.
    # When its steps name their map, the page draws each map with only the steps taken on it. The
    # groups come out in the order the steps run, so the maps follow the walk rather than the
    # manifest, and a step naming no map (the sign-off that leaves for the next leg) trails the
    # last group. A stop whose steps carry no map at all returns nothing and renders as one block.
    def step_groups
      return [] if steps.none?(&:map?)

      runs = steps.chunk_while { |before, after| before.map == after.map }
      runs.each_with_object([]) { |run, groups| absorb_run(groups, run) }
    end

    # A run of steps naming no map (the sign-off that leaves for the next leg) has no map to draw
    # above it, so it joins the block before rather than opening a bare one. The rail down the left
    # of the steps runs first-child to last-child inside one block, so an orphan block would break
    # the line between two consecutive steps.
    def absorb_run(groups, run)
      area = area_map_named(run.first.map)
      return groups << [ area, run ] if area || groups.empty?

      groups[-1] = [ groups.last.first, groups.last.last + run ]
    end

    def area_map_named(name) = area_maps.find { |area| area.name == name }

    # steps that lead up to the gym, then the rest: rendered after the gym in this band, or
    # held back with the gym itself when it closes the whole leg
    def lead_steps = gym_after ? steps.first(gym_after) : steps
    def trailing_steps = gym_after ? steps.drop(gym_after) : []
    def after_steps = gym_finale ? [] : trailing_steps
    def finale_steps = gym_finale ? trailing_steps : []
  end

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
    :best_catches, :windows) do
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

    def plan_for(current) = Challenge.plan(self, current)

    # Which stages one caught body of this species covers. A fact about the whole run, not about
    # any one stop, so a card can count bodies whether or not the page it sits on queues it.
    def covers(dex) = Challenge.covered_by(self, dex)

    def registerable_upto_leg(current) = Challenge.registerable(self, Challenge.leg_order(current).last.slug)

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

  # What a Gym Badge does once it is in the case. `kind` is "boost" (an in-battle stat lift for the
  # whole party) or "obey" (the level a traded Pokémon obeys up to), `level` fills the obedience
  # copy, and `field` is the HM the badge switches on outside battle, nil for the last three.
  BadgeCard = Data.define(:no, :name, :image, :leader, :city, :kind, :effect_key, :level, :field) do
    def obey? = kind == "obey"
    def field? = !field.nil?
  end
  BadgeRule = Data.define(:no, :label_key, :title_key, :text_key)
  BadgeGuide = Data.define(:anchor, :cards, :rules)

  def self.games = { "yellow" => Yellow.game }

  def self.find(slug) = games[slug]

  def self.find!(slug)
    find(slug) || raise(ActiveRecord::RecordNotFound, "No walkthrough for game: #{slug}")
  end
end
