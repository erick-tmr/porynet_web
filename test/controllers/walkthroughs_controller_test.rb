require "test_helper"

class WalkthroughsControllerTest < ActionDispatch::IntegrationTest
  test "the Yellow index renders the hero, route timeline and Oak summary" do
    get walkthrough_path(game: "yellow")

    assert_response :success
    assert_select "title", /Pokémon Yellow Walkthrough/
    assert_select ".pn-wt-hero__title", /Yellow/
    assert_select ".pn-nav__crumb-here", text: "POKÉMON YELLOW"
    assert_select ".pn-wt-route__name", text: "Viridian Forest"
    assert_select ".pn-wt-route__stat--gym"
    assert_select "a.pn-nav__link.is-active", text: "Walkthroughs"
    assert_includes response.body, "OAK CHALLENGE · FIRST CATCHES"
  end

  test "the Yellow index renders in Portuguese" do
    get walkthrough_path(game: "yellow", locale: :pt)

    assert_response :success
    assert_select "html[lang=?]", "pt"
    assert_includes response.body, "Pallet Town → Indigo Plateau"
    assert_includes response.body, "A ROTA · 49 PARADAS"
  end

  test "the Viridian Forest page renders steps, catch cards, hidden items and trainers" do
    get walkthrough_location_path(game: "yellow", location: "viridian-forest")

    assert_response :success
    assert_select ".pn-nav__crumb-here", text: "VIRIDIAN FOREST"
    assert_select ".pn-wt-step", count: 5
    assert_select ".pn-wt-catch", count: 4
    assert_select ".pn-wt-catch__name", text: "Caterpie"
    assert_select "img.pn-wt-shot__img[src*=?]", "viridian-forest/antidote"
    assert_select ".pn-wt-pin--vf-antidote"
    assert_select ".pn-wt-trainer__name", text: "LASS"
    assert_select "img[src*=?]", "pokemon/010"
    assert_select ".pn-wt-nav__where", text: "Pewter City"
  end

  test "the Viridian Forest page renders in Portuguese" do
    get walkthrough_location_path(game: "yellow", location: "viridian-forest", locale: :pt)

    assert_response :success
    assert_includes response.body, "Seu caminho, passo a passo"
  end

  test "town and boundary pages cover the empty-section and edge branches" do
    get walkthrough_location_path(game: "yellow", location: "pallet-town")
    assert_response :success
    assert_select ".pn-wt-catch__name", text: "Pikachu"
    assert_select ".pn-wt-tagpill--gift"
    assert_select ".pn-wt-oak", false
    assert_select ".pn-wt-nav__link", count: 1

    get walkthrough_location_path(game: "yellow", location: "viridian-city")
    assert_response :success
    assert_select ".pn-wt-catch-grid", false
    assert_select ".pn-wt-trainers", false

    get walkthrough_location_path(game: "yellow", location: "pewter-city")
    assert_response :success
    assert_select ".pn-wt-trainer__name", text: "Brock"

    get walkthrough_location_path(game: "yellow", location: "cerulean-cave")
    assert_response :success
    assert_select ".pn-wt-nav__link--next", false
  end

  test "the wider Kanto pages render mixed tips, method pills and named trainers" do
    get walkthrough_location_path(game: "yellow", location: "mt-moon")
    assert_response :success
    assert_select ".pn-wt-catch__name", text: "Clefairy"
    assert_select ".pn-wt-catch__tip"
    assert_select ".pn-wt-tagpill--cave"
    assert_select ".pn-wt-trainer__name", text: "Jessie & James"

    get walkthrough_location_path(game: "yellow", location: "seafoam-islands")
    assert_response :success
    assert_select ".pn-wt-tagpill--static"

    get walkthrough_location_path(game: "yellow", location: "indigo-plateau")
    assert_response :success
    assert_select ".pn-wt-trainer__name", text: "Lance"
  end

  test "an unknown game or location returns 404" do
    get "/walkthroughs/red"
    assert_response :not_found

    get "/walkthroughs/yellow/nowhere"
    assert_response :not_found
  end

  test "the walkthrough routes are recognized" do
    assert_equal({ controller: "walkthroughs", action: "show", game: "yellow" },
      Rails.application.routes.recognize_path("/walkthroughs/yellow"))
    assert_equal({ controller: "walkthroughs", action: "location", game: "yellow", location: "viridian-forest" },
      Rails.application.routes.recognize_path("/walkthroughs/yellow/viridian-forest"))
  end
end
