# Mon agent : prénom, couleur, image, style et consignes. Le même dans tous mes clients (décision A2).
class AgentsController < ApplicationController
  include AccountScoped
  include AttachmentServing

  def edit
    @agent = Agent.for(Current.user)
  end

  def update
    @agent = Agent.for(Current.user)
    attributes = params.expect(agent: %i[name color style instructions avatar remove_avatar])
    @agent.avatar.purge_later if attributes.delete(:remove_avatar) == "1" && attributes[:avatar].blank? && @agent.avatar.attached?
    if @agent.update(attributes)
      redirect_to edit_agent_path, notice: "#{@agent.name} est prêt."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # L'image de mon agent, servie comme une pièce jointe : seulement à moi.
  def avatar
    agent = Agent.find_by(user: Current.user)
    return head(:not_found) unless agent&.avatar&.attached?

    serve_inline(agent.avatar.blob)
  end
end
