require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "accent_last wraps the final word in an accent span" do
    assert_equal 'Pokémon <span class="pn-accent">Yellow</span>', accent_last("Pokémon Yellow")
    assert_equal 'Viridian <span class="pn-accent">Forest</span>', accent_last("Viridian Forest")
  end

  test "accent_last leaves a single word untouched and escaped" do
    assert_equal "Route", accent_last("Route")
    assert_equal "A&amp;B", accent_last("A&B")
  end

  test "r2_asset_url prefixes the path with the R2 public host" do
    host = Rails.application.config.x.r2_public_host
    assert_equal "#{host}/pokemon/yellow/025.png", r2_asset_url("pokemon/yellow/025.png")
  end

  test "r2_image_tag renders an img whose src is the R2 URL and forwards options" do
    host = Rails.application.config.x.r2_public_host
    html = r2_image_tag("porygon.png", alt: "Porygon", class: "pn-hero__mascot")

    assert_includes html, %(src="#{host}/porygon.png")
    assert_includes html, 'alt="Porygon"'
    assert_includes html, 'class="pn-hero__mascot"'
  end

  test "best_catch_reason compares the two spots when a species has a rival location" do
    best = Walkthrough::BestCatch.new(
      dex: "016", slug: "route-1", rate: "70%", alt_name: "Route 5", alt_rate: "40%"
    )

    assert_equal "70% here versus 40% at Route 5, the best odds for Pidgey.",
      best_catch_reason(best, encounter("016", "Pidgey"))
  end

  test "best_catch_reason falls back to the earliest location on a tie" do
    best = Walkthrough::BestCatch.new(
      dex: "019", slug: "route-2", rate: "35%", tie: true, alt_name: "Route 4", alt_rate: "35%"
    )

    assert_equal "Best rate at 35%, and the earliest place to catch Rattata.",
      best_catch_reason(best, encounter("019", "Rattata"))
  end

  test "best_catch_reason quotes the rate for a species with a single rated location" do
    best = Walkthrough::BestCatch.new(dex: "063", slug: "route-24", rate: "10%", only: true)

    assert_equal "The only place in the game to catch Abra, at 10%.",
      best_catch_reason(best, encounter("063", "Abra"))
  end

  test "best_catch_reason says a species lives elsewhere too, just behind a later rod" do
    best = Walkthrough::BestCatch.new(dex: "119", slug: "cerulean-cave", rate: "15%",
                                      armed_only: true)

    assert_equal "The only stop you reach already equipped for Seaking. The rest come before the rod.",
      best_catch_reason(best, encounter("119", "Seaking"))
  end

  test "best_catch_reason drops the rate for a static with no percentage to quote" do
    best = Walkthrough::BestCatch.new(dex: "150", slug: "cerulean-cave", rate: nil, only: true)

    assert_equal "The only place in the game to catch Mewtwo. Miss it here and you miss it.",
      best_catch_reason(best, encounter("150", "Mewtwo"))
  end

  private

  def encounter(dex, name)
    Walkthrough::Encounter.new(
      dex: dex, name: name, how: "GRASS", rate: "10%", level: "10",
      rarity: "COMMON", tip_key: nil, evo_line: []
    )
  end

  test "the page root carries both walkthrough controllers, each scoped to the same game" do
    attrs = walkthrough_page_controller(Walkthrough.find!("yellow"))

    assert_includes attrs, 'data-controller="progress-toggle mode-toggle"'
    assert_includes attrs, 'data-progress-toggle-game-value="yellow"'
    assert_includes attrs, 'data-mode-toggle-game-value="yellow"'
  end

  test "an exit hint speaks about the place behind the door, not the door" do
    door = Walkthrough::MapMarker.new(
      id: "exit-5-5", cat: "exit", name: "Reds House 1F", x: 1.0, y: 2.0, align: "r",
      edge: "inner", ref: "REDS_HOUSE_1F", place: Walkthrough::Place.new(kind: "house")
    )

    assert_equal I18n.t("walkthrough.ui.map_place_kind_house"), marker_detail(door)
  end

  test "an exit the game says nothing about still says which way it leaves" do
    edge = Walkthrough::MapMarker.new(
      id: "exit-north", cat: "exit", name: "Route 1", x: 1.0, y: 2.0, align: "r",
      edge: "north", ref: "ROUTE_1"
    )

    assert_equal I18n.t("walkthrough.ui.map_exit_north"), marker_detail(edge)
  end

  test "a badge window names its leader, and the last one names the League instead" do
    game = Walkthrough.find!("yellow")
    brock = game.windows.first
    league = game.windows.last

    assert_equal "EVERYTHING BEFORE BROCK", window_label(brock)
    assert_equal "Registered before Brock", window_title(brock)
    assert_equal "SPECIES DUE BY BROCK", window_due_label(brock)

    assert_equal "EVERYTHING LEFT IN THE DEX", window_label(league)
    assert_equal "Registered before the League", window_title(league)
    assert_equal "SPECIES DUE IN ALL", window_due_label(league)
    assert_includes modes_off_body(league), "the dex still owes"
  end

  test "a queued species uses its hand-written line when the stop has one" do
    entry = plan_entry("010", why_key: "walkthrough.ui.ld_why_sole", why_args: { name: "Caterpie" })

    assert_equal "The only Caterpie in the game. Miss it here and you miss it.", challenge_why(entry)
  end

  test "a note reads from its kind, so a new kind cannot render an untranslated tag" do
    note = Walkthrough::ChallengeNote.new(kind: :one_copy, args: { names: "Bulbasaur", count: 1 })

    assert_equal "NO SECOND COPY", challenge_note_tag(note)
    assert_includes challenge_note_text(note), "holds one Bulbasaur and no more"
  end

  test "the spot chip says whether this really is the best place, or merely a good one" do
    best = Walkthrough::BestCatch.new(dex: "010", slug: "viridian-forest", rate: "50%")

    assert_equal "BEST PLACE · 50%", catch_spot(plan_entry("010", best: best))
    assert_equal "GOOD PLACE · 50%", catch_spot(plan_entry("010", best: nil))
  end

  test "a live count slot names the ids it watches so the controller can total them" do
    assert_includes progress_remaining(%w[010 011]), 'data-progress-ids="010 011"'
    assert_includes progress_remaining(%w[010 011]), ">2<"
    assert_includes progress_meter(%w[010]), 'data-progress-toggle-target="meter"'
    assert_includes body_progress(2), 'data-body-counter-target="have"'
  end

  # The Pokédex does not care where you caught it, and neither does the box: catch a Magikarp off
  # Vermilion's dock and Viridian's Old Rod card, four legs before you own a rod, has to show it
  # caught and counted. So a card with no plan entry still wires up both, taking its cover list
  # from the game rather than from a page that never queued the species.
  test "a card the stop cannot catch yet ticks and counts like one it can" do
    @game = Walkthrough.find!("yellow")
    locked = catch_card_attributes("129", nil)

    assert_equal "caught", locked.dig(:data, :kind)
    assert_equal "129", locked.dig(:data, :progress_id)
    assert_equal "item", locked.dig(:data, :progress_toggle_target)
    assert_equal "body-counter", locked.dig(:data, :controller)
    assert_equal "129", locked.dig(:data, :body_counter_dex_value)
    assert_equal @game.covers("129").to_json, locked.dig(:data, :body_counter_covers_value)
  end

  test "a card the stop does catch takes its cover list from the page's own plan" do
    @game = Walkthrough.find!("yellow")
    entry = @game.plan_for(@game.leg!("leg-02")).entry_for("029")
    queued = catch_card_attributes("029", entry)

    assert_equal "029", queued.dig(:data, :progress_id)
    assert_equal "body-counter", queued.dig(:data, :controller)
    assert_equal entry.covers.to_json, queued.dig(:data, :body_counter_covers_value)
  end

  test "a section header tallies only the species that method finds" do
    tally = catch_tally(%w[010 011])

    assert_includes tally, 'data-progress-toggle-target="count"'
    assert_includes tally, 'data-kind="caught"'
    assert_includes tally, 'data-progress-ids="010 011"'
    assert_includes tally, "/ 2 CAUGHT"
  end

  test "a floor row takes the card's own tag when it reads the same table" do
    assert_equal "CAVE", encounter_method_label(place(kind: "grass"), "CAVE"),
      "Mt. Moon reads the grass table, but there is no grass in a cave"
    assert_equal "SAFARI", encounter_method_label(place(kind: "grass"), "SAFARI")
    assert_equal "GRASS", encounter_method_label(place(kind: "grass"), "GRASS")
    assert_equal "GRASS", encounter_method_label(place(kind: "grass"), "SURF"),
      "a land row under a Surf card still says what it really is"
  end

  test "encounter_method_label names every way a place is fished or walked into" do
    assert_equal "GRASS", encounter_method_label(place(kind: "grass"))
    assert_equal "SURF", encounter_method_label(place(kind: "water"))
    assert_equal "OLD ROD", encounter_method_label(place(kind: "old_rod"))
    assert_equal "GOOD ROD", encounter_method_label(place(kind: "good_rod"))
    assert_equal "SUPER ROD", encounter_method_label(place(kind: "super_rod"))
  end

  test "an encounter place answers to the card tag that reads its table" do
    assert place(kind: "grass").method?("CAVE"), "a cave floor reads the grass table"
    assert place(kind: "grass").method?("SAFARI")
    refute place(kind: "grass").method?("SURF")
    assert place(kind: "super_rod").method?("SUPER ROD")
    refute place(kind: "super_rod").method?("GOOD ROD")
    refute place(kind: "grass").method?("STATIC"), "a static encounter reads no table at all"
  end

  test "the floor bar runs proportional to the best floor on the card" do
    best = place(rate: 10.5)

    assert_equal "pn-wt-floors__bar pn-wt-floors__bar--w100", floor_bar_class(best, best)
    assert_equal "pn-wt-floors__bar pn-wt-floors__bar--w50", floor_bar_class(place(rate: 5.25), best)
  end

  test "a barely-there spawn still draws a bar rather than nothing" do
    assert_equal "pn-wt-floors__bar pn-wt-floors__bar--w10",
      floor_bar_class(place(rate: 1.2), place(rate: 10.5)),
      "Clefairy's 1.2% on 1F is 11% of its best floor, so it buckets to 10 rather than vanishing"
    assert_equal "pn-wt-floors__bar pn-wt-floors__bar--w5",
      floor_bar_class(place(rate: 0.1), place(rate: 10.5)),
      "a share under half a step is floored to a sliver, never to an empty track"
  end

  test "a rate of zero fills the bar instead of dividing by it" do
    assert_equal "pn-wt-floors__bar pn-wt-floors__bar--w100",
      floor_bar_class(place(rate: 0), place(rate: 0)),
      "the generator never emits a zero-slot row, but the bar must not raise if one appears"
  end

  test "an encounter place knows a rod from a walk" do
    assert place(kind: "old_rod").rod?
    assert place(kind: "super_rod").rod?
    refute place(kind: "water").rod?
    assert place(kind: "water").surf?
  end

  test "an encounter place reads a single-level floor as one number, not a range" do
    assert_equal "11", place(min_level: 11, max_level: 11).levels
    assert_equal "9–13", place(min_level: 9, max_level: 13).levels
  end

  private

  def place(floor: "1F", kind: "grass", rate: 10.5, min_level: 9, max_level: 13)
    Walkthrough::EncounterPlace.new(floor: floor, kind: kind, rate: rate,
      min_level: min_level, max_level: max_level)
  end

  def plan_entry(dex, **overrides)
    Walkthrough::PlanEntry.new(
      dex: dex, name: "Caterpie", at: "viridian-forest", stop_name: "Viridian Forest", qty: 2,
      covers: [ dex ], chain: [ dex ], fresh: true, boxed: false, done_at: nil, how: "GRASS",
      rate: "50%", best: nil,
      why_key: nil, why_args: {}, **overrides
    )
  end
end
