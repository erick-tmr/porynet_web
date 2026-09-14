require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "a trainer needs a name, an address, a password and the fan-project tick" do
    assert_predicate build, :valid?
    assert_not build(terms: "0").valid?
    assert_not build(trainer_name: nil).valid?
    assert_not build(email: nil).valid?
    assert_not build(password: nil, password_confirmation: nil).valid?
  end

  test "a trainer name is 2 to 12 characters of the game's own alphabet" do
    assert_predicate build(trainer_name: "AB"), :valid?
    assert_predicate build(trainer_name: "RED_2.0-X"), :valid?
    assert_not build(trainer_name: "A").valid?
    assert_not build(trainer_name: "THIRTEEN_CHAR").valid?
    assert_not build(trainer_name: "ASH KETCHUM").valid?
    assert_not build(trainer_name: "ash!").valid?
  end

  test "two trainers cannot take the same name in different cases" do
    taken = build(trainer_name: users(:confirmed).trainer_name.downcase)

    assert_not taken.valid?
    assert_includes taken.errors[:trainer_name], "has already been taken"
  end

  test "a trainer name is stored without the spaces around it" do
    assert_equal "ASH2", build(trainer_name: "  ASH2  ").tap(&:valid?).trainer_name
  end

  test "the avatar is one of the trainers the roster offers" do
    User::AVATARS.each { |avatar| assert_predicate build(avatar: avatar), :valid? }
    assert_not build(avatar: "porygon").valid?
  end

  test "accepting the terms stamps when they were accepted" do
    trainer = build
    trainer.save!

    assert_in_delta Time.current, trainer.terms_accepted_at, 5.seconds
  end

  test "login falls back to the trainer name until something is typed into the field" do
    trainer = build

    assert_equal "OAK", trainer.login

    trainer.login = "oak@pallet.town"

    assert_equal "oak@pallet.town", trainer.login
  end

  test "signing in works off the trainer name or the address, in any case" do
    ash = users(:confirmed)

    assert_equal ash, User.find_for_database_authentication(login: "ASH")
    assert_equal ash, User.find_for_database_authentication(login: "ash")
    assert_equal ash, User.find_for_database_authentication(login: "  ASH@PALLET.TOWN ")
    assert_nil User.find_for_database_authentication(login: "brock@pallet.town")
  end

  test "an empty login field matches nobody rather than the first row" do
    assert_nil User.find_for_database_authentication(login: "")
    assert_nil User.find_for_database_authentication(login: nil)
  end

  test "a trainer arriving through a provider needs no password" do
    user = build(password: nil, password_confirmation: nil)
    user.identities.build(provider: "google", uid: "1")

    assert user.valid?
    assert_not user.password_set?
  end

  test "a trainer arriving with no provider still needs a password" do
    user = build(password: nil, password_confirmation: nil)

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :password
  end

  test "a password set later is still held to the length rule" do
    daisy = users(:linked)

    assert_not daisy.update(password: "short", password_confirmation: "short")
    assert_includes daisy.errors.attribute_names, :password
    assert daisy.update(password: "pikachu123", password_confirmation: "pikachu123")
    assert daisy.reload.password_set?
  end

  test "a linked trainer can change what is not their password" do
    assert users(:linked).update(avatar: "blue")
  end

  test "an empty password never authenticates" do
    daisy = users(:linked)

    assert_not daisy.valid_password?("")
    assert_not daisy.valid_password?("pikachu123")
  end

  test "a provider login is the sole way in only while no password is set" do
    assert users(:linked).sole_way_in?
    assert_not users(:rival).sole_way_in?, "GARY has a password as well as Google"
  end

  private

  def build(**overrides)
    User.new({ trainer_name: "OAK", email: "oak@pallet.town", password: "pikachu123",
               password_confirmation: "pikachu123", avatar: "red", terms: "1" }.merge(overrides))
  end
end
