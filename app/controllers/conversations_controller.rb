class ConversationsController < ApplicationController
  include AccountScoped
  PER_PAGE = 50

  before_action :set_conversation, only: %i[show unread assign]

  # Boîte de réception unifiée : les fils de toutes les boîtes auxquelles on a accès.
  # Une pile façon Hey : la réception (par défaut), ?box=feed ou ?box=paper_trail.
  def index
    @box = params[:box].presence_in(Screening::BUCKETS) || "imbox"
    @mailboxes = Mailbox.accessible_by(Current.user).order(:address)
    @mailbox = @mailboxes.find(params[:mailbox_id]) if params[:mailbox_id].present?
    @conversations = page(filtered_conversations)
  end

  def show
    @messages = @conversation.messages.includes(:readings)
    @people = @conversation.mailbox.users_with_access.order(:name).to_a
    @notes = @conversation.notes.includes(:user)
    @tasks = @conversation.tasks.includes(:assignee).by_due_date
    @screening = @conversation.screening_for(Current.user)
    @bucket = @conversation.bucket_for(Current.user)
    @conversation.mark_read_by!(Current.user)
  end

  def unread
    @conversation.mark_unread_by!(Current.user)
    redirect_to conversations_path, notice: "Fil marqué comme non lu."
  end

  # Qui s'occupe de ce fil : une personne qui a accès à la boîte, ou personne.
  def assign
    assignee = @conversation.mailbox.users_with_access.find_by(id: params[:assignee_id])
    @conversation.update!(assignee: assignee)
    notice = assignee ? "#{assignee.display_name} s'occupe de ce fil." : "Plus personne n'est assigné à ce fil."
    redirect_to conversation_path(@conversation), notice: notice
  end

  # « Tout marquer comme lu » : utile après l'import de milliers de vieux messages.
  # Depuis le Feed ou le Paper Trail, seulement les fils de cette pile.
  def mark_all_read
    mailboxes = Mailbox.accessible_by(Current.user)
    mailboxes = mailboxes.where(id: params[:mailbox_id]) if params[:mailbox_id].present?
    messages = Message.where(mailbox: mailboxes)
    box = params[:box].presence_in(Screening::BUCKETS - [ "imbox" ])
    messages = messages.where(conversation_id: Conversation.in_bucket_for(Current.user, box).select(:id)) if box
    Reading.mark!(Current.user, messages)
    redirect_to conversations_path(box: box, mailbox_id: params[:mailbox_id].presence), notice: "Tout est marqué comme lu."
  end

  private

  def set_conversation
    @conversation = Conversation.accessible_by(Current.user).find(params[:id])
  end

  def filtered_conversations
    scope = Conversation.accessible_by(Current.user).in_bucket_for(Current.user, @box)
      .with_unread_for(Current.user).includes(:mailbox, :assignee)
    scope = @mailbox ? scope.where(mailbox: @mailbox) : scope.inbox
    scope = scope.assigned_to(Current.user) if params[:mine] == "1"
    scope = scope.unread_for(Current.user) if params[:unread] == "1"
    scope
  end

  # Pagination par date : ?before=<horodatage du dernier fil affiché>.
  def page(scope)
    scope = scope.where(last_message_at: ...Time.zone.parse(params[:before])) if params[:before].present?
    scope.recent.limit(PER_PAGE).to_a
  end
end
