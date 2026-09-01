require "test_helper"

# The League page is the one place a trainer card is the page rather than a cell in a grid, so the
# plates are built off the stop's own cards. These hold the two together.
class WalkthroughLeagueTest < ActiveSupport::TestCase
  def plateau = Walkthrough.find!("yellow").locations.find { |loc| loc.slug == "indigo-plateau" }
  def league = Walkthrough::Yellow.elite_four(plateau)

  test "the plates are the stop's own cards, in the order the doors open" do
    assert_equal %w[lorelei bruno agatha lance], league.members.map(&:key)
    assert_equal [ "Lorelei", "Bruno", "Agatha", "Lance" ],
      league.members.map { |member| member.trainer.name }
    assert_equal plateau.trainers.first(4), league.members.map(&:trainer)
    assert_equal plateau.trainers.last, league.champion.trainer
  end

  test "every room ticks under its own name, and the brief counts all five" do
    assert_equal %w[indigo-plateau/lorelei indigo-plateau/bruno indigo-plateau/agatha
                    indigo-plateau/lance indigo-plateau/blue], league.ticks
  end

  test "the ace is the last slot of a roster, wherever it is drawn" do
    lorelei = league.members.first

    assert lorelei.ace?(4), "Lapras closes her team"
    refute lorelei.ace?(0)
    assert league.champion.teams.first.ace?(5), "the Eeveelution closes his"
    refute league.champion.teams.first.ace?(0)
  end

  # Rival3Data: three parties that share a head and part company over the last three slots.
  test "the Champion's three teams share the card's head and end on their own Eeveelution" do
    teams = league.champion.teams

    assert_equal %w[jolteon flareon vaporeon], teams.map(&:key)
    assert_equal %w[Jolteon Flareon Vaporeon], teams.map(&:name)
    teams.each do |team|
      assert_equal 6, team.team.size
      assert_equal plateau.trainers.last.team.first(3), team.team.first(3)
      assert_equal team.dex, team.team.last[:dex]
      assert_equal 65, team.team.last[:lvl]
    end
  end

  test "the copy hangs off the stop's own locale block" do
    assert_equal "walkthrough.yellow.locations.indigo_plateau.league", league.copy_key
  end

  # Every string the page reads, in both locales: a plate that lost its copy would render the key.
  test "each room and the boards around it are written in every locale" do
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        league.brief.each { |key| assert_brief("#{league.copy_key}.brief.#{key}") }
        assert_brief("#{league.copy_key}.brief.cleared", parts: %w[label note])
        league.members.each { |member| assert_room("#{league.copy_key}.members.#{member.key}") }
        assert_champion("#{league.copy_key}.champion")
        assert_after("#{league.copy_key}.after", league.after)
      end
    end
  end

  private

  def assert_brief(base, parts: %w[label value note])
    parts.each { |part| assert_copy("#{base}.#{part}") }
  end

  def assert_room(base)
    %w[eyebrow heading rail kicker spread line counter door].each { |part| assert_copy("#{base}.#{part}") }
  end

  def assert_champion(base)
    %w[eyebrow heading ribbon stamp sub line screen_label screen_note variant_label warn_label
       warn hof_label hof seal_todo seal_todo_note seal_done seal_done_note].each do |part|
      assert_copy("#{base}.#{part}")
    end
    %w[jolteon flareon vaporeon].each { |key| assert_copy("#{base}.rules.#{key}") }
  end

  def assert_after(base, tiles)
    %w[eyebrow heading kicker title lead art_alt].each { |part| assert_copy("#{base}.#{part}") }
    tiles.each { |key| assert_brief("#{base}.tiles.#{key}", parts: %w[label value]) }
  end

  def assert_copy(key)
    assert I18n.t(key).present?, "#{I18n.locale}: #{key} is blank"
  end
end
