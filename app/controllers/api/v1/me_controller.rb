class Api::V1::MeController < Api::V1::BaseController
  # Qui suis-je, dans quel client, avec quelles boîtes et quels collègues.
  def show
    render json: {
      user: serializer.user(Current.user),
      account: serializer.account(Current.account),
      mailboxes: actions.mailboxes.map { |mailbox| serializer.mailbox(mailbox) },
      members: actions.members.map { |user| serializer.user(user) }
    }
  end
end
