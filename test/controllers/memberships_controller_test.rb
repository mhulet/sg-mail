require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup { @semisto = accounts(:semisto) }

  test "lists members and pending invitations" do
    sign_in_as users(:michael)
    get memberships_path(account_id: @semisto.id)
    assert_response :success
    assert_select "td", "Mohammad"
    assert_select "td", "nouvelle@example.com"
    assert_select "td", { text: "ancienne@example.com", count: 0 }
  end

  test "an admin invites someone" do
    sign_in_as users(:michael)
    assert_enqueued_emails 1 do
      post invitations_path(account_id: @semisto.id), params: { invitation: { email_address: "silvia@example.com", role: "member" } }
    end
    assert_redirected_to memberships_path(account_id: @semisto.id)
    assert @semisto.invitations.exists?(email_address: "silvia@example.com")
  end

  test "an existing member cannot be invited again" do
    sign_in_as users(:michael)
    assert_no_difference -> { Invitation.count } do
      post invitations_path(account_id: @semisto.id), params: { invitation: { email_address: "mohammad@example.com", role: "member" } }
    end
  end

  test "a member can neither invite nor change roles" do
    sign_in_as users(:mohammad)
    assert_no_difference -> { Invitation.count } do
      post invitations_path(account_id: @semisto.id), params: { invitation: { email_address: "x@example.com", role: "admin" } }
    end
    patch membership_path(memberships(:mohammad_semisto), account_id: @semisto.id), params: { membership: { role: "admin" } }
    assert_equal "member", memberships(:mohammad_semisto).reload.role
  end

  test "an admin promotes a member" do
    sign_in_as users(:michael)
    patch membership_path(memberships(:mohammad_semisto), account_id: @semisto.id), params: { membership: { role: "admin" } }
    assert_equal "admin", memberships(:mohammad_semisto).reload.role
  end

  test "the last admin can neither step down nor leave" do
    sign_in_as users(:michael)
    patch membership_path(memberships(:michael_semisto), account_id: @semisto.id), params: { membership: { role: "member" } }
    assert_equal "admin", memberships(:michael_semisto).reload.role

    delete membership_path(memberships(:michael_semisto), account_id: @semisto.id)
    assert Membership.exists?(memberships(:michael_semisto).id)
  end

  test "a member can leave" do
    sign_in_as users(:mohammad)
    delete membership_path(memberships(:mohammad_semisto), account_id: @semisto.id)
    assert_redirected_to accounts_path
    assert_not Membership.exists?(memberships(:mohammad_semisto).id)
  end

  test "a member cannot remove someone else" do
    sign_in_as users(:mohammad)
    delete membership_path(memberships(:michael_semisto), account_id: @semisto.id)
    assert Membership.exists?(memberships(:michael_semisto).id)
  end
end
