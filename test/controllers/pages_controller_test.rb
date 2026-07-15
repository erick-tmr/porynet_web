require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "root renders the PORYNET landing page" do
    get root_path

    assert_response :success
    assert_select "title", /PORYNET/
    assert_select "h1", /Your PC box/
  end

  test "root renders every section in order" do
    get root_path

    %w[
      01\ ·\ THE\ KIT
      02\ ·\ OAK\ CHALLENGE
      03\ ·\ THE\ TRACKER
      04\ ·\ SELF-HOSTED
      05\ ·\ ROADMAP
      06\ ·\ IDENTITY\ ·\ NEON\ MODE
    ].each do |label|
      assert_includes response.body, label
    end
    assert_includes response.body, "not affiliated with Nintendo"
    assert_includes response.body, "porynet/pokehome:latest"
  end

  test "root wires up the Stimulus controllers with the default city selected" do
    get root_path

    assert_select "[data-controller='oak-toggle city-selector']"
    assert_select ".pn-city-btn.is-active", text: "PEWTER CITY"
    assert_select ".pn-oak-stat__total", text: "12"
  end
end
