require "test_helper"

class WalkthroughVersionsTest < ActiveSupport::TestCase
  def versions = Walkthrough::Versions.all
  def find(slug) = versions.find { |version| version.slug == slug }

  test "the catalogue lists the five Gen 1 versions in routing order" do
    assert_equal %w[yellow red blue green yellow-legacy], versions.map(&:slug)
    assert_equal "Pokémon Yellow Legacy", find("yellow-legacy").name
    assert_equal "green-jp", find("green").cover
  end

  test "a version is live exactly when a walkthrough exists under its slug" do
    live, planned = versions.partition(&:live?)

    assert_equal %w[yellow], live.map(&:slug)
    assert_equal %w[red blue green yellow-legacy], planned.map(&:slug)
    assert_equal Walkthrough.find!("yellow").legs.size, find("yellow").pages
    assert_predicate find("red").pages, :zero?
  end

  test "every cartridge carries release years and the ROM hack carries none" do
    assert_equal [ "JP 1998", "INTL 1999" ], find("yellow").released
    assert(versions.reject { |version| version.slug == "yellow-legacy" }.all?(&:dated?))
    assert_not_predicate find("yellow-legacy"), :dated?
  end

  test "the marquee names every version" do
    assert_equal [ "RED", "GREEN", "BLUE", "YELLOW", "YELLOW LEGACY" ], Walkthrough::Versions::MARQUEE
  end
end
