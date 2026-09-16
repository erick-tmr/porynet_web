require "test_helper"

class WalkthroughsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "the version index offers every Gen 1 cartridge, Yellow first and open" do
    get walkthroughs_path

    assert_response :success
    assert_select "title", "Walkthroughs · PORYNET"
    assert_select ".pn-nav__crumb-here", text: "SELECT A VERSION"
    assert_select "#pn-nav-menu a.pn-nav__menu-link.is-active", text: "Walkthroughs"
    assert_select ".pn-ver", count: 5
    assert_select ".pn-ver__name", text: "Pokémon Yellow"
    assert_select ".pn-ver--live .pn-ver__open[href=?]", walkthrough_path(game: "yellow"), text: "OPEN ▶"
    assert_select ".pn-ver--live .pn-ver__pages",
      text: "#{Walkthrough.find!('yellow').legs.size} pages live"
    assert_select ".pn-ver__status", count: 3, text: "ROUTING · NEXT UP"
  end

  test "every page of every live game renders, in both locales" do
    Walkthrough.games.each_value do |game|
      game.legs.each do |leg|
        %w[en pt].each do |locale|
          get walkthrough_leg_path(game: game.slug, leg: leg.slug, locale: locale)
          assert_response :success, "#{game.slug} #{leg.slug} (#{locale})"
        end
      end
    end
  end

  test "the ROM hack opens too, on its own slug" do
    get walkthroughs_path

    assert_select ".pn-ver--dark .pn-ver__name", text: "Pokémon Yellow Legacy"
    assert_select ".pn-ver--dark .pn-ver__open[href=?]",
      walkthrough_path(game: "yellow-legacy"), text: "OPEN ▶"
    assert_select ".pn-ver--dark .pn-ver__pages",
      text: "#{Walkthrough.find!('yellow-legacy').legs.size} pages live"
  end

  test "the version index dates the cartridges and marks the ROM hack instead" do
    get walkthroughs_path

    assert_select ".pn-ver__released", text: "JP 1998INTL 1999", count: 1
    assert_select ".pn-ver--dark .pn-ver__released", text: "ROM HACK"
    assert_select ".pn-ver__art--crop[src*=?]", "covers/green-jp.png"
  end

  test "the version index carries no mode switches, having no game to track" do
    get walkthroughs_path

    assert_response :success
    assert_select ".pn-modesw", count: 0
    assert_select ".pn-nav__panel-mode", count: 0
  end

  test "the version index renders in Portuguese" do
    get walkthroughs_path(locale: :pt)

    assert_response :success
    assert_select "html[lang=?]", "pt"
    assert_select ".pn-ver__open", text: "ABRIR ▶"
    assert_select ".pn-nav__crumb-here", text: "ESCOLHA UMA VERSÃO"
  end

  test "the Yellow index lists the legs and specials with the new framing" do
    get walkthrough_path(game: "yellow")

    assert_response :success
    assert_select "title", /Pokémon Yellow Walkthrough/
    assert_select "#pn-nav-menu a.pn-nav__menu-link.is-active", text: "Walkthroughs"
    assert_select ".pn-wt-route__name", text: "Pallet Town → Route 1"
    assert_select ".pn-wt-route__special"
    assert_select ".pn-wt-route__stat--gym"
    assert_includes response.body, "SPECIALS · OFF THE MAIN LINE"
  end

  test "the index explains both challenge trackers, with the Brock deadline drawn from the game data" do
    get walkthrough_path(game: "yellow")

    assert_response :success
    assert_select "#modes .pn-wt-moderow", count: 2
    assert_select ".pn-wt-moderow--living .pn-wt-modeid__title", text: "Catch one of every species, and keep it"
    assert_select ".pn-wt-moderow--oak .pn-wt-modeid__title", text: "Register everything before the next gym"
    assert_select ".pn-wt-species .pn-wt-mode--locked", count: 3

    assert_select ".pn-wt-deadline__title", text: "First deadline · Brock"
    assert_select ".pn-wt-deadline__note", text: "17 entries owed before you step into Pewter Gym."
    assert_select ".pn-wt-deadline__badge-name", text: "BOULDER"
    assert_select ".pn-wt-oakq__cell", count: 17
    assert_select ".pn-wt-oakq__how--start", text: "START"
    assert_select ".pn-wt-oakq__how--either", count: 2
  end

  test "the index renders in Portuguese" do
    get walkthrough_path(game: "yellow", locale: :pt)

    assert_response :success
    assert_select "html[lang=?]", "pt"
    assert_includes response.body, "A ROTA · 34 PARADAS"
  end

  test "a leg merges its locations into bands with a jump switcher" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select ".pn-nav__crumb-here", text: "LEG 01"
    assert_select ".pn-wt-loc__title", /Pallet Town/
    assert_select "[data-controller='leg-switcher']"
    assert_select ".pn-legsw__chip", count: 2
    assert_select ".pn-wt-band__title", text: "Pallet Town"
    assert_select ".pn-wt-band__title", text: "Route 1"
    assert_select ".pn-wt-catch__name", text: "Pidgey"
    assert_select ".pn-wt-nav__where", text: "Viridian City → Route 2"
  end

  test "back from a leg lands on that leg's card in the index, not the top of the page" do
    get walkthrough_path(game: "yellow")
    assert_select ".pn-wt-route#leg-04"
    assert_select ".pn-wt-route#viridian-forest"

    get walkthrough_leg_path(game: "yellow", leg: "leg-04")
    assert_select "a.pn-wt-back[href=?]", "#{walkthrough_path(game: 'yellow')}#leg-04"

    get walkthrough_leg_path(game: "yellow", leg: "viridian-forest")
    assert_select "a.pn-wt-back[href=?]", "#{walkthrough_path(game: 'yellow')}#viridian-forest"
  end

  test "reward amounts carry the drawn Poke Dollar sign instead of a currency character" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select ".pn-wt-trainer__reward span.pn-money-value" do
      assert_select "span.pn-money[role=img][aria-label=?]", "Poké Dollar"
    end
    assert_select ".pn-wt-trainer__reward", text: /\A175\z/
    assert_not_includes response.body, "₽"
  end

  test "step prose renders the Poke Dollar through the same component" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select ".pn-wt-step__text span.pn-money-value span.pn-money[aria-label=?]", "Poké Dollar"
  end

  test "the rival battles link to the trivia that explains the Eevee outcome" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select "#rival-eevee .pn-wt-band__h3", text: "This battle decides your rival's Eevee"
    assert_select ".pn-wt-step__text a[href=?]", "/walkthroughs/yellow/leg-01#rival-eevee"

    get walkthrough_leg_path(game: "yellow", leg: "leg-02")

    assert_response :success
    assert_select ".pn-wt-step__text a[href=?]", "/walkthroughs/yellow/leg-01#rival-eevee"
  end

  test "a step link keeps the locale prefix" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-02", locale: "pt")

    assert_response :success
    assert_select ".pn-wt-step__text a[href=?]", "/pt/walkthroughs/yellow/leg-01#rival-eevee"
  end

  test "the best place to catch tag flags the winning card with a reason" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select ".pn-wt-catch--best", 1
    assert_select ".pn-wt-best__label", text: "BEST PLACE TO CATCH"
    assert_includes response.body, "the best odds for Pidgey"
  end

  test "a tied best place reads as the earliest spot" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-02")

    assert_response :success
    assert_includes response.body, "Best rate at 30%, and the earliest place to catch Nidoran♀"
  end

  test "a location renders its area map with a marker overlay" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select "img.pn-mm-canvas__img[src*=?]", "walkthrough/yellow/maps/route-1.png"
    assert_select "[data-map-markers-map-value=?] .pn-mm[data-cat=exit]", "route-1", 2
  end

  test "an exit marker is labelled with what is on the other side of it" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-02")

    assert_response :success
    assert_select "[data-map-markers-map-value=?] .pn-mm[data-cat=exit] .pn-mm__label",
      "route-22", text: /Viridian City/
    assert_select "[data-map-markers-map-value=?] .pn-mm[data-cat=exit] .pn-mm__label",
      "viridian-city", text: /Route 22/
  end

  test "an important NPC joins the map as an un-tickable, lettered label" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select "[data-map-markers-map-value=?] .pn-mm[data-cat=npc] .pn-mm__label-key", "pallet-town", text: "N1"
    assert_select "[data-map-markers-map-value=?] .pn-mm[data-cat=npc] [aria-pressed]", "pallet-town", false
    assert_select ".pn-mm-legend__title", text: "IMPORTANT NPCS"
    assert_includes response.body, "Technology is incredible"
  end

  test "Legacy's Pallet page briefs the rules its neighbours changed, pinned to where they stand" do
    get walkthrough_leg_path(game: "yellow-legacy", leg: "leg-01")

    assert_response :success
    assert_select "#pallet-town-what-changed .pn-eyebrow-label", text: "TRIVIA · WHAT CHANGED"
    assert_select "#pallet-town-what-changed .pn-wt-trivia__facts .pn-wt-trivia-row", 5
    assert_select "#pallet-town-what-changed .pn-wt-trivia-mark--no", 1, "only Bug lost a matchup"
    assert_select "#pallet-town-what-changed .pn-wt-trivia__intro .pn-wt-mark[data-mark-key=?]", "N1"
    assert_select "#pallet-town-what-changed .pn-wt-shot img[src*=?]", "pallet-running-shoes.png"
    assert_select "#rival-eevee", 1, "the Eevee trivia still has the page to itself above it"
  end

  test "an Old Rod catch whose best odds lie elsewhere says so on the card" do
    get walkthrough_leg_path(game: "yellow-legacy", leg: "leg-02")

    assert_response :success
    assert_select "#catchsec-viridian-city-old-rod .pn-wt-catchbadge--elsewhere", 2
    assert_select "#catchsec-viridian-city-old-rod .pn-wt-catchbadge--elsewhere",
      text: "SUPER ROD ON ROUTE 6", count: 1
    assert_select "#catchsec-viridian-city-old-rod .pn-wt-catchbadge--elsewhere",
      text: "SUPER ROD ON ROUTE 23", count: 1
    assert_select "#catchsec-viridian-city-old-rod .pn-wt-best", 0,
      "neither is the best place, so neither wears the star"
  end

  test "a briefed stop shows its What Changed section, pinned to the NPC that says it" do
    get walkthrough_leg_path(game: "yellow-legacy", leg: "leg-02")

    assert_response :success
    assert_select "#viridian-city-what-changed .pn-eyebrow-label", text: "TRIVIA · WHAT CHANGED"
    assert_select "#viridian-city-what-changed .pn-wt-trivia__facts .pn-wt-trivia-row", 5
    assert_select "#viridian-city-what-changed .pn-wt-trivia-mark--na", 1, "only the PP board is a Gen 1 rule"
    assert_select "#viridian-city-what-changed .pn-wt-trivia__intro .pn-wt-mark[data-mark-key=?]", "N3"
  end

  test "vanilla Yellow's Viridian page carries no rule-change section" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-02")

    assert_response :success
    assert_select "[id$=what-changed]", 0
  end

  test "a pin's hint links to the step that collects it, and that step is there to land on" do
    get walkthrough_leg_path(game: "yellow", leg: "viridian-forest")

    assert_response :success
    assert_select ".pn-mm[data-marker-id=?] .pn-mm__hint-step[href=?]", "item-1-31",
      "#viridian-forest-step-3", text: /STEP 3/
    assert_select ".pn-wt-step#viridian-forest-step-3"
    assert_select ".pn-mm[data-marker-id=?] .pn-mm__hint-step", "trainer-2-41", false,
      "a trainer is the location's, not one step's"
  end

  test "every card prints the letter of the pin it belongs to" do
    get walkthrough_leg_path(game: "yellow", leg: "viridian-forest")

    assert_response :success
    assert_select ".pn-wt-item .pn-wt-mark", text: "I3"
    assert_select ".pn-wt-hidden__name .pn-wt-mark", text: "H2"
    assert_select ".pn-mm-legend__chip--item", text: "I3"
  end

  test "a stop with one encounter method renders exactly one section" do
    get walkthrough_leg_path(game: "yellow", leg: "viridian-forest")

    assert_response :success
    assert_select ".pn-wt-catchsec", count: 1
    assert_select "#catchsec-viridian-forest-grass .pn-wt-catch", count: 4
    assert_select "#catchsec-viridian-forest-surf", false
    assert_select "#catchsec-viridian-forest-gift", false
  end

  test "an interior map fills a step screenshot slot" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select ".pn-wt-shot--map img.pn-wt-shot__map-img[src*=?]", "walkthrough/yellow/maps/reds-house-2f.png"
    assert_select ".pn-wt-shot--map img.pn-wt-shot__map-img[src*=?]", "walkthrough/yellow/scenes/pallet-town-exit.png"
  end

  test "the leg back from the ship switches between Vermilion and Route 11" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-06")

    assert_response :success
    assert_select "[data-controller='leg-switcher']"
    assert_select ".pn-legsw__chip[data-slug='vermilion-city-return']"
    assert_select ".pn-legsw__chip[data-slug='route-11']"
    assert_select ".pn-wt-band__title", text: "Route 11"
  end

  test "a leg renders in Portuguese with a gym band and its leader" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-16", locale: :pt)

    assert_response :success
    assert_select ".pn-wt-band__badge", /VOLCANO/
    assert_select ".pn-wt-gym__leader-name", text: /\ABlaine\b/
  end

  test "the fossil lab renders in Portuguese with its trades and both mode chips" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-15", locale: :pt)

    assert_response :success
    assert_select ".pn-wt-tagpill--fossil"
    assert_select ".pn-wt-trade__tag", text: "TROCA"
    assert_select ".pn-wt-oak__chip", text: "MODO DESAFIO OAK"
    assert_select ".pn-wt-ld__chip", text: "MODO LIVING DEX"
  end

  test "a location renders its in-game trades with give and receive sprites" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-15")

    assert_response :success
    assert_select ".pn-eyebrow-label", text: /IN-GAME TRADES/
    assert_select ".pn-wt-trades .pn-wt-trade", 3
    assert_select ".pn-wt-trade__title", text: "Muk"
    assert_select ".pn-wt-trade__nick", text: /STICKY/
    assert_select ".pn-wt-trade__mon--give img[src*=?]", "pokemon/yellow/115.png"
    assert_select ".pn-wt-trade__mon--get img[src*=?]", "pokemon/yellow/089.png"
  end

  test "each trade card is a tick target that carries a toast and a traded badge" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-15")

    assert_response :success
    assert_select ".pn-wt-trade[role='button'][data-kind='collected'][data-progress-id]", 3
    assert_select ".pn-wt-trade .pn-wt-toast .pn-wt-toast__retry", 3
    assert_select ".pn-wt-trade__done", text: /TRADED/
    assert_select ".pn-wt-trade__tag--done", text: "TRADED"
  end

  test "trades render on a single-location leg between the map and the oak queue" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-06")

    assert_response :success
    assert_select ".pn-wt-trades .pn-wt-trade", 1
    assert_select ".pn-wt-trade__title", text: "Dugtrio"
  end

  test "a stop drawn map by map hangs each map's catches and trades off that map" do
    get walkthrough_leg_path(game: "yellow", leg: "digletts-cave")

    assert_response :success
    marks = css_select(".pn-mm-titlebar__name, .pn-wt-catchsecs, .pn-wt-trades").map do |node|
      node["class"] == "pn-mm-titlebar__name" ? node.text.tr("◈", "").strip : node["class"]
    end

    assert_equal [ "DIGLETT'S CAVE", "pn-wt-catchsecs", "ROUTE 2", "pn-wt-trades",
                   "VIRIDIAN CITY", "PEWTER CITY" ], marks
    assert_select ".pn-wt-catchsecs .pn-wt-catch__name", text: "Diglett"
    assert_select ".pn-wt-trade__title", text: "Mr. Mime"
  end

  test "the cave approach draws its three borrowed maps in walk order and meets the last trainer" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-19")

    assert_response :success
    assert_select ".pn-wt-band__title", text: "Route 4 → Cerulean Cave"
    assert_equal [ "ROUTE 24", "CERULEAN CITY", "ROUTE 4" ],
      css_select(".pn-mm-titlebar__name").map { |node| node.text.tr("◈", "").strip }
    assert_select ".pn-wt-trainer__name", text: "LASS T1"
    assert_select "[data-progress-id=?]", "route-4/trainer-63-3"
    assert_select ".pn-wt-step__text a[href=?]",
      walkthrough_leg_path(game: "yellow", leg: "cerulean-cave", anchor: "cerulean-cave-step-1")
  end

  test "a multi-floor dungeon badges each trainer with the floor it waits on" do
    get walkthrough_leg_path(game: "yellow", leg: "rock-tunnel")

    assert_response :success
    floors = css_select(".pn-wt-trainer__floor").map(&:text)

    assert_equal({ "1F" => 7, "B1F" => 8 }, floors.tally)
    assert_select ".pn-wt-trainer__floor[title=?]", "Which floor this trainer waits on"
  end

  test "a stop that is all one floor badges nobody" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-03")

    assert_response :success
    assert_select ".pn-wt-trainer", minimum: 1
    assert_select ".pn-wt-trainer__floor", false, "nothing to tell apart on a route or in a gym"
  end

  test "a no-maze gym renders a dedicated section with an inside trainer and badge" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-03")

    assert_response :success
    assert_select ".pn-wt-gym__name", text: "Pewter Gym"
    assert_select ".pn-wt-gym__type", /ROCK/
    assert_select ".pn-wt-trainers--gym .pn-wt-trainer__name", text: /JR. TRAINER♂/
    assert_select ".pn-wt-gym__leader-name", text: /\ABrock\b/
    assert_select ".pn-wt-gym__leader[role='button'][data-kind='collected'][data-progress-id='pewter-city-gym/trainer-4-1']"
    assert_select ".pn-wt-gym__leader .pn-wt-toast__retry"
    assert_select ".pn-wt-gym__leader-cleared", text: /GYM CLEARED/
    assert_select ".pn-wt-gym__badge-name", text: "BOULDER"
    assert_select "img.pn-wt-gym__badge-img[src*=?]", "badges/boulder"
    assert_select ".pn-wt-gym__puzzle", false
    assert_select ".pn-wt-step__title", text: "Heal, prep, and enter the Gym"
    assert_select ".pn-eyebrow-label", text: /AFTER THE GYM/
    assert_select ".pn-wt-step__title", text: "Head east to Route 3"
  end

  test "a maze gym renders its puzzle solution steps" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-06")

    assert_response :success
    assert_select ".pn-wt-gym__name", text: "Vermilion Gym"
    assert_select ".pn-wt-gym__leader-name", text: /\ALt\.\ Surge\b/
    assert_select ".pn-wt-gym__puzzle"
    assert_select ".pn-wt-gym__pstep", count: 3
    assert_select ".pn-wt-shot--pstep"
  end

  test "Celadon leaves the gym to its return leg" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-09")

    assert_response :success
    assert_select ".pn-wt-gym", false, "no gym card on the first pass"
    assert_select ".pn-wt-band__badge", false
    assert_select ".pn-wt-step__title", text: "Find the Game Corner"
    assert_select ".pn-wt-step__title", text: /Erika/, count: 0
    steps = css_select(".pn-wt-step__title").map { |el| el.text.strip }
    assert_operator steps.index("Open Saffron with a drink"), :<, steps.index("Find the Game Corner")
    assert_select ".pn-wt-step__text", text: /back door/

    get walkthrough_leg_path(game: "yellow", leg: "leg-10")

    assert_response :success
    assert_select ".pn-wt-band__badge", text: "GYM · RAINBOW"
    assert_select ".pn-wt-gym__leader-name", text: /Erika/
    assert_select ".pn-wt-step__title", text: "Cut into the greenhouse"
    assert_select ".pn-wt-gym__needs-badge", text: "NEEDS · HM01 CUT"
  end

  test "a leg whose catches are all better elsewhere still answers the living dex" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-10")

    assert_response :success
    assert_select ".pn-wt-ld"
    assert_select ".pn-wt-ldrow", count: 0
    assert_select ".pn-wt-ldq__none"
    assert_select ".pn-wt-ld__ledger-head", count: 0
    assert_select ".pn-wt-catchbadge--elsewhere", text: "IN THE GRASS ON ROUTE 17"
    assert_select ".pn-wt-catchbadge--elsewhere", text: "DO IT AT POKÉMON MANSION"
    assert_select ".pn-wt-ldnote__text", text: /Doduo has better odds at Route 17/
  end

  test "the Coin Case is collected in Celadon, with its own shot" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-09")

    assert_response :success
    assert_select ".pn-wt-step__title", text: "Collect the Coin Case"
    assert_select ".pn-wt-item__name", text: "Coin Case"
    assert_select ".pn-wt-shot__map-img[src*=?]", "celadon-diner-coin-case"

    steps = css_select(".pn-wt-step__title").map { |el| el.text.strip }
    assert_operator steps.index("Take the Eevee off the roof"), :<, steps.index("Collect the Coin Case")

    get walkthrough_leg_path(game: "yellow", leg: "rocket-hideout")
    assert_select ".pn-wt-loc__title", text: "Game Corner / Rocket Hideout"
    assert_select ".pn-wt-item__name", text: "Coin Case", count: 0
  end

  test "the Game Corner floor is drawn, with every coin pile priced" do
    get walkthrough_leg_path(game: "yellow", leg: "rocket-hideout")

    assert_response :success
    assert_select ".pn-mm-canvas__img[src*=?]", "rocket-hideout-game-corner"
    assert_select ".pn-wt-step__title", text: "Sweep the arcade floor for coins"
    assert_select ".pn-wt-step__title", text: "Beat the Rocket, then read the poster"

    piles = css_select(".pn-mm:has(.pn-mm__pin--hidden) .pn-mm__label").map { |el| el.text.strip }
    assert_equal 8, piles.count { |l| l.include?("10 coins") }
    assert_equal 3, piles.count { |l| l.include?("20 coins") }
    assert_equal 1, piles.count { |l| l.include?("100 coins") }, "one pile is worth the other eleven"

    npcs = css_select(".pn-mm:has(.pn-mm__pin--npc) .pn-mm__label")
      .map { |el| el.text.split.drop(1).join(" ") }
    assert_equal [ "10 coins", "20 coins", "20 coins" ], npcs.grep(/coins/).sort
    sweep = css_select(".pn-wt-step").find { |el| el.text.include?("Sweep the arcade") }
    assert_equal 3, sweep.css(".pn-wt-mark").count { |m| m.text.strip.start_with?("N") }

    assert_includes npcs, "The poster"
    poster = css_select(".pn-wt-step").find { |el| el.text.include?("read the poster") }
    assert_equal %w[T N E], poster.css(".pn-wt-mark").map { |m| m.text.strip[0] },
      "the Rocket, then the poster he stands in front of, then what it opens"
  end

  test "the Rocket Hideout carries the Game Corner prize counters, priced from the game" do
    get walkthrough_leg_path(game: "yellow", leg: "rocket-hideout")

    assert_response :success
    assert_select "#prize-room .pn-wt-gc__window", 3
    assert_select "#prize-room .pn-wt-gc__prize", 9
    assert_select ".pn-wt-gc__prize-name", text: "Porygon"
    assert_select ".pn-wt-gc__prize-name", text: "TM23 Dragon Rage"
    assert_select ".pn-wt-gc__coins", text: "9,999"
    assert_select ".pn-wt-gc__coins", text: "3,300"
    assert_select ".pn-wt-gc__stat-title", text: "12 coin piles on the floor"
    assert_select ".pn-wt-gc__prize.is-pick", 3
    assert_select ".pn-wt-gc__know-text", text: /¥200,000/

    assert_select ".pn-wt-gc__art-img[src*=?]", "art/celadon-game-corner"
    assert_select ".pn-wt-gc__art-credit", text: /GAME FREAK/
    assert_select ".pn-wt-gc__stat-tile--coin .pn-money"
    assert_select ".pn-wt-gc__stat-title .pn-money-value__n", text: "1,000"
  end

  test "no other special stop draws the prize counters" do
    get walkthrough_leg_path(game: "yellow", leg: "mt-moon")

    assert_response :success
    assert_select "#prize-room", false
  end

  test "a special stop carries the shared bar inside a host that wraps the page" do
    get walkthrough_leg_path(game: "yellow", leg: "mt-moon")

    assert_response :success
    assert_select ".pn-legsw-host .pn-legsw--solo .pn-legsw__current-name", text: "Mt. Moon"
    assert_select ".pn-legsw-host .pn-wt-steps"
    assert_select ".pn-legsw-host .pn-wt-ld"
    assert_select ".pn-legsw__chip", false
  end

  test "a special stop renders its own dedicated page with hidden-item pins" do
    get walkthrough_leg_path(game: "yellow", leg: "viridian-forest")

    assert_response :success
    assert_select ".pn-nav__crumb-here", text: "VIRIDIAN FOREST"
    assert_select ".pn-wt-loc__title", /Forest/
    assert_select ".pn-legsw__chip", false
    assert_select "img.pn-wt-shot__img[src*=?]", "scenes/viridian-forest-hidden-antidote"
    assert_select ".pn-wt-pin--viridian-forest-antidote"
  end

  test "a trainer-only special hides the catch section but still owes Oak the next gym" do
    get walkthrough_leg_path(game: "yellow", leg: "ss-anne")

    assert_response :success
    assert_select ".pn-wt-catch-grid", false
    assert_select ".pn-wt-ld", false
    assert_select ".pn-wt-trainer__name", text: "Blue"
    assert_select ".pn-wt-oak"
  end

  test "a single-stop page queues its catches, its box ledger and its Oak window" do
    get walkthrough_leg_path(game: "yellow", leg: "viridian-forest")

    assert_response :success
    assert_select ".pn-wt-ld__chip", text: "LIVING DEX MODE"
    assert_select ".pn-wt-ldrow", count: 2
    assert_select ".pn-wt-ldrow__qty", text: "×2"
    assert_select ".pn-wt-statbar__big--cyan", text: "3"
    assert_select ".pn-wt-ldfam__card", count: 1
    assert_select ".pn-wt-ldstage", count: 3

    assert_select ".pn-wt-oak__window", text: "WINDOW 01 · EVERYTHING BEFORE BROCK"
    assert_select ".pn-h2", text: "Registered before Brock"
    assert_select ".pn-wt-statbar__big--amber", text: "17"
    assert_select ".pn-wt-oakgroup__label--earlier", text: "EARLIER STOPS"
    assert_select ".pn-wt-locked__name", text: "Raichu"
    assert_select ".pn-wt-locked__name", text: "Nidoqueen"
  end

  test "a multi-stop page merges its stops into one queue and tags each band with its share" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select ".pn-wt-oak__window", text: "WINDOW 02 · EVERYTHING BEFORE MISTY"
    assert_select ".pn-wt-ldrow", count: 5
    assert_select ".pn-wt-ldrow__spot", text: "ROUTE 24"
    assert_select ".pn-wt-bandledger", count: 4
    assert_select ".pn-legsw__work"
    assert_select ".pn-wt-catchbadge--elsewhere", text: /DO IT AT ROUTE 24/
    assert_select ".pn-wt-catchbadge--boxed", text: "ALREADY BOXED"

    assert_select ".pn-wt-catch--gift .pn-wt-catch__badges .pn-wt-catchbadge--living"
    assert_select ".pn-wt-catch--gift .pn-wt-catch__gift-from", text: "FROM THE HILLTOP BOY"
    assert_select ".pn-wt-catch[data-body-counter-dex-value='004'] .pn-wt-tagpill", count: 1,
      text: "GIFT"
  end

  test "Cerulean carries Mew as a static, and both challenge modes ask for it there" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select ".pn-wt-catch[data-body-counter-dex-value=?][data-kind=?]", "151", "caught"
    assert_select ".pn-wt-catch[data-body-counter-dex-value='151'] .pn-wt-tagpill", text: "STATIC"
    assert_select ".pn-wt-catch[data-body-counter-dex-value='151'] .pn-wt-catch__stat-val",
      text: "7"
    assert_select ".pn-wt-catch[data-body-counter-dex-value='151'] .pn-wt-catch__tip",
      text: /Trainer-Fly glitch/
    assert_select ".pn-wt-ldrow[data-body-counter-dex-value=?]", "151"
    assert_select ".pn-wt-oaktile[data-progress-id=?]", "151"
  end

  test "the challenge stats are live slots, so the meter and the counts move with the store" do
    get walkthrough_leg_path(game: "yellow", leg: "viridian-forest")

    assert_response :success
    assert_select "[data-progress-toggle-target='meter'][data-kind='caught']"
    assert_select "[data-progress-toggle-target='remaining'][data-kind='caught']", text: "17"
    assert_select "[data-meter-pct]", text: "0%"
    assert_select "[data-controller='body-counter'][data-body-counter-dex-value='010']"
    assert_select "[data-body-counter-covers-value]"
  end

  test "a page whose window opened on an earlier page says so instead of repeating it" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-03")

    assert_response :success
    assert_select ".pn-wt-oak__window", text: "WINDOW 02 · EVERYTHING BEFORE MISTY"
    assert_select ".pn-wt-oak__assumes", text: /The Brock window closed clean/
    assert_select ".pn-wt-oakgroup__label--earlier", false
  end

  test "the Safari Zone is its own page, and Koga's pass runs on into Sabrina's window" do
    get walkthrough_leg_path(game: "yellow", leg: "safari-zone")

    assert_response :success
    assert_select ".pn-wt-oak__window", text: "WINDOW 05 · EVERYTHING BEFORE KOGA"
    assert_select ".pn-nav__crumb-here", text: "SAFARI ZONE"

    get walkthrough_leg_path(game: "yellow", leg: "leg-12")

    assert_response :success
    assert_select ".pn-wt-oak__window", text: "WINDOW 06 · EVERYTHING BEFORE SABRINA"
    assert_select ".pn-wt-band__title", text: "Fuchsia City"
    assert_select ".pn-wt-gym__leader-name", text: /\AKoga\b/

    get walkthrough_leg_path(game: "yellow", leg: "leg-13")

    assert_response :success
    assert_select ".pn-wt-band__title", text: "Saffron City"
    assert_select ".pn-wt-gym__leader-name", text: /\ASabrina\b/
  end

  test "the Route 22 rematch card names one Eeveelution and links the recipe that picks it" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-18")

    assert_response :success
    assert_select ".pn-wt-trainer__name", text: "Blue"
    assert_select ".pn-wt-team-mon__name", text: "Jolteon"
    assert_select ".pn-wt-trainer__note", text: /whichever Eeveelution his Eevee became/
    assert_select ".pn-wt-trainer__note a[href=?]",
      walkthrough_leg_path(game: "yellow", leg: "leg-01", anchor: "rival-eevee")
  end

  test "the endgame page names the League rather than a leader it does not have" do
    get walkthrough_leg_path(game: "yellow", leg: "victory-road")

    assert_response :success
    assert_select ".pn-wt-oak__window", text: "WINDOW 09 · EVERYTHING LEFT IN THE DEX"
    assert_select ".pn-h2", text: "Registered before the League"
    assert_select ".pn-wt-statbar__label", text: "SPECIES DUE IN ALL"
  end

  test "both challenge sections render even with the modes off, so CSS alone gates them" do
    get walkthrough_leg_path(game: "yellow", leg: "viridian-forest")

    assert_response :success
    assert_select ".pn-wt-modesoff__tag", text: "BOTH MODES OFF"
    assert_select ".pn-wt-modesoff__cta[data-mode='living']"
    assert_select ".pn-wt-modesoff__cta[data-mode='oak']"
    assert_select ".pn-wt-ld"
    assert_select ".pn-wt-oak"
  end

  test "a boss trainer gets its own full-width feature card, apart from the trainer grid" do
    get walkthrough_leg_path(game: "yellow", leg: "mt-moon")

    assert_response :success
    assert_select ".pn-wt-trainers--feature .pn-wt-trainer__name", text: "Jessie & James"
    assert_select ".pn-wt-trainers--feature .pn-wt-shot--battlescreen"
    assert_select ".pn-wt-trainers--feature .pn-wt-trainer", count: 1
    assert_select ".pn-wt-trainers:not(.pn-wt-trainers--feature) .pn-wt-trainer", minimum: 2
  end

  test "the first and last stops omit prev and next respectively" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")
    assert_response :success
    assert_select ".pn-wt-nav__link", count: 1

    get walkthrough_leg_path(game: "yellow", leg: "cerulean-cave")
    assert_response :success
    assert_select ".pn-wt-nav__link--next", false
  end

  test "the last stop signs off with the true ending, its tick tags and its three ways on" do
    get walkthrough_leg_path(game: "yellow", leg: "cerulean-cave")

    assert_response :success
    assert_select "#true-ending .pn-truend__title", text: "Congratulations, trainer"
    assert_select ".pn-truend__mewtwo[src*=?]", "walkthrough/art/mewtwo-gen1-art.png"
    assert_select ".pn-truend__mew[src*=?]", "walkthrough/art/mew-gen1-art.png"
    assert_select ".pn-truend__frame-img[src*=?]", "walkthrough/art/party-pikachu.png"
    assert_select ".pn-truend__tag", count: 2
    assert_select ".pn-truend__tag--violet[data-progress-id=?][data-kind=?]", "150", "caught"
    assert_select ".pn-truend__tag--pink[data-progress-id=?][data-kind=?]", "151", "caught"
    assert_select ".pn-wt-catch[data-progress-id=?][data-kind=?]", "150", "caught"
    assert_select ".pn-truend__tag--pink .pn-truend__tag-todo", text: "#151 · STILL MISSING"
    assert_select ".pn-truend__tile", count: 4
    assert_select ".pn-truend__tile-v a[href=?]", root_path(anchor: "tracker")
    assert_select ".pn-truend__tile-v a[href=?]",
      walkthrough_leg_path(game: "yellow", leg: "indigo-plateau")
    assert_select ".pn-truend__tile-v a[href=?]", walkthrough_mew_glitch_path(game: "yellow")
    assert_select ".pn-truend__stamp", text: /Pokémon Yellow · stop 53 of 53 · Cerulean Cave B1F/
    assert_select "link[href*=?]", "pages/cerulean-cave"
  end

  test "no other stop carries the sign-off" do
    get walkthrough_leg_path(game: "yellow", leg: "indigo-plateau")

    assert_response :success
    assert_select ".pn-truend", false
  end

  test "the true ending renders in Portuguese" do
    get walkthrough_leg_path(game: "yellow", leg: "cerulean-cave", locale: :pt)

    assert_response :success
    assert_select ".pn-truend__title", text: "Parabéns, treinador"
    assert_select ".pn-truend__stamp-b", text: "ARQUIVO COMPLETO"
    assert_select ".pn-truend__tile-v a[href=?]",
      walkthrough_mew_glitch_path(game: "yellow", locale: :pt)
  end

  test "a city renders a Poké Mart section listing its priced stock" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-02")

    assert_response :success
    assert_select ".pn-wt-mart"
    assert_select ".pn-eyebrow-label", text: "POKÉ MART · 5 ITEMS"
    assert_select ".pn-wt-mart__row", 5
    assert_select ".pn-wt-mart__name", text: "Poké Ball"
    assert_select ".pn-wt-mart__price span.pn-money[aria-label=?]", "Poké Dollar"
    assert_select ".pn-wt-mart__buy-tag", text: "BUY LIST"
    assert_not_includes response.body, "₽"
  end

  test "the mart section renders in Portuguese" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-02", locale: :pt)

    assert_response :success
    assert_select ".pn-wt-band__h3", text: "O que o Mart vende"
  end

  test "Cerulean explains the eight badges right after its Mart" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select "#badges-explained .pn-wt-band__h3", text: "Gym Badges, explained"
    assert_select "#badges-explained .pn-wt-badge", 8
    assert_select ".pn-wt-badge__name", text: "Cascade"
    assert_select ".pn-wt-badge__where", text: "Misty · Cerulean City"
    assert_select ".pn-wt-badge-row__text", text: "Traded Pokémon up to Lv 30"
    assert_select ".pn-wt-badge-row__text--none", 3
    assert_select ".pn-wt-badge-rules__row", 4
    assert_operator response.body.index("pn-wt-mart"), :<, response.body.index("badges-explained"),
      "the badge guide must follow the Mart"
    assert_operator response.body.index("badges-explained"), :<,
      response.body.index("cerulean-city-step-1"), "the badge guide must precede the steps"
  end

  test "the badge guide renders in Portuguese" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04", locale: :pt)

    assert_response :success
    assert_select "#badges-explained .pn-wt-band__h3", text: "As Insígnias de Ginásio, explicadas"
    assert_select ".pn-wt-badge-row__text", text: "Trocados até o Nv 30"
  end

  test "a one-stop leg gets the bar reduced to a plate" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-09")

    assert_response :success
    assert_select "[data-controller='leg-switcher']"
    assert_select ".pn-legsw--solo .pn-legsw__plate .pn-legsw__current-name", text: "Celadon City"
    assert_select ".pn-legsw--solo .pn-legsw__plate .pn-legsw__current-no", text: "28"
    assert_select ".pn-legsw__chip", false
    assert_select ".pn-legsw__stepper", false
    assert_select ".pn-legsw__sheet", false
    assert_select ".pn-legsw__meter", false
  end

  test "Celadon renders the multi-floor department store with an elevator" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-09")

    assert_response :success
    assert_select "[data-controller='dept-store']"
    assert_select ".pn-wt-store__entry", 6
    assert_select ".pn-wt-store__stat-num", text: "9"
    assert_select ".pn-wt-mart__name", text: "TM09 · Take Down"
    assert_select ".pn-wt-store__tradelink[href='#roof-trades']"
  end

  test "the free TM18 gets its own step and ticks with the store's gift card" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-09")

    assert_response :success
    assert_select ".pn-wt-step__title", text: "Take the free TM18 from the 3F clerk"
    assert_select ".pn-wt-shot__map-img[src*=?]", "celadon-mart-3f-tm18"

    tick = "celadon-city/gift-tm18-counter"
    assert_select ".pn-wt-store__gift[data-progress-id=?]", tick
    assert_select ".pn-wt-item[data-progress-id=?]", tick
  end

  test "the stone counter recommends nothing" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-09")

    assert_response :success
    assert_select ".pn-wt-mart__name", text: "Water Stone"
    assert_select ".pn-wt-mart__rec", text: /Vaporeon/, count: 0
  end

  test "the rooftop trades render as their own section, priced from the game" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-09")

    assert_response :success
    assert_select "#roof-trades .pn-wt-roof__row", 3
    assert_select ".pn-wt-roof__row .pn-wt-roof__side-name", text: "Fresh Water"
    assert_select ".pn-wt-roof__row .pn-wt-roof__side-name", text: "TM13"
    assert_select ".pn-wt-roof__move", text: "Ice Beam"
    assert_select ".pn-wt-roof__move", text: "Rock Slide"
    assert_select ".pn-wt-roof__move", text: "Tri Attack"
    assert_select ".pn-wt-roof__side-price .pn-money-value__n", text: "200"
    assert_select ".pn-wt-roof__total .pn-money-value__n", text: "1,050"
    assert_select ".pn-wt-roof__shot-img[src*=?]", "scenes/celadon-roof-girl"
    assert_select ".pn-wt-roof__row[data-progress-id='celadon-city/roof-trade-ice-beam']"
  end

  test "a plain town mart renders as a single counter" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-08")

    assert_response :success
    assert_select ".pn-wt-mart"
    assert_select "[data-controller='dept-store']", false
  end

  test "the Mew glitch page renders its hero, phases, and level calculator" do
    get walkthrough_mew_glitch_path(game: "yellow")

    assert_response :success
    assert_select "title", /The Mew Glitch/
    assert_select ".pn-nav__crumb-here--glitch", text: "MEW GLITCH"
    assert_select ".pn-mew-hero__word", text: "Mew"
    assert_select ".pn-mew-tldr__card", count: 5
    assert_select ".pn-mew-phase", count: 3
    assert_select ".pn-mew-tcard", count: 4
    assert_select ".pn-mew-tcard__tag", text: "RT 24"
    assert_select ".pn-mew-tcard__role", text: "THE TRIGGER"
    assert_select "[data-controller='mew-level'] .pn-mew-stage", count: 13
    assert_select ".pn-mew-stage.is-active", text: "0"
    assert_select "[data-mew-level-target='level']", text: "7"
    assert_select ".pn-mew-recipe", count: 13
    assert_select "img[src*=?]", "walkthrough/yellow/art/mew-sugimori.png"
    assert_select "img[src*=?]", "walkthrough/yellow/art/red-and-mew.png"
    assert_select ".pn-mew-step .pn-wt-shot", count: 10
    assert_select ".pn-mew-step .pn-wt-shot--step", count: 0
    assert_select ".pn-mew-step--warn .pn-mew-step__tag--purple", text: "SECOND MEW"
    assert_select ".pn-mew-step img[src*=?]", "walkthrough/yellow/scenes/route-25-trainer-18-5.png"
    assert_select "img[src*=?]", "walkthrough/yellow/scenes/mew-glitch-route24.png"
    assert_select "img[src*=?]", "walkthrough/yellow/battles/mew-glitch-swimmer.png"
  end

  test "the glitch's afterword is where a file registers Mew, on the same handle a card ticks" do
    get walkthrough_mew_glitch_path(game: "yellow")

    assert_response :success
    assert_select ".pn-mew-after__tag[data-progress-id=?][data-kind=?]", "151", "caught"
    assert_select ".pn-mew-after__tag[data-progress-toggle-target=?]", "item"
    assert_select ".pn-mew-after__tag-todo", text: "No. 151 · NOT REGISTERED"
    assert_select ".pn-mew-after__tag-done", text: "No. 151 · REGISTERED ✓"
  end

  test "the Mew glitch page renders in Portuguese" do
    get walkthrough_mew_glitch_path(game: "yellow", locale: :pt)

    assert_response :success
    assert_select "html[lang=?]", "pt"
    assert_select ".pn-nav__crumb-here--glitch", text: "GLITCH DO MEW"
    assert_select ".pn-mew-after__tag-todo", text: "Nº 151 · NÃO REGISTRADO"
  end

  test "the Cerulean Mew section teases the glitch guide and warns on the Swimmer and Misty" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select ".pn-mew-teaser a[href*=?]", "/walkthroughs/yellow/mew-glitch"
    assert_select ".pn-wt-trainers--gym .pn-wt-trainer__note", text: /Shellder's Attack stage sets Mew's level/
    assert_select ".pn-wt-gym__leader-note", text: /locks the Swimmer behind her/
  end

  test "Misty closes leg 04, below the routes north, with her own lead-in step" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    bands = css_select(".pn-wt-band-wrap")
    assert_equal 5, bands.size, "the four stops plus the gym finale"
    assert_equal %w[route-4 cerulean-city route-24 route-25 cerulean-city],
      bands.map { |band| band["data-slug"] }
    assert bands.last.at_css(".pn-wt-gym__leader-name")&.text&.strip&.start_with?("Misty"),
      "Misty's gym card is the last thing on the page"
    assert_select ".pn-eyebrow-label", text: /AFTER THE GYM/, count: 0
    assert_select ".pn-eyebrow-label", text: /LAST STOP · BACK TO THE GYM/
    assert_select ".pn-wt-step__title", text: "Come back down for Misty"
    assert_select ".pn-wt-step__title", text: "Grab the extras, then head north"
  end

  test "the Cerulean Bulbasaur is a gift card with a Pikachu-friendship unlock condition" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select ".pn-wt-catch--gift .pn-wt-catch__gift-from", text: "FROM MELANIE'S HOUSE"
    assert_select ".pn-wt-catch__unlock-text", text: "Pikachu friendship 147 or higher"
  end

  test "Misty's leader card and her pin on the gym map tick the same key" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    map = css_select(".pn-wt-gym [data-map-markers-map-value]").first["data-map-markers-map-value"]
    pin = css_select(".pn-wt-gym [data-role='marker']").find { |node| node.text.include?("Misty") }
    assert pin, "Misty has a pin on the gym map"

    assert_equal "#{map}/#{pin['data-marker-id']}",
      css_select(".pn-wt-gym__leader").first["data-progress-id"],
      "beating her on the map and on her card must write the same key"
  end

  test "Route 15 carries the Exp. All explainer under the step that collects it" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-11")

    assert_response :success
    assert_select "#exp-all .pn-xa[data-controller='exp-share']"
    assert_select ".pn-xa__btn", 12, "six party sizes and six fighter counts"
    assert_select ".pn-xa__verdict-text[hidden]", 3
    assert_select "[data-exp-share-target='legendText'][data-row='bench'][hidden]", 2
    assert_select ".pn-xa__trivia-row", 3
    assert_select ".pn-xa__trivia-title", text: "The PC is the toggle"
  end

  test "Route 19 opens Pikachu's Beach ahead of its steps" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-14")

    assert_response :success
    assert_select "#surfing-pikachu.pn-sp"
    assert response.body.index('id="surfing-pikachu"') < response.body.index("pn-wt-steps"),
      "the beach house reads before the steps that surf past it"
    assert_select ".pn-sp__shot-img", 2, "the same water tile, with the board and without it"
    assert_select ".pn-sp__score", 4
    assert_select ".pn-sp__score--big .pn-sp__score-alt", text: %r{/ 500}
    assert_select ".pn-sp__score--clock .pn-sp__score-val", text: /6000/
    assert_select ".pn-sp__step", 5, "four conditions and the award screen"
    assert_select ".pn-sp__vc-label", text: "VIRTUAL CONSOLE · 3DS"
  end

  test "Cinnabar opens the fossil wait ahead of its steps" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-15")

    assert_response :success
    assert_select "#fossil-wait .pn-wt-band__h3", text: "Two steps. That is the whole wait."
    assert_select "#fossil-wait .pn-eyebrow-label", text: "TRIVIA · CINNABAR LAB"
    assert_select ".pn-fw__count", text: "2"
    assert_select ".pn-fw__step", 2
    assert_select ".pn-fw__step-lead", text: "Step out the front door."
    assert_select ".pn-fw__card", 3
    assert_select ".pn-fw__card-art[src*=?]", "walkthrough/art/kabuto-card.png"
    assert_select ".pn-fw__card-line", text: /Helix Fossil · 0.4 m · 7.7 kg/
    assert_select ".pn-fw__facts .pn-wt-trivia-row", 4
    assert_select ".pn-fw__facts .pn-wt-trivia-mark--no", 1
    assert response.body.index('id="fossil-wait"') < response.body.index("cinnabar-island-step-1"),
      "the wait is answered before the steps that hand a fossil over"
  end

  test "the fossil wait renders in Portuguese" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-15", locale: :pt)

    assert_response :success
    assert_select "#fossil-wait .pn-wt-band__h3", text: "Dois passos. É essa a espera inteira."
    assert_select "#fossil-wait .pn-eyebrow-label", text: "CURIOSIDADE · LABORATÓRIO DE CINNABAR"
    assert_select ".pn-fw__step-lead", text: "Volte direto para dentro."
  end

  test "the mansion reads its diary between the maps and the steps" do
    get walkthrough_leg_path(game: "yellow", leg: "pokemon-mansion")

    assert_response :success
    assert_select "#mansion-diary .pn-eyebrow-label", text: "TRIVIA · MANSION DIARY"
    assert_select "#mansion-diary .pn-wt-band__h3",
      text: "Four pages, and the only place Mew is named"
    assert_select ".pn-md__card-art[src*=?]", "walkthrough/art/mew-card.png"
    assert_select ".pn-md__band-img[src*=?]", "walkthrough/art/mansion-diary.png"
    assert_select ".pn-md__card-line", text: /#151 · NEW SPECIE POKéMON · 0.4 m · 4.1 kg/
    assert_select ".pn-md__entry", 4
    assert_select ".pn-md__date--mew", 2
    assert_select ".pn-md__date--mewtwo", 2
    assert_select ".pn-md__quote", text: /We christened the newly discovered POK.MON, MEW./
    assert response.body.index("pn-wt-maps") < response.body.index('id="mansion-diary"'),
      "the maps the reader scans first come before the diary"
    assert response.body.index('id="mansion-diary"') < response.body.index('id="pokemon-mansion-step-1"'),
      "the diary is read before the steps that walk past its pages"
  end

  test "the diary translates its own words and leaves the pages in the game's English" do
    get walkthrough_leg_path(game: "yellow", leg: "pokemon-mansion", locale: :pt)

    assert_response :success
    assert_select "#mansion-diary .pn-eyebrow-label", text: "CURIOSIDADE · DIÁRIO DA MANSÃO"
    assert_select "#mansion-diary .pn-wt-band__h3",
      text: "Quatro páginas, e o único lugar onde Mew é nomeado"
    assert_select ".pn-md__date", text: "6 DE FEVEREIRO"
    assert_select ".pn-md__quote", text: /MEW gave birth. We named the newborn MEWTWO./
  end

  test "Cerulean carries the collapsible Pikachu friendship explainer, hidden by default" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select "#friendship .pn-fs[data-controller='disclosure']"
    assert_select ".pn-fs__body[hidden]"
    assert_select ".pn-fs__table .pn-fs__row", count: 12
    assert_select ".pn-fs__meter-num--goal", text: /147/
    assert_select ".pn-fs__cell--action", text: "Deposit Pikachu in the PC"
    assert_select ".pn-fs__row--gain .pn-fs__cell--val", text: "+5"
    assert_select ".pn-fs__row--loss .pn-fs__cell--val", text: "−20"
  end

  test "the leave-standing board folds its four shots away, keeping the count and the warning" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select "#leave-standing .pn-ls[data-controller='disclosure']"
    assert_select ".pn-ls__reveal[aria-expanded='false'][aria-controls='pn-ls-cards']"
    assert_select ".pn-ls__reveal-txt--show", text: "SHOW THE FOUR"
    assert_select "#pn-ls-cards.pn-ls__grid[hidden] .pn-ls-card", 4
    assert_select ".pn-ls__head .pn-ls__title", text: "Four Trainers to leave standing"
    assert_select ".pn-ls__intro"
    assert_select ".pn-ls__foot .pn-ls__cta"
  end

  test "a gift Pokemon sits in its own row above the wild grid, as a gift card" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select ".pn-wt-catch-grid--gifts .pn-wt-catch__gift-from", text: "FROM THE HILLTOP BOY"
    assert_select "#catchsec-route-24-gift .pn-wt-catch-grid--gifts .pn-wt-catch--gift .pn-wt-catch__name",
      text: "Charmander"
    assert_select "#catchsec-route-24-grass .pn-wt-catch-grid:not(.pn-wt-catch-grid--gifts) .pn-wt-catch__name",
      text: "Oddish"
  end

  test "a card you have no rod for is never crowned the best place to catch" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-02")

    assert_response :success
    assert_select "#catchsec-route-22-old-rod .pn-wt-catch__name", text: "Magikarp"
    assert_select "#catchsec-route-22-old-rod .pn-wt-catchbadge--locked", text: "NEEDS OLD ROD"
    assert_select "#catchsec-route-22-old-rod .pn-wt-best", false
    assert_select "#catchsec-route-22-super-rod .pn-wt-best", false
    assert_select "#catchsec-route-22-good-rod .pn-wt-best", false
    assert_select "#catchsec-route-22-grass .pn-wt-best"
  end

  test "the catchables box into one section per method, gifts first" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    ids = css_select(".pn-wt-band-wrap[data-slug='route-24'] .pn-wt-catchsec").map { |s| s["id"] }
    assert_equal %w[catchsec-route-24-gift catchsec-route-24-grass catchsec-route-24-old-rod
                    catchsec-route-24-good-rod catchsec-route-24-super-rod], ids
    assert_select "#catchsec-route-24-gift .pn-wt-catchsec__label", text: "Gifts and starters"
    assert_select "#catchsec-route-24-gift .pn-wt-catchsec__code", text: "GIFT"
    assert_select "#catchsec-route-24-grass .pn-wt-catchsec__hint",
      text: "Walk the patches and let them come to you."
    assert_select "#catchsec-route-24-super-rod .pn-wt-catchsec__num", text: "2 SPECIES"
    assert_select "#catchsec-route-24-old-rod .pn-wt-catchsec__num", text: "1 SPECIES"
    assert_select "#catchsec-route-24-safari .pn-wt-catchsec__icon img[src*=?]", "safari-ball.png",
      false, "a method this stop has no Pokemon for gets no box"
  end

  test "a section header tallies only the species its own method finds" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-15")

    assert_response :success
    assert_select "#catchsec-cinnabar-island-fossil .pn-wt-catchsec__label", text: "Revived fossils"
    assert_select "#catchsec-cinnabar-island-fossil .pn-wt-catchsec__icon img[src*=?]",
      "walkthrough/items/dome-fossil.png"
    assert_select "#catchsec-cinnabar-island-fossil " \
                  "[data-progress-toggle-target='count'][data-progress-ids='138 140 142']"
  end

  test "each section folds on its own, keyed by the stop and the method" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select "#catchsec-route-24-grass.pn-wt-catchsec.is-open" \
                  "[data-controller='section-fold']" \
                  "[data-section-fold-game-value='yellow']" \
                  "[data-section-fold-id-value='route-24/grass']"
    assert_select "#catchsec-route-24-grass .pn-wt-catchsec__head" \
                  "[aria-expanded='true'][aria-controls='catchsec-route-24-grass-body']"
    assert_select "#catchsec-route-24-grass-body[data-section-fold-target='body']"
  end

  test "a gift gated by a badge (Squirtle) shows that badge as its unlock icon" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-06")

    assert_response :success
    assert_select ".pn-wt-catch--gift .pn-wt-catch__gift-from", text: "FROM OFFICER JENNY"
    assert_select ".pn-wt-catch__unlock-text", text: "Beat Lt. Surge for the Thunder Badge"
    assert_select "img.pn-wt-catch__unlock-sprite[src*=?]", "badges/thunder.png"
  end

  test "each gym's grid takes an identity colour, cycling by badge order" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-03")
    assert_response :success
    assert_select ".pn-wt-gym.pn-wt-gym--magenta" # Brock, gym 1

    get walkthrough_leg_path(game: "yellow", leg: "leg-04")
    assert_response :success
    assert_select ".pn-wt-gym.pn-wt-gym--cyan" # Misty, gym 2
  end

  test "the walkthrough index surfaces the Mew glitch as a special, off the timeline" do
    get walkthrough_path(game: "yellow")

    assert_response :success
    assert_select ".pn-wt-specials a.pn-wt-special[href*=?]", "/walkthroughs/yellow/mew-glitch"
    assert_select ".pn-wt-special__name", text: "The Mew glitch"
    assert_select ".pn-wt-steps a[href*='/mew-glitch']", count: 0
  end

  test "the mode switches ride the nav on every walkthrough page and stay off the landing page" do
    get walkthrough_path(game: "yellow")

    assert_response :success
    assert_select ".porynet[data-controller~='mode-toggle'][data-mode-toggle-game-value=?]", "yellow"
    assert_select ".pn-nav__modes .pn-modesw[data-mode='living'][aria-pressed='false']"
    assert_select ".pn-nav__modes .pn-modesw[data-mode='oak'][aria-pressed='false']"
    assert_select ".pn-wt-modechip[data-mode='living']"
    assert_select ".pn-wt-modechip[data-mode='oak']"
    assert_select ".pn-wt-modeid__cta[data-mode='living']"
    assert_select ".pn-wt-modeid__cta[data-mode='oak']"

    get walkthrough_mew_glitch_path(game: "yellow")
    assert_select ".pn-nav__modes .pn-modesw", count: 2

    get root_path
    assert_select ".pn-nav__modes", count: 0
  end

  test "the one menu carries the links everywhere and the mode rows only in a walkthrough" do
    get walkthrough_path(game: "yellow")

    assert_response :success
    assert_select ".pn-nav[data-controller='disclosure']"
    assert_select ".pn-nav__account-toggle[aria-expanded='false'][aria-controls='pn-nav-menu']"
    assert_select "#pn-nav-menu[hidden]"
    assert_select "#pn-nav-menu .pn-nav__menu-link.is-active", text: "Walkthroughs"
    assert_select "#pn-nav-menu .pn-nav__menu-mode[data-mode='living'][aria-pressed='false']"
    assert_select "#pn-nav-menu .pn-nav__menu-mode[data-mode='oak'][aria-pressed='false']"

    get root_path
    assert_select "#pn-nav-menu .pn-nav__menu-link.is-active", text: "Home"
    assert_select "#pn-nav-menu .pn-nav__menu-mode", count: 0
  end

  test "the Mew glitch route is recognized and 404s for an unknown game" do
    assert_equal({ controller: "walkthroughs", action: "mew_glitch", game: "yellow" },
      Rails.application.routes.recognize_path("/walkthroughs/yellow/mew-glitch"))

    get "/walkthroughs/red/mew-glitch"
    assert_response :not_found
  end

  test "Indigo Plateau draws the Elite Four as plates instead of the trainer grid" do
    get walkthrough_leg_path(game: "yellow", leg: "indigo-plateau")

    assert_response :success
    assert_select ".pn-wt-step", count: 2
    assert_select ".pn-wt-step__title", text: "Walk straight through"
    assert_select ".pn-wt-step__title", text: "Fly back for the last cave"
    assert_select ".pn-wt-step__text a[href=?]",
      walkthrough_leg_path(game: "yellow", leg: "leg-19", anchor: "route-4-return-step-1")
    assert_select ".pn-wt-trainers", false, "the plates replace the grid"
    assert_select ".pn-plate", count: 4
    assert_select ".pn-plate--cyan .pn-plate__name", text: "Lorelei"
    assert_select ".pn-plate--magenta .pn-plate__name", text: "Agatha"
    assert_select ".pn-plate__chip", count: 20
    assert_select ".pn-plate__chip--ace .pn-plate__chip-name", text: "Lapras"
    assert_select ".pn-plate__art[src*=?]", "walkthrough/art/lorelei-art.png"
    assert_select ".pn-e4-brief__tile", count: 4
    assert_select "[data-progress-ids=?]",
      "indigo-plateau/trainer-lorelei indigo-plateau/trainer-bruno " \
      "indigo-plateau/trainer-agatha indigo-plateau/trainer-lance indigo-plateau/trainer-blue"
  end

  test "the Champion ships all three rosters and opens on the Jolteon one" do
    get walkthrough_leg_path(game: "yellow", leg: "indigo-plateau")

    assert_response :success
    assert_select ".pn-throne[data-progress-id=?]", "indigo-plateau/trainer-blue"
    assert_select ".pn-gbscreen__img[src*=?]", "battles/battle-champion.png"
    assert_select ".pn-throne__tab", count: 3
    assert_select ".pn-throne__tab.is-active", text: /JOLTEON/
    assert_select "[data-champion-team-target=panel]", count: 3
    assert_select "[data-champion-team-target=panel][data-team=jolteon]:not([hidden])", count: 1
    assert_select "[data-champion-team-target=panel][hidden]", count: 2
    assert_select "[data-team=vaporeon] .pn-throne__mon.is-ace .pn-throne__mon-name", text: "Vaporeon"
    assert_select ".pn-congrats__hero-img[src*=?]", "walkthrough/art/gen1-hall-of-fame-sugimori.png"
  end

  test "the League page renders in Portuguese" do
    get walkthrough_leg_path(game: "yellow", leg: "indigo-plateau", locale: :pt)

    assert_response :success
    assert_select ".pn-wt-step__title", text: "Siga em frente"
    assert_select ".pn-plate__rail-txt", text: "GELO · SALA 01"
    assert_select ".pn-throne__name", text: "Blue"
    assert_select ".pn-congrats__title", text: "Parabéns, Campeão"
  end

  test "an unknown game, leg, or a merged location returns 404" do
    get "/walkthroughs/red"
    assert_response :not_found

    get "/walkthroughs/yellow/nope"
    assert_response :not_found

    get "/walkthroughs/yellow/route-1"
    assert_response :not_found
  end

  test "a trainer who has been playing as a guest is offered the sync on every page of a game" do
    sign_in users(:confirmed)

    [ walkthrough_path(game: "yellow"),
      walkthrough_leg_path(game: "yellow", leg: "leg-01"),
      walkthrough_leg_path(game: "yellow", leg: "indigo-plateau"),
      walkthrough_mew_glitch_path(game: "yellow") ].each do |page|
      get page

      assert_select ".pn-sync[data-sync-banner-url-value=?]",
        walkthrough_sync_path(game: "yellow"), count: 1, message: "no sync banner on #{page}"
    end
  end

  test "the sync banner draws all three of its states up front, so no wording lives in JS" do
    sign_in users(:confirmed)

    get walkthrough_path(game: "yellow")

    assert_select ".pn-sync[hidden]"
    assert_select ".pn-sync__state", count: 3
    assert_select ".pn-sync__state--syncing .pn-sync__title", text: "Uploading your local dex to Porynet"
    assert_select ".pn-sync__state--done .pn-sync__title", text: "Your progress is on your account now"
    assert_select ".pn-sync__state--failed .pn-sync__title", text: "We could not reach the Porynet server"
    assert_select ".pn-sync__note", text: /ash@pallet\.town/
    assert_select ".pn-sync__num[data-sync-banner-target=?]", "sent"
  end

  test "the sync banner speaks Portuguese too" do
    sign_in users(:confirmed)

    get walkthrough_path(game: "yellow", locale: :pt)

    assert_select ".pn-sync__state--syncing .pn-sync__title", text: "Enviando sua dex local para a Porynet"
    assert_select ".pn-sync[data-sync-banner-url-value=?]",
      walkthrough_sync_path(game: "yellow", locale: :pt)
  end

  test "a guest keeps their progress in the browser and is never offered the sync" do
    get walkthrough_path(game: "yellow")

    assert_select ".pn-sync", count: 0
  end

  test "a synced trainer's page renders from the save file, not the browser" do
    sign_in users(:confirmed)
    save_files(:ash_yellow).update!(imported_at: Time.current)

    get walkthrough_path(game: "yellow")

    assert_select ".porynet[data-progress-adopted=?]", "true"
    state = JSON.parse(css_select(".porynet").first["data-progress-state"])
    assert_equal({ walkthrough_marks(:moon_stone).mark_id => true }, state["collected"]["yellow"])
    assert_equal({ "025" => 2 }, state["bodies"]["yellow"])
    assert_equal({ "025" => true }, state["caught"]["yellow"])
  end

  test "a trainer still holding a guest run keeps rendering from the browser until it lands" do
    sign_in users(:confirmed)

    get walkthrough_path(game: "yellow")

    assert_select ".porynet[data-progress-adopted=?]", "false"
  end

  test "a trainer who has never opened this game reads back an empty save file" do
    sign_in users(:rival)

    get walkthrough_path(game: "yellow")

    assert_select ".porynet[data-progress-adopted=?]", "false"
    state = JSON.parse(css_select(".porynet").first["data-progress-state"])
    assert_equal({ "yellow" => {} }, state["collected"])
  end

  test "a guest's page names no save file to render from" do
    get walkthrough_path(game: "yellow")

    assert_select ".porynet[data-progress-state]", count: 0
  end

  test "a game already taken up stops asking" do
    sign_in users(:confirmed)
    save_files(:ash_yellow).update!(imported_at: Time.current)

    get walkthrough_path(game: "yellow")

    assert_select ".pn-sync", count: 0
  end

  test "the walkthrough routes are recognized" do
    assert_equal({ controller: "walkthroughs", action: "show", game: "yellow" },
      Rails.application.routes.recognize_path("/walkthroughs/yellow"))
    assert_equal({ controller: "walkthroughs", action: "leg", game: "yellow", leg: "leg-01" },
      Rails.application.routes.recognize_path("/walkthroughs/yellow/leg-01"))
  end
end
