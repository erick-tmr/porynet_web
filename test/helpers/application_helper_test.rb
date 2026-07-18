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
end
