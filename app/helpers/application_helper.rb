module ApplicationHelper
  # « À trier (3) » : le nombre d'expéditeurs qui attendent une décision dans le Screener.
  def screener_label
    count = Conversation.accessible_by(Current.user).screening_pending_for(Current.user).distinct.count(:sender_address)
    count.zero? ? "À trier" : "À trier (#{count})"
  end

  # Lien de navigation, marqué comme page courante quand on y est.
  def nav_link(label, path)
    link_to label, path, aria: { current: ("page" if current_page?(path)) }
  end
end
