class SearchesController < ApplicationController
  include AccountScoped
  LIMIT = 100
  PREVIEW_LIMIT = 8

  # Pendant la frappe, le champ du menu demande l'aperçu (cadre « search_preview ») et la page de
  # recherche ne recharge que ses résultats (cadre « search_results »).
  def show
    @mailboxes = Mailbox.accessible_by(Current.user).by_display_name
    @mailbox = @mailboxes.find(params[:mailbox_id]) if params[:mailbox_id].present?
    @search = MessageSearch.new(Current.user, params[:q], mailbox: @mailbox)
    preview = turbo_frame_request_id == "search_preview"
    @conversations = @search.blank? ? [] :
      @search.conversations.with_unread_for(Current.user).includes(:mailbox, :assignee).recent
        .limit(preview ? PREVIEW_LIMIT : LIMIT).to_a
    render :preview if preview
  end
end
