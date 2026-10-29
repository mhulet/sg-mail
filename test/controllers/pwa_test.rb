require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "the manifest and service worker are public, and every page links the manifest" do
    get pwa_manifest_path(format: :json)
    assert_response :success
    assert_equal "SG Mail", response.parsed_body["name"]
    assert_equal "standalone", response.parsed_body["display"]

    get pwa_service_worker_path(format: :js)
    assert_response :success
    assert_includes response.body, "/offline.html"

    get new_session_path
    assert_select "link[rel=manifest][href=?]", "/manifest.json"
  end

  test "the install page is public and offers the button and the steps for each browser" do
    get install_path
    assert_response :success
    assert_select "[data-controller=install] button[data-action='install#install']"
    %w[chromium safari firefox ios android].each { |browser| assert_select "details[data-browser=?]", browser }
  end

  test "signed-in people find the install page in their settings" do
    sign_in_as users(:michael)
    get push_subscriptions_path
    assert_select "a.install-link[href=?]", install_path
  end
end
