require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:michael)
    @sent = []
    PushSubscription.transport = ->(**options) { @sent << options }
  end

  teardown { PushSubscription.transport = ->(**options) { WebPush.payload_send(**options) } }

  test "subscribes this device, sends a test notification, then removes it" do
    get push_subscriptions_path
    assert_select "[data-controller=push][data-push-key-value=?]", VapidKey.public_key

    post push_subscriptions_path, params: { subscription: { endpoint: "https://push.example/1", keys: { p256dh: "key", auth: "secret" } } },
      headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)" }, as: :json
    assert_response :success
    subscription = users(:michael).push_subscriptions.sole
    assert_match(/\AiPhone, /, subscription.name)

    post push_subscriptions_path, params: { subscription: { endpoint: "https://push.example/1", keys: { p256dh: "new", auth: "secret" } } }, as: :json
    assert_equal "new", subscription.reload.p256dh

    post test_push_subscriptions_path
    assert_equal 1, @sent.size
    follow_redirect!
    assert_select "td", /\AiPhone, /

    delete push_subscription_path(subscription)
    assert_not PushSubscription.exists?(subscription.id)
  end

  test "the VAPID key pair is stable and valid" do
    key = WebPush::VapidKey.from_keys(VapidKey.public_key, VapidKey.private_key)
    assert_equal VapidKey.public_key, key.public_key.delete("=")
  end
end
