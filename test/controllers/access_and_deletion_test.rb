require "test_helper"

class AccessAndDeletionTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @semisto = accounts(:semisto)
    with_account(@semisto) do
      @shared = Mailbox.create!(provider: "gmail", address: "formations@semisto.org", credentials: { "refresh_token" => "rt-123" })
      @shared.grant!(users(:michael), "manage")
      @shared.grant!(users(:mohammad), "send")
      @message = @shared.messages.create!(provider_uid: "a", thread_key: "t1", from_address: "anne@example.org", from_name: "Anne",
        subject: "Inscription", sent_at: 2.days.ago, labels: %w[INBOX])
      Conversation.rebuild_for(@shared)
      @inscription = Conversation.find_by!(thread_key: "t1")
    end
  end

  test "opening a thread from the web, the API or Claude is logged, and only admins read the log" do
    sign_in_as users(:mohammad)
    get conversation_path(@inscription, account_id: @semisto.id)
    token = ApiToken.create!(user: users(:mohammad), account: @semisto, name: "CLI").token
    get api_v1_conversation_path(@inscription), headers: { "Authorization" => "Bearer #{token}" }

    with_account(@semisto) do
      assert_equal [ %w[open api], %w[open web] ], AccessLog.recent.map { |log| [ log.action, log.via ] }
      assert_equal [ users(:mohammad) ], AccessLog.all.map(&:user).uniq
    end

    get access_logs_path(account_id: @semisto.id)
    assert_redirected_to account_root_path(account_id: @semisto.id)

    sign_in_as users(:michael)
    get access_logs_path(account_id: @semisto.id, user_id: users(:mohammad).id)
    assert_response :success
    assert_select "table.access-logs tr", 3
    assert_select "td", /a ouvert « Inscription »/
    assert_select "td", "API ou CLI"
  end

  test "logs older than a year are purged" do
    with_account(@semisto) do
      AccessLog.record!(users(:michael), @inscription, via: "web").update_columns(created_at: 13.months.ago)
      AccessLog.record!(users(:michael), @inscription, via: "web")
    end
    PurgeAccessLogsJob.perform_now
    assert_equal 1, with_account(@semisto) { AccessLog.count }
  end

  test "staff deletes a client and all its data, after typing its name" do
    with_account(@semisto) do
      AccessLog.record!(users(:michael), @inscription, via: "web")
      Reading.mark!(users(:michael), @shared.messages)
      @inscription.notes.create!(user: users(:michael), body: "Rappeler")
      ConversationState.archive!(@inscription, users(:michael))
      Screening.decide!(users(:michael), "anne@example.org", "accepted")
    end
    ApiToken.create!(user: users(:mohammad), account: @semisto, name: "CLI")

    sign_in_as users(:michael)
    delete account_path(@semisto), params: { confirmation: "semisto" }
    assert_equal "Pour supprimer « #{@semisto.name} », retape son nom exactement.", flash[:alert]
    assert Account.exists?(@semisto.id)

    assert_enqueued_with(job: RevokeGoogleTokenJob, args: [ "rt-123" ]) do
      delete account_path(@semisto), params: { confirmation: @semisto.name }
    end
    assert_equal "Client « #{@semisto.name} » supprimé, avec toutes ses données.", flash[:notice]
    assert_not Account.exists?(@semisto.id)

    tables = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT table_name FROM information_schema.columns WHERE column_name = 'account_id' AND table_schema = 'public'
    SQL
    Tenancy.across_accounts do
      tables.each { |table| assert_equal 0, ActiveRecord::Base.connection.select_value("SELECT count(*) FROM #{table} WHERE account_id = #{@semisto.id}"), table }
      assert Account.exists?(accounts(:silvea).id)
    end
  end

  test "only staff can delete a client" do
    sign_in_as users(:mohammad)
    delete account_path(@semisto), params: { confirmation: @semisto.name }
    assert Account.exists?(@semisto.id)
  end
end
