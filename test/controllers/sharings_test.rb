require "test_helper"

class SharingsTest < ActionDispatch::IntegrationTest
  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @personal = Mailbox.create!(provider: "imap", address: "mohammad@semisto.org", connected_by: users(:mohammad))
      @personal.grant!(users(:mohammad), "manage")
      @shared = Mailbox.create!(provider: "gmail", address: "formations@semisto.org")
      @shared.grant!(users(:mohammad), "manage")
      @shared.grant!(users(:michael), "read")
    end
  end

  def access_level(user, mailbox) = with_account(@semisto) { mailbox.access_for(user)&.level }

  test "shows every member against every mailbox one manages" do
    sign_in_as users(:mohammad)
    get sharing_path(account_id: @semisto.id)
    assert_response :success
    assert_select "table.sharing thead a", "formations@semisto.org"
    assert_select "table.sharing thead a", "mohammad@semisto.org"
    assert_select "table.sharing tbody tr", @semisto.memberships.count
    assert_select "select[aria-label='Accès de #{users(:michael).display_name} à formations@semisto.org'] option[selected][value=read]"
  end

  test "mailboxes one does not manage stay out of the matrix" do
    sign_in_as users(:michael)
    get sharing_path(account_id: @semisto.id)
    assert_response :success
    assert_select "table.sharing", count: 0
    assert_select "p", /Une boîte à laquelle tu as accès n'apparaît pas ici/
  end

  test "a manager grants, changes and removes access from the matrix" do
    sign_in_as users(:mohammad)
    patch sharing_path(account_id: @semisto.id), params: { mailbox_id: @personal.id, user_id: users(:michael).id, level: "send" }
    assert_redirected_to sharing_path(account_id: @semisto.id)
    assert_equal "send", access_level(users(:michael), @personal)

    patch sharing_path(account_id: @semisto.id), params: { mailbox_id: @personal.id, user_id: users(:michael).id, level: "" }
    assert_nil access_level(users(:michael), @personal)
  end

  test "the last manager stays" do
    sign_in_as users(:mohammad)
    patch sharing_path(account_id: @semisto.id), params: { mailbox_id: @personal.id, user_id: users(:mohammad).id, level: "read" }
    assert_equal "manage", access_level(users(:mohammad), @personal)
    assert_equal "Il faut garder au moins une personne qui gère mohammad@semisto.org.", flash[:alert]
  end

  test "readers cannot change access, even by crafting the request" do
    sign_in_as users(:michael)
    patch sharing_path(account_id: @semisto.id), params: { mailbox_id: @shared.id, user_id: users(:michael).id, level: "manage" }
    assert_response :not_found
    assert_equal "read", access_level(users(:michael), @shared)
  end

  test "only members of the account can be given access" do
    sign_in_as users(:mohammad)
    patch sharing_path(account_id: @semisto.id), params: { mailbox_id: @personal.id, user_id: users(:lea).id, level: "read" }
    assert_response :not_found
  end
end
