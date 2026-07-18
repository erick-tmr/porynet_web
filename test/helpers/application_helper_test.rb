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
end
