require "test_helper"

# Guards against locale drift: every translation key must exist in both en.yml
# and pt.yml so neither page ever falls back mid-render. Compares the YAML files
# directly (leaf keys only; array values count as a single leaf).
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

  private

  def leaf_keys(value, prefix = nil)
    return [ prefix ] unless value.is_a?(Hash)

    value.flat_map do |key, nested|
      leaf_keys(nested, [ prefix, key ].compact.join("."))
    end.sort
  end
end
