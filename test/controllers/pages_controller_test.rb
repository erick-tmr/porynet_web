require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "root renders the PORYNET landing page in the default locale" do
    get root_path

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_select "title", /PORYNET/
    assert_select "h1", /Your PC box/
  end

  test "root renders every section in order" do
    get root_path

    [
      "01 · THE KIT",
      "02 · OAK CHALLENGE",
      "03 · THE TRACKER",
      "04 · PORYPC APP · YOUR SAVE, YOUR WAY",
      "05 · ROADMAP"
    ].each do |label|
      assert_includes response.body, label
    end
    assert_includes response.body, "not affiliated with Nintendo"
    assert_includes response.body, "PoryPC works offline"
  end

  test "root wires up the Stimulus controllers with the default city selected" do
    get root_path

    assert_select "[data-controller='oak-toggle city-selector']"
    assert_select ".pn-city-btn.is-active", text: "PEWTER CITY"
    assert_select ".pn-oak-stat__total", text: "12"
  end

  test "the /pt route renders the page in Portuguese" do
    get "/pt"

    assert_response :success
    assert_select "html[lang=?]", "pt"
    assert_includes response.body, "Sua Box do PC,"
    assert_includes response.body, "04 · APP PORYPC · SEU SAVE, DO SEU JEITO"
  end

  test "the shared nav shows the cross-page menu with Home active on the landing page" do
    get root_path

    assert_select "a.pn-nav__link.is-active", text: "Home"
    assert_select "a.pn-nav__link[href=?]", walkthrough_path(game: "yellow"), text: "Walkthroughs"
    assert_select ".pn-footer__link", text: "Walkthroughs"
  end

  test "the default locale keeps a clean URL and offers the Portuguese toggle" do
    get root_path

    assert_select "a.pn-nav__lang[href=?]", "/pt", text: "PT"
  end

  test "the Portuguese page toggles back to the default locale at /" do
    get "/pt"

    assert_select "a.pn-nav__lang[href=?]", "/", text: "EN"
  end

  test "an unsupported locale is not routable" do
    assert_equal({ controller: "pages", action: "home", locale: "pt" },
      Rails.application.routes.recognize_path("/pt"))
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/de")
    end
  end
end
