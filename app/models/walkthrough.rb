module Walkthrough
  # Marker categories in the order the map legend lists them.
  # The Strength boulder, generated on its own (tools/maps/icons.py) so a step's map can draw one
  # where the game has not placed one yet.
  BOULDER_ICON = "walkthrough/yellow/icons/boulder.png".freeze

  MAP_CATEGORIES = %w[trainer npc pokemon item hidden exit hole].freeze

  # Categories that are signposts, not chores: they raise a hint but never tick off.
  NON_TICKABLE = %w[exit npc hole].freeze

  # Categories whose key is shared by the several maps that show one thing: a staircase wears the
  # same letter on both floors it joins, and so do the two ends of a hole. Everything else numbers
  # per map, so an H1 on two floors is two different hidden items that happen to share a letter.
  # This is what tells `map-jump` whether two pins wearing one key are one pin seen twice.
  LINKED_CATEGORIES = %w[exit hole].freeze

  DENSE_TRAINERS = 6

  # Colours a drawn route cycles through, one per leg. Enough of them that the longest floor never
  # reuses one (Viridian Gym's ten legs are the most any floor asks for), because a step draws its
  # own leg on its own copy of the map and the two have to agree about which line is which. The
  # hexes are in walkthrough-map.css; this is only how many there are.
  ROUTE_HUES = 10

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
    # One sprite on the map, one battle, no respawn: the body is certain rather than rolled for,
    # which is a different kind of catch from a percentage in the grass.
    def static? = how == STATIC_METHOD
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
  # `quiz` is the answer key for a gym whose doors ask one, in door order; empty for every gym but
  # Cinnabar's.
  GymFacts = Data.define(:leader, :types, :badge, :tm, :quiz) do
    def initialize(quiz: [], **rest) = super
  end
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
  #
  # `route` is the way round an arrow-tile floor, one leg per stretch between the things the walk
  # collects, each a list of [x, y] points in the image's own pixels. Only the floors where the
  # game states how you move carry one (tools/maps/spinners.py); everywhere else it is empty and
  # nothing is drawn. `route_kind` says what the line is a picture of: a "ride" the arrows take the
  # hero on, or a "push", the way a boulder goes when it is shoved (tools/maps/boulders.py). The
  # two are drawn identically and captioned apart, because following one is not doing the other.
  #
  # `boulders` is the cell each push starts from, one per leg. The map itself does not draw them:
  # the game ships every boulder below Seafoam 1F hidden until the one above it falls, so a floor
  # with one baked in would claim a boulder that is not there. A step that pushes one draws it
  # over its own crop instead, which is the only place the reader is being told to move it.
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
    # A map half-again wider than it is tall reads as a horizontal strip, and so does one simply
    # too wide for the column the split template would give it: the map shares that row with the
    # legend at 1.55fr of 2.55, which is about 675px with the page at its widest, and a picture
    # wider than that can only be shown there by scrolling a frame narrower than itself. Either
    # way it takes the full-width landscape template, map on top and legend spread beneath.
    #
    # A third again, rather than half again: Silph Co's upper floors are 416x288, wide rooms that
    # the split column shrinks to a stamp while its legend sits half empty beside them. Its 10F and
    # 11F are the other shape (256x288 and square), and those still read better next to their
    # legend, which is where the line sits.
    #
    # The middle rule is about size rather than shape. A town map is 640x576, which is not a strip
    # and does fit the column, but only just: it draws there at barely 1x, the size its labels
    # crowd worst at, while full width lets it reach 2.5x and the names come apart. So a map wider
    # than it is tall that the column cannot enlarge by a quarter goes full width too. Tall maps
    # are left out however wide, because the landscape template would strand their legend under a
    # column of picture.
    SPLIT_COLUMN_PX = 675

    def landscape?
      width * 3 >= height * 4 ||                                # a horizontal strip
        (width > height && width * 5 > SPLIT_COLUMN_PX * 4) ||  # the column cannot enlarge it
        width > SPLIT_COLUMN_PX                                 # the column cannot hold it
    end
  end

  # One stretch of a drawn route. `n` is which leg it is, counting from 1, and `hue` cycles a small
  # palette off it: two rides through the same maze cross each other often, and one colour for the
  # lot reads as a scribble.
  RouteLeg = Data.define(:points, :n, :boulder) do
    def initialize(boulder: nil, **rest) = super
    def boulder? = !boulder.nil?
    def line = points.map { |x, y| "#{x},#{y}" }.join(" ")
    def tip = points.last
    def hue = (n - 1) % ROUTE_HUES + 1

    # Which way the leg's last step is heading, in degrees, so the arrowhead on its tip points the
    # way the hero was going. A leg of one cell has no last step and simply points east.
    def heading
      to_x, to_y = tip
      from_x, from_y = points[-2] || tip
      (Math.atan2(to_y - from_y, to_x - from_x) * 180 / Math::PI).round(1)
    end
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

  # A step's own copy of the floor it is on, cropped to the stretch of route it walks: the same
  # image the area map draws, an SVG viewBox over the part that matters, and the legs to draw on
  # it. The overview at the top of the page shows the floor; this shows the reader where they are.
  StepMap = Data.define(:image, :width, :height, :box, :legs, :kind) do
    def initialize(kind: "ride", **rest) = super
    def view_box = box.join(" ")
  end

  Step = Data.define(:n, :title_key, :text_key, :items, :hidden, :shots, :link, :pins, :marks, :map,
    :dex_seen, :line, :step_map) do
    def initialize(shots: [], pins: {}, marks: {}, map: nil, dex_seen: nil, line: nil, step_map: nil, **rest) = super
    def line? = !line.nil?
    def step_map? = !step_map.nil?
    def items? = items.any?
    def hidden? = hidden.any?
    def shots? = shots.any?
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
    :tick, :note_key, :note_link, :floor) do
    def initialize(opp: nil, marker_key: nil, tick: nil, note_key: nil, note_link: nil, floor: nil, **rest) = super
    def marker_key? = !marker_key.nil?
    def note_key? = !note_key.nil?
    # A note that points at something explained elsewhere in the guide, as the leg and anchor to
    # link to: Blue's last team ends on whichever Eeveelution his Eevee became, and the recipe for
    # that is a trivia section back on leg 1.
    def note_link? = !note_link.nil?
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
    # The stop the plan wants this body caught at. A card shown away from that stop names it, so a
    # reader who finds a species in the grass in front of them is told where to get it instead of
    # just being told not to bother here. `done_at` carries it when the home is off this leg
    # entirely; when the home is on this leg but another page, `stop_name` is already that page.
    def catch_at = done_at || stop_name
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
    # A leg with catchable species but an empty queue still gets the section: every one of them is
    # better caught later, and "nothing here is worth a box slot" is the answer a living-dex reader
    # came for. A leg with nothing catchable at all (the S.S. Anne, Viridian's gym) has no question
    # to answer and stays quiet.
    def living? = queue.any? || entries.any?
    def oak? = groups.any?(&:any?) || earlier.any?
    def any? = living? || oak?
  end

  OakEntry = Data.define(:dex, :name, :qty, :why_key)
  OakExample = Data.define(:dex, :name, :how)
  BestCatch = Data.define(:dex, :slug, :rate, :tie, :alt_name, :alt_rate, :only, :armed_only) do
    def initialize(tie: false, alt_name: nil, alt_rate: nil, only: false, armed_only: false, **rest) = super
    def rate? = !rate.nil?
  end

  # `answers` is a quiz door's answer key, one "yes"/"no" per door in door order. Cinnabar is the
  # only gym that asks: its six locked doors each pose a yes-or-no question, and the answers are
  # read out of the game rather than typed, because the byte the doors carry is the truth of the
  # question and not the answer to it. Saying which is the whole of the step, so it is a row of
  # numbered chips rather than a clause the reader has to count along.
  GymStep = Data.define(:n, :text_key, :shot, :answers) do
    def initialize(answers: [], **rest) = super
    def shot? = !shot.nil?
    def answers? = answers.any?
  end

  # `needs` is the HM a floor cannot be finished without, as the game spells it, and `needs_key`
  # the line saying what is behind it. A gym whose leader sits past a barrier has to say so before
  # the reader walks in with the wrong party, not after.
  Gym = Data.define(
    :type, :name, :intro_key, :shot, :area, :badge, :badge_img, :tm, :puzzle, :trainers, :leader,
    :needs, :needs_key
  ) do
    def initialize(area: nil, needs: nil, needs_key: nil, **rest) = super
    def needs? = !needs.nil?
    def puzzle? = puzzle.any?
    def trainers? = trainers.any?
    def area? = !area.nil?
    # Trainers and any ball on the floor, plus the doorways when the floor has more than one: a gym
    # with a single front door needs no pin for the way it came in, but Saffron's is nine sealed
    # rooms and thirty warp pads, and the pin on a pad is the only thing that says which room it
    # throws you into. Viridian is the one gym with an item on its floor, and its step says to pick
    # it up, so its letter has to be somewhere the reader can find.
    def pins = area? ? area.markers_in("trainer") + area.markers_in("item") + puzzle_doors : []
    def puzzle_doors = area.markers_in("exit").then { |doors| doors.one? ? [] : doors }
  end

  # A hall that fights like a gym and pays like one, without a badge at the end of it: Saffron's
  # Fighting Dojo. It renders in the gym's own frame and carries the same shape (intro, how it
  # runs, students, the one at the back), with the badge slot swapped for the prize. `map` is the
  # game map its roster comes off, which is what routes those trainers here instead of onto the
  # city page they share a stop with.
  Dojo = Data.define(:anchor, :map, :name, :type, :intro_key, :when_key, :prize_key, :shot, :area,
    :steps, :trainers, :leader, :note_key, :choice) do
    # `area` is filled in once the stop's maps are read, and the dojo's floor is always one of
    # them, so nothing asks whether it has one.
    def initialize(area: nil, **rest) = super
    def pins = area.markers_in("trainer")
    def cards = trainers + [ leader ]
    def purse = cards.sum(&:reward)
  end

  # One of the two Poké Balls behind the Karate Master, and the case for taking it. `stats` are the
  # four the choice actually turns on, `knows` what it arrives holding and `learns` what it picks
  # up after. Picking one is a catch, so the card ticks against the species itself: the same tick
  # the catch card below it carries, and the one the living dex counts.
  DojoPick = Data.define(:side, :dex, :name, :level, :stats, :knows, :learns, :note_key)

  # `lead` is true for the stat this one of the pair wins, which is the only thing the bar beside
  # the number is for. `fill` is its share of the better of the two, in the fives a class can carry.
  DojoStat = Data.define(:key, :value, :fill, :lead)

  DojoMove = Data.define(:name, :level)

  DojoChoice = Data.define(:anchor, :intro_key, :room_key, :rec_key, :picks) do
    def left = picks.first
    def right = picks.last
  end

  # `name` is the place the game knows, and it stays on everything anchored to that place: the map
  # titlebar, the catch cards, the challenge planner's "do at" badge. `title` is what the guide
  # calls the stop, which parts company with the name when a stop walks well past its own map
  # (Diglett's Cave, whose steps carry on through Route 2 into Viridian). Defaults to the name.
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
        later: later, trivia: trivia, missable: missable, trades: trades, mart: mart,
        grind: grind, second_visit: second_visit, dojo: dojo, **rest)
    end

    def dojo? = !dojo.nil?
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

    # A stop that *is* a gym: its page is the one room, so the walk up to the leader belongs inside
    # the gym block with the floor it is walked on, not in a section of its own above it. Every
    # other gym is a room off a city, and the steps above it are the city's.
    def gym_walk? = band_gym? && kind == "GYM"
    def gym_steps = gym_walk? ? lead_steps : []
    def band_steps = gym_walk? ? [] : lead_steps

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
    def lead_steps = steps.first(gym_after || second_visit&.after || steps.size)
    def trailing_steps = gym_after ? steps.drop(gym_after) : []

    # A stop the guide walks twice, in one numbered sequence split across two headings. The Safari
    # Zone turns you out when its step clock runs down and holds one prize behind an HM the badge
    # two stops later unlocks, so its leftovers are a return trip rather than a footnote:
    # everything past `second_visit.after` is that trip, and the numbers run on through it.
    def second_visit? = !second_visit.nil?
    def second_visit_steps = second_visit ? steps.drop(second_visit.after) : []
    def after_steps = gym_finale ? [] : trailing_steps
    def finale_steps = gym_finale ? trailing_steps : []
  end

  # The return trip a twice-walked stop carries: the step its first visit ends on, and the line
  # that says what changed in between and why you are going back.
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

  # The Safari Zone explainer: why nothing in the Safari bag beats a plain throw. Every figure is
  # read from the disassembly (ItemUseBall in engine/items/item_effects.asm for the throw,
  # PrintSafariZoneBattleText in engine/battle/safari_zone.asm for the timers, and the flee roll in
  # engine/battle/core.asm), except the per-encounter odds, which are simulated over those exact
  # routines because no closed form covers a turn loop with a flee roll in it.
  #
  # `rows` on a panel is whatever that panel tabulates, kept as values rather than sentences so the
  # copy never has to restate a number the model already holds.
  CatchStep = Data.define(:n, :title_key, :text_key, :rows, :code_key) do
    def initialize(code_key: nil, **rest) = super
    def code? = !code_key.nil?
    def rows? = rows.any?
  end
  CatchRow = Data.define(:label_key, :value, :tone) do
    def initialize(label_key: nil, tone: nil, **rest) = super
    def labelled? = !label_key.nil?
  end
  # One line of the worked example: which step it is, and what that step costs you on this target.
  CatchCalc = Data.define(:n, :text_key, :value, :tone)
  # What an item does to the two numbers that matter, and what is left once its timer runs out.
  CatchItem = Data.define(:key, :sprite, :rate, :rate_note, :flee, :after_key, :tone)
  # Flee odds per turn for one target, calm and angry. Ranges, because speed moves with DVs.
  CatchFlee = Data.define(:label_key, :normal, :angry)
  # One strategy over a whole encounter, as a percentage of encounters that end in a catch.
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

  # What a Gym Badge does once it is in the case. `kind` is "boost" (an in-battle stat lift for the
  # whole party) or "obey" (the level a traded Pokémon obeys up to), `level` fills the obedience
  # copy, and `field` is the HM the badge switches on outside battle, nil for the last three.
  BadgeCard = Data.define(:no, :name, :image, :leader, :city, :kind, :effect_key, :level, :field) do
    def obey? = kind == "obey"
    def field? = !field.nil?
  end
  BadgeRule = Data.define(:no, :label_key, :title_key, :text_key)
  BadgeGuide = Data.define(:anchor, :cards, :rules)

  # The Exp. All hands its share out in two passes, and the arithmetic below is the game's own.
  # `fighters` and `party` are the state the section opens on; the rest is copy the reader toggles
  # between, rendered server-side so no user-facing string lives in the controller.
  ExpShare = Data.define(:anchor, :sprite, :max_party, :party, :fighters, :verdicts, :legend,
    :trivia)
  ExpVerdict = Data.define(:tone, :text_key)
  ExpLegendText = Data.define(:row, :state, :text_key)
  ExpTrivia = Data.define(:tag_key, :title_key, :text_key)

  # Pikachu's Beach, the minigame the Route 19 beach house hides behind a Pokémon the cartridge
  # cannot produce. Every figure is the game's own: the radness table is the comment on
  # SurfingMinigame_CalculateAndAddRadnessFromStunt (engine/minigame/surfing_pikachu.asm), the
  # 6000 is what the setup writes to wSurfingMinigamePikachuHP, and the meter caps at three flips
  # in SurfingMinigame_IncreaseRadnessMeter. `alt` is the higher payout a row has a second way of
  # scoring; nil when the row pays one number.
  SurfPikachu = Data.define(:anchor, :art, :beach, :stadium, :sprite, :chips, :shots, :scores,
    :steps)
  SurfShot = Data.define(:key, :image, :tone)
  SurfScore = Data.define(:key, :value, :alt, :tone) do
    def alt? = !alt.nil?
  end
  SurfStadiumStep = Data.define(:key, :glyph, :tone)

  # The Cinnabar Lab's fossil revival, which the scientist calls a wait and the cartridge does not:
  # handing a fossil over sets EVENT_LAB_STILL_REVIVING_FOSSIL, and only CinnabarIsland_Script
  # clears it, so the whole "wait" is stepping onto the island map and back inside. `steps` is that
  # round trip, `fossils` the three specimens with their card art, `facts` the ✓/✕/– rows.
  # The Pokémon Mansion's four diary pages, the only lines in the whole script that type out MEW
  # or MEWTWO. `pages` are the entries in the order the maze walks you past them, and `mon` is
  # Mew's own card, whose measurements come out of yellow_dex.json rather than the copy.
  MansionDiary = Data.define(:anchor, :art, :card, :mon, :pages)
  # `tone` is which half of the story the page belongs to, the expedition that found Mew or the
  # thing they made from it, which is what the date's colour says before the words do.
  DiaryPage = Data.define(:key, :tone)
  DiaryMon = Data.define(:dex, :name, :species, :sprite, :height, :weight)

  FossilWait = Data.define(:anchor, :count, :steps, :fossils, :facts)
  FossilStep = Data.define(:n, :title_key, :text_key)
  FossilCard = Data.define(:dex, :name, :item, :art, :sprite, :height, :weight)
  FossilFact = Data.define(:key, :state, :mark)

  def self.games = { "yellow" => Yellow.game }

  def self.find(slug) = games[slug]

  def self.find!(slug)
    find(slug) || raise(ActiveRecord::RecordNotFound, "No walkthrough for game: #{slug}")
  end
end
