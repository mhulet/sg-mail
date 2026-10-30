module DraftsHelper
  # « Envoyer plus tard » : quelques heures toutes prêtes, à l'heure de Bruxelles.
  def send_later_choices(now = Time.zone.now)
    today = now.to_date
    choices = []
    choices << [ "Ce soir, 18h", today.in_time_zone.change(hour: 18) ] if now.hour.between?(6, 16)
    choices << [ "Demain matin, 8h", today.tomorrow.in_time_zone.change(hour: 8) ]
    monday = today.next_occurring(:monday)
    choices << [ "Lundi matin, 8h", monday.in_time_zone.change(hour: 8) ] unless monday == today.tomorrow
    choices
  end

  # « demain à 8h00 », « lundi 2 novembre à 8h00 ».
  def send_time_label(time)
    time = time.in_time_zone
    day = case time.to_date
    when Time.zone.today then "aujourd'hui"
    when Time.zone.tomorrow then "demain"
    else l(time.to_date, format: "%A %-d %B")
    end
    "#{day} à #{l(time, format: "%-Hh%M")}"
  end
end
