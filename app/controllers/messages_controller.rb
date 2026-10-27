class MessagesController < ApplicationController
  include AccountScoped

  def show
    @message = Message.where(mailbox: Mailbox.accessible_by(Current.user)).find(params[:id])
    @thread = @message.mailbox.messages.where(thread_key: @message.thread_key).order(:sent_at)
  end
end
