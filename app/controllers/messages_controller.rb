class MessagesController < ApplicationController
  include AccountScoped

  # Ancienne adresse d'un message : on ouvre son fil.
  def show
    message = Message.where(mailbox: Mailbox.accessible_by(Current.user)).find(params[:id])
    redirect_to conversation_path(message.conversation_id, anchor: helpers.dom_id(message))
  end
end
