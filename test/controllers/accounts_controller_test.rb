require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "requires a signed in user" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "a member of a single account goes straight to it" do
    sign_in_as users(:mohammad)
    get root_path
    assert_redirected_to account_root_path(account_id: accounts(:semisto).id)
  end

  test "staff can create an account and invite its first admin without joining it" do
    sign_in_as users(:michael)

    assert_difference -> { Account.count } => 1, -> { Invitation.count } => 1 do
      assert_enqueued_emails 1 do
        post accounts_path, params: { account: { name: "Super Génial", admin_email: "Marco@Example.com" } }
      end
    end

    account = Account.find_by!(name: "Super Génial")
    assert_redirected_to accounts_path
    assert_equal [ "marco@example.com", "admin" ], account.invitations.sole.values_at(:email_address, :role)
    assert_empty account.memberships
  end

  test "an invalid account is not created" do
    sign_in_as users(:michael)
    assert_no_difference -> { Account.count } do
      post accounts_path, params: { account: { name: "", admin_email: "pas-un-email" } }
    end
    assert_response :unprocessable_entity
  end

  test "only staff can create accounts" do
    sign_in_as users(:lea)
    assert_no_difference -> { Account.count } do
      post accounts_path, params: { account: { name: "Intrus", admin_email: "x@example.com" } }
    end
    assert_redirected_to accounts_path
  end

  test "a member of several accounts switches from the sidebar and comes back to the last one" do
    with_account(accounts(:silvea)) { accounts(:silvea).memberships.create!(user: users(:mohammad), role: "member") }
    sign_in_as users(:mohammad)

    get root_path
    assert_response :success

    get account_root_path(account_id: accounts(:semisto).id)
    assert_select ".account-switcher summary[data-shortcut='g c']", /Semisto/
    assert_select ".account-switcher nav a[aria-current]", "Semisto"
    assert_select ".account-switcher nav a[href=?]", account_root_path(account_id: accounts(:silvea).id), "Silvéa"

    get account_root_path(account_id: accounts(:silvea).id)
    get root_path
    assert_redirected_to account_root_path(account_id: accounts(:silvea).id)

    get accounts_path
    assert_response :success
  end

  test "a member of a single account has no switcher" do
    sign_in_as users(:mohammad)
    get account_root_path(account_id: accounts(:semisto).id)
    assert_select ".account-switcher", count: 0
    assert_select ".brand .account", "Semisto"
  end
end
