require "test_helper"

class WalkthroughsControllerTest < ActionDispatch::IntegrationTest
  test "the Yellow index lists the legs and specials with the new framing" do
    get walkthrough_path(game: "yellow")

    assert_response :success
    assert_select "title", /Pokémon Yellow Walkthrough/
    assert_select "a.pn-nav__link.is-active", text: "Walkthroughs"
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
    assert_includes response.body, "A ROTA · 27 PARADAS"
  end

  test "a leg merges its locations into bands with a jump switcher" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select ".pn-nav__crumb-here", text: "LEG 01"
    assert_select ".pn-wt-loc__title", /Pallet Town/
    assert_select "[data-controller='leg-switcher']"
    assert_select ".pn-wt-chip", count: 2
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

  test "an edge marker's hint opens inward so it never scrolls the map sideways" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-02")

    assert_response :success
    # Route 22's east exit hugs the right edge, so its hint opens left, not off the map
    assert_select "[data-map-markers-map-value=?] .pn-mm--hint-left[data-cat=exit] .pn-mm__label",
      "route-22", text: /Viridian City/
    # Viridian City's west exit hugs the left edge, so its hint opens right
    assert_select "[data-map-markers-map-value=?] .pn-mm--hint-right[data-cat=exit] .pn-mm__label",
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
    assert_select ".pn-wt-chip[data-slug='vermilion-city-return']"
    assert_select ".pn-wt-chip[data-slug='route-11']"
    assert_select ".pn-wt-band__title", text: "Route 11"
  end

  test "a leg renders in Portuguese with a gym band, fossils and its leader" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-12", locale: :pt)

    assert_response :success
    assert_select ".pn-wt-band__badge", /VOLCANO/
    assert_select ".pn-wt-tagpill--fossil"
    assert_select ".pn-wt-gym__leader-name", text: /\ABlaine\b/
    assert_select ".pn-wt-oak__chip", text: "MODO DESAFIO OAK"
    assert_select ".pn-wt-ld__chip", text: "MODO LIVING DEX"
    assert_select ".pn-wt-trade__tag", text: "TROCA"
  end

  test "a location renders its in-game trades with give and receive sprites" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-12")

    assert_response :success
    assert_select ".pn-eyebrow-label", text: /IN-GAME TRADES/
    assert_select ".pn-wt-trades .pn-wt-trade", 3
    assert_select ".pn-wt-trade__title", text: "Muk"
    assert_select ".pn-wt-trade__nick", text: /STICKY/
    assert_select ".pn-wt-trade__mon--give img[src*=?]", "pokemon/yellow/115.png"
    assert_select ".pn-wt-trade__mon--get img[src*=?]", "pokemon/yellow/089.png"
  end

  test "each trade card is a tick target that carries a toast and a traded badge" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-12")

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
    # lead-in step, then the gym, then the follow-up "where next" step
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

  test "a special stop renders its own dedicated page with hidden-item pins" do
    get walkthrough_leg_path(game: "yellow", leg: "viridian-forest")

    assert_response :success
    assert_select ".pn-nav__crumb-here", text: "VIRIDIAN FOREST"
    assert_select ".pn-wt-loc__title", /Forest/
    assert_select ".pn-wt-chip", false
    assert_select "img.pn-wt-shot__img[src*=?]", "scenes/viridian-forest-hidden-antidote"
    assert_select ".pn-wt-pin--viridian-forest-antidote"
  end

  test "a trainer-only special hides the catch section but still owes Oak the next gym" do
    get walkthrough_leg_path(game: "yellow", leg: "ss-anne")

    assert_response :success
    assert_select ".pn-wt-catch-grid", false
    assert_select ".pn-wt-ld", false
    assert_select ".pn-wt-trainer__name", text: "Blue"
    # Surge now sits on the far side of the ship, so the ship is inside his deadline window
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
    assert_select ".pn-wt-ldrow", count: 4
    assert_select ".pn-wt-ldrow__spot", text: "ROUTE 24"
    assert_select ".pn-wt-bandledger", count: 4
    assert_select ".pn-wt-chip__work"
    assert_select ".pn-wt-catchbadge--elsewhere", text: /DO IT AT ROUTE 24/
    assert_select ".pn-wt-catchbadge--boxed", text: "ALREADY BOXED"

    assert_select ".pn-wt-catch--gift .pn-wt-catch__badges .pn-wt-catchbadge--living"
    assert_select ".pn-wt-catch--gift .pn-wt-catch__gift-from", text: "FROM THE HILLTOP BOY"
    assert_select ".pn-wt-catch[data-body-counter-dex-value='004'] .pn-wt-tagpill", count: 1,
      text: "GIFT"
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

  test "the Safari Zone sits inside the Koga window now that it precedes his gym" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-09")

    assert_response :success
    assert_select ".pn-wt-oak__window", text: "WINDOW 05 · EVERYTHING BEFORE KOGA"
    assert_select ".pn-wt-band__title", text: "Safari Zone"
    assert_select ".pn-wt-gym__leader-name", text: /\AKoga\b/
  end

  test "the endgame page names the League rather than a leader it does not have" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-14")

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
    # Jessie & James (the only trainer here with a battle shot) is pulled into a feature row that
    # carries the battle screen; the rest of Mt. Moon's trainers stay in the plain grid.
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

  test "Celadon renders the multi-floor department store with an elevator" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-08")

    assert_response :success
    assert_select "[data-controller='dept-store']"
    assert_select ".pn-wt-store__entry", 6
    assert_select ".pn-wt-store__stat-num", text: "9"
    # a sold TM shows its number and move, the rooftop trades a drink for one
    assert_select ".pn-wt-mart__name", text: "TM09 · Take Down"
    assert_select ".pn-wt-store__trade-move", text: "Ice Beam"
    # Lavender's plain mart sits in the same leg, so both mart shapes render together
    assert_select ".pn-wt-mart"
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
    # the calculator wires 13 stage buttons to the Stimulus controller, default stage 0 = Lv 7
    assert_select "[data-controller='mew-level'] .pn-mew-stage", count: 13
    assert_select ".pn-mew-stage.is-active", text: "0"
    assert_select "[data-mew-level-target='level']", text: "7"
    assert_select ".pn-mew-recipe", count: 13
    assert_select "img[src*=?]", "walkthrough/yellow/art/mew-sugimori.png"
    assert_select "img[src*=?]", "walkthrough/yellow/art/red-and-mew.png"
    # 10 of the 12 steps carry a shot; the two battle-frame steps (Mew appears, catch it) have
    # none, so no step renders the empty placeholder.
    assert_select ".pn-mew-step .pn-wt-shot", count: 10
    assert_select ".pn-mew-step .pn-wt-shot--step", count: 0
    # the second-Mew heads-up step warns off the Route 25 Slowpoke Youngster, reusing his WHERE
    # frame, and wears the same amber warning panel as the "do not beat" step
    assert_select ".pn-mew-step--warn .pn-mew-step__tag--purple", text: "SECOND MEW"
    assert_select ".pn-mew-step img[src*=?]", "walkthrough/yellow/scenes/route-25-trainer-18-5.png"
    assert_select "img[src*=?]", "walkthrough/yellow/scenes/mew-glitch-route24.png"
    assert_select "img[src*=?]", "walkthrough/yellow/battles/mew-glitch-swimmer.png"
  end

  test "the Mew glitch page renders in Portuguese" do
    get walkthrough_mew_glitch_path(game: "yellow", locale: :pt)

    assert_response :success
    assert_select "html[lang=?]", "pt"
    assert_select ".pn-nav__crumb-here--glitch", text: "GLITCH DO MEW"
  end

  test "the Cerulean Mew section teases the glitch guide and warns on the Swimmer and Misty" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select ".pn-mew-teaser a[href*=?]", "/walkthroughs/yellow/mew-glitch"
    # the Swimmer and Misty carry the Mew-glitch caption; the Jr. Trainer does not
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
    # the Cerulean band itself ends at step 3, with no gym and no "after the gym" section
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

  test "Cerulean carries the collapsible Pikachu friendship explainer, hidden by default" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    assert_select "#friendship .pn-fs[data-controller='disclosure']"
    assert_select ".pn-fs__body[hidden]"
    # the game-verified friendship table: a header row plus 11 action rows
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
    # the head, the warning and the way out of the section stay readable while folded
    assert_select ".pn-ls__head .pn-ls__title", text: "Four Trainers to leave standing"
    assert_select ".pn-ls__intro"
    assert_select ".pn-ls__foot .pn-ls__cta"
  end

  test "a gift Pokemon sits in its own row above the wild grid, as a gift card" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-04")

    assert_response :success
    # Route 24's Charmander is a gift: badge + source, in the gifts row, and unconditional (no box)
    assert_select ".pn-wt-catch-grid--gifts .pn-wt-catch__gift-from", text: "FROM THE HILLTOP BOY"
    assert_select "#catchsec-route-24-gift .pn-wt-catch-grid--gifts .pn-wt-catch--gift .pn-wt-catch__name",
      text: "Charmander"
    # the wild grass mons stay in the separate wild grid
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
    get walkthrough_leg_path(game: "yellow", leg: "leg-12")

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

  test "the burger panel carries the links everywhere and the mode rows only in a walkthrough" do
    get walkthrough_path(game: "yellow")

    assert_response :success
    assert_select ".pn-nav[data-controller='nav-menu']"
    assert_select ".pn-nav__burger[aria-expanded='false'][aria-controls='pn-nav-panel']"
    assert_select "#pn-nav-panel .pn-nav__panel-link", count: 3
    assert_select "#pn-nav-panel .pn-nav__panel-link.is-active", text: "Walkthroughs"
    assert_select "#pn-nav-panel .pn-nav__panel-mode[data-mode='living'][aria-pressed='false']"
    assert_select "#pn-nav-panel .pn-nav__panel-mode[data-mode='oak'][aria-pressed='false']"

    get root_path
    assert_select "#pn-nav-panel .pn-nav__panel-link", count: 3
    assert_select "#pn-nav-panel .pn-nav__panel-link.is-active", text: "Home"
    assert_select "#pn-nav-panel .pn-nav__panel-mode", count: 0
  end

  test "the Mew glitch route is recognized and 404s for an unknown game" do
    assert_equal({ controller: "walkthroughs", action: "mew_glitch", game: "yellow" },
      Rails.application.routes.recognize_path("/walkthroughs/yellow/mew-glitch"))

    get "/walkthroughs/red/mew-glitch"
    assert_response :not_found
  end

  test "an unknown game, leg, or a merged location returns 404" do
    get "/walkthroughs/red"
    assert_response :not_found

    get "/walkthroughs/yellow/nope"
    assert_response :not_found

    get "/walkthroughs/yellow/route-1"
    assert_response :not_found
  end

  test "the walkthrough routes are recognized" do
    assert_equal({ controller: "walkthroughs", action: "show", game: "yellow" },
      Rails.application.routes.recognize_path("/walkthroughs/yellow"))
    assert_equal({ controller: "walkthroughs", action: "leg", game: "yellow", leg: "leg-01" },
      Rails.application.routes.recognize_path("/walkthroughs/yellow/leg-01"))
  end
end
