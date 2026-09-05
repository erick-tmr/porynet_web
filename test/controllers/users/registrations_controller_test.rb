require "test_helper"

module Users
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    test "a registration takes only the fields the form draws" do
      post user_registration_path, params: {
        user: { trainer_name: "OAK", email: "oak@pallet.town", password: "pikachu123",
                password_confirmation: "pikachu123", avatar: "blue", terms: "1",
                confirmed_at: 1.day.ago, encrypted_password: "smuggled" }
      }

      trainer = User.find_by(trainer_name: "OAK")

      assert_equal "blue", trainer.avatar
      assert_nil trainer.confirmed_at
      assert trainer.valid_password?("pikachu123")
    end

    test "a new trainer is sent to the page that says which inbox to open" do
      post user_registration_path, params: {
        user: { trainer_name: "OAK", email: "oak@pallet.town", password: "pikachu123",
                password_confirmation: "pikachu123", avatar: "red", terms: "1" }
      }

      assert_redirected_to new_user_confirmation_path(email: "oak@pallet.town")
      follow_redirect!

      assert_select "[data-confirmation-email]", text: "oak@pallet.town"
    end

    test "a trainer who is already logged in has no reason to see the register form" do
      sign_in users(:confirmed)
      get new_user_registration_path

      assert_redirected_to account_path
    end
  end
end
