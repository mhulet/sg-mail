class NotesController < ApplicationController
  include AccountScoped
  before_action :set_conversation

  def create
    note = @conversation.notes.build(user: Current.user, body: params.dig(:note, :body))
    if note.save
      redirect_to conversation_path(@conversation, anchor: helpers.dom_id(note)), notice: "Note ajoutée."
    else
      redirect_to conversation_path(@conversation), alert: "Une note vide ne s'enregistre pas."
    end
  end

  def destroy
    @conversation.notes.where(user: Current.user).find(params[:id]).destroy!
    redirect_to conversation_path(@conversation), notice: "Note supprimée."
  end

  private

  def set_conversation
    @conversation = Conversation.accessible_by(Current.user).find(params[:conversation_id])
  end
end
