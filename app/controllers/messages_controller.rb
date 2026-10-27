class MessagesController < ApplicationController
  include AccountScoped

  def show
    @message = Message.find(params[:id])
    @thread = @message.mailbox.messages.where(thread_key: @message.thread_key).order(:sent_at)
  end
end
