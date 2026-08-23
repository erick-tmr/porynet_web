require "test_helper"

class I18nParityTest < ActiveSupport::TestCase
  LOCALES = Rails.root.glob("config/locales/*.yml").freeze

  test "every locale defines exactly the same set of keys" do
    key_sets = LOCALES.to_h do |path|
      locale = File.basename(path, ".yml")
      [ locale, leaf_keys(YAML.safe_load_file(path).fetch(locale)) ]
    end

    reference_locale, reference_keys = key_sets.first
    key_sets.each do |locale, keys|
      assert_equal reference_keys, keys,
        "#{locale}.yml keys differ from #{reference_locale}.yml " \
        "(missing: #{(reference_keys - keys).sort}; extra: #{(keys - reference_keys).sort})"
    end
  end

  # A grid coordinate is a fact about the map file, not an instruction: nobody plays with a finger
  # on tile (11,14), and a reader who wanted to find it would have to count squares from a corner.
  # Every place worth naming has a landmark to name it by, which is how the rest of the corpus
  # reads ("against the far west wall of 1F", "the lone rock east of TM01").
  GRID = /\(\d+,\s*\d+\)/

  test "no copy sends the player to a grid coordinate" do
    counted = LOCALES.flat_map do |path|
      locale = File.basename(path, ".yml")
      leaf_strings(YAML.safe_load_file(path).fetch(locale))
        .select { |_key, text| text.match?(GRID) }
        .map { |key, text| "#{locale}.#{key}: #{text}" }
    end

    assert_empty counted, "these lines tell the player to count tiles"
  end

  private

  def leaf_strings(value, prefix = nil)
    return [ [ prefix, value ] ] if value.is_a?(String)
    return [] unless value.is_a?(Hash)

    value.flat_map { |key, nested| leaf_strings(nested, [ prefix, key ].compact.join(".")) }
  end

  def leaf_keys(value, prefix = nil)
    return [ prefix ] unless value.is_a?(Hash)

    value.flat_map do |key, nested|
      leaf_keys(nested, [ prefix, key ].compact.join("."))
    end.sort
  end
end
