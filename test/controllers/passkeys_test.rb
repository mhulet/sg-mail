require "test_helper"
require "webauthn/fake_client"

class PasskeysTest < ActionDispatch::IntegrationTest
  ORIGIN = "http://www.example.com".freeze

  setup { @client = WebAuthn::FakeClient.new(ORIGIN) }

  test "add a passkey, then sign in with it, without an email or password" do
    sign_in_as users(:mohammad)
    post options_passkeys_path, as: :json
    options = response.parsed_body
    assert_equal "www.example.com", options.dig("rp", "id")
    assert_equal "required", options.dig("authenticatorSelection", "residentKey")

    credential = @client.create(challenge: options["challenge"], rp_id: "www.example.com", user_verified: true)
    post passkeys_path, params: { credential: credential }, as: :json
    assert_equal passkeys_path, response.parsed_body["redirect"]
    passkey = users(:mohammad).passkeys.sole
    assert_equal credential["id"], passkey.external_id

    get passkeys_path
    assert_select "td", passkey.name

    delete session_path
    post passkey_session_options_path, as: :json
    challenge = response.parsed_body["challenge"]
    assertion = @client.get(challenge: challenge, rp_id: "www.example.com", user_verified: true)
    post passkey_session_path, params: { credential: assertion }, as: :json
    assert_equal root_url, response.parsed_body["redirect"]
    assert passkey.reload.last_used_at

    get accounts_path
    assert_redirected_to account_root_path(account_id: accounts(:semisto).id) # connecté
  end

  test "an unknown passkey is refused" do
    @client.create(challenge: WebAuthn.standard_encoder.encode(SecureRandom.random_bytes(32)), rp_id: "www.example.com")
    post passkey_session_options_path, as: :json
    assertion = @client.get(challenge: response.parsed_body["challenge"], rp_id: "www.example.com")
    post passkey_session_path, params: { credential: assertion }, as: :json
    assert_response :unauthorized
    assert_equal "Cette passkey n'est pas reconnue.", response.parsed_body["error"]
  end

  test "a registration answering another challenge is refused" do
    sign_in_as users(:mohammad)
    post options_passkeys_path, as: :json
    credential = @client.create(challenge: WebAuthn.standard_encoder.encode(SecureRandom.random_bytes(32)), rp_id: "www.example.com")
    post passkeys_path, params: { credential: credential }, as: :json
    assert_response :unprocessable_entity
    assert_empty users(:mohammad).passkeys
  end

  test "passkeys are personal" do
    passkey = users(:michael).passkeys.create!(external_id: "abc", public_key: "pk", name: "Mac")
    sign_in_as users(:mohammad)
    delete passkey_path(passkey)
    assert_response :not_found
    assert Passkey.exists?(passkey.id)
  end
end
