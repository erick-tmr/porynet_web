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
end
