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
end
