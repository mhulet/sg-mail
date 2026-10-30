# Un connecteur qui couvre plusieurs clients de la personne. Chaque appel d'outil s'exécute client par client,
# avec l'isolation habituelle (acts_as_tenant et Row Level Security), et le résultat dit de quel client vient
# chaque élément :
# - un argument qui désigne un élément (conversation_id, id…) : dans le client de cet élément ;
# - sinon, pour une liste (aggregates!) : dans chaque client, résultats combinés ;
# - sinon : dans le client donné par account_id, obligatoire dès qu'il y en a plusieurs.
class SgMailMcp::Accounts
  def initialize(memberships)
    @memberships = memberships
  end

  def run(tool, account_id, arguments, &perform)
    memberships = account_id.present? ? [ membership!(account_id) ] : @memberships

    if (membership = owner(tool, arguments, memberships))
      tag(membership, within(membership) { perform.(arguments) })
    elsif tool.aggregates?
      results = memberships.map { |m| [ account(m), within(m) { perform.(arguments) } ] }
      tool.combine(results, **arguments)
    elsif memberships.one?
      tag(memberships.first, within(memberships.first) { perform.(arguments) })
    else
      raise ArgumentError, "Tu as accès à plusieurs clients : précise account_id (#{@memberships.map { |m| "#{m.account_id} #{m.account.name}" }.join(", ")})."
    end
  end

  private

  def membership!(account_id)
    @memberships.find { |m| m.account_id == account_id.to_i } or
      raise ArgumentError, "account_id #{account_id} : client inconnu ou inaccessible (voir whoami)"
  end

  # Le client de l'élément désigné. Seul son numéro de client est lu hors isolation ; l'outil le relit
  # ensuite dans ce client, avec les règles d'accès habituelles.
  def owner(tool, arguments, memberships)
    argument, model = tool.locators.find { |name, _| arguments[name].present? }
    return unless argument

    id = arguments[argument]
    account_id = Tenancy.across_accounts { model.where(id: id).pick(:account_id) }
    memberships.find { |m| m.account_id == account_id } or raise ActiveRecord::RecordNotFound.new(nil, model.name, nil, id)
  end

  def within(membership, &block)
    Current.set(membership: membership) { Tenancy.with_account(membership.account, &block) }
  end

  def account(membership) = { id: membership.account_id, name: membership.account.name }

  def tag(membership, result) = { account: account(membership) }.merge(result)
end
