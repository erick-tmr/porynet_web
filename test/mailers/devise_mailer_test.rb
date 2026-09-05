require "test_helper"

class DeviseMailerTest < ActionDispatch::IntegrationTest
  REGISTRATION = { trainer_name: "OAK", email: "oak@pallet.town", password: "pikachu123",
                   password_confirmation: "pikachu123", avatar: "red", terms: "1" }.freeze

  test "the confirmation mail greets the trainer by name and links to the English site" do
    post user_registration_path, params: { user: REGISTRATION }
    mail = ActionMailer::Base.deliveries.last

    assert_equal [ "oak@pallet.town" ], mail.to
    assert_equal I18n.t("devise.mailer.confirmation_instructions.subject"), mail.subject
    assert_match "OAK", mail.body.to_s
    assert_match %r{http://example\.com/confirmation\?}, mail.body.to_s
    assert_no_match(/locale/, mail.body.to_s)
  end

  test "a trainer who registered in Portuguese gets a Portuguese mail and a Portuguese link" do
    post "/pt/register", params: { user: REGISTRATION }
    mail = ActionMailer::Base.deliveries.last

    assert_equal I18n.t("devise.mailer.confirmation_instructions.subject", locale: :pt), mail.subject
    assert_match I18n.t("devise.mailer.confirmation_instructions.action", locale: :pt), mail.body.to_s
    assert_match %r{http://example\.com/pt/confirmation\?}, mail.body.to_s
  end

  test "the reset mail links to the page that takes the new password" do
    post user_password_path, params: { user: { email: users(:confirmed).email } }
    mail = ActionMailer::Base.deliveries.last

    assert_equal I18n.t("devise.mailer.reset_password_instructions.subject"), mail.subject
    assert_match "ASH", mail.body.to_s
    assert_match %r{http://example\.com/password/edit\?reset_password_token=}, mail.body.to_s
  end
end
