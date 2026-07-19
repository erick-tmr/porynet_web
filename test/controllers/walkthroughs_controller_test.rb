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

  test "a location renders its plain area map without hidden-item markers" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select "img.pn-wt-map__img[src*=?]", "walkthrough/yellow/maps/route-1.png"
    assert_select ".pn-wt-maps .pn-wt-map__marker", false
  end

  test "an interior map fills a step screenshot slot with a positioned marker" do
    get walkthrough_leg_path(game: "yellow", leg: "leg-01")

    assert_response :success
    assert_select ".pn-wt-shot__map[data-controller=?]", "map-markers"
    assert_select "img.pn-wt-shot__map-img[src*=?]", "walkthrough/yellow/maps/reds-house-2f.png"
    assert_select ".pn-wt-map__marker--poi[data-map-markers-target=?]", "marker"
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
    assert_select "img.pn-wt-shot__img[src*=?]", "viridian-forest/antidote"
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
