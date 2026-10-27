require "test_helper"

class InvitationAcceptancesControllerTest < ActionDispatch::IntegrationTest
  setup { @invitation = invitations(:pending) }

  test "a newcomer creates an account and joins" do
    get invitation_acceptance_path(@invitation.token)
    assert_response :success

    assert_difference -> { User.count } => 1, -> { Membership.count } => 1 do
      post invitation_acceptance_path(@invitation.token), params: { user: { name: "Nouvelle", password: "secret123", password_confirmation: "secret123" } }
    end

    user = User.find_by!(email_address: "nouvelle@example.com")
    assert_redirected_to account_root_path(account_id: @invitation.account_id)
    assert_equal "member", user.memberships.sole.role
    assert @invitation.reload.accepted_at
    assert cookies[:session_id].present?
  end

  test "an invitation works only once" do
    post invitation_acceptance_path(@invitation.token), params: { user: { name: "Nouvelle", password: "secret123", password_confirmation: "secret123" } }
    delete session_path

    get invitation_acceptance_path(@invitation.token)
    assert_redirected_to root_path
  end

  test "a signed in user joins with their account" do
    sign_in_as users(:lea)
    assert_difference -> { users(:lea).memberships.count } => 1 do
      post invitation_acceptance_path(@invitation.token)
    end
    assert_redirected_to account_root_path(account_id: @invitation.account_id)
  end

  test "someone who already has an account is asked to sign in first" do
    @invitation.update!(email_address: "lea@example.com")
    assert_no_difference -> { User.count } do
      post invitation_acceptance_path(@invitation.token), params: { user: { name: "Léa", password: "x", password_confirmation: "x" } }
    end
    assert_redirected_to new_session_path

    post session_path, params: { email_address: "lea@example.com", password: "password" }
    assert_redirected_to invitation_acceptance_url(@invitation.token)
  end

  test "an expired invitation is refused" do
    get invitation_acceptance_path(invitations(:expired).token)
    assert_redirected_to root_path
  end
end
