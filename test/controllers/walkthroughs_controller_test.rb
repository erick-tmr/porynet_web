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
    assert_includes response.body, "OAK CHALLENGE · FIRST CATCHES"
  end

  test "the index renders in Portuguese" do
    get walkthrough_path(game: "yellow", locale: :pt)

    assert_response :success
    assert_select "html[lang=?]", "pt"
    assert_includes response.body, "A ROTA · 26 PARADAS"
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
    assert_includes response.body, "Best rate at 35%, and the earliest place to catch Rattata"
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
    assert_select "[data-map-markers-map-value=?] .pn-mm[data-cat=npc] .pn-mm__label-key", "pallet-town", text: "A"
    assert_select "[data-map-markers-map-value=?] .pn-mm[data-cat=npc] [aria-pressed]", "pallet-town", false
    assert_select ".pn-mm-legend__title", text: "IMPORTANT NPCS"
    assert_includes response.body, "Technology is incredible"
  end

  test "an interior map fills a step screenshot slot" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select ".pn-wt-shot--map img.pn-wt-shot__map-img[src*=?]", "walkthrough/yellow/maps/reds-house-2f.png"
    assert_select ".pn-wt-shot--map img.pn-wt-shot__map-img[src*=?]", "walkthrough/yellow/scenes/pallet-town-exit.png"
  end

  test "a single-location leg drops the switcher" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-06")

    assert_response :success
    assert_select "[data-controller='leg-switcher']", false
    assert_select ".pn-wt-loc__title", text: "Route 11"
  end

  test "a leg renders in Portuguese with a gym band, fossils and its leader" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-12", locale: :pt)

    assert_response :success
    assert_select ".pn-wt-band__badge", /VOLCANO/
    assert_select ".pn-wt-tagpill--fossil"
    assert_select ".pn-wt-gym__leader-name", text: "Blaine"
    assert_select ".pn-wt-band-oak"
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
    assert_select ".pn-wt-gym-tr__cls", text: "JR. TRAINER♂"
    assert_select ".pn-wt-gym__leader-name", text: "Brock"
    assert_select ".pn-wt-gym__badge-name", text: "BOULDER"
    assert_select "img.pn-wt-gym__badge-img[src*=?]", "badges/boulder"
    assert_select ".pn-wt-gym__puzzle", false
    # lead-in step, then the gym, then the follow-up "where next" step
    assert_select ".pn-wt-step__title", text: "Heal, prep, and enter the Gym"
    assert_select ".pn-eyebrow-label", text: /AFTER THE GYM/
    assert_select ".pn-wt-step__title", text: "Head east to Route 3"
  end

  test "a maze gym renders its puzzle solution steps" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-05")

    assert_response :success
    assert_select ".pn-wt-gym__name", text: "Vermilion Gym"
    assert_select ".pn-wt-gym__leader-name", text: "Lt. Surge"
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
    assert_select "img.pn-wt-shot__img[src*=?]", "scenes/viridian-forest-antidote"
    assert_select ".pn-wt-pin--vf-antidote"
  end

  test "a trainer-only special hides the catch and Oak sections" do
    get walkthrough_leg_path(game: "yellow", leg: "ss-anne")

    assert_response :success
    assert_select ".pn-wt-catch-grid", false
    assert_select ".pn-wt-oak", false
    assert_select ".pn-wt-trainer__name", text: "Blue"
  end

  test "the first and last stops omit prev and next respectively" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")
    assert_response :success
    assert_select ".pn-wt-nav__link", count: 1

    get walkthrough_leg_path(game: "yellow", leg: "cerulean-cave")
    assert_response :success
    assert_select ".pn-wt-nav__link--next", false
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
