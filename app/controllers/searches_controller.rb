class SearchesController < ApplicationController
  include AccountScoped
  LIMIT = 100

  def show
    @mailboxes = Mailbox.accessible_by(Current.user).order(:address)
    @mailbox = @mailboxes.find(params[:mailbox_id]) if params[:mailbox_id].present?
    @search = MessageSearch.new(Current.user, params[:q], mailbox: @mailbox)
    @conversations = @search.blank? ? [] :
      @search.conversations.with_unread_for(Current.user).includes(:mailbox, :assignee).recent.limit(LIMIT).to_a
  end
end
